class ServiceChangeAnalyzer
  NORTH = {
    route_direction: 1,
    scheduled_direction: 0,
    suffix: 'N',
    sym: :north,
  }

  SOUTH = {
    route_direction: 3,
    scheduled_direction: 1,
    suffix: 'S',
    sym: :south,
  }

  CITY_HALL_STOP = "R24" # Use to disguish re-routes via Manhattan Bridge/Lower Manhattan as not just Local <=> Express, but re-routes

  CANAL_TO_ATLANTIC_VIA_BRIDGE_WITH_DEKALB = [["Q01", "R30", "R31"], ["Q01", "R30", "D24"]]

  CANAL_TO_ATLANTIC_VIA_BRIDGE_WITH_DEKALB_BOTH_DIRS = CANAL_TO_ATLANTIC_VIA_BRIDGE_WITH_DEKALB + CANAL_TO_ATLANTIC_VIA_BRIDGE_WITH_DEKALB.map {|r| r.reverse}

  DEKALB_AV_STOP = "R30"

  ATLANTIC_AV_STOPS = ["R31", "R24"]

  class << self
    def service_change_summary(route_id, actual_routings, scheduled_routings, recent_scheduled_routings, timestamp)
      direction_changes = [NORTH, SOUTH].map do |direction|
        changes = []
        actual = actual_routings[direction[:route_direction]]
        scheduled = scheduled_routings[direction[:scheduled_direction]]
        long_term_routings = LongTermServiceChangeRoutingManager.get_routing(route_id, direction[:sym])

        if !actual || actual.empty?
          if !scheduled || scheduled.empty?
            changes << [ServiceChanges::NotScheduledServiceChange.new(direction[:route_direction], [], nil, nil)]
          else
            changes << [ServiceChanges::NoTrainServiceChange.new(direction[:route_direction], [], nil, nil)]
          end
        else
          actual.each do |actual_routing|
            proposed_changes = [false, true].map do |long_term_change|
              next [] unless !long_term_change || long_term_routings.present?
              routing_changes = []
              ongoing_service_change = nil
              scheduled_routings_to_use = scheduled
              if long_term_change == true
                scheduled_routings_to_use = long_term_routings
              end

              scheduled_routing = scheduled_routings_to_use&.min_by { |sr| [(actual_routing - sr).size, (sr - actual_routing).size] }

              if !scheduled_routing
                next [ServiceChanges::ReroutingServiceChange.new(direction[:route_direction], actual_routing, actual_routing.first, actual_routing)]
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
                        if array_of_skipped_stations.include?(CITY_HALL_STOP)
                          routing_changes << ServiceChanges::ReroutingServiceChange.new(direction[:route_direction], [previous_actual_station, actual_station], actual_routing.first, actual_routing)
                        else
                          routing_changes << ServiceChanges::LocalToExpressServiceChange.new(direction[:route_direction], array_of_skipped_stations, actual_routing.first, actual_routing)
                        end
                        scheduled_index = scheduled_index_to_current_station + 1
                        previous_scheduled_station = actual_station
                      end
                    else
                      if (actual_routing.include?(scheduled_station) || interchangeable_transfers[scheduled_station]&.any? { |t| actual_routing.include?(t.from_stop_internal_id) }) && previous_actual_station
                        if routing_changes.last&.class == ServiceChanges::ExpressToLocalServiceChange && !CANAL_TO_ATLANTIC_VIA_BRIDGE_WITH_DEKALB_BOTH_DIRS.include?(routing_changes.last.stations_affected) && actual_routing[actual_index - 2, 2].include?(routing_changes.last.last_station)
                          ongoing_service_change = routing_changes.pop
                          ongoing_service_change.stations_affected << actual_station if ongoing_service_change.last_station != actual_station
                        else
                          ongoing_service_change = ServiceChanges::ExpressToLocalServiceChange.new(direction[:route_direction], [previous_actual_station, actual_station].compact, actual_routing.first, actual_routing)
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
                    if actual_station == CITY_HALL_STOP
                      ongoing_service_change = ongoing_service_change.convert_to_rerouting
                    end
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
              elsif scheduled_routing[scheduled_index] && scheduled_routing.size > scheduled_index
                routing_changes << ServiceChanges::TruncatedServiceChange.new(direction[:route_direction], scheduled_routing[scheduled_index - 1..scheduled_routing.length].concat([nil]), actual_routing.first, actual_routing)
              end
              routing_changes
            end

            if long_term_routings.present?
              long_term_changes = (proposed_changes.second - proposed_changes.first).map { |c|
                c.long_term_override = true
                c
              }
              long_term_changes.concat(proposed_changes.first)
              changes << long_term_changes
            else
              changes << proposed_changes.first
            end
          end
        end

        changes.each do |changes_by_routing|
          changes_by_routing.each do |c|
            if c.is_a?(ServiceChanges::ReroutingServiceChange)
              match_route(route_id, c, recent_scheduled_routings, timestamp, c.begin_of_route?)
            elsif c.is_a?(ServiceChanges::ExpressToLocalServiceChange)
              trim_express_to_local_service_change(c, timestamp)
            end
          end
        end

        if actual && actual.size > 1
          unique_actual_routings = actual.uniq { |a|
            "#{a.first}-#{a.last}"
          }
          actual_tuples = unique_actual_routings.select { |a1|
            unique_actual_routings.none? { |a2| a1 != a2 && a2.include?(a1.first) && a2.include?(a1.last) }
          }.map { |a| [a.first, a.last] }.uniq
          scheduled_tuples = scheduled&.map { |s| [s.first, s.last] }&.uniq || []
          long_term_change = false
          if long_term_routings.present?
            scheduled_tuples = long_term_routings&.map { |s| [s.first, s.last] }&.uniq || []
            long_term_change = true
          end

          if actual_tuples.size > 1 && (scheduled_tuples.size != actual_tuples.size || !scheduled_tuples.all? { |s| actual_tuples.any? { |a| a == s }})
            evergreen_current_routing = evergreen_routings[route_id][direction[:scheduled_direction].to_s].max_by(&:size)
            sorted_actual_tuples = evergreen_current_routing.flat_map { |s| actual_tuples.filter { |at| at.include?(s) }}.uniq
            remaining_tuples = actual_tuples - sorted_actual_tuples
            sorted_actual_tuples = sorted_actual_tuples.concat(remaining_tuples)

            split_change = ServiceChanges::SplitRoutingServiceChange.new(direction[:route_direction], sorted_actual_tuples, long_term_change)
            changes.each_with_index do |changes_by_routing, i|
              rerouting_changes = changes_by_routing.select { |c| c.is_a?(ServiceChanges::ReroutingServiceChange) && (c.begin_of_route? || c.end_of_route?)}
              related_routes = rerouting_changes.flat_map { |c| c.related_routes }.compact.uniq.select{ |r| r != route_id }
              if related_routes.size > 0
                split_change.related_routes_by_segments[i] = related_routes
              end
            end
            changes.first << split_change
          end
        end
        changes.map { |r| r.select { |c|
          !(c.is_a?(ServiceChanges::TruncatedServiceChange) || (c.is_a?(ServiceChanges::ReroutingServiceChange) && (c.begin_of_route? || c.end_of_route?))) ||
          (!truncate_service_change_overlaps_with_different_routing?(c, actual) &&
            !changes.flatten.any?{ |c2| c2.is_a?(ServiceChanges::SplitRoutingServiceChange)})}}
      end

      both = []

      condensed_changes = direction_changes.map do |d|
        flatten_changes = d.flatten
        changes = flatten_changes.select.with_index { |c1, i|
          if amended_change = flatten_changes[0...i].find { |c2| c1.eql?(c2) }
            amended_change.destinations = [amended_change.destinations + c1.destinations].flatten.compact.uniq
            false
          else
            true
          end
        }

        changes.each do |c|
          c.affects_some_trains = d.each_index.select { |i|
            !d[i].include?(c) && c.applicable_to_routing?(actual_routings[c.direction][i].dup.unshift(nil).push(nil))
          }.present?
        end

        changes.sort_by { |c| c.affects_some_trains ? 1 : 0 }
      end

      condensed_changes[1].select! do |c1|
        if other_direction = condensed_changes[0].find { |c2|
            c1.class != ServiceChanges::SplitRoutingServiceChange &&
            (c1.class == c2.class || [c1.class, c2.class].all? { |klass| [ServiceChanges::ReroutingServiceChange, ServiceChanges::TruncatedServiceChange].include?(klass) }) &&
            (
              ([c1.class, c2.class].any? { |klass| klass == ServiceChanges::ReroutingServiceChange } && c1.routing.first == c2.routing.last && c1.routing.last == c2.routing.first) ||
              (c1.first_station == c2.last_station || interchangeable_transfers[c1.first_station]&.any?{ |t| t.from_stop_internal_id == c2.last_station }) &&
              (c1.last_station == c2.first_station || interchangeable_transfers[c1.last_station]&.any?{ |t| t.from_stop_internal_id == c2.first_station })
            )
          }
          condensed_changes[0].delete(other_direction)
          both << c1
          false
        else
          true
        end
      end

      split_changes = condensed_changes[1].find{ |c| c.is_a?(ServiceChanges::SplitRoutingServiceChange) }
      split_changes_other_direction = condensed_changes[0].find{ |c| c.is_a?(ServiceChanges::SplitRoutingServiceChange) }

      if split_changes && split_changes_other_direction
        if split_changes.match?(split_changes_other_direction)
          both << split_changes
          condensed_changes[1].delete(split_changes)
          condensed_changes[0].delete(split_changes_other_direction)

        end
      end

      {
        both: both,
        north: condensed_changes[0],
        south: condensed_changes[1],
      }
    end

    def match_route(current_route_id, reroute_service_change, recent_scheduled_routings, timestamp, is_begin_of_route)
      current = current_routings(timestamp)
      long_term_routings = LongTermServiceChangeRoutingManager.get_all_routings
      stations = reroute_service_change.stations_affected.compact
      stations -= [DEKALB_AV_STOP]
      station_combinations = [stations.dup]
      tr1 = interchangeable_transfers[stations.first]&.map(&:from_stop_internal_id)
      tr2 = interchangeable_transfers[stations.last]&.map(&:from_stop_internal_id)
      if tr1 && tr2
        ([stations.first] + tr1).each do |t1|
          ([stations.last] + tr2).each do |t2|
            station_combinations << [t1].concat(stations[1...stations.length - 1]).concat([t2])
          end
        end
      elsif tr1
        tr1.each do |t1|
          station_combinations << [t1].concat(stations[1...stations.length])
        end
      elsif tr2
        tr2.each do |t2|
          station_combinations << stations[0...stations.length - 1].concat([t2])
        end
      end

      route_pair = nil
      current_route_routings = { current_route_id => current[current_route_id] }
      current_long_term_routings = {current_route_id => long_term_routings[current_route_id] }
      recent_route_routings = { current_route_id => recent_scheduled_routings }
      current_evergreen_routings = { current_route_id => evergreen_routings[current_route_id] }
      [current_long_term_routings, long_term_routings, current_route_routings, recent_route_routings, current_evergreen_routings, current, evergreen_routings].each do |routing_set|
        route_pair = routing_set.find do |route_id, direction|
          next false if !is_begin_of_route && route_id == current_route_id
          direction&.any? do |_, routings|
            station_combinations.any? do |sc|
              routings.any? do |r|
                routing = r
                routing -= [DEKALB_AV_STOP]
                routing.each_cons(sc.length).any?(&sc.method(:==))
              end
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

      [long_term_routings, current, evergreen_routings].each do |routing_set|
        (0..1).each do |j|
          ((1 + j)...stations.size - 1).each_with_index do |i|
            first_station_sequence = stations[0..(i - j)] - [DEKALB_AV_STOP]
            second_station_sequence = stations[i..stations.size] - [DEKALB_AV_STOP]

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

      if route_pairs.compact.size == 2
        reroute_service_change.related_routes = route_pairs.map {|r| r[0] }.uniq
        return
      end

      [long_term_routings, current, evergreen_routings].each do |routing_set|
        (0...stations.size - 2).each_with_index do |i|
          (i...stations.size - 1).each_with_index do |j|
            first_station_sequence = stations[0..i] - [DEKALB_AV_STOP]
            second_station_sequence = stations[i..j] - [DEKALB_AV_STOP]
            third_station_sequence = stations[j..stations.size] - [DEKALB_AV_STOP]

            route_pairs = [first_station_sequence, second_station_sequence, third_station_sequence].map do |station_sequence|
              route_pair = routing_set.find do |route_id, direction|
                route_id[0] != current_route_id[0] && direction.any? do |_, routings|
                  routings.any? {|r| r.each_cons(station_sequence.length).any?(&station_sequence.method(:==))}
                end
              end
              route_pair
            end
            break if route_pairs.compact.size == 3
          end
          break if route_pairs.compact.size == 3
        end
        break if route_pairs.compact.size == 3
      end

      if route_pairs.compact.size == 3
        reroute_service_change.related_routes = route_pairs.map {|r| r[0] }.uniq
        return
      end
    end

    def trim_express_to_local_service_change(express_to_local_service_change, timestamp)
      all_routings = current_routings(timestamp)
      all_routings.merge!(LongTermServiceChangeRoutingManager.get_all_routings)
      stations_sequence = express_to_local_service_change.stations_affected
      results = stations_sequence
      found = false

      (0..stations_sequence.size - 1).each do |i|
        [stations_sequence.slice(0, stations_sequence.size - i), stations_sequence.slice(i, stations_sequence.size)].each do |stations|
          if all_routings.any? { |_, routings_by_direction|
            routings_by_direction.any? do |_, routings|
              routings.any? do |routing|
                stations == routing & stations && routing.each_cons(stations.size).any?(&stations.method(:==))
              end
            end
          }
            results = stations
            found = true
            break
          end
        end
        break if found
      end

      express_to_local_service_change.stations_affected = results
    end

    def truncate_service_change_overlaps_with_different_routing?(service_change, routings)
      if service_change.begin_of_route?
        routings.any? do |r|
          next if r == service_change.routing
          i = r.index(service_change.destinations.first)
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