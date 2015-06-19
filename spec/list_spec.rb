require "spec_helper"

describe Reliable::List do
  let(:redis) { Redic.new }
  let(:key) { "foo" }
  let(:list) { described_class.new(key, redis) }

  describe "#all" do
    context "with some stuff in redis" do
      before do
        redis.call "FLUSHALL"
        redis.call "LPUSH", key, 1
        redis.call "LPUSH", key, 3
        redis.call "LPUSH", key, 2
        redis.call "LPUSH", "other", 4
      end

      it { expect(list.all).to eql(["2","3","1"]) }
    end
  end

  describe "#size" do
    context "with some stuff in redis" do
      before do
        redis.call "FLUSHALL"
        redis.call "LPUSH", key, 1
        redis.call "LPUSH", key, 3
        redis.call "LPUSH", key, 2
        redis.call "LPUSH", "other", 4
      end

      it { expect(list.size).to eql(3) }
    end
  end
end
