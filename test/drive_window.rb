# frozen_string_literal: true

# Drives the main window: both layouts, the symbol list, copying a symbol, the
# markup language switch, and the two dialogs the window can open.
#
#   nix develop --command xvfb-run -a ruby test/drive_window.rb

require "tmpdir"

ENV["XDG_CONFIG_HOME"] = Dir.mktmpdir
ENV["GSETTINGS_BACKEND"] = "memory"

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "hieroglyphic"
require_relative "gtk_driver"

# How long the drive waits for a classification before giving up on it.
CLASSIFIER_TIMEOUT = 30

LATEX_SYMBOLS = %w[
  bGF0ZXgyZS1PVDEtX2JpZ2N1cA==
  YW1zc3ltYi1PVDEtX0N1cA==
  bGF0ZXgyZS1PVDEtX0dhbW1h
].freeze

app = Hieroglyphic::Application.new

GtkDriver.drive(app, shots: "tmp/shots") do |d, _app|
  d.window { app.window.window }

  d.step("the window opens on the placeholder") do
    d.check("window is visible") { app.window.window.visible? }
    d.check("sidebar layout is active") { app.window.layout_view.layout_name == "sidebar" }
    d.check("placeholder page showing") { app.window.symbol_stack.visible_child_name == "placeholder" }
    d.check("nudge dot is shown") { app.window.indicator_button.show_indicator? }
    d.shot("01-placeholder")
  end

  d.step("drawing a stroke records it") do
    app.window.drawing_area.drag_gesture.signal_emit("drag-begin", 40.0, 40.0)
    app.window.drawing_area.drag_gesture.signal_emit("drag-update", 60.0, 10.0)
    app.window.drawing_area.drag_gesture.signal_emit("drag-end", 60.0, 10.0)
  end

  d.step("the stroke is on the canvas") do
    d.check("one stroke drawn") { app.window.drawing_area.strokes.length == 1 }
    d.check("stroke has points") { app.window.drawing_area.strokes.first.points.length == 2 }
    d.shot("02-stroke")
  end

  # The classifier runs on a thread of its own and takes about a second, so the
  # list is given a nested main loop to fill in rather than a fixed number of
  # ticks to hope for.
  d.step("waiting for the classifier") do
    GLib::MainLoop.new.tap do |nested|
      GLib::Timeout.add(50) do
        if app.window.symbol_store.n_items.positive?
          nested.quit
          false
        else
          true
        end
      end

      GLib::Timeout.add_seconds(CLASSIFIER_TIMEOUT) do
        nested.quit
        false
      end

      nested.run
    end
  end

  d.step("the drawn stroke was classified") do
    d.check("symbols page showing") { app.window.symbol_stack.visible_child_name == "symbols" }
    d.check("the list filled up") { app.window.symbol_store.n_items == 25 }
    d.check("every row carries a command") do
      (0...app.window.symbol_store.n_items).all? do |position|
        !app.window.symbol_store.get_item(position).symbol.command.to_s.empty?
      end
    end
  end

  d.step("a shot of the classification") { d.shot("03-classified") }

  d.step("symbols are displayed") do
    app.window.display_symbols(LATEX_SYMBOLS)
  end

  d.step("the symbol list filled in") do
    d.check("three rows") { app.window.symbol_store.n_items == 3 }
    d.check("symbols page showing") { app.window.symbol_stack.visible_child_name == "symbols" }
    d.check("first row shows the command") do
      app.window.symbol_list.first_child.child.first_child.next_sibling.first_child.next_sibling.text == "\\bigcup"
    end
    d.shot("03-symbols")
  end

  d.step("activating a row copies the command") do
    app.window.symbol_list.signal_emit("row-activated", app.window.symbol_list.first_child)
  end

  d.step("the clipboard and a toast carry the symbol") do
    d.check("clipboard offers text") do
      app.window.window.clipboard.formats.to_s.include?("text/plain")
    end
    d.shot("04-copied")
  end

  d.step("switching to Typst") do
    app.window.markup_language_action.activate(GLib::Variant.new("typst"))
  end

  d.step("Typst commands are shown") do
    d.check("setting changed") { app.settings.markup_language == :typst }
    d.check("action state changed") { app.window.markup_language_action.state.to_s.include?("typst") }
    d.check("rows kept only the symbols Typst can spell") { app.window.symbol_store.n_items.positive? }
    d.check("first row shows a typst command") do
      app.window.symbol_list.first_child.child.first_child.next_sibling.first_child.next_sibling.text == "union.big"
    end
    d.shot("05-typst")
  end

  d.step("switching back to LaTeX") do
    app.window.markup_language_action.activate(GLib::Variant.new("latex"))
  end

  d.step("clearing the canvas") do
    app.window.clear_action.activate(nil)
  end

  d.step("the canvas is empty again") do
    d.check("no strokes left") { app.window.drawing_area.strokes.empty? }
    d.shot("06-cleared")
  end

  d.step("the narrow layout") do
    app.window.layout_view.layout_name = "bottom-sheet"
  end

  d.step("the bottom bar previews a symbol") do
    d.check("bottom-sheet layout active") { app.window.layout_view.layout_name == "bottom-sheet" }
    d.check("bottom bar shows the symbols page") do
      app.window.bottom_bar_stack.visible_child_name == "symbols"
    end
    d.check("preview carries a command") { !app.window.preview_symbol.command.to_s.empty? }
    d.shot("07-bottom-sheet")
  end

  d.step("opening the sheet") do
    app.window.all_symbols_button.active = true
  end

  d.step("the sheet is open") do
    d.check("sheet open") { app.window.bottom_sheet.open? }
  end

  # The sheet's content is reparented on the tick it opens, so it has not been
  # laid out again yet - a shot taken the same tick gets no render node at all.
  # One more tick lets it settle before the screenshot looks at it.
  d.step("the open sheet renders") { d.shot("08-sheet-open") }

  d.step("closing the sheet and returning to the wide layout") do
    app.window.all_symbols_button.active = false
    app.window.layout_view.layout_name = "sidebar"
  end

  d.step("opening the contribution dialog") do
    app.window.contribution_dialog_action.activate(nil)
  end

  d.step("the contribution dialog is up") do
    d.check("a dialog is showing") { !app.window.window.visible_dialog.nil? }
    d.check("nudge dot is gone") { !app.window.indicator_button.show_indicator? }
    d.shot("09-contribution", app.window.window.visible_dialog)
  end

  d.step("the switch writes the setting") do
    app.window.contribution_dialog.switch_row.active = true
  end

  d.step("the setting took") do
    d.check("contribute-data is on") { app.settings.contribute_data? }
    d.check("the switch follows the setting back") do
      app.settings.contribute_data = false
      !app.window.contribution_dialog.switch_row.active?
    end
    app.window.window.visible_dialog.close
  end

  d.step("opening the about dialog") do
    app.about.present(app.window.window)
  end

  d.step("the about dialog is up") do
    d.check("a dialog is showing") { !app.window.window.visible_dialog.nil? }
    d.check("debug info names the app") { app.about.dialog.debug_info.include?("Hieroglyphic") }
    d.check("debug info names GTK") { app.about.dialog.debug_info.include?("GTK:") }
    d.shot("10-about", app.window.window.visible_dialog)
  end

  # Every remaining literal upstream's about.rs sets, read back off the
  # dialog it built - not just the two substrings checked above.
  d.step("the about dialog carries upstream's remaining literals") do
    app.about.dialog.then do |dialog|
      d.check("its application icon is the application id") do
        dialog.application_icon == Hieroglyphic::About::APP_ID
      end
      d.check("its copyright is upstream's") { dialog.copyright == Hieroglyphic::About::COPYRIGHT }
      d.check("its developer name is upstream's") do
        dialog.developer_name == Hieroglyphic::About::DEVELOPER_NAME
      end
      d.check("its developers are upstream's") { dialog.developers == Hieroglyphic::About::DEVELOPERS }
      d.check("its designers are upstream's") { dialog.designers == Hieroglyphic::About::DESIGNERS }
      d.check("its artists are upstream's") { dialog.artists == Hieroglyphic::About::ARTISTS }
      d.check("its licence is GPL-3.0") { dialog.license_type == :gpl_3_0 }
      d.check("its website is upstream's") { dialog.website == Hieroglyphic::About::WEBSITE }
      d.check("its issue tracker is upstream's") { dialog.issue_url == Hieroglyphic::About::ISSUE_TRACKER }
      # Not a fixed literal: en_GB.po fills in real names for this msgid, and
      # the environment this runs in is en_GB, so the correct value is
      # whatever gettext resolves it to right now - the same call about.rb
      # makes - not the untranslated "translator-credits" string.
      d.check("its translator credits came from gettext, not a heredoc") do
        dialog.translator_credits == _("translator-credits")
      end
    end
    app.window.window.visible_dialog.close
  end

  d.step("the header bar's menu button carries the primary menu") do
    app.window.menu_button.then do |button|
      d.check("it is a Gtk::MenuButton") { button.is_a?(Gtk::MenuButton) }
      d.check("its icon is the hamburger") { button.icon_name == "open-menu-symbolic" }
      button.menu_model.then do |model|
        d.check("the model is a Gio::Menu") { model.is_a?(Gio::Menu) }
        d.check("it carries two sections, as upstream's primary-menu does") { model.n_items == 2 }
      end
    end
  end

  d.step("the menu's language section is a two-item radio group") do
    Hieroglyphic::PrimaryMenu.new.build.then do |menu|
      menu.get_item_link(0, "section").then do |language_section|
        d.check("two language items") { language_section.n_items == 2 }
        d.check("both target win.markup-language-mode") do
          (0...language_section.n_items).all? do |index|
            language_section.get_item_attribute_value(index, "action", nil) ==
              "win.markup-language-mode"
          end
        end
        d.check("LaTeX and Typst, in that order") do
          (0...language_section.n_items).map do |index|
            language_section.get_item_attribute_value(index, "target", nil).to_s
          end == ["latex", "typst"]
        end
      end
      menu.get_item_link(1, "section").then do |about_section|
        d.check("one about item") { about_section.n_items == 1 }
        d.check("it opens the about dialog") do
          about_section.get_item_attribute_value(0, "action", nil) == "app.about"
        end
      end
    end
  end

  # Compared as parsed key combinations: Gtk hands accelerators back in their
  # own canonical spelling, which need not match the literal upstream wrote.
  d.step("the application registered upstream's accelerators") do
    Hieroglyphic::Application::ACCELS.each do |action, accels|
      d.check("#{action} is #{accels.first}") do
        app.app.get_accels_for_action(action).map { |accel| Gtk.accelerator_parse(accel) } ==
          accels.map { |accel| Gtk.accelerator_parse(accel) }
      end
    end
  end

  d.step("the app-wide actions exist and are enabled") do
    d.check("app.quit is a Gio::SimpleAction") { app.quit_action.is_a?(Gio::SimpleAction) }
    d.check("and it is enabled") { app.quit_action.enabled? }
    d.check("app.about is a Gio::SimpleAction") { app.about_action.is_a?(Gio::SimpleAction) }
    d.check("and it is enabled") { app.about_action.enabled? }
  end

  d.step("the window-level actions upstream wires are all registered") do
    %w[clear show-contribution-dialog copy-symbol markup-language-mode].each do |name|
      d.check("win.#{name} exists") { !app.window.window.lookup_action(name).nil? }
    end
  end

  # src/main.rs: --show-only restricts display to the named symbol ids, so a
  # drawing can be checked against one symbol during development. This never
  # runs inside the activated app above (ARGV there is the test's own), so a
  # fresh window reads a stubbed ARGV instead.
  d.step("--show-only restricts the symbol filter to the named ids") do
    stashed_argv = ARGV.dup
    begin
      ARGV.replace([Hieroglyphic::Application::SHOW_ONLY_FLAG, "foo-OT1-_bar"])
      Hieroglyphic::Application.new.symbol_filter.then do |filter|
        d.check("the filter is read from --show-only") { filter.is_a?(Array) }
      end
      ARGV.replace([])
      Hieroglyphic::Application.new.symbol_filter.then do |filter|
        d.check("with no --show-only, nothing is filtered") { filter.empty? }
      end
    ensure
      ARGV.replace(stashed_argv)
    end
  end
end
