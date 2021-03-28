class TwitterWorker
  include Sidekiq::Worker
  sidekiq_options retry: 1, queue: 'critical'

  def perform
    return unless twitter_client

    time = Time.zone.at((Time.current.to_f / 10.minutes).round * 10.minutes)

    routes_with_alternate_names = Scheduled::Route.all.where("alternate_name is not null").to_h do |r|
      [r.internal_id, r]
    end

    delayed_routes = RedisStore.route_status_summaries&.to_h { |k, v|
      data = JSON.parse(v)
      r = routes_with_alternate_names[k]
      [r ? "#{r.name} - #{r.alternate_name.gsub(" Shuttle", "")}" : k, data['timestamp'] && data['timestamp'] >= (Time.current - 5.minutes).to_i && data['status'] == 'Delay']
    }.select { |k, v| v }.map { |k, _| k }.sort

    prev_delayed_routes = RedisStore.delayed_routes && JSON.parse(RedisStore.delayed_routes)

    if delayed_routes.present?
      status = "Delays detected @ #{time.strftime("%-l:%M%P")}: #{delayed_routes.join(', ')} trains"
    elsif prev_delayed_routes.present?
      status = "Delays detected @ #{time.strftime("%-l:%M%P")}: none"
    end

    return unless status

    puts "Sending delay status to Twitter"
    tweet = twitter_client.update!(status)
    RedisStore.update_delayed_routes(delayed_routes.to_json)
    puts "Tweeted #{status}"
    puts "Tweet URI: #{tweet.uri}"
  rescue StandardError => e
    puts "Error tweeting: #{e.message}"
    puts e.backtrace
  end

  private

  def twitter_client
    return unless ENV["TWITTER_CONSUMER_KEY"]
    @twitter_client ||= Twitter::REST::Client.new do |config|
      config.consumer_key        = ENV["TWITTER_CONSUMER_KEY"]
      config.consumer_secret     = ENV["TWITTER_CONSUMER_SECRET"]
      config.access_token        = ENV["TWITTER_ACCESS_TOKEN"]
      config.access_token_secret = ENV["TWITTER_ACCESS_TOKEN_SECRET"]
    end
  end
end