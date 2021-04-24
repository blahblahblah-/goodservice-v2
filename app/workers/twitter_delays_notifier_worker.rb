class TwitterDelaysNotifierWorker
  include Sidekiq::Worker
  sidekiq_options retry: 1, queue: 'critical'

  SKIPPED_ROUTES = ENV['DELAY_NOTIFICATION_EXCLUDED_ROUTES']&.split(',') || []
  DELAY_NOTIFICATION_THRESHOLD = (ENV['DELAY_NOTIFICATION_THRESHOLD'] || 10.minutes).to_i
  DELAY_CLEARED_TIMEOUT_MINS = (ENV['DELAY_CLEARED_TIMEOUT_MINS'] || 10).to_i
  REANNOUNCE_DELAY_TIME = (ENV['DELAY_NOTIFICATION_REANNOUNCE_TIME'] || 15.minutes).to_i
  ROUTE_CLIENT_MAPPING = (ENV['TWITTER_ROUTE_CLIENT_MAPPING'] || '').split(",").to_h { |str|
    array = str.split(":")
    [array.first, array.second]
  }
  ENABLE_ROUTE_CLIENTS = ENV['TWITTER_ENABLE_ROUTE_CLIENTS'] ? ActiveModel::Type::Boolean.new.cast(ENV['TWITTER_ENABLE_ROUTE_CLIENTS']) : true

  def perform
    return unless twitter_client

    puts "Running TwitterDelaysNotifierWorker"

    route_ids = Scheduled::Route.all.pluck(:internal_id)
    trips_by_routes_futures = {}
    route_status_futures = {}

    REDIS_CLIENT.pipelined do
      trips_by_routes_futures = route_ids.to_h do |route_id|
        [route_id, RedisStore.processed_trips(route_id)]
       end
      route_status_futures = route_ids.to_h do |route_id|
        [route_id, RedisStore.route_status(route_id)]
      end
    end

    prev_delays = previous_delay_notifications
    delays = []
    updated_delays = []

    route_ids.each do |route_id|
      next if SKIPPED_ROUTES.include?(route_id)
      marshaled_trips = trips_by_routes_futures[route_id].value
      next unless marshaled_trips
      trips_by_directions = Marshal.load(marshaled_trips)
      trips_by_directions.each do |d, trips_by_routings|
        direction = d == 1 ? "north" : "south"
        delayed_trips = trips_by_routings.flat_map { |_, trips|
          trips
        }.select(&:delayed?).uniq { |t| t.id }
        next unless delayed_trips.present?
        encoded_status = route_status_futures[route_id].value
        route_status = JSON.parse(encoded_status)
        if trips_by_routings.keys.size == 1
          routing = route_status["actual_routings"][direction].first
          destinations = [routing.last]
          stops = delayed_trips.map(&:upcoming_stop).uniq
          max_delay = delayed_trips.map(&:effective_delayed_time).max
          i = routing.index(stops.first)
          j = routing.index(stops.last)
          next if i == j && i == routing.size - 1
          routing_subset = routing[i..j]
          upsert_delay_notification(prev_delays, delays, updated_delays, max_delay, route_id, direction, routing_subset, routing, destinations)
        else
          routing_keys = trips_by_routings.keys.sort { |a, b|
            if a == 'blended'
              -1
            elsif b == 'blended'
              1
            else
              a <=> b
            end
          }
          delayed_trips_by_routings = delayed_trips.group_by { |t|
            routing_keys.find { |r| trips_by_routings[r].any? { |trip| trip.id == t.id } }
          }
          delayed_trips_by_routings.each do |routing_key, delayed_trips|
            if routing_key == 'blended'
              routing = route_status['common_routings'][direction]
              destinations = route_status['actual_routings'][direction].map(&:last)
            else
              routing = route_status['actual_routings'][direction].find {|r| routing_key == "#{r.first}-#{r.last}-#{r.size}"}
              destinations = [routing.last]
            end
            stops = delayed_trips.map(&:upcoming_stop).uniq
            max_delay = delayed_trips.map(&:effective_delayed_time).max
            i = routing.index(stops.first)
            j = routing.index(stops.last)
            routing_subset = routing[i..j]
            upsert_delay_notification(prev_delays, delays, updated_delays, max_delay, route_id, direction, routing_subset, routing, destinations)
          end
        end
      end
    end

    delayed_not_timed_out = prev_delays.select do |d|
      d.update_not_observed!
      d.mins_since_observed < DELAY_CLEARED_TIMEOUT_MINS
    end

    delayed_not_timed_out.each do |d|
      delays << d
      prev_delays.delete(d)
    end

    tweet_delays!(prev_delays, delays, updated_delays)
    delays.select! { |d| d.last_tweet_times.present? }
    marshaled_delays = Marshal.dump(delays)
    RedisStore.update_delay_notifications(marshaled_delays)
  end

  private

  def previous_delay_notifications
    marshaled_notifications = RedisStore.delay_notifications
    return [] unless marshaled_notifications
    Marshal.load(marshaled_notifications)
  end

  def upsert_delay_notification(prev_delays, delays, updated_delays, max_delay, route_id, direction, stops, routing, destinations)
    actual_direction = direction
    if route_id == 'M' && stops.any? { |s| Api::StopsController::M_TRAIN_SHUFFLE_STOPS.include?(s) }
      actual_direction = direction == "north" ? "south" : "north"
    end

    matching_delay = prev_delays.find { |d| d.direction == actual_direction && d.match_routing?(routing) }
    if matching_delay
      prev_delays.delete(matching_delay)
    else
      matching_delay = delays.find { |d| d.direction == actual_direction && d.match_routing?(routing) }
      delays.delete(matching_delay) if matching_delay
    end

    if matching_delay
      route_exists_for_delay = matching_delay.routes.include?(route_id)
      matching_delay.append!(route_id, stops, routing, destinations)
      delay_to_add = matching_delay
      updated_delays << delay_to_add unless route_exists_for_delay || delay_to_add.last_tweet_ids.empty?
    else
      return if max_delay < DELAY_NOTIFICATION_THRESHOLD
      delay_to_add = DelayNotification.new(route_id, actual_direction, stops, routing, destinations)
    end
    delays << delay_to_add
  end

  def tweet_delays!(prev_delays, delays, updated_delays)
    prev_delays.each do |d|
      tweet(d, "Delays cleared for #{stop_names(d.destinations)}-bound #{route_names(d.routes)} trains.", true, false)
    end

    delays.each do |d|
      next if d.mins_since_observed && d.mins_since_observed > 0
      tweet(d, "#{stop_names(d.destinations)}-bound #{route_names(d.routes)} trains are currently delayed #{delayed_sections(d.affected_sections)}.", false, false)
    end

    updated_delays.each do |d|
      tweet(d, "#{stop_names(d.destinations)}-bound #{route_names(d.routes)} trains are currently delayed #{delayed_sections(d.affected_sections)}.", false, true)
    end
  end

  def delayed_sections(affected_sections)
    affected_sections.each_with_index.map { |s, i|
      str = (i > 0 && i == affected_sections.size - 1) ? "and " : ""
      if s.size == 1
        str << "at #{stop_name(s.first)}"
      else
        str << "between #{stop_name(s.first)} and #{stop_name(s.last)}"
      end

      str
    }.join(", ")
  end

  def stop_name(stop_id)
    stop_names([stop_id])
  end

  def stop_names(stop_ids)
    stop_ids.map { |s|
      Scheduled::Stop.find_by(internal_id: s).stop_name.gsub(/ - /, '–')
    }.join('/')
  end

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

  def tweet(delay_notification, text, required_update, force_update_on_main_feed)
    (["all"] + delay_notification.routes).map { |r| ROUTE_CLIENT_MAPPING[r] || r }.uniq.each do |route_id|
      begin
        tweet_text = text
        if delay_notification.last_tweet_ids[route_id]
          tweet_text = "#{text} #{tweet_url(delay_notification.last_tweet_ids[route_id], route_id)}"
        end
        puts "Tweeting #{tweet_text} for #{route_id}"
        client = route_id == "all" ? twitter_client : twitter_route_client(route_id)
        if route_id != "all" && !required_update && delay_notification.last_tweet_times[route_id]
          next if delay_notification.last_tweet_times[route_id].to_i > Time.current.to_i - REANNOUNCE_DELAY_TIME
        end
        if route_id == "all" && !force_update_on_main_feed
          next if delay_notification.last_tweet_times[route_id].to_i > Time.current.to_i - REANNOUNCE_DELAY_TIME
        end
        result = client.update!(tweet_text)
        if result
          delay_notification.last_tweet_ids[route_id] = result.id
          delay_notification.last_tweet_times[route_id] = Time.current
        end
      rescue StandardError => e
        puts "Error tweeting: #{e.message}"
      end
    end
  end

  def twitter_client
    return unless ENV["TWITTER_TEST_CONSUMER_KEY"]
    @twitter_client ||= Twitter::REST::Client.new do |config|
      config.consumer_key        = ENV["TWITTER_TEST_CONSUMER_KEY"]
      config.consumer_secret     = ENV["TWITTER_TEST_CONSUMER_SECRET"]
      config.access_token        = ENV["TWITTER_TEST_ACCESS_TOKEN"]
      config.access_token_secret = ENV["TWITTER_TEST_ACCESS_TOKEN_SECRET"]
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