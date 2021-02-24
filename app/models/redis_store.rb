class RedisStore
  INACTIVE_TRIP_TIMEOUT = 30.minutes.to_i
  DATA_RETENTION = 3.hours.to_i
  DELAYS_RETENTION = 1.day.to_i
  ROUTE_UPDATE_TIMEOUT = 1.minute.to_i

  class << self
    # Feeds
    def feed_timestamp(feed_id)
      REDIS_CLIENT.hget("feed-timestamp", feed_id)
    end

    def update_feed_timestamp(feed_id, timestamp)
      REDIS_CLIENT.hset("feed-timestamp", feed_id, timestamp)
    end

    def feed(feed_id, minutes, fraction_of_minute)
      REDIS_CLIENT.get("feed:#{minutes}:#{fraction_of_minute}:#{feed_id}")
    end

    def add_feed(feed_id, minutes, fraction_of_minute, marshaled_data)
      REDIS_CLIENT.set("feed:#{minutes}:#{fraction_of_minute}:#{feed_id}", marshaled_data, ex: (Rails.env.production? ? 150 : 1800))
    end

    # Route Trips
    def route_trips(route_id, timestamp)
      REDIS_CLIENT.get("route-trips:#{route_id}:#{timestamp}")
    end

    def add_route_trips(route_id, timestamp, marshaled_data)
      REDIS_CLIENT.set("route-trips:#{route_id}:#{timestamp}", marshaled_data, ex: 300)
    end

    # Trips
    def active_trip_list(feed_id, timestamp)
      REDIS_CLIENT.zrangebyscore("active-trips-list:#{feed_id}", timestamp - INACTIVE_TRIP_TIMEOUT, "(#{timestamp}")
    end

    def add_to_active_trip_list(feed_id, trip_id, timestamp)
      REDIS_CLIENT.zadd("active-trips-list:#{feed_id}", timestamp, trip_id)
    end

    def remove_from_active_trip_list(feed_id, trip_id)
      REDIS_CLIENT.zrem("active-trips-list:#{feed_id}", trip_id)
    end

    def trip_translation(feed_id, trip_id)
      REDIS_CLIENT.hget("active-trips:translations:#{feed_id}", trip_id)
    end

    def add_trip_translation(feed_id, former_trip_id, new_trip_id)
      REDIS_CLIENT.hset("active-trips:translations:#{feed_id}", new_trip_id, former_trip_id)
    end

    def remove_trip_translations(feed_id, former_trip_id)
      REDIS_CLIENT.hgetall("active-trips:translations:#{feed_id}").select { |_, v| v == former_trip_id }.keys.each do |trip_id|
        REDIS_CLIENT.hdel("active-trips:translations:#{feed_id}", trip_id)
      end
    end

    def active_trip(feed_id, trip_id)
      REDIS_CLIENT.hget("active-trips:#{feed_id}", trip_id)
    end

    def add_active_trip(feed_id, trip_id, marshaled_trip)
      REDIS_CLIENT.hset("active-trips:#{feed_id}", trip_id, marshaled_trip)
    end

    def remove_active_trip(feed_id, trip_id)
      REDIS_CLIENT.hdel("active-trips:#{feed_id}", trip_id)
    end

    # Delays
    def add_delay(route_id, direction, trip_id, timestamp)
      REDIS_CLIENT.zadd("delay:#{route_id}:#{direction}", timestamp, trip_id)
    end

    # Route stops
    def add_route_to_route_stop(route_id, stop_id, direction, timestamp)
      REDIS_CLIENT.zadd("routes-stop:#{stop_id}:#{direction}", timestamp, route_id)
    end

    def routes_stop_at(stop_id, direction, timestamp)
      REDIS_CLIENT.zrangebyscore("routes-stop:#{stop_id}:#{direction}", timestamp - ROUTE_UPDATE_TIMEOUT, timestamp + ROUTE_UPDATE_TIMEOUT)
    end

    # Travel times
    def add_travel_time(stops_str, travel_time, timestamp)
      REDIS_CLIENT.zadd("travel-time:actual:#{stops_str}", timestamp, "#{timestamp}-#{travel_time}")
    end

    def travel_times_at(stop_id_1, stop_id_2, max_time, min_time)
      stops_str = "#{stop_id_1}-#{stop_id_2}"
      REDIS_CLIENT.zrevrangebyscore("travel-time:actual:#{stops_str}", max_time, min_time)
    end

    def supplementary_scheduled_travel_time(stop_id_1, stop_id_2)
      REDIS_CLIENT.hget("travel-time:supplementary", "#{stop_id_1}-#{stop_id_2}")&.to_f
    end

    def supplementary_scheduled_travel_times(stop_id_pairs)
      if stop_id_pairs.present?
        REDIS_CLIENT.mapped_hmget("travel-time:supplementary", *stop_id_pairs.map{ |pair| "#{pair.first}-#{pair.last}"})
      else
        {}
      end
    end

    def add_supplementary_scheduled_travel_time(stop_id_1, stop_id_2, time)
      REDIS_CLIENT.hset("travel-time:supplementary", "#{stop_id_1}-#{stop_id_2}", time)
    end

    def scheduled_travel_time(stop_id_1, stop_id_2)
      REDIS_CLIENT.hget("travel-time:scheduled", "#{stop_id_1}-#{stop_id_2}")&.to_i
    end

    def scheduled_travel_times(stop_id_pairs)
      if stop_id_pairs.present?
        REDIS_CLIENT.mapped_hmget("travel-time:scheduled", *stop_id_pairs.map{ |pair| "#{pair.first}-#{pair.last}"})
      else
        {}
      end
    end

    def add_scheduled_travel_time(stop_id_1, stop_id_2, time)
      REDIS_CLIENT.hset("travel-time:scheduled", "#{stop_id_1}-#{stop_id_2}", time)
    end

    # Route statuses
    def route_status(route_id)
      REDIS_CLIENT.hget("route-status", route_id)
    end

    def route_status_summaries
      REDIS_CLIENT.hgetall("route-status")
    end

    def add_route_status_summary(route_id, data)
      REDIS_CLIENT.hset("route-status", route_id, data)
    end

    def route_status(route_id)
      REDIS_CLIENT.get("route-status:#{route_id}")
    end

    def update_route_status(route_id, data)
      REDIS_CLIENT.set("route-status:#{route_id}", data, ex: 300)
    end

    # Routings
    def current_routings
      REDIS_CLIENT.get("current-routings")
    end

    def set_current_routings(json)
      REDIS_CLIENT.set("current-routings", json)
    end

    def evergreen_routings
      REDIS_CLIENT.get("evergreen-routings")
    end

    def set_evergreen_routings(json)
      REDIS_CLIENT.set("evergreen-routings", json)
    end

    # Dynos
    def last_unempty_workqueue_timestamp
      REDIS_CLIENT.get("last-unempty-workqueue-timestamp")&.to_i
    end

    def update_last_unempty_workqueue_timestamp
      REDIS_CLIENT.set("last-unempty-workqueue-timestamp", Time.current.to_i)
    end

    def last_scaleup_timestamp
      REDIS_CLIENT.get("last-scaleup-timestamp")&.to_i
    end

    def update_last_scaleup_timestamp
      REDIS_CLIENT.set("last-scaleup-timestamp", Time.current.to_i)
    end

    # Maintenance
    def clear_outdated_trips
      FeedRetrieverSpawningWorker::FEEDS.each do |feed_id|
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