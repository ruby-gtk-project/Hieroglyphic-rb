# frozen_string_literal: true

module Hieroglyphic
  # Point is an (x, y) coordinate plus the vector arithmetic the stroke
  # normalisation needs.
  #
  # Ported from upstream's src/classify/point.rs, which in turn comes from
  # detexify-rust. Upstream's Point is `Copy`; a Data is frozen, which gives the
  # same guarantee that no operation mutates its operands.
  Point = Data.define(:x, :y) do
    def +(other) = Point.new(x: x + other.x, y: y + other.y)
    def -(other) = Point.new(x: x - other.x, y: y - other.y)
    def *(scalar) = Point.new(x: x * scalar, y: y * scalar)

    # Dot product between self and another point.
    def dot(other) = (x * other.x) + (y * other.y)

    # The euclidean norm.
    def norm = Math.sqrt(dot(self))

    # Euclidean distance to the point `other`.
    def euclidean_distance(other) = (self - other).norm

    # Scales the point by `scale_x` and `scale_y`.
    def scale(scale_x, scale_y) = Point.new(x: x * scale_x, y: y * scale_y)

    # Whether the given point is within DELTA of self.
    def approx_eq?(other) = euclidean_distance(other) < Point::DELTA

    # The angle (in radians) between the two vectors formed by three points:
    # self (the origin point), `p` (an intermediate point) and `q` (the
    # endpoint).
    #
    # The division binds tighter than the `.acos()` in upstream's expression
    # (`v.dot(&w) / (v.norm() * w.norm()).clamp(-1.0, 1.0).acos()`), so the
    # product of the norms — not the cosine — is what gets clamped and inverted.
    # `dominant` thresholds against this value, so the port keeps the same
    # grouping rather than the textbook angle.
    def angle(p, q)
      (p - self).then do |v|
        (q - p).then do |w|
          v.dot(w) / Math.acos((v.norm * w.norm).clamp(-1.0, 1.0))
        end
      end
    end
  end

  # Reopened rather than configured in the Data.define block: a constant
  # assigned inside that block binds to the enclosing lexical scope, so
  # Point::DELTA would not exist.
  class Point
    # δ-value for comparing if two points are equal.
    DELTA = 1e-10

    # Point located at the origin (0,0).
    ZERO = new(x: 0.0, y: 0.0)
    # Point located at (1,1).
    ONE = new(x: 1.0, y: 1.0)
  end
end
