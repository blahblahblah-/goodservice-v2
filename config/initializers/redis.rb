require 'redis'
require 'uri'

if Rails.env == 'production'
  if ENV['REDIS_URL']
    url = URI.parse(ENV["REDIS_URL"])
    url.scheme = "rediss"
    url.port = Integer(url.port) + 1
    REDIS_CLIENT = Redis.new(url: url, driver: :ruby, ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE })
  else
    REDIS_CLIENT = Redis.new(url: ENV['REDISCLOUD_URL'])
  end
else
  REDIS_CLIENT = Redis.new(url: ENV['REDIS_URL'])
end



