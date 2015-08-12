require 'securerandom'
require 'delegate'

module Reliable
  class Worker
    extend Forwardable

    delegate [:pending, :failed] => :@queue

    def initialize(queue, &block)
      @queue = queue
      @block = block
      @processing_key = "#{queue.base_key}:workers:#{SecureRandom.uuid}:processing"
      @redis = Redis.new
    end

    def processing
      @processing ||= List.new(@processing_key, @redis)
    end

    def next
      uuid = @redis.brpoplpush pending.key, processing.key
      return if uuid.nil?

      item = @redis.get uuid

      if item
        catch(:failed) do
          process item, &@block
          @redis.lpop_and_del processing.key, uuid
          logger.info "Processed #{uuid}"
        end
      end

      item
    rescue StandardError => e
      @redis.rpoplpush processing.key, failed.key
      notify(e, uuid: uuid, worker: processing.key)
      nil
    end

    def process(item, &block)
      if block_given?
        block.yield item
      else
        # NOTE: What do we do here?
        item
      end
    rescue StandardError => e
      @redis.rpoplpush processing.key, failed.key
      notify(e, worker: processing.key)
      throw :failed
    end
    private :process

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
