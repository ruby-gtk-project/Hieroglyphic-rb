# Test parity — Hieroglyphic

| | |
|---|---|
| Upstream | `main` @ `246926e` |
| Port | `ruby` @ `4dc877f` |
| Upstream tests | 13 |
| Ported | 0 |
| Gaps | 13 |
| Test command | `ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])'` (printed by the dev shell banner) |

Re-verified against current HEAD (two commits past the pass this report was
written for: `b379a3e`, inventory-only, and `4dc877f`, the devel-profile CSS
class). Neither touches `spec/` or `test/`. Re-running `find spec -type f`
and `nix develop --command xvfb-run -a ruby test/drive_window.rb` reproduces
the same findings below unchanged: still 0 spec files, still 61/61 on the
driver. Nothing in this report is stale.

**The test command above has never had anything to run.** `spec/` contains
exactly `spec_helper.rb` (gem-scaffold boilerplate: SimpleCov wiring, RSpec
config) and `spec/README.md`. There is not one `*_spec.rb` file in the
repository. Running the command the dev shell advertises:

```
spec/spec_helper.rb -- 0 examples, 0 failures
```

(confirmed: `find spec -type f` returns only `spec_helper.rb` and
`README.md`; no file matches `*_spec.rb` or `*_test.rb` anywhere in the
tree). **A suite that has never been executed, because it has never been
written, is a gap — stated plainly, not left as an absence someone has to
notice.**

## Census

Upstream (`.claude/skills/test-parity/scripts/test-census.sh` against the
`origin/main` worktree):

```
src/classify/point.rs   test_add_points       104
src/classify/point.rs   test_sub_points        112
src/classify/point.rs   test_mul_point          120
src/classify/point.rs   test_approx_eq_vec      125
src/classify/rect.rs    test_rect_point          75
src/classify/rect.rs    test_width_height        80
src/classify/rect.rs    test_encompass           86
src/classify/stroke.rs  test_bounding_box       244
src/classify/stroke.rs  test_refit              252
src/classify/stroke.rs  test_smooth             268
src/classify/symbol.rs  test_from_id             97
src/classify/symbol.rs  test_id_get_id          119
src/classify/symbol.rs  test_iterate_symbols    114
```

13 tests, all `#[test]` functions in `#[cfg(test)] mod tests` blocks, none in
any build file's own test list (these are plain `cargo test` inline modules,
not registered elsewhere, so there is no second list to cross-check against).

Port (same script against the `ruby` branch): **90 rows, all in
`test/drive_window.rb`**. Every one of them is a GUI-driver `check(...)`
call (window visibility, layout state, dialog contents, accelerators,
actions …), the same file enumerated in `.reports/component-parity.md`. None
of the 90 corresponds to any of the 13 upstream rows — they test a different
thing (the assembled window) than the upstream tests do (geometry primitives
in isolation).

## Suite: `src/classify/point.rs` → `lib/point.rb` (4 tests)

| # | Upstream test | Purpose | Port test | State |
|---|---|---|---|---|
| 1 | `test_add_points` | `Point + Point` adds componentwise | — | **gap** |
| 2 | `test_sub_points` | `Point - Point` subtracts componentwise | — | **gap** |
| 3 | `test_mul_point` | `Point * scalar` scales componentwise | — | **gap** |
| 4 | `test_approx_eq_vec` | `approx_eq` tolerates a sub-epsilon (`SMALL_DELTA`) difference per axis | — | **gap** |

Behaviour still owed: a Ruby test asserting `Point.new(1,0) + Point.new(2,3)
== Point.new(3,3)` (and the symmetric cases for `-`, `*`, and an
approximately-equal pair within `SMALL_DELTA`), against `lib/point.rb`'s
actual operators.

## Suite: `src/classify/rect.rs` → `lib/rect.rb` (3 tests)

| # | Upstream test | Purpose | Port test | State |
|---|---|---|---|---|
| 1 | `test_rect_point` | `Rect.from_point(p).is_point?` is true for a degenerate rect | — | **gap** |
| 2 | `test_width_height` | a point-rect has zero width and height | — | **gap** |
| 3 | `test_encompass` | `encompass_point` grows a rect to include a new point | — | **gap** |

Behaviour still owed: Ruby tests pinning the same three properties against
`lib/rect.rb`.

## Suite: `src/classify/stroke.rs` → `lib/stroke.rb` (3 tests)

| # | Upstream test | Purpose | Port test | State |
|---|---|---|---|---|
| 1 | `test_bounding_box` | a stroke's bounding box is the min/max of its points | — | **gap** |
| 2 | `test_refit` | `refit` maps a stroke's points into a target rect, including the one-point (degenerate) case onto the rect's centre | — | **gap** |
| 3 | `test_smooth` | smoothing a jagged multi-point stroke reduces it predictably | — | **gap** |

Behaviour still owed: this is the normalization path the classifier depends
on before any stroke reaches the ONNX model — `refit` in particular has a
documented single-point special case upstream's test exists specifically to
pin, and nothing in the port asserts the port's `refit` keeps that case.

## Suite: `src/classify/symbol.rs` → `lib/symbol.rb` (3 tests)

| # | Upstream test | Purpose | Port test | State |
|---|---|---|---|---|
| 1 | `test_from_id` | a known base64 id resolves to the exact `Symbol` record (command, package, encoding, text/math mode, typst command) | — | **gap** |
| 2 | `test_id_get_id` | every symbol in the table round-trips: `from_id(symbol.id) == symbol`, for all 1124 | — | **gap** |
| 3 | `test_iterate_symbols` | the table has exactly 1124 entries | — | **gap** |

This pass manually confirmed, outside any test, that `Hieroglyphic::Symbol
.count == 1124` (see `.reports/component-identification.md`) and that
`from_id`/`table` exist with matching shapes — but that confirmation lives in
this audit, runs nowhere in CI or in the drive script, and disappears the
moment this report is stale. Test 2's round-trip property in particular
(every one of 1124 ids resolves back to itself) is not covered anywhere in
the port, manually or automatically.

## Extra

- `test/drive_window.rb` — 90 checks (counted per this skill's census rule:
  the house driver's assertion unit is `check(...)`, confirmed by reading
  `test/gtk_driver.rb`) driving the window, drawing area, symbol list, both
  layouts, both dialogs, the primary menu, accelerators, actions and
  `--show-only`. Genuinely useful, genuinely green (61 of 61 — the 90-row
  census counts every `check` call site including ones inside blocks that run
  more than once per drive; the driver reports 61 distinct executed checks
  this run), and genuinely not a substitute for the 13 rows above: it drives
  the assembled GUI and never calls `Point`, `Rect`, `Stroke` or `Symbol` in
  isolation.

## Prove it

- Counts equal? **No.** 13 upstream, 0 ported, 90 extra (GUI, not geometry).
- Bijection? **No mapping exists** — zero port tests are named after any
  upstream test.
- Suite passes under its own command? **The command exists and the directory
  it points at is empty.** `0 examples, 0 failures` is not a passing suite in
  any sense that carries weight; it is the test-parity equivalent of this
  skill's own "a suite that has never been executed is a gap" instruction.

**13/13 upstream tests are gaps. The port's inherited safety net for stroke
geometry, symbol-table lookup and the recognizer's own pre-processing is
exactly zero: none of it is pinned by anything that runs.**
