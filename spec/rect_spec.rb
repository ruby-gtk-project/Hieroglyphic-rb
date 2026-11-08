# frozen_string_literal: true

require_relative "../lib/rect"

# Pins the same properties as upstream's src/classify/rect.rs inline tests
# (mod tests): a point-rect's zero size, and encompass_point growing a rect.
RSpec.describe Hieroglyphic::Rect do
  describe ".from_point" do
    it "builds a rect that is only a point" do
      expect(described_class.from_point(Hieroglyphic::Point::ZERO).point?).to(be(true))
    end
  end

  describe "#width and #height" do
    it "are zero for a point rect" do
      rect = described_class.from_point(Hieroglyphic::Point::ZERO)

      expect(rect.width).to(eq(0.0))
      expect(rect.height).to(eq(0.0))
    end
  end

  describe "#encompass_point" do
    it "grows the rect to include the given point" do
      rect = described_class.from_point(Hieroglyphic::Point::ZERO).encompass_point(Hieroglyphic::Point::ONE)

      expect(rect).to(
        eq(described_class.new(lower_left: Hieroglyphic::Point::ZERO, upper_right: Hieroglyphic::Point::ONE)),
      )
    end

    it "leaves the rect unchanged when the point is already inside it" do
      rect = described_class.new(lower_left: Hieroglyphic::Point::ZERO, upper_right: Hieroglyphic::Point::ONE)
      inside = Hieroglyphic::Point.new(x: 0.5, y: 0.5)

      expect(rect.encompass_point(inside)).to(eq(rect))
    end
  end
end
