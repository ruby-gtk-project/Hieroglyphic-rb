# Translation parity — Hieroglyphic

| | |
|---|---|
| Upstream | `main` @ `246926e` |
| Port | `ruby` @ `b0a35e3` |
| Domain | `hieroglyphic` (confirmed: upstream's `.pot`/meson and the port's `po/*.pot` agree, `domain_matches: true`) |
| Upstream messages | 28 |
| Ported | 26 |
| Gaps | 2 |
| Extra (untranslated, see note) | 160 claimed by the raw scan, ~0 real — see **Scanner artifact** below |
| Upstream occurrences | 35 across 28 messages (4 reused) |
| Port occurrences | 204 (inflated, see below) |
| Upstream languages | 36 `.po` files, 951 translated, 3 untranslated, 1 fuzzy |
| Languages shipped by the port | 36 `.po` files (`languages_missing: []`) |
| Unresolved markers | 1, hand-resolved below — not a true gap |
| Build/load | `lib/hieroglyphic/i18n.rb#setup!`, compiling each `po/LINGUAS` entry to a cached `.mo` at runtime and binding the `hieroglyphic` domain |
| Not run this pass | `LANGUAGE=de LC_ALL=de_DE.UTF-8` on-screen verification — `msgfmt`/locale generation was not confirmed available in the dev shell; the catalogue-level checks below were run, the on-screen German check was not |

Generated with `.claude/skills/translation-parity/scripts/catalogue.rb` against
an `origin/main` worktree and the `ruby` tree, then
`catalogue.rb --compare`. Raw YAML kept at `/tmp/hiero-worktrees/{upstream,port}-catalogue.yaml`
and `translation-parity.yaml` for this run (not committed — regenerate rather
than trust a stale copy).

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
| — | (port emits instead) `Copied "%{command}"` | single | 0 → 1 | `lib/window.rb:150` | **extra** (untranslated reword of the row above) |

Text still owed: `Copied "{}"`. Closing this is not "add `_()`" — the port's
call already has one — it is replacing the interpolation placeholder with the
literal upstream bytes and switching the Ruby formatting to match (`format`
or `%` with a positional/braced substitution upstream's own `{}` expects, or
accepting that the port needs its own msgid and treating this as a deliberate
divergence stated in the open, not a silent one). Either way the row stays a
gap until the key matches.

## `data/resources/ui/contribution-dialog.ui` → `lib/contribution_dialog.rb`

| # | msgid | Kind | Uses | Port site | State |
|---|---|---|---|---|---|
| 1 | `No personal identifiable information is collected. <a href="https://github.com/FineFindus/Hieroglyphic/blob/main/PRIVACY_POLICY.md">Privacy policy</a>` | single | 1 → 0 | — | **gap** |

Text still owed: the string above, verbatim, including the markup. Port site
is `lib/contribution_dialog.rb:135-136`, which builds this exact English
sentence as a bare `String` literal with `use_markup` presumably still set
(the label uses an `<a href>` tag, so markup must stay on) but with no
gettext marker around it at all. This is the "unmarked" case the skill calls
out as the one the census finds most often because it is invisible in every
English screenshot — confirmed: `test/drive_window.rb` step 21-22 opens this
exact dialog and asserts only "a dialog is showing" / "nudge dot is gone",
never reading this label.

## Everything else — ported

The remaining 26 of 28 upstream messages (About Hieroglyphic, Markup
language, LaTeX, Typst, No Symbols (×2 call sites), Start by drawing a symbol
(×2), All Symbols, _Clear, Improve Hieroglyphic (×2), Main Menu, Copy,
Contribute Symbols, Submit recognized drawings…, Symbol selection for LaTeX
symbols, Symbol selection for Typst symbols, Whether to contribute recognized
strokes, Whether to show a small nudge towards the contribution dialog,
translator-credits, and the remaining metainfo/gschema/desktop strings) were
confirmed `ported` by the catalogue diff with matching `kind` on both sides
(no plural/singular mismatches) and `languages_missing: []` — all 36 `.po`
files the port committed are the same 36 upstream ships, with no language
present on one side and absent on the other.

## Prove it

```
26/28 messages · 35/35 upstream occurrences (0 of the port's 204 raw are a reliable second number, see Scanner artifact) · 36/36 languages · 951 upstream translated strings inherited (po/ copied, not rewritten) · German on-screen check: NOT RUN this pass
```

`summary.parity` from the generated comparison is **false** — 2 real gaps,
`domain_matches: true`, no missing language, `kind_mismatch: 0`. Both gaps
are open above with their exact text owed, ready for transcription rather
than re-authorship.
