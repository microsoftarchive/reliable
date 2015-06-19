require_relative '../reliable'
require_relative 'clock'
require_relative 'list'
require_relative 'uuid'

module Reliable
  class Queue
    FatalError = Class.new(StandardError)

    attr_reader :clock

    def initialize(name)
      base_key = "reliable:queues:#{name}"
      @pending_key = base_key + ":pending"
      @processing_key = base_key + ":processing"
      @failed_processing_key = base_key + ":failed:processing"
      @failed_removing_key = base_key + ":failed:removing"
      @clock = Clock.new(base_key + ":time", self)
      @mutex = Mutex.new
    end

    def synchronize
      @mutex.synchronize { yield }
    end

    def current_time
      if ENV["USE_CLOCK"] == "yes"
        @clock.fetch_time
      else
        Time.now.utc.to_i
      end
    end

    def push(value)
      redis_multi do
        UUID.new(current_time) do |uuid|
          redis.call! "SET", uuid.to_s, value
          redis.call! "LPUSH", pending.key, uuid.to_s
        end
      end
    end
    alias_method :<<, :push

    def to_enum(&block)
      Enumerator.new do |y|
        loop do                     # forever
          result = work_one(&block) # do work
          y.yield result            # then release control
        end
      end
    end

    def work_one(&block)
      uuid, item = fetch_item

      if uuid && item
        catch(:failed) do
          process uuid, item, &block
          remove uuid
        end
      end

      item
    end
    private :work_one

    def take(number, &block)
      to_enum(&block).take(number)
    end

    def each(&block)
      if block_given?
        # This is because we confuse iteration with work here
        # So we need to front-load the work, then fake the iteration
        to_enum(&block).each { |item| item }
      else
        to_enum
      end
    end

    def peach(concurrency = 1, &block)
      raise "must supply a block" unless block_given?

      threads = concurrency.times.map do
        Thread.new { each(&block) }
      end

      threads.map(&:join)
    end

    def pending
      @pending ||= List.new(@pending_key, redis)
    end

    def processing
      @processing ||= List.new(@processing_key, redis)
    end

    def failed_processing
      @failed_processing ||= List.new(@failed_processing_key, redis)
    end

    def failed_removing
      @failed_removing ||= List.new(@failed_removing_key, redis)
    end

    def stale_items
      processing.all.select { |uuid_key| uuid = UUID.parse(uuid_key); current_time - uuid.time > PROCESSING_TIMEOUT }
    end

    def redis
      Reliable.redis
    end

    def fetch_item
      uuid = synchronize { redis.call!("BRPOPLPUSH", pending.key, processing.key, POP_TIMEOUT) }

      if uuid
        [uuid, synchronize { redis.call!("GET", uuid) }]
      else
        [nil, nil]
      end
    rescue StandardError => e
      notify(e, uuid: uuid)
      [nil, nil]
    end

    def process(uuid, item, &block)
      if block_given?
        block.yield item
      else
        # NOTE: What do we do here?
        item
      end
    rescue StandardError => e
      move uuid, processing.key, failed_processing.key
      notify(e) # order here matters, we want to move to failures before we try to do anything else
      throw :failed
    end

    def redis_multi
      synchronize do
        begin
          redis.call! "MULTI"
          yield
          redis.call! "EXEC"
        rescue StandardError => e
          redis.call! "DISCARD"
          raise e
        end
      end
    end

    def remove(uuid)
      redis_multi do
        redis.call! "LREM", processing.key, 0, uuid
        redis.call! "DEL", uuid
      end
    rescue StandardError => e
      notify(e) # order here matters, if this erorrs it was probably redis and the next #move call will probably fail
      move uuid, processing.key, failed_removing.key
    end

    def move(value, from, to)
      redis_multi do
        redis.call! "LREM", from, 0, value
        redis.call! "LPUSH", to, value
      end
    rescue StandardError => e
      notify(e) # yes, we need to notify here because if this fails we will never make it to the notify in #process
      raise
    end

    def notify(e, other = {})
      # TODO: make configurable
      Rails.logger.info e.inspect
      Rails.logger.info e.backtrace
      Rails.logger.info other.inspect
    end
  end
end
