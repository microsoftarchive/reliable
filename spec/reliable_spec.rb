require 'spec_helper'

describe Reliable do
  it "caches queues" do
    queue = Reliable[:foo]
    expect(queue).to be_a(Reliable::Queue)
    expect(Reliable[:foo]).to be(queue)
  end
end
