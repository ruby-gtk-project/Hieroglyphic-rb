# frozen_string_literal: true

require "yaml"

module Hieroglyphic
  # Symbol is one entry of the symbol table: a LaTeX command, the package that
  # provides it, the modes it may be used in, and the equivalent Typst command
  # where one is known.
  #
  # Ported from upstream's src/classify/symbol.rs. Upstream's table is generated
  # at compile time by build.rs into a `phf::Map`; here the same YAML sources
  # (data/symbols.yaml, data/typst-aliases.yaml) are read once at load and
  # expanded by the same rules, which keeps the table and the data in one place
  # instead of a checked-in thousand-entry literal.
  #
  # The LaTeX side of the table is complete: the port builds the same 1124
  # symbols, under the same base64 ids, as upstream's generated table. The Typst
  # side is narrower — upstream also folds in the alias tables of the `mitex`
  # and `codex` Rust crates, which are compile-time data of those crates rather
  # than files of this project, so symbols whose only Typst spelling came from
  # there have none here and are skipped in Typst mode exactly as an unmapped
  # symbol is.
  Symbol = Data.define(
    :command,
    :package,
    :font_encoding,
    :text_mode,
    :math_mode,
    :typst_command,
  ) do
    # The id of the symbol: the base64 of "package-fontenc-command", with the
    # backslashes of the command replaced by underscores. It is both the
    # classifier's label and the name of the symbol's preview icon.
    def id = [[package, font_encoding, command.gsub("\\", "_")].join("-")].pack("m0")

    # Command to use the symbol in the given markup language, or nil when the
    # language has no spelling for it.
    def command_for(language)
      if language == :typst
        typst_command
      else
        command
      end
    end

    # Package which provides the symbol in the given markup language. Typst
    # needs no import for its symbols, so it has none.
    def package_for(language)
      if language == :typst
        nil
      else
        package
      end
    end

    # Textual representation of the mode in which the symbol can be used, as
    # shown under the command in the symbol list.
    def mode_description(language)
      if language == :typst
        nil
      else
        latex_mode_description
      end
    end

    private

      def latex_mode_description
        case [math_mode, text_mode]
        in [true, true] then "mathmode & textmode"
        in [false, true] then "textmode"
        in [true, false] then "mathmode"
        else
          # a symbol has to be either math mode or textmode
          raise("Symbol #{id} is neither math nor textmode")
        end
      end
  end

  # Reopened rather than configured in the Data.define block: a constant
  # assigned inside that block binds to the enclosing lexical scope, so
  # Symbol::TABLE would not exist.
  class Symbol
    DATA_DIR = File.expand_path("../data", __dir__)
    SYMBOLS_FILE = File.join(DATA_DIR, "symbols.yaml")
    TYPST_ALIASES_FILE = File.join(DATA_DIR, "typst-aliases.yaml")

    # Defaults for a symbol that is listed without a table of its own.
    DEFAULT_PACKAGE = "latex2e"
    DEFAULT_FONT_ENCODING = "OT1"

    # The modes a symbols.yaml table may group its commands under, and the
    # (math_mode, text_mode) pair each one stands for.
    MODES = {
      "bothmodes" => [true, true],
      "textmode"  => [false, true],
      "mathmode"  => [true, false],
    }.freeze

    # Commands of the form \mathcal{X} have a Typst equivalent of the form
    # math.cal(X), computed rather than looked up.
    MATH_ALPHABET = /\\math(cal|frak|scr|ds)\{(\w)\}/
    # \mathds is Typst's `bb`; the other three keep their LaTeX name.
    MATH_ALPHABET_ALIASES = {"ds" => "bb"}.freeze

    class << self
      # The symbol the `id` specifies, or nil for an unknown id.
      def from_id(id) = table[id]

      # The whole table, keyed by symbol id.
      def table = @table ||= build_table

      # Amount of available symbols.
      def count = table.size

      private

        def build_table
          YAML.load_file(SYMBOLS_FILE).each_with_object({}) do |data, table|
            collect(data, defaults, table)
          end.freeze
        end

        # The LaTeX-to-Typst command map, as upstream's typst-aliases.yaml
        # spells it.
        def typst_aliases = @typst_aliases ||= YAML.load_file(TYPST_ALIASES_FILE)

        def defaults
          {
            package:       DEFAULT_PACKAGE,
            font_encoding: DEFAULT_FONT_ENCODING,
            math_mode:     false,
            text_mode:     true,
          }
        end

        # Walks one symbols.yaml entry, which is either a command or a table
        # grouping commands under the modes they are available in.
        def collect(data, attributes, table)
          case data
          when ::String
            table.store(*symbol_for(data, attributes))
          when ::Hash
            collect_table(data, attributes, table)
          else
            raise("Unexpected symbols.yaml entry: #{data.inspect}")
          end
        end

        def collect_table(data, attributes, table)
          attributes.merge(
            package:       data.fetch("package", attributes[:package]),
            font_encoding: data.fetch("fontenc", attributes[:font_encoding]),
          ).then do |inherited|
            MODES.each do |mode, (math_mode, text_mode)|
              data.fetch(mode, []).each do |entry|
                collect(entry, inherited.merge(math_mode: math_mode, text_mode: text_mode), table)
              end
            end
          end
        end

        # The id/symbol pair a command and its inherited attributes produce.
        def symbol_for(command, attributes)
          Symbol.new(
            command:       command,
            package:       attributes[:package],
            font_encoding: attributes[:font_encoding],
            text_mode:     attributes[:text_mode],
            math_mode:     attributes[:math_mode],
            typst_command: typst_command_for(command),
          ).then { |symbol| [symbol.id, symbol] }
        end

        def typst_command_for(command)
          MATH_ALPHABET.match(command).then do |match|
            if match
              math_alphabet_command(match)
            else
              typst_aliases[command]
            end
          end
        end

        def math_alphabet_command(match)
          MATH_ALPHABET_ALIASES.fetch(match[1], match[1]).then do |mode|
            "math.#{mode}(#{match[2]})"
          end
        end
    end
  end
end
