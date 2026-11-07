# Component identification — Hieroglyphic

| | |
|---|---|
| Upstream | `main` @ `246926e` |
| Port | `ruby` @ `b0a35e3` |

This report does not re-derive the full per-widget inventory from scratch —
`.reports/component-inventory.md` already carries that (one `## <file>`
section per upstream component, with widget type, count, CSS and signal
columns, written by an earlier pass of this skill). What follows is this
pass's verification of that inventory against the actual trees, plus the
units it does not cover.

## Verified against source

- **Symbol table size.** Upstream's `test_iterate_symbols` pins
  `SYMBOL_TABLE.len() == 1124`. Running the port
  (`Hieroglyphic::Symbol.count`) returns **1124**. Confirmed by execution, not
  by reading the YAML.
- **Typst coverage.** Of those 1124, only **421** carry a `typst_command`
  (`Hieroglyphic::Symbol.table.values.count { |s| s.typst_command }`). The
  inventory's blocker #2 ("the Typst half of the symbol table is incomplete")
  is accurate and, if anything, understates it: 63% of the table has no Typst
  spelling at all, not a tail of edge cases.
- **Drawing area line colour.** Upstream `src/widgets/drawing_area.rs:114-118`
  (`#CCCCCC` light-mode, `gdk::RGBA::new(0.37, 0.36, 0.39, 1.0)` dark `@dark_2`)
  matches `lib/drawing_area.rb:23-26` (`LIGHT_LINE_COLOR = [0.37, 0.36,
  0.39]`, comment citing the same `#CCCCCC`). Component 3 in the inventory is
  accurate.
- **IndicatorButton.** `lib/indicator_button.rb` is a `Gtk::Overlay` +
  `Gtk::DrawingArea` standing in for upstream's `GtkButton` subclass with an
  overridden `snapshot`, reproducing the same 8px dot at the same `(14, 15)`
  offset and the same `notify::accent-color-rgba` trigger. The substitution is
  recorded in the file's own class comment, which is the correspondence the
  `component-parity` skill asks for, not a silent swap.
- **Upstream unit-test subjects are untracked as components, correctly.**
  `src/classify/{point,rect,stroke,symbol}.rs` carry 13 `#[test]` functions
  (see `.reports/test-parity.md`) but no widgets — they back model classes
  already listed as components 10/12/13/14 in the inventory. No separate
  component entry is owed for them; their gap is a test-parity gap, not a
  missing widget.

## Units the existing inventory does not score

The inventory enumerates 21 upstream files/surfaces mapped to port files and
marks every one "yes". It is a **presence** map, not a **parity** map — it
says a `lib/*.rb` file exists for every upstream file, not that each one
reproduces the same widget counts, CSS and signals. That comparison is done
in `.reports/component-parity.md`, scoped to the two components with the most
at stake (the window/drawing-area/dialog cluster that the drive script
actually exercises, and the symbol table / Typst path that it does not).

## Correction to the existing inventory

`.reports/component-inventory.md:163-165` still reads, under "Other behaviour
to port": *"the opt-in stroke upload (`POST .../v1/upload/{label}`, skipped
when `contribute-data` is off, …)"* — phrased as outstanding work. It is not:
`lib/window.rb:625-654` (`try_upload_data`, `upload_allowed?`, `upload`) and
`lib/settings.rb:41-44` (`contribute_data?`) implement the full gate (setting,
`Gio::NetworkMonitor#network_metered?`, `Gio::PowerProfileMonitor` when
present). This is the earlier survey going stale, not a hidden gap — if
anything it under-claims — but a reader skimming that line would conclude the
upload is unbuilt when it is built. Flagged here so the next pass fixes the
wording rather than re-investigating the feature.
