require 'logger'
require 'securerandom'

require_relative '../reliable'
require_relative 'clock'
require_relative 'list'
require_relative 'uuid'
require_relative 'worker'

module Reliable
  class Queue
    FatalError = Class.new(StandardError)

    attr_accessor :base_key, :uuid

    def initialize(name)
      @name = name
      @base_key = "reliable:queues:#{name}"
      @redis = Redis.new
      @pending_key = @base_key + ":pending"
      @failed_key = @base_key + ":failed"
      @clock = Clock.new(base_key + ":time", @redis)
    end

    def current_time
      @clock.current_time
    end

    def push(value)
      UUID.new(current_time) do |uuid|
        @redis.set_and_lpush(pending.key, uuid.to_s, value)
      end
    end
    alias_method :<<, :push

    def pending
      @pending ||= List.new(@pending_key, @redis)
    end

    def failed
      @failed ||= List.new(@failed_key, @redis)
    end

    def create_worker(&work)
      Worker.new(self, &work)
    end

    def to_enum(&work)
      work ||= ->(item) { item }
      worker = create_worker(&work)
      Enumerator.new do |y|
        loop do                   # forever
          result = worker.next    # do work
          y.yield result          # then release control
        end
      end
    end

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

    def peach(opts = {}, &block)
      raise "must supply a block" unless block_given?

      concurrency = opts.fetch(:concurrency)

      threads = concurrency.times.map do
        Thread.new { each(&block) }
      end

      threads.map { |t| t.abort_on_exception = true }
      threads.map(&:join)
    end

    def total_processing
      keys = @redis.scan "reliable:queues:*:workers:*:processing"

      lengths = @redis.pipeline do |pipe|
        keys.each do |key|
          pipe.llen key
        end
      end

      lengths.map(&:to_i).reduce(0, &:+)
    end

    def total_items
      @redis.scan("reliable:items:*").length
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
