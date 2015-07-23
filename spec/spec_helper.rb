$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'reliable'

Reliable.configure_redis "redis://127.0.0.1:6379"

RSpec.configure do |config|
  config.before(:each) do
    Reliable.redis.flushdb
  end
end
