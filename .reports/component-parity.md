# Component parity — Hieroglyphic

| | |
|---|---|
| Upstream | `main` @ `246926e` |
| Port | `ruby` @ `d5d7c8c` |
| Units checked | 2 / 21 (window+drawing+dialogs cluster, symbol table) — unchanged scope this pass; the other 19 remain a presence map, not a parity map (see `component-identification.md`) |
| Runtime gate | `test/drive_window.rb`: 61/61 checks, DRIVE OK (re-run this pass, matches this round's reported gate exactly) |

## Re-verified against current HEAD (`d5d7c8c`, five commits past `4dc877f`)

Both open gaps from the last pass over the checked units are now **closed**:

- **Devel-profile upload suppression** — `dc72d34` added `!devel_profile?`
  to `lib/window.rb`'s `upload_allowed?`. Confirmed by reading
  `lib/window.rb:647-654` this pass: all four of upstream's conditions are
  now present (`!strokes.empty?`, `contribute_data?`, `!network_metered?`,
  `!power_saver_enabled?`, `!devel_profile?`).
- **Privacy-policy label unmarked** — `5a2094a` wrapped it in `_()`. See
  `.reports/translation-parity.md` for the text-axis detail (the msgid now
  matches upstream's, byte for byte, once the `&lt;`/`&gt;` scanner artifact
  is accounted for).

One gap from the last pass is still open, **worse than previously
described**, and three new ones were found this pass by reading rather than
re-trusting the earlier "yes" rows.

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
| `win.copy-symbol` + clipboard + toast | 1 | 1 | — | fires | **✗** | **gap** — msgid reworded *and* fabricated-translation finding, see below |
| `Adw.SwitchRow` `contribute-data` | 1 | 1 | — | `notify::active` bound | ✓ | parity (driven: step 23-24) |
| contribution dialog privacy-policy label | 1 | 1 | — | — | ✓ | **parity, closed this pass** (`5a2094a`) |
| `Adw.AboutDialog` + debug info | 1 | 1 | — | — | **✗** | **gap** — `Profile:` line dropped, filename renamed, see below (not driven: steps 25-27 check nine other literals, not this one) |
| accels (`app.quit`, `window.close`, `win.clear`) | 3 | 3 | — | — | — | parity (driven: step 30, parsed-combination comparison) |
| `win.markup-language-mode` Typst branch | 1 | 1 | — | fires | — | **gap** — see Symbol table unit below; the action exists and switches state (driven, step 10-11) but the content it switches to is 63% incomplete |
| Devel-profile upload suppression | 1 | 1 | — | — | — | **parity, closed this pass** (`dc72d34`) |
| decorative-image `accessible-role` (contribution dialog, symbol item) | 2 | 0 | — | — | — | **gap**, new this pass — see below |
| `Application#build` reactivation guard | 1 | 0 | — | — | — | **gap**, new this pass — see below |

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
2. **Privacy-policy label.** **Closed** (`5a2094a`); see
   `.reports/translation-parity.md`. Kept as a row for the record, state
   corrected from the last pass.

**Gap carried over, now worse than described — the reworded "Copied"
string is not just untranslated, it ships 36 fabricated translations.**
The last pass recorded this as a reword that drops the upstream key and
ships "untranslated". Reading the actual `.po` files this pass shows every
one of the 36 catalogues has a complete, non-fuzzy `msgstr` for the invented
key — mechanically derived from the old translation by a textual `{}` →
`%{command}` substitution, not reviewed by anyone. Full detail, including
the exact `.po` excerpts across six languages, is in
`.reports/translation-parity.md`'s headline finding; recorded here because
it is also a behaviour-axis note: `win.copy-symbol` (behaviour) still passes
(driven, step 9), and the text axis fails in a way no screenshot or drive
check can see, which is exactly this report's split of axes doing its job.

**New gaps found this pass:**

3. **`About`'s debug-info blob drops upstream's `Profile:` line and renames
   the attachment file.** Upstream `src/widgets/about.rs:33,43`:
   `.debug_info_filename("tex_match_debug")` and a `Profile: {}` line right
   after the app-id/version line. Port `lib/about.rb#debug_info` has no
   `Profile:` entry at all, and `about.debug_info_filename =
   "hieroglyphic_debug"` — a different filename than upstream's. The
   drive script's steps 25-27 check that the debug info "names the app" and
   "names GTK" and check nine *other* literal fields (icon, copyright,
   developer, developers, designers, artists, licence, website, issue
   tracker) — none of those checks reads the `Profile:` line or the
   filename, so this gap is invisible to the 61/61 result. Minor in
   consequence (a bug reporter's attachment is named differently and is
   missing one diagnostic line) but real and unflagged before this pass.
4. **Two decorative images drop `accessible-role="GTK_ACCESSIBLE_ROLE_PRESENTATION"`.**
   `data/resources/ui/contribution-dialog.ui`'s `GtkPicture` and
   `data/resources/ui/symbol-item.ui`'s `GtkImage` both carry this attribute
   upstream; `lib/contribution_dialog.rb#illustration` and
   `lib/symbol_item.rb#image` do not set it. An accessibility regression: a
   screen reader will now announce these purely decorative images where
   upstream suppresses them. Not something a screenshot-based drive check
   can catch by construction.
5. **`Application#build`'s `activate` handler has no "already running"
   guard.** Upstream's `activate()` checks for an existing window and only
   `present()`s it on a second activation; the port's
   `app.signal_connect("activate") { window.tap { |win| win.build; … } }`
   unconditionally calls `win.build` again on the same memoized `window`
   object every time `activate` fires (which GTK delivers to the same
   process on a second launch of a single-instance app, not just once per
   process). `Gio::SimpleAction#add_action` does not raise on a duplicate
   name (confirmed by testing it directly this pass), so this does not crash
   — but every `signal_connect` call inside `build` (on `clear_action`,
   `contribution_dialog_action`, `copy_symbol_action`,
   `markup_language_action`, and the window's `narrow_breakpoint`) adds a
   *second* handler alongside the first, so a second activation leaves the
   window responding to each of those actions twice (clearing twice,
   spawning a second classifier thread, showing a toast twice, etc. on
   every subsequent use). Not exercised by `test/drive_window.rb`, which
   activates the app exactly once per process.

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

- the toast's msgid, the fabricated translations behind it, the dropped
  `Profile:` line, the renamed debug-info filename, or either dropped
  `accessible-role` — no assertion reads any of these, only that *a* toast or
  *a* dialog appears, or that the debug blob names the app and GTK;
- the size of the Typst alias table (asserts non-empty, not complete);
- anything in `lib/classifier.rb` / `lib/onnx.rb` beyond "the list filled up
  … every row carries a command" — it never asserts the recognized symbol is
  the *correct* one for the drawn stroke, so a classifier that always
  returned the same wrong 25 labels would also pass step 4;
- a second `activate` on an already-running instance — the driver activates
  the app exactly once per process, so the reactivation gap above has no
  check that could have caught it;
- the 13 upstream unit tests under `src/classify/` — now closed, see
  `.reports/test-parity.md`, but the driver still never calls them; they are
  covered by the spec suite, not by this script.

## Rules check

No component rated "parity" above rests on a status the drive script does
not actually assert; where the drive script's check is weaker than the claim
(symbol-list "every row carries a command" vs. "the correct row"), that gap
is named rather than folded into a pass. The two components whose state
flipped this pass (Devel upload suppression, privacy-policy label) were
re-read from source, not carried over from the last report's wording; the
four still-or-newly open gaps (Typst coverage, the "Copied" rewording and
its fabricated translations, the About debug-info drops, the two
accessible-role drops, and the reactivation guard) are each cited to a file
and line above.
