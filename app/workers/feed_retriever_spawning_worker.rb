class FeedRetrieverSpawningWorker
  include Sidekiq::Worker
  sidekiq_options retry: false, queue: 'critical'

  FEEDS = ["", "-ace", "-bdfm", "-g", "-jz", "-nqrw", "-l", "-si"]

  MISC_FEED_MAPPING = {
    "FS" => "-ace",
    "GS" => "",
    "H" => "-ace",
    "SI" => "-si",
  }

  def perform
    minutes = Time.current.min
    fraction_of_minute = Time.current.sec / 15
    FEEDS.each do |id|
      FeedRetrieverWorker.perform_async(id, minutes, fraction_of_minute)
    end
  end

  def self.feed_id_for(route_id)
    if MISC_FEED_MAPPING[route_id]
      MISC_FEED_MAPPING[route_id]
    elsif feed_id = FEEDS.find { |f| f.upcase.include?(route_id.first) }
      feed_id
    else
      ""
    end
  end
end
