class FeedRetrieverSpawningWorker
  include Sidekiq::Worker
  sidekiq_options retry: false, queue: 'critical'

  BASE_URI = "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs"
  FEEDS = ["", "-ace", "-bdfm", "-g", "-jz", "-nqrw", "-l", "-7", "-si"]

  def perform
    minutes = Time.current.min
    fraction_of_minute = Time.current.sec / 10
    FEEDS.each do |id|
      FeedRetrieverWorker.perform_async(id, minutes, fraction_of_minute)
    end
  end
end
