module Reliable
  class Clock
    def initialize(key, host)
      @key = key.to_s
      @host = host
      @mutex = Mutex.new
      store_time
    end

    def store_time
      @mutex.synchronize do
        @last_time = fetch_time
      end
    end

    def move_time_forward
      @host.redis.call "INCR", @key
      store_time
    end

    def time_has_progressed?
      @mutex.synchronize do
        fetch_time > @last_time + 1
      end
    end

    def periodically_move_time_forward
      @time_travel_thread = Thread.new do
        loop do
          delay_with_jitter = TIME_TRAVEL_DELAY + rand(TIME_TRAVEL_DELAY)
          sleep delay_with_jitter

          if time_has_progressed?
            store_time
          else
            move_time_forward
          end
        end
      end
    end

    def fetch_time
      @host.redis.call("GET", @key).to_i
    end

    def stop_periodically_moving_time_forward
      @time_travel_thread.terminate if @time_travel_thread && @time_travel_thread.alive?
    end
  end
end
