# frozen_string_literal: true

require "adwaita"
require_relative "settings"

module Hieroglyphic
  # ContributionDialog asks whether the drawings of recognised symbols may be
  # submitted to Hieroglyphic's dataset. The switch is bound to the
  # `contribute-data` key, so it is also the app's only preferences surface.
  #
  # Ported from upstream's data/resources/ui/contribution-dialog.ui, which
  # upstream builds from the resource bundle in the win.show-contribution-dialog
  # action; the port builds the same widget tree in Ruby and loads the
  # illustration from the shipped file rather than from a GResource.
  class ContributionDialog
    ILLUSTRATION = File.expand_path("../data/illustrations/pen-broadcast.svg", __dir__)

    def initialize(settings)
      @settings = settings
    end

    # Builds the dialog and presents it over the given parent window.
    def present(parent)
      build.present(parent)
    end

    def build
      dialog.tap do |d|
        d.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = scrolled_window
        end

        scrolled_window.tap { |window| window.child = clamp }
        clamp.tap { |c| c.child = content }

        content.tap do |box|
          box.append(illustration_box)
          box.append(title_label)
          box.append(description_label)
          box.append(preferences_group)
          box.append(privacy_label)

          illustration_box.tap { |b| b.append(illustration) }
          preferences_group.tap { |group| group.add(switch_row) }
        end

        @settings.bind("contribute-data", switch_row, "active")
      end
    end

    def dialog
      @dialog ||= Adwaita::Dialog.new.tap do |d|
        d.title = _("Improve Hieroglyphic")
        d.content_width = 500
        d.content_height = 500
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar
      @header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
        bar.show_title = false
      end
    end

    def scrolled_window
      @scrolled_window ||= Gtk::ScrolledWindow.new.tap do |window|
        window.hscrollbar_policy = :never
      end
    end

    def clamp = @clamp ||= Adwaita::Clamp.new

    def content
      @content ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.margin_start = 12
        box.margin_end = 12
        box.margin_bottom = 12
        box.valign = :center
      end
    end

    def illustration_box
      @illustration_box ||= Gtk::Box.new(:horizontal, 0).tap do |box|
        box.halign = :center
      end
    end

    def illustration
      @illustration ||= Gtk::Picture.new.tap do |picture|
        picture.filename = ILLUSTRATION
        picture.can_shrink = false
      end
    end

    def title_label
      @title_label ||= Gtk::Label.new(_("Improve Hieroglyphic")).tap do |label|
        label.justify = :center
        label.wrap = true
        label.margin_top = 24
        label.add_css_class("title-1")
      end
    end

    def description_label
      @description_label ||=
        Gtk::Label.new(_("Help make Hieroglyphic better at identifying symbols for everyone")).tap do |label|
          label.justify = :center
          label.wrap = true
          label.margin_top = 12
        end
    end

    def preferences_group
      @preferences_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.margin_top = 24
      end
    end

    def switch_row
      @switch_row ||= Adwaita::SwitchRow.new.tap do |row|
        row.title = _("Contribute Symbols")
        row.subtitle = _("Submit recognized drawings to Hieroglyphic’s dataset")
      end
    end

    def privacy_label
      @privacy_label ||= Gtk::Label.new.tap do |label|
        label.use_markup = true
        label.label = _(
          "No personal identifiable information is collected. " \
          "<a href=\"https://github.com/FineFindus/Hieroglyphic/blob/main/PRIVACY_POLICY.md\">Privacy policy</a>",
        )
        label.margin_top = 12
        label.add_css_class("dim-label")
        label.add_css_class("caption")
      end
    end
  end
end
