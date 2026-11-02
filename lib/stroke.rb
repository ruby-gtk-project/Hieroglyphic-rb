# frozen_string_literal: true

require_relative "point"
require_relative "rect"

module Hieroglyphic
  # Stroke is a list of connected Points: one press-drag-release of the pointer
  # in the drawing area, and the unit the classifier normalises.
  #
  # Ported from upstream's src/classify/stroke.rs, which in turn comes from
  # detexify-rust. Upstream's `Stroke(Vec<Point>)` is mutated in place by the
  # normalisation steps, so this is a plain class rather than a Data.
  class Stroke
    # Number of iterations `redistribute` is allowed before it gives up, matching
    # upstream's loop guard.
    REDISTRIBUTE_ITERATIONS = 100

    attr_reader :points

    def initialize(points = [])
      @points = points
    end

    # Whether the stroke contains no Points.
    def empty? = @points.empty?

    # Removes all points from the stroke.
    def clear = @points = []

    # Appends a Point to the end of the stroke.
    def add_point(point) = @points << point

    # The total length of the stroke: the sum of the distances between all of
    # its points.
    def length = @points.each_cons(2).sum { |p, q| p.euclidean_distance(q) }

    # A bounding box encompassing all points in the stroke.
    #
    # Raises if the stroke is empty, as upstream's assert does.
    def bounding_box
      if empty?
        raise(ArgumentError, "an empty stroke has no bounding box")
      end

      @points.drop(1).inject(Rect.from_point(@points.first)) do |box, point|
        box.encompass_point(point)
      end
    end

    # Maps all points to fit within the given Rect, keeping the aspect ratio
    # and the relative distance between the points the same.
    def aspect_refit(target) = refit(aspect_rect(bounding_box, target))

    # Removes points that are nearly identical to their predecessor.
    def dedup
      @points = @points.chunk_while { |p, q| p.approx_eq?(q) }.map(&:first)
    end

    # Smooths the stroke by averaging triplets of its points, keeping the start
    # and end point where they are.
    def smooth
      if @points.size >= 3
        @points = [
          @points.first,
          *@points.each_cons(3).map { |x, y, z| (x + y + z) * (1.0 / 3.0) },
          @points.last,
        ]
      end
    end

    # Redistributes the points of the stroke so they sit at an equal distance
    # from each other, aiming for `count` points in total.
    def redistribute(count)
      if @points.size >= 2
        distribute(length / (count - 1.0))
      end
    end

    # Filters the points down to the dominant ones: those whose angle to their
    # neighbours is no wider than the `alpha` threshold (in radians).
    def dominant(alpha)
      if @points.size >= 3
        @points = [
          @points.first,
          *@points.each_cons(3).select { |p, q, r| p.angle(q, r) <= alpha }.map { |_p, q, _r| q },
          @points.last,
        ]
      end
    end

    def ==(other) = other.is_a?(Stroke) && other.points == @points

    # The representation the upload endpoint expects: upstream derives
    # `Serialize` on the newtype, so a stroke is a bare list of {x, y} objects.
    def as_json = @points.map { |point| {"x" => point.x, "y" => point.y} }

    private

      # Maps all points to fit within the given Rect, stretching each axis
      # independently.
      def refit(rect)
        bounding_box.then do |box|
          translation = Point.new(
            x: axis_translation(box.width, rect.lower_left.x, rect.width),
            y: axis_translation(box.height, rect.lower_left.y, rect.height),
          )

          @points = @points.map do |point|
            (point - box.lower_left).scale(
              axis_scale(box.width, rect.width),
              axis_scale(box.height, rect.height),
            ) + translation
          end
        end
      end

      def axis_scale(extent, target_extent)
        if extent.zero?
          1.0
        else
          1.0 / extent * target_extent
        end
      end

      def axis_translation(extent, target_origin, target_extent)
        if extent.zero?
          target_origin + (0.5 * target_extent)
        else
          target_origin
        end
      end

      # The Rect `refit` is handed by `aspect_refit`: the target area shrunk to
      # the source's aspect ratio and centred on the axis that has room left.
      def aspect_rect(source, target)
        if source.point?
          Rect.from_point((target.lower_left + target.upper_right) * 0.5)
        else
          scale = aspect_scale(source, target)
          offset = aspect_offset(source, target, scale)
          source.map_points { |point| ((point - source.lower_left) * scale) + (offset + target.lower_left) }
        end
      end

      def aspect_scale(source, target)
        if (source.width / source.height) > (target.width / target.height)
          1.0 / source.width * target.width
        else
          1.0 / source.height * target.height
        end
      end

      def aspect_offset(source, target, scale)
        if (source.width / source.height) > (target.width / target.height)
          Point.new(x: 0.0, y: (target.height - (scale * source.height)) / 2.0)
        else
          Point.new(x: (target.width - (scale * source.width)) / 2.0, y: 0.0)
        end
      end

      # Walks the stroke inserting a point every `dist` units of travelled
      # length, which is what makes the points equidistant.
      def distribute(dist)
        work_list = @points.dup
        distributed = [@points.first]
        left = dist
        iterations = REDISTRIBUTE_ITERATIONS

        while work_list.size >= 2 && iterations.positive?
          iterations -= 1
          point = work_list.shift
          direction = work_list.first - point
          distance = direction.norm

          if distance < left
            left -= distance
          else
            (point + (direction * (left / distance))).then do |inserted|
              left = dist
              work_list.unshift(inserted)
              distributed << inserted
            end
          end
        end

        @points = distributed + work_list
      end
  end
end
