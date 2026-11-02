# frozen_string_literal: true

require_relative "onnx"
require_relative "point"
require_relative "rect"
require_relative "stroke"

module Hieroglyphic
  # Classifier turns hand-drawn strokes into the ids of the symbols they most
  # look like: it normalises the strokes, draws them into a 1x3x32x32 tensor,
  # runs the tensor through the shipped convolutional model, and reads the 25
  # highest-scoring labels off its output.
  #
  # Ported from upstream's src/classify/classifier.rs and data/model.onnx.
  # Upstream runs the model through the `ort` crate and keeps the 1098 labels in
  # a static array in the same file; here the forward pass is Hieroglyphic::Onnx
  # (see lib/onnx.rb for why) and the labels are data/labels.txt, in the model's
  # output order, which keeps a thousand-line literal out of the source the same
  # way the symbol table does.
  #
  # The normalisation pipeline and the Bresenham rasteriser are upstream's, step
  # for step: a stroke is deduplicated, smoothed, refitted into the unit square,
  # redistributed over ten points, deduplicated again and reduced to its
  # dominant points before its segments are drawn into all three channels.
  class Classifier
    DATA_DIR = File.expand_path("../data", __dir__)
    MODEL_FILE = File.join(DATA_DIR, "model.onnx")
    LABELS_FILE = File.join(DATA_DIR, "labels.txt")

    # The shape of the model's input: one RGB image of 32x32 pixels.
    CHANNELS = 3
    SIZE = 32
    INPUT_SHAPE = [1, CHANNELS, SIZE, SIZE].freeze

    # How many of the model's labels are reported, likeliest first.
    TOP_LABELS = 25

    # Only this many strokes of a drawing are classified.
    MAX_STROKES = 10
    # How many points each stroke is redistributed over.
    STROKE_POINTS = 10
    # The widest angle (in radians) at which a point still counts as dominant.
    DOMINANT_ANGLE = 2.0 * Math::PI * 15.0 / 360.0
    # The area the strokes are refitted into before they are rasterised.
    UNIT_SQUARE = Rect.new(lower_left: Point::ZERO, upper_right: Point::ONE)

    class << self
      # The model's labels, in the order its output scores them: the base64
      # symbol ids Symbol.from_id takes.
      def labels = @labels ||= File.readlines(LABELS_FILE, chomp: true).freeze
    end

    # The ids of the symbols the given strokes most look like, likeliest first,
    # or nil when there is nothing to classify.
    def classify(sample)
      prepared = prepare(sample)

      if prepared.empty?
        nil
      else
        top_labels(model.run(input_tensor(prepared)))
      end
    end

    # The model itself, read once and reused for every classification.
    def model = @model ||= Onnx::Model.load(MODEL_FILE)

    private

      # The strokes that take part in the classification, normalised. The
      # copies are deliberate: the window hands the same strokes to the upload
      # endpoint after a symbol is copied, so normalisation must not reach them.
      def prepare(sample)
        sample.reject(&:empty?).first(MAX_STROKES).map do |stroke|
          Stroke.new(stroke.points.dup).tap do |copy|
            copy.dedup
            copy.smooth
            copy.aspect_refit(UNIT_SQUARE)
            copy.redistribute(STROKE_POINTS)
            copy.dedup
            copy.dominant(DOMINANT_ANGLE)
          end
        end
      end

      # The model's input: the strokes drawn into an otherwise empty image,
      # which is what the model was trained on.
      def input_tensor(strokes)
        Onnx::Tensor.filled(INPUT_SHAPE, 0.0).tap do |tensor|
          strokes.each do |stroke|
            pixels(stroke).each_cons(2) do |(from_x, from_y), (to_x, to_y)|
              draw_line(
                tensor.data,
                from_x,
                from_y,
                to_x,
                to_y,
              )
            end
          end
        end
      end

      # The stroke's points as pixel coordinates, scaled from the unit square
      # onto the image's 32x32 grid.
      def pixels(stroke)
        stroke.points.map do |point|
          [coordinate(point.x), coordinate(point.y)]
        end
      end

      def coordinate(value) = (value * (SIZE - 1)).round.clamp(0, SIZE - 1)

      # Draws a line from (x0, y0) to (x1, y1) into every channel of the image
      # using Bresenham's line algorithm.
      def draw_line(image, x0, y0, x1, y1)
        delta_x = (x1 - x0).abs
        delta_y = -(y1 - y0).abs
        step_x = direction(x0, x1)
        step_y = direction(y0, y1)
        error = delta_x + delta_y
        x = x0
        y = y0

        loop do
          plot(image, x, y)

          if x == x1 && y == y1
            break
          end

          doubled = 2 * error

          if doubled >= delta_y
            if x == x1
              break
            end

            error += delta_y
            x += step_x
          end

          if doubled <= delta_x
            if y == y1
              break
            end

            error += delta_x
            y += step_y
          end
        end
      end

      def direction(from, to)
        if from < to
          1
        else
          -1
        end
      end

      # Lights one pixel in all three channels, as upstream's grayscale-in-RGB
      # input does.
      def plot(image, x, y)
        CHANNELS.times do |channel|
          image[(((channel * SIZE) + y) * SIZE) + x] = 1.0
        end
      end

      # The labels of the highest-scoring outputs, likeliest first. Ties keep
      # the model's own label order, as upstream's stable sort does.
      def top_labels(output)
        if output.size != self.class.labels.size
          raise("the model scored #{output.size} labels, but #{self.class.labels.size} are known")
        end

        output.data.each_with_index.sort_by { |score, index| [-score, index] }
          .first(TOP_LABELS)
          .map { |_score, index| self.class.labels[index] }
      end
  end
end
