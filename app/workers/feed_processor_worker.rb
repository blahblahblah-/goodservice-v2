class FeedProcessorWorker
  include Sidekiq::Worker
  sidekiq_options retry: false, queue: 'critical'

  def perform(feed_id, route_id, minutes, fraction_of_minute)
    begin
      if !RedisStore.acquire_feed_processor_lock(feed_id, route_id, minutes, fraction_of_minute)
        raise "Can't acquire FeedProcessor lock for #{feed_id}:#{route_id}:#{minutes}:#{fraction_of_minute}"
      end
      FeedProcessor.analyze_feed(feed_id, route_id, minutes, fraction_of_minute)
    ensure
      RedisStore.release_feed_processor_lock(feed_id, route_id, minutes, fraction_of_minute)
    end
  end
end