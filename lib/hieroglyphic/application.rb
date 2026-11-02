# frozen_string_literal: true

require "gtk4"
require "adwaita"
require_relative "../about"
require_relative "../settings"
require_relative "../symbol"
require_relative "../window"

module Hieroglyphic
  # Application is the app itself: one window, the app-wide actions and
  # accelerators, the stylesheet and the icon theme the symbol previews live in.
  #
  # Ported from upstream's src/application.rs. Upstream reads its stylesheet and
  # its icons out of a GResource bundle built by meson; the port ships them as
  # files and points GTK at them, which is the same two lines of setup without a
  # build step. `--show-only` keeps upstream's meaning: restrict the displayed
  # symbols to the given ids.
  #
  # House style (see .claude/skills/ruby-gtk): every widget is a memoized
  # method, all configuration lives in its `tap`, assembly happens only in
  # `build`, and the launcher is one expression.
  class Application
    APP_ID = "org.rubygtkproject.Hieroglyphic"
    STYLESHEET = File.expand_path("../style.css", __dir__)
    ICON_DIR = File.expand_path("../../data/icons", __dir__)
    SHOW_ONLY_FLAG = "--show-only"
    ACCELS = {
      "app.quit"     => ["<Control>q"],
      "window.close" => ["<Control>w"],
      "win.clear"    => ["<Control>n", "Delete"],
    }.freeze

    def build
      app.tap do
        app.signal_connect("startup") do
          Gtk::Window.set_default_icon_name(APP_ID)
          setup_icons
          setup_css

          app.add_action(quit_action)
          app.add_action(about_action)
          ACCELS.each { |action, accels| app.set_accels_for_action(action, accels) }

          quit_action.signal_connect("activate") do
            window.window.close
            app.quit
          end

          about_action.signal_connect("activate") { about.present(window.window) }
        end

        app.signal_connect("activate") do
          window.tap do |win|
            win.build
            win.symbol_filter = symbol_filter
            win.present
          end
        end
      end
    end

    # Adwaita::Application is broken in the Ruby bindings; the application
    # object comes from Gtk and only the window is Adwaita.
    def app = @app ||= Gtk::Application.new(APP_ID, :default_flags)

    def window = @window ||= Window.new(app, settings: settings)
    def settings = @settings ||= Settings.new
    def about = @about ||= About.new

    def quit_action = @quit_action ||= Gio::SimpleAction.new("quit")
    def about_action = @about_action ||= Gio::SimpleAction.new("about")

    # The symbols `--show-only` restricts the display to, by id.
    def symbol_filter
      @symbol_filter ||= show_only_arguments.filter_map { |id| Symbol.from_id(id)&.id }
    end

    private

      def show_only_arguments
        if ARGV.first == SHOW_ONLY_FLAG
          ARGV.drop(1)
        else
          []
        end
      end

      # The symbol previews and the app's own action icons are an icon theme of
      # their own, which GTK finds once its directory is on the search path.
      def setup_icons
        Gtk::IconTheme.get_for_display(Gdk::Display.default).add_search_path(ICON_DIR)
      end

      def setup_css
        Gtk::StyleContext.add_provider_for_display(
          Gdk::Display.default,
          css_provider,
          Gtk::StyleProvider::PRIORITY_APPLICATION,
        )
      end

      def css_provider
        @css_provider ||= Gtk::CssProvider.new.tap do |provider|
          provider.load_from_path(STYLESHEET)
        end
      end
  end
end
