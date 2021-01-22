require 'clockwork'
require './config/boot'
require './config/environment'

module Clockwork
  handler do |job|
    puts "Running #{job}"
  end

  every(30.seconds, 'retrieve feeds') {
    ServiceChangeAnalyzer.preload_current_routings
    FeedRetriever.retrieve_all_feeds(Time.current)
  }

  every(30.minutes, 'clean-up', at: ['**:30', '**:00']) {
    RedisStore.clear_outdated_trips
    RedisStore.clear_outdated_trip_stops_and_delays
  }

  every(2.minutes, 'autoscaler') {
    HerokuAutoscaler.run
  }
end