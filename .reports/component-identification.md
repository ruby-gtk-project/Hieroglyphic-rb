# Component identification — Hieroglyphic

| | |
|---|---|
| Upstream | `main` @ `246926e` |
| Port | `ruby` @ `d5d7c8c` |

This report does not re-derive the full per-widget inventory from scratch —
`.reports/component-inventory.md` already carries that (one `## <file>`
section per upstream component, with widget type, count, CSS and signal
columns, written by an earlier pass of this skill). What follows is this
pass's verification of that inventory against the actual trees, plus the
units it does not cover.

## Re-verified against current HEAD

Two commits landed since this report's original pass: `b379a3e` (rewrote
`.reports/component-inventory.md` only) and `4dc877f` (added
`devel_profile?`/`DEVEL_PROFILE` to `lib/window.rb`, porting upstream's
`config::PROFILE == "Devel"` CSS-class and nudge-preenable behaviour). The
latter is a genuinely new unit of behaviour and is scored in
`.reports/component-parity.md`'s window/drawing/dialogs table — it is
**not** full parity: the commit ports the CSS class and nudge pre-enable but
misses the other half of upstream's same `Devel` check, which also
suppresses uploads. See that report for the gap in full; it is the
headline new finding of this pass.

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

## Re-verified against current HEAD (`d5d7c8c`, five commits past `4dc877f`)

Previously-open findings re-checked, not assumed:

- **Devel-profile upload suppression (`component-parity.md`'s "new gap found
  this pass" for `4dc877f`) is closed.** `dc72d34` ("Skip strokes upload in
  devel profile") added `!devel_profile?` to `lib/window.rb`'s
  `upload_allowed?`, matching upstream's second `config::PROFILE == "Devel"`
  check in `try_upload_data`. Confirmed by reading both sides; the gate now
  has all three of upstream's conditions plus the devel check.
- **The 13-unported-test / empty-`spec/` finding is closed.** `d5a9dfb` added
  `spec/{point,rect,stroke,symbol}_spec.rb`; re-run this pass (19 examples, 0
  failures — see `.reports/test-parity.md` for the row-by-row mapping).
- **Privacy-policy label gap is closed.** `5a2094a` wrapped it in `_()`. See
  `.reports/translation-parity.md`.

### New findings this pass, not previously identified

- **`About`'s debug-info blob drops upstream's `Profile:` line.** Upstream
  `src/widgets/about.rs:43`: `information.push_str(&format!("Profile: {}\n",
  config::PROFILE));`, immediately after the app-id/version line. Port
  `lib/about.rb#debug_info` has no `Profile:` entry anywhere in its array —
  checked by reading the method's literal list, not by inference. This is a
  real line of the "attach this when filing a bug" blob that the port
  silently drops; a bug reporter's debug info never says whether they are
  running a Devel or stable build.
- **`About`'s debug-info filename differs from upstream's.** Upstream:
  `.debug_info_filename("tex_match_debug")` (`src/widgets/about.rs:33`).
  Port: `about.debug_info_filename = "hieroglyphic_debug"`
  (`lib/about.rb:62`). Cosmetic — it only changes what the saved attachment
  is called — but it is a literal upstream names explicitly and the port
  changed without comment, so it is recorded rather than assumed harmless.
- **`accessible-role="GTK_ACCESSIBLE_ROLE_PRESENTATION"` is dropped on two
  decorative images.** Upstream sets it on the `GtkPicture` in
  `data/resources/ui/contribution-dialog.ui` and the `GtkImage` in
  `data/resources/ui/symbol-item.ui` — both purely decorative, and the
  attribute is what keeps a screen reader from announcing them. Port
  `lib/contribution_dialog.rb#illustration` and `lib/symbol_item.rb#image`
  build the same widgets with no accessible-role set at all. Small,
  consistent across two files, and an accessibility regression a visual
  screenshot comparison would never catch (confirmed: `test/drive_window.rb`
  never asserts on either widget's accessible role).
- **`Application#build`'s `activate` handler always rebuilds the window.**
  Upstream's `activate()` (`src/application.rs`) checks `self.window.get()`
  first and, when a window already exists, only presents it — it never
  re-runs the window's construction on a second activation (e.g. a second
  launch of a single-instance app, which GTK delivers as another `activate`
  signal to the same primary process rather than a new process). Port
  `lib/hieroglyphic/application.rb#build`'s `app.signal_connect("activate")`
  block calls `win.build` unconditionally every time, with no guard. `window`
  itself is memoized, so this re-runs `build` — which calls `win.add_action`
  four times and `win.add_breakpoint` once — on the *same* already-built
  window object. Not exercised by `test/drive_window.rb` (which activates the
  app once per process) and not caught by any report before this pass;
  flagged in `.reports/component-parity.md` as an open component gap.
