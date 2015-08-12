module Reliable
  class List
    attr_reader :key

    def initialize(key, redis)
      @key = key
      @redis = redis
    end

    def llen
      @redis.llen(key)
    end
  end
end
