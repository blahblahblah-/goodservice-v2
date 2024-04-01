Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'], ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } }
end

Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'], ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } }
end

Sidekiq.options[:poll_interval] = 5

Sidekiq::Cron::Job.create(name: 'RoutingRefreshWorker - Every 30 secs', cron: '*/30 * * * * *', class: 'RoutingRefreshWorker')
Sidekiq::Cron::Job.create(name: 'FeedRetrieverSpawningAWorker - Every 15 secs', cron: '2-59/15 * * * * *', class: 'FeedRetrieverSpawningAWorker')
Sidekiq::Cron::Job.create(name: 'FeedRetrieverSpawningB1Worker - Every 15 secs', cron: '7-59/15 * * * * *', class: 'FeedRetrieverSpawningB1Worker')
Sidekiq::Cron::Job.create(name: 'FeedRetrieverSpawningB2Worker - Every 15 secs', cron: '17-59/15 * * * * *', class: 'FeedRetrieverSpawningB2Worker')
Sidekiq::Cron::Job.create(name: 'AccessibilityListWorker - Every 5 mins', cron: '*/5 * * * *', class: 'AccessibilityListWorker')
Sidekiq::Cron::Job.create(name: 'AccessibilityStatusesWorker - Every 5 mins', cron: '*/5 * * * *', class: 'AccessibilityStatusesWorker')
Sidekiq::Cron::Job.create(name: 'TwitterDelaysNotifierWorker - Every 1 min', cron: '* * * * *', class: 'TwitterDelaysNotifierWorker')
Sidekiq::Cron::Job.create(name: 'TwitterServiceChangesNotifierWorker - Every 1 min', cron: '* * * * *', class: 'TwitterServiceChangesNotifierWorker')
Sidekiq::Cron::Job.create(name: 'HerokuAutoscalerWorker - Every 1 min', cron: '* * * * *', class: 'HerokuAutoscalerWorker')
Sidekiq::Cron::Job.create(name: 'TravelTimesRefreshWorker - Every 2 min', cron: '*/2 * * * *', class: 'TravelTimesRefreshWorker')
Sidekiq::Cron::Job.create(name: 'RedisCleanupWorker - Every 30 mins', cron: '*/30 * * * *', class: 'RedisCleanupWorker')