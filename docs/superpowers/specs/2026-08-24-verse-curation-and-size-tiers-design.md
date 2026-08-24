# Meaningful verse curation with size-aware pools

Date: 2026-08-24
Status: approved, not yet implemented

## Problem

Two defects, one cause.

The curated set sometimes lands on a verse that does not stand on its own:
a line of dialogue inside a narrative, or a sentence whose subject was
introduced an ayah earlier. Read cold on a desktop at 9am, it means little.

The cause is the widget. `Tests/VerseSelectionTests.swift` caps Arabic at 500
characters because the small family shrinks to a 0.5 scale factor and
`AyahWidget/VerseView.swift:157` deliberately refuses to truncate scripture.
Every entry has had to survive the smallest layout, so widening a verse to the
point where its thought closes was rarely affordable. The measured result: a
median Arabic length of 115 characters, with 270 of 365 entries under 150.

Selection is also size-blind. A large widget has room for a passage several
times longer than the small one and is shown the same short verse.

## Goals

- Every entry reads correctly with nothing before or after it.
- Selection is grounded in recognized compilations, not in the author's taste.
- Larger widgets draw on longer passages that a small widget could never show.
- Small-widget legibility improves rather than regresses.

## Non-goals

- Renaming or restyling anything in the widget UI.
- Changing the refresh intervals, the display-mode toggles, or the backgrounds.
- Translating or re-sourcing the Arabic and English text. `alquran.cloud`
  remains the source, Saheeh International remains the translation.

## Selection policy

Every candidate is checked against three rules, in order. Failing any one drops
the candidate or sends it back to be widened.

**1. Self-contained.** The entry reads correctly in isolation. It fails if its
grammatical subject is a pronoun introduced in an earlier ayah, if it is a line
of dialogue inside a narrative, or if it answers a question posed before it.
The remedy is to widen the range until the thought closes; if widening cannot
close it, the entry is dropped.

**2. Sourced.** Each entry records a basis in a recognized compilation or an
established devotional selection. This is a field in the refs file, not a
private note. An entry that cannot cite one does not ship.

**3. Themed.** Each entry carries exactly one theme tag. Tags exist so the
balance can be audited mechanically rather than by impression.

Target balance, roughly 70/30: the majority drawn from mercy, hope, patience,
reliance, du'a, gratitude, and character; a real but smaller presence of
accountability, the hereafter, and warning. The intent is a set that
encourages on most days without editing the Qur'an down to a comfort feed.

Explicitly excluded: narrative fragments, and ruling-specific legal verses
lifted out of the context that qualifies them.

## Data model

### `Scripts/verse_refs.txt`

Becomes pipe-delimited. Field one keeps its current syntax, so every existing
line remains valid and the migration is additive.

```
31:12-19 | gratitude | Luqman's counsel, standard thematic selection
2:155-157 | patience | al-Baqarah, the patience passage
```

Fields: reference, theme, source. Comments and blank lines behave as they do
today.

### `AyahWidget/Verses.json`

Version goes from 1 to 2. Each verse object gains:

- `tier`: 0 short, 1 medium, 2 long
- `theme`: the tag from the refs file
- `source`: the citation from the refs file

`tier` is computed by `Scripts/fetch_verses.sh` from the fetched text, never
written by hand. Deriving it from measured length is what keeps it honest: a
hand-set tier can drift from what actually fits, a computed one cannot.

The reader in `VerseStore.load()` must tolerate a missing `tier` by treating
the entry as tier 0, so a stale bundled JSON degrades to small-only rather
than crashing.

## Tier calibration

Measured 2026-08-24, not estimated. Rather than eyeballing widgets on a desktop,
the real Uthmani font was laid out with CoreText at each family's actual font
size, line limit, box dimensions, and padding, and the largest scale that still
fits was solved for. That is what SwiftUI's `minimumScaleFactor` settles on, so
it answers the question directly and repeatably.

Legibility is judged by **rendered point size**, not by relative scale, because
the three families start from different base sizes (15pt small, 17pt medium,
24pt large). A 0.8 scale means 12pt on small but 19pt on large.

**Arabic caps**, the length at which each family still draws at roughly 14pt:

| Tier | Smallest family showing it | Cap | Renders at |
|---|---|---|---|
| 0 | small (15pt, 6 lines) | 250 | 14.2pt |
| 1 | medium (17pt, 4 lines) | 400 | 15.3pt |
| 2 | large (24pt, 9 lines) | 700 | 16.8pt |

A tier 2 verse on a large widget is therefore *more* legible than a tier 0 verse
on a small one. The ladder trades length for room, not for readability.

**English caps** come from english-only mode, the one place a long translation
can be neither dropped nor hidden. Medium's cap is no larger than small's
because it uses a bigger font over fewer lines:

| Tier | Cap | Bound by |
|---|---|---|
| 0 | 300 | english-only on medium |
| 1 | 300 | english-only on medium |
| 2 | 550 | english-only on large |

A verse takes the lowest tier whose caps *both* texts clear. Applied to the
existing 365 this yields 352 / 5 / 8 across tiers 0 / 1 / 2, rejects nothing,
and moves only five verses up on English length alone.

### The long-verse decision, resolved

The demotion is accepted. On a small widget 2:255 renders at 10.0pt and 2:286 at
10.5pt; both read far better at medium or large, and the 250 cap lets the small
pool carry verses that render at 14pt or more. No exemption list is added.

### A defect found during calibration

Large drew both texts unconditionally, which truncated the English on 17 of the
365 curated verses, contradicting the rule that scripture is never cut
mid-sentence. Medium already hid a long English rather than shrinking it; large
now does the same, at a threshold of 390 (`arabic.count + english.count`)
measured as the point past which one of the two texts truncates. Without this,
tier 2 could not work at all: a 700-scalar passage carries roughly 800 scalars
of English, and both cannot fit a 364x382 box at any readable size.

The visibility rule moved from `VerseView` onto `Verse.showsEnglish(sizeClass:mode:)`
so it can be tested without a widget host.

## Selection

`WidgetFamily` maps to a maximum tier:

| Family | Max tier | Draws from |
|---|---|---|
| `systemSmall` | 0 | short |
| `systemMedium` | 1 | short + medium |
| `systemLarge` | 2 | short + medium + long |

Pools nest, so a large widget still shows short verses; it simply has more to
choose from. `VerseStore.verse(for:)` gains a family parameter, filters to that
pool, and runs the existing seeded Fisher-Yates shuffle over it.

Each tier uses a distinct seed. With a shared seed the three pools would
advance in step and a small and a large widget on the same desktop would show
correlated verses; distinct seeds decorrelate them.

`Provider.swift:26` already reads `context.family`, so this threads an existing
value through rather than adding plumbing.

### Consequences, accepted

Two widgets of different sizes on the same desktop show different verses on the
same day. This was weighed against the alternative of one verse per day
rendered at different extents, and the pooled model was chosen deliberately for
the content freedom it buys on the large family.

Each pool cycles at its own natural length rather than being padded to 365. A
pool of 240 repeats every 240 days. The no-repeat guarantee holds within each
pool: any run of `poolCount` consecutive periods shows every verse in that pool
exactly once.

## Tests

`Tests/VerseSelectionTests.swift` moves from single-list assertions to per-pool
ones:

- Each pool's reading order is a permutation of that pool.
- Any run of `poolCount` consecutive periods is repeat-free, per pool.
- Pools nest: every tier-0 entry appears in the medium and large pools.
- Every entry's Arabic and English are within its tier's caps.
- References are unique across the whole list.
- A verse object with no `tier` decodes as tier 0.

Two further assertions land in phase 2, not phase 1, because phase 1 changes no
content and the existing 365 entries carry no tags yet:

- Every entry has a non-empty theme and source.
- The 70/30 balance holds within a stated tolerance, computed from theme tags.

Accordingly `theme` and `source` are optional in the version 2 schema. Phase 2
makes them mandatory once every entry has them.

The existing `verses.count == 365` assertion is replaced by a per-pool minimum,
since the total is now expected to exceed 365.

## Documentation

`README.md:49` claims every Mac shows the same verse on the same day. It
becomes: every Mac shows the same verse on the same day **for a given widget
size**, and larger widgets draw on longer passages.

The Options section gains a note that widget size affects verse length.

## Rollout

**Phase 1, mechanical.** Schema, tier computation, per-pool selection, tests,
README. The existing 365 verses are auto-tiered by the script with no content
change. This ships working size-aware selection and is reviewable on its own.
Because today's set is overwhelmingly short, nearly all of it lands in tier 0
and the medium and large pools start out barely distinguishable from small.
That is expected: phase 1 builds the mechanism, phase 2 fills it.

One consequence of phase 1 needs a decision before it ships. Auto-tiering at a
200-character tier-0 cap demotes today's longest entries out of the small pool,
including 2:255 (Ayat al-Kursi, 431 characters), 2:286 (421), and 24:35 (456).
Small-widget users would stop seeing them. Options: accept it, since those
verses are precisely the ones that render badly at a 0.5 scale factor; raise the
tier-0 cap enough to retain them at the cost of legibility elsewhere; or grant a
named exemption list that stays in tier 0 regardless of length. This is resolved
during calibration, when the rendering evidence is in hand.

**Phase 2, content.** Audit the 365 against the selection policy, widen or drop
the fragments, then add the long-tier passages that only become possible once
the mechanism exists. Every add and drop is reviewed verse by verse before it
ships.

Phase 1 is safe to ship alone. Phase 2 changes what users read and does not
ship without that review.
