Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'], ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } }
end

Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'], ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } }
end

Sidekiq.options[:poll_interval] = 5

Sidekiq::Cron::Job.create(name: 'RoutingRefreshWorker - Every 30 secs', cron: '*/30 * * * * *', class: 'RoutingRefreshWorker')
Sidekiq::Cron::Job.create(name: 'FeedRetrieverSpawningWorker - Every 30 secs', cron: '*/30 * * * * *', class: 'FeedRetrieverSpawningWorker')
Sidekiq::Cron::Job.create(name: 'HerokuAutoscalerWorker - Every 1 min', cron: '* * * * *', class: 'HerokuAutoscalerWorker')
Sidekiq::Cron::Job.create(name: 'RedisCleanupWorker - Every 30 mins', cron: '*/30 * * * *', class: 'RedisCleanupWorker')