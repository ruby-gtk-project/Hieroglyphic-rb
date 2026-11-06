# frozen_string_literal: true

require "gettext"
require "gettext/po_parser"
require "gettext/mo"
require "fileutils"
require "tmpdir"

module Hieroglyphic
  # I18n wires up the "hieroglyphic" gettext text domain, making `_()`
  # available everywhere (upstream's `gettext-rs` equivalent).
  #
  # Upstream's meson build compiles po/*.po into *.mo files at build time via
  # `i18n.gettext`. The port has no build step, so `setup!` compiles each
  # catalogue named in po/LINGUAS into a tmp cache lazily, the first time the
  # app runs (and again whenever a .po file is newer than its cached .mo), and
  # then binds that cache directory as the domain's search path.
  class I18n
    TEXTDOMAIN = "hieroglyphic"
    PO_DIR = File.expand_path("../../po", __dir__)
    LINGUAS_FILE = File.join(PO_DIR, "LINGUAS")

    class << self
      # Compiles every catalogue in po/LINGUAS and binds the domain. Call this
      # once, before any translatable string is looked up.
      def setup!
        languages.each { |language| compile(language) }
        GetText.bindtextdomain_to(Object, TEXTDOMAIN, path: locale_dir)
      end

      def languages
        File.readlines(LINGUAS_FILE).map(&:strip).reject(&:empty?)
      end

      def locale_dir
        @locale_dir ||= File.join(Dir.tmpdir, "hieroglyphic-locale")
      end

      private

        def compile(language)
          po_path = File.join(PO_DIR, "#{language}.po")
          mo_path = File.join(
            locale_dir,
            language,
            "LC_MESSAGES",
            "#{TEXTDOMAIN}.mo",
          )
          unless File.exist?(mo_path) && File.mtime(mo_path) >= File.mtime(po_path)
            FileUtils.mkdir_p(File.dirname(mo_path))
            po_parser.parse_file(po_path, GetText::MO.new).save_to_file(mo_path)
          end
        end

        # po-file entries with a `#~` (obsolete) comment are warned about by
        # default, which would print on every startup for every obsolete
        # entry in every catalogue; the catalogues carry some on purpose
        # (strings upstream has not ported to the UI yet), so the parser
        # built here is quieted instead of pruning them.
        def po_parser
          @po_parser ||= GetText::POParser.new.tap do |parser|
            parser.report_warning = false
          end
        end
    end
  end
end
