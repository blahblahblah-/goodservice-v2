class Api::AlexaController < ApplicationController
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
  }
  TIMESTAMP_TOLERANCE_IN_SECONDS = 150

  def index
    verify_timestamp
    verify_header
    if params["alexa"]["request"]["type"] == "IntentRequest"
      case params["alexa"]["request"]["intent"]["name"]
      when "LookupTrainTimes"
        data = stop_times_response
      when "LookupDelays"
        data = delays_response
      when "LookupTrainStatus"
        data = route_status_response
      when "AMAZON.CancelIntent", "AMAZON.NavigateHomeIntent", "AMAZON.StopIntent"
        data = quit_response
      else
        data = help_response
      end
    else
      data = help_response
    end

    render json: data
  rescue => e
    p e.message
    p e.backtrace.join("\n")
    render nothing: true, status: :bad_request
  end

  private

  def verify_timestamp
    timestamp = DateTime.iso8601(params["alexa"]["request"]["timestamp"])
    day_diff = (timestamp - DateTime.current)
    seconds_diff = (day_diff * 24 * 60 * 60).to_i.abs
    if seconds_diff > TIMESTAMP_TOLERANCE_IN_SECONDS
      raise "Error invalid timestamp"
    end
  end

  def verify_header
    verify_url
    verify_cert
  end

  def verify_url
    uri = parsed_cert_uri

    if uri.scheme != "https"
      raise "URI protocol #{uri.scheme} is not https"
    end

    if uri.host.upcase != "s3.amazonaws.com".upcase
      raise "URI host #{uri.host} is not s3.amazonaws.com"
    end

    if uri.port != 443
      raise "URI port #{uri.port} is not 443"
    end

    if uri.path[0..9] != "/echo.api/"
      raise "URI path #{uri.path} does not start with /echo.api/"
    end
  end

  def verify_cert
    response = HTTParty.get(request.headers["SignatureCertChainUrl"])
    raise "Invalid cert response code" unless response.code == 200
    cert = OpenSSL::X509::Certificate.new(response.body)
    current_time = Time.current

    if cert.not_before > current_time || cert.not_after < current_time
      raise "Certificate is outdated for #{cert.not_before} to #{cert.not_after}"
    end

    if !cert.subject.to_a.flatten.include?("echo-api.amazon.com")
      raise "Invalid Subject Alternative Names #{cert.subject.to_a.flatten}"
    end

    signature = Base64.decode64(request.headers["Signature"])
    if !cert.public_key.verify(OpenSSL::Digest::SHA1.new, signature, request.body.read)
      raise "Signature does not match request hash"
    end
  end

  def parsed_cert_uri
    uri_str = request.headers["SignatureCertChainUrl"]
    URI.parse(uri_str)
  end

  def stop_times_response
    full_user_id = params["alexa"]["session"]["user"] && params["alexa"]["session"]["user"]["userId"]
    user_id = full_user_id && full_user_id.split(".").last

    if !params["alexa"]["request"]["intent"]["slots"]["station"]["resolutions"]
      if user_id
        stop_id = RedisStore.alexa_most_recent_stop(user_id)
        if stop_id
          data = upcoming_arrival_times_response(stop_id, user_id)
        else
          data = {
            version: "1.0",
            response: {
              outputSpeech: {
                type: "PlainText",
                text: "Please specify which station you would like to lookup upcoming train arrival times. For example, you can say: ask good service, when are the next trains arriving at bedford avenue?"
              }
            }
          }
        end
      else
        data = {
            version: "1.0",
            response: {
              outputSpeech: {
                type: "PlainText",
                text: "Please specify which station you would like to lookup upcoming train arrival times. For example, you can say: ask good service, when are the next trains arriving at bedford avenue?"
              }
            }
          }
      end
    else
      stop_resolution_code = params["alexa"]["request"]["intent"]["slots"]["station"]["resolutions"]["resolutionsPerAuthority"].first["status"]["code"]

      if stop_resolution_code == "ER_SUCCESS_NO_MATCH"
        value = params["alexa"]["request"]["intent"]["slots"]["station"]["value"]
        RedisStore.add_alexa_stop_query_miss(value)
        data = {
          version: "1.0",
          response: {
            outputSpeech: {
              type: "PlainText",
              text: "Sorry, there are no stations named #{value}. Please try again."
            }
          }
        }
      else
        stop_ids = params["alexa"]["request"]["intent"]["slots"]["station"]["resolutions"]["resolutionsPerAuthority"].first["values"].first["value"]["id"].split(",")
        timestamp = Time.current.to_i

        if stop_ids.size > 1
          routes_with_alternate_names = Scheduled::Route.all.where("alternate_name is not null").to_h do |r|
            [r.internal_id, r]
          end
          stops = stop_ids.map { |id| Scheduled::Stop.find_by(internal_id: id) }
          strs = stops.map { |stop|
            routes_stopped_ids = Api::SlackController.routes_stop_at(stop.internal_id, timestamp)
            routes_stopped = routes_stopped_ids.map do |route_id|
              route_name = (routes_with_alternate_names[route_id] && Scheduled::Stop.normalized_partial_name(routes_with_alternate_names[route_id].alternate_name)) || route_id
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
          strs.last.prepend("or ")
          output = strs.join(", ")
          PRONOUNCIATION_MAPPING.each do |k, v|
            output.gsub!(/\b#{k}\b/, "<phoneme alphabet=\"ipa\" ph=\"#{v}\">#{k}</phoneme>")
          end

          data = {
            version: "1.0",
            response: {
              outputSpeech: {
                type: "SSML",
                ssml: "<speak>There is more than one station with that name. Do you mean #{output}</speak>"
              }
            }
          }
        else
          stop_id = stop_ids.first
          data = upcoming_arrival_times_response(stop_id, user_id)
        end
      end
    end
  end

  def delays_response
    routes_with_alternate_names = Scheduled::Route.all.where("alternate_name is not null").to_h do |r|
      [r.internal_id, r]
    end
    delayed_routes = RedisStore.route_status_summaries&.to_h { |k, v|
      data = JSON.parse(v)
      r = routes_with_alternate_names[k]
      [r ? r.alternate_name : k, data['timestamp'] && data['timestamp'] >= (Time.current - 5.minutes).to_i && data['status'] == 'Delay']
    }.select { |k, v| v }.map { |k, _| k }.sort

    if delayed_routes.any?
      {
        version: "1.0",
        response: {
          outputSpeech: {
            type: "PlainText",
            text: "Delays detected on #{delayed_routes.join(', ')} trains"
          }
        }
      }
    else
      {
        version: "1.0",
        response: {
          outputSpeech: {
            type: "PlainText",
            text: "There are no delays currently detected."
          }
        }
      }
    end
  end

  def route_status_response
    if !params["alexa"]["request"]["intent"]["slots"]["train"]["resolutions"]
      output = "Please specify which train you would like to lookup the status for. For example, you can say: ask good service, what's the status of the A train?"
    else
      train_resolution_code = params["alexa"]["request"]["intent"]["slots"]["train"]["resolutions"]["resolutionsPerAuthority"].first["status"]["code"]

      if train_resolution_code == "ER_SUCCESS_NO_MATCH"
        value = params["alexa"]["request"]["intent"]["slots"]["train"]["value"]
        output = "Sorry, there are no trains named #{value}. Please try again."
      else
        route_id = params["alexa"]["request"]["intent"]["slots"]["train"]["resolutions"]["resolutionsPerAuthority"].first["values"].first["value"]["id"]
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
            strs << summary.gsub(/\//, ' ').gsub(/<(.*?)>/, '\1').gsub(/\(\((.*?)\)\)/) do |stop_name|
              Scheduled::Stop.normalized_partial_name($1)
            end
          end
        end

        output = strs.join(" ")
        PRONOUNCIATION_MAPPING.each do |k, v|
          output.gsub!(/\b#{k}\b/, "<phoneme alphabet=\"ipa\" ph=\"#{v}\">#{k}</phoneme>")
        end
      end
    end


    {
      version: "1.0",
      response: {
        outputSpeech: {
          type: "SSML",
          ssml: "<speak>#{output}</speak>"
        }
      }
    }
  end

  def quit_response
    {
      version: "1.0",
      response: {
        shouldEndSession: true,
      }
    }
  end

  def help_response
    {
      version: "1.0",
      response: {
        outputSpeech: {
          type: "PlainText",
          text: "You can use good service to check the status of a new york city subway train, or to look up upcoming departure times for a particular station. "\
            "For example, you can say: Ask good service, what is the status of the A train? Or, ask good service, when are the next trains arriving at Bedford Avenue? "\
            "Or, ask good service, what trains are delayed?"
        }
      }
    }
  end

  def upcoming_arrival_times_response(stop_id, user_id)
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
    strs = ["Here are the upcoming arrival times for #{stop.normalized_full_name(separator: "<break strength='weak'/>")}."]

    trips.each do |_, routes|
      routes.each do |route_id, trips|
        route_name = (routes_with_alternate_names[route_id] && Scheduled::Stop.normalized_partial_name(routes_with_alternate_names[route_id].alternate_name)) || route_id
        route_name = "Staten Island Railway" if route_name == "SI"
        route_name.gsub!(/X/, ' Express') if route_name
        if trips.present?
          first_trip_destination = Scheduled::Stop.find_by(internal_id: trips.first[:destination_stop])
          eta = (trips.first[:arrival_time] / 60).round
          if eta < 1
            strs << "The next #{first_trip_destination.normalized_name}-bound #{route_name} train is now arriving."
          else
            strs << "The next #{first_trip_destination.normalized_name}-bound #{route_name} train arrives in #{eta} #{"minute".pluralize(eta)}."
          end

          if trips.size > 1
            second_trip_destination = Scheduled::Stop.find_by(internal_id: trips.second[:destination_stop])
            eta = (trips.second[:arrival_time] / 60).round
            if first_trip_destination != second_trip_destination
              if eta < 1
                strs << "The next #{second_trip_destination.normalized_name}-bound #{route_name} train is now arriving."
              else
                strs << "The next #{second_trip_destination.normalized_name}-bound #{route_name} train arrives in #{eta} #{"minute".pluralize(eta)}."
              end
            else
              if eta < 1
                strs << "The following train is now arriving."
              else
                strs << "The following in #{eta} #{"minute".pluralize(eta)}."
              end
            end
          end
        end
      end
    end

    RedisStore.set_alexa_most_recent_stop(user_id, stop_id) if user_id

    if strs.size == 1
      strs = ["There are no upcoming train arrivals for #{stop.normalized_full_name}."]
    end

    if elevator_advisories[stop.internal_id].present?
      elevator_advisories[stop.internal_id].each { |a|
        strs << "The elevator for #{Scheduled::Stop.normalized_partial_name(a)} is out of service.".gsub(/\//, ' ')
      }
    end

    output = strs.join(" ")
    PRONOUNCIATION_MAPPING.each do |k, v|
      output.gsub!(/\b#{k}\b/, "<phoneme alphabet=\"ipa\" ph=\"#{v}\">#{k}</phoneme>")
    end

    {
      version: "1.0",
      response: {
        outputSpeech: {
          type: "SSML",
          ssml: "<speak>#{output}</speak>"
        }
      }
    }
  end
end