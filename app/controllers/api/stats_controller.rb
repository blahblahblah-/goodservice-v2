class Api::StatsController < ApplicationController
    def index
        data = {
            feeds: RedisStore.all_feed_latencies.transform_values(&:to_f),
            routes: RedisStore.all_processed_route_latencies.transform_values(&:to_f),
        }
        render json: data
    end
end