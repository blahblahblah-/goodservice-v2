require 'nyct-subway.pb'

class FeedProcessor
  UPCOMING_TRIPS_TIME_ALLOWANCE = 30.minutes
  INACTIVE_TRIP_TIMEOUT = 30.minutes
  INCOMPLETE_TRIP_TIMEOUT = 3.minutes
  DELAY_THRESHOLD = 5.minutes

  class << self
    def analyze_feed(feed_id, minutes, half_minute)
      feed_name = "feed:#{minutes}:#{half_minute}:#{feed_id}"
      marshaled_feed = REDIS_CLIENT.get("feed:#{minutes}:#{half_minute}:#{feed_id}")
      feed = Marshal.load(marshaled_feed) if marshaled_feed

      if !feed
        throw "Error: Feed #{feed_name} not found"
      end

      puts "Analyzing feed #{feed_name}"

      return if feed.entity.empty?

      timestamp = feed.header.timestamp
      if timestamp < (Time.current - 1.hour).to_i
        puts "Feed id #{feed_id} is outdated"
        return
      end

      trips = feed.entity.select { |entity|
        valid_trip?(timestamp, entity)
      }.map { |entity|
        convert_trip(timestamp, entity)
      }

      translated_trips = trips.map{ |trip|
        translate_trip(feed_id, trip)
      }

      unmatched_trips = []
      active_trip_ids = REDIS_CLIENT.zrangebyscore("active-trips-list:#{feed_id}", timestamp - INACTIVE_TRIP_TIMEOUT, "(#{timestamp}")
      unmatched_trip_ids = active_trip_ids - translated_trips.map(&:id)

      unmatched_trips = translated_trips.select do |trip|
        !active_trip_ids.include?(trip.id)
      end

      unmatched_trips.each do |trip|
        match_trip(feed_id, unmatched_trip_ids, trip)
      end

      translated_trips.each do |trip|
        attach_previous_trip_update(feed_id, trip)
      end

      REDIS_CLIENT.pipelined do
        translated_trips.each do |trip|
          update_trip(feed_id, timestamp, trip)
        end
        translated_trips.map(&:route_id).uniq.each do |route_id|
          REDIS_CLIENT.set("last-update:#{route_id}", timestamp, ex: 3600)
        end
      end

      complete_trips(feed_id, timestamp)
    end

    private

    def valid_trip?(timestamp, entity)
      return false unless entity.field?(:trip_update) && entity.trip_update.trip.nyct_trip_descriptor
      entity.trip_update.stop_time_update.reject! { |update|
        (update.departure || update.arrival)&.time.nil?
      }
      return false if entity.trip_update.stop_time_update.all? {|update| (update&.departure || update&.arrival).time < timestamp }
      return false if entity.trip_update.stop_time_update.all? {|update|
        (update&.departure || update&.arrival).time > timestamp + UPCOMING_TRIPS_TIME_ALLOWANCE
      }
      true
    end

    def convert_trip(timestamp, entity)
      route_id = translate_route_id(entity.trip_update.trip.route_id)
      trip_id = entity.trip_update.trip.trip_id
      direction = entity.trip_update.trip.nyct_trip_descriptor.direction.to_i

      if is_a_shuttle?(route_id, entity)
        puts "A Shuttle found, reversing trip #{trip_id}"
        entity.trip_update, direction = reverse_trip_update(entity.trip_update)
      end

      Trip.new(route_id, direction, trip_id, timestamp, entity.trip_update)
    end

    def translate_trip(feed_id, trip)
      if (translated_trip_id = REDIS_CLIENT.hget("active-trips:translations:#{feed_id}", trip.id))
        trip.id = translated_trip_id
      end
      trip
    end

    def match_trip(feed_id, unmatched_trip_ids, trip)
      potential_match = unmatched_trip_ids.map { |t_id|
        t = REDIS_CLIENT.hget("active-trips:#{feed_id}", t_id)
        marshaled_t = Marshal.load(t) if t
      }.compact.select { |marshaled_t|
        trip.similar(marshaled_t)
      }.min_by(1) { |marshaled_t|
        (marshaled_t.destination_time - trip.destination_time).abs
      }.first

      if potential_match
        REDIS_CLIENT.hset("active-trips:translations:#{feed_id}", trip.id, potential_match.id)
        puts "Matched trip #{trip.id} with #{potential_match.id}"
        trip.id = potential_match.id
        unmatched_trip_ids.delete(trip.id)
      else
        puts "New trip #{trip.id}"
      end
    end

    def attach_previous_trip_update(feed_id, trip)
      marshaled_previous_update = REDIS_CLIENT.hget("active-trips:#{feed_id}", trip.id)
      if marshaled_previous_update
        previous_update = Marshal.load(marshaled_previous_update)
        trip.previous_trip = previous_update
      end
    end

    def update_trip(feed_id, timestamp, trip)
      process_stops(trip)
      trip.update_delay!
      if trip.delay >= DELAY_THRESHOLD
        puts "Delay detected for #{trip.id} for #{trip.delay}"
        REDIS_CLIENT.zadd("delay:#{trip.route_id}:#{trip.direction}", trip.timestamp, trip.id)
      end
      marshaled_trip = Marshal.dump(trip)
      REDIS_CLIENT.hset("active-trips:#{feed_id}", trip.id, marshaled_trip)
      REDIS_CLIENT.zadd("active-trips-list:#{feed_id}", timestamp, trip.id)
    end

    def process_stops(trip)
      # TODO: M train shuffle
      trip.stops_made.each do |stop_id, timestamp|
        puts "Stop made at #{stop_id} for #{trip.id} at #{timestamp}"
        REDIS_CLIENT.zadd("stops:#{stop_id}", timestamp, trip.id)
      end
    end

    def complete_trips(feed_id, timestamp)
      active_trips_not_in_current_feed = REDIS_CLIENT.zrangebyscore("active-trips-list:#{feed_id}", timestamp - INCOMPLETE_TRIP_TIMEOUT, "(#{timestamp}").to_set
      active_trips_not_in_current_feed.each do |trip_id|
        marshaled_trip = REDIS_CLIENT.hget("active-trips:#{feed_id}", trip_id)
        next unless marshaled_trip
        trip = Marshal.load(marshaled_trip)
        next unless trip.stops.size < 4
        puts "Completing trip #{trip_id} with stops at #{trip.stops.keys.join(", ")}"
        trip.stops.each do |stop_id, time|
          REDIS_CLIENT.zadd("stops:#{stop_id}", [timestamp, time].min, trip_id)
        end
        REDIS_CLIENT.zrem("active-trips-list:#{feed_id}", trip_id)
      end
    end

    def translate_route_id(route_id)
      route_id = "SI" if route_id == "SS"
      route_id = "5" if route_id == "5X"
      route_id
    end

    def is_a_shuttle?(route_id, entity)
      route_id == 'A' && entity.trip_update.stop_time_update.present? &&
        ((entity.trip_update.stop_time_update.last.stop_id == 'A55S' && entity.trip_update.stop_time_update[-2] && entity.trip_update.stop_time_update[-2].stop_id =='A57S') ||
            (entity.trip_update.stop_time_update.last.stop_id == 'A65N' && entity.trip_update.stop_time_update[-2] && entity.trip_update.stop_time_update[-2].stop_id =='A64N'))
    end

    def reverse_trip_update(trip_update)
      direction = (trip_update.trip.nyct_trip_descriptor.direction.to_i == 1) ? 3 : 1

      trip_update.stop_time_update = trip_update.stop_time_update.map do |stop_time_update|
        stop_time_update.stop_id = "#{stop_time_update.stop_id[0..2]}#{stop_time_update.stop_id[3] == 'N' ? 'S' : 'N'}"

        stop_time_update
      end

      return trip_update, direction
    end

    handle_asynchronously :analyze_feed, priority: 0
  end
end