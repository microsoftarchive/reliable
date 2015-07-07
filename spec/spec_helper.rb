$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'reliable'

Reliable.redis = Redic.new

RSpec.configure do |config|
  config.before(:each) do
    Reliable.redis.flushdb
  end
end
