# frozen_string_literal: true

require "adwaita"

module Hieroglyphic
  # IndicatorButton is the header-bar button that opens the contribution
  # dialog, with a small dot in the accent colour nudging towards it until the
  # dialog has been opened once.
  #
  # Ported from upstream's src/widgets/indicator_button.rs. Upstream is a
  # GtkButton subclass that paints the dot in its own `snapshot`; the Ruby
  # bindings do not let a Ruby subclass override a widget vfunc, so the port
  # overlays the dot on the button and paints it with Cairo. It keeps upstream's
  # 8px dot, and redraws it when the system accent colour changes.
  class IndicatorButton
    DOT_SIZE = 8
    # Upstream paints the dot into the rect (14, 15, 8, 8) of the button, so
    # the overlay is offset from the same corner by the same amounts.
    DOT_OFFSET_X = 14
    DOT_OFFSET_Y = 15

    def initialize(action_name:, icon_name:, tooltip_text:)
      @action_name = action_name
      @icon_name = icon_name
      @tooltip_text = tooltip_text
      @show_indicator = false
    end

    def build
      overlay.tap do |o|
        o.child = button
        o.add_overlay(indicator)

        indicator.tap do |dot|
          dot.set_draw_func { |_, context, width, height| draw(context, width, height) }
        end

        Adwaita::StyleManager.default.signal_connect("notify::accent-color-rgba") do
          indicator.queue_draw
        end
      end
    end

    # Whether the indicator is painted.
    def show_indicator? = @show_indicator

    # Sets the visibility of the indicator.
    def show_indicator=(show_indicator)
      @show_indicator = show_indicator
      indicator.visible = show_indicator
      indicator.queue_draw
    end

    def overlay = @overlay ||= Gtk::Overlay.new

    def button
      @button ||= Gtk::Button.new.tap do |b|
        b.action_name = @action_name
        b.icon_name = @icon_name
        b.tooltip_text = @tooltip_text
      end
    end

    def indicator
      @indicator ||= Gtk::DrawingArea.new.tap do |area|
        area.content_width = DOT_SIZE
        area.content_height = DOT_SIZE
        area.halign = :start
        area.valign = :start
        area.margin_start = DOT_OFFSET_X
        area.margin_top = DOT_OFFSET_Y
        area.visible = false
        # the dot is decoration; clicks belong to the button underneath it
        area.can_target = false
      end
    end

    private

      def draw(context, width, height)
        Adwaita::StyleManager.default.accent_color_rgba.then do |color|
          context.set_source_rgba(
            color.red,
            color.green,
            color.blue,
            color.alpha,
          )
        end
        context.arc(
          width / 2.0,
          height / 2.0,
          [width, height].min / 2.0,
          0,
          2 * Math::PI,
        )
        context.fill
      end
  end
end
