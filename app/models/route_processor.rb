class RouteProcessor
  RUNTIME_END_LIMIT = 30.minutes.to_i
  RUNTIME_START_LIMIT = 40.minutes.to_i

  class << self
    def process_route(route_id, trips, timestamp)
      puts "Processing route #{route_id} at #{Time.at(timestamp)}"

      trips_by_direction = trips.group_by(&:direction)

      routings = determine_routings(trips_by_direction)

      trips_by_routes = trips_by_direction.map { |direction, trips|
        [direction, routings[direction].map {|r|
          trips_selected = trips.select { |t|
            stops = t.stop_ids
            r.each_cons(stops.length).any?(&stops.method(:==))
          }
          [r, r.map {|s|
            trips.select { |t| t.upcoming_stop == s }.sort_by { |t| t.upcoming_stop_estimated_arrival_time }
          }.flatten.compact]
        }.to_h]
      }.to_h

      headway_by_routes = determine_actual_headway(trips_by_routes, timestamp)

      scheduled_trips = Scheduled::Trip.soon_grouped(timestamp, route_id)
      scheduled_routings = determine_scheduled_routings(scheduled_trips, timestamp, exclude_past_stops: true)

      # Reload to load all stops
      scheduled_trips.each do |_, trips|
        trips.each { |t| t.stop_times.reload }
      end
      recent_scheduled_routings = determine_scheduled_routings(scheduled_trips, timestamp)
      scheduled_headways_by_routes = determine_max_scheduled_headway(scheduled_trips, route_id, timestamp)

      REDIS_CLIENT.pipelined do
        update_scheduled_runtimes(scheduled_trips)
      end

      RouteAnalyzer.analyze_route(
        route_id,
        trips_by_routes,
        routings,
        headway_by_routes,
        timestamp,
        scheduled_trips,
        scheduled_routings,
        recent_scheduled_routings,
        scheduled_headways_by_routes
      )
    end

    def average_travel_time(a_stop, b_stop, timestamp)
      train_stops_at_b = RedisStore.trips_stopped_at(b_stop, timestamp + 1.minute.to_i, timestamp - RUNTIME_END_LIMIT)
      train_stops_at_a = RedisStore.trips_stopped_at(a_stop, timestamp + 1.minute.to_i, timestamp - RUNTIME_START_LIMIT)

      trains_stopped_at_a = train_stops_at_a.map(&:first)
      trains_traveled = train_stops_at_b.select{ |b_train, _| train_stops_at_a.find {|a_train, _| a_train == b_train } }.keys

      return RedisStore.supplementary_scheduled_travel_time(a_stop, b_stop) unless trains_traveled.present?

      trains_traveled.map { |train_id| train_stops_at_b[train_id] - train_stops_at_a[train_id] }.sum / trains_traveled.size
    end

    def determine_routings(trips_by_direction)
      trips_by_direction.map { |direction, t|
        [direction, determine_routings_for_direction(t)]
      }.to_h
    end

    def determine_routings_for_direction(trips)
      trips.map(&:stop_ids).reverse.inject([]) do |memo, stops_array|
        unless memo.any? { |array| (stops_array - array).empty? }
          memo << stops_array
        end
        memo
      end
    end

    def determine_actual_headway(trips_by_routes, timestamp)
      trips_by_routes.map { |direction, routes|
        headway_by_routes = routes.map { |r, trips|
          ["#{r.first}-#{r.last}-#{r.size}", trips.each_cons(2).map{ |a_trip, b_trip|
            time_between_trips(a_trip, b_trip, timestamp, r)
          }.filter { |v| v > 0 }]
        }.to_h

        if headway_by_routes.size > 1
          headway_by_routes['blended'] = determine_actual_blended_headway(routes.keys, routes.values.flatten, timestamp)
        end

        [direction, headway_by_routes]
      }.to_h
    end

    def determine_actual_blended_headway(routes, trips, timestamp)
      common_start = routes.first.find { |s| routes.all? { |r| r.include?(s) }}
      common_end = routes.first.reverse.find { |s| routes.all? { |r| r.include?(s) }}

      return unless common_start && common_end

      common_sub_route = routes.map { |r| r[r.index(common_start)..r.index(common_end)] }.sort_by(&:size).reverse.first
      trips_in_order = common_sub_route.map { |s| trips.find { |t| t.upcoming_stop == s }}.compact
      trips_in_order.each_cons(2).map{ |a_trip, b_trip|
        time_between_trips(a_trip, b_trip, timestamp, common_sub_route)
      }
    end

    def time_between_trips(a_trip, b_trip, timestamp, routing)
      if a_trip.stops_behind(b_trip).present?
        (time_until_upcoming_stop(a_trip, timestamp, routing) +
          a_trip.stops_behind(b_trip).each_cons(2).map { |a_stop, b_stop| average_travel_time(a_stop, b_stop, timestamp) }.sum -
          time_until_upcoming_stop(b_trip, timestamp, routing)) / 60
      else
        (time_until_upcoming_stop(b_trip, timestamp, routing) - time_until_upcoming_stop(a_trip, timestamp, routing)) / 60
      end
    end

    def time_until_upcoming_stop(trip, timestamp, routing)
      next_stop = trip.upcoming_stop
      i = routing.index(next_stop)
      return trip.time_until_upcoming_stop unless i && i > 0

      previous_stop = routing[i - 1]
      predicted_time_until_next_stop = trip.time_until_upcoming_stop
      predicted_time_between_stops = RedisStore.supplementary_scheduled_travel_time(previous_stop, next_stop)
      actual_time_between_stops = average_travel_time(previous_stop, next_stop, timestamp)

      (predicted_time_until_next_stop / predicted_time_between_stops) * actual_time_between_stops
    end

    def determine_max_scheduled_headway(scheduled_trips, route_id, timestamp)
       return [nil, nil] unless scheduled_trips.present?

       scheduled_trips.map do |direction, trips|
        routing_trips = trips.map { |t| t.stop_times }.group_by { |stop_times| "#{stop_times.first.stop_internal_id}-#{stop_times.last.stop_internal_id}-#{stop_times.size}" }

        headway_by_routing = routing_trips.map { |r, s| [r, determine_scheduled_routing_headway(s)] }.to_h

        if headway_by_routing.size > 1
          headway_by_routing['blended'] = determine_scheduled_blended_headway(trips)
        end

        [direction, headway_by_routing]
       end.to_h
    end

    def determine_scheduled_routing_headway(stop_time_arrays)
      departure_times = stop_time_arrays.map(&:last).map(&:departure_time)

      calculate_scheduled_headway(departure_times)
    end

    def determine_scheduled_blended_headway(trips)
      reverse_trip_stops = trips.map { |t| t.stop_times.pluck(:stop_internal_id).reverse }
      common_stop = reverse_trip_stops.first.find { |s| reverse_trip_stops.all? { |t| t.include?(s) } }
      departure_times = trips.map { |t| t.stop_times.find { |s| s.stop_internal_id == common_stop }}.map(&:departure_time)

      calculate_scheduled_headway(departure_times)
    end

    def calculate_scheduled_headway(departure_times)
      # This probably means departure times span across midnight
      d = departure_times.clone
      if (departure_times.max - departure_times.min) > 4.hours.to_i
        d = departure_times.map do |time|
          if time < 8.hours.to_i
            time + 24.hours.to_i
          else
            time
          end
        end
      end
      d.sort.each_cons(2).map { |a,b| (b - a) / 60 }
    end

    def update_scheduled_runtimes(scheduled_trips)
      scheduled_trips.each do |_, trips|
        trips.each do |t|
          t.stop_times.each_cons(2).each do |a_st, b_st|
            time = b_st.departure_time - a_st.departure_time
            RedisStore.add_scheduled_travel_time(a_st.stop_internal_id, b_st.stop_internal_id, time)
          end
        end
      end
    end

    def determine_scheduled_routings(scheduled_trips, timestamp, exclude_past_stops: false)
      scheduled_trips.map { |direction, trips|
        potential_routings = trips.map { |t|
          exclude_past_stops ? t.stop_times.not_past.pluck(:stop_internal_id) : t.stop_times.pluck(:stop_internal_id)
        }.uniq
        result = potential_routings.select { |selected_routing|
          others = potential_routings - [selected_routing]
          selected_routing.length > 0 && others.none? {|o| o.each_cons(selected_routing.length).any?(&selected_routing.method(:==))}
        }
        [direction,  result]
      }.to_h
    end

    handle_asynchronously :process_route, priority: 1
  end
end