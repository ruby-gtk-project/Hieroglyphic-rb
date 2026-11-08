# frozen_string_literal: true

require_relative "../lib/point"

# Pins the same properties as upstream's src/classify/point.rs inline tests
# (mod tests): point arithmetic, scalar multiplication and approx_eq's
# delta tolerance.
RSpec.describe Hieroglyphic::Point do
  # A delta smaller than Point::DELTA, used the same way upstream's
  # `SMALL_DELTA` is: to prove approx_eq? tolerates sub-delta noise.
  small_delta = 1e-11

  describe "#+" do
    it "adds the coordinates of both points" do
      point = described_class.new(x: 1.0, y: 0.0) + described_class.new(x: 2.0, y: 3.0)

      expect(point).to(eq(described_class.new(x: 3.0, y: 3.0)))
    end
  end

  describe "#-" do
    it "subtracts the coordinates of the other point" do
      point = described_class.new(x: 1.0, y: 0.0) - described_class.new(x: 2.0, y: 3.0)

      expect(point).to(eq(described_class.new(x: -1.0, y: -3.0)))
    end
  end

  describe "#*" do
    it "scales both coordinates by the scalar" do
      point = described_class.new(x: 1.0, y: 3.0) * 4.0

      expect(point).to(eq(described_class.new(x: 4.0, y: 12.0)))
    end
  end

  describe "#approx_eq?" do
    it "is true for points within DELTA of each other" do
      point = described_class.new(x: 1.0, y: 3.0)
      nearby = described_class.new(x: 1.0 + small_delta, y: 3.0 - small_delta)

      expect(point.approx_eq?(nearby)).to(be(true))
    end

    it "is false for points further apart than DELTA" do
      point = described_class.new(x: 1.0, y: 3.0)
      far = described_class.new(x: 1.1, y: 3.0)

      expect(point.approx_eq?(far)).to(be(false))
    end
  end
end
