class RedisCleanupWorker
  include Sidekiq::Worker
  sidekiq_options retry: false, queue: 'low'

  def perform
    RedisStore.clear_outdated_trips
    RedisStore.clear_outdated_trip_stops_and_delays
  end
end