# frozen_string_literal: true

require "adwaita"
require_relative "settings"

module Hieroglyphic
  # PrimaryMenu is the header bar's menu: the markup language the symbols are
  # suggested for, and the about dialog.
  #
  # Ported from the `primary-menu` menu model in upstream's
  # data/resources/ui/window.ui. The language items share the stateful
  # win.markup-language-mode action, which is what makes them a radio group.
  class PrimaryMenu
    LANGUAGE_LABELS = {
      MarkupLanguage::LATEX => N_("LaTeX"),
      MarkupLanguage::TYPST => N_("Typst"),
    }.freeze

    def build
      menu.tap do |m|
        m.append_section(_("Markup language"), language_section)
        m.append_section(nil, about_section)

        language_section.tap do |section|
          LANGUAGE_LABELS.each do |language, label|
            section.append(_(label), "win.markup-language-mode('#{language}')")
          end
        end

        about_section.tap do |section|
          section.append(_("About Hieroglyphic"), "app.about")
        end
      end
    end

    def menu = @menu ||= Gio::Menu.new
    def language_section = @language_section ||= Gio::Menu.new
    def about_section = @about_section ||= Gio::Menu.new
  end
end
