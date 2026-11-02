# frozen_string_literal: true

require "adwaita"

module Hieroglyphic
  # MarkupLanguage is the markup language symbols are suggested for.
  #
  # Ported from the MarkupLanguageMode enum in upstream's src/window.rs. The
  # values are the ones the gschema's `markup-language-mode` key allows.
  module MarkupLanguage
    LATEX = :latex
    TYPST = :typst
    ALL = [LATEX, TYPST].freeze
    DEFAULT = LATEX

    # The language the given gschema value names, falling back to the default
    # for a value outside the schema's choices.
    def self.from_value(value)
      ALL.find { |language| language.to_s == value } || DEFAULT
    end
  end

  # Settings wraps the app's GSettings schema.
  #
  # Ported from the SETTINGS thread_local and MarkupLanguageMode::from_settings
  # in upstream's src/window.rs. Upstream reaches a schema that its build
  # installed into the system schema directory; the port ships the schema in
  # data/schemas and compiles it on first use, so running from a checkout needs
  # no install step.
  class Settings
    SCHEMA_ID = "org.rubygtkproject.Hieroglyphic"
    SCHEMA_DIR = File.expand_path("../data/schemas", __dir__)
    COMPILED_SCHEMA = File.join(SCHEMA_DIR, "gschemas.compiled")

    def show_contribution_nudge? = gio.get_boolean("show-contribution-nudge")

    def show_contribution_nudge=(value)
      gio.set_boolean("show-contribution-nudge", value)
    end

    def contribute_data? = gio.get_boolean("contribute-data")

    def contribute_data=(value)
      gio.set_boolean("contribute-data", value)
    end

    # The markup language symbols are suggested for.
    def markup_language = MarkupLanguage.from_value(gio.get_string("markup-language-mode"))

    def markup_language=(language)
      gio.set_string("markup-language-mode", MarkupLanguage.from_value(language.to_s).to_s)
    end

    # Binds a key to a property of a GObject, two-way, as upstream's
    # `settings.bind(...).build()` does.
    def bind(key, object, property, flags = :default)
      gio.bind(
        key,
        object,
        property,
        flags,
      )
    end

    # Runs the block whenever the given key changes.
    def on_change(key, &block) = gio.signal_connect("changed::#{key}") { block.call }

    def gio = @gio ||= Gio::Settings.new(schema: schema)

    private

      def schema
        schema_source.lookup(SCHEMA_ID, true) ||
          raise("GSettings schema #{SCHEMA_ID} not found in #{SCHEMA_DIR}")
      end

      # The port's own schema directory, chained to the system source so the
      # lookup still finds an installed copy of the schema.
      def schema_source
        compile_schema
        Gio::SettingsSchemaSource.new(
          SCHEMA_DIR,
          Gio::SettingsSchemaSource.default,
          true,
        )
      end

      # glib-compile-schemas turns the shipped XML into the binary GSettings
      # reads. It is cheap and idempotent, so it runs whenever the binary is
      # missing or older than the XML it was built from.
      def compile_schema
        Dir.glob(File.join(SCHEMA_DIR, "*.gschema.xml")).then do |sources|
          if sources.any? { |source| stale?(source) }
            system("glib-compile-schemas", SCHEMA_DIR, out: File::NULL)
          end
        end
      end

      def stale?(source)
        !File.exist?(COMPILED_SCHEMA) || File.mtime(source) > File.mtime(COMPILED_SCHEMA)
      end
  end
end
