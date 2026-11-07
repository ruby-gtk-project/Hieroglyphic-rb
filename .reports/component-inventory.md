# Hieroglyphic component inventory

Upstream is read from `origin/main` (Rust/gtk-rs + blueprint/GtkBuilder `.ui`
files, GSettings schema, GResource bundle, `po/` catalogue). The port is the
`lib/` tree on `ruby`. This is a survey only — no app code was written for
this pass.

Order follows how a user meets the app: application, window, then the
window's children (drawing area, symbol row, indicator button, primary menu,
contribution dialog), then the supporting data-model classes.

## Summary

The `ruby` branch already has a `lib/*.rb` file for every upstream
component. This inventory did not find a missing user-facing component,
dialog, action, accelerator, settings key, or menu item. Each row below
confirms the upstream file(s), the port file, its kind, and existence.

| Upstream file(s) | Port file | Kind | Exists? |
|---|---|---|---|
| `src/application.rs` | `lib/hieroglyphic/application.rb` | app class (actions, accels, CSS, icon theme setup) | Yes |
| `src/window.rs` + `data/resources/ui/window.ui` | `lib/window.rb` | window (main widget tree, actions, settings wiring) | Yes |
| `src/widgets/drawing_area.rs` + `data/resources/ui/drawing-area.ui` | `lib/drawing_area.rb` | widget (canvas + gesture) | Yes |
| `src/widgets/symbol_item.rs` + `data/resources/ui/symbol-item.ui` | `lib/symbol_item.rb` | widget (list row / preview) | Yes |
| `src/widgets/symbol_object.rs` | `lib/symbol_object.rb` | GObject wrapper for list model | Yes |
| `src/widgets/indicator_button.rs` | `lib/indicator_button.rb` | widget (header-bar button + nudge dot) | Yes |
| `src/widgets/about.rs` | `lib/about.rb` | dialog (About) | Yes |
| `data/resources/ui/contribution-dialog.ui` (built in `src/window.rs`'s `win.show-contribution-dialog` action) | `lib/contribution_dialog.rb` | dialog (preferences / data-contribution) | Yes |
| `primary-menu` menu model in `data/resources/ui/window.ui` | `lib/primary_menu.rb` | menu model | Yes |
| `data/io.github.finefindus.Hieroglyphic.gschema.xml.in` | `lib/settings.rb` (+ `data/schemas/org.rubygtkproject.Hieroglyphic.gschema.xml`) | GSettings schema + wrapper | Yes |
| `src/classify/classifier.rs` (model load/inference via the `ort` crate) | `lib/classifier.rb` + `lib/onnx.rb` | classifier / ONNX runtime | Yes (`lib/onnx.rb` is a from-scratch ONNX forward-pass engine, since Ruby has no `ort` binding; documented in its header comment) |
| `src/classify/symbol.rs` | `lib/symbol.rb` | symbol table / data model | Yes |
| `src/classify/point.rs` | `lib/point.rb` | data model | Yes |
| `src/classify/rect.rs` | `lib/rect.rb` | data model | Yes |
| `src/classify/stroke.rs` | `lib/stroke.rb` | data model | Yes |
| `src/classify/mod.rs` | (module re-exports only; no port file needed) | module glue | N/A — nothing to port |
| `src/main.rs` | `lib/hieroglyphic.rb` + `exe/` launcher | entry point | Yes |
| `src/config.rs.in` | version/app-id constants inlined in `lib/about.rb`, `lib/hieroglyphic/application.rb`, `lib/hieroglyphic/rb/version.rb` | build-time config | Yes |
| `data/io.github.finefindus.Hieroglyphic.desktop.in.in` | `data/org.rubygtkproject.Hieroglyphic.desktop.in` | desktop entry | Yes |
| `data/io.github.finefindus.Hieroglyphic.metainfo.xml.in.in` | `data/org.rubygtkproject.Hieroglyphic.metainfo.xml.in` | AppStream metainfo | Yes |
| `data/io.github.finefindus.Hieroglyphic.service.in` | (D-Bus service activation file; no runtime behaviour to port — not a user-facing component) | service activation | N/A |
| `data/model.onnx` | `data/model.onnx` | ML model asset | Yes |
| `data/resources/illustrations/pen-broadcast.svg` | `data/illustrations/pen-broadcast.svg` | asset (contribution dialog illustration) | Yes |
| `data/icons/*` | `data/icons/*` | app icon | Yes |
| `data/resources/icons/*-symbolic.svg` (per-symbol glyph icons) | `data/icons/hicolor/...` | per-symbol icon theme | Yes (spot-checked; see note below) |
| `symbols.yaml`, `typst-aliases.yaml`, `unicode_to_latex.yaml` | `data/symbols.yaml`, `data/typst-aliases.yaml`, `data/labels.txt` | symbol/label data tables consumed by `Symbol`/`Classifier` | Yes |
| `po/*.po`, `po/LINGUAS`, `po/POTFILES.in` | `po/*.po`, `po/LINGUAS`, `po/POTFILES.in`, `po/hieroglyphic.pot` | translation catalogue | Present (full translation-string parity is out of scope for this pass — see `translation-parity` skill) |

## Widget-tree detail by file

### `lib/hieroglyphic/application.rb` — the application
Ported from `src/application.rs`.

| Facet | Upstream | Port |
|---|---|---|
| Actions | `app.quit`, `app.about` | `quit_action` (`app.quit`), `about_action` (`app.about`) — matches |
| Accelerators | `app.quit` → `<Control>q`; `window.close` → `<Control>w`; `win.clear` → `<Control>n`, `Delete` | `ACCELS` hash — matches exactly |
| CSS | loads `style.css` via `Gtk::StyleProvider::PRIORITY_APPLICATION` | same, via `setup_css` | 
| Icon theme | registers app's own symbolic-icon dir | `setup_icons` adds `data/icons` to the icon theme search path |
| `--show-only` dev flag | reads trailing args as symbol ids via `command_line` override | `symbol_filter` reads `ARGV` | 

### `lib/window.rb` — the main window
Ported from `src/window.rs` + `data/resources/ui/window.ui`.

| Widget | × | CSS | Signals/actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` (`window`) | 1 | `devel` (Devel profile only — **not reproduced**, see Observations) | — | default size 700×400, height-request 400 |
| `Adw.Breakpoint` (`narrow_breakpoint`) | 1 | — | `apply`/`unapply` (halign of clear button) | condition `max-width: 500sp` |
| `Adw.ToastOverlay` | 1 | — | — | |
| `Adw.MultiLayoutView` (`layout_view`) | 1 | — | — | two named layouts: `sidebar`, `bottom-sheet` |
| `Adw.Layout` ×2 | 2 | — | — | `sidebar`, `bottom-sheet` |
| `Adw.OverlaySplitView` | 1 | — | — | `sidebar-position: end` |
| `Adw.NavigationPage` ×2 | 2 | — | — | "Symbols", "Drawing area" |
| `Adw.ToolbarView` ×5 | 5 | — | — | sidebar/content/sheet-content/sheet toolbars + symbol pane |
| `Adw.LayoutSlot` ×5 | 5 | — | — | headerbar/primary/secondary ×2 layouts |
| `Adw.BottomSheet` | 1 | — | `open` bound bidirectionally to `all_symbols_button.active`; `bottom-bar-height` bound to slot margin | |
| `Gtk.Overlay` (drawing) | 1 | — | — | holds drawing area + clear button |
| `DrawingArea` (app widget) | 1 | — | stroke callback → `classify` | see its own file |
| `Gtk.Button` (`clear_button`) | 1 | `clear-button` | `action-name: win.clear` | child is `Adw.ButtonContent` (icon `eraser-symbolic`, label "_Clear", underline) |
| `Gtk.Stack` (`symbol_stack`) | 1 | — | — | crossfade; pages `placeholder`/`symbols` |
| `Adw.StatusPage` | 1 | `compact` | — | "No Symbols" / "Start by drawing a symbol" |
| `Gtk.ScrolledWindow` (`symbol_scroller`) | 1 | — | — | `propagate-natural-height`, width 330, min-height 200 |
| `Gtk.ListBox` (`symbol_list`) | 1 | `navigation-sidebar` | `row-activated` → `copy_symbol_at` | bound to `symbol_store` via `NoSelection` |
| `Gio.ListStore` (`symbol_store`) | 1 | — | — | model type `SymbolObject` |
| `Gtk.Stack` (`bottom_bar_stack`) | 1 | — | — | crossfade; pages `placeholder`/`symbols` |
| `Gtk.Box`/`Gtk.Image`/`Gtk.Inscription` (bottom-bar placeholder) | 1 box, 1 image, 2 inscriptions | `title-3`, `caption` | — | "No Symbols" / "Start by drawing a symbol" |
| `SymbolItem` (`preview_symbol`) | 1 | — | — | shows the placeholder/preview symbol |
| `Gtk.ToggleButton` (`all_symbols_button`) | 1 | `flat` | `active` bound to sheet `open` | icon `up-symbolic` |
| `Adw.HeaderBar` (main) | 1 | — | — | `decoration-layout: :close` |
| `Adw.HeaderBar` (sheet) | 1 | — | — | |
| `IndicatorButton` | 1 | — | `action-name: win.show-contribution-dialog` | see its own file |
| `Adw.WindowTitle` | 1 | — | — | "Hieroglyphic" |
| `Gtk.MenuButton` | 1 | — | — | `menu_model` = `PrimaryMenu#build`, `primary: true` |
| Actions on window | — | — | `win.clear`, `win.show-contribution-dialog`, `win.copy-symbol(s)`, `win.markup-language-mode(s)` | all four present and wired |

### `lib/drawing_area.rb` — canvas
Ported from `src/widgets/drawing_area.rs` + `data/resources/ui/drawing-area.ui`.

| Widget | × | Signals | Notes |
|---|---:|---|---|
| `Gtk.DrawingArea` | 1 | — | hexpand/vexpand, custom draw func |
| `Gtk.GestureDrag` | 1 | `drag-begin`, `drag-update`, `drag-end` | all three connected |

Line color/width/cap/join and dot radius match upstream constants.

### `lib/symbol_item.rb` — one symbol row/preview
Ported from `src/widgets/symbol_item.rs` + `data/resources/ui/symbol-item.ui`.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` (root) | 1 | — | — | horizontal, margins 6/6 |
| `Gtk.Image` | 1 | — | — | icon-size large |
| `Gtk.Box` (inscriptions column) | 1 | — | — | vertical, hexpand |
| `Gtk.Inscription` ×3 | 3 | `title-3` (command), `caption` (mode) | — | package/command/mode |
| `Gtk.Button` (copy) | 1 | `flat` | `clicked` → `on_copy` | icon `copy-symbolic`, tooltip "Copy" |

### `lib/indicator_button.rb`
Ported from `src/widgets/indicator_button.rs` (no `.ui`; built in code, as the Ruby bindings cannot subclass to override `snapshot`).

| Widget | × | Signals | Notes |
|---|---:|---|---|
| `Gtk.Overlay` | 1 | — | |
| `Gtk.Button` | 1 | `action-name`, `icon-name`, `tooltip-text` set from constructor args | |
| `Gtk.DrawingArea` (dot) | 1 | custom draw func; `Adw.StyleManager` `notify::accent-color-rgba` | 8×8, offset (14,15), repainted on accent-color change |

### `lib/about.rb`
Ported from `src/widgets/about.rs`. Credits, license, website, issue tracker and the full debug-info blob (app id/version, backend, OS name/version, GTK/Libadwaita/Ruby versions, sandbox info incl. flatpak metadata keys) all present and match upstream's fields.

### `lib/contribution_dialog.rb`
Ported from `data/resources/ui/contribution-dialog.ui`, which upstream only materialises inside `win.show-contribution-dialog`'s handler in `src/window.rs`.

| Widget | × | CSS | Notes |
|---|---:|---|---|
| `Adw.Dialog` | 1 | — | 500×500, title "Improve Hieroglyphic" |
| `Adw.ToolbarView` | 1 | — | |
| `Adw.HeaderBar` | 1 | — | `show-title: false` |
| `Gtk.ScrolledWindow` + `Adw.Clamp` | 1 each | — | |
| `Gtk.Box` (content) | 1 | — | vertical |
| `Gtk.Picture` (illustration) | 1 | — | `pen-broadcast.svg` |
| `Gtk.Label` ×3 | 3 | `title-1`; `dim-label`+`caption` (privacy line) | title, description, privacy-policy link |
| `Adw.PreferencesGroup` | 1 | — | |
| `Adw.SwitchRow` | 1 | — | bound to `contribute-data` GSettings key |

### `lib/primary_menu.rb`
Ported from the `primary-menu` menu model in `window.ui`: a "Markup language" section with two radio items (`win.markup-language-mode('latex'|'typst')`) and an unlabelled section with `app.about`. All three items present.

### `lib/settings.rb`
Ported from `data/io.github.finefindus.Hieroglyphic.gschema.xml.in`. All three keys present: `show-contribution-nudge` (bool), `contribute-data` (bool), `markup-language-mode` (string, choices `latex`/`typst`, default `latex`).

### Data-model files
`lib/symbol.rb`, `lib/point.rb`, `lib/rect.rb`, `lib/stroke.rb`, `lib/symbol_object.rb` correspond 1:1 to `src/classify/{symbol,point,rect,stroke}.rs` and `src/widgets/symbol_object.rs`. `lib/classifier.rb` + `lib/onnx.rb` together cover `src/classify/classifier.rs`'s model loading and forward pass (`lib/onnx.rb` substitutes for the unavailable `ort`/ONNX-Runtime Ruby binding, as its header comment documents).

## Observations (not blockers, noted for follow-up)

- **`devel` CSS class**: upstream's `src/window.rs` `constructed()` adds the
  `devel` class to the window and forces `show-contribution-nudge` to `true`
  when `config::PROFILE == "Devel"`. No equivalent profile/CSS-class branch
  was found in `lib/window.rb` or `lib/hieroglyphic/application.rb`. This is
  a development-profile visual cue (diagonal stripe), not a release-build
  behaviour difference, but it is a dropped CSS class per the
  `component-identification` rules and worth a small follow-up.
- **Translation parity** (`po/*.po` string coverage) and **test parity**
  were not assessed here — they are the `translation-parity` and
  `test-parity` skills' job, not this inventory's.
- **Icon-set completeness** (every `data/resources/icons/*-symbolic.svg` has
  a corresponding file under `data/icons/hicolor/...`) was spot-checked, not
  exhaustively diffed; a full asset diff is a good follow-up for a future
  pass given the icon set numbers in the hundreds.

## Conclusion

No missing user-facing component was found. The `ruby` branch's `lib/`
tree already has full structural and behavioural coverage of upstream's
window, dialogs, widgets, menu, actions, accelerators, and settings schema.
The one gap worth tracking is the `devel` CSS class / profile check noted
above.
