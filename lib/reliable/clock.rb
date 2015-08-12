module Reliable
  class Clock
    def initialize(key, redis)
      @key = key.to_s
      @redis = redis
      @mutex = Mutex.new
      store_time
    end

    def current_time
      @last_time
    end

    def store_time(new_time = nil)
      @mutex.synchronize do
        @last_time = new_time || fetch_time
      end
    end

    def move_time_forward
      new_time = @redis.incr @key
      store_time(new_time)
    end

    def time_has_progressed?
      @mutex.synchronize do
        remote_time = fetch_time
        if remote_time > @last_time
          remote_time
        end
      end
    end

    def periodically_move_time_forward
      @time_travel_thread = Thread.new do
        loop do
          delay_with_jitter = TIME_TRAVEL_DELAY + rand(TIME_TRAVEL_DELAY)
          sleep delay_with_jitter

          if new_time = time_has_progressed?
            store_time(new_time)
          else
            move_time_forward
          end
        end
      end
      @time_travel_thread.abort_on_exception = true
    end

    def fetch_time
      @redis.get(@key).to_i
    end

    def stop_periodically_moving_time_forward
      @time_travel_thread.terminate if @time_travel_thread && @time_travel_thread.alive?
    end
  end
end
