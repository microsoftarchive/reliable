require 'securerandom'

module Reliable
  MalformedUUID = Class.new(StandardError)

  class UUID
    def self.parse(key)
      _, _, time, random = key.split(":")
      raise MalformedUUID unless time && random
      new(time, random)
    end

    attr_reader :random

    def initialize(time, random = SecureRandom.uuid)
      @time = time
      @random = random
      yield(self) if block_given?
    end

    def time
      @time.to_i
    end

    def to_s
      "reliable:items:#{time}:#{random}"
    end
  end
end
