require "spec_helper"
require "reliable/redis"
require "reliable/clock"

describe Reliable::Clock do
  let(:redis) { Reliable::Redis.new }
  let(:key)   { "test_clock" }
  let(:clock) { Reliable::Clock.new(key, redis) }

  it "should know the current time (is zero if time just began)" do
    expect(clock.current_time).to eq(0)
  end

  it "can move time forward" do
    clock.move_time_forward
    expect(clock.current_time).to eq(1)
  end

  context "with time moving" do
    before { clock.periodically_move_time_forward }
    after { clock.stop_periodically_moving_time_forward }

    it "expect time to have moved" do
      sleep 1.1
      expect(clock.current_time).to eq(1)
    end

    it "won't move time forward if someone else already has" do
      redis.set key, 1
      sleep 1.1
      expect(clock.current_time).to eq(1)
      sleep 1.1
      expect(clock.current_time).to eq(2)
    end
  end
end
