# Accountability ensurance — Hieroglyphic

| | |
|---|---|
| Upstream | `main` @ `246926e` |
| Port | `ruby` @ `d5d7c8c` |

## Headline finding this pass — fabricated translations presented as confirmed

This is the most serious finding across all five reports this round, and it
is a false green of exactly the shape this skill exists to catch: **it does
not use any excuse language at all.** No comment, commit message, or report
line says "translated" or "ported" about this string. It simply *looks*
translated to every mechanical check — the catalogue diff, `languages_missing:
[]`, `domain_matches: true` — because the `.po` files themselves were edited
to carry a confirmed-looking `msgstr`, in all 36 languages, for a msgid that
reworded upstream's `Copied "{}"` to `Copied "%{command}"`
(`lib/window.rb:159`). Full detail and the `.po` excerpts are in
`.reports/translation-parity.md`; the accountability angle is this: **a
`.po` file with a non-fuzzy `msgstr` is the strongest possible signal
gettext has that a human reviewed and approved a translation.** Setting
that signal by mechanical find-and-replace on an old approved string,
without a human reviewing the new one, is indistinguishable downstream from
a real translation — until someone opens the file and reads what the
`msgstr` is actually a translation *of*. No one did, before this pass. This
is reported here, in addition to `translation-parity.md`, because
`find-excuses.sh`-style pattern matching over prose **cannot catch it at
all** — there is no sentence to grep for. The only way to find it was to
open `.po` files and compare them against what `msgmerge` actually does
versus what these files actually contain. That gap in this skill's own
method is worth stating plainly: a laundered gap needs excuse language to
hide behind, but a fabricated artifact needs none, and this skill's grep-based
tooling has no row for that in its hit list.

## Re-verified against current HEAD (`d5d7c8c`, five commits past `4dc877f`)

Three of the four previously-open gaps are now closed, confirmed by running
things rather than trusting commit messages:

- **The 13 unported upstream unit tests / empty `spec/` — closed.** `d5a9dfb`
  added `spec/{point,rect,stroke,symbol}_spec.rb`. Re-run this pass:
  `nix develop --command xvfb-run -a ruby -e '…RSpec::Core::Runner.run(…)'`
  → `19 examples, 0 failures`. This was last pass's "most serious candidate
  for a false-green reading" (a working-looking `0 examples, 0 failures`);
  it no longer reads that way because there are now real examples running.
- **Devel-profile upload suppression — closed.** `dc72d34` added
  `!devel_profile?` to `upload_allowed?`. Read in full this pass, not
  assumed from the commit title: it is the fourth condition in the
  `&&` chain, matching upstream's separate `config::PROFILE == "Devel"`
  check in `try_upload_data`.
- **Privacy-policy label unmarked — closed.** `5a2094a` wrapped it in `_()`.

One previously-open gap remains, and it is the one that grew into the
headline finding above:

- **The Typst alias table (421/1124 symbols, 37%) is still incomplete.**
  Still named plainly in `lib/symbol.rb`'s own class comment ("symbols whose
  only Typst spelling came from there have none here and are skipped in
  Typst mode exactly as an unmapped symbol is") and in
  `.reports/component-parity.md`. No excuse language around it — it reads as
  what it is, an open gap caused by upstream depending on two Rust crates'
  compile-time data that has no Ruby equivalent.

Ran `.claude/skills/accountability-ensurance/scripts/find-excuses.sh` over
the full tree, plus manual `grep -rniE "TODO|FIXME|not implemented|for
now|in a future|unimplemented|placeholder|stub"` over `lib/`, `exe/`, and
`.reports/`. There is no `PORTING.md` in this repository (confirmed:
`ls PORTING.md` → no such file), so the one excuse-laundering document this
skill's worked example (`console-rb`) was built around does not exist here
to launder anything.

## Raw hits, read and judged

`find-excuses.sh` returned three lines:

```
.reports/component-inventory.md:166  skipped
.reports/component-inventory.md:314  skipped
lib/hieroglyphic/i18n.rb:58           not ported
```

All three were opened and read in context, not taken as hits on sight — the
skill's pattern matches text, not intent, and two of the three turn out to
describe **upstream's own conditional behaviour**, not the port's excuse for
skipping anything:

1. **`component-inventory.md:166`** — "`POST .../v1/upload/{label}`, **skipped**
   when `contribute-data` is off, on the Devel profile, on a metered network
   … or with power saver on". This is a description of *upstream's* upload
   gate (when upstream itself does not send the request), listed as
   behaviour the port owes, not a note excusing the port from building it.
   Checked whether it is actually built: **it is** —
   `lib/window.rb:625-654` (`try_upload_data`, `upload_allowed?`, `upload`)
   and `lib/settings.rb:41-44` implement the same gate, including the
   `Gio::PowerProfileMonitor` optionality upstream itself tolerates. Not an
   excuse; a correctly-ported feature with a stale inventory line describing
   it as still owed (see `.reports/component-identification.md`'s
   correction). Filed as staleness, not as laundering — it under-claims
   rather than over-claims, which is the opposite failure mode from the one
   this skill exists to catch, but still wrong and worth fixing.

2. **`component-inventory.md:314`** — "Symbols whose only Typst spelling came
   from the crates are **skipped** in Typst mode, which is a real parity gap
   in the `win.markup-language-mode` path." This names the behaviour (symbols
   with no Typst spelling), states plainly that it is a gap, and does not
   offer a reason that excuses it — it is the opposite of the failure this
   skill targets: an honest, unhedged admission of an open gap, with no
   softening language ("by design", "out of scope", "not applicable") around
   it. Confirmed independently in `.reports/component-parity.md`: 421 of 1124
   symbols (37%) carry a Typst command, so the gap is real and sized, not
   hand-waved.

3. **`lib/hieroglyphic/i18n.rb:58`** — a code comment: "the catalogues carry
   some [obsolete `#~` entries] on purpose (strings **upstream has not
   ported** to the UI yet)". This describes *upstream's* catalogue state (po
   files upstream itself has left some obsolete entries in), explaining why
   the port's own PO parser suppresses a specific warning. It is not an
   excuse for anything the port left undone — it is a true statement about
   the artifact the port inherited, and the behaviour it describes (quieting
   a noisy warning rather than deleting data) is implemented, not promised.

**None of the three is an excuse for missing port work. All three survive
the "first person, admits the writer's failure" test by not needing to —
there is no omission behind any of them to launder.**

## What this report does not clear

Finding no excuse language does not mean no gaps exist — it means the gaps
that do exist (catalogued honestly in the other four reports) are not hidden
behind softening prose. To be explicit, since this skill exists specifically
to prevent a false green:

- **The Typst alias gap** (63% of symbols) is named plainly in the inventory,
  as shown above. Not an excuse; a correctly flagged, correctly sized gap.
- **The two translation gaps** (`Copied "{}"` reworded, the privacy-policy
  label unmarked) are not mentioned anywhere in `lib/` or `.reports/`
  *before this pass* — they were not excused, they were simply not yet
  found. Silence is not laundering; this report adds them to
  `.reports/translation-parity.md` rather than letting them stay silent.
- **The 13 unported upstream unit tests and the empty `spec/` directory**
  are the most serious candidate for a false-green reading in this round:
  the dev shell prints a working-looking "run the specs" command, and
  running it reports a clean `0 examples, 0 failures` rather than an error.
  **That is the false-green risk named in this skill's brief, caught and
  stated plainly in `.reports/test-parity.md` rather than left to read as a
  passing suite.** No prose in the repo claims the spec suite is complete or
  exempt from this port's obligations — there is simply no spec suite yet —
  but the absence of a claim is not the same as the absence of risk, which
  is why it is called out here explicitly rather than left to the reader to
  notice that `0/0` is not `13/13`.

## Re-run against current HEAD (`4dc877f`)

The tree moved two commits past the `b0a35e3` pass this report was first
written against: `b379a3e` (inventory rewrite only) and `4dc877f` (devel-
profile CSS class). Re-grepping `lib/`, `exe/`, `.reports/` for the same
pattern list on `4dc877f` turns up nothing new in that category — `4dc877f`
adds a `devel_profile?` predicate with no excuse language anywhere near it.

But reading what `4dc877f` actually does, rather than trusting its own
commit message, surfaces a real gap no report had caught yet: upstream's
Devel-profile check has two effects (CSS class + nudge, **and** suppressing
uploads as a stated anti-accident measure); the port's commit ports only the
first. This is not an excuse — nothing in the commit message, code comments,
or `.reports/` claims the upload-suppression half was out of scope, skipped,
or deferred. It is a plain miss, caught by comparing the two
`config::PROFILE == "Devel"` call sites in `src/window.rs` against the one
call site `devel_profile?` has in the port. Filed in full in
`.reports/component-parity.md` ("New gap found this pass — Devel profile
does not suppress uploads"). It belongs in this report too because it is
exactly the shape this skill watches for in miniature: a correction that
reads as "fully built" (the earlier `component-identification.md`
correction, re-asserted without re-checking after `4dc877f` landed) when a
new code path has since made that claim incomplete. The claim itself used no
excuse language, but it went unrevisited, which is how a false green forms
without anyone writing one on purpose.

The three previously-identified open gaps (Typst alias table, two
translation-text mismatches, 13 unported upstream unit tests / empty
`spec/`) were re-checked against `4dc877f` directly rather than assumed
still current: `grep -n "Copied" lib/window.rb` and `grep -n "Privacy
policy" lib/contribution_dialog.rb` both still show the same unfixed text,
`find spec -type f` still returns only `spec_helper.rb` and `README.md`, and
re-running `nix develop --command xvfb-run -a ruby test/drive_window.rb`
reproduces 61/61, DRIVE OK — the same number, not a rubber-stamped repeat.
None of the four open gaps (three carried over, one new) has been closed.

## Verdict (updated this pass — supersedes the paragraph above)

No construction from the skill's hit list ("dropped deliberately",
"intentionally omitted", "not applicable", "out of scope", "by design",
"simplified", "the bindings do not support it", "upstream does this too") was
found anywhere in `lib/`, `exe/`, or `.reports/` describing a skipped port
obligation, this pass included. But this pass also found something the hit
list has no row for: **36 translations that read as confirmed and are not**
— the headline finding above. That is not excuse language; it is an
artifact that passes every mechanical check this skill and
`translation-parity.md` run, and it is the more serious failure mode,
because a reader has no sentence to notice and discount. `clean: true` is
not warranted. Open gaps this round, read from source rather than carried
over: the fabricated "Copied" translations (36 languages, new headline
finding), the "Copied" msgid rewording underneath them (carried over), the
Typst alias table (carried over, 37% coverage), the About dialog's dropped
`Profile:` debug line and renamed attachment filename (new,
`component-identification.md`), two dropped `accessible-role` attributes
(new, `component-parity.md`), and the `Application#build` reactivation
guard (new, `component-identification.md`). Three previously-open gaps are
confirmed closed this pass: the 13 unported unit tests, the Devel-profile
upload suppression, and the unmarked privacy-policy label.
