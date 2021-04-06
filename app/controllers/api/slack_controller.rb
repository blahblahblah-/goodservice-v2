class Api::SlackController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_slack_request

  def index
    query = params[:text]

    if query == 'help'
      result = help_response
    elsif (route = Scheduled::Route.find_by(internal_id: query))
      result = route_response(route)
    elsif query == 'delays'
      result = delays_response
    else
      result = default_response
    end
   
    render json: result
  end

  # Responds to select interactive components
  def query
    payload = JSON.parse(params[:payload]).with_indifferent_access

    uri = URI(payload[:response_url])

    if payload[:actions].first[:action_id] == 'select_route'
      if (route = Scheduled::Route.find_by(internal_id: payload[:actions].first[:selected_option][:value]))
        result = route_response(route)
      end
    elsif payload[:actions].first[:action_id] == 'select_station'
      if (stop = Scheduled::Stop.find_by(internal_id: payload[:actions].first[:selected_option][:value]))
        result = stop_response(stop)
      end
    end

    Net::HTTP.post(uri, result.to_json, "Content-Type" => "application/json")

    render json: result
  end

  private

  def help_response
    route_ids = Scheduled::Route.all.pluck(:internal_id)
    {
      text: "Usage:\n"\
        "_/goodservice_ is the main menu and will bring up select boxes of available routes and stations to then view statuses of.\n"\
        "_/goodservice delays_  displays a list of routes where delays are currently detected.\n"\
        "_/goodservice [route]_ (i.e. _/goodservice A_) is a shortcut to display current status about the route.\n\nRoutes available: #{route_ids.join(" ") }"
    }
  end

  def default_response
    routes = Scheduled::Route.all
    stops = Scheduled::Stop.all
    futures = {}
    REDIS_CLIENT.pipelined do
      futures = stops.to_h { |stop|
        [stop.internal_id, [1, 3].to_h { |direction|
          [direction, RedisStore.routes_stop_at(stop.internal_id, direction, Time.current.to_i)]
        }]
      }
    end

    {
      response_type: "in_channel",
      channel: params[:channel_id],
      blocks:[
        {
          "type": "section",
          "text": {
            "type": "mrkdwn",
            "text": "Check route status"
          },
          "accessory": {
            "type": "static_select",
            "action_id": "select_route",
            "placeholder": {
              "type": "plain_text",
              "text": "Select a route",
            },
            "options": routes.map { |r|
              {
                "text": {
                  "type": "plain_text",
                  "text": (r.name == 'S') ? "S - #{r.alternate_name}" : r.name,
                },
                "value": r.internal_id
              }
            }
          }
        },
        {
          "type": "section",
          "text": {
            "type": "mrkdwn",
            "text": "Check arrival times"
          },
          "accessory": {
            "type": "static_select",
            "action_id": "select_station",
            "placeholder": {
              "type": "plain_text",
              "text": "Select a Station",
            },
            "option_groups": Naturally.sort_by(stops){ |s| "#{s.stop_name} #{s.secondary_name}" }.group_by{ |s|
              if s.stop_name[0].match?(/[[:digit:]]/)
                i = s.stop_name.index(' ')
                number = s.stop_name[0...i].to_i
                if number < 50
                  "1 - 49"
                elsif number < 100
                  "50 - 99"
                else
                  "100+"
                end
              else
                s.stop_name[0]
              end
            }.map { |first_letter, stops_start_with_this_letter|
              {
                "label": {
                  "type": "plain_text",
                  "text": first_letter
                },
                "options": stops_start_with_this_letter.map { |s|
                  routes_stop_at = transform_to_routes_array(futures[s.internal_id])
                  {
                    "text": {
                      "type": "plain_text",
                      "text": (s.secondary_name ? "#{s.stop_name.gsub(/ - /, '–')} (#{s.secondary_name}) - #{routes_stop_at.join(', ')}" : "#{s.stop_name.gsub(/ - /, '–')} - #{routes_stop_at.join(', ')}")
                    },
                    "value": s.internal_id,
                  }
                }
              }
            }
          }
        }
      ]
    }
  end

  def delays_response
    routes_with_alternate_names = Scheduled::Route.all.where("alternate_name is not null").to_h do |r|
      [r.internal_id, r]
    end
    delayed_routes = RedisStore.route_status_summaries&.to_h { |k, v|
      data = JSON.parse(v)
      r = routes_with_alternate_names[k]
      [r ? "#{r.name} - #{r.alternate_name.gsub(" Shuttle", "")}" : k, data['timestamp'] && data['timestamp'] >= (Time.current - 5.minutes).to_i && data['status'] == 'Delay']
    }.select { |k, v| v }.map { |k, _| k }.sort

    if delayed_routes.any?
      {
        response_type: "in_channel",
        channel: params[:channel_id],
        text: "Delays detected on #{delayed_routes.join(', ')} trains"
      }
    else
      {
        response_type: "in_channel",
        channel: params[:channel_id],
        text: "No delays currently detected."
      }
    end
  end

  def route_response(route)
    route_id = route.internal_id
    scheduled = Scheduled::Trip.soon(Time.current.to_i, route_id).present?
    route_data_encoded = RedisStore.route_status(route_id)
    route_data = route_data_encoded ? JSON.parse(route_data_encoded) : {}
    if !route_data['timestamp'] || route_data['timestamp'] <= (Time.current - 5.minutes).to_i
      route_data = {}
    end

    result = [
      {
        "type": "section",
        "text": {
          "type": "mrkdwn",
          "text": "*#{route.name}#{route.name == 'S' ? " - " + route.alternate_name : ""} train*\n"\
                  "_Status_: *#{route_data['status'] || (scheduled ? 'No Service' : 'Not Scheduled')}*"
        }
      }
    ]

    if route_data.present?
      summary = route_data['service_summaries'].map { |_, summary| summary }.compact + route_data['service_change_summaries'].flat_map { |_, summary| summary}.compact

      if summary.present?
        result << {
          "type": "divider"
        }
        result << {
          "type": "section",
          "text": {
            "type": "mrkdwn",
            "text": summary.join("\n\n").gsub(/ - /, '–')
          }
        }
      end
    end

    result << {
      "type": "divider"
    }

    result << {
      "type": "context",
      "elements": [
        {
          "type": "mrkdwn",
          "text": "More info on https://www.goodservice.io/trains/#{route_id}"
        }
      ]
    }

    {
      response_type: "in_channel",
      channel: params[:channel_id],
      blocks: result
    }
  end

  def stop_response(stop)
    timestamp = Time.current
    futures = {}
    REDIS_CLIENT.pipelined do
      futures = [1, 3].to_h { |direction|
        [direction, RedisStore.routes_stop_at(stop.internal_id, direction, timestamp.to_i)]
      }
    end
    routes_stop_at = transform_to_routes_array(futures[stop.internal_id])
    elevator_advisories_str = RedisStore.elevator_advisories
    route_trips = routes_stop_at.to_h do |route_id|
      [route_id, RedisStore.processed_trips(route_id)]
    end
    travel_times_data = RedisStore.travel_times
    travel_times = travel_times_data ? Marshal.load(travel_times_data) : {}
    trips_by_routes_array = route_ids.map do |route_id|
      marshaled_trips = route_trips[route_id]
      next unless marshaled_trips
      Marshal.load(marshaled_trips)
    end
    trips = [:north, :south].to_h { |direction|
      [direction, trips_by_routes_array.flat_map { |route_hash|
        route_id = route_hash.values.map(&:values)&.first&.first&.first&.route_id
        actual_direction = Api::StopsController.determine_direction(direction, stop_id, route_id)
          route_hash[actual_direction]&.values&.flatten&.uniq { |t| t.id }
        }.select { |trip|
          trip&.upcoming_stops(time_ref: timestamp)&.include?(stop_id)
        }.map { |trip| transform_trip(stop.internal_id, trip, travel_times, timestamp)}.sort_by { |trip| trip[:arrival_time] }
      ]
    }

    elevator_advisories = elevator_advisories_str ? JSON.parse(elevator_advisories_str) : {}
    
    result = [
      {
        "type": "section",
        "text": {
          "type": "mrkdwn",
          "text": stop.alternate_name ? "*#{stop.name}* (#{stop.alternate_name}) - #{routes_stop_at.join(', ')}" : "*#{stop.name}* - #{routes_stop_at.join(', ')}"
        }
      }
    ]

    if elevator_advisories[stop.internal_id].present?
      result << {
        "type": "section",
        "text": {
          "type": "mrkdwn",
          "text": elevator_advisories[stop.internal_id].map { |a| "Elevator for #{a} is out of service"}.join("\n\n")
        }
      }
    end

    result << {
      "type": "divider"
    }

    [:north, :south].each do |direction, trips|
      next unless trips.present?
      destinations = trips.map { |t| t[:destination_stop]}.uniq.map { |d| Scheduled::Stop.find_by(internal_id: d).stop_name.gsub(/ - /, '–') }.sort
      result << {
        "type": "section",
        "text": {
          "type": "mrkdwn",
          "text": "_To #{destinations.join(', ').gsub(/ - /, '–')}_"
        }
      }
      result << {
        "type": "section",
        "text": {
          "type": "mrkdwn",
          "text": trips.slice(0, 5).map { |t|
            if t[:is_delayed]
              "Delayed (#{t[:route_id]}"
            else
              "#{[(t[:arrival_time] / 60).round, 0].max} min (#{t[:route_id]}"
            end
          }.join(', ')
        }
      }
    end

    result << {
      "type": "divider"
    }

    result << {
      "type": "context",
      "elements": [
        {
          "type": "mrkdwn",
          "text": "More info on https://www.goodservice.io/stations/#{stop.internal_id}"
        }
      ]
    }

    {
      response_type: "in_channel",
      channel: params[:channel_id],
      blocks: result
    }
  end

  def transform_to_routes_array(direction_futures_hash)
    routes_by_direction = direction_futures_hash.flat_map { |_, future|
      future.value
    }.compact.uniq.sort
  end

  def transform_trip(stop_id, trip, travel_times, timestamp)
    upcoming_stops = trip.upcoming_stops
    i = upcoming_stops.index(stop_id)
    estimated_current_stop_arrival_time = trip.estimated_upcoming_stop_arrival_time
    if i > 0
      estimated_current_stop_arrival_time += upcoming_stops[0..i].each_cons(2).map { |a_stop, b_stop|
        travel_times["#{a_stop}-#{b_stop}"] || RedisStore.supplemented_scheduled_travel_time(a_stop, b_stop) || RedisStore.scheduled_travel_time(a_stop, b_stop) || 0
      }.reduce(&:+)
    end
    {
      route_id: trip.route_id,
      arrival_time: estimated_current_stop_arrival_time - timestamp,
      destination_stop: trip.destination,
      is_delayed: trip.delayed?,
    }
  end

  def verify_slack_request
    slack_signature = request.headers["X-Slack-Signature"]
    timestamp = request.headers["X-Slack-Request-Timestamp"]
    body = request.body.read
    base = "v0:#{timestamp}:#{body}"
    key = ENV["SLACK_SIGNING_SECRET"]

    signature = "v0=#{OpenSSL::HMAC.hexdigest("SHA256", key, base)}"

    if (Time.current.to_i - timestamp.to_i).abs > 60 * 5
      return head :forbidden
    end

    if signature != slack_signature
      return head :forbidden
    end
  end
end