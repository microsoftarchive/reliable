require 'delegate'
require_relative 'threadsafe_redis_connection'

module Reliable
  class Redis < SimpleDelegator
    def initialize(connection)
      super ThreadsafeRedisConnection.new(connection)
    end

    def keys(pattern)
      synchronize do
        command "KEYS", pattern
      end
    end

    def flushdb
      synchronize do
        command "FLUSHDB"
      end
    end

    def get(key)
      synchronize do
        command "GET", key
      end
    end

    def get_all(key)
      synchronize do
        command "LRANGE", key, 0, -1
      end
    end

    def incr(key)
      synchronize do
        command "INCR", key
      end
    end

    def size(key)
      synchronize do
        command "LLEN", key
      end
    end

    def brpoplpush(pop_key, push_key)
      synchronize do
        command "BRPOPLPUSH", pop_key, push_key, POP_TIMEOUT
      end
    end

    def lpush(key, value)
      synchronize do
        command "LPUSH", key, value
      end
    end

    def push(list_key, key, value)
      multi do
        command "SET", key, value
        command "LPUSH", list_key, key
      end
    end

    def move(value, from_key, to_key)
      multi do
        command "LREM", from_key, 0, value
        command "LPUSH", to_key, value
      end
    end

    def remove(list_key, key)
      multi do
        command "LREM", list_key, 0, key
        command "DEL", key
      end
    end
  end
end
