require "spec_helper"

describe Reliable::List do
  let(:redis) { Reliable.redis }
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

      it { expect(list.all).to eql(["2","3","1"]) }
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

      it { expect(list.size).to eql(3) }
    end
  end
end
