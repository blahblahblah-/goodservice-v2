class TwitterServiceChangesNotifierWorker
  include Sidekiq::Worker
  include TwitterHelper
  sidekiq_options retry: 1, queue: 'low'

  SERVICE_CHANGE_NOTIFICATION_THRESHOLD = (ENV['SERVICE_CHANGE_NOTIFICATION_THRESHOLD'] || 30.minutes).to_i
  ENABLE_ROUTE_CLIENTS = ENV['TWITTER_ENABLE_ROUTE_CLIENTS'] ? ActiveModel::Type::Boolean.new.cast(ENV['TWITTER_ENABLE_ROUTE_CLIENTS']) : true
  SKIPPED_ROUTES = ENV['SERVICE_CHANGE_NOTIFICATION_EXCLUDED_ROUTES']&.split(',') || []

  def perform
    return unless ENABLE_ROUTE_CLIENTS
    route_ids = Scheduled::Route.all.pluck(:internal_id)
    route_status_futures = {}
    upcoming_service_change_notification_futures = {}
    upcoming_service_change_notification_timestamp_futures = {}

    REDIS_CLIENT.pipelined do |pipeline|
      route_status_futures = route_ids.to_h do |route_id|
        [route_id, RedisStore.route_status(route_id, pipeline)]
      end
      upcoming_service_change_notification_futures = route_ids.to_h do |route_id|
        [route_id, RedisStore.upcoming_service_change_notification(route_id, pipeline)]
      end
      upcoming_service_change_notification_timestamp_futures = route_ids.to_h do |route_id|
        [route_id, RedisStore.upcoming_service_change_notification_timestamp(route_id, pipeline)]
      end
    end

    current_notifications = RedisStore.current_service_change_notifications
    scheduled_routes = Scheduled::Trip.soon(Time.current.to_i, nil).pluck(:route_internal_id).to_set

    route_ids.each do |route_id|
      next if SKIPPED_ROUTES.include?(route_id)
      route_status = route_status_futures[route_id].value
      feed_timestamp = RedisStore.feed_timestamp(FeedRetrieverSpawningWorkerBase.feed_id_for(route_id))
      scheduled = scheduled_routes.include?(route_id)

      current_notification_str = current_notifications[route_id]
      current_notification_array = current_notification_str && Marshal.load(current_notification_str)

      if !route_status && feed_timestamp && feed_timestamp.to_i >= (Time.current - 5.minutes).to_i && scheduled
        service_changes = {
          "both" => [
            "<#{route_id}> trains are not running."
          ]
        }
      else
        unless route_status
          RedisStore.clear_upcoming_service_change_notification(route_id)
          RedisStore.clear_service_change_notification(route_id)
          next
        end
        service_changes = JSON.parse(route_status)["service_change_summaries"]
        unless service_changes
          if current_notification_array.present?
            tweet(route_id, ["<#{route_id}> trains have resumed regularly scheduled routing."])
          end
          RedisStore.clear_upcoming_service_change_notification(route_id)
          RedisStore.clear_service_change_notification(route_id)
          next
        end
      end

      service_changes_array = ["both", "north", "south"].flat_map { |direction| service_changes[direction] }.compact
      service_changes_array.select! { |t| !t.start_with?("Some ") }

      if service_changes_array.blank?
        RedisStore.clear_upcoming_service_change_notification(route_id)
        RedisStore.clear_service_change_notification(route_id)
        next
      end

      upcoming_notification = upcoming_service_change_notification_futures[route_id].value
      upcoming_notification_array = upcoming_notification && Marshal.load(upcoming_notification)
      upcoming_notification_timestamp = upcoming_service_change_notification_timestamp_futures[route_id].value&.to_i

      if service_changes_array == current_notification_array
        RedisStore.clear_upcoming_service_change_notification(route_id)
        RedisStore.clear_upcoming_service_change_notification_timestamp(route_id)
        next
      end

      if upcoming_notification_timestamp
        if upcoming_notification_array && service_changes_array == upcoming_notification_array
          if (Time.current.to_i - upcoming_notification_timestamp) >= SERVICE_CHANGE_NOTIFICATION_THRESHOLD
            if tweet(route_id, service_changes_array)
              RedisStore.update_service_change_notification(route_id, Marshal.dump(service_changes_array))
              RedisStore.clear_upcoming_service_change_notification(route_id)
              RedisStore.clear_upcoming_service_change_notification_timestamp(route_id)
            end
          end

          next
        end
      end

      RedisStore.update_upcoming_service_change_notification(route_id, Marshal.dump(service_changes_array))
      RedisStore.update_upcoming_service_change_notification_timestamp(route_id)
    end
  end

  private

  def tweet(route_id, service_changes_array)
    route_name = route_names([route_id])
    results = service_changes_array.map do |str|
      str.gsub(/ - /, "–").gsub(/\(\(/, '').gsub(/\)\)/, '').gsub(/<#{route_id}>/, route_name).gsub(/<(.*?)>/, '\1').sub("bound trains", "bound #{route_name} trains")
    end

    tweet_texts = results.flat_map do |str|
      str.scan(/.{0,#{TWITTER_MAX_CHARS}}[a-z.!?,;-](?:\b|$)/mi)
    end

    puts "Tweeting service changes: #{tweet_texts}"
    updated = false
    prev_tweet = nil
    incomplete = false

    begin
      client_route_id = ROUTE_CLIENT_MAPPING[route_id] || route_id
      [twitter_route_client(client_route_id), twitter_client].each do |client|
        next unless client
        tweet_texts.each_with_index do |tweet, i|
          text = tweet

          if tweet_texts.size > 1
            text = "#{tweet} (#{i + 1}/#{tweet_texts.size})"
          end

          puts "Tweeting: #{text}"

          client_route_id = ROUTE_CLIENT_MAPPING[route_id] || route_id
          prev_tweet = client.update(text, in_reply_to_status: prev_tweet)

          if text != prev_tweet.text
            puts "Tweets don't match: #{text} vs. #{prev_tweet.text}"
            incomplete = true
            break
          end
          updated = true
        end
        break if incomplete
      end
    rescue StandardError => e
      puts "Error tweeting: #{e.message}"
    end

    updated
  end
end