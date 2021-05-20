class Api::RoutesController < ApplicationController
  def index
    detailed = params[:detailed] == '1'
    data = Rails.cache.fetch(detailed ? "status-detailed" : "status", expires_in: 10.seconds) do
      data_hash = detailed ? RedisStore.route_status_detailed_summaries : RedisStore.route_status_summaries
      scheduled_routes = Scheduled::Trip.soon(Time.current.to_i, nil).pluck(:route_internal_id).to_set
      timestamps = []
      {
        routes: Scheduled::Route.all.sort_by { |r| "#{r.name} #{r.alternate_name}" }.map { |route|
          route_data_encoded = data_hash[route.internal_id]
          route_data = route_data_encoded ? JSON.parse(route_data_encoded) : {}
          if !route_data['timestamp'] || route_data['timestamp'] < (Time.current - 5.minutes).to_i
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
    data = Rails.cache.fetch("status:#{route_id}", expires_in: 10.seconds) do
      route = Scheduled::Route.find_by!(internal_id: route_id)
      scheduled = Scheduled::Trip.soon(Time.current.to_i, route_id).present?
      route_data_encoded = RedisStore.route_status(route_id)
      route_data = route_data_encoded ? JSON.parse(route_data_encoded.gsub(/\(\(/, '').gsub(/\)\)/, '')) : {}
      if !route_data['timestamp'] || route_data['timestamp'] <= (Time.current - 5.minutes).to_i
        route_data = {}
      else
        pairs = route_pairs(route_data['actual_routings'])

        if pairs.present?
          route_data[:scheduled_travel_times] = scheduled_travel_times(pairs)
          route_data[:supplemented_travel_times] = supplemented_travel_times(pairs)
          route_data[:estimated_travel_times] = estimated_travel_times(route_data['actual_routings'], pairs, route_data['timestamp'])
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

  def route_pairs(routings)
    routings.map { |_, r| r.map { |routing| routing.each_cons(2).map { |a, b| [a, b] }}}.flatten(2).uniq
  end

  def scheduled_travel_times(pairs)
    results = RedisStore.scheduled_travel_times(pairs)
    results.to_h do |k, v|
      stops = k.split("-")
      [k, v ? v.to_i : RedisStore.supplemented_scheduled_travel_time(stops.first, stops.second)]
    end
  end

  def supplemented_travel_times(pairs)
    results = RedisStore.supplemented_scheduled_travel_times(pairs)
    results.to_h do |k, v|
      stops = k.split("-")
      [k, v ? v.to_i : RedisStore.scheduled_travel_time(stops.first, stops.second)]
    end
  end

  def estimated_travel_times(routings, pairs, timestamp)
    travel_times_data = RedisStore.travel_times
    travel_times = travel_times_data ? Marshal.load(travel_times_data) : {}

    pairs.to_h { |pair|
      pair_str = "#{pair.first}-#{pair.second}"
      [pair_str, travel_times[pair_str] || RedisStore.supplemented_scheduled_travel_time(pair.first, pair.second) || RedisStore.scheduled_travel_time(pair.first, pair.second)]
    }.compact
  end
end