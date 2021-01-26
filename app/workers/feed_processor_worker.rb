class FeedProcessorWorker
  include Sidekiq::Worker
  sidekiq_options retry: false, queue: 'default'

  def perform(feed_id, minutes, half_minute)
    FeedProcessor.analyze_feed(feed_id, minutes, half_minute)
  end
end