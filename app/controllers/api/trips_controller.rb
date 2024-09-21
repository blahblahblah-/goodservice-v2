class Api::TripsController < ApplicationController
  def show
    trip_id = params[:id].sub("-", "..")
    marshaled_trip = RedisStore.active_trip(ROUTE_FEED_MAPPING[params[:route_id]], trip_id)

    if !marshaled_trip && trip_id.include?("..")
      trip_id = trip_id.sub("..", ".")
      marshaled_trip = RedisStore.active_trip(ROUTE_FEED_MAPPING[params[:route_id]], trip_id)
    end

    raise ActionController::RoutingError.new('Not Found') unless marshaled_trip
    trip = Marshal.load(marshaled_trip)

    data = {
      route_id: trip.route_id,
      trip_id: trip.id,
      stop_times: trip.stops,
      tracks: trip.tracks,
      past_stops: trip.past_stops,
      is_assigned: trip.is_assigned,
      timestamp: trip.timestamp
    }

    expires_now
    render json: data
  end
end