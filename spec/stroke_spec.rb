# frozen_string_literal: true

require_relative "../lib/stroke"

# Pins the same properties as upstream's src/classify/stroke.rs inline tests
# (mod tests): bounding_box, refit (including its single-point degenerate
# case, where the box has zero width/height and is centered instead of
# scaled), and smooth.
RSpec.describe Hieroglyphic::Stroke do
  half_point = Hieroglyphic::Point.new(x: 0.5, y: 0.5)

  describe "#bounding_box" do
    it "encompasses all points of the stroke" do
      stroke = described_class.new([
        Hieroglyphic::Point.new(x: 1.0, y: 1.0),
        Hieroglyphic::Point.new(x: -1.0, y: -1.0),
      ],)

      expect(stroke.bounding_box).to(
        eq(
          Hieroglyphic::Rect.new(
            lower_left:  Hieroglyphic::Point.new(x: -1.0, y: -1.0),
            upper_right: Hieroglyphic::Point.new(x: 1.0, y: 1.0),
          ),
        ),
      )
    end

    it "raises for an empty stroke" do
      expect { described_class.new([]).bounding_box }.to(raise_error(ArgumentError))
    end
  end

  describe "#refit (private)" do
    rect = Hieroglyphic::Rect.new(lower_left: Hieroglyphic::Point::ZERO, upper_right: Hieroglyphic::Point::ONE)

    it "centers a single-point stroke in the target rect, instead of scaling a zero-width box" do
      stroke = described_class.new([Hieroglyphic::Point.new(x: -100.0, y: 0.0)])
      stroke.send(:refit, rect)

      expect(stroke).to(eq(described_class.new([half_point])))
    end

    it "scales a two-point stroke to fill the target rect" do
      stroke = described_class.new([
        Hieroglyphic::Point.new(x: -100.0, y: 0.0),
        Hieroglyphic::Point.new(x: 0.0, y: 100.0),
      ],)
      stroke.send(:refit, rect)

      expect(stroke).to(eq(described_class.new([Hieroglyphic::Point::ZERO, Hieroglyphic::Point::ONE])))
    end
  end

  describe "#smooth" do
    it "averages triplets of points, keeping the first and last point fixed" do
      stroke = described_class.new([
        Hieroglyphic::Point.new(x: 1.2311, y: 1.323),
        Hieroglyphic::Point.new(x: 2.121, y: 2.4123),
        Hieroglyphic::Point.new(x: 3.213, y: 3.251),
        Hieroglyphic::Point.new(x: 1.412, y: 4.02441),
      ],)
      stroke.smooth

      expect(stroke).to(
        eq(
          described_class.new([
            Hieroglyphic::Point.new(x: 1.2311, y: 1.323),
            Hieroglyphic::Point.new(x: 2.1883666666666666, y: 2.3287666666666667),
            Hieroglyphic::Point.new(x: 2.2486666666666664, y: 3.229236666666666),
            Hieroglyphic::Point.new(x: 1.412, y: 4.02441),
          ],),
        ),
      )
    end

    it "leaves a stroke of fewer than three points unchanged" do
      stroke = described_class.new([
        Hieroglyphic::Point.new(x: 0.0, y: 0.0),
        Hieroglyphic::Point.new(x: 1.0, y: 1.0),
      ],)
      stroke.smooth

      expect(stroke).to(
        eq(
          described_class.new([
            Hieroglyphic::Point.new(x: 0.0, y: 0.0),
            Hieroglyphic::Point.new(x: 1.0, y: 1.0),
          ],),
        ),
      )
    end
  end
end
