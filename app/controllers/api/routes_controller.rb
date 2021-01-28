class Api::RoutesController < ApplicationController
  def index
    data = Rails.cache.fetch("status", expires_in: 30.seconds) do
      data_hash = RedisStore.route_status_summaries
      scheduled_routes = Scheduled::Trip.soon(Time.current.to_i, nil).pluck(:route_internal_id).to_set
      timestamps = []
      {
        routes: Scheduled::Route.all.sort_by { |r| "#{r.name} #{r.alternate_name}" }.map { |route|
          route_data_encoded = data_hash[route.internal_id]
          route_data = route_data_encoded ? JSON.parse(route_data_encoded) : {}
          if !route_data['timestamp'] || route_data['timestamp'] <= (Time.current - 5.minutes).to_i
            route_data = {}
          else
            timestamps << route_data['timestamp']
          end
          scheduled = scheduled_routes.include?(route.internal_id)
          [route.internal_id, {
            id: route.internal_id,
            name: route.name,
            color: route.color && "##{route.color}",
            text_color: route.text_color && "##{route.text_color}",
            alternate_name: route.alternate_name,
            status: scheduled ? 'No Service' : 'Not Scheduled',
            visible: route.visible?,
            scheduled: scheduled,
          }.merge(route_data).except('timestamp')]
        }.to_h,
        timestamp: timestamps.max
      }
    end

    expires_now
    render json: data
  end

  def show
    route_id = params[:id]
    data = Rails.cache.fetch("status:#{route_id}", expires_in: 30.seconds) do
      time_check = Time.current
      route = Scheduled::Route.find_by!(internal_id: route_id)
      scheduled = Scheduled::Trip.soon(Time.current.to_i, route_id).present?
      route_data_encoded = RedisStore.route_status(route_id)
      route_data = route_data_encoded ? JSON.parse(route_data_encoded) : {}
      time_check2 = Time.current
      puts "Loaded data #{(time_check2 - time_check)* 1000}ms"
      if !route_data['timestamp'] || route_data['timestamp'] <= (Time.current - 5.minutes).to_i
        route_data = {}
      else
        route_data[:stops] = stops_info(route_data['actual_routings'])
        time_check3 = Time.current
        puts "Loaded stops #{(time_check3 - time_check2)* 1000}ms"
        route_data[:transfers] = transfers_info(route_data['actual_routings'], route_id, route_data['timestamp'])
        time_check4 = Time.current
        puts "Loaded transfers #{(time_check4 - time_check3)* 1000}ms"
        pairs = route_pairs(route_data['actual_routings'])

        if pairs.present?
          route_data[:scheduled_travel_times] = scheduled_travel_times(pairs)
          time_check5 = Time.current
          puts "Loaded scheduled travel times #{(time_check5 - time_check4)* 1000}ms"
          route_data[:supplementary_travel_times] = supplementary_travel_times(pairs)
          time_check6 = Time.current
          puts "Loaded supplementary travel times #{(time_check6 - time_check5)* 1000}ms"
          route_data[:estimated_travel_times] = estimated_travel_times(pairs, route_data['timestamp'])
          time_check7 = Time.current
        puts "Loaded estimated travel times #{(time_check7 - time_check6)* 1000}ms"
        end
      end
      {
        id: route.internal_id,
        name: route.name,
        color: route.color && "##{route.color}",
        text_color: route.text_color && "##{route.text_color}",
        alternate_name: route.alternate_name,
        status: scheduled ? 'No Service' : 'Not Scheduled',
        visible: route.visible?,
        scheduled: scheduled,
        timestamp: Time.current.to_i,
      }.merge(route_data)
    end

    expires_now
    render json: data
  end

  private

  def stops_info(routings)
    stations = routings.map { |_, r| r }.flatten.uniq
    Scheduled::Stop.where(internal_id: stations).pluck(:internal_id, :stop_name).to_h
  end

  def transfers_info(routings, route_id, timestamp)
    stations = routings.map { |_, r| r }.flatten.uniq
    transfers = Scheduled::Transfer.where("from_stop_internal_id <> to_stop_internal_id and from_stop_internal_id in (?)", stations)
    futures = {}

    REDIS_CLIENT.pipelined do
      futures = stations.to_h { |stop_id|
        [stop_id, [1, 3].to_h { |direction|
          f = [RedisStore.routes_stop_at(stop_id, direction, timestamp)]
          transfers.select { |t| t.from_stop_internal_id == stop_id }.each { |t|
            f << RedisStore.routes_stop_at(t.to_stop_internal_id, direction, timestamp)
          }
          [direction, f]
        }]
      }
    end

    futures.to_h { |stop_id, futures_by_direction|
      arr = []
      routes_by_direction = futures_by_direction.to_h { |direction, futures|
        [direction, futures.map(&:value).flatten.uniq - [route_id]]
      }
      routes = routes_by_direction.values.flatten.uniq.sort
      [stop_id, routes.to_h { |route_id|
        directions_array = []
        if routes_by_direction[1].include?(route_id)
          directions_array << "north"
        end
        if routes_by_direction[3].include?(route_id)
          directions_array << "south"
        end
        [route_id, directions_array]
      }]
    }.filter { |_, v| v.present? }
  end

  def route_pairs(routings)
    routings.map { |_, r| r.map { |routing| routing.each_cons(2).map { |a, b| [a, b] }}}.flatten(2).uniq
  end

  def scheduled_travel_times(pairs)
    results = RedisStore.scheduled_travel_times(pairs)
    results.to_h do |k, v|
      stops = k.split("-")
      [k, v ? v.to_i : RedisStore.supplementary_scheduled_travel_time(stops.first, stops.second)]
    end
  end

  def supplementary_travel_times(pairs)
    results = RedisStore.supplementary_scheduled_travel_times(pairs)
    results.to_h do |k, v|
      stops = k.split("-")
      [k, v ? v.to_i : RedisStore.scheduled_travel_time(stops.first, stops.second)]
    end
  end

  def estimated_travel_times(pairs, timestamp)
    pairs.to_h { |pair|
      ["#{pair.first}-#{pair.second}", RouteProcessor.average_travel_time(pair.first, pair.second, timestamp)]
    }.compact
  end
end