class HerokuAutoscaler
  MINIMUM_NUMBER_OF_DYNOS = 1
  MAXIMUM_NUMBER_OF_DYNOS = 10
  SCALE_DOWN_THRESHOLD = ENV['AUTOSCALER_SCALE_DOWN_THRESHOLD'].to_i || 0
  SCALE_UP_THRESHOLD = ENV['AUTOSCALER_SCALE_UP_THRESHOLD'].to_i || 49

  class << self
    def run
      return unless ENV['HEROKU_OAUTH_TOKEN'] && ENV['HEROKU_APP_NAME']
      heroku = PlatformAPI.connect_oauth(ENV['HEROKU_OAUTH_TOKEN'])
      info = heroku.formation.info(ENV['HEROKU_APP_NAME'], 'worker')
      return unless info

      number_of_dynos = info['quantity']
      jobs_in_queue = Delayed::Job.all.size
      puts "HerokuAutoscaler: #{number_of_dynos} dynos, #{jobs_in_queue} jobs"

      if jobs_in_queue <= SCALE_DOWN_THRESHOLD
        last_unempty_timestamp = RedisStore.update_last_unempty_workqueue_timestamp
        if last_unempty_timestamp && (Time.at(last_unempty_timestamp) - Time.current) >= 10.minutes && number_of_dynos > MINIMUM_NUMBER_OF_DYNOS
          new_quantity = number_of_dynos - 1
          heroku.formation.update(ENV['HEROKU_APP_NAME'], 'worker', {"quantity" => new_quantity})
          puts "HerokuAutoscaler: Scaled down to #{new_quantity} dynos"
        end
      else
        if jobs_in_queue > SCALE_UP_THRESHOLD
          if number_of_dynos < MAXIMUM_NUMBER_OF_DYNOS
            new_quantity = number_of_dynos + 1
            heroku.formation.update(ENV['HEROKU_APP_NAME'], 'worker', {"quantity" => new_quantity})
            puts "HerokuAutoscaler: Scaled up to #{new_quantity} dynos"
          end
        end
        RedisStore.update_last_unempty_workqueue_timestamp
      end
    end

    handle_asynchronously :run, priority: 0
  end
end