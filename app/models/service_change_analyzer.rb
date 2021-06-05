class ServiceChangeAnalyzer
  NORTH = {
    route_direction: 1,
    scheduled_direction: 0,
    suffix: 'N'
  }

  SOUTH = {
    route_direction: 3,
    scheduled_direction: 1,
    suffix: 'S'
  }

  class << self
    def service_change_summary(route_id, actual_routings, scheduled_routings, recent_scheduled_routings, timestamp)
      direction_changes = [NORTH, SOUTH].map do |direction|
        changes = []
        actual = actual_routings[direction[:route_direction]]
        scheduled = scheduled_routings[direction[:scheduled_direction]]

        if !actual || actual.empty?
          if !scheduled || scheduled.empty?
            changes << [ServiceChanges::NotScheduledServiceChange.new(direction[:route_direction], [], nil, nil)]
          else
            changes << [ServiceChanges::NoTrainServiceChange.new(direction[:route_direction], [], nil, nil)]
          end
        else
          actual.each do |actual_routing|
            routing_changes = []
            ongoing_service_change = nil
            scheduled_routing = scheduled&.min_by { |sr| (actual_routing - sr).size + (sr - actual_routing).size }

            if !scheduled_routing
              changes << [ServiceChanges::ReroutingServiceChange.new(direction[:route_direction], actual_routing, actual_routing.first, actual_routing)]
              next
            end

            scheduled_index = 0
            previous_actual_station = nil
            previous_scheduled_station = nil
            remaining_stations = nil

            actual_routing.each_with_index do |actual_station, actual_index|
              scheduled_station = scheduled_routing[scheduled_index]

              if scheduled_station.nil?
                remaining_stations = actual_routing[actual_index - 1...actual_routing.length]
                break
              end

              if ongoing_service_change.nil?
                if actual_station != scheduled_station &&
                  (interchangeable_transfers[actual_station].nil? || interchangeable_transfers[actual_station].none? { |t| t.from_stop_internal_id == scheduled_station })
                  if (scheduled_index_to_current_station = scheduled_routing.index(actual_station)) || interchangeable_transfers[actual_station]&.any?{ |t| scheduled_index_to_current_station = scheduled_routing.index(t.from_stop_internal_id)}
                    if previous_actual_station.nil? && previous_scheduled_station.nil?
                      array_of_skipped_stations = [nil].concat(scheduled_routing[0..scheduled_index_to_current_station])
                      routing_changes << ServiceChanges::TruncatedServiceChange.new(direction[:route_direction], array_of_skipped_stations, actual_routing.first, actual_routing)
                      scheduled_index = scheduled_index_to_current_station + 1
                      previous_scheduled_station = array_of_skipped_stations.last
                    else
                      array_of_skipped_stations = scheduled_routing[(scheduled_index - 1)..scheduled_index_to_current_station]
                      routing_changes << ServiceChanges::LocalToExpressServiceChange.new(direction[:route_direction], array_of_skipped_stations, actual_routing.first, actual_routing)
                      scheduled_index = scheduled_index_to_current_station + 1
                      previous_scheduled_station = actual_station
                    end
                  else
                    if actual_routing.include?(scheduled_station) && previous_actual_station
                      if routing_changes.last&.class == ServiceChanges::ExpressToLocalServiceChange && actual_routing[actual_index - 2, 2].include?(routing_changes.last.last_station)
                        ongoing_service_change = routing_changes.pop
                        ongoing_service_change.stations_affected << actual_station if ongoing_service_change.last_station != actual_station
                      else
                        if scheduled_routing.include?(previous_actual_station)
                          ongoing_service_change = ServiceChanges::ExpressToLocalServiceChange.new(direction[:route_direction], [previous_actual_station, actual_station], actual_routing.first, actual_routing)
                        else
                          ongoing_service_change = ServiceChanges::ReroutingServiceChange.new(direction[:route_direction], [previous_actual_station, actual_station], actual_routing.first, actual_routing)
                        end
                      end
                    else
                      ongoing_service_change = ServiceChanges::ReroutingServiceChange.new(direction[:route_direction], [previous_actual_station, actual_station], actual_routing.first, actual_routing)
                    end
                  end
                else
                  scheduled_index += 1
                  previous_scheduled_station = scheduled_station
                end
              else
                if ongoing_service_change.is_a?(ServiceChanges::ExpressToLocalServiceChange)
                  ongoing_service_change.stations_affected << actual_station

                  if actual_station == scheduled_station || interchangeable_transfers[actual_station]&.any? { |t| t.from_stop_internal_id == scheduled_station }
                    routing_changes << ongoing_service_change
                    ongoing_service_change = nil
                    scheduled_index += 1
                    previous_scheduled_station = scheduled_station
                  end
                else  # ongoing_service_change.is_a?(ServiceChanges::ReroutingServiceChange)
                  ongoing_service_change.stations_affected << actual_station
                  if skip_to_scheduled_index = (scheduled_routing.index(actual_station) ||
                    (interchangeable_transfers[actual_station] && interchangeable_transfers[actual_station]&.map { |t| scheduled_routing.index(t.from_stop_internal_id) }.compact.first))
                    routing_changes << ongoing_service_change
                    ongoing_service_change = nil
                    scheduled_index = skip_to_scheduled_index + 1
                    previous_scheduled_station = scheduled_station
                  end
                end
              end

              previous_actual_station = actual_station
            end
            if ongoing_service_change
              ongoing_service_change.stations_affected << nil
              routing_changes << ongoing_service_change
            elsif remaining_stations.present?
              routing_changes << ServiceChanges::ReroutingServiceChange.new(direction[:route_direction], remaining_stations.concat([nil]), actual_routing.first, actual_routing)
            elsif scheduled_routing[scheduled_index] && scheduled_routing.size > scheduled_index + 1
              routing_changes << ServiceChanges::TruncatedServiceChange.new(direction[:route_direction], scheduled_routing[scheduled_index - 1..scheduled_routing.length].concat([nil]), actual_routing.first, actual_routing)
            end
            changes << routing_changes
          end
        end
        if actual&.size == 2 && (actual[0] & actual[1]).size <= 1
          actual.each_with_index do |ar, i|
            changes[i] = [] unless changes[i]
            changes[i] << ServiceChanges::SplitRoutingServiceChange.new(direction[:route_direction], ar, ar.first, ar)
          end
        end
        changes.map { |r| r.select { |c| !c.is_a?(ServiceChanges::TruncatedServiceChange) || (!truncate_service_change_overlaps_with_different_routing?(c, actual) && !r.any?{ |c2| c2.is_a?(ServiceChanges::SplitRoutingServiceChange)} )}}
      end

      both = []

      direction_changes.each do |d|
        d.each do |r|
          r.each do |c|
            if c.is_a?(ServiceChanges::ReroutingServiceChange)
              match_route(route_id, c, recent_scheduled_routings, timestamp)
            end
          end
        end
      end

      condensed_changes = direction_changes.map do |d|
        changes = d.flatten.uniq

        changes.each do |c|
          c.affects_some_trains = d.each_index.select { |i|
            !d[i].include?(c) && c.applicable_to_routing?(actual_routings[c.direction][i].dup.unshift(nil).push(nil))
          }.present?
        end

        changes.sort_by { |c| c.affects_some_trains ? 1 : 0 }
      end

      condensed_changes[1].select! do |c1|
        if other_direction = condensed_changes[0].find { |c2|
            c1.class == c2.class &&
            (c1.first_station == c2.last_station || interchangeable_transfers[c1.first_station]&.any?{ |t| t.from_stop_internal_id == c2.last_station }) &&
            (c1.last_station == c2.first_station || interchangeable_transfers[c1.last_station]&.any?{ |t| t.from_stop_internal_id == c2.first_station }) &&
            c1.class != ServiceChanges::SplitRoutingServiceChange
          }
          condensed_changes[0].delete(other_direction)
          both << c1
          false
        else
          true
        end
      end

      split_changes = condensed_changes[1].select{ |c| c.is_a?(ServiceChanges::SplitRoutingServiceChange) }
      split_changes_other_direction = condensed_changes[0].select{ |c| c.is_a?(ServiceChanges::SplitRoutingServiceChange) }

      if split_changes.present? && split_changes_other_direction.present?
        if split_changes.all? { |c1| split_changes_other_direction.any? { |c2| c1.first_station == c2.last_station && c1.last_station == c2.first_station }}
          both.concat(split_changes)
          split_changes.each { |c|
            condensed_changes[1].delete(c)
          }
          split_changes_other_direction.each { |c|
            condensed_changes[0].delete(c)
          }
        end
      end

      {
        both: both,
        south: condensed_changes[1],
        north: condensed_changes[0],
      }
    end

    def match_route(current_route_id, reroute_service_change, recent_scheduled_routings, timestamp)
      current = current_routings(timestamp)
      stations = reroute_service_change.stations_affected.compact
      station_combinations = [stations]
      if tr = interchangeable_transfers[stations.first]
        tr.each do |t|
          station_combinations << [t.from_stop_internal_id].concat(stations[1...stations.length])
        end
      end
      if tr = interchangeable_transfers[stations.last]
        tr.each do |t|
          station_combinations << stations[0...stations.length - 1].concat([t.from_stop_internal_id])
        end
      end

      route_pair = nil
      current_route_routings = { current_route_id => current[current_route_id] }
      recent_route_routings = { current_route_id => recent_scheduled_routings }
      current_evergreen_routings = { current_route_id => evergreen_routings[current_route_id] }
      [current_route_routings, recent_route_routings, current_evergreen_routings, current, evergreen_routings].each do |routing_set|
        route_pair = routing_set.find do |route_id, direction|
          direction&.any? do |_, routings|
            station_combinations.any? do |sc|
              routings.any? {|r| r.each_cons(sc.length).any?(&sc.method(:==))}
            end
          end
        end
        break if route_pair
      end

      if route_pair
        reroute_service_change.related_routes = [route_pair[0]]
        return
      end

      route_pairs = []

      [current, evergreen_routings].each do |routing_set|
        (0..1).each do |j|
          ((1 + j)...stations.size - 1).each_with_index do |i|
            first_station_sequence = stations[0..(i - j)]
            second_station_sequence = stations[i..stations.size]

            route_pairs = [first_station_sequence, second_station_sequence].map do |station_sequence|
              route_pair = routing_set.find do |route_id, direction|
                route_id[0] != current_route_id[0] && direction.any? do |_, routings|
                  routings.any? {|r| r.each_cons(station_sequence.length).any?(&station_sequence.method(:==))}
                end
              end
              route_pair
            end
            break if route_pairs.compact.size == 2
          end
          break if route_pairs.compact.size == 2
        end
        break if route_pairs.compact.size == 2
      end
      reroute_service_change.related_routes = route_pairs.map {|r| r[0] } if route_pairs.compact.size == 2
    end

    def truncate_service_change_overlaps_with_different_routing?(service_change, routings)
      if service_change.begin_of_route?
        routings.any? do |r|
          next if r == service_change.routing
          i = r.index(service_change.destination)
          i && i > 0
        end
      else
        routings.any? do |r|
          next if r == service_change.routing
          i = r.index(service_change.first_station)
          i && i < r.size - 1
        end
      end
    end

    def current_routings(timestamp)
      from_cache = RedisStore.current_routings
      if from_cache
        parsed_from_cache = JSON.parse(from_cache)
        if timestamp - parsed_from_cache['timestamp'] < 60
          return parsed_from_cache.except('timestamp')
        end
      end

      refresh_routings(timestamp)
    end

    def refresh_routings(timestamp)
      puts "Refresh current routings"
      data = Scheduled::Trip.soon_grouped(timestamp, nil).map { |route_id, trips_by_direction|
        [route_id, trips_by_direction.map { |direction, trips|
          potential_routings = trips.map { |t|
            t.stop_times.not_past.pluck(:stop_internal_id)
          }.uniq
          result = potential_routings.select { |selected_routing|
            others = potential_routings - [selected_routing]
            selected_routing.length > 0 && others.none? {|o| o.each_cons(selected_routing.length).any?(&selected_routing.method(:==))}
          }
          [direction,  result]
        }.to_h]
      }.to_h
      RedisStore.set_current_routings(data.merge(timestamp: timestamp).to_json)

      data
    end

    def evergreen_routings
      from_cache = RedisStore.evergreen_routings
      return JSON.parse(from_cache) if from_cache

      puts "Get evergreen routings"
      ref_time = Scheduled::CalendarException.next_weekday.to_time.change(hour: 12).to_i
      data = Scheduled::Trip.soon_grouped(ref_time, nil).map { |route_id, trips_by_direction|
        [route_id, trips_by_direction.map { |direction, trips|
          potential_routings = trips.map { |t|
            t.stop_times.not_past(current_timestamp: ref_time).pluck(:stop_internal_id)
          }.uniq
          result = potential_routings.select { |selected_routing|
            others = potential_routings - [selected_routing]
            selected_routing.length > 0 && others.none? {|o| o.each_cons(selected_routing.length).any?(&selected_routing.method(:==))}
          }
          [direction,  result]
        }.to_h]
      }.to_h
      RedisStore.set_evergreen_routings(data.to_json)

      data
    end

    def interchangeable_transfers
      @interchangeable_transfers ||= Scheduled::Transfer.where("from_stop_internal_id <> to_stop_internal_id and interchangeable_platforms = true").group_by(&:to_stop_internal_id)
    end
  end
end