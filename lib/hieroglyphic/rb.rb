# frozen_string_literal: true

# The part of Hieroglyphic that loads without a display.
#
# This file exists because `require "gtk4"` initialises GTK at require time
# and raises Gtk::InitError when there is no display server, so anything that
# reaches a widget class cannot be loaded by a plain `ruby -e` or by a test
# process on a headless machine. The split is along that line and no other:
#
#   require "hieroglyphic/rb"   the classification model — points, rects,
#                               strokes and the symbol table — no gtk4, no
#                               adwaita, loadable anywhere;
#   require "hieroglyphic"      all of the above plus every widget and the
#                               application, which needs a display.
#
# It is also the file the gem's version constant lives under, which is why
# spec/spec_helper.rb requires it: the specs for the display-free half need
# nothing more, and the ones that drive widgets ask for "hieroglyphic"
# themselves.
require_relative "../point"
require_relative "../rect"
require_relative "../stroke"
require_relative "../symbol"
require_relative "rb/version"
