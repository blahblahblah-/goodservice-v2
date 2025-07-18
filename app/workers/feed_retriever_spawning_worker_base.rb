class FeedRetrieverSpawningWorkerBase
  ALL_FEEDS = ["", "-ace", "-bdfm", "-g", "-jz", "-nqrw", "-l", "-si"]
  MISC_FEED_MAPPING = {
    "FS" => "-bdfm",
    "GS" => "",
    "H" => "-ace",
    "SI" => "-si",
    "SS" => "-si",
  }

  def self.feed_id_for(route_id)
    if MISC_FEED_MAPPING[route_id]
      MISC_FEED_MAPPING[route_id]
    elsif feed_id = ALL_FEEDS.find { |f| f.upcase.include?(route_id.first) }
      feed_id
    else
      ""
    end
  end
end
