require 'redis'

REDIS_CLIENT = Redis.new(url: ENV['REDIS_URL'] || ENV['REDISCLOUD_URL'])