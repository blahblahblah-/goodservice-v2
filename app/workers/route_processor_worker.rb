class RouteProcessorWorker
  include Sidekiq::Worker
  sidekiq_options retry: false, queue: 'default'

  def perform(route_id, timestamp)
    marshaled_trips = RedisStore.route_trips(route_id, timestamp)
    trips = Marshal.load(marshaled_trips) if marshaled_trips

    if !trips
      throw "Error: Trips for #{route_id} at #{Time.zone.at(timestamp)} not found"
    end

    RouteProcessor.process_route(route_id, trips, timestamp)
  end
end