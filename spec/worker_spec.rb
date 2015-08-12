require "spec_helper"
require "reliable/worker"
require "reliable/queue"

describe Reliable::Worker do
  let(:queue) { Reliable::Queue.new("foo") }
  let(:results) { [] }
  let(:worker) do
    described_class.new(queue) { |item| results << item }
  end

  before { queue.push "1" }

  it "can work an item without error" do
    expect { worker.next }.to_not raise_error
    expect { worker.next }.to_not raise_error
  end

  it "can work an item and return it" do
    expect(worker.next).to eq("1")
    expect(worker.next).to eq(nil)
  end
end
