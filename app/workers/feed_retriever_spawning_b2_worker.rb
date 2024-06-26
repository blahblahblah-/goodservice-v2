class FeedRetrieverSpawningB2Worker < FeedRetrieverSpawningWorkerBase
  include Sidekiq::Worker
  sidekiq_options retry: false, queue: 'critical'

  FEEDS = ["-jz", "-nqrw", "-l", "-si"]

  def perform
    minutes = Time.current.min
    fraction_of_minute = Time.current.sec / 15
    FEEDS.each do |id|
      FeedRetrieverWorker.perform_async(id, minutes, fraction_of_minute)
    end
  end
end
