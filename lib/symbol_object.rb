# frozen_string_literal: true

require "adwaita"
require_relative "symbol"

module Hieroglyphic
  # SymbolObject is a GObject wrapper around a Symbol, so symbols can live in
  # the Gio::ListStore the symbol ListBox is bound to — a list model holds
  # GObjects, not plain Ruby values.
  #
  # Ported from upstream's src/widgets/symbol_object.rs.
  class SymbolObject < GLib::Object
    type_register

    # The Symbol the object is wrapping.
    attr_reader :symbol

    def initialize(symbol)
      super()
      @symbol = symbol
    end
  end
end
