require 'redis'

REDIS_CLIENT = Redis.new(url: ENV['REDIS_URL'])