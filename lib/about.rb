# frozen_string_literal: true

require "adwaita"
require_relative "hieroglyphic/rb/version"

module Hieroglyphic
  # About is the about dialog, including the debug-information blob the user can
  # attach to a bug report.
  #
  # Ported from upstream's src/widgets/about.rs. The credits are upstream's,
  # since they are the credits of the app being ported. The debug blob reports
  # the same facts, read where the Ruby bindings expose them: the OS name and
  # version come from /etc/os-release, as glib's os_info has no Ruby binding,
  # and the display backend from the Gdk display's type.
  class About
    APP_ID = "org.rubygtkproject.Hieroglyphic"
    COPYRIGHT = "Copyright © 2024 FineFindus"
    WEBSITE = "https://github.com/FineFindus/Hieroglyphic/"
    ISSUE_TRACKER = "https://github.com/FineFindus/Hieroglyphic/issues/"
    DEVELOPER_NAME = "FineFindus"
    DEVELOPERS = ["Zoey Sheffield", "FineFindus https://github.com/FineFindus"].freeze
    DESIGNERS = ["Tobias Bernard", "Brage Fuglseth"].freeze
    ARTISTS = ["Tobias Bernard"].freeze
    OS_RELEASE = "/etc/os-release"
    FLATPAK_INFO = "/.flatpak-info"
    # The /.flatpak-info keys upstream reports, and the labels it reports them
    # under.
    FLATPAK_KEYS = {
      "name"            => "Name",
      "runtime"         => "Runtime",
      "runtime-commit"  => "Runtime commit",
      "arch"            => "Arch",
      "flatpak-version" => "Flatpak Version",
      "devel"           => "Devel",
    }.freeze

    # Builds the dialog and presents it over the given parent window.
    def present(parent)
      build.present(parent)
    end

    def build = dialog

    def dialog
      @dialog ||= Adwaita::AboutDialog.new.tap do |about|
        about.application_icon = APP_ID
        about.application_name = _("Hieroglyphic")
        about.developer_name = DEVELOPER_NAME
        about.developers = DEVELOPERS
        about.designers = DESIGNERS
        about.artists = ARTISTS
        # Translators: This should not be translate, Please enter your credits
        # here instead (format: "Name https://example.com" or
        # "Name <email@example.com>", no quotes)
        about.translator_credits = _("translator-credits")
        about.license_type = Gtk::License::GPL_3_0
        about.version = Rb::Version::VERSION
        about.website = WEBSITE
        about.issue_url = ISSUE_TRACKER
        about.copyright = COPYRIGHT
        about.debug_info = debug_info
        about.debug_info_filename = "hieroglyphic_debug"
      end
    end

    private

      # Useful information for debugging the application.
      def debug_info
        [
          "#{APP_ID}: #{Rb::Version::VERSION}",
          "Backend: #{backend}",
          "OS:",
          " - Name: #{os_release.fetch("NAME", "Failed to get OS NAME").inspect}",
          " - Version: #{os_release.fetch("VERSION", "Failed to get VERSION").inspect}",
          "Libraries:",
          " - GTK: #{Gtk::Version::STRING}",
          " - Libadwaita: #{Adwaita::VERSION_S}",
          " - Ruby: #{RUBY_VERSION}",
          "",
          "Sandbox:",
          sandbox_info,
          "",
        ].join("\n")
      end

      # The display server in use, read off the Gdk display's type: the Ruby
      # bindings have no Gdk::Display#backend, but each backend has its own
      # display class.
      def backend
        Gdk::Display.default.then do |display|
          if display
            display.class.name.split("::").last.sub(/Display\z/, "")
          else
            "Failed to get backend"
          end
        end
      end

      def os_release
        @os_release ||= read_os_release
      end

      def read_os_release
        if File.exist?(OS_RELEASE)
          key_value_pairs(OS_RELEASE)
            .to_h { |key, value| [key, value.delete_prefix("\"").delete_suffix("\"")] }
        else
          {}
        end
      end

      # Info about the sandbox the app is running in: the flatpak metadata when
      # there is any, otherwise only whether GTK_USE_PORTAL is set.
      def sandbox_info
        if File.exist?(FLATPAK_INFO)
          flatpak_info
        else
          " - GTK_USE_PORTAL: #{ENV.fetch("GTK_USE_PORTAL", "0") == "1"}"
        end
      end

      def flatpak_info
        key_value_pairs(FLATPAK_INFO)
          .select { |key, _value| FLATPAK_KEYS.key?(key) }
          .map { |key, value| " - #{FLATPAK_KEYS[key]}: #{value}" }
          .unshift("Flatpak Info:")
          .join("\n")
      end

      # The `key=value` lines of a file, as [key, value] pairs. Lines without a
      # `=` are dropped.
      def key_value_pairs(path)
        File.readlines(path, chomp: true)
          .map { |line| line.split("=", 2) }
          .select { |parts| parts.size == 2 }
      end
  end
end
