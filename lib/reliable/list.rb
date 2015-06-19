module Reliable
  class List
    attr_reader :key

    def initialize(key, redis)
      @key = key
      @redis = redis
    end

    def all
      @redis.call "LRANGE", @key, 0, -1
    end

    def size
      @redis.call "LLEN", @key
    end
  end
end
