class FeedRetrieverSpawningWorker
  include Sidekiq::Worker
  BASE_URI = "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs"
  FEEDS = ["", "-ace", "-bdfm", "-g", "-jz", "-nqrw", "-l", "-7", "-si"]

  def perform
    minutes = Time.current.min
    half_minute = Time.current.sec / 30
    FEEDS.each do |id|
      FeedRetrieverWorker.perform_async(id, minutes, half_minute)
    end
  end
end
