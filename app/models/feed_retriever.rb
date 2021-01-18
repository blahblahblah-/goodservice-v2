require 'nyct-subway.pb'
require 'net/http'
require 'uri'

class FeedRetriever
  BASE_URI = "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs"
  FEEDS = ["", "-ace", "-bdfm", "-g", "-jz", "-nqrw", "-l", "-7", "-si"]

  class << self
    def retrieve_all_feeds
      minutes = Time.current.min
      half_minute = Time.current.sec / 30
      if ENV['FEED_THREADS']
        Parallel.each(FEEDS, in_threads: ENV['FEED_THREADS'].to_i) do |id|
          retrieve_feed(id, minutes, half_minute)
        end
      else
        FEEDS.each do |id|
          retrieve_feed(id, minutes, half_minute)
        end
      end
    end

    def retrieve_feed(feed_id, minutes, half_minute)
      puts "Retrieving feed #{feed_id}"

      uri = URI.parse("#{BASE_URI}#{feed_id}")
      decoded_data = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        request = Net::HTTP::Get.new uri
        request["x-api-key"] = ENV["MTA_KEY"]

        response = http.request request
        data = response.body
        Transit_realtime::FeedMessage.decode(data)
      end
      last_feed_timestamp = RedisStore.feed_timestamp(feed_id)
      if last_feed_timestamp && last_feed_timestamp == decoded_data.header.timestamp
        puts "Skipping feed #{feed_id} with timestamp #{last_feed_timestamp} has not been updated"
        return
      end
      RedisStore.update_feed_timestamp(feed_id, decoded_data.header.timestamp)
      RedisStore.add_feed(feed_id, minutes, half_minute, Marshal.dump(decoded_data))
      ActiveRecord::Base.connection_pool.with_connection do
        FeedProcessor.analyze_feed(feed_id, minutes, half_minute)
      end
      puts "Feed #{feed_id} done!"
    end

    handle_asynchronously :retrieve_all_feeds, priority: 0
    handle_asynchronously :retrieve_feed, priority: 0
  end
end