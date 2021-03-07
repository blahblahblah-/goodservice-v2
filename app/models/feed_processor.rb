require 'nyct-subway.pb'

class FeedProcessor
  UPCOMING_TRIPS_TIME_ALLOWANCE = 30.minutes.to_i
  UPCOMING_TRIPS_TIME_ALLOWANCE_FOR_SI = 60.minutes.to_i
  SI_FEED = '-si'
  INCOMPLETE_TRIP_TIMEOUT = 3.minutes.to_i
  DELAY_THRESHOLD = 5.minutes.to_i
  EXCESSIVE_DELAY_THRESHOLD = 10.minutes.to_i
  SCHEDULE_DISCREPANCY_THRESHOLD = -2.minutes.to_i
  SUPPLEMENTARY_TIME_LOOKUP = 20.minutes.to_i
  TRIP_UPDATE_TIMEOUT = 10.minutes.to_i

  class << self
    def analyze_feed(feed_id, minutes, fraction_of_minute)
      feed_name = "feed:#{minutes}:#{fraction_of_minute}:#{feed_id}"
      marshaled_feed = RedisStore.feed(feed_id, minutes, fraction_of_minute)
      feed = Marshal.load(marshaled_feed) if marshaled_feed

      if !feed
        throw "Error: Feed #{feed_name} not found"
      end

      puts "Analyzing feed #{feed_name}:#{minutes}:#{fraction_of_minute}"

      return if feed.entity.empty?

      timestamp = feed.header.timestamp
      if timestamp < (Time.current - 1.hour).to_i
        puts "Feed id #{feed_id} is outdated"
        return
      end

      puts "Timestamp of #{feed_name} is #{timestamp}"

      trip_timestamps = extract_vehicle_timestamps(feed.entity)

      trips = feed.entity.select { |entity|
        valid_trip?(timestamp, entity, feed_id)
      }.map { |entity|
        convert_trip(timestamp, entity, trip_timestamps)
      }.select { |trip| trip.timestamp >= timestamp - TRIP_UPDATE_TIMEOUT }

      translated_trips = trips.map{ |trip|
        translate_trip(feed_id, trip, trips)
      }

      unmatched_trips = []
      active_trip_ids = RedisStore.active_trip_list(feed_id, timestamp)
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

      routes = translated_trips.group_by(&:route_id)

      REDIS_CLIENT.pipelined do
        translated_trips.each do |trip|
          update_trip(feed_id, timestamp, trip)
        end
      end

      complete_trips(feed_id, timestamp)

      routes.each do |route_id, trips|
        if trips.any?(&:latest)
          RouteProcessor.process_route(route_id, trips, timestamp) 
        else
          puts "No updated trips for #{route_id}, skipping..."
        end
      end
    end

    private

    def extract_vehicle_timestamps(entity)
      entity.select {|e| e.field?(:vehicle) && e.vehicle.timestamp > 0 }.to_h { |e|
        [e.vehicle.trip.trip_id, e.vehicle.timestamp]
      }
    end

    def valid_trip?(timestamp, entity, feed_id)
      return false unless entity.field?(:trip_update) && entity.trip_update.trip.nyct_trip_descriptor
      upcoming_trip_time_allowance = feed_id == SI_FEED ? UPCOMING_TRIPS_TIME_ALLOWANCE_FOR_SI : UPCOMING_TRIPS_TIME_ALLOWANCE
      entity.trip_update.stop_time_update.reject! { |update|
        (update.departure || update.arrival)&.time.nil?
      }
      return false if entity.trip_update.stop_time_update.all? {|update| (update&.departure || update&.arrival).time < timestamp }
      return false if entity.trip_update.stop_time_update.all? {|update|
        (update&.departure || update&.arrival).time > timestamp + upcoming_trip_time_allowance
      }
      direction = entity.trip_update.trip.nyct_trip_descriptor.direction == Transit_realtime::NyctTripDescriptor::Direction::NORTH ? 'N' : 'S'
      return false unless entity.trip_update.stop_time_update.all? {|update| update.stop_id[3] == direction }
      return false unless entity.trip_update.stop_time_update.present?
      true
    end

    def convert_trip(timestamp, entity, trip_timestamps)
      route_id = translate_route_id(entity.trip_update.trip.route_id)
      trip_id = entity.trip_update.trip.trip_id
      direction = entity.trip_update.trip.nyct_trip_descriptor.direction.to_i

      if is_a_shuttle?(route_id, entity)
        puts "A Shuttle found, reversing trip #{trip_id}"
        entity.trip_update, direction = reverse_trip_update(entity.trip_update)
      end

      remove_hidden_stops!(entity.trip_update)
      remove_bad_data!(entity.trip_update, timestamp)
      trip_timestamp = [trip_timestamps[trip_id] || timestamp, timestamp].min

      Trip.new(route_id, direction, trip_id, trip_timestamp, entity.trip_update)
    end

    def translate_trip(feed_id, trip, trips)
      if (translated_trip_id = RedisStore.trip_translation(feed_id, trip.id))
        unless trips.map(&:id).include?(translated_trip_id)
          trip.id = translated_trip_id
        end
      end
      trip
    end

    def match_trip(feed_id, unmatched_trip_ids, trip)
      potential_match = unmatched_trip_ids.map { |t_id|
        t = RedisStore.active_trip(feed_id, t_id)
        marshaled_t = Marshal.load(t) if t
      }.compact.select { |marshaled_t|
        trip.similar(marshaled_t)
      }.min_by(1) { |marshaled_t|
        (marshaled_t.destination_time - trip.destination_time).abs
      }.first

      if potential_match
        RedisStore.add_trip_translation(feed_id, trip.id, potential_match.id)
        puts "Matched trip #{trip.id} with #{potential_match.id}"
        trip.id = potential_match.id
        unmatched_trip_ids.delete(trip.id)
      else
        puts "New trip #{trip.id}"
      end
    end

    def attach_previous_trip_update(feed_id, trip)
      marshaled_previous_update = RedisStore.active_trip(feed_id, trip.id)
      if marshaled_previous_update
        previous_update = Marshal.load(marshaled_previous_update)

        if trip.timestamp != previous_update.timestamp
          trip.previous_trip = previous_update
          trip.previous_trip.previous_trip = nil
        else
          puts "#{trip.id} has not been updated since #{Time.zone.at(trip.timestamp)}"
          trip.previous_trip = trip.previous_trip&.previous_trip
          trip.delayed_time = previous_update.delayed_time
          trip.latest = false
        end

        trip.schedule = trip.previous_trip.schedule if trip.previous_trip&.schedule
        trip.past_stops = trip.previous_trip.past_stops if trip.previous_trip&.past_stops
      end
    end

    def update_trip(feed_id, timestamp, trip)
      return unless trip.latest
      trip.update_delay!
      process_stops(trip)
      if trip.effective_delayed_time >= DELAY_THRESHOLD
        puts "Delay detected for #{trip.id} for #{trip.effective_delayed_time}"
        RedisStore.add_delay(trip.route_id, trip.direction, trip.id, trip.timestamp)
      end
      marshaled_trip = Marshal.dump(trip)
      trip.time_between_stops(SUPPLEMENTARY_TIME_LOOKUP).each do |station_ids, time|
        stop_ids = station_ids.split('-')
        RedisStore.add_supplementary_scheduled_travel_time(stop_ids.first, stop_ids.second, time) if time > 0
      end
      trip.upcoming_stops.each do |stop_id|
        RedisStore.add_route_to_route_stop(trip.route_id, stop_id, trip.direction, timestamp)
      end
      RedisStore.add_active_trip(feed_id, trip.id, marshaled_trip)
      RedisStore.add_to_active_trip_list(feed_id, trip.id, timestamp)
    end

    def process_stops(trip)
      if trip.previous_trip &&
        trip.previous_trip.effective_delayed_time < EXCESSIVE_DELAY_THRESHOLD &&
        (trip.previous_trip.previous_stop_schedule_discrepancy >= SCHEDULE_DISCREPANCY_THRESHOLD ||
            trip.schedule_discrepancy - trip.previous_trip.previous_stop_schedule_discrepancy <= (SCHEDULE_DISCREPANCY_THRESHOLD * -1)
        )
        time_traveled_between_stops_made = trip.time_traveled_between_stops_made
        return unless time_traveled_between_stops_made.size < 3
        trip.time_traveled_between_stops_made.each do |stops_str, travel_time|
          RedisStore.add_travel_time(stops_str, travel_time, trip.timestamp)
        end
      end
      trip.update_stops_made!
    end

    def complete_trips(feed_id, timestamp)
      active_trips_not_in_current_feed = RedisStore.active_trip_list(feed_id, timestamp).to_set
      active_trips_not_in_current_feed.each do |trip_id|
        marshaled_trip = RedisStore.active_trip(feed_id, trip_id)
        if marshaled_trip
          trip = Marshal.load(marshaled_trip)
          next unless trip.stops.size < 3
          puts "Completing trip #{trip_id} with stops at #{trip.stops.keys.join(", ")}"
          stops_hash = {}

          if trip.past_stops.present?
            last_stop_id = trip.past_stops.keys.last
            stops_hash[last_stop_id] = trip.past_stops[last_stop_id]
          end

          stops_hash.merge!(trip.stops.select { |_, time|
            time > trip.timestamp
          }).each_cons(2) do |(a_stop, a_timestamp), (b_stop, b_timestamp)|
            stops_str = "#{a_stop}-#{b_stop}"
            a_stop_time = [timestamp, a_timestamp].min
            b_stop_time = [timestamp, b_timestamp].min

            break if a_stop_time == b_stop_time
            travel_time = b_stop_time - a_stop_time
            RedisStore.add_travel_time(stops_str, travel_time, timestamp)
          end
        end
        RedisStore.remove_from_active_trip_list(feed_id, trip_id)
        RedisStore.remove_trip_translations(feed_id, trip_id)
        RedisStore.remove_active_trip(feed_id, trip_id)
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

    def remove_hidden_stops!(trip_update)
      trip_update.stop_time_update.filter! { |update| valid_stops.include?(update.stop_id[0..2]) }
    end

    def remove_bad_data!(trip_update, timestamp)
      first_stop = trip_update.stop_time_update.sort_by { |update| (update.departure || update.arrival).time}.first
      first_stop_index = trip_update.stop_time_update.index(first_stop)
      trip_update.stop_time_update.filter! { |update| trip_update.stop_time_update.index(update) >= first_stop_index || (update.departure || update.arrival).time < (first_stop.departure || first_stop.arrival).time }
    end

    def valid_stops
      @valid_stops ||= Scheduled::Stop.pluck(:internal_id).to_set
    end
  end
end