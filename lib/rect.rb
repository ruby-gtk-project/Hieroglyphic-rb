# frozen_string_literal: true

require_relative "point"

module Hieroglyphic
  # Rect is a rectangle between two Points, used as the target area the strokes
  # are refitted into before classification.
  #
  # Ported from upstream's src/classify/rect.rs. Upstream's `encompass_point`
  # takes `&mut self`; here it returns a widened copy, because a Data is frozen.
  # Both callers (Stroke#bounding_box) fold over the points either way.
  Rect = Data.define(:lower_left, :upper_right) do
    # A Rect with an area of 0, at the given point.
    def self.from_point(point) = new(lower_left: point, upper_right: point)

    # Whether the Rect is only a point.
    def point? = lower_left == upper_right

    def width = upper_right.x - lower_left.x
    def height = upper_right.y - lower_left.y

    # Maps the lower-left and the upper-right points that form the Rect with
    # the given block.
    def map_points(&block)
      Rect.new(
        lower_left:  block.call(lower_left),
        upper_right: block.call(upper_right),
      )
    end

    # Returns a Rect grown to encompass the given Point. A point already within
    # the Rect leaves it unchanged.
    def encompass_point(point)
      Rect.new(
        lower_left:  Point.new(
          x: [lower_left.x, point.x].min,
          y: [lower_left.y, point.y].min,
        ),
        upper_right: Point.new(
          x: [upper_right.x, point.x].max,
          y: [upper_right.y, point.y].max,
        ),
      )
    end
  end
end
