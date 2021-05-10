class Api::AlexaController < ApplicationController
  skip_before_action :verify_authenticity_token

  def index
    return render nothing: true, status: :bad_request unless params["alexa"]["request"]["type"] == "IntentRequest" &&
      params["alexa"]["request"]["intent"]["name"] == "LookupTrainTimes"
    fullUserId = params["alexa"]["session"]["user"] && params["alexa"]["session"]["userId"]
    userId = fullUserId && fullUserId.split(".").last

    if !params["alexa"]["request"]["intent"]["slots"]["station"]["resolutions"]
      if userId
        data = {

        }
      else
        data = {

        }
      end
    else
      stop_ids = params["alexa"]["request"]["intent"]["slots"]["station"]["resolutions"]["resolutionsPerAuthority"].first["values"].first["value"]["id"].split(",")
      timestamp = Time.current.to_i

      if stop_ids.size > 1
        stops = stop_ids.map { |id| Scheduled::Stop.find_by(internal_id: id) }
        strs = stops.map { |stop|
          routes_stopped = Api::SlackController.routes_stop_at(stop.internal_id, timestamp)
          if routes_stopped.size > 1
            routes_stopped.last.prepend("and ") if routes_stopped.size > 1
            "#{stop.normalized_full_name} (currently served by #{routes_stopped.join(" ")} trains)"
          elsif routes_stopped.size == 1
            "#{stop.normalized_full_name} (currently served by the #{routes_stopped.first} train)"
          else
            "#{stop.normalized_full_name} (not currently in service)"
          end
        }
        strs.last.prepend("or ")
        str = strs.join(", ")

        data = {
          version: "1.0",
          response: {
            outputSpeech: {
              type: "PlainText",
              text: "There is more than one station with that name. Do you mean #{str}?"
            }
          }
        }
      else
        stop_id = stop_ids.first
        timestamp = Time.current.to_i
        routes_stopped = Api::SlackController.routes_stop_at(stop_id, timestamp)
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
        strs = ["Here are the upcoming arrival times for #{stop.normalized_full_name}."]

        trips.each do |_, routes|
          routes.each do |route_id, trips|
            if trips.present?
              first_trip_destination = Scheduled::Stop.find_by(internal_id: trips.first[:destination_stop])
              eta = (trips.first[:arrival_time] / 60).round
              if eta < 1
                strs << "The next #{first_trip_destination.normalized_name}-bound #{route_id} train is now arriving."
              else
                strs << "The next #{first_trip_destination.normalized_name}-bound #{route_id} train arrives in #{eta} #{"minutes".pluralize(eta)}."
              end

              if trips.size > 1
                second_trip_destination = Scheduled::Stop.find_by(internal_id: trips.second[:destination_stop])
                eta = (trips.second[:arrival_time] / 60).round
                if first_trip_destination != second_trip_destination
                  if eta < 1
                    strs << "The next #{second_trip_destination.normalized_name}-bound #{route_id} train is now arriving."
                  else
                    strs << "The next #{second_trip_destination.normalized_name}-bound #{route_id} train arrives in #{eta} #{"minutes".pluralize(eta)}."
                  end
                else
                  if eta < 1
                    strs << "The following train is now arriving."
                  else
                    strs << "The following in #{eta} #{"minutes".pluralize(eta)}."
                  end
                end
              end
            end
          end
        end

        if strs.size == 1
          strs = ["There are no upcoming train arrivals for #{stop.normalized_full_name}."]
        end

        if elevator_advisories[stop.internal_id].present?
          elevator_advisories[stop.internal_id].each { |a|
            strs << "The elevator for #{a} is out of service."
          }
        end

        data = {
          version: "1.0",
          response: {
            outputSpeech: {
              type: "PlainText",
              text: strs.join(" ")
            }
          }
        }
      end
    end

    render json: data
  end
end