class TravelTimesRefreshWorker
  include Sidekiq::Worker
  sidekiq_options retry: false, queue: 'default'

  def perform
    routes = Scheduled::Route.all
    route_futures = {}

    REDIS_CLIENT.pipelined do
      route_futures = routes.to_h do |r|
        [r.internal_id, RedisStore.route_status(r.internal_id)]
      end
    end

    stop_pairs = route_futures.flat_map { |_, rf|
      data = rf.value && JSON.parse(rf.value)
      data && data['actual_routings']&.flat_map do |_, routings|
        routings.flat_map { |r| r.each_cons(2).to_a }
      end
    }.compact.uniq

    travel_times = RouteProcessor.batch_average_travel_time_pairs(stop_pairs)
    data = Marshal.dump(travel_times)
    RedisStore.update_travel_times(data)
  end
end
