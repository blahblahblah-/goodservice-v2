class Api::InfoController < ApplicationController
  def index
    data = Rails.cache.fetch("status", expires_in: 30.seconds) do
      data_hash = RedisStore.route_status_summaries
      scheduled_routes = Scheduled::Trip.soon(Time.current.to_i, nil).pluck(:route_internal_id).to_set
      {
        routes: Scheduled::Route.all.sort_by { |r| "#{r.name} #{r.alternate_name}" }.map { |route|
          route_data_encoded = data_hash[route.internal_id]
          route_data = route_data_encoded ? JSON.parse(route_data_encoded) : {}
          route_data = {} if !route_data['timestamp'] || route_data['timestamp'] < (Time.current - 1.minute).to_i
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
        timestamp: Time.current.to_i
      }
    end

    expires_now
    render json: data
  end
end