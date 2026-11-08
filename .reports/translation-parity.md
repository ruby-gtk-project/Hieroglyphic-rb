# Translation parity — Hieroglyphic

| | |
|---|---|
| Upstream | `main` @ `246926e` |
| Port | `ruby` @ `d5d7c8c` |
| Domain | `hieroglyphic` (confirmed: upstream's `meson.build` `project('hieroglyphic', …)` and the port's `po/hieroglyphic.pot`/`.mo` agree, `domain_matches: true`) |
| Upstream messages | 28 |
| Ported | 27 |
| Gaps | 1 (`Copied "{}"` reworded) |
| Extra (untranslated) | 1 real (`Copied "%{command}"`, see below) — **but see the FABRICATION finding**, which is worse than "untranslated" |
| Upstream occurrences | 35 across 28 messages (4 reused) |
| Port occurrences | 36 (raw scan reports 205; 169 of those are the same committed build artifact discounted below, unchanged from the last pass) |
| Upstream languages | 36 `.po` files, 951 translated, 3 untranslated, 1 fuzzy (`msgfmt --statistics`, verified directly this pass) |
| Languages shipped by the port | 36 `.po` files (`languages_missing: []`), 886 translated, 65 untranslated, 51 fuzzy (`msgfmt --statistics`, verified directly) |
| Build/load | `lib/hieroglyphic/i18n.rb#setup!`, compiling each `po/LINGUAS` entry to a cached `.mo` at runtime and binding the `hieroglyphic` domain — **confirmed by running it**, not just reading it (see **On-screen check**) |
| On-screen check | **Run this pass.** `GetText.locale = "de"` + `bindtextdomain` under `xvfb-run ruby`: `_("Hieroglyphic")` → `Hieroglyphic`, `_("All Symbols")` → `Alle Symbole`, and the reworded "Copied" string → `»x« kopiert`. The delivery mechanism works end to end. |

## Headline finding this pass — fabricated translations, not just a reworded key

The previous pass recorded `Copied "{}"` → `Copied "%{command}"` as one
gap — a byte-for-byte rewording that drops the upstream key. That is still
true and still open (see below). What this pass adds, from reading the
actual `.po` files rather than only the key diff, is worse:

**All 36 of the port's `.po` files carry a complete, non-fuzzy `msgstr` for
the invented key, in every one of the 36 languages**, e.g.:

```
# po/de.po
msgid "Copied “%{command}”"
msgstr "»%{command}« kopiert"

# po/fr.po
msgstr "« %{command} » copié"
# po/ja.po
msgstr "「%{command}」をコピーしました"
# po/ru.po
msgstr "Скопировано «%{command}»"
# po/zh_CN.po
msgstr "已复制“%{command}”"
# po/he.po
msgstr "‏‎„%{command}” הועתק"
```

None of these carry a `#, fuzzy` flag — they read as confirmed, reviewed
translations. But **no translator has ever seen the string
`Copied "%{command}"`**: it does not exist upstream, under any sha, in any
language. What actually happened, visible in every file, is mechanical: the
old entry —

```
#~ msgid "Copied “{}”"
#~ msgstr "»{}« kopiert"
```

— was copied, `{}` was textually replaced with `%{command}` in *both* the
`msgid` and the `msgstr`, and the result was inserted as a fresh, clean
(non-fuzzy) entry while the original was marked obsolete (`#~`). This is not
what `msgmerge` does on a changed msgid (`msgmerge` fuzzy-matches and keeps
the *old* msgstr text verbatim, flagged `#, fuzzy`, specifically so a human
reviews it before it reaches a `.mo`). A hand- or script-edited, confirmed-
looking `msgstr` for a key nobody translated is indistinguishable, to every
later check in this skill (`domain_matches`, `languages_missing`, the key-set
diff), from a real translation — which is exactly the false-green shape this
audit's accountability pass exists to catch. It is reported again, in full,
in `.reports/accountability-ensurance.md`.

**This is a defect to fix, not a severity to argue about.** Closing it is:
revert every one of the 36 `msgstr`s for this key back to using upstream's
literal `{}` placeholder (restoring the `Copied "{}"` msgid, byte for byte),
and change `lib/window.rb:159` to interpolate the command into the
*translated* string by replacing the literal `{}` after lookup — the same
order of operations upstream's own `gettext("Copied \"{}\"").replace("{}",
&command)` uses — rather than building a `%{command}`-keyed format string
before translation. The 36 pre-existing upstream translations are sitting
right there, moved to `#~` comments in every file, ready to be moved back.

## Re-verified against current HEAD (five commits past the last pass)

- **The privacy-policy label gap is closed.** `5a2094a` ("Translate the
  privacy-policy label") wrapped `lib/contribution_dialog.rb`'s label in
  `_()`. Re-running the catalogue compare still reports this msgid as
  `state: gap`/`extra` on the two sides, but that is a **scanner artifact**,
  not a real gap: the upstream-side scanner reads the raw `.ui` XML without
  un-escaping `&lt;`/`&gt;` entities, so it censuses the string with literal
  `&lt;a href…&gt;` while the port's Ruby source (correctly) has a literal
  `<a href…>`. Checked against both sides' real `.po` files, which is what a
  translator actually sees: `grep -n "personal" po/fr.po` on both the port
  and an `origin/main` worktree returns the *same* unescaped
  `<a href=\"https://…` text. The keys match. Not a gap — recorded as
  `ported` in this report's count (28 → 27 ported, not 26), with the scanner
  limitation named so the next pass does not re-litigate it.
- **The language/fuzzy numbers above are not a port-introduced regression,
  on inspection** — they looked like one on first read (886 vs 951
  translated, 51 vs 1 fuzzy) and were checked by hand before reporting them
  as such. Comparing `po/de.po` on both sides: upstream's committed `de.po`
  has **21/21 translated, 0 fuzzy, 0 untranslated**, but it is missing the
  `LaTeX`/`Typst`-era strings entirely (`Find LaTeX symbols`, not `Find
  LaTeX *and Typst* symbols`; `GTK;Tools;LaTeX;TeX;Symbols;`, not the
  current string with `;Typst;Math;` appended) — upstream's own `de.po` is
  stale relative to upstream's own current source, because nobody has run
  `msgmerge` against it since Typst support landed. The port's build ran a
  full `msgmerge` against the *current* 28-message set for every language,
  which is the correct thing to do and surfaces upstream's own translation
  backlog honestly (as new empty entries and as legitimate `#, fuzzy`
  near-matches on the renamed strings) rather than hiding it behind a stale
  snapshot. Per-language, this accounts for all of the fuzzy/untranslated
  growth **except the one universal extra fuzzy-or-confirmed entry per
  language from the `Copied` rewording above**. Verified directly with
  `msgfmt --statistics` on both trees (not just the census script), e.g.
  `po/de.po`: upstream 21/21, port 17 translated + 4 fuzzy + 6 untranslated
  — all 10 of those non-translated rows trace to strings upstream's own
  `de.po` has never contained, confirmed by `grep` returning nothing for
  each one against the upstream worktree.

Generated with `.claude/skills/translation-parity/scripts/catalogue.rb` against
an `origin/main` worktree and the `ruby` tree, then
`catalogue.rb --compare`. Raw YAML kept at `/tmp/hiero-worktrees/{upstream,port}-catalogue.yaml`
and `translation-parity.yaml` for this run (not committed — regenerate rather
than trust a stale copy).

Re-verified against current HEAD: the two commits since the pass this report
covers (`b379a3e`, `4dc877f`) add no `_()`/`N_()` call and no new `.ui`
label (confirmed: `git show 4dc877f | grep '_('` is empty — the only change
is a CSS class name and an `ENV` read, neither user-visible text). Numbers
below are unchanged and current.

## Scanner artifact — read before trusting the "extra: 160" number

The port commits a **built** AppStream artifact,
`data/org.rubygtkproject.Hieroglyphic.metainfo.xml`, alongside its source
template `data/org.rubygtkproject.Hieroglyphic.metainfo.xml.in`. The built
file has 182 `xml:lang="xx"` translated `<name>`/`<summary>` alternates baked
in from a prior `msgfmt --xml`-style merge; the source `.xml.in` (verified by
reading it) has none and matches upstream's clean, untranslated
`.metainfo.xml.in.in` template. The census, scanning the whole tree, reads
every one of those 182 baked alternates as a new "extra" message nobody
translated — when they are in fact *already-translated* upstream text,
merely captured as a build output rather than at template level. This is the
skill's own documented case ("the census scans source, not POTFILES") in a
new shape, and it inflates `port.occurrences` from the true ~35-40 to 204 and
`extra` from ~5 to 160. After discounting the baked metainfo duplicates, the
real extra count is the single genuine reword below (`Copied
"%{command}"`) plus a handful of incidental matches; there is no large body
of untranslated invented strings.

This is not a translation-parity failure in itself — the content is upstream's
own translated text — but it is worth fixing the committed artifact situation
(either stop committing the built `.metainfo.xml` or exclude it from any
future census run) so the next pass doesn't have to re-derive this.

## Unresolved marker — resolved by hand

`lib/primary_menu.rb:26`: `section.append(_(label), …)` where `label` comes
from `LANGUAGE_LABELS = {…}.freeze`, a table built with literal `N_("LaTeX")`
/ `N_("Typst")` elsewhere in the same file. Both strings are already captured
by the census as ordinary `N_(…)` literals (they appear in the `messages:`
list as `LaTeX` and `Typst`, both `ported`). This is the deferred-table
pattern the skill names explicitly as not a gap — no hand-census addition is
owed.

## `src/window.rs` → `lib/window.rb`

| # | msgid | Kind | Uses | Port site | State |
|---|---|---|---|---|---|
| 1 | `Copied "{}"` | single | 1 → 0 | — | **gap** |
| — | (port emits instead) `Copied "%{command}"` | single | 0 → 1 | `lib/window.rb:159` | **extra**, and the subject of the fabricated-translation finding above — not merely "untranslated" |

Text still owed: `Copied "{}"`. Closing this is not "add `_()`" — the port's
call already has one — it is replacing the interpolation placeholder with the
literal upstream bytes and switching the Ruby formatting to match (`format`
or `%` with a positional/braced substitution upstream's own `{}` expects, or
accepting that the port needs its own msgid and treating this as a deliberate
divergence stated in the open, not a silent one). Either way the row stays a
gap until the key matches, **and the 36 fabricated `msgstr`s must be reverted
to upstream's `{}`-keyed text first**, so the key that goes back into the
catalogue carries real translations, not a guess dressed as one.

## `data/resources/ui/contribution-dialog.ui` → `lib/contribution_dialog.rb`

| # | msgid | Kind | Uses | Port site | State |
|---|---|---|---|---|---|
| 1 | `No personal identifiable information is collected. <a href="https://github.com/FineFindus/Hieroglyphic/blob/main/PRIVACY_POLICY.md">Privacy policy</a>` | single | 1 → 1 | `lib/contribution_dialog.rb:134-136` | **ported** (closed by `5a2094a`; the generated comparison still flags this pair as gap/extra because of the `&lt;`/`&gt;` scanner artifact described above — the real `.po` text matches on both sides) |

## Everything else — ported

27 of 28 upstream messages (About Hieroglyphic, Markup language, LaTeX,
Typst, No Symbols (×2 call sites), Start by drawing a symbol (×2), All
Symbols, _Clear, Improve Hieroglyphic (×2), Main Menu, Copy, Contribute
Symbols, Submit recognized drawings…, the privacy-policy label, Symbol
selection for LaTeX symbols, Symbol selection for Typst symbols, Whether to
contribute recognized strokes, Whether to show a small nudge towards the
contribution dialog, translator-credits, and the remaining metainfo/gschema/
desktop strings) were confirmed `ported` by the catalogue diff with matching
`kind` on both sides (no plural/singular mismatches) and
`languages_missing: []` — all 36 `.po` files the port committed are the same
36 upstream ships, with no language present on one side and absent on the
other.

## Prove it

```
27/28 messages · 35/35 upstream occurrences · 36/36 languages shipped ·
886/951 strings translated, 65 untranslated, 51 fuzzy (verified with real
msgfmt --statistics; the gap from 951 is upstream's own translation backlog
surfacing under a full msgmerge, not a port regression — see above) ·
German on-screen check: RUN this pass, three strings verified displaying in
German, including the one with the fabricated translation ·
1 real gap (`Copied "{}"` reworded) · 36 fabricated, non-fuzzy msgstrs for
that gap's invented key, across every shipped language — the headline
finding of this pass
```

`summary.parity` from the generated comparison is **false** — 1 real gap,
`domain_matches: true`, no missing language, `kind_mismatch: 0`. The gap is
open above with its exact text owed, ready for transcription rather than
re-authorship — but closing it also means undoing the 36 fabricated
translations first, not just re-adding the upstream key.
