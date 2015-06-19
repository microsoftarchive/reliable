require "spec_helper"

describe Reliable::UUID do
  describe ".parse" do
    context "with well formed key" do
      let(:time) { Time.now }
      let(:key) { described_class.new(time).to_s }

      it { expect(described_class.parse(key).to_s).to eql(key) }
    end

    context "with malformed key" do
      it { expect{described_class.parse("foobar")}.to raise_error(Reliable::MalformedUUID) }
    end
  end
end
