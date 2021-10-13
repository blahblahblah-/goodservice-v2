module TwitterHelper
  TWITTER_MAX_CHARS = 280 - 10
  ROUTE_CLIENT_MAPPING = (ENV['TWITTER_ROUTE_CLIENT_MAPPING'] || '').split(",").to_h { |str|
    array = str.split(":")
    [array.first, array.second]
  }
  ENABLE_ROUTE_CLIENTS = ENV['TWITTER_ENABLE_ROUTE_CLIENTS'] ? ActiveModel::Type::Boolean.new.cast(ENV['TWITTER_ENABLE_ROUTE_CLIENTS']) : true

  def route_names(route_ids)
    route_ids.map { |r|
      route = Scheduled::Route.find_by(internal_id: r)
      if route.alternate_name
        "#{route.name} - #{route.alternate_name}"
      else
        route.name
      end
    }.sort.join(', ')
  end

  def tweet_url(tweet_id, route_id)
    if route_id == 'all'
      twitter_account = ENV['TWITTER_USERNAME'] || "goodservicetest"
      "https://twitter.com/#{twitter_account}/status/#{tweet_id}"
    else
      twitter_account_name_prefix = ENV['TWITTER_USERNAME_ROUTE_CLIENT_PREFIX'] || "goodservice_"
      "https://twitter.com/#{twitter_account_name_prefix}#{route_id}/status/#{tweet_id}"
    end
  end

  def twitter_client
    return unless ENV["TWITTER_CONSUMER_KEY"]
    @twitter_client ||= Twitter::REST::Client.new do |config|
      config.consumer_key        = ENV["TWITTER_CONSUMER_KEY"]
      config.consumer_secret     = ENV["TWITTER_CONSUMER_SECRET"]
      config.access_token        = ENV["TWITTER_ACCESS_TOKEN"]
      config.access_token_secret = ENV["TWITTER_ACCESS_TOKEN_SECRET"]
    end
  end

  def twitter_route_client(route_id)
    return unless ENABLE_ROUTE_CLIENTS && ENV["TWITTER_CONSUMER_KEY"] && ENV["TWITTER_CLIENT_#{route_id}_ACCESS_TOKEN"]
    Twitter::REST::Client.new do |config|
      config.consumer_key        = ENV["TWITTER_CONSUMER_KEY"]
      config.consumer_secret     = ENV["TWITTER_CONSUMER_SECRET"]
      config.access_token        = ENV["TWITTER_CLIENT_#{route_id}_ACCESS_TOKEN"]
      config.access_token_secret = ENV["TWITTER_CLIENT_#{route_id}_ACCESS_TOKEN_SECRET"]
    end
  end
end