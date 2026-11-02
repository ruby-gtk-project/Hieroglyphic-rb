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
    d.shot("08-sheet-open")
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
    app.window.window.visible_dialog.close
  end
end
