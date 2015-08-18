$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
ENV["RELIABLE_TIMEOUT"] = "1"
ENV["RELIABLE_TIME_TRAVEL_DELAY"] = "1"
ENV["REDIS_URI"] = "redis://127.0.0.1:6379/0"
require 'reliable'

RSpec.configure do |config|
  redis = Reliable::Redis.new
  config.before(:each) do
    redis.scommand "FLUSHDB"
  end
end
