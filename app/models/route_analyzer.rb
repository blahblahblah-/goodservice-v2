class RouteAnalyzer
  def self.analyze_route(route_id, actual_trips, actual_routings, actual_headways_by_routes, timestamp, scheduled_trips, scheduled_routings, recent_scheduled_routings, scheduled_headways_by_routes)
    service_changes = ServiceChangeAnalyzer.service_change_summary(route_id, actual_routings, scheduled_routings, recent_scheduled_routings, timestamp)
    max_delayed_time = max_delay(actual_trips)
    slowness = accumulated_extra_time_between_stops(actual_routings, timestamp)
    runtime_diff = overall_runtime_diff(actual_routings, timestamp)
    headway_discrepancy = max_headway_discrepancy(actual_headways_by_routes, scheduled_headways_by_routes)
    direction_statuses, status = route_status(max_delayed_time, slowness, headway_discrepancy, service_changes, actual_trips, scheduled_trips)
    destination_station_names = destinations(actual_routings)
    converted_destination_station_names = convert_to_readable_directions(destination_station_names)
    summaries = service_summaries(max_delayed_time, slowness, headway_discrepancy, destination_station_names, actual_trips, actual_routings, scheduled_headways_by_routes, timestamp)

    summary = {
      status: status,
      direction_statuses: convert_to_readable_directions(direction_statuses),
      service_summaries: convert_to_readable_directions(summaries),
      service_change_summaries: service_change_summaries(route_id, service_changes, converted_destination_station_names),
      timestamp: timestamp,
    }.to_json

    detailed_stats = {
      status: status,
      direction_statuses: convert_to_readable_directions(direction_statuses),
      service_summaries: convert_to_readable_directions(summaries),
      destinations: converted_destination_station_names,
      max_delay: convert_to_readable_directions(max_delayed_time),
      accumulated_extra_travel_time: convert_to_readable_directions(slowness),
      overall_runtime_diff: convert_to_readable_directions(runtime_diff),
      max_headway_discrepancy: convert_to_readable_directions(headway_discrepancy),
      service_changes: service_changes,
      scheduled_headways: convert_to_readable_directions(scheduled_headways_by_routes),
      actual_headways: convert_to_readable_directions(actual_headways_by_routes),
      actual_routings: convert_to_readable_directions(actual_routings),
      timestamp: timestamp,
    }.to_json

    RedisStore.add_route_status_summary(route_id, summary)
    RedisStore.update_route_status(route_id, detailed_stats)
  end

  private

  def self.route_status(delays, slowness, headway_discrepancy, service_changes, actual_trips, scheduled_trips)
    direction_statuses = [1, 3].map { |direction|
      direction_key = direction == 3 ? :south : :north
      status = 'Good Service'
      if actual_trips.empty?
        if scheduled_trips.empty?
          status = 'Not Scheduled'
        else
          status = 'No Service'
        end
      elsif delays[direction] && delays[direction] >= 5
        status = 'Delay'
      elsif service_changes[direction_key].present? || service_changes[:both].present?
        status = 'Service Change'
      elsif slowness[direction] && slowness[direction] >= 5
        status = 'Slow'
      elsif headway_discrepancy[direction] && headway_discrepancy[direction] >= 2
        status = 'Not Good'
      end
      [direction, status]
    }.to_h
    status = ['Delay', 'Service Change', 'Slow', 'Not Good', 'No Service', 'Not Scheduled', 'Good Service'].find { |s| direction_statuses.any? { |_, status| s == status } }

    return direction_statuses, status
  end

  def self.service_summaries(delays, slowness, headway_discrepancy, destination_stations, actual_trips, actual_routings, scheduled_headways_by_routes, timestamp)
    direction_statuses = [ServiceChangeAnalyzer::NORTH, ServiceChangeAnalyzer::SOUTH].map { |direction|
      next [direction[:route_direction], nil] unless actual_trips[direction[:route_direction]]
      strs = []
      intro = "#{destination_stations[direction[:route_direction]]}-bound trains are "

      if delays[direction[:route_direction]] && delays[direction[:route_direction]] >= 5
        delayed_trips = actual_trips[direction[:route_direction]].map { |_, trips|
          trips.select { |t| t.delayed_time >= 300 }
        }.max_by { |trips| trips.map { |t| t.delayed_time }.max || 0 }
        max_delay = delayed_trips.max_by { |t| t.delayed_time }.delayed_time / 60
        if delayed_trips.size == 1
          strs << "delayed at #{stop_name(delayed_trips.first.upcoming_stop)} (for #{max_delay.round} mins)"
        else
          strs << "delayed between #{stop_name(delayed_trips.first.upcoming_stop)} and #{stop_name(delayed_trips.last.upcoming_stop)} (for #{max_delay.round} mins)"
        end
      end

      if slowness[direction[:route_direction]] && slowness[direction[:route_direction]] >= 5
        slow_obj = actual_routings[direction[:route_direction]].map { |r|
          stop_pairs = r.each_cons(2).map { |a_stop, b_stop|
            scheduled_travel_time = RedisStore.scheduled_travel_time(a_stop, b_stop)
            actual_travel_time = RouteProcessor.average_travel_time(a_stop, b_stop, timestamp)
            {
              from: a_stop,
              to: b_stop,
              travel_time_diff: (actual_travel_time - scheduled_travel_time) / 60.0,
            }
          }.select { |obj|
            obj[:travel_time_diff] >= 1
          }

          next { accumulated_travel_time_diff: 0 } unless stop_pairs.present?

          accumulated_travel_time_diff = stop_pairs.reduce(0) { |sum, obj| sum + obj[:travel_time_diff]}

          {
            from: stop_pairs.first && stop_pairs.first[:from],
            to: stop_pairs.last && stop_pairs.last[:to],
            accumulated_travel_time_diff: accumulated_travel_time_diff,
          }
        }.max_by { |obj| obj[:accumulated_travel_time_diff] }

        strs << "traveling slowly between #{stop_name(slow_obj[:from])} and #{stop_name(slow_obj[:to])} (taking #{slow_obj[:accumulated_travel_time_diff].round} mins longer)"
      end

      if headway_discrepancy[direction[:route_direction]] && headway_discrepancy[direction[:route_direction]] >= 2
        max_scheduled_headway = determine_headway_to_use(scheduled_headways_by_routes[direction[:scheduled_direction]])&.max
        selected_routing = actual_trips[direction[:route_direction]].first.first
        selected_trips = actual_trips[direction[:route_direction]].first.last
        if actual_trips[direction[:route_direction]].keys.size > 1
          routing_with_most_trips = actual_trips[direction[:route_direction]].max_by { |_, trips| trips.size }
          routing_with_least_trips = actual_trips[direction[:route_direction]].min_by { |_, trips| trips.size }

          all_routes = actual_routings[direction[:route_direction]]
          common_start = all_routes.first.find { |s| all_routes.all? { |r| r.include?(s) }}
          common_end = all_routes.first.reverse.find { |s| all_routes.all? { |r| r.include?(s) }}

          if common_start && common_end
            all_trips = actual_trips[direction[:route_direction]].values.flatten
            selected_routing = all_routes.map { |r| r[r.index(common_start)..r.index(common_end)] }.sort_by(&:size).reverse.first
            selected_trips = selected_routing.map { |s| all_trips.select { |t| t.upcoming_stop == s }.sort_by { |t| t.upcoming_stop_estimated_arrival_time }}.flatten.compact
          else
            selected_routing = routing_with_most_trips.first
            selected_trips = routing_with_most_trips.last
          end
        end

        headways = selected_trips.each_cons(2).map { |a_trip, b_trip|
          {
            prev_trip: a_trip,
            next_trip: b_trip,
            time_between: RouteProcessor.time_between_trips(a_trip, b_trip, timestamp, selected_routing)
          }
        }.select { |obj| obj[:time_between] > max_scheduled_headway}
        max_actual_headway = headways.max_by { |obj| obj[:time_between] }[:time_between]

        strs << "have longer wait times between #{stop_name(headways.first[:prev_trip].upcoming_stop)} and #{stop_name(headways.last[:next_trip].upcoming_stop)} (up to #{max_actual_headway.round} mins, normally every #{max_scheduled_headway.round} mins)"
      end

      next [direction[:route_direction], nil] unless strs.present?

      if strs.size > 1
        strs[strs.size - 1] = "and #{strs.last}"
      end

      [direction[:route_direction], "#{intro}#{strs.join(', ')}."]
    }.to_h
  end

  def self.convert_to_readable_directions(hash)
    hash.map { |direction, data| [direction == 3 ? :south : :north, data] }.to_h
  end

  def self.max_headway_discrepancy(actual_headways_by_routes, scheduled_headways_by_routes)
    [ServiceChangeAnalyzer::NORTH, ServiceChangeAnalyzer::SOUTH].map { |direction|
      actual_headway = determine_headway_to_use(actual_headways_by_routes[direction[:route_direction]])&.max
      scheduled_headway = determine_headway_to_use(scheduled_headways_by_routes[direction[:scheduled_direction]])&.max
      diff = scheduled_headway && actual_headway ? actual_headway - scheduled_headway : 0
      [direction[:route_direction], [diff, 0].max]
    }.to_h
  end

  def self.determine_headway_to_use(headway_by_routes)
    if headway_by_routes && headway_by_routes.keys.size > 1
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

  def self.overall_runtime_diff(actual_routings, timestamp)
    actual_routings.map { |direction, routings|
      [direction, routings.map { |r|
        scheduled_runtime = (
          r.each_cons(2).map { |a_stop, b_stop|
            station_ids = "#{a_stop}-#{b_stop}"
            RedisStore.scheduled_travel_time(a_stop, b_stop)
          }.reduce(&:+) || 0
        ) / 60.0
        actual_runtime = (
          r.each_cons(2).map { |a_stop, b_stop|
            RouteProcessor.average_travel_time(a_stop, b_stop, timestamp)
          }.reduce(&:+) || 0
        ) / 60.0
        actual_runtime - scheduled_runtime
      }.max]
    }.to_h
  end

  def self.accumulated_extra_time_between_stops(actual_routings, timestamp)
    actual_routings.map { |direction, routings|
      [direction, routings.map { |r|
        (
          r.each_cons(2).map { |a_stop, b_stop|
            scheduled_travel_time = RedisStore.scheduled_travel_time(a_stop, b_stop)
            actual_travel_time = RouteProcessor.average_travel_time(a_stop, b_stop, timestamp)
            diff = actual_travel_time - scheduled_travel_time
            diff >= 60.0 ? diff : 0
          }.reduce(&:+) || 0
        ) / 60.0
      }.max]
    }.to_h
  end

  def self.max_delay(actual_trips)
    actual_trips.map { |direction, trips|
      [direction, trips.values.flatten.map(&:delayed_time).max / 60]
    }.to_h
  end

  def self.service_change_summaries(route_id, service_changes_by_directions, destination_stations)
    service_changes_by_directions.map { |direction, service_changes|
      return [direction, ''] unless service_changes

      service_changes.select! { |s| !s.is_a?(ServiceChanges::NotScheduledServiceChange)}

      notices = []

      case direction
      when :both
        sentence_intro = "<#{route_id}> trains are"
        begin_preposition = 'to/from'
        end_preposition = 'to/from'
      else
        sentence_intro = "#{destination_stations[direction]}-bound trains are"
        begin_preposition = 'from'
        end_preposition = 'to'
      end

      if service_changes.any? { |c| c.is_a?(ServiceChanges::NoTrainServiceChange) }
        return [direction, "#{sentence_intro} not running."]
      end

      begin_of_route = service_changes.find(&:begin_of_route?)
      end_of_route = service_changes.find(&:end_of_route?)

      if begin_of_route || end_of_route
        if direction != :both && begin_of_route.present? && end_of_route.nil?
          sentence = (service_changes.any?(&:affects_some_trains) ? 'Some ' : '') + "#{stop_name(begin_of_route.destination)}-bound trains are running"
        elsif direction != :both && end_of_route.present?
          sentence = (service_changes.any?(&:affects_some_trains) ? 'Some ' : '') + "#{stop_name(end_of_route.destination)}-bound trains are running"
        else
          sentence = (service_changes.any?(&:affects_some_trains) ? 'Some ' : '') + sentence_intro + " running"
        end
        if begin_of_route && end_of_route && begin_of_route != end_of_route && [begin_of_route, end_of_route].all? {|c| c.is_a?(ServiceChanges::TruncatedServiceChange)} && ([begin_of_route.stations_affected[1...-1] & end_of_route.stations_affected[1...-1]]).present?
          sentence += " in two sections: between #{stop_name(end_of_route.origin)} and #{stop_name(end_of_route.first_station)}, and #{stop_name(begin_of_route.last_station)} and #{stop_name(begin_of_route.destination)}"
        else
          if end_of_route.present? && direction != :both
            sentence = (service_changes.any?(&:affects_some_trains) ? 'Some ' : '') + " #{stop_name(end_of_route.destination)}-bound trains are running"
          end

          if begin_of_route&.is_a?(ServiceChanges::ReroutingServiceChange)
            if begin_of_route.related_routes.present? && !begin_of_route.related_routes.include?(route_id)
              if begin_of_route == end_of_route
                if begin_of_route.first_station == begin_of_route.last_station
                  sentence += " via #{begin_of_route.related_routes.map { |r| "<#{r}>" }.join(' and ')} to"
                else
                  sentence += " via #{begin_of_route.related_routes.map { |r| "<#{r}>" }.join(' and ')} between #{stop_name(begin_of_route.first_station)} and"
                end
              else
                sentence += " #{begin_preposition} #{stop_name(begin_of_route.first_station)} via #{begin_of_route.related_routes.map { |r| "<#{r}>" }.join(' and ')}, and between #{stop_name(begin_of_route.last_station)} and"
              end
            else
              sentence += " between #{stop_name(begin_of_route.first_station)} and"
            end
          elsif begin_of_route&.is_a?(ServiceChanges::TruncatedServiceChange)
            sentence += " between #{stop_name(begin_of_route.last_station)} and"
          else
            sentence += " between #{stop_name(end_of_route.origin)} and"
          end

          if end_of_route&.is_a?(ServiceChanges::ReroutingServiceChange)
            if end_of_route.related_routes.present? && begin_of_route != end_of_route && !end_of_route.related_routes.include?(route_id)
              sentence += " #{stop_name(end_of_route.first_station)}, via  #{end_of_route.related_routes.map { |r| "<#{r}>" }.join(' and ')} #{end_preposition} #{stop_name(end_of_route.last_station)}."
            else
              sentence += " #{stop_name(end_of_route.last_station)}."
            end
          elsif end_of_route&.is_a?(ServiceChanges::TruncatedServiceChange)
            sentence += " #{stop_name(end_of_route.first_station)}."
          else
            sentence += " #{stop_name(begin_of_route.destination)}."
          end
        end

        notices << sentence
      end

      split_route_changes = service_changes.select { |c| c.is_a?(ServiceChanges::SplitRoutingServiceChange)}

      if split_route_changes.present?
        notices << sentence_intro + " running in two sections: between #{stop_name(split_route_changes.first.first_station)} and #{stop_name(split_route_changes.first.last_station)}, and between #{stop_name(split_route_changes.second.first_station)} and #{stop_name(split_route_changes.second.last_station)}"
      end

      service_changes.select { |c| c.is_a?(ServiceChanges::ReroutingServiceChange) && !c.begin_of_route? && !c.end_of_route?}.each do |change|
        sentence = (change.affects_some_trains ? 'Some ' : '') + sentence_intro + " running"
        if change.related_routes.present?
          if change.related_routes.include?(route_id)
            sentence += " between #{stop_name(change.first_station)} and #{stop_name(change.last_station)}."
          else
            sentence += " via #{change.related_routes.map { |r| "<#{r}>" }.join(' and ')} between #{stop_name(change.first_station)} and #{stop_name(change.last_station)}."
          end
        else
          sentence += " via #{change.intermediate_stations.map { |s| stop_name(s) }.join(', ') } between #{stop_name(change.first_station)} and #{stop_name(change.last_station)}."
        end
        notices << sentence
      end

      local_to_express = service_changes.select { |c| c.is_a?(ServiceChanges::LocalToExpressServiceChange)}

      if local_to_express.present?
        skipped_stops = local_to_express.map { |c| c.intermediate_stations }.flatten.map { |s| stop_name(s) }
        if skipped_stops.length > 1
          skipped_stops_text = "#{skipped_stops[0...-1].join(', ')}, and #{skipped_stops.last}"
        else
          skipped_stops_text = skipped_stops.first
        end
        sentence = (local_to_express.any?(&:affects_some_trains) ? 'Some ' : '') + sentence_intro + " skipping #{skipped_stops_text}."
        notices << sentence
      end

      service_changes.select { |c| c.is_a?(ServiceChanges::ExpressToLocalServiceChange)}.each do |change|
        sentence = (change.affects_some_trains ? 'Some ' : '') + sentence_intro + " making local stops between #{stop_name(change.first_station)} and #{stop_name(change.last_station)}"
        notices << sentence
      end

      [direction, notices]
    }.to_h
  end

  def self.destinations(actual_routings)
    actual_routings.map { |direction, routings|
      [direction, routings.map(&:last).uniq.map {|s| stop_name(s)}.compact.uniq.join('/')]
    }.to_h
  end

  def self.stop_name(stop_id)
    Scheduled::Stop.find_by(internal_id: stop_id)&.stop_name
  end
end