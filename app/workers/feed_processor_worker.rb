class FeedProcessorWorker
  include Sidekiq::Worker
  sidekiq_options retry: false, queue: 'default'

  def perform(feed_id, minutes, fraction_of_minute)
    FeedProcessor.analyze_feed(feed_id, minutes, fraction_of_minute)
  end
end