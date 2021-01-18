class RedisStore
  INACTIVE_TRIP_TIMEOUT = 30.minutes.to_i

  class << self
    # Feeds
    def feed_timestamp(feed_id)
      REDIS_CLIENT.hget("feed-timestamp", feed_id)
    end

    def update_feed_timestamp(feed_id, timestamp)
      REDIS_CLIENT.hset("feed-timestamp", feed_id, timestamp)
    end

    def feed(feed_id, minutes, half_minute)
      REDIS_CLIENT.get("feed:#{minutes}:#{half_minute}:#{feed_id}")
    end

    def add_feed(feed_id, minutes, half_minute, marshaled_data)
      REDIS_CLIENT.set("feed:#{minutes}:#{half_minute}:#{feed_id}", marshaled_data, ex: 180)
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

    def add_delay(route_id, direction, trip_id, timestamp)
      REDIS_CLIENT.zadd("delay:#{route_id}:#{direction}", timestamp, trip_id)
    end

    def trips_stopped_at(stop_id, max_time, min_time)
      REDIS_CLIENT.zrevrangebyscore("stops:#{stop_id}", max_time, min_time, withscores: true).to_h
    end

    def add_stop(stop_id, trip_id, timestamp)
      REDIS_CLIENT.zadd("stops:#{stop_id}", timestamp, trip_id)
    end

    # Travel times
    def supplementary_scheduled_travel_time(stop_id_1, stop_id_2)
      REDIS_CLIENT.hget("travel-time:supplementary", "#{stop_id_1}-#{stop_id_2}").to_f
    end

    def add_supplementary_scheduled_travel_time(stop_id_1, stop_id_2, time)
      REDIS_CLIENT.hset("travel-time:supplementary", "#{stop_id_1}-#{stop_id_2}", time)
    end

    def scheduled_travel_time(stop_id_1, stop_id_2)
      REDIS_CLIENT.hget("travel-time:scheduled", "#{stop_id_1}-#{stop_id_2}").to_i
    end

    def add_scheduled_travel_time(stop_id_1, stop_id_2, time)
      REDIS_CLIENT.hset("travel-time:scheduled", "#{stop_id_1}-#{stop_id_2}", time)
    end

    # Route statuses
    def route_status(route_id)
      REDIS_CLIENT.hget("route-status", route_id)
    end

    def route_statuses
      REDIS_CLIENT.hgetall("route-status")
    end

    def add_route_status(route_id, data)
      REDIS_CLIENT.hset("route-status", route_id, data)
    end
  end
end