class Api::RoutesController < ApplicationController
  def show
    route_id = params[:id]
    data = Rails.cache.fetch("status:#{route_id}", expires_in: 30.seconds) do
      route = Scheduled::Route.find_by!(internal_id: route_id)
      scheduled = Scheduled::Trip.soon(Time.current.to_i, route_id).present?
      route_data_encoded = RedisStore.route_status(route_id)
      route_data = route_data_encoded ? JSON.parse(route_data_encoded) : {}
      route_data = {} if !route_data['timestamp'] || route_data['timestamp'] < (Time.current - 1.minute).to_i
      {
        id: route.internal_id,
        name: route.name,
        color: route.color && "##{route.color}",
        text_color: route.text_color && "##{route.text_color}",
        alternate_name: route.alternate_name,
        status: scheduled ? 'No Service' : 'Not Scheduled',
        visible: route.visible?,
        scheduled: scheduled,
      }.merge(route_data)
    end

    expires_now
    render json: data
  end
end