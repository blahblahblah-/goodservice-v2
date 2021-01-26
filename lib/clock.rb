require 'clockwork'
require './config/boot'
require './config/environment'

module Clockwork
  handler do |job|
    puts "Running #{job}"
  end

  every(30.seconds, 'retrieve feeds') {
    RoutingRefreshWorker.perform_async
    FeedRetriever.retrieve_all_feeds(Time.current)
  }

  every(30.minutes, 'clean-up', at: ['**:30', '**:00']) {
    RedisCleanupWorker.perform_async
  }

  every(1.minute, 'autoscaler') {
    HerokuAutoscalerWorker.perform_async
  }
end