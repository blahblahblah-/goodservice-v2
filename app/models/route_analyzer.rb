class RouteAnalyzer
  def self.analyze_route(route_id, actual_trips, actual_routings, actual_headways_by_routes, timestamp, scheduled_trips, scheduled_routings, recent_scheduled_routings, scheduled_headways_by_routes)
    service_changes = ServiceChangeAnalyzer.service_change_summary(route_id, actual_routings, scheduled_routings, recent_scheduled_routings, timestamp)
    # status, secondary_status, direction_statuses, direction_secondary_statuses, service_summaries = route_status
    destination_station_names = destinations(actual_routings)
    max_delayed_time = max_delay(actual_trips)
    results = {
      # id: route_id,
      # name: route.name,
      # color: route.color,
      # text_color: route.text_color,
      # alternate_name: route.alternate_name,

      # status: status,
      # secondary_status: secondary_status,
      # direction_statuses: direction_statuses,
      # direction_secondary_statuses: direction_secondary_statuses,
      # service_summaries: service_summaries,
      max_delay: max_delayed_time,
      service_changes: service_changes,
      service_change_summaries: service_change_summaries(route_id, service_changes, destination_station_names),
      scheduled_headways: scheduled_headways_by_routes.map { |direction, headways| [direction == 0 ? :north : :south, headways] }.to_h ,
      actual_headways: actual_headways_by_routes.map { |direction, headways| [direction == 0 ? :north : :south, headways] }.to_h,
      actual_routings: actual_routings.map { |direction, routings| [direction == 0 ? :north : :south, routings] }.to_h,
      scheduled: scheduled_trips.present?,
      # visible: route.visible?,
    }.to_json
    REDIS_CLIENT.zadd("route-status:#{route_id}", timestamp, results)
  end

  private

  def self.max_delay(actual_trips)
    actual_trips.values.map(&:values).flatten.map(&:delayed_time).max
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
            if begin_of_route.related_routes.present?
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
            if end_of_route.related_routes.present? && begin_of_route != end_of_route
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
          sentence += " via #{change.related_routes.map { |r| "<#{r}>" }.join(' and ')} between #{stop_name(change.first_station)} and #{stop_name(change.last_station)}."
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
      [direction == 0 ? :north : :south, routings.map(&:last).uniq.map {|s| stop_name(s)}.compact.uniq.join('/')]
    }.to_h
  end

  def self.stop_name(stop_id)
    Scheduled::Stop.find_by(internal_id: stop_id)&.stop_name
  end
end