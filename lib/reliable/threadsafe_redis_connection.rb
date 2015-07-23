require 'redic'

module Reliable
  class ThreadsafeRedisConnection
    def initialize(connection)
      @connection = connection
      @mutex = Mutex.new
    end

    def synchronize
      @mutex.synchronize { yield }
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

    def command(*args)
      @connection.call!(*args)
    end
  end

end
