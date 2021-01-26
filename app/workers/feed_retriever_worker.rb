require 'nyct-subway.pb'
require 'net/http'
require 'uri'

class FeedRetrieverWorker
  include Sidekiq::Worker
  sidekiq_options retry: 1, dead: false, queue: 'critical'

  BASE_URI = "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs"

  def perform(feed_id, minutes, half_minute)
    current_minute = Time.current.min
    if (current_minute - minutes) > 1
      puts "Job expired, noop"
      return
    end
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
    FeedProcessorWorker.perform_async(feed_id, minutes, half_minute)
    puts "Feed #{feed_id} done!"
  end
end