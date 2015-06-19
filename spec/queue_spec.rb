require "spec_helper"

describe Reliable::Queue do
  let(:name) { "foo" }
  let(:queue) { described_class.new(name) }

  def get_keys
    Reliable.redis.call "KEYS", "*"
  end

  def select_keys(&blk)
    get_keys.select(&blk)
  end

  def mutation_keys
    select_keys { |key| key =~ /^reliable:items:/ }
  end

  describe "writing and reading" do
    before do
      queue.redis.call "FLUSHDB"
      queue.push(1)
      queue.push(5)
      queue.push(2)
      queue.push(3)
    end

    it { expect(queue.each.take(4)).to eql(["1","5","2","3"]) }
    it { expect(mutation_keys.length).to eql(4) }
  end

  describe "#pending" do
    context "with values pushed on" do
      before do
        queue.redis.call "FLUSHDB"
        queue.push(1)
        queue.push(5)
        queue.push(2)
        queue.push(3)
      end

      it { expect(queue.pending.size).to eql(4) }
      it { expect(queue.processing.size).to eql(0) }
      it { expect(queue.failed_processing.size).to eql(0) }
      it { expect(queue.failed_removing.size).to eql(0) }
      it { expect(mutation_keys.length).to eql(4) }
    end

    context "with values pushed on and taken off" do
      before do
        queue.redis.call "FLUSHDB"
        queue.push(1)
        queue.push(5)
        queue.push(2)
        queue.push(3)
        queue.take(2)
      end

      it { expect(queue.pending.size).to eql(2) }
      it { expect(queue.processing.size).to eql(0) }
      it { expect(queue.failed_processing.size).to eql(0) }
      it { expect(queue.failed_removing.size).to eql(0) }
      it { expect(mutation_keys.length).to eql(2) }
    end
  end

  describe "#failures" do
    context "with values pushed on" do
      before do
        queue.redis.call "FLUSHDB"
        queue.push("fail")
        queue.push("succeed")
        queue.take(2) { |item| raise("wat") if item == "fail" }
      end

      it { expect(queue.pending.size).to eql(0) }
      it { expect(queue.processing.size).to eql(0) }
      it { expect(queue.failed_processing.size).to eql(1) }
      it { expect(queue.failed_removing.size).to eql(0) }
      it { expect(mutation_keys.length).to eql(1) }
    end

    context "take multiple failures" do
      before do
        queue.redis.call "FLUSHDB"
        queue.push "succeed"
        queue.push "fail"
        queue.push "fail"
        queue.push "succeed"
        queue.push "succeed"
        queue.to_enum { |item| raise("wat") if item == "fail" }.take(4)
      end

      it { expect(queue.pending.size).to eql(1) }
      it { expect(queue.processing.size).to eql(0) }
      it { expect(queue.failed_processing.size).to eql(2) }
      it { expect(queue.failed_removing.size).to eql(0) }
      it { expect(mutation_keys.length).to eql(3) } # the 2 failed ones and the 1 that hasn't been processed yet
    end
  end
end
