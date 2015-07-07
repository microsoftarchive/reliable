module Reliable
  class List
    attr_reader :key

    def initialize(key, redis)
      @key = key
      @redis = redis
    end

    def all
      @redis.get_all(key)
    end

    def size
      @redis.size(key)
    end
  end
end
