require_relative 'reliable/version'
require_relative 'reliable/queue'
require_relative 'reliable/redis'

module Reliable
  POP_TIMEOUT = ENV.fetch("RELIABLE_TIMEOUT", "2").to_i
  TIME_TRAVEL_DELAY = ENV.fetch("RELIABLE_TIME_TRAVEL_DELAY", "60").to_i
  PROCESSING_TIMEOUT = ENV.fetch("PROCESSING_TIMEOUT", "120").to_i

  @queues = Hash.new do |h, k|
    h[k] = Queue.new(k)
  end

  def self.[](queue)
    @queues[queue]
  end

  class NullLogger
    def debug(*); end
    def info(*); end
    def error(*); end
    def warn(*); end
    def fatal(*); end
  end

  def self.logger
    @logger ||= NullLogger.new
  end

  def self.logger=(new_logger)
    @logger = new_logger
  end
end
