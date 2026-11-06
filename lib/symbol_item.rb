# frozen_string_literal: true

require "adwaita"
require_relative "symbol"

module Hieroglyphic
  # SymbolItem is one symbol as the UI shows it: its rendered preview, the
  # package providing it, the command to type, the modes it works in, and a
  # button that copies the command. It is used both as a row of the symbol list
  # and as the preview in the bottom bar.
  #
  # Ported from upstream's src/widgets/symbol_item.rs and
  # data/resources/ui/symbol-item.ui. Upstream is a GtkBox subclass whose five
  # construct-only properties the template binds to; the port keeps the symbol
  # itself and pushes it into the widgets, which is what those bindings did.
  class SymbolItem
    def initialize(symbol, language)
      @symbol = symbol
      @language = language
    end

    def build
      box.tap do |b|
        b.append(image)
        b.append(inscriptions)
        b.append(copy_button)

        inscriptions.tap do |column|
          column.append(package_inscription)
          column.append(command_inscription)
          column.append(mode_inscription)
        end

        copy_button.tap do |button|
          button.signal_connect("clicked") { on_copy }
        end

        display(@symbol, @language)
      end
    end

    # Sets the displayed symbol to the given symbol.
    def set_symbol(symbol, language)
      @symbol = symbol
      @language = language
      display(symbol, language)
    end

    # The id of the displayed symbol, as the classifier labels it.
    def id = @symbol.id

    # The command of the displayed symbol, in the displayed language.
    def command = @symbol.command_for(@language)

    # Copies the symbol, by way of the window's action: the row's copy button
    # and the row itself both end up in the same place.
    def on_copy
      box.activate_action("win.copy-symbol", GLib::Variant.new(id))
    end

    def box
      @box ||= Gtk::Box.new(:horizontal, 0).tap do |b|
        b.margin_top = 6
        b.margin_bottom = 6
      end
    end

    def image
      @image ||= Gtk::Image.new.tap do |i|
        i.icon_size = :large
        i.margin_end = 4
      end
    end

    def inscriptions
      @inscriptions ||= Gtk::Box.new(:vertical, 0).tap do |b|
        b.hexpand = true
      end
    end

    def package_inscription = @package_inscription ||= Gtk::Inscription.new

    def command_inscription
      @command_inscription ||= Gtk::Inscription.new.tap do |inscription|
        inscription.add_css_class("title-3")
      end
    end

    def mode_inscription
      @mode_inscription ||= Gtk::Inscription.new.tap do |inscription|
        inscription.add_css_class("caption")
      end
    end

    def copy_button
      @copy_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = "copy-symbolic"
        button.tooltip_text = _("Copy")
        button.valign = :center
        button.add_css_class("flat")
      end
    end

    private

      def display(symbol, language)
        image.icon_name = icon_name(symbol)
        package_inscription.text = symbol.package_for(language)
        command_inscription.text = symbol.command_for(language)
        mode_inscription.text = symbol.mode_description(language)
      end

      # The symbol's preview icon. Icon filenames do not carry the padding of
      # the base64 id.
      def icon_name(symbol) = "#{symbol.id.sub(/=+\z/, "")}-symbolic"
  end
end
