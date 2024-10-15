class RouteAnalyzer
  SLOW_SECTION_STATIONS_RANGE = 3..7

  def self.analyze_route(route_id, processed_trips, actual_routings, common_routings, timestamp, scheduled_trips, scheduled_routings, recent_scheduled_routings, scheduled_headways_by_routes, routes_with_shared_tracks)
    stop_name_formatter = StopNameFormatter.new(actual_routings, scheduled_routings)
    travel_times_data = RedisStore.travel_times
    travel_times = travel_times_data ? Marshal.load(travel_times_data) : {}
    changes = ServiceChangeAnalyzer.service_change_summary(route_id, actual_routings.to_h { |direction, routings|
      [direction, routings.filter { |r|
        processed_trips[direction]["#{r.first}-#{r.last}-#{r.size}"]&.any? { |t| !t.is_phantom? } || processed_trips[direction]["#{r.first}-#{r.last}-#{r.size}"]&.size > 1
      }.presence || routings]
    }, scheduled_routings, recent_scheduled_routings, timestamp)
    max_delayed_time = max_delay(processed_trips)
    slow_sections = identify_slow_sections(actual_routings, travel_times, timestamp)
    long_headway_sections = identify_long_headway_sections(scheduled_headways_by_routes, actual_routings, common_routings, processed_trips, travel_times)
    delayed_sections = identify_delayed_sections(actual_routings, common_routings, processed_trips)
    scheduled_runtimes = calculate_scheduled_runtimes(actual_routings, timestamp)
    estimated_runtimes = calculate_estimated_runtimes(actual_routings, travel_times, timestamp)
    runtime_diffs = calculate_runtime_diff(scheduled_runtimes, estimated_runtimes)
    overall_runtime_diffs = overall_runtime_diff(scheduled_runtimes, estimated_runtimes)
    headway_discrepancy = max_headway_discrepancy(processed_trips, scheduled_headways_by_routes)
    direction_statuses, status = route_status(max_delayed_time, overall_runtime_diffs, slow_sections, long_headway_sections, changes, processed_trips, scheduled_trips)
    destination_station_names = destinations(route_id, scheduled_trips, actual_routings, stop_name_formatter)
    converted_destination_station_names = convert_to_readable_directions(destination_station_names)
    irregularity_summaries = service_irregularity_summaries(overall_runtime_diffs, slow_sections, long_headway_sections, destination_station_names, processed_trips, scheduled_headways_by_routes, stop_name_formatter)
    irregularities = service_irregularities(overall_runtime_diffs, slow_sections, long_headway_sections, destination_station_names, processed_trips, scheduled_headways_by_routes, stop_name_formatter)
    delay_summaries = delay_summaries(max_delayed_time, delayed_sections, destination_station_names, processed_trips, stop_name_formatter)
    delays = determine_delays(max_delayed_time, delayed_sections, destination_station_names, processed_trips, stop_name_formatter)
    additional_trips = append_additional_trips(route_id, processed_trips, actual_routings, common_routings, routes_with_shared_tracks)

    summary = {
      status: status,
      timestamp: timestamp,
    }.to_json

    detailed_summary = {
      status: status,
      direction_statuses: convert_to_readable_directions(direction_statuses),
      delay_summaries: convert_to_readable_directions(delay_summaries),
      delays: convert_to_readable_directions(delays),
      service_change_summaries: service_change_summaries(route_id, changes, converted_destination_station_names, stop_name_formatter),
      service_changes: service_changes(route_id, changes, converted_destination_station_names, stop_name_formatter),
      service_irregularity_summaries: convert_to_readable_directions(irregularity_summaries),
      service_irregularities: convert_to_readable_directions(irregularities),
      actual_routings: convert_to_readable_directions(sort_actual_routings(route_id, actual_routings, scheduled_routings)),
      scheduled_routings: convert_scheduled_to_readable_directions(scheduled_routings),
      slow_sections: convert_to_readable_directions(slow_sections),
      long_headway_sections: convert_to_readable_directions(long_headway_sections),
      delayed_sections: convert_to_readable_directions(delayed_sections),
      routes_with_shared_tracks: convert_to_readable_directions(routes_with_shared_tracks),
      routes_with_shared_tracks_summary: summarize_routes_with_shared_tracks(routes_with_shared_tracks),
      trips: convert_to_readable_directions(format_trips_with_upcoming_stop_times(processed_trips, travel_times)),
      additional_trips_on_shared_tracks: additional_trips_to_array(additional_trips, route_id),
      timestamp: timestamp,
    }.to_json

    detailed_stats = {
      status: status,
      direction_statuses: convert_to_readable_directions(direction_statuses),
      delay_summaries: convert_to_readable_directions(delay_summaries),
      delays: convert_to_readable_directions(delays),
      service_change_summaries: service_change_summaries(route_id, changes, converted_destination_station_names, stop_name_formatter),
      service_changes: service_changes(route_id, changes, converted_destination_station_names, stop_name_formatter),
      service_irregularity_summaries: convert_to_readable_directions(irregularity_summaries),
      service_irregularities: convert_to_readable_directions(irregularities),
      destinations: converted_destination_station_names,
      max_delay: convert_to_readable_directions(max_delayed_time),
      slow_sections: convert_to_readable_directions(slow_sections),
      long_headway_sections: convert_to_readable_directions(long_headway_sections),
      delayed_sections: convert_to_readable_directions(delayed_sections),
      scheduled_runtimes: convert_to_readable_directions(scheduled_runtimes),
      estimated_runtimes: convert_to_readable_directions(estimated_runtimes),
      runtime_diffs: convert_to_readable_directions(runtime_diffs),
      overall_runtime_diff: convert_to_readable_directions(overall_runtime_diffs),
      max_headway_discrepancy: convert_to_readable_directions(headway_discrepancy),
      scheduled_headways: convert_scheduled_to_readable_directions(scheduled_headways_by_routes),
      actual_routings: convert_to_readable_directions(sort_actual_routings(route_id, actual_routings, scheduled_routings)),
      common_routings: convert_to_readable_directions(common_routings),
      scheduled_routings: convert_scheduled_to_readable_directions(scheduled_routings),
      routes_with_shared_tracks: convert_to_readable_directions(routes_with_shared_tracks),
      trips: convert_to_readable_directions(format_processed_trips(processed_trips, route_id)),
      trips_including_other_routes_on_shared_tracks: convert_to_readable_directions(format_processed_trips(additional_trips, route_id)),
      timestamp: timestamp,
    }.to_json

    REDIS_CLIENT.pipelined do |pipeline|
      RedisStore.add_route_status_summary(route_id, summary, pipeline)
      RedisStore.add_route_status_detailed_summary(route_id, detailed_summary, pipeline)
      RedisStore.update_route_status(route_id, detailed_stats, pipeline)
    end
  end

  def self.convert_to_readable_directions(hash)
    hash.map { |direction, data| [direction == 3 ? :south : :north, data] }.to_h
  end

  def self.convert_scheduled_to_readable_directions(hash)
    hash.map { |direction, data| [direction == 1 ? :south : :north, data] }.to_h
  end

  private

  def self.route_status(delays, runtime_diff, slow_sections, long_headway_sections, changes, actual_trips, scheduled_trips)
    direction_statuses = [1, 3].map { |direction|
      direction_key = direction == 3 ? :south : :north
      scheduled_key = direction == 3 ? 1 : 0
      status = 'Good Service'
      if !actual_trips[direction]
        if !scheduled_trips[scheduled_key]
          status = 'Not Scheduled'
        else
          status = 'No Service'
        end
      elsif delays[direction] && delays[direction] >= Processed::Trip::DELAY_THRESHOLD
        status = 'Delay'
      elsif changes[direction_key]&.select(&:not_long_term?).present? || changes[:both]&.select(&:not_long_term?).present?
        status = 'Service Change'
      elsif (runtime_diff[direction] && runtime_diff[direction] >= 300) || slow_sections[direction].present?
        status = 'Slow'
      elsif long_headway_sections[direction].present?
        status = 'Not Good'
      end
      [direction, status]
    }.to_h
    status = ['Delay', 'Service Change', 'Slow', 'Not Good', 'No Service', 'Good Service', 'Not Scheduled'].find { |s| direction_statuses.any? { |_, status| s == status } }
    if status == 'No Service' && direction_statuses.any? { |_, s| !['No Service', 'Not Scheduled'].include?(s) }
      status = 'Partial Service'
    end

    return direction_statuses, status
  end

  def self.service_irregularity_summaries(runtime_diff, slow_sections, long_headway_sections, destination_stations, actual_trips, scheduled_headways_by_routes, stop_name_formatter)
    direction_statuses = [ServiceChangeAnalyzer::NORTH, ServiceChangeAnalyzer::SOUTH].map { |direction|
      next [direction[:route_direction], nil] unless actual_trips[direction[:route_direction]]
      strs = []
      intro = "#{destination_stations[direction[:route_direction]].sort.join('/')}-bound trains are "

      if slow_sections[direction[:route_direction]].present?
        slow_strs = slow_sections[direction[:route_direction]].map do |s|
           "#{(s[:runtime_diff] / 60.0).round} mins longer to travel between #{stop_name_formatter.stop_name(s[:begin])} and #{stop_name_formatter.stop_name(s[:end])}"
        end
        slow_strs[0] = "taking #{slow_strs[0]}"
        strs << slow_strs.join(", ")
      elsif runtime_diff[direction[:route_direction]] && runtime_diff[direction[:route_direction]] >= 300
        strs << "taking #{(runtime_diff[direction[:route_direction]] / 60.0).round} mins longer to travel per trip"
      end

      if long_headway_sections[direction[:route_direction]].present?
        first_stop = long_headway_sections[direction[:route_direction]].first[:begin]
        last_stop = long_headway_sections[direction[:route_direction]].last[:end]
        max_actual = (long_headway_sections[direction[:route_direction]].map { |s| s[:max_actual_headway] }.max / 60.0).round
        max_scheduled = (long_headway_sections[direction[:route_direction]].first[:max_scheduled_headway] / 60.0).round
        if first_stop == last_stop
          strs << "having longer wait times at #{stop_name_formatter.stop_name(first_stop)} (up to #{max_actual} mins, normally every #{max_scheduled} mins)"
        else
          strs << "having longer wait times between #{stop_name_formatter.stop_name(first_stop)} and #{stop_name_formatter.stop_name(last_stop)} (up to #{max_actual} mins, normally every #{max_scheduled} mins)"
        end
      end

      next [direction[:route_direction], nil] unless strs.present?

      [direction[:route_direction], "#{intro}#{strs.to_sentence(two_words_connector: ", and ")}."]
    }.to_h
  end

  def self.service_irregularities(runtime_diff, slow_sections, long_headway_sections, destination_stations, actual_trips, scheduled_headways_by_routes, stop_name_formatter)
    direction_statuses = [ServiceChangeAnalyzer::NORTH, ServiceChangeAnalyzer::SOUTH].map { |direction|
      next [direction[:route_direction], []] unless actual_trips[direction[:route_direction]]
      results = []
      intro = "#{destination_stations[direction[:route_direction]].sort.join('/')}-bound trains are "

      if slow_sections[direction[:route_direction]].present?
        slow_strs = slow_sections[direction[:route_direction]].map do |s|
           "#{(s[:runtime_diff] / 60.0).round} mins longer to travel between #{stop_name_formatter.stop_name(s[:begin])} and #{stop_name_formatter.stop_name(s[:end])}"
        end
        slow_strs[0] = "taking #{slow_strs[0]}"
        results << {
          type: "Slow",
          description: intro + slow_strs.join(", ") + ".",
          stations_affected: slow_sections[direction[:route_direction]].flat_map { |s| s[:stops] },
        }
      elsif runtime_diff[direction[:route_direction]] && runtime_diff[direction[:route_direction]] >= 300
        results << {
          type: "Slow",
          description: intro + "taking #{(runtime_diff[direction[:route_direction]] / 60.0).round} mins longer to travel per trip.",
          stations_affected: nil,
        }
      end

      if long_headway_sections[direction[:route_direction]].present?
        first_stop = long_headway_sections[direction[:route_direction]].first[:begin]
        last_stop = long_headway_sections[direction[:route_direction]].last[:end]
        max_actual = (long_headway_sections[direction[:route_direction]].map { |s| s[:max_actual_headway] }.max / 60.0).round
        max_scheduled = (long_headway_sections[direction[:route_direction]].first[:max_scheduled_headway] / 60.0).round
        if first_stop == last_stop
          results << {
            type: "LongHeadway",
            description: intro + "having longer wait times at #{stop_name_formatter.stop_name(first_stop)} (up to #{max_actual} mins, normally every #{max_scheduled} mins).",
            stations_affected: [first_stop],
          }
        else
          results << {
            type: "LongHeadway",
            description: intro + "having longer wait times between #{stop_name_formatter.stop_name(first_stop)} and #{stop_name_formatter.stop_name(last_stop)} (up to #{max_actual} mins, normally every #{max_scheduled} mins).",
            # Not actually accurate, but we're not using it right now, so we don't care.
            stations_affected: [first_stop, last_stop],
          }
        end
      end

      [direction[:route_direction], results]
    }.to_h
  end

  def self.delay_summaries(delays, delayed_sections, destination_stations, actual_trips, stop_name_formatter)
    direction_statuses = [ServiceChangeAnalyzer::NORTH, ServiceChangeAnalyzer::SOUTH].map { |direction|
      next [direction[:route_direction], nil] unless actual_trips[direction[:route_direction]]
      str = nil
      intro = "#{destination_stations[direction[:route_direction]].sort.join('/')}-bound trains are "

      if delayed_sections[direction[:route_direction]].present?
        first_stop = delayed_sections[direction[:route_direction]].first[:begin]
        last_stop = delayed_sections[direction[:route_direction]].last[:end]
        max_delay_mins = (delayed_sections[direction[:route_direction]].map { |s| s[:delayed_time] }.max / 60.0).round
        if first_stop == last_stop
          str = "delayed at #{stop_name_formatter.stop_name(first_stop)} (since #{max_delay_mins} mins ago)"
        else
          str = "delayed between #{stop_name_formatter.stop_name(first_stop)} and #{stop_name_formatter.stop_name(last_stop)} (since #{max_delay_mins} mins ago)"
        end
      end

      next [direction[:route_direction], nil] unless str.present?

      [direction[:route_direction], "#{intro}#{str}."]
    }.to_h
  end

  def self.determine_delays(delays, delayed_sections, destination_stations, actual_trips, stop_name_formatter)
    direction_statuses = [ServiceChangeAnalyzer::NORTH, ServiceChangeAnalyzer::SOUTH].map { |direction|
      next [direction[:route_direction], nil] unless actual_trips[direction[:route_direction]]
      str = nil
      intro = "#{destination_stations[direction[:route_direction]].sort.join('/')}-bound trains are "

      if delayed_sections[direction[:route_direction]].present?
        first_stop = delayed_sections[direction[:route_direction]].first[:begin]
        last_stop = delayed_sections[direction[:route_direction]].last[:end]
        max_delay_mins = (delayed_sections[direction[:route_direction]].map { |s| s[:delayed_time] }.max / 60.0).round
        if first_stop == last_stop
          str = "delayed at #{stop_name_formatter.stop_name(first_stop)} (since #{max_delay_mins} mins ago)"
        else
          str = "delayed between #{stop_name_formatter.stop_name(first_stop)} and #{stop_name_formatter.stop_name(last_stop)} (since #{max_delay_mins} mins ago)"
        end
      end

      next [direction[:route_direction], nil] unless str.present?

      [direction[:route_direction], {
        description: "#{intro}#{str}.",
        stations_affected: [first_stop, last_stop], # Not exactly accurate, but good enough for now.
      }]
    }.to_h
  end

  def self.convert_scheduled_to_readable_directions(hash)
    hash.map { |direction, data| [direction == 1 ? :south : :north, data] }.to_h
  end

  def self.max_headway_discrepancy(processed_trips, scheduled_headways_by_routes)
    [ServiceChangeAnalyzer::NORTH, ServiceChangeAnalyzer::SOUTH].map { |direction|
      next [direction, nil] unless processed_trips[direction[:route_direction]]
      actual_headways_by_routes = processed_trips[direction[:route_direction]].map { |r, trips|
        [r, trips.map(&:estimated_time_behind_next_train).compact]
      }.to_h
      actual_headway = determine_headway_to_use(actual_headways_by_routes)&.max
      scheduled_headway = determine_headway_to_use(scheduled_headways_by_routes[direction[:scheduled_direction]])&.max
      diff = scheduled_headway && actual_headway ? actual_headway - scheduled_headway : 0
      [direction[:route_direction], [diff, 0].max]
    }.to_h
  end

  def self.determine_headway_to_use(headway_by_routes)
    if headway_by_routes && headway_by_routes.size > 1
      routing_with_most_headways = headway_by_routes.except('blended').max_by { |_, h| h.size }

      if headway_by_routes['blended']
        actual_headway = headway_by_routes['blended']
      else
        actual_headway = routing_with_most_headways.last
      end
    else
      headway_by_routes&.values&.first
    end
  end

  def self.calculate_scheduled_runtimes(actual_routings, timestamp)
    actual_routings.to_h do |direction, routings|
      [direction, routings.to_h { |r|
        scheduled_times = RouteProcessor.batch_scheduled_travel_time(r)
        key = "#{r.first}-#{r.last}-#{r.size}"
        [key, r.each_cons(2).map { |a_stop, b_stop|
          station_ids = "#{a_stop}-#{b_stop}"
          scheduled_times[station_ids]&.to_i || RedisStore.supplemented_scheduled_travel_time(a_stop, b_stop) || 0
        }.reduce(&:+) || 0]
      }]
    end
  end

  def self.calculate_estimated_runtimes(actual_routings, travel_times, timestamp)
    actual_routings.to_h do |direction, routings|
      [direction, routings.to_h { |r|
        ["#{r.first}-#{r.last}-#{r.size}", r.each_cons(2).map { |a_stop, b_stop|
          station_ids = "#{a_stop}-#{b_stop}"
          travel_times[station_ids]&.to_i || RedisStore.supplemented_scheduled_travel_time(a_stop, b_stop) || 0
        }.reduce(&:+) || 0]
      }]
    end
  end

  def self.calculate_runtime_diff(scheduled_runtimes, estimated_runtimes)
    scheduled_runtimes.to_h do |direction, runtimes_by_routing|
      [direction, runtimes_by_routing.to_h {|routing, scheduled_runtime|
        [routing, estimated_runtimes[direction][routing] - scheduled_runtime]
      }]
    end
  end

  def self.overall_runtime_diff(scheduled_runtimes, estimated_runtimes)
    scheduled_runtimes.to_h do |direction, runtimes_by_routing|
      [direction, runtimes_by_routing.map {|routing, scheduled_runtime|
        estimated_runtimes[direction][routing] - scheduled_runtime
      }.max]
    end
  end

  def self.identify_slow_sections(actual_routings, travel_times, timestamp)
    actual_routings.to_h do |direction, routings|
      objs = routings.flat_map { |r|
        scheduled_times = RouteProcessor.batch_scheduled_travel_time(r)
        SLOW_SECTION_STATIONS_RANGE.map { |n|
          r.each_cons(n).map { |array|
            runtime_diff = array.each_cons(2).map { |a_stop, b_stop|
              station_ids = "#{a_stop}-#{b_stop}"
              scheduled_travel_time = scheduled_times[station_ids]&.to_i || RedisStore.supplemented_scheduled_travel_time(a_stop, b_stop) || 0
              actual_travel_time = travel_times[station_ids]&.to_i || RedisStore.supplemented_scheduled_travel_time(a_stop, b_stop) || 0
              actual_travel_time - scheduled_travel_time
            }.reduce(&:+) || 0

            {
              stops: array,
              runtime_diff: runtime_diff
            }
          }.select { |obj| obj[:runtime_diff] >= 300}
        }
      }.flatten.compact.sort_by { |obj| -obj[:runtime_diff] }
      [direction, objs.select.with_index { |obj, i| i == 0 || obj[:stops].none? { |s| objs[0...i].any? { |o| o[:stops].include?(s) }}}.map { |o|
        {
          begin: o[:stops].first,
          end: o[:stops].last,
          stops: o[:stops],
          runtime_diff: o[:runtime_diff],
        }
      }]
    end
  end

  def self.identify_long_headway_sections(scheduled_headways_by_routes, actual_routings, common_routings, actual_trips, travel_times)
    direction_statuses = [ServiceChangeAnalyzer::NORTH, ServiceChangeAnalyzer::SOUTH].to_h do |direction|
      next [direction[:route_direction], nil] unless actual_trips[direction[:route_direction]]
      max_scheduled_headway = determine_headway_to_use(scheduled_headways_by_routes[direction[:scheduled_direction]])&.max
      next [direction[:route_direction], nil] unless max_scheduled_headway
      processed_trips = actual_trips[direction[:route_direction]].first&.last
      next [direction[:route_direction], nil] unless processed_trips
      routing = actual_routings[direction[:route_direction]].first

      if actual_trips[direction[:route_direction]].size > 1
        routing_with_most_trips = actual_trips[direction[:route_direction]].max_by { |_, trips| trips.size }
        processed_trips = routing_with_most_trips.last
        routing = actual_routings[direction[:route_direction]].find { |r| "#{r.first}-#{r.last}-#{r.size}" == routing_with_most_trips.first }

        if actual_trips[direction[:route_direction]]['blended']
          processed_trips = actual_trips[direction[:route_direction]]['blended']
          routing = common_routings[direction[:route_direction]]
        end
      end

      trips_with_long_headways = processed_trips.select do |trip|
        if trip.estimated_time_behind_next_train
          if trip.past_stops.empty? && trip.upcoming_stop != routing.first
            false
          else
            (trip.estimated_time_behind_next_train - max_scheduled_headway) >= 120
          end
        else
          # If there's no train ahead, we check to see if the end of the line has a long wait
          routing.last == trip.destination && (trip.estimated_time_until_destination - max_scheduled_headway) >= 120
        end
      end
      objs = trips_with_long_headways.map do |trip|
        stop_count = 0
        begin_stop = trip.upcoming_stop
        time_until_begin_stop = trip.estimated_upcoming_stop_arrival_time - trip.timestamp
        while time_until_begin_stop <= max_scheduled_headway
          stop_count += 1
          begin_stop = trip.upcoming_stops[stop_count]
          if !begin_stop
            begin_stop = trip.upcoming_stops[stop_count - 1]
            break
          end
          key = "#{trip.upcoming_stops[stop_count - 1]}-#{trip.upcoming_stops[stop_count]}"
          time_until_begin_stop += travel_times[key] || (trip.stops[trip.upcoming_stops[stop_count]] - trip.stops[trip.upcoming_stops[stop_count - 1]])
        end
        i = processed_trips.index(trip)
        next_trip = processed_trips[i + 1]
        if next_trip
          j = routing.index(next_trip.upcoming_stop)
          next_trip_prev_stop = j > 0 ? routing[j - 1] : routing[0]
        else
          # If there's no train ahead, then the identified section ends at the end of the line
          next_trip_prev_stop = routing.last
        end
        {
          begin: begin_stop,
          end: next_trip_prev_stop,
          max_actual_headway: trip.estimated_time_behind_next_train || trip.estimated_time_until_destination,
          max_scheduled_headway: max_scheduled_headway,
        }
      end

      [direction[:route_direction], objs]
    end
  end

  def self.identify_delayed_sections(actual_routings, common_routings, actual_trips)
    [1, 3].to_h do |direction|
      delayed_trips = actual_trips[direction]&.flat_map { |r_key, trips|
        routing = r_key == 'blended' ? common_routings[direction] : actual_routings[direction].find { |r| "#{r.first}-#{r.last}-#{r.size}" == r_key }
        results = trips.each_with_index.map { |t, i|
          next_trip = trips[i + 1]
          # There may not be any trips ahead of this trip
          next_trip_prev_stop = routing.last
          if next_trip
            j = routing.index(next_trip.upcoming_stop)
            next_trip_prev_stop = j && j > 0 ? routing[j - 1] : routing[0]
          end
          {
            begin: t.upcoming_stop,
            end: next_trip_prev_stop,
            delayed_time: t.effective_delayed_time
          }
        }.select { |t| t[:delayed_time] >= Processed::Trip::DELAY_THRESHOLD }
        if results.uniq { |t| t[:end] }.size == 1 && results.first[:begin] == routing.last && results.first[:end] == routing.last
          []
        else
          results
        end
      }&.uniq { |t| t[:end] }
      [direction, delayed_trips]
    end
  end

  def self.accumulated_extra_time_between_stops(actual_routings, processed_trips, timestamp)
    actual_routings.map { |direction, routings|
      [direction, routings.map { |r|
        key = "#{r.first}-#{r.last}-#{r.size}"
        trips = processed_trips[direction][key]
        (
          r.each_cons(2).map { |a_stop, b_stop|
            scheduled_travel_time = RedisStore.scheduled_travel_time(a_stop, b_stop) || RedisStore.supplemented_scheduled_travel_time(a_stop, b_stop) || 0
            actual_travel_time = RouteProcessor.average_travel_time(a_stop, b_stop) || 0
            diff = actual_travel_time - scheduled_travel_time
            diff >= 60.0 ? diff : 0
          }.reduce(&:+) || 0
        )
      }.max]
    }.to_h
  end

  def self.max_delay(actual_trips)
    actual_trips.map { |direction, trips|
      [direction, trips.values.flatten.select{ |t| t.upcoming_stops.size > 1 }.map(&:effective_delayed_time).max]
    }.to_h
  end

  def self.service_change_summaries(route_id, service_changes_by_directions, destination_stations, stop_name_formatter)
    service_changes_by_directions.map { |direction, changes|
      next [direction, []] unless changes
      destination_names = destination_stations[direction]&.sort&.join('/')

      changes.select! { |s| !s.is_a?(ServiceChanges::NotScheduledServiceChange)}

      notices = []

      case direction
      when :both
        sentence_intro = "<#{route_id}> trains are"
        begin_preposition = 'to/from'
        end_preposition = 'to/from'
      else
        sentence_intro = "#{destination_names}-bound trains are"
        begin_preposition = 'from'
        end_preposition = 'to'
      end

      if changes.any? { |c| c.is_a?(ServiceChanges::NoTrainServiceChange) }
        next [direction, ["#{sentence_intro} not running."]]
      end

      begin_of_route = changes.find(&:begin_of_route?)
      end_of_route = changes.find(&:end_of_route?)

      if begin_of_route || end_of_route
        if direction != :both && begin_of_route.present? && end_of_route.nil?
          sentence = (changes.any?(&:affects_some_trains) ? 'Some ' : '') + "#{begin_of_route.destinations.map { |d| stop_name_formatter.brief_stop_name(d) }.sort.join('/')}-bound trains are running"
        elsif direction != :both && end_of_route.present?
          sentence = (changes.any?(&:affects_some_trains) ? 'Some ' : '') + "#{end_of_route.destinations.map { |d| stop_name_formatter.brief_stop_name(d) }.sort.join('/')}-bound trains are running"
        else
          if direction == :both
            sentence = (changes.any?(&:affects_some_trains) ? 'Some ' : '') + sentence_intro + " running"
          else
            sentence = (changes.any?(&:affects_some_trains) ? 'Some ' : '') + "#{changes.map(&:destinations).flatten.uniq.map { |d| stop_name_formatter.brief_stop_name(d) }.sort.join('/')}-bound trains are running"
          end
        end
        if end_of_route.present? && direction != :both
          sentence = (changes.any?(&:affects_some_trains) ? 'Some ' : '') + "#{end_of_route.destinations.map { |d| stop_name_formatter.brief_stop_name(d) }.sort.join('/')}-bound trains are running"
        end

        if begin_of_route&.is_a?(ServiceChanges::ReroutingServiceChange)
          if begin_of_route.related_routes.present? && !begin_of_route.related_routes.include?(route_id)
            if begin_of_route == end_of_route
              if begin_of_route.first_station == begin_of_route.last_station
                sentence += " via #{begin_of_route.related_routes.map { |r| "<#{r}>" }.join(' and ')} to"
              else
                sentence += " via #{begin_of_route.related_routes.map { |r| "<#{r}>" }.join(' and ')} between #{stop_name_formatter.stop_name(begin_of_route.first_station)} and"
              end
            else
              sentence += " #{begin_preposition} #{stop_name_formatter.stop_name(begin_of_route.first_station)} via #{begin_of_route.related_routes.map { |r| "<#{r}>" }.join(' and ')}, and between #{stop_name_formatter.stop_name(begin_of_route.last_station)} and"
            end
          else
            sentence += " between #{stop_name_formatter.stop_name(begin_of_route.first_station)} and"
          end
        elsif begin_of_route&.is_a?(ServiceChanges::TruncatedServiceChange)
          sentence += " between #{stop_name_formatter.stop_name(begin_of_route.last_station)} and"
        elsif end_of_route
          sentence += " between #{stop_name_formatter.stop_name(end_of_route.origin)} and"
        end

        if end_of_route&.is_a?(ServiceChanges::ReroutingServiceChange)
          if end_of_route.related_routes.present? && begin_of_route != end_of_route && !end_of_route.related_routes.include?(route_id)
            sentence += " #{stop_name_formatter.stop_name(end_of_route.first_station)}, via  #{end_of_route.related_routes.map { |r| "<#{r}>" }.join(' and ')} #{end_preposition} #{stop_name_formatter.stop_name(end_of_route.last_station)}."
          else
            sentence += " #{stop_name_formatter.stop_name(end_of_route.last_station)}."
          end
        elsif end_of_route&.is_a?(ServiceChanges::TruncatedServiceChange)
          sentence += " #{stop_name_formatter.stop_name(end_of_route.first_station)}."
        elsif begin_of_route
          sentence += " #{begin_of_route.destinations.map { |d| stop_name_formatter.stop_name(d) }.sort.join('/')}."
        end

        notices << sentence
      end

      split_route_changes = changes.find { |c| c.is_a?(ServiceChanges::SplitRoutingServiceChange)}

      if split_route_changes.present?
        split_routes = split_route_changes.routing_tuples.map.with_index { |rt, i|
          if rt.first == rt.last
            "at #{stop_name_formatter.stop_name(rt.first)}"
          else
            if related_routes = split_route_changes.related_routes_by_segments[i]
              "between #{stop_name_formatter.stop_name(rt.first)} and #{stop_name_formatter.stop_name(rt.last)} via #{related_routes.map { |r| "<#{r}>" }.join(' and ')}"
            else
              "between #{stop_name_formatter.stop_name(rt.first)} and #{stop_name_formatter.stop_name(rt.last)}"
            end
          end
        }.to_sentence(two_words_connector: ", and ")
        notices << sentence_intro + " running in #{split_route_changes.routing_tuples.size} sections: #{split_routes}."
      end

      changes.select { |c| c.is_a?(ServiceChanges::ReroutingServiceChange) && !c.begin_of_route? && !c.end_of_route?}.each do |change|
        if direction == :both
            sentence = (change.affects_some_trains ? 'Some ' : '') + sentence_intro + " running"
          else
            sentence = (changes.any?(&:affects_some_trains) ? 'Some ' : '') + "#{change.destinations.uniq.map { |d| stop_name_formatter.brief_stop_name(d) }.sort.join('/')}-bound trains are running"
          end
        if change.related_routes.present?
          if change.related_routes.include?(route_id)
            sentence += " between #{stop_name_formatter.stop_name(change.first_station)} and #{stop_name_formatter.stop_name(change.last_station)}."
          else
            sentence += " via #{change.related_routes.map { |r| "<#{r}>" }.join(' and ')} between #{stop_name_formatter.stop_name(change.first_station)} and #{stop_name_formatter.stop_name(change.last_station)}."
          end
        else
          sentence += " via #{change.intermediate_stations.map { |s| stop_name_formatter.stop_name(s) }.join(', ') } between #{stop_name_formatter.stop_name(change.first_station)} and #{stop_name_formatter.stop_name(change.last_station)}."
        end
        notices << sentence
      end

      local_to_express = changes.select { |c| c.is_a?(ServiceChanges::LocalToExpressServiceChange)}

      if local_to_express.present?
        skipped_stops = local_to_express.flat_map { |c| c.intermediate_stations }.map { |s| stop_name_formatter.stop_name(s) }
        if skipped_stops.length > 1
          skipped_stops_text = "#{skipped_stops[0...-1].join(', ')}, and #{skipped_stops.last}"
        else
          skipped_stops_text = skipped_stops.first
        end
        if direction == :both
          sentence = (local_to_express.any?(&:affects_some_trains) ? 'Some ' : '') + sentence_intro + " skipping #{skipped_stops_text}."
        else
          sentence = (local_to_express.any?(&:affects_some_trains) ? 'Some ' : '') + "#{local_to_express.map(&:destinations).flatten.uniq.map { |d| stop_name_formatter.brief_stop_name(d) }.sort.join('/')}-bound trains are skipping #{skipped_stops_text}."
        end
        notices << sentence
      end

      changes.select { |c| c.is_a?(ServiceChanges::ExpressToLocalServiceChange)}.each do |change|
        if direction == :both
          if ServiceChangeAnalyzer::CANAL_TO_ATLANTIC_VIA_BRIDGE_WITH_DEKALB_BOTH_DIRS.include?(change.stations_affected)
            sentence = (change.affects_some_trains ? 'Some ' : '') + sentence_intro + " stopping at #{stop_name_formatter.stop_name(ServiceChangeAnalyzer::DEKALB_AV_STOP)}."
          else
            sentence = (change.affects_some_trains ? 'Some ' : '') + sentence_intro + " making local stops between #{stop_name_formatter.stop_name(change.first_station)} and #{stop_name_formatter.stop_name(change.last_station)}."
          end
        else
          if ServiceChangeAnalyzer::CANAL_TO_ATLANTIC_VIA_BRIDGE_WITH_DEKALB_BOTH_DIRS.include?(change.stations_affected)
            sentence = (change.affects_some_trains ? 'Some ' : '') + "#{change.destinations.uniq.map { |d| stop_name_formatter.stop_name(d) }.sort.join('/')}-bound trains are stopping at #{stop_name_formatter.stop_name(ServiceChangeAnalyzer::DEKALB_AV_STOP)}."
          else
            sentence = (change.affects_some_trains ? 'Some ' : '') + "#{change.destinations.uniq.map { |d| stop_name_formatter.stop_name(d) }.sort.join('/')}-bound trains are making local stops between #{stop_name_formatter.stop_name(change.first_station)} and #{stop_name_formatter.stop_name(change.last_station)}."
          end
        end
        notices << sentence
      end

      [direction, notices]
    }.to_h
  end

  def self.service_changes(route_id, service_changes_by_directions, destination_stations, stop_name_formatter)
    service_changes_by_directions.map { |direction, changes|
      next [direction, []] unless changes
      destination_names = destination_stations[direction]&.sort&.join('/')

      changes.select! { |s| !s.is_a?(ServiceChanges::NotScheduledServiceChange)}

      results = []

      case direction
      when :both
        sentence_intro = "<#{route_id}> trains are"
        begin_preposition = 'to/from'
        end_preposition = 'to/from'
      else
        sentence_intro = "#{destination_names}-bound trains are"
        begin_preposition = 'from'
        end_preposition = 'to'
      end

      if changes.any? { |c| c.is_a?(ServiceChanges::NoTrainServiceChange) }
        next [direction, [{
          types: [ServiceChanges::NoTrainServiceChange.name.demodulize],
          description: "#{sentence_intro} not running.",
          stations_affected: nil,
          is_long_term: changes.all? { |c| c.long_term? },
        }]]
      end

      begin_of_route = changes.find(&:begin_of_route?)
      end_of_route = changes.find(&:end_of_route?)

      if begin_of_route || end_of_route
        if direction != :both && begin_of_route.present? && end_of_route.nil?
          sentence = (changes.any?(&:affects_some_trains) ? 'Some ' : '') + "#{begin_of_route.destinations.map { |d| stop_name_formatter.brief_stop_name(d) }.sort.join('/')}-bound trains are running"
        elsif direction != :both && end_of_route.present?
          sentence = (changes.any?(&:affects_some_trains) ? 'Some ' : '') + "#{end_of_route.destinations.map { |d| stop_name_formatter.brief_stop_name(d) }.sort.join('/')}-bound trains are running"
        else
          if direction == :both
            sentence = (changes.any?(&:affects_some_trains) ? 'Some ' : '') + sentence_intro + " running"
          else
            sentence = (changes.any?(&:affects_some_trains) ? 'Some ' : '') + "#{changes.map(&:destinations).flatten.uniq.map { |d| stop_name_formatter.brief_stop_name(d) }.sort.join('/')}-bound trains are running"
          end
        end
        if end_of_route.present? && direction != :both
          sentence = (changes.any?(&:affects_some_trains) ? 'Some ' : '') + "#{end_of_route.destinations.map { |d| stop_name_formatter.brief_stop_name(d) }.sort.join('/')}-bound trains are running"
        end

        if begin_of_route&.is_a?(ServiceChanges::ReroutingServiceChange)
          if begin_of_route.related_routes.present? && !begin_of_route.related_routes.include?(route_id)
            if begin_of_route == end_of_route
              if begin_of_route.first_station == begin_of_route.last_station
                sentence += " via #{begin_of_route.related_routes.map { |r| "<#{r}>" }.join(' and ')} to"
              else
                sentence += " via #{begin_of_route.related_routes.map { |r| "<#{r}>" }.join(' and ')} between #{stop_name_formatter.stop_name(begin_of_route.first_station)} and"
              end
            else
              sentence += " #{begin_preposition} #{stop_name_formatter.stop_name(begin_of_route.first_station)} via #{begin_of_route.related_routes.map { |r| "<#{r}>" }.join(' and ')}, and between #{stop_name_formatter.stop_name(begin_of_route.last_station)} and"
            end
          else
            sentence += " between #{stop_name_formatter.stop_name(begin_of_route.first_station)} and"
          end
        elsif begin_of_route&.is_a?(ServiceChanges::TruncatedServiceChange)
          sentence += " between #{stop_name_formatter.stop_name(begin_of_route.last_station)} and"
        elsif end_of_route
          sentence += " between #{stop_name_formatter.stop_name(end_of_route.origin)} and"
        end

        if end_of_route&.is_a?(ServiceChanges::ReroutingServiceChange)
          if end_of_route.related_routes.present? && begin_of_route != end_of_route && !end_of_route.related_routes.include?(route_id)
            sentence += " #{stop_name_formatter.stop_name(end_of_route.first_station)}, via  #{end_of_route.related_routes.map { |r| "<#{r}>" }.join(' and ')} #{end_preposition} #{stop_name_formatter.stop_name(end_of_route.last_station)}."
          else
            sentence += " #{stop_name_formatter.stop_name(end_of_route.last_station)}."
          end
        elsif end_of_route&.is_a?(ServiceChanges::TruncatedServiceChange)
          sentence += " #{stop_name_formatter.stop_name(end_of_route.first_station)}."
        elsif begin_of_route
          sentence += " #{begin_of_route.destinations.map { |d| stop_name_formatter.stop_name(d) }.sort.join('/')}."
        end

        results << {
          types: [begin_of_route&.class&.name&.demodulize, end_of_route&.class&.name&.demodulize].compact.uniq,
          description: sentence,
          stations_affected: [begin_of_route&.stations_affected, end_of_route&.stations_affected].flatten.compact.uniq,
          is_long_term: [begin_of_route, end_of_route].compact.all? { |c| c.long_term? },
        }
      end

      split_route_changes = changes.find { |c| c.is_a?(ServiceChanges::SplitRoutingServiceChange)}

      if split_route_changes.present?
        split_routes = split_route_changes.routing_tuples.map.with_index { |rt, i|
          if rt.first == rt.last
            "at #{stop_name_formatter.stop_name(rt.first)}"
          else
            if related_routes = split_route_changes.related_routes_by_segments[i]
              "between #{stop_name_formatter.stop_name(rt.first)} and #{stop_name_formatter.stop_name(rt.last)} via #{related_routes.map { |r| "<#{r}>" }.join(' and ')}"
            else
              "between #{stop_name_formatter.stop_name(rt.first)} and #{stop_name_formatter.stop_name(rt.last)}"
            end
          end
        }.to_sentence(two_words_connector: ", and ")
        results << {
          types: [split_route_changes.class.name.demodulize],
          description: sentence_intro + " running in #{split_route_changes.routing_tuples.size} sections: #{split_routes}.",
          stations_affected: split_route_changes.stations_affected,
          is_long_term: split_route_changes.long_term?,
        }
      end

      changes.select { |c| c.is_a?(ServiceChanges::ReroutingServiceChange) && !c.begin_of_route? && !c.end_of_route?}.each do |change|
        if direction == :both
            sentence = (change.affects_some_trains ? 'Some ' : '') + sentence_intro + " running"
          else
            sentence = (changes.any?(&:affects_some_trains) ? 'Some ' : '') + "#{change.destinations.uniq.map { |d| stop_name_formatter.brief_stop_name(d) }.sort.join('/')}-bound trains are running"
          end
        if change.related_routes.present?
          if change.related_routes.include?(route_id)
            sentence += " between #{stop_name_formatter.stop_name(change.first_station)} and #{stop_name_formatter.stop_name(change.last_station)}."
          else
            sentence += " via #{change.related_routes.map { |r| "<#{r}>" }.join(' and ')} between #{stop_name_formatter.stop_name(change.first_station)} and #{stop_name_formatter.stop_name(change.last_station)}."
          end
        else
          sentence += " via #{change.intermediate_stations.map { |s| stop_name_formatter.stop_name(s) }.join(', ') } between #{stop_name_formatter.stop_name(change.first_station)} and #{stop_name_formatter.stop_name(change.last_station)}."
        end
        results << {
          types: [change.class.name.demodulize],
          description: sentence,
          stations_affected: change.stations_affected,
          is_long_term: change.long_term?,
        }
      end

      local_to_express = changes.select { |c| c.is_a?(ServiceChanges::LocalToExpressServiceChange)}

      if local_to_express.present?
        skipped_stops = local_to_express.flat_map { |c| c.intermediate_stations }.map { |s| stop_name_formatter.stop_name(s) }
        if skipped_stops.length > 1
          skipped_stops_text = "#{skipped_stops[0...-1].join(', ')}, and #{skipped_stops.last}"
        else
          skipped_stops_text = skipped_stops.first
        end
        if direction == :both
          sentence = (local_to_express.any?(&:affects_some_trains) ? 'Some ' : '') + sentence_intro + " skipping #{skipped_stops_text}."
        else
          sentence = (local_to_express.any?(&:affects_some_trains) ? 'Some ' : '') + "#{local_to_express.map(&:destinations).flatten.uniq.map { |d| stop_name_formatter.brief_stop_name(d) }.sort.join('/')}-bound trains are skipping #{skipped_stops_text}."
        end
        results << {
          types: local_to_express.map { |s| s.class.name.demodulize }.uniq,
          description: sentence,
          stations_affected: local_to_express.flat_map { |s| s.stations_affected }.compact.uniq,
          is_long_term: local_to_express.all? { |c| c.long_term? },
        }
      end

      changes.select { |c| c.is_a?(ServiceChanges::ExpressToLocalServiceChange)}.each do |change|
        if direction == :both
          if ServiceChangeAnalyzer::CANAL_TO_ATLANTIC_VIA_BRIDGE_WITH_DEKALB_BOTH_DIRS.include?(change.stations_affected)
            sentence = (change.affects_some_trains ? 'Some ' : '') + sentence_intro + " stopping at #{stop_name_formatter.stop_name(ServiceChangeAnalyzer::DEKALB_AV_STOP)}."
          else
            sentence = (change.affects_some_trains ? 'Some ' : '') + sentence_intro + " making local stops between #{stop_name_formatter.stop_name(change.first_station)} and #{stop_name_formatter.stop_name(change.last_station)}."
          end
        else
          if ServiceChangeAnalyzer::CANAL_TO_ATLANTIC_VIA_BRIDGE_WITH_DEKALB_BOTH_DIRS.include?(change.stations_affected)
            sentence = (change.affects_some_trains ? 'Some ' : '') + "#{change.destinations.uniq.map { |d| stop_name_formatter.stop_name(d) }.sort.join('/')}-bound trains are stopping at #{stop_name_formatter.stop_name(ServiceChangeAnalyzer::DEKALB_AV_STOP)}."
          else
            sentence = (change.affects_some_trains ? 'Some ' : '') + "#{change.destinations.uniq.map { |d| stop_name_formatter.stop_name(d) }.sort.join('/')}-bound trains are making local stops between #{stop_name_formatter.stop_name(change.first_station)} and #{stop_name_formatter.stop_name(change.last_station)}."
          end
        end
        results << {
          types: [change.class.name.demodulize],
          description: sentence,
          stations_affected: change.stations_affected,
          is_long_term: change.long_term?,
        }
      end

      [direction, results]
    }.to_h
  end

  def self.destinations(route_id, scheduled_trips, actual_routings, stop_name_formatter)
    [1, 0].map { |scheduled_direction|
      trips = scheduled_trips[scheduled_direction]
      key_translation = scheduled_direction == 0 ? 1 : 3
      [key_translation, actual_routings[key_translation]&.map(&:last)&.uniq&.map {|s| stop_name_formatter.brief_stop_name(s)}&.compact&.uniq || trips&.map(&:destination)&.uniq]
    }.to_h
  end

  def self.append_additional_trips(route_id, processed_trips, actual_routings, common_routings, routes_with_shared_tracks)
    additional_routes = routes_with_shared_tracks.flat_map { |_, stops_map| stops_map.flat_map { |_, route_map| route_map.map { |key, _| key}}}.uniq
    additional_processed_trip_futures = {}
    REDIS_CLIENT.pipelined do |pipeline|
      additional_processed_trip_futures = additional_routes.map { |r| RedisStore.processed_trips(r, pipeline) }
    end
    additional_processed_trip_maps = additional_processed_trip_futures.flat_map { |future| future.value && Marshal.load(future.value)}.filter { |m| m.present? }
    additional_processed_trips = additional_processed_trip_maps.flat_map { |m| m.values.flat_map { |n| n.values.flatten }}.uniq(&:id)
    processed_trips.to_h { |direction, trips_by_routes|
      [direction, trips_by_routes.to_h { |routing_key, processed_trips|
        if routing_key == 'blended'
          tracks = processed_trips.map(&:tracks).inject(Hash.new { |h, k| h[k] = [] }) { |merged_map, tracks|
            tracks.each { |stop_id, track_id|
              merged_map[stop_id].push(track_id)
            }
            merged_map
          }
          routing = common_routings[direction]
          all_trips = processed_trips + additional_processed_trips.filter { |t| tracks[t.upcoming_stop].include?(t.tracks[t.upcoming_stop]) }
          [routing_key, routing.map { |s|
            all_trips.select { |t| t.upcoming_stop == s }.sort_by { |t| -t.estimated_upcoming_stop_arrival_time }
          }.flatten.compact]
        else
          ref_trip = processed_trips.max_by { |t| t.tracks.keys.size }
          tracks = ref_trip.tracks
          routing = ref_trip.stops.sort_by { |_, v| v }.map { |k, _| k }
          all_trips = processed_trips + additional_processed_trips.filter { |t| tracks[t.upcoming_stop].present? && tracks[t.upcoming_stop] == t.tracks[t.upcoming_stop] }
          [routing_key, routing.map { |s|
            all_trips.select { |t| t.upcoming_stop == s }.sort_by { |t| -t.estimated_upcoming_stop_arrival_time }
          }.flatten.compact]
        end
      }]
    }
  end

  def self.additional_trips_to_array(additional_trips, route_id)
    additional_trips.flat_map { |_, trips_by_direction|
      trips_by_direction.flat_map { |_, trips_by_routing|
        trips_by_routing.reject { |t| t.route_id == route_id }.map(&:id)
      }
    }.uniq
  end

  def self.summarize_routes_with_shared_tracks(routes_with_shared_tracks)
    routes_with_shared_tracks.flat_map { |_, stops_with_shared_routes|
      stops_with_shared_routes.flat_map { |_, routes|
        routes.keys
      }
    }.uniq
  end

  def self.format_processed_trips(processed_trips, route_id)
    processed_trips.to_h { |direction, trips_by_routes|
      [direction, trips_by_routes.to_h { |routing, processed_trips|
        [routing, processed_trips.map { |trip|
          estimated_upcoming_stop_arrival_time = (trip.timestamp > trip.estimated_upcoming_stop_arrival_time) ? trip.upcoming_stop_arrival_time : trip.estimated_upcoming_stop_arrival_time
          if route_id != trip.route_id
            {
              id: trip.id,
              route_id: trip.route_id,
              direction: trip.direction == 3 ? "south" : "north",
              previous_stop: trip.previous_stop,
              previous_stop_arrival_time: trip.previous_stop_arrival_time,
              upcoming_stop: trip.upcoming_stop,
              upcoming_stop_arrival_time: trip.upcoming_stop_arrival_time,
              estimated_upcoming_stop_arrival_time: estimated_upcoming_stop_arrival_time,
              destination_stop: trip.destination,
              delayed_time: trip.delayed_time,
              schedule_discrepancy: trip.schedule_discrepancy,
              is_delayed: trip.delayed?,
              is_assigned: trip.is_assigned,
              timestamp: trip.timestamp,
            }
          else
            {
              id: trip.id,
              route_id: trip.route_id,
              previous_stop: trip.previous_stop,
              previous_stop_arrival_time: trip.previous_stop_arrival_time,
              upcoming_stop: trip.upcoming_stop,
              upcoming_stop_arrival_time: trip.upcoming_stop_arrival_time,
              estimated_upcoming_stop_arrival_time: estimated_upcoming_stop_arrival_time,
              time_behind_next_train: trip.time_behind_next_train,
              estimated_time_behind_next_train: trip.estimated_time_behind_next_train,
              estimated_time_until_destination: trip.estimated_time_until_destination,
              destination_stop: trip.destination,
              delayed_time: trip.delayed_time,
              schedule_discrepancy: trip.schedule_discrepancy,
              is_delayed: trip.delayed?,
              is_assigned: trip.is_assigned,
              timestamp: trip.timestamp,
            }
          end
        }]
      }]
    }
  end

  def self.format_trips_with_upcoming_stop_times(processed_trips, travel_times)
    processed_trips.to_h { |direction, trips_by_routes|
      [direction, trips_by_routes.flat_map { |routing_id, trips|
        trips.map { |trip|
          [routing_id, trip]
        }
      }.uniq { |routing_id, trip|
        trip.id
      }.map { |routing_id, trip|
        stops = trip.past_stops.dup
        last_past_stop = trip.past_stops.keys.last
        stops[trip.upcoming_stop] = trip.estimated_upcoming_stop_arrival_time.to_i
        trip.upcoming_stops.each_cons(2).reduce(trip.estimated_upcoming_stop_arrival_time.to_i) { |sum, (a_stop, b_stop)|
          pair_str = "#{a_stop}-#{b_stop}"
          next_interval = travel_times[pair_str].to_i >= 30 ? travel_times[pair_str] : trip.stops[b_stop] - trip.stops[a_stop]
          stops[b_stop] = sum + next_interval.to_i
        }
        {
          id: trip.id,
          stops: stops,
          delayed_time: trip.delayed_time,
          schedule_discrepancy: trip.schedule_discrepancy,
          is_delayed: trip.delayed?,
          is_assigned: trip.is_assigned,
          last_stop_made: last_past_stop,
          routing_id: routing_id
        }
      }]
    }
  end

  def self.sort_actual_routings(route_id, actual_routings, scheduled_routings)
    all_south_scheduled_routings = ((scheduled_routings[1] || []) + (scheduled_routings[0]&.map(&:reverse) || [])).compact.uniq
    # TODO: Replace this
    # if ENV["SIXTY_THIRD_STREET_SERVICE_CHANGES"] == "true" && ServiceChangeAnalyzer::SIXTY_THIRD_STREET_SERVICE_CHANGES[route_id].present?
    #   all_south_scheduled_routings = ServiceChangeAnalyzer::SIXTY_THIRD_STREET_SERVICE_CHANGES[route_id].map { |_, r| r.reverse }
    # end
    actual_routings.to_h { |direction, a|
      compared_routings = direction == 3 ? all_south_scheduled_routings : all_south_scheduled_routings.map(&:reverse)
      results = compared_routings.sort_by { |r| -r.size }.first&.flat_map { |s| a.filter { |a1| a1.any? { |s| a1.include?(s) }}}&.compact&.uniq || []
      remaining_routings = a - results
      [direction, results + remaining_routings]
    }
  end

  class StopNameFormatter
    attr_accessor :stops, :ambiguous_stop_names

    def initialize(actual_routings, scheduled_routings)
      stop_ids = Set.new
      actual_routings.each do |_, routings|
        routings.each do |r|
          r.each do |stop_id|
            stop_ids << stop_id
          end
        end
      end
      scheduled_routings.each do |_, routings|
        routings.each do |r|
          r.each do |stop_id|
            stop_ids << stop_id
          end
        end
      end

      self.stops = Scheduled::Stop.where(internal_id: stop_ids).to_h { |stop| [stop.internal_id, stop] }
      self.ambiguous_stop_names = stops.values.group_by(&:stop_name).select { |_, v| v.size > 1}.map(&:first)
    end

    def stop_name(stop_id)
      stop = stops[stop_id]
      return unless stop
      if ambiguous_stop_names&.include?(stop.stop_name) && !stop.secondary_name&.include?('Level')
        return "((#{stop.stop_name} (#{stop.secondary_name})))"
      end
      "((#{stop.stop_name}))"
    end

    def brief_stop_name(stop_id)
      stop = stops[stop_id]
      return unless stop
      "((#{stop.stop_name}))"
    end
  end
end