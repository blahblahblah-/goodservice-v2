class FeedRetriever
  BASE_URI = "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs"
  FEEDS = ["", "-ace", "-bdfm", "-g", "-jz", "-nqrw", "-l", "-7", "-si"]

  class << self
    def retrieve_all_feeds(time)
      if (Time.current - time) > 1.minute
        puts "Job expired, noop"
        return
      end
      minutes = Time.current.min
      half_minute = Time.current.sec / 30
      FEEDS.each do |id|
        FeedRetrieverWorker.perform_async(id, minutes, half_minute)
      end
    end
  end
end