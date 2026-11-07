# Component parity — Hieroglyphic

| | |
|---|---|
| Upstream | `main` @ `246926e` |
| Port | `ruby` @ `b0a35e3` |
| Units checked | 2 / 21 (window+drawing+dialogs cluster, symbol table) |
| Runtime gate | `test/drive_window.rb`: 61/61 checks, DRIVE OK (re-run this pass) |

Full four-axis comparison (count, style, behaviour, text) was run on the two
units where the stakes are highest: the unit the drive script actually
exercises, and the unit it does not touch at all. The remaining 19 mapped
files in `.reports/component-inventory.md` are unchecked on this pass — they
have a file mapping and a "yes" in that inventory, but no axis-by-axis
verdict here, which is a narrower claim than "parity" and is stated as such
rather than rounded up.

## Unit: main window / drawing area / dialogs — `src/window.rs` + `ui/window.ui` + `ui/drawing-area.ui` + `ui/contribution-dialog.ui` + `src/widgets/about.rs` → `lib/window.rb`, `lib/drawing_area.rb`, `lib/contribution_dialog.rb`, `lib/about.rb`

| Widget / behaviour | Up | Port | CSS | Signals/actions | Text | Verdict |
|---|---|---|---|---|---|---|
| `Adw.Breakpoint` (500sp → bottom-sheet) | 1 | 1 | — | — | — | parity (driven: steps 15-20, DRIVE OK) |
| `Gtk.ListBox` `symbol_list`, capped at 25, filtered by language | 1 | 1 | `navigation-sidebar` | `row-activated` | — | parity (driven: step 6-7) |
| `IndicatorButton` nudge dot | 1 | 1 | — | `notify::accent-color-rgba` | — | parity (driven: step 0, 21-22; correspondence recorded, see component-identification.md) |
| `win.copy-symbol` + clipboard + toast | 1 | 1 | — | fires | **✗** | **gap** — msgid reworded, see below |
| `Adw.SwitchRow` `contribute-data` | 1 | 1 | — | `notify::active` bound | ✓ | parity (driven: step 23-24) |
| contribution dialog privacy-policy label | 1 | 1 | — | — | **✗** | **gap** — never marked, see below |
| `Adw.AboutDialog` + debug info | 1 | 1 | — | — | ✓ | parity (driven: steps 25-27, checks every upstream literal: icon, copyright, developer, developers, designers, artists, licence, website, issue tracker, translator-credits) |
| accels (`app.quit`, `window.close`, `win.clear`) | 3 | 3 | — | — | — | parity (driven: step 30, parsed-combination comparison) |
| `win.markup-language-mode` Typst branch | 1 | 1 | — | fires | — | **gap** — see Symbol table unit below; the action exists and switches state (driven, step 10-11) but the content it switches to is 63% incomplete |

**Text-axis gaps found, both real and both open in `.reports/translation-parity.md`:**

1. **`Copied "{}"` reworded.** Upstream `src/window.rs:393`:
   `format!("Copied \u{201c}{}\u{201d}", text)` wrapped in `gettext`, msgid
   `Copied "{}"`. Port `lib/window.rb:150`:
   `_("Copied "%{command}"") % {command: command}` — msgid
   `Copied "%{command}"`. Same user-visible sentence, different lookup key:
   the port's key has no translation in any of the 36 catalogues it ships,
   and upstream's key is simply missing from the port. This is a translation
   gap wearing a correctly-functioning toast — the behaviour axis passes
   (driven, step 9: "clipboard offers text") and the text axis does not, which
   is exactly the shape this skill's axes are split to catch.
2. **Privacy-policy label unmarked.** Upstream
   `data/resources/ui/contribution-dialog.ui:71`, msgid `No personal
   identifiable information is collected. <a
   href="…PRIVACY_POLICY.md">Privacy policy</a>`. Port
   `lib/contribution_dialog.rb:135-136` builds the identical English string as
   a bare literal concatenation, with no `_()` anywhere. It renders correctly
   in English and in no other language, and the drive script's step 21-22
   only checks "a dialog is showing" / "nudge dot is gone" — it never asserts
   on this label's text, so a screenshot and the existing 61/61 drive result
   both pass with this gap present.

## Unit: symbol table / Typst half — `src/classify/symbol.rs` + `symbols.yaml` + `typst-aliases.yaml` + `unicode_to_latex.yaml` → `lib/symbol.rb`

| Axis | Finding |
|---|---|
| Count | 1124 symbols on both sides (verified by running `Hieroglyphic::Symbol.count`, matching upstream's `test_iterate_symbols` assertion) |
| Behaviour | `win.markup-language-mode` switches and the list re-filters (driven, step 10-11: "rows kept only the symbols Typst can spell") |
| Completeness | **gap, and a large one.** Only 421 of 1124 symbols (37%) carry a `typst_command`. `unicode_to_latex.yaml` is present in `data/` but unused by `lib/symbol.rb` (confirmed: `grep -rn unicode_to_latex lib/` finds no reference). Upstream reaches the rest of its Typst coverage through the `mitex` and `codex` Rust crates' compile-time alias tables, which have no Ruby equivalent shipped or written. |
| Text | n/a — command strings are not translated, upstream or port |

This gap is disclosed in `.reports/component-inventory.md`'s own blockers
section, which is the right place for it, but the drive script's "Typst
commands are shown" check (step 11) only asserts that *some* row shows a
Typst command after filtering — it would pass identically whether 421 or 4
symbols carried one. **A component no check actually sizes is not a
component the runtime gate speaks to**, and 61/61 should not be read as
covering this axis.

## What the runtime gate actually covers

Re-running `nix develop --command xvfb-run -a ruby test/drive_window.rb`
this pass reproduces 61/61, DRIVE OK, across the window, drawing area,
symbol list, both layouts (sidebar + bottom-sheet), both dialogs, the primary
menu, accelerators, app/window actions and `--show-only`. That is a real and
fairly wide GUI smoke test — nine components is an accurate count of what it
touches. It is not, and does not claim to be, a check of:

- the two text-axis gaps above (no assertion reads the toast's or the
  privacy label's actual translated-vs-literal status, only that *a* toast
  or *a* dialog appears);
- the size of the Typst alias table (asserts non-empty, not complete);
- anything in `lib/classifier.rb` / `lib/onnx.rb` beyond "the list filled up
  … every row carries a command" — it never asserts the recognized symbol is
  the *correct* one for the drawn stroke, so a classifier that always
  returned the same wrong 25 labels would also pass step 4.
- the 13 upstream unit tests under `src/classify/` — see
  `.reports/test-parity.md`.

## Rules check

No component rated "parity" above rests on a status the drive script does
not actually assert; where the drive script's check is weaker than the claim
(symbol-list "every row carries a command" vs. "the correct row"), that gap
is named rather than folded into a pass.
