require 'redic'

module Reliable
  class Redis
    def initialize
      url = ENV.fetch("REDIS_URI") { ENV.fetch("REDIS_URL") }
      @connection = Redic.new(url)
      @mutex = Mutex.new
    end

    def synchronize
      @mutex.synchronize { yield }
    end

    def command(*args)
      @connection.call!(*args)
    end

    def scommand(*args)
      synchronize { command(*args) }
    end

    def get(key)
      scommand "GET", key
    end

    def set(key, value)
      scommand "SET", key, value
    end

    def incr(key)
      scommand "INCR", key
    end

    def llen(key)
      scommand "LLEN", key
    end

    def brpoplpush(pop_key, push_key, timeout = POP_TIMEOUT)
      scommand "BRPOPLPUSH", pop_key, push_key, timeout
    end

    def rpoplpush(pop_key, push_key)
      scommand "RPOPLPUSH", pop_key, push_key
    end

    def lpush(key, value)
      scommand "LPUSH", key, value
    end

    def lpop(key)
      scommand "LPOP", key
    end

    class Pipeline
      def initialize(conn)
        @connection = conn
      end

      def queue(*args)
        @connection.queue(*args)
      end
      alias_method :q, :queue

      def llen(key)
        queue "LLEN", key
      end
    end

    def pipeline
      synchronize do
        @connection.reset
        pipe = Pipeline.new(@connection)
        yield(pipe)
        @connection.commit
      end
    end

    def multi
      synchronize do
        begin
          command "MULTI"
          yield
          command "EXEC"
        rescue StandardError => e
          command "DISCARD"
          raise
        end
      end
    end

    def set_and_lpush(list_key, key, value)
      multi do
        command "SET", key, value
        command "LPUSH", list_key, key
      end
    end

    def lpop_and_del(list_key, key)
      multi do
        command "LPOP", list_key
        command "DEL", key
      end
    end

    def scan(pattern)
      keys = []
      cursor = "0"
      loop do
        cursor, list = scommand "SCAN", cursor, "MATCH", pattern
        keys << list
        break if cursor == "0"
      end
      keys.flatten.compact.uniq
    end
  end
end
