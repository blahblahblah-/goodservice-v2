Delayed::Worker.max_attempts = 1
Delayed::Worker.max_run_time = Rails.env.production? ? 1.minute : 10.minutes
Delayed::Worker.read_ahead = 2
Delayed::Worker.sleep_delay = 1