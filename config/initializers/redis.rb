require 'redis'
require 'uri'

if Rails.env == 'production'
  if ENV['REDIS_URL']
    REDIS_CLIENT =Redis.new(url: ENV["REDIS_URL"], ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE })
  else
    REDIS_CLIENT = Redis.new(url: ENV['REDISCLOUD_URL'])
  end
else
  REDIS_CLIENT = Redis.new(url: ENV['REDIS_URL'])
end



