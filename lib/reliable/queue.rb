require 'logger'

require_relative '../reliable'
require_relative 'clock'
require_relative 'list'
require_relative 'uuid'

module Reliable
  class Queue
    FatalError = Class.new(StandardError)

    def initialize(name, redis = Reliable.redis)
      base_key = "reliable:queues:#{name}"
      @redis = redis
      @pending_key = base_key + ":pending"
      @processing_key = base_key + ":processing"
      @failed_processing_key = base_key + ":failed:processing"
      @failed_removing_key = base_key + ":failed:removing"
      @clock = Clock.new(base_key + ":time", @redis)
    end

    def current_time
      if ENV["USE_CLOCK"] == "yes"
        @clock.fetch_time
      else
        Time.now.utc.to_i
      end
    end

    def push(value)
      UUID.new(current_time) do |uuid|
        @redis.push(pending.key, uuid.to_s, value)
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
          remove_from_processing uuid
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
      @pending ||= List.new(@pending_key, @redis)
    end

    def processing
      @processing ||= List.new(@processing_key, @redis)
    end

    def failed_processing
      @failed_processing ||= List.new(@failed_processing_key, @redis)
    end

    def failed_removing
      @failed_removing ||= List.new(@failed_removing_key, @redis)
    end

    def stale_items
      processing.all.select { |uuid_key| uuid = UUID.parse(uuid_key); current_time - uuid.time > PROCESSING_TIMEOUT }
    end

    def fetch_item
      uuid = @redis.brpoplpush(pending.key, processing.key)

      if uuid
        [uuid, @redis.get(uuid)]
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
      # TODO: if #move raises, what do we do?
      notify(e) # order here matters, we want to move to failures before we try to do anything else
      throw :failed
    end

    def remove_from_processing(uuid)
      @redis.remove(processing.key, uuid)
    rescue StandardError => e
      notify(e) # order here matters, if this erorrs it was probably redis and the next #move call will probably fail
      move uuid, processing.key, failed_removing.key
    end

    def move(value, from, to)
      @redis.move(value, from, to)
    rescue StandardError => e
      notify(e) # yes, we need to notify here because if this fails we will never make it to the notify in #process
      raise
    end

    def logger
      Reliable.logger
    end

    def notify(e, other = {})
      # TODO: make configurable
      logger.info e.inspect
      logger.info e.backtrace
      logger.info other.inspect
    end
  end
end
