class Api::TripsController < ApplicationController
  ROUTE_FEED_MAPPING = {
    "1" => "",
    "2" => "",
    "3" => "",
    "4" => "",
    "5" => "",
    "5X" => "",
    "6" => "",
    "6X" => "",
    "GS" => "",
    "A" => "-ace",
    "C" => "-ace",
    "E" => "-ace",
    "H" => "-ace",
    "FS" => "-ace",
    "N" => "-nqrw",
    "Q" => "-nqrw",
    "R" => "-nqrw",
    "W" => "-nqrw",
    "B" => "-bdfm",
    "D" => "-bdfm",
    "F" => "-bdfm",
    "M" => "-bdfm",
    "L" => "-l",
    "SI" => "-si",
    "G" => "-g",
    "J" => "-jz",
    "Z" => "-jz",
    "7" => "-7",
    "7X" => "-7",
  }

  def show
    trip_id = params[:id].gsub("-", "..")
    marshaled_trip = RedisStore.active_trip(ROUTE_FEED_MAPPING[params[:route_id]], trip_id)

    if !marshaled_trip && trip_id.include?("..")
      trip_id = trip_id.gsub("..", ".")
      marshaled_trip = RedisStore.active_trip(ROUTE_FEED_MAPPING[params[:route_id]], trip_id)
    end

    raise ActionController::RoutingError.new('Not Found') unless marshaled_trip
    trip = Marshal.load(marshaled_trip)

    data = {
      route_id: trip.route_id,
      trip_id: trip.id,
      stop_times: trip.stops,
      past_stops: trip.past_stops,
      timestamp: trip.timestamp
    }

    expires_now
    render json: data
  end
end