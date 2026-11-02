# frozen_string_literal: true

require "adwaita"
require_relative "point"
require_relative "stroke"

module Hieroglyphic
  # DrawingArea is the canvas the symbol is drawn on: a drag gesture collects
  # points into strokes, every finished stroke is handed to the `on_stroke_drawn`
  # callback, and all strokes are drawn until the area is cleared.
  #
  # Ported from upstream's src/widgets/drawing_area.rs and
  # data/resources/ui/drawing-area.ui. Upstream is an AdwBin subclass that
  # overrides `snapshot` and emits a `stroke-drawn` signal carrying a boxed
  # stroke list; the Ruby bindings do not let a Ruby subclass override a widget
  # vfunc, so the port draws through a Gtk::DrawingArea's draw function and
  # calls back into Ruby instead of emitting a GObject signal. The geometry is
  # upstream's: 3px round-capped lines, and a 1.5px dot for a stroke that is a
  # single point.
  class DrawingArea
    LINE_WIDTH = 3.0
    DOT_RADIUS = 1.5
    # #CCCCCC, as upstream uses on dark backgrounds.
    DARK_LINE_COLOR = [0.8, 0.8, 0.8].freeze
    # The adw @dark_2 colour, as upstream uses on light backgrounds.
    LIGHT_LINE_COLOR = [0.37, 0.36, 0.39].freeze

    def initialize(&on_stroke_drawn)
      @on_stroke_drawn = on_stroke_drawn
      @strokes = []
      @current_stroke = Stroke.new
    end

    def build
      drawing_area.tap do |area|
        area.set_draw_func { |_, context, _width, _height| draw(context) }
        area.add_controller(drag_gesture)

        drag_gesture.tap do |drag|
          drag.signal_connect("drag-begin") { |_, x, y| on_drag_begin(x, y) }
          drag.signal_connect("drag-update") { |_, x, y| on_drag_update(x, y) }
          drag.signal_connect("drag-end") { |_, x, y| on_drag_end(x, y) }
        end
      end
    end

    # Clears the drawing area.
    def clear
      @strokes = []
      @current_stroke.clear
      drawing_area.queue_draw
    end

    # The strokes drawn so far, finished ones only.
    def strokes = @strokes

    def drawing_area
      @drawing_area ||= Gtk::DrawingArea.new.tap do |area|
        area.hexpand = true
        area.vexpand = true
      end
    end

    def drag_gesture = @drag_gesture ||= Gtk::GestureDrag.new

    private

      def on_drag_begin(x, y)
        @current_stroke.add_point(Point.new(x: x, y: y))
        drawing_area.queue_draw
      end

      # x and y are the movement relative to the start coordinate, so they are
      # added to the point the drag started at.
      def on_drag_update(x, y)
        @current_stroke.points.first.then do |start|
          @current_stroke.add_point(Point.new(x: start.x + x, y: start.y + y))
        end
        drawing_area.queue_draw
      end

      def on_drag_end(_x, _y)
        @strokes << Stroke.new(@current_stroke.points)
        @current_stroke = Stroke.new
        drawing_area.queue_draw
        @on_stroke_drawn&.call(@strokes)
      end

      def draw(context)
        line_color.then { |red, green, blue| context.set_source_rgb(red, green, blue) }
        context.line_width = LINE_WIDTH
        context.line_cap = Cairo::LINE_CAP_ROUND
        context.line_join = Cairo::LINE_JOIN_ROUND

        (@strokes + [@current_stroke]).each { |stroke| draw_stroke(context, stroke) }
      end

      def draw_stroke(context, stroke)
        case stroke.points.size
        when 0 then nil
        when 1 then draw_dot(context, stroke.points.first)
        else draw_line(context, stroke)
        end
      end

      def draw_dot(context, point)
        context.arc(
          point.x,
          point.y,
          DOT_RADIUS,
          0,
          2 * Math::PI,
        )
        context.fill
      end

      def draw_line(context, stroke)
        context.move_to(stroke.points.first.x, stroke.points.first.y)
        stroke.points.drop(1).each { |point| context.line_to(point.x, point.y) }
        context.stroke
      end

      # A theme-specific colour for the drawing line.
      def line_color
        if Adwaita::StyleManager.default.dark?
          DARK_LINE_COLOR
        else
          LIGHT_LINE_COLOR
        end
      end
  end
end
