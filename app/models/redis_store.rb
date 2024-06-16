class RedisStore
  INACTIVE_TRIP_TIMEOUT = 30.minutes.to_i
  DATA_RETENTION = 4.hours.to_i
  DELAYS_RETENTION = 1.day.to_i
  ROUTE_UPDATE_TIMEOUT = 5.minutes.to_i

  class << self
    # Feeds
    def feed_timestamp(feed_id, client = REDIS_CLIENT)
      client.hget("feed-timestamp", feed_id)
    end

    def update_feed_timestamp(feed_id, timestamp, client = REDIS_CLIENT)
      client.hset("feed-timestamp", feed_id, timestamp)
    end

    def feed(feed_id, minutes, fraction_of_minute, client = REDIS_CLIENT)
      client.get("feed:#{minutes}:#{fraction_of_minute}:#{feed_id}")
    end

    def add_feed(feed_id, minutes, fraction_of_minute, marshaled_data, client = REDIS_CLIENT)
      client.set("feed:#{minutes}:#{fraction_of_minute}:#{feed_id}", marshaled_data, ex: (Rails.env.production? ? 15 : 1800))
    end

    # FeedProcessor lock
    def acquire_feed_processor_lock(feed_id, route_id, minutes, fraction_of_minute, client = REDIS_CLIENT)
      client.set("feed-processor-lock:#{feed_id}:#{route_id}", "#{minutes}:#{fraction_of_minute}", nx: true, ex: 15)
    end

    def release_feed_processor_lock(feed_id, route_id, minutes, fraction_of_minute, client = REDIS_CLIENT)
      if client.get("feed-processor-lock:#{feed_id}:#{route_id}") == "#{minutes}:#{fraction_of_minute}"
        client.del("feed-processor-lock:#{feed_id}:#{route_id}")
      end
    end

    # Accessibility
    def update_accessible_stops_list(list, client = REDIS_CLIENT)
      client.set("accessibile-stops", list, ex: 1800)
    end

    def accessible_stops_list(client = REDIS_CLIENT)
      client.get("accessibile-stops")
    end

    def update_elevator_map(obj, client = REDIS_CLIENT)
      client.set("accessibile-elevator-map", obj, ex: 1800)
    end

    def elevator_map(client = REDIS_CLIENT)
      client.get("accessibile-elevator-map")
    end

    def update_elevator_advisories(obj, client = REDIS_CLIENT)
      client.set("accessibile-elevator-advisories", obj, ex: 1800)
    end

    def elevator_advisories(client = REDIS_CLIENT)
      client.get("accessibile-elevator-advisories")
    end

    # Route Trips
    def route_trips(route_id, timestamp, client = REDIS_CLIENT)
      client.get("route-trips:#{route_id}:#{timestamp}")
    end

    def add_route_trips(route_id, timestamp, marshaled_data, client = REDIS_CLIENT)
      client.set("route-trips:#{route_id}:#{timestamp}", marshaled_data, ex: 60)
    end

    # Processed trips
    def update_processed_trips(route_id, marshaled_data, client = REDIS_CLIENT)
      client.set("processed-trips:#{route_id}", marshaled_data, ex: 300)
    end

    def processed_trips(route_id, client = REDIS_CLIENT)
      client.get("processed-trips:#{route_id}")
    end

    # Trips
    def active_trip_list(feed_id, timestamp, timeout_threshold = 0, client = REDIS_CLIENT)
      upperbound = timestamp - timeout_threshold
      client.zrangebyscore("active-trips-list:#{feed_id}", timestamp - INACTIVE_TRIP_TIMEOUT, "(#{upperbound}")
    end

    def add_to_active_trip_list(feed_id, trip_id, timestamp, client = REDIS_CLIENT)
      client.zadd("active-trips-list:#{feed_id}", timestamp, trip_id)
    end

    def remove_from_active_trip_list(feed_id, trip_id, client = REDIS_CLIENT)
      client.zrem("active-trips-list:#{feed_id}", trip_id)
    end

    def trip_translation(feed_id, trip_id, client = REDIS_CLIENT)
      client.hget("active-trips:translations:#{feed_id}", trip_id)
    end

    def add_trip_translation(feed_id, former_trip_id, new_trip_id, client = REDIS_CLIENT)
      client.hset("active-trips:translations:#{feed_id}", new_trip_id, former_trip_id)
    end

    def remove_trip_translations(feed_id, former_trip_id, client = REDIS_CLIENT)
      client.hgetall("active-trips:translations:#{feed_id}").select { |_, v| v == former_trip_id }.keys.each do |trip_id|
        client.hdel("active-trips:translations:#{feed_id}", trip_id)
      end
    end

    def active_trip(feed_id, trip_id, client = REDIS_CLIENT)
      client.hget("active-trips:#{feed_id}", trip_id)
    end

    def add_active_trip(feed_id, trip_id, marshaled_trip, client = REDIS_CLIENT)
      client.hset("active-trips:#{feed_id}", trip_id, marshaled_trip)
    end

    def remove_active_trip(feed_id, trip_id, client = REDIS_CLIENT)
      client.hdel("active-trips:#{feed_id}", trip_id)
    end

    # Route stops
    def add_route_to_route_stop(route_id, stop_id, direction, timestamp, client = REDIS_CLIENT)
      client.zadd("routes-stop:#{stop_id}:#{direction}", timestamp, route_id)
    end

    def routes_stop_at(stop_id, direction, timestamp, client = REDIS_CLIENT)
      client.zrangebyscore("routes-stop:#{stop_id}:#{direction}", timestamp - ROUTE_UPDATE_TIMEOUT, timestamp + ROUTE_UPDATE_TIMEOUT)
    end

    # Route stop tracks
    def add_route_to_route_stop_track(route_id, direction, stop_id, track, timestamp, client = REDIS_CLIENT)
      client.zadd("routes-stop-track:#{stop_id}:#{track}", timestamp, "#{route_id}:#{direction}")
      client.sadd?("stop-tracks", "#{stop_id}:#{track}")
    end

    def routes_stop_at_track(stop_id, track, timestamp, client = REDIS_CLIENT)
      client.zrangebyscore("routes-stop-track:#{stop_id}:#{track}", timestamp - ROUTE_UPDATE_TIMEOUT, timestamp + ROUTE_UPDATE_TIMEOUT)
    end

    def stop_tracks(client = REDIS_CLIENT)
      client.smembers("stop-tracks")
    end

    # Travel times
    def add_travel_time(stops_str, travel_time, trip_id, timestamp, client = REDIS_CLIENT)
      client.zadd("travel-time:actual:#{stops_str}", timestamp, "#{trip_id}-#{travel_time}")
    end

    def travel_times_at(stop_id_1, stop_id_2, count, client = REDIS_CLIENT)
      stops_str = "#{stop_id_1}-#{stop_id_2}"
      client.zrevrange("travel-time:actual:#{stops_str}", 0, count - 1)
    end

    def supplemented_scheduled_travel_time(stop_id_1, stop_id_2, client = REDIS_CLIENT)
      client.hget("travel-time:supplemented", "#{stop_id_1}-#{stop_id_2}")&.to_f
    end

    def supplemented_scheduled_travel_times(stop_id_pairs, client = REDIS_CLIENT)
      if stop_id_pairs.present?
        client.mapped_hmget("travel-time:supplemented", *stop_id_pairs.map{ |pair| "#{pair.first}-#{pair.last}"})
      else
        {}
      end
    end

    def add_supplemented_scheduled_travel_time(stop_id_1, stop_id_2, time, client = REDIS_CLIENT)
      client.hset("travel-time:supplemented", "#{stop_id_1}-#{stop_id_2}", time)
    end

    def scheduled_travel_time(stop_id_1, stop_id_2, client = REDIS_CLIENT)
      client.hget("travel-time:scheduled", "#{stop_id_1}-#{stop_id_2}")&.to_i
    end

    def scheduled_travel_times(stop_id_pairs, client = REDIS_CLIENT)
      if stop_id_pairs.present?
        client.mapped_hmget("travel-time:scheduled", *stop_id_pairs.map{ |pair| "#{pair.first}-#{pair.last}"})
      else
        {}
      end
    end

    def add_scheduled_travel_time(stop_id_1, stop_id_2, time, client = REDIS_CLIENT)
      client.hset("travel-time:scheduled", "#{stop_id_1}-#{stop_id_2}", time)
    end

    def update_travel_times(data, client = REDIS_CLIENT)
      client.set("travel-times", data, ex: 1800)
    end

    def travel_times(client = REDIS_CLIENT)
      client.get("travel-times")
    end

    # Route statuses
    def route_status_summaries(client = REDIS_CLIENT)
      client.hgetall("route-status")
    end

    def add_route_status_summary(route_id, data, client = REDIS_CLIENT)
      client.hset("route-status", route_id, data)
    end

    def route_status_detailed_summaries(client = REDIS_CLIENT)
      client.hgetall("route-status-detailed")
    end

    def add_route_status_detailed_summary(route_id, data, client = REDIS_CLIENT)
      client.hset("route-status-detailed", route_id, data)
    end

    def route_status(route_id, client = REDIS_CLIENT)
      client.get("route-status:#{route_id}")
    end

    def update_route_status(route_id, data, client = REDIS_CLIENT)
      client.set("route-status:#{route_id}", data, ex: 300)
    end

    # Delayed routes
    def update_delayed_routes(data, client = REDIS_CLIENT)
      client.set("delayed-routes", data, ex: 1800)
    end

    def delayed_routes(client = REDIS_CLIENT)
      client.get("delayed-routes")
    end

    # Delay Notifications
    def update_delay_notifications(data, client = REDIS_CLIENT)
      client.set("delay-notifications", data, ex: 1800)
    end

    def delay_notifications(client = REDIS_CLIENT)
      client.get("delay-notifications")
    end

    # Service Change Notifications
    def update_service_change_notification(route_id, data, client = REDIS_CLIENT)
      client.hset("service-change-notifications", route_id, data)
    end

    def current_service_change_notifications(client = REDIS_CLIENT)
      client.hgetall("service-change-notifications")
    end

    def clear_service_change_notification(route_id, client = REDIS_CLIENT)
      client.hdel("service-change-notifications", route_id)
    end

    def update_upcoming_service_change_notification(route_id, data, client = REDIS_CLIENT)
      client.set("upcoming-service-change-notification-#{route_id}", data, ex: 3600)
    end

    def clear_upcoming_service_change_notification(route_id, client = REDIS_CLIENT)
      client.del("upcoming-service-change-notification-#{route_id}")
    end

    def upcoming_service_change_notification(route_id, client = REDIS_CLIENT)
      data = client.get("upcoming-service-change-notification-#{route_id}")
    end

    def update_upcoming_service_change_notification_timestamp(route_id, client = REDIS_CLIENT)
      client.set("upcoming-service-change-notification-#{route_id}-timestamp", Time.current.to_i, ex: 3600)
    end

    def clear_upcoming_service_change_notification_timestamp(route_id, client = REDIS_CLIENT)
      client.del("upcoming-service-change-notification-#{route_id}-timestamp")
    end

    def upcoming_service_change_notification_timestamp(route_id, client = REDIS_CLIENT)
      client.get("upcoming-service-change-notification-#{route_id}-timestamp")
    end

    # Routings
    def current_routings(client = REDIS_CLIENT)
      client.get("current-routings")
    end

    def set_current_routings(json, client = REDIS_CLIENT)
      client.set("current-routings", json)
    end

    def evergreen_routings(client = REDIS_CLIENT)
      client.get("evergreen-routings")
    end

    def set_evergreen_routings(json, client = REDIS_CLIENT)
      client.set("evergreen-routings", json)
    end

    # Alexa
    def alexa_most_recent_stop(user_id, client = REDIS_CLIENT)
      client.get("alexa-recent-stop:#{user_id}")
    end

    def set_alexa_most_recent_stop(user_id, stop_id, client = REDIS_CLIENT)
      client.set("alexa-recent-stop:#{user_id}", stop_id, ex: 2592000)
    end

    def add_alexa_stop_query_miss(query, client = REDIS_CLIENT)
      client.sadd?("alexa-query-misses", query)
    end

    # Dynos
    def last_unempty_workqueue_timestamp(client = REDIS_CLIENT)
      client.get("last-unempty-workqueue-timestamp")&.to_i
    end

    def update_last_unempty_workqueue_timestamp(client = REDIS_CLIENT)
      client.set("last-unempty-workqueue-timestamp", Time.current.to_i)
    end

    def last_scaleup_timestamp(client = REDIS_CLIENT)
      client.get("last-scaleup-timestamp")&.to_i
    end

    def update_last_scaleup_timestamp(client = REDIS_CLIENT)
      client.set("last-scaleup-timestamp", Time.current.to_i)
    end

    # Maintenance
    def clear_outdated_trips
      FeedRetrieverSpawningWorkerBase::ALL_FEEDS.each do |feed_id|
        active_trip_list_removed = REDIS_CLIENT.zremrangebyscore("active-trips-list:#{feed_id}", '-inf', Time.current.to_i - DATA_RETENTION)
        puts "Removed #{active_trip_list_removed} outdated trips from active trips list for #{feed_id}"

        active_trips = REDIS_CLIENT.zrange("active-trips-list:#{feed_id}", 0, -1).to_set
        active_trips_in_store = REDIS_CLIENT.hgetall("active-trips:#{feed_id}").keys.to_set
        trips_to_remove = active_trips_in_store - active_trips
        trips_to_remove.each do |trip_id|
          REDIS_CLIENT.hdel("active-trips:#{feed_id}", trip_id)
        end
        puts "Removed #{trips_to_remove.size} outdated active trips for #{feed_id}"

        translations_to_remove = REDIS_CLIENT.hgetall("active-trips:translations:#{feed_id}").select { |_, v| !active_trips.include?(v) }.keys
        translations_to_remove.each do |translation|
          REDIS_CLIENT.hdel("active-trips:translations:#{feed_id}", translation)
        end

        puts "Removed #{translations_to_remove.size} outdated translations for #{feed_id}"
      end
    end

    def clear_outdated_trip_stops_and_delays
      REDIS_CLIENT.keys("travel-time:actual:*").each do |key|
        travel_times_removed = REDIS_CLIENT.zremrangebyscore(key, '-inf', Time.current.to_i - DATA_RETENTION)
        puts "Removed #{travel_times_removed} outdated travel times between #{key}"
      end

      Scheduled::Route.all.pluck(:internal_id).each do |route_id|
        [1, 3].each do |direction|
          delays_removed = REDIS_CLIENT.zremrangebyscore("delay:#{route_id}:#{direction}", '-inf', Time.current.to_i - DELAYS_RETENTION)
          puts "Removed #{delays_removed} outdated delayed trips for #{route_id}:#{direction}"
        end
      end
    end
  end
end