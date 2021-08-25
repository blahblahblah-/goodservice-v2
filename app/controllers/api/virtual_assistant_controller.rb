class Api::VirtualAssistantController < ApplicationController
  skip_before_action :verify_authenticity_token

  PRONOUNCIATION_MAPPING = {
    "houston" => "ˈhaʊstən",
    "nostrand" => "ˈnoʊstrənd",
    "dyckman" => "daɪkmɪn",
    "schermerhorn" => "ʃɜrmərhərn",
    "kosciuszko" => "ˌkɒʒiˈʊʃkoʊ",
    "tremont" => "tɹimɑnt",
    "dyre" => "ˈdaɪɚ",
    "via" => "ˈviːə",
    "evers" => "ˈɛvərz",
    "avenue n" => "ˈævɪnjuː ɛn",
  }
  TIMESTAMP_TOLERANCE_IN_SECONDS = 150

  private

  def route_status_text(route_id)
    route = Scheduled::Route.find_by!(internal_id: route_id)
    route_name = route.alternate_name && Scheduled::Stop.normalized_partial_name(route.alternate_name) || "#{route_id} train"
    route_name = "Staten Island Railway" if route_name == "SI train"
    route_name.gsub!(/X/, ' Express')
    scheduled = Scheduled::Trip.soon(Time.current.to_i, route_id).present?
    route_data_encoded = RedisStore.route_status(route_id)
    route_data = route_data_encoded ? JSON.parse(route_data_encoded) : {}
    if !route_data['timestamp'] || route_data['timestamp'] <= (Time.current - 5.minutes).to_i
      route_data = {}
    end

    status = route_data['status'] || (scheduled ? 'No Service' : 'Not Scheduled')
    strs = ["The current status of the #{route_name} is #{status}."]

    if route_data.present?
      summaries = route_data['service_change_summaries'].flat_map { |_, summary| summary}.compact + route_data['service_summaries'].map { |_, summary| summary }.compact
      summaries.each do |summary|
        if route_name != "#{route_id} train"
          strs << summary.gsub("to/from", "to and from").gsub(/\//, ' ').gsub(/<#{route_id}>/, route_name).gsub(/<(.*?)>/, '<say-as interpret-as="characters">\1</say-as>').gsub(/\(\((.*?)\)\)/) do |stop_name|
            Scheduled::Stop.normalized_partial_name($1)
          end
        else
          strs << summary.gsub("to/from", "to and from").gsub(/\//, ' ').gsub(/<(.*?)>/, '<say-as interpret-as="characters">\1</say-as>').gsub(/\(\((.*?)\)\)/) do |stop_name|
            Scheduled::Stop.normalized_partial_name($1)
          end
        end
      end
    end

    output = strs.join(" ")
    PRONOUNCIATION_MAPPING.each do |k, v|
      output.gsub!(/\b#{k}\b/, " <phoneme alphabet=\"ipa\" ph=\"#{v}\">#{k}</phoneme> ")
    end

    return output, (["#{route_name} status: #{status}."] + summaries).join("\n\n").gsub(/<|>/, '').gsub(/\(\(|\)\)/, '').gsub(/\s\-\s/, '–')
  end

  def stop_times_text(stop_ids, user_id: nil)
    timestamp = Time.current.to_i

    if stop_ids.size > 1
      routes_with_alternate_names = Scheduled::Route.all.where("alternate_name is not null").to_h do |r|
        [r.internal_id, r]
      end
      stops = stop_ids.map { |id| Scheduled::Stop.find_by(internal_id: id) }
      strs = stops.map { |stop|
        routes_stopped_ids = Api::SlackController.routes_stop_at(stop.internal_id, timestamp)
        routes_stopped = routes_stopped_ids.map do |route_id|
          route_name = (routes_with_alternate_names[route_id] && Scheduled::Stop.normalized_partial_name(routes_with_alternate_names[route_id].alternate_name)) || "<say-as interpret-as='characters'>#{route_id}</say-as>"
          route_name = "Staten Island Railway" if route_name == "SI"
          route_name.gsub!(/X/, ' Express')
          route_name
        end
        if routes_stopped.size > 1
          routes_stopped.last.prepend("and ") if routes_stopped.size > 1
          "#{stop.normalized_full_name(separator: "<break strength='weak'/>")} (currently served by #{routes_stopped.join(" ")} trains)? "
        elsif routes_stopped.size == 1
          "#{stop.normalized_full_name(separator: "<break strength='weak'/>")} (currently served by the #{routes_stopped.first} train)? "
        else
          "#{stop.normalized_full_name(separator: "<break strength='weak'/>")} (not currently in service)? "
        end
      }
      text = stops.map { |stop|
        routes_stopped_ids = Api::SlackController.routes_stop_at(stop.internal_id, timestamp)
        routes_stopped = routes_stopped_ids.map do |route_id|
          route_name = (routes_with_alternate_names[route_id] && routes_with_alternate_names[route_id].alternate_name) || route_id
          route_name = "SIR" if route_name == "SI"
          route_name
        end
        stop_name = stop.secondary_name ? "#{stop.stop_name.gsub(/ - /, '–')} (#{stop.secondary_name})" : stop.stop_name.gsub(/ - /, '–')
        if routes_stopped.size >= 1
          "- #{stop_name} - #{routes_stopped.join("/")}"
        else
          "- #{stop_name} - No Service"
        end
      }
      strs.last.prepend("or ")
      output = strs.join(", ")
      PRONOUNCIATION_MAPPING.each do |k, v|
        output.gsub!(/\b#{k}\b/, "<phoneme alphabet=\"ipa\" ph=\"#{v}\">#{k}</phoneme>")
      end
      output_text = "Did you mean...?\n\n" + text.join("\n\n")

      return "There is more than one station with that name. Do you mean #{output}", output_text
    else
      stop_id = stop_ids.first
      upcoming_arrival_times_response(stop_id, user_id: user_id)
    end
  end

  def upcoming_arrival_times_response(stop_id, user_id: nil)
    timestamp = Time.current.to_i
    routes_stopped = Api::SlackController.routes_stop_at(stop_id, timestamp)
    routes_with_alternate_names = Scheduled::Route.all.where("alternate_name is not null").to_h do |r|
      [r.internal_id, r]
    end
    elevator_advisories_str = RedisStore.elevator_advisories
    route_trips = routes_stopped.to_h do |route_id|
      [route_id, RedisStore.processed_trips(route_id)]
    end
    travel_times_data = RedisStore.travel_times
    travel_times = travel_times_data ? Marshal.load(travel_times_data) : {}
    trips_by_routes_array = routes_stopped.map do |route_id|
      marshaled_trips = route_trips[route_id]
      next unless marshaled_trips
      Marshal.load(marshaled_trips)
    end
    elevator_advisories = elevator_advisories_str ? JSON.parse(elevator_advisories_str) : {}
    trips = [1, 3].to_h { |direction|
      [direction, trips_by_routes_array.map { |route_hash|
        route_id = route_hash.values.map(&:values)&.first&.first&.first&.route_id
        actual_direction = Api::StopsController.determine_direction(direction, stop_id, route_id)
        next unless route_hash[actual_direction]
        [route_id, route_hash[actual_direction]&.values&.flatten&.uniq { |t| t.id }.select{ |t| t.upcoming_stops(time_ref: timestamp)&.include?(stop_id)}.map {|t| Api::SlackController.transform_trip(stop_id, t, travel_times, timestamp)}.sort_by { |t| t[:arrival_time]}[0..2]]
      }]
    }

    stop = Scheduled::Stop.find_by(internal_id: stop_id)
    strs = ["Upcoming arrival times for #{stop.normalized_full_name(separator: "<break strength='weak'/>")}."]
    text = [stop.secondary_name ? "#{stop.stop_name.gsub(/ - /, '–')} (#{stop.secondary_name})" : stop.stop_name.gsub(/ - /, '–')]

    trips.each do |_, routes|
      routes.each do |route_id, trips|
        route_name = route_id
        pronounceable_route_name = "<say-as interpret-as='characters'>#{route_id}</say-as>"

        if routes_with_alternate_names[route_id]
          route_name = routes_with_alternate_names[route_id].alternate_name
          pronounceable_route_name = Scheduled::Stop.normalized_partial_name(routes_with_alternate_names[route_id].alternate_name)
        end

        if route_name == "SI"
          route_name = "SIR"
          pronounceable_route_name = "Staten Island Railway"
        end

        pronounceable_route_name.gsub!(/X/, ' Express')
        if trips.present?
          first_trip_destination = Scheduled::Stop.find_by(internal_id: trips.first[:destination_stop])
          second_trip_destination = trips.second && Scheduled::Stop.find_by(internal_id: trips.second[:destination_stop])

          if trips.size == 1 || first_trip_destination != second_trip_destination
            eta = (trips.first[:arrival_time] / 60).round
            if eta < 1
              strs << "Next #{pronounceable_route_name} train to #{first_trip_destination.normalized_name} is now arriving."
              text << "#{route_name} to #{first_trip_destination.stop_name.gsub(/ - /, '–')}: due."
            else
              strs << "Next #{pronounceable_route_name} train to #{first_trip_destination.normalized_name} arrives in #{eta} #{"minute".pluralize(eta)}."
              text << "#{route_name} to #{first_trip_destination.stop_name.gsub(/ - /, '–')}: #{eta} #{"min".pluralize(eta)}."
            end
          end

          if trips.size > 1
            first_eta = (trips.first[:arrival_time] / 60).round
            second_eta = (trips.second[:arrival_time] / 60).round
            if first_trip_destination != second_trip_destination
              if second_eta < 1
                strs << "Next #{pronounceable_route_name} train to #{second_trip_destination.normalized_name} is now arriving."
                text << "#{route_name} to #{second_trip_destination.stop_name.gsub(/ - /, '–')}: due."
              else
                strs << "Next #{pronounceable_route_name} train to #{second_trip_destination.normalized_name} arrives in #{second_eta} #{"minute".pluralize(second_eta)}."
                text << "#{route_name} to #{second_trip_destination.stop_name.gsub(/ - /, '–')}: #{eta} #{"min".pluralize(eta)}."
              end
            else
              if first_eta < 1
                if second_eta < 1
                  strs << "Next #{pronounceable_route_name} train to #{first_trip_destination.normalized_name} is now arriving."
                  text << "#{route_name} to #{first_trip_destination.stop_name.gsub(/ - /, '–')}: due."
                else
                  strs << "Next #{pronounceable_route_name} train to #{first_trip_destination.normalized_name} is now arriving, following in #{second_eta} #{"minute".pluralize(second_eta)}."
                  text << "#{route_name} to #{first_trip_destination.stop_name.gsub(/ - /, '–')}: due, #{second_eta} #{"min".pluralize(second_eta)}."
                end
              else
                strs << "Next #{pronounceable_route_name} trains to #{first_trip_destination.normalized_name} arrive in #{first_eta} #{"minute".pluralize(first_eta)} and #{second_eta} #{"minute".pluralize(second_eta)}."
                text << "#{route_name} to #{first_trip_destination.stop_name.gsub(/ - /, '–')}: #{first_eta} #{"min".pluralize(first_eta)}, #{second_eta} #{"min".pluralize(second_eta)}."
              end
            end
          end
        end
      end
    end

    RedisStore.set_alexa_most_recent_stop(user_id, stop_id) if user_id

    if strs.size == 1
      strs = ["There are no upcoming train arrivals for #{stop.normalized_full_name}."]
      text << "No upcoming arrivals."
    end

    if elevator_advisories[stop.internal_id].present?
      elevator_advisories[stop.internal_id].each { |a|
        strs << "Elevator for #{Scheduled::Stop.normalized_partial_name(a)} is out of service.".gsub(/\//, ' ')
        text << "Elevator for #{a} is out of service."
      }
    end

    output = strs.join(" ")
    PRONOUNCIATION_MAPPING.each do |k, v|
      output.gsub!(/\b#{k}\b/, "<phoneme alphabet=\"ipa\" ph=\"#{v}\">#{k}</phoneme>")
    end

    return output, text.join("\n\n")
  end

  def delays_text
    routes_with_alternate_names = Scheduled::Route.all.where("alternate_name is not null").to_h do |r|
      [r.internal_id, r]
    end
    delayed_routes = RedisStore.route_status_summaries&.to_h { |k, v|
      data = JSON.parse(v)
      r = routes_with_alternate_names[k]
      [r ? r.alternate_name : k, data['timestamp'] && data['timestamp'] >= (Time.current - 5.minutes).to_i && data['status'] == 'Delay']
    }.select { |k, v| v }.map { |k, _| k }.sort

    if delayed_routes.any?
      "Delays detected on #{delayed_routes.join(', ')} trains."
    else
      "There are no delays currently detected."
    end
  end
end