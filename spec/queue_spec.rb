require "spec_helper"
require "reliable/queue"

describe Reliable::Queue do
  let(:name) { "foo" }
  let(:queue) { described_class.new(name) }
  let(:redis) { Reliable::Redis.new }

  describe "writing and reading" do
    before do
      queue.push(1)
      queue.push(5)
      queue.push(2)
      queue.push(3)
    end

    it { expect(queue.take(4)).to eql(["1","5","2","3"]) }
    it { expect(queue.total_items).to eql(4) }
  end

  describe "#pending" do
    context "with values pushed on" do
      before do
        queue.push(1)
        queue.push(5)
        queue.push(2)
        queue.push(3)
      end

      it { expect(queue.pending.llen).to eql(4) }
      it { expect(queue.total_processing).to eql(0) }
      it { expect(queue.failed.llen).to eql(0) }
      it { expect(queue.total_items).to eql(4) }
    end

    context "with values pushed on and taken off" do
      before do
        queue.push(1)
        queue.push(5)
        queue.push(2)
        queue.push(3)
        queue.take(2)
      end

      it { expect(queue.pending.llen).to eql(2) }
      it { expect(queue.total_processing).to eql(0) }
      it { expect(queue.failed.llen).to eql(0) }
      it { expect(queue.total_items).to eql(2) }
    end
  end

  describe "#failures" do
    context "with values pushed on" do
      before do
        queue.push("fail")
        queue.push("succeed")
        queue.take(2) { |item| raise("wat") if item == "fail" }
      end

      it { expect(queue.pending.llen).to eql(0) }
      it { expect(queue.total_processing).to eql(0) }
      it { expect(queue.failed.llen).to eql(1) }
      it { expect(queue.total_items).to eql(1) }
    end

    context "take multiple failures" do
      before do
        queue.push "succeed"
        queue.push "fail"
        queue.push "fail"
        queue.push "succeed"
        queue.push "succeed"
        queue.to_enum { |item| raise("wat") if item == "fail" }.take(4)
      end

      it { expect(queue.pending.llen).to eql(1) }
      it { expect(queue.total_processing).to eql(0) }
      it { expect(queue.failed.llen).to eql(2) }
      it { expect(queue.total_items).to eql(3) } # the 2 failed ones and the 1 that hasn't been processed yet
    end
  end
end
