require 'securerandom'

module Reliable
  MalformedUUID = Class.new(StandardError)

  class UUID
    def self.parse(key)
      _, _, time, random, tries = key.split(":")
      raise MalformedUUID unless time && random && tries
      new(time, random, tries)
    end

    attr_reader :random

    def initialize(time, random = SecureRandom.uuid, tries = 0)
      @time = time
      @random = random
      @tries = tries || 0
      yield(self) if block_given?
    end

    def time
      @time.to_i
    end

    def tries
      @tries.to_i
    end

    def incr
      @tries = tries + 1
    end

    def to_s
      "reliable:items:#{time}:#{random}:#{tries}"
    end
  end
end
