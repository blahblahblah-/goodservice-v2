require 'sidekiq/api'

class HerokuAutoscalerWorker
  include Sidekiq::Worker
  sidekiq_options retry: false, queue: 'critical'

  MINIMUM_NUMBER_OF_DYNOS = 1
  MAXIMUM_NUMBER_OF_DYNOS = 10
  SCALEUP_DELAY = 2.minutes.to_i
  SCALE_DOWN_THRESHOLD = ENV['AUTOSCALER_SCALE_DOWN_THRESHOLD']&.to_i || 0

  def perform
    return unless ENV['HEROKU_OAUTH_TOKEN'] && ENV['HEROKU_APP_NAME']
    heroku = PlatformAPI.connect_oauth(ENV['HEROKU_OAUTH_TOKEN'])
    info = heroku.formation.info(ENV['HEROKU_APP_NAME'], 'worker')
    return unless info

    number_of_dynos = info['quantity']
    queue_latency = Sidekiq::Queue.new.latency
    jobs_in_queue = Sidekiq::Queue.new.size
    puts "HerokuAutoscaler: #{number_of_dynos} dynos, queue latency #{queue_latency}, #{jobs_in_queue} jobs"

    if jobs_in_queue <= SCALE_DOWN_THRESHOLD
      last_unempty_timestamp = RedisStore.last_unempty_workqueue_timestamp
      if last_unempty_timestamp && (Time.current - Time.zone.at(last_unempty_timestamp) >= 10.minutes) && number_of_dynos > MINIMUM_NUMBER_OF_DYNOS
        new_quantity = number_of_dynos - 1
        heroku.formation.update(ENV['HEROKU_APP_NAME'], 'worker', {"quantity" => new_quantity})
        puts "HerokuAutoscaler: Scaled down to #{new_quantity} dynos"

        # Reset counter
        RedisStore.update_last_unempty_workqueue_timestamp
      end
    else
      if queue_latency > 15
        if number_of_dynos < MAXIMUM_NUMBER_OF_DYNOS && (!RedisStore.last_scaleup_timestamp || RedisStore.last_scaleup_timestamp < Time.current.to_i  - SCALEUP_DELAY)
          new_quantity = number_of_dynos + 1
          heroku.formation.update(ENV['HEROKU_APP_NAME'], 'worker', {"quantity" => new_quantity})
          puts "HerokuAutoscaler: Scaled up to #{new_quantity} dynos"
          RedisStore.update_last_scaleup_timestamp
        end
      end
      RedisStore.update_last_unempty_workqueue_timestamp
    end
  end
end
