require 'nyct-subway.pb'

class FeedProcessor
  UPCOMING_TRIPS_TIME_ALLOWANCE = 30.minutes.to_i
  UPCOMING_TRIPS_TIME_ALLOWANCE_FOR_SI = 60.minutes.to_i
  SI_FEED = '-si'
  INACTIVE_TRIP_TIMEOUT = 10.minutes.to_i
  SCHEDULE_DISCREPANCY_THRESHOLD = -2.minutes.to_i
  SUPPLEMENTED_TIME_LOOKUP = 20.minutes.to_i
  TRIP_UPDATE_TIMEOUT = 30.minutes.to_i
  MIN_TRAVEL_TIME_BETWEEN_STOPS_TO_RECORD = 20
  CLOSED_STOPS = ENV['CLOSED_STOPS']&.split(',') || []
  CANAL_ST_BRIDGE_STOP = "Q01"
  CANAL_ST_TUNNEL_STOP = "R23"
  CITY_HALL_STOP = "R24"

  class << self
    def analyze_feed(feed_id, route_id, minutes, fraction_of_minute)
      feed_name = "feed:#{minutes}:#{fraction_of_minute}:#{feed_id}"
      marshaled_feed = RedisStore.feed(feed_id, minutes, fraction_of_minute)
      feed = Marshal.load(marshaled_feed) if marshaled_feed

      if !feed
        raise "Error: #{feed_name} not found"
      end

      return if feed.entity.empty?

      timestamp = feed.header.timestamp

      puts "Analyzing #{feed_name} for route #{route_id}, latency #{Time.current - Time.zone.at(timestamp)}"

      if timestamp < (Time.current - 1.hour).to_i
        puts "Feed id #{feed_id} is outdated"
        return
      end

      trip_timestamps = extract_vehicle_timestamps(feed.entity)

      trip_entities = feed.entity.select { |entity|
        valid_trip?(timestamp, entity, feed_id, route_id)
      }

      duplicate_trip_ids = trip_entities.select { |entity|
        trip_entities.any? { |e| e != entity && e.trip_update.trip.trip_id == entity.trip_update.trip.trip_id }
      }.map { |entity|
        entity.trip_update.trip.trip_id
      }

      trips = trip_entities.map { |entity|
        if duplicate_trip_ids.include?(entity.trip_update.trip.trip_id)
          entity.trip_update.trip.trip_id = "#{entity.trip_update.trip.trip_id}_#{entity.trip_update.stop_time_update.last.stop_id[0..2]}"
        end

        entity
      }.uniq { |entity|
        entity.trip_update.trip.trip_id
      }.map { |entity|
        convert_trip(timestamp, entity, trip_timestamps)
      }.compact.select { |trip| trip.timestamp >= timestamp - TRIP_UPDATE_TIMEOUT }

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

      translated_trips.select! do |trip|
        trip.is_assigned || (trip.stops.size + trip.past_stops.size) > 1
      end

      REDIS_CLIENT.pipelined do |pipeline|
        translated_trips.each do |trip|
          update_trip(feed_id, timestamp, trip, pipeline)
        end
      end

      complete_trips(feed_id, timestamp)

      if translated_trips.none?(&:latest)
        route_data_encoded = RedisStore.route_status(route_id)
        if route_data_encoded
          route_data = JSON.parse(route_data_encoded)
          if route_data['timestamp'] >= (Time.current - 2.minutes).to_i
            puts "No updated trips for #{route_id}, skipping..."
            # next
            return
          end
        end
      end

      marshaled_trips = Marshal.dump(translated_trips)
      RedisStore.add_route_trips(route_id, timestamp, marshaled_trips)
      RouteProcessorWorker.perform_async(route_id, timestamp)
      puts "Analyzed #{feed_name} for route #{route_id}, latency #{Time.current - Time.zone.at(timestamp)}"
    end

    private

    def extract_vehicle_timestamps(entity)
      entity.select {|e| e.field?(:vehicle) && e.vehicle.timestamp > 0 }.to_h { |e|
        [e.vehicle.trip.trip_id, e.vehicle.timestamp]
      }
    end

    def valid_trip?(timestamp, entity, feed_id, route_id)
      return false unless entity.field?(:trip_update) && entity.trip_update.trip.nyct_trip_descriptor
      return false unless translate_route_id(entity.trip_update.trip.route_id) == route_id
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
      is_assigned = entity.trip_update.trip.nyct_trip_descriptor.is_assigned

      if is_a_shuttle?(route_id, entity)
        entity.trip_update, direction = reverse_trip_update(entity.trip_update)
      end

      remove_hidden_stops!(entity.trip_update)
      remove_closed_stops!(entity.trip_update)
      remove_bad_data!(entity.trip_update, timestamp)
      correct_canal_st_stop!(entity.trip_update, direction)
      trip_timestamp = [trip_timestamps[trip_id] || timestamp, timestamp].min

      return unless entity.trip_update.stop_time_update.present?

      Trip.new(route_id, direction, trip_id, trip_timestamp, entity.trip_update, is_assigned)
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
        RedisStore.add_trip_translation(feed_id, potential_match.id, trip.id)
        trip.id = potential_match.id
        unmatched_trip_ids.delete(potential_match.id)
      end
    end

    def attach_previous_trip_update(feed_id, trip)
      marshaled_previous_update = RedisStore.active_trip(feed_id, trip.id)
      if marshaled_previous_update
        previous_update = Marshal.load(marshaled_previous_update)

        if trip.timestamp != previous_update.timestamp || (Time.current.to_i - previous_update.timestamp) >= 4.minutes.to_i
          trip.previous_trip = previous_update
          trip.previous_trip.previous_trip = nil
        else
          trip.previous_trip = trip.previous_trip&.previous_trip
          trip.latest = false
        end

        trip.is_assigned = trip.is_assigned || previous_update.is_assigned
        trip.schedule = previous_update.schedule if previous_update
        trip.past_stops = previous_update.past_stops if previous_update&.past_stops
      end
    end

    def update_trip(feed_id, timestamp, trip, pipeline)
      return unless trip.latest
      process_stops(trip, pipeline)
      marshaled_trip = Marshal.dump(trip)
      trip.time_between_stops(SUPPLEMENTED_TIME_LOOKUP).each do |station_ids, time|
        stop_ids = station_ids.split('-')
        RedisStore.add_supplemented_scheduled_travel_time(stop_ids.first, stop_ids.second, time, pipeline) if time >= 30
      end
      trip.upcoming_stops.each do |stop_id|
        RedisStore.add_route_to_route_stop(trip.route_id, stop_id, trip.direction, timestamp, pipeline)
      end
      trip.tracks.each do |stop_id, track|
        RedisStore.add_route_to_route_stop_track(trip.route_id, trip.direction, stop_id, track, timestamp, pipeline) if track.present?
      end
      RedisStore.add_active_trip(feed_id, trip.id, marshaled_trip, pipeline)
      RedisStore.add_to_active_trip_list(feed_id, trip.id, timestamp, pipeline)
    end

    def process_stops(trip, pipeline)
      if trip.previous_trip &&
        trip.is_assigned &&
        (trip.previous_trip.previous_stop_schedule_discrepancy >= SCHEDULE_DISCREPANCY_THRESHOLD ||
            trip.schedule_discrepancy - trip.previous_trip.previous_stop_schedule_discrepancy <= (SCHEDULE_DISCREPANCY_THRESHOLD * -1)
        )
        time_traveled_between_stops_made = trip.time_traveled_between_stops_made
        if time_traveled_between_stops_made.size < 3
          trip.time_traveled_between_stops_made.each do |stops_str, travel_time|
            if travel_time >= MIN_TRAVEL_TIME_BETWEEN_STOPS_TO_RECORD
              RedisStore.add_travel_time(stops_str, travel_time, trip.id, trip.timestamp, pipeline)
            end
          end
        end
      end
      trip.update_stops_made!
    end

    def complete_trips(feed_id, timestamp)
      active_trips_not_in_current_feed = RedisStore.active_trip_list(feed_id, timestamp, INACTIVE_TRIP_TIMEOUT).to_set
      active_trips_not_in_current_feed.each do |trip_id|
        marshaled_trip = RedisStore.active_trip(feed_id, trip_id)
        if marshaled_trip
          trip = Marshal.load(marshaled_trip)
          if trip.upcoming_stops.size < 2
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

              if b_stop_time > a_stop_time
                travel_time = b_stop_time - a_stop_time
                RedisStore.add_travel_time(stops_str, travel_time, trip.id, timestamp)
              end
            end
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

    def remove_closed_stops!(trip_update)
      trip_update.stop_time_update.filter! { |update| !CLOSED_STOPS.include?(update.stop_id) }
    end

    def remove_bad_data!(trip_update, timestamp)
      first_stop = trip_update.stop_time_update.select { |update| (update.departure&.time || update.arrival&.time || 0) > 0 }.sort_by { |update| update.departure&.time && update.departure.time > 0 ? update.departure.time : update.arrival&.time }.first
      first_stop_index = trip_update.stop_time_update.index(first_stop)
      trip_update.stop_time_update.filter! { |update| (update.departure&.time || update.arrival&.time || 0) > 0 && trip_update.stop_time_update.index(update) >= first_stop_index || (update.departure || update.arrival).time < (first_stop.departure || first_stop.arrival).time }
    end

    def correct_canal_st_stop!(trip_update, direction)
      direction_str = direction == Transit_realtime::NyctTripDescriptor::Direction::NORTH ? 'N' : 'S'
      if (canal_update = trip_update.stop_time_update.find { |update| update.stop_id[0..2] == CANAL_ST_BRIDGE_STOP })
        i = trip_update.stop_time_update.index(canal_update)
        city_hall_update = trip_update.stop_time_update.find { |update| update.stop_id[0..2] == CITY_HALL_STOP }
        return unless city_hall_update
        canal_update.stop_id = "#{CANAL_ST_TUNNEL_STOP}#{direction_str}"
      elsif (canal_update = trip_update.stop_time_update.find { |update| update.stop_id[0..2] == CANAL_ST_TUNNEL_STOP })
        i = trip_update.stop_time_update.index(canal_update)
        city_hall_update = trip_update.stop_time_update.find { |update| update.stop_id[0..2] == CITY_HALL_STOP }
        return if city_hall_update || (i == 0 && direction_str == 'N')
        canal_update.stop_id = "#{CANAL_ST_BRIDGE_STOP}#{direction_str}"
      end
    end

    def valid_stops
      @valid_stops ||= Scheduled::Stop.pluck(:internal_id).to_set
    end
  end
end