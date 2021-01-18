class Api::InfoController < ApplicationController
  def index
    data = Rails.cache.fetch("status", expires_in: 30.seconds) do
      {
        routes: Scheduled::Route.all.sort_by { |r| "#{r.name} #{r.alternate_name}" }.map { |route|
          route_data_encoded = RedisStore.route_status(route.internal_id)
          route_data = route_data_encoded ? JSON.parse(route_data_encoded) : {}
          scheduled = Scheduled::Trip.any_scheduled?(route.internal_id)
          [route.internal_id, {
            id: route.internal_id,
            name: route.name,
            color: route.color && "##{route.color}",
            text_color: route.text_color && "##{route.text_color}",
            alternate_name: route.alternate_name,
            status: scheduled ? 'No Service' : 'Not Scheduled',
            visible: route.visible?,
            scheduled: scheduled,
          }.merge(route_data)]
        }.to_h,
        timestamp: Time.current.to_i
      }
    end

    expires_now
    render json: data
  end
end