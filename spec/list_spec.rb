require "spec_helper"
require "reliable/list"

describe Reliable::List do
  let(:redis) { Reliable::Redis.new }
  let(:key) { "foo" }
  let(:list) { described_class.new(key, redis) }

  describe "#all" do
    context "with some stuff in redis" do
      before do
        redis.lpush key, 1
        redis.lpush key, 3
        redis.lpush key, 2
        redis.lpush "other", 4
      end

      it {
        keys = redis.scommand("LRANGE", key, 0, -1)
        expect(keys).to eql(["2","3","1"])
      }
    end
  end

  describe "#size" do
    context "with some stuff in redis" do
      before do
        redis.lpush key, 1
        redis.lpush key, 3
        redis.lpush key, 2
        redis.lpush "other", 4
      end

      it { expect(list.llen).to eql(3) }
    end
  end
end
