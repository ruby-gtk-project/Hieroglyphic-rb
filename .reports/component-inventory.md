# Hieroglyphic — upstream component inventory

Upstream is the Rust/gtk-rs implementation on `origin/main` (read with
`git show origin/main:<path>`). The port is the `ruby` branch of this repo.
Survey only — no app code was written for this report.

Upstream UI is split the usual gtk-rs way: a `src/**.rs` subclass beside a
`data/resources/ui/*.ui` GtkBuilder template. **The component is the pair**, and
both halves collapse into one `lib/*.rb` file in the port.

House shape taken from the pilot port `gnome-contacts-rb`: flat `lib/<thing>.rb`,
one top-level class per upstream source file, `# frozen_string_literal: true`
then `require 'adwaita'` then `require_relative` siblings, a class comment
naming the upstream file, widgets as memoized accessors configured in `.tap`.
The launcher stays at `lib/hieroglyphic/application.rb` as it is today.

## What the port has today

```
lib/hieroglyphic.rb                 require_relative shim
lib/hieroglyphic/application.rb     stub: window + toolbar view + header bar + "not written yet" status page
lib/hieroglyphic/rb/version.rb      version constant
```

Nothing else. **Every user-facing component below is missing.** The stub's
`Adwaita::StatusPage` ("The Ruby port has not been written yet") is not an
upstream component and should go when the real window lands.

## Component map

| # | Upstream file(s) | → port file | Kind | Exists |
|--:|---|---|---|---|
| 1 | `src/application.rs` | `lib/hieroglyphic/application.rb` | application (actions, accels, CSS) | partial (stub only) |
| 2 | `src/window.rs` + `data/resources/ui/window.ui` | `lib/window.rb` | main window | no |
| 3 | `src/widgets/drawing_area.rs` + `data/resources/ui/drawing-area.ui` | `lib/drawing_area.rb` | custom drawing widget | no |
| 4 | `src/widgets/symbol_item.rs` + `data/resources/ui/symbol-item.ui` | `lib/symbol_item.rb` | list row / bottom-bar preview | no |
| 5 | `src/widgets/indicator_button.rs` | `lib/indicator_button.rb` | header-bar button with custom snapshot | no |
| 6 | `data/resources/ui/contribution-dialog.ui` (built in `src/window.rs`) | `lib/contribution_dialog.rb` | dialog | no |
| 7 | `src/widgets/about.rs` | `lib/about.rb` | about dialog | no |
| 8 | `data/resources/ui/window.ui` → `menu id="primary-menu"` | `lib/primary_menu.rb` | menu model | no |
| 9 | `src/widgets/symbol_object.rs` | `lib/symbol_object.rb` | list-model item (GObject wrapper) | no |
| 10 | `src/classify/symbol.rs` + `symbols.yaml` + `typst-aliases.yaml` + `unicode_to_latex.yaml` | `lib/symbol.rb` | model / symbol table | no |
| 11 | `src/classify/classifier.rs` + `data/model.onnx` | `lib/classifier.rb` | ONNX inference engine | no |
| 12 | `src/classify/stroke.rs` | `lib/stroke.rb` | model | no |
| 13 | `src/classify/point.rs` | `lib/point.rb` | model | no |
| 14 | `src/classify/rect.rs` | `lib/rect.rb` | model | no |
| 15 | `src/window.rs` → `MarkupLanguageMode` + `SETTINGS` | `lib/settings.rb` | GSettings wrapper + enum | no |
| 16 | `data/resources/style.css` | `lib/style.css` (loaded by the application) | stylesheet | no |
| 17 | `data/io.github.finefindus.Hieroglyphic.gschema.xml.in` | `data/org.rubygtkproject.Hieroglyphic.gschema.xml` | GSettings schema | no |
| 18 | `data/resources/resources.gresource.xml` + `data/resources/icons/*` (1000+) + `illustrations/pen-broadcast.svg` | `data/icons/`, loaded via `Gtk::IconTheme#add_search_path` | resources | no |
| 19 | `po/` (36 languages, `po/POTFILES.in`) | `po/` | translations | no |

Nothing in `lib/` on `ruby` is an extra the upstream does not have, apart from
the placeholder status page.

---

## 1. `src/application.rs` — the application: actions, accelerators, CSS

Not a widget, but it owns the global commands.

| Item | × | Notes |
|---|---:|---|
| `Gtk.CssProvider` | 1 | loads `style.css` at `STYLE_PROVIDER_PRIORITY_APPLICATION` on the default display |
| action `app.quit` | 1 | closes the main window (to fire the delete event / save state) then quits |
| action `app.about` | 1 | presents the about dialog (component 7) |
| accel `app.quit` | 1 | `<Control>q` |
| accel `window.close` | 1 | `<Control>w` |
| accel `win.clear` | 1 | `<Control>n`, `Delete` |

Other behaviour: `Gtk::Window.set_default_icon_name(APP_ID)` on startup; single
window held weakly and re-presented on a second activate; `HANDLES_COMMAND_LINE`
flag with a `--show-only <ids…>` developer argument that pins the symbol list
to the given ids (any other argument exits with failure); `resource-base-path`
`/io/github/finefindus/Hieroglyphic/`; `GTK_THEME` is unset before startup.
`_backdoor()` is a joke function with no behaviour — do not port.

Port notes: the Ruby bindings have no working `Adwaita::Application`, so the
application object is `Gtk::Application` (as the current stub already does).
Accels go through `set_accels_for_action`.

## 2. `src/window.rs` + `ui/window.ui` — the main window

The whole app. Two layouts of the same three slots, switched by a breakpoint.

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` (template `HieroglyphicWindow`) | 1 | `devel` (Devel profile only) | — | 700×400 default, `height-request` 400; `stack_page` string property drives both stacks |
| `Adw.Breakpoint` | 1 | — | — | `max-width: 500sp` → sets `view.layout-name` to `bottom-sheet` and `clear_button.halign` to `center` |
| `Adw.ToastOverlay` `toast_overlay` | 1 | — | — | `dismiss_all` then one toast per copy |
| `Adw.MultiLayoutView` `view` | 1 | — | — | slots `headerbar`, `primary`, `secondary` |
| `Adw.Layout` name `sidebar` | 1 | — | — | wide layout |
| `Adw.OverlaySplitView` | 1 | — | — | `sidebar-position: end` |
| `Adw.NavigationPage` | 2 | — | — | titles `Symbols` (untranslated), `Drawing area` (untranslated) |
| `Adw.ToolbarView` | 4 | — | — | sidebar page, content page, bottom-sheet content, bottom-sheet sheet |
| `Adw.LayoutSlot` | 5 | — | — | `headerbar` ×2, `secondary` ×2, `primary` ×1 (+ `primary` in the sheet layout, `margin-bottom` bound to `sheet.bottom-bar-height`) |
| `Adw.Layout` name `bottom-sheet` | 1 | — | — | narrow layout |
| `Adw.BottomSheet` `sheet` | 1 | — | — | `open` bound bidirectionally + sync-create to `all_symbols_button.active` |
| `Adw.HeaderBar` | 2 | — | — | the shared one (slot `headerbar`, `decoration-layout` `:close`), plus a bare one on the sheet |
| `Gtk.Stack` | 2 | — | — | `visible-child-name` bound to the window's `stack_page`; `crossfade`; pages `placeholder` / `symbols`. One is the sheet's bottom bar, one is the sidebar content |
| `Gtk.Box` | 4 | — | — | bottom-bar placeholder row, its vertical text box, bottom-bar symbol row, (margins 6/6/15/15) |
| `Gtk.Image` | 1 | — | — | `edit-symbolic`, `GTK_ICON_SIZE_LARGE`, in the bottom-bar placeholder |
| `Gtk.Inscription` | 2 | `title-3`, `caption` | — | "No Symbols" / "Start by drawing a symbol" in the bottom bar |
| `SymbolItem` `preview_symbol` | 1 | — | — | component 4, in the bottom bar; placeholder properties point at `\bigcup` |
| `Gtk.ToggleButton` `all_symbols_button` | 1 | `flat` | — | tooltip "All Symbols", icon `up`, `valign: center`; opens the sheet |
| `Adw.StatusPage` | 1 | `compact` | — | **empty state**: icon `edit-symbolic`, title "No Symbols", description "Start by drawing a symbol" |
| `Gtk.ScrolledWindow` | 1 | — | — | `width-request` 330, `min-content-height` 200, `hscrollbar-policy: never`, `propagate-natural-height` |
| `Gtk.ListBox` `symbol_list` | 1 | `navigation-sidebar` | `row-activated` → `on_item_activated` | `selection-mode: none`; `bind_model` over a `Gtk.NoSelection` of the `Gio.ListStore` with a factory building a `SymbolItem` per `SymbolObject` |
| `Gtk.Overlay` `overlay` | 1 | — | — | holds the drawing area with the clear button on top |
| `DrawingArea` `drawing_area` | 1 | — | `stroke-drawn` → `classify` | component 3 |
| `Gtk.Button` `clear_button` | 1 | `clear-button` | action `win.clear` | overlay, `halign: start` / `valign: end`, margins 12/18/18 |
| `Adw.ButtonContent` | 1 | — | — | icon `eraser-symbolic`, label `_Clear` with mnemonic |
| `Adw.WindowTitle` | 1 | — | — | "Hieroglyphic", untranslated |
| `IndicatorButton` `indicator_button` | 1 | — | action `win.show-contribution-dialog` | icon `document-send-symbolic`, tooltip "Improve Hieroglyphic"; `show-indicator` bound to the `show-contribution-nudge` setting |
| `Gtk.MenuButton` | 1 | — | — | `primary: true`, icon `open-menu-symbolic`, tooltip "Main Menu", `menu_model` = `primary-menu` (component 8) |

Actions installed on the window:

| Action | Parameter | Does |
|---|---|---|
| `win.clear` | — | `drawing_area.clear` |
| `win.show-contribution-dialog` | — | builds the contribution dialog (component 6), binds `contribute-data` to its switch, sets `show-contribution-nudge` false, presents it |
| `win.copy-symbol` | `s` (symbol id) | resolves the id to a `Symbol` and copies it |
| `win.markup-language-mode` | `s`, stateful | state from the `markup-language-mode` setting; writes it back and re-renders the current symbol list in the new language |

Repeaters: `symbol_list` is one component per `SymbolObject` in the store,
**capped at 25** (`.take(25)`) and filtered to symbols the current markup
language supports. Conditional: the `devel` CSS class and the forced nudge only
in the Devel profile; the `--show-only` filter replaces classifications when set.

Other behaviour to port: `Copied “{}”` toast on copy (clipboard via
`self.clipboard`), scroll-to-top after each refresh, GTK icon theme forced to
`Adwaita`, classifier on a worker thread with a request/response channel pair,
and the opt-in stroke upload (`POST .../v1/upload/{label}`, skipped when
`contribute-data` is off, on the Devel profile, on a metered network
(`Gio::NetworkMonitor`) or with power saver on (`Gio::PowerProfileMonitor`)).

## 3. `src/widgets/drawing_area.rs` + `ui/drawing-area.ui` — the canvas

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` (template `DrawingArea`) | 1 | — | emits `stroke-drawn` (`BoxedStrokes`) | `hexpand` / `vexpand` true |
| `Gtk.GestureDrag` `drag` (controller) | 1 | — | `drag-begin` → `on_drag_begin`, `drag-update` → `on_drag_update`, `drag-end` → `on_drag_end` | added as a controller in `constructed` |

No child widgets: everything is drawn in `snapshot` with a `Gsk::PathBuilder`
— 3px round-cap stroke, a 1.5px circle for a single-point stroke, line colour
`#CCCCCC` in dark mode and `rgb(0.37,0.36,0.39)` (adw `@dark_2`) in light.
`clear` empties both the stroke list and the in-progress stroke and redraws.
`drag-update` coordinates are relative to the drag start and must be added to
the first point.

## 4. `src/widgets/symbol_item.rs` + `ui/symbol-item.ui` — one symbol row

Used twice: as the `symbol_list` row and as the bottom-bar preview.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` (template `SymbolItem`) | 1 | — | — | horizontal, margins 6/6; properties `id`, `icon`, `package`, `command`, `mode` (construct-only upstream, all re-notified by `set_symbol`) |
| `Gtk.Image` | 1 | — | — | `icon-name` bound to `icon` (sync-create), `GTK_ICON_SIZE_LARGE`, `margin-end` 4, accessible role `presentation` |
| `Gtk.Box` | 1 | — | — | vertical, `hexpand` |
| `Gtk.Inscription` | 3 | — / `title-3` / `caption` | — | package, command, mode description |
| `Gtk.Button` | 1 | `flat` | `clicked` → `on_copy` | tooltip "Copy", icon `copy-symbolic`, `valign: center`; activates `win.copy-symbol` with the id |

The icon name is the symbol id with trailing `=` stripped plus `-symbolic`.

## 5. `src/widgets/indicator_button.rs` — the nudge button

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Button` subclass `IndicatorButton` | 1 | — | `Adw.StyleManager::notify::accent-color-rgba` → `queue_draw` | `show-indicator` boolean property; setter redraws |

Custom `snapshot`: chains up, then — only when `show-indicator` — pushes a
rounded clip of `Rect(14, 15, 8, 8)` (radius 100) and fills it with the current
accent colour. In Ruby this is the one place a GObject subclass with an
overridden `snapshot` is unavoidable; the alternative is an overlay dot.

## 6. `ui/contribution-dialog.ui` — "Improve Hieroglyphic" dialog

Built by `win.show-contribution-dialog`; no backing source file upstream.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Dialog` `contribution_dialog` | 1 | — | — | 500×500, title "Improve Hieroglyphic" |
| `Adw.ToolbarView` | 1 | — | — | — |
| `Adw.HeaderBar` | 1 | — | — | `show-title: false` |
| `Gtk.ScrolledWindow` | 1 | — | — | `hscrollbar-policy: never` |
| `Adw.Clamp` | 1 | — | — | — |
| `Gtk.Box` | 2 | — | — | vertical content box (margins 12/12/12, `valign: center`) and the centred picture box |
| `Gtk.Picture` | 1 | — | — | `pen-broadcast.svg`, `can-shrink: false`, accessible role `presentation` |
| `Gtk.Label` | 3 | `title-1`; (none); `dim-label` + `caption` | — | heading, body copy, and the privacy-policy line with `use_markup` and an `<a href>` to `PRIVACY_POLICY.md` |
| `Adw.PreferencesGroup` | 1 | — | — | `margin-top` 24 |
| `Adw.SwitchRow` `switch_row` | 1 | — | — | "Contribute Symbols" / "Submit recognized drawings to Hieroglyphic's dataset"; `active` bound to the `contribute-data` setting |

This is the app's only preferences surface — there is no preferences window.

## 7. `src/widgets/about.rs` — about dialog

| Widget | × | Notes |
|---|---:|---|
| `Adw.AboutDialog` | 1 | app icon, name "Hieroglyphic", developer `FineFindus`, developers / designers / artists lists, `translator-credits`, GPL-3.0, version, website, issue URL, copyright "Copyright © 2024 FineFindus" |

Also builds a `debug_info` blob (filename `tex_match_debug`): app id and
version, profile, GDK backend name, OS name/version, GTK and libadwaita
versions, and sandbox info read from `/.flatpak-info` or `GTK_USE_PORTAL`.
Note `Gtk::VERSION` does not exist in the Ruby bindings — use `Gtk::Version`.

## 8. `primary-menu` (menu model in `ui/window.ui`)

| Section | Items | Action |
|---|---|---|
| "Markup language" | "LaTeX", "Typst" | `win.markup-language-mode` with targets `latex` / `typst` |
| (unlabelled) | "About Hieroglyphic" | `app.about` |

Three `item` entries, no `custom:` slots. The first section is a radio group
driven by the stateful window action.

## 9–14. Non-widget model and engine

| Upstream | → port | What it is |
|---|---|---|
| `src/widgets/symbol_object.rs` | `lib/symbol_object.rb` | bare `GObject` wrapping a `Symbol`, the `Gio::ListStore` item type |
| `src/classify/symbol.rs` (+ `build.rs` codegen from `symbols.yaml`, `typst-aliases.yaml`, `unicode_to_latex.yaml`) | `lib/symbol.rb` | the ~1000-entry symbol table; base64 id from `package-encoding-command`; per-language `command` / `package` / `mode_description`; `SYMBOL_COUNT` |
| `src/classify/classifier.rs` + `data/model.onnx` | `lib/classifier.rb` | ONNX session, strokes → 1×3×32×32 tensor, top-25 labels |
| `src/classify/stroke.rs` | `lib/stroke.rb` | point list, length, bounding box, refit/dedup/aspect-ratio normalisation, JSON serialisation for upload |
| `src/classify/point.rs` | `lib/point.rb` | x/y, dot, norm, distance, scale, angle, approx-eq |
| `src/classify/rect.rs` | `lib/rect.rb` | two-point rect, width/height, map_points, encompass_point |

## 15–19. Supporting surfaces

- **Settings** (`lib/settings.rb`): schema `@app-id@` at path
  `/io.github.finefindus.Hieroglyphic/` with `show-contribution-nudge` (b,
  default true), `contribute-data` (b, default false) and
  `markup-language-mode` (s, choices `latex` / `typst`, default `latex`).
  `MarkupLanguageMode` (upstream an enum in `src/window.rs`) belongs here.
- **Stylesheet**: `data/resources/style.css` defines `.title-header`
  (36px bold — **defined and never applied; dead upstream**) and `.clear-button`
  (padding 5px 16px, `border-radius: 9999px`). Other classes used by the app
  (`flat`, `compact`, `title-1`, `title-3`, `caption`, `dim-label`,
  `navigation-sidebar`, `devel`) come from libadwaita.
- **Resources**: six action icons (`eraser-symbolic` ← `eraser5-symbolic`,
  `info-outline-symbolic` (**registered but unused**), `edit-symbolic`,
  `document-send-symbolic`, `copy-symbolic`, `up-symbolic`), one illustration
  (`pen-broadcast.svg`), and 1000+ generated per-symbol preview icons whose
  names are the base64 symbol ids. The port has no GResource, so these need an
  icon search path.
- **Translations**: 36 languages in `po/LINGUAS`; `po/POTFILES.in` lists the
  desktop file, gschema, metainfo, the three translatable `.ui` files and four
  `.rs` files. Translatable UI strings: "Markup language", "LaTeX", "Typst",
  "About Hieroglyphic", "No Symbols" ×2, "Start by drawing a symbol" ×2,
  "All Symbols", "_Clear", "Improve Hieroglyphic" ×2, "Main Menu", "Copy",
  "Contribute Symbols", "Submit recognized drawings…", the privacy-policy
  line, "Hieroglyphic", `translator-credits`, and `Copied “{}”`.

## Blockers for the port

1. **The classifier.** Upstream runs `data/model.onnx` through the `ort` crate.
   Ruby has no comparable in-tree ONNX runtime in this fork's dev shell, so
   either an FFI binding to `onnxruntime` is added to the flake or the
   classifier is stubbed and every symbol-list component is exercised with
   canned classifications.
2. **The symbol table is generated at build time** by `build.rs` from three
   YAML files into a perfect-hash map. The port has to generate or load the
   equivalent at runtime from `symbols.yaml`, `typst-aliases.yaml` and
   `unicode_to_latex.yaml`.
3. **1000+ generated symbol icons** live in the GResource, built by
   `scripts/generate_icons.py` from LaTeX. The port needs them on disk plus an
   icon search path; regenerating them needs a TeX toolchain.
4. **`Adw.MultiLayoutView`, `Adw.Layout`, `Adw.LayoutSlot`, `Adw.BottomSheet`
   and `Adw.Breakpoint` setters** are recent libadwaita; whether the fork's
   Ruby bindings expose them (especially `Adwaita::Breakpoint#add_setter` and
   the layout-slot API) must be checked in the dev shell before the window is
   written.
5. **`IndicatorButton` needs a real GObject subclass** with an overridden
   `snapshot`, which the house style otherwise avoids; the `.ui` property
   bindings (`bind-source` / `bind-flags`) also have to become explicit
   `bind_property` calls.
6. **`BoxedStrokes` is a custom boxed GType** carrying the strokes through the
   `stroke-drawn` signal. In Ruby the signal can carry the Ruby object
   directly, so the boxed type does not port — but a custom signal must still
   be registered on the drawing area.
