# Verse Curation Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace ad-hoc verse selection with a sourced, themed set where every entry reads correctly on its own, and fill the medium and long tiers that phase 1 built but left empty.

**Architecture:** `Scripts/verse_refs.txt` is the source of truth; everything else is generated from it. A mechanical audit narrows 365 entries down to the ones that plausibly fail the self-containment rule, so human review is spent only where judgment is actually needed. Widening a fragment to where its thought closes is a data edit, and the tier is recomputed from the result.

**Tech Stack:** zsh + curl + jq for the fetch and audit scripts, Python for the report generator, Swift/XCTest for the invariants.

**Spec:** `docs/superpowers/specs/2026-08-24-verse-curation-and-size-tiers-design.md` (Selection policy section)

**Depends on:** phase 1, `docs/superpowers/plans/2026-08-24-verse-size-tiers.md`, complete on branch `verse-size-tiers`.

## Global Constraints

- Requires macOS 26 and Xcode 26. Run `xcodegen generate` before building; the `.xcodeproj` is not committed.
- Arabic is `quran-uthmani`, English is `en.sahih`, both from `api.alquran.cloud`. Do not change sources or hand-edit the text in `Verses.json`.
- Lengths are Unicode scalars on both sides: `${#var}` in zsh, `unicodeScalars.count` in Swift. Never `String.count` for a cap.
- Tier caps after Task 1: Arabic 250 / 400 / 700, English 300 / 300 / 800.
- The three rules from the spec, in order: **self-contained**, **sourced**, **themed**. An entry failing any one is widened or dropped, never waved through.
- Target balance roughly 70/30: mercy, hope, patience, reliance, du'a, gratitude, and character outweighing accountability, the hereafter, and warning.
- **Every add and every drop is reviewed by Malek before it ships.** No batch is applied on the agent's own judgment.
- No em dashes in any user-facing copy or documentation.
- Commits are authored as Malek Albdoor <malekalbdoor10@gmail.com> with no AI co-author trailer.

## The blocker this plan opens with

Phase 1 set the tier 2 Arabic cap at 700, but the English cap of 550 binds first. Real verses run about 1.13 English scalars per Arabic scalar, so a 550 English cap corresponds to roughly 487 Arabic. That is barely above tier 1's 400, and it would make tier 2 pointless. Task 1 fixes it. Do not start the curation tasks before it lands.

---

### Task 1: Open up english-only mode on large

Measured cause: english-only on large is capped by `englishLineLimit`'s value of 12, not by the box. At 15.3pt an 800-scalar translation needs 18 lines and the height still fits. Raising the limit lets the English cap rise to 800, which pairs correctly with a 700-scalar Arabic passage.

**Files:**
- Modify: `AyahWidget/VerseView.swift:150-156` (`englishLineLimit`), `Scripts/fetch_verses.sh` (the `ENGLISH_CAPS` array)
- Test: `Tests/VerseSelectionTests.swift`

**Interfaces:**
- Consumes: `VerseTier`, `VerseSizeClass`, `Verse.showsEnglish(sizeClass:mode:)` from phase 1.
- Produces: `ENGLISH_CAPS=(300 300 800)`; no new Swift symbols.

- [ ] **Step 1: Write the failing test**

The cap lives in a shell array, so the test that proves the change has to run
the script. A Swift test asserting a hardcoded number would pass before the fix
as well as after, which is no test at all.

Add to `Scripts/test_fetch_verses.sh`, inside the heredoc that builds the
sample refs file:

```
# a genuinely long passage: al-Hujurat on mockery and suspicion.
# Measured: 638 Arabic scalars, 680 English. It clears the 700 Arabic cap but
# breaks the old 550 English one, which is exactly what makes it the test case.
49:11-12 | character | hujurat-akhlaq
```

And add these assertions after the existing ones:

```zsh
[[ $(jq '.verses | length' "$WORK/out.json") == 4 ]] || fail "expected 4 verses"
[[ $(jq -r '.verses[3].tier' "$WORK/out.json") == 2 ]] || fail "49:11-12 should be tier 2"
[[ $(jq -r '.verses[3].english | length' "$WORK/out.json") -gt 550 ]] \
    || fail "49:11-12 should exceed the old English cap, or it proves nothing"
```

Update the existing `expected 3 verses` assertion to 4.

- [ ] **Step 2: Run it to verify it fails**

```bash
Scripts/test_fetch_verses.sh
```

Expected: FAIL. The script exits non-zero with `49:11-12 does not fit any tier`,
because the passage's English runs well past the 550 cap. That rejection is
exactly the blocker this task removes.

- [ ] **Step 3: Raise the line limit**

In `AyahWidget/VerseView.swift`, `englishLineLimit` currently reads:

```swift
    private var englishLineLimit: Int {
        if entry.mode == .englishOnly {
            if isSmall { return 11 }
            return isLarge ? 12 : 5
        }
        return isLarge ? 4 : 3
    }
```

Change the english-only large case from 12 to 18:

```swift
    private var englishLineLimit: Int {
        if entry.mode == .englishOnly {
            if isSmall { return 11 }
            // 18 rather than 12: the large box has the height for it, and the
            // line limit was what stopped a long translation from fitting.
            // Measured 2026-08-24 at 15.3pt, where 800 scalars needs 18 lines.
            return isLarge ? 18 : 5
        }
        return isLarge ? 4 : 3
    }
```

- [ ] **Step 4: Raise the cap in the fetch script**

In `Scripts/fetch_verses.sh`, change `ENGLISH_CAPS=(300 300 550)` to `ENGLISH_CAPS=(300 300 800)` and update the comment above it to record that the long-tier English cap is set by the 18-line english-only large layout, measured 2026-08-24.

- [ ] **Step 5: Run tests to verify they pass**

```bash
xcodebuild -project Ayah.xcodeproj -scheme Ayah test
```

Expected: PASS, all tests. No verse in the current set is tier 2 with English over 550, so raising the cap changes no existing tier.

- [ ] **Step 6: Commit**

```bash
git add AyahWidget/VerseView.swift Scripts/fetch_verses.sh Tests/VerseSelectionTests.swift
git commit -m "Let english-only mode on large hold a full long passage

The 12-line limit, not the box, was capping the translation at 550
scalars, which would have bound tier 2 to roughly 487 Arabic scalars and
made the long tier pointless."
```

---

### Task 2: Build the audit inventory

Reviewing 365 verses one by one is the wrong use of anyone's time. This produces a report that mechanically narrows the field to entries that plausibly fail the self-containment rule, so review goes only where judgment is needed.

**Files:**
- Create: `Scripts/audit_verses.py`, `docs/verse-audit.md` (generated, committed for review)
- Test: `Scripts/test_audit_verses.sh` (create)

**Interfaces:**
- Consumes: `AyahWidget/Verses.json` (version 2, with `tier`).
- Produces: `docs/verse-audit.md`, a table of every entry with its reference, Arabic and English scalar counts, tier, and a `flags` column drawn from the heuristics below.

- [ ] **Step 1: Write the failing test**

Create `Scripts/test_audit_verses.sh`:

```zsh
#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
OUT=$(mktemp -d); trap 'rm -rf "$OUT"' EXIT
python3 audit_verses.py --json ../AyahWidget/Verses.json --out "$OUT/audit.md"
fail() { echo "FAIL: $1" >&2; exit 1 }
grep -q "^| Reference" "$OUT/audit.md" || fail "no table header"
[[ $(grep -c '^| [0-9]' "$OUT/audit.md") -ge 365 ]] || fail "not every verse listed"
# 2:255 stands alone and opens with the divine name: it must not be flagged.
grep -E '^\| 2:255 ' "$OUT/audit.md" | grep -q 'none' || fail "2:255 should carry no flags"
# 12:101 is Yusuf's du'a inside a narrative; it must be flagged for review.
grep -E '^\| 12:101 ' "$OUT/audit.md" | grep -qv 'none' || fail "12:101 should be flagged"
echo "PASS"
```

Then `chmod +x Scripts/test_audit_verses.sh`.

- [ ] **Step 2: Run it to verify it fails**

```bash
Scripts/test_audit_verses.sh
```

Expected: FAIL, `audit_verses.py` does not exist.

- [ ] **Step 3: Write the audit script**

Create `Scripts/audit_verses.py`. The heuristics are deliberately crude and tuned to over-flag: a false flag costs one line of review, a missed fragment ships.

```python
#!/usr/bin/env python3
"""Inventory every curated verse and flag the ones that may not stand alone.

The flags are hints for human review, not verdicts. They over-flag on purpose:
a wrong flag costs a line of reading, a missed fragment ships to every desktop.
"""
import argparse, json, re

# Surahs that are largely continuous narrative. A single ayah lifted out of one
# is far more likely to depend on what came before it.
NARRATIVE_SURAHS = {7, 11, 12, 18, 19, 20, 21, 26, 27, 28, 37, 38, 54, 71}

# English openings that point at something introduced earlier.
BACKREF = re.compile(
    r"^(And |But |So |Then |Thus |That |They |He |She |It |Those |Such |Therein |"
    r"Indeed, he |Indeed, they |Indeed, it )", re.I)

def flags_for(v):
    out = []
    if v["surah"] in NARRATIVE_SURAHS and v["ayahStart"] > 10:
        out.append("narrative-surah")
    if BACKREF.match(v["english"].strip()):
        out.append("opens-with-backreference")
    if '"' in v["english"] or "said" in v["english"].lower():
        out.append("reported-speech")
    if v["ayahStart"] == v["ayahEnd"] and len(v["arabic"]) < 60:
        out.append("very-short")
    return out or ["none"]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    verses = json.load(open(a.json))["verses"]
    rows, counts = [], {}
    for v in verses:
        f = flags_for(v)
        for x in f:
            counts[x] = counts.get(x, 0) + 1
        ref = f'{v["surah"]}:{v["ayahStart"]}'
        if v["ayahEnd"] != v["ayahStart"]:
            ref += f'-{v["ayahEnd"]}'
        rows.append((ref, v, f))
    with open(a.out, "w") as fh:
        fh.write("# Verse audit\n\nGenerated by `Scripts/audit_verses.py`. ")
        fh.write("Flags are review hints, not verdicts.\n\n")
        fh.write("## Flag counts\n\n")
        for k in sorted(counts, key=lambda k: -counts[k]):
            fh.write(f"- `{k}`: {counts[k]}\n")
        fh.write("\n## Entries\n\n")
        fh.write("| Reference | Surah | Ar | En | Tier | Flags | English |\n")
        fh.write("|---|---|---|---|---|---|---|\n")
        for ref, v, f in rows:
            eng = v["english"].replace("|", "\\|")
            fh.write(f'| {ref} | {v["surahName"]} | {len(v["arabic"])} | '
                     f'{len(v["english"])} | {v["tier"]} | {",".join(f)} | {eng} |\n')
    print(f"wrote {a.out}: {len(rows)} entries, "
          f"{sum(c for k, c in counts.items() if k != 'none')} flags")

if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
Scripts/test_audit_verses.sh
```

Expected: `PASS`. If 2:255 or 12:101 land on the wrong side, adjust the heuristics rather than the assertions: those two are the calibration points.

- [ ] **Step 5: Generate the committed report**

```bash
python3 Scripts/audit_verses.py --json AyahWidget/Verses.json --out docs/verse-audit.md
head -20 docs/verse-audit.md
```

- [ ] **Step 6: Commit**

```bash
git add Scripts/audit_verses.py Scripts/test_audit_verses.sh docs/verse-audit.md
git commit -m "Add a verse audit that flags entries which may not stand alone

Heuristics over-flag on purpose: a wrong flag costs a line of review, a
missed fragment ships."
```

---

### Task 3: Triage the flagged entries

**Review gate. Nothing here is applied without Malek's approval.**

**Files:**
- Create: `docs/verse-triage.md` (the decision record)

**Interfaces:**
- Consumes: `docs/verse-audit.md` from Task 2.
- Produces: for each flagged entry, one of `keep`, `widen <new range>`, or `drop`, each with a one-line reason.

- [ ] **Step 1: Read every flagged entry against the rule**

For each entry the audit flagged, answer one question: read cold, with nothing before or after it, does this say something complete? Not "is it a good verse", which is a different question and not one to decide here.

- [ ] **Step 2: Classify each into keep, widen, or drop**

- **keep**: the flag was a false positive. Most `very-short` and many `opens-with-backreference` entries will land here; "And Allah is Knowing of all things" needs no antecedent.
- **widen**: the thought closes within a couple of ayat. Record the new range, e.g. `12:101` becomes `12:100-101`. Prefer this over dropping: it is exactly what the tiers were built to afford.
- **drop**: the thought cannot be closed without pulling in half a page, or the entry is a ruling lifted out of its qualifying context.

- [ ] **Step 3: Write the decision record**

Create `docs/verse-triage.md` with a table: reference, decision, new range if widening, and reason. Every flagged entry appears exactly once.

- [ ] **Step 4: Present batches for review**

Present the triage in batches of at most 40 rows. For each batch, show the reference, the current English, the proposed decision, and the reason. Wait for approval on each batch before moving to the next. Record any decision Malek changes, with his reasoning, in the same file.

- [ ] **Step 5: Commit the approved record**

```bash
git add docs/verse-triage.md
git commit -m "Record the self-containment triage decisions"
```

---

### Task 4: Apply the triage

**Files:**
- Modify: `Scripts/verse_refs.txt`, `AyahWidget/Verses.json` (regenerated)
- Test: `Tests/VerseSelectionTests.swift`

**Interfaces:**
- Consumes: `docs/verse-triage.md` from Task 3.
- Produces: an updated refs file; tiers recomputed by the fetch script.

- [ ] **Step 1: Edit the refs file**

Apply every approved decision: widen the ranges, delete the drops. Leave the theme and source fields empty for now; Task 5 fills them.

- [ ] **Step 2: Regenerate**

```bash
Scripts/fetch_verses.sh
jq '[.verses[].tier] | group_by(.) | map({tier: .[0], n: length})' AyahWidget/Verses.json
```

Widening moves entries up a tier. That is the intended trade and the reason phase 1 came first.

- [ ] **Step 3: Check the pools did not collapse**

```bash
jq '[.verses[] | select(.tier == 0)] | length' AyahWidget/Verses.json
```

If the tier 0 pool has fallen below 200, stop and report. Widening pushes verses out of the small pool, and a small widget still needs a healthy set. The remedy is adding short entries in Task 6, not loosening the caps.

- [ ] **Step 4: Run the full suite**

```bash
xcodebuild -project Ayah.xcodeproj -scheme Ayah test
```

Expected: PASS. `testEveryPoolHasEnoughVerses` is the one most likely to catch a problem here.

- [ ] **Step 5: Commit**

```bash
git add Scripts/verse_refs.txt AyahWidget/Verses.json
git commit -m "Widen or drop the verses that did not stand on their own"
```

---

### Task 5: Theme and source every entry

**Files:**
- Create: `docs/verse-sources.md` (the collection registry)
- Modify: `Scripts/verse_refs.txt`

**Interfaces:**
- Consumes: the refs file from Task 4.
- Produces: every line carrying `ref | theme | source`, where `source` is a key defined in `docs/verse-sources.md`.

- [ ] **Step 1: Write the source registry**

Create `docs/verse-sources.md` listing each collection an entry may cite, with a short key, the full name, and a link or citation. Sourcing 365 entries individually is not tractable; sourcing them to a small set of named collections is, and it is what makes the selection defensible rather than personal.

Keys should cover the ground the set actually uses, for example a recognized topical index, a standard du'a collection, and the widely recognized individual passages (Ayat al-Kursi, the closing ayat of al-Baqarah, the opening and closing of al-Kahf). Each key needs a verifiable reference; anything that cannot be pointed at does not become a key.

- [ ] **Step 2: Tag themes**

Assign exactly one theme per entry from a closed vocabulary. Define the vocabulary at the top of `verse_refs.txt` as a comment so it cannot drift. Suggested set: `mercy`, `hope`, `patience`, `reliance`, `dua`, `gratitude`, `character`, `knowledge`, `justice`, `tawhid`, `accountability`, `hereafter`, `warning`.

- [ ] **Step 3: Tag sources**

Give every entry a source key from the registry. An entry that cannot cite one is a signal that it entered the set on taste alone; raise it for a keep-or-drop decision rather than inventing a citation.

- [ ] **Step 4: Present for review in batches**

Batches of at most 60 rows, showing reference, theme, and source. Wait for approval on each.

- [ ] **Step 5: Regenerate and commit**

```bash
Scripts/fetch_verses.sh
jq '[.verses[] | select(.theme == null)] | length' AyahWidget/Verses.json
```

Expected: `0`. Then:

```bash
git add Scripts/verse_refs.txt docs/verse-sources.md AyahWidget/Verses.json
git commit -m "Give every verse a theme and a sourced basis"
```

---

### Task 6: Fill the medium and long tiers

The payoff. Phase 1 built pools that today hold 352 / 5 / 8; this is what makes the larger sizes worth having.

**Files:**
- Modify: `Scripts/verse_refs.txt`, `AyahWidget/Verses.json` (regenerated)

**Interfaces:**
- Consumes: the registry and vocabulary from Task 5.
- Produces: enough tier 1 and tier 2 entries that the medium and large pools are meaningfully larger than the small one.

- [ ] **Step 1: Draft candidate passages**

Calibrate expectations first. A tier 2 entry holds roughly **two to four ayat**, not a page. Measured against the caps:

| Candidate | Arabic | English | Result |
|---|---|---|---|
| 25:63-65, the servants of the Merciful | 274 | 350 | tier 2 |
| 3:190-191, signs for people of reason | 315 | 411 | tier 2 |
| 2:155-157, the patience passage | 333 | 357 | tier 2 |
| 17:23-24, parents | 341 | 375 | tier 2 |
| 31:13-15, Luqman's counsel | 525 | 725 | tier 2 |
| 49:11-12, mockery and suspicion | 638 | 680 | tier 2 |
| 2:285-286, closing ayat of al-Baqarah | 683 | **912** | **rejected** |
| 31:12-19, Luqman's full counsel | **1229** | 1631 | **rejected** |

Two lessons from that table. Passages people think of as a unit are often too long: Luqman's counsel has to be narrowed to 31:13-15, and the closing ayat of al-Baqarah do not fit at all because the English runs to 912 scalars. And English is usually the binding constraint, not Arabic, since it runs about 1.13 scalars per Arabic scalar and more on passages heavy with names.

Each candidate needs a theme and a source key like any other entry.

Measure before proposing, since a rejected passage wastes a review round:

```bash
# Sums a range and reports whether it clears the caps.
ar=""; en=""
for a in $(seq 11 12); do
  r=$(curl -fsS "https://api.alquran.cloud/v1/ayah/49:$a/editions/quran-uthmani,en.sahih")
  ar+=$(jq -r '.data[]|select(.edition.identifier=="quran-uthmani")|.text' <<<"$r")
  en+=$(jq -r '.data[]|select(.edition.identifier=="en.sahih")|.text' <<<"$r")
  sleep 0.2
done
python3 -c "import sys; print(f'arabic={len(sys.argv[1])} english={len(sys.argv[2])} (caps 700 / 800)')" "$ar" "$en"
```

- [ ] **Step 2: Present candidates for review**

Show each candidate's reference, full translation, theme, source, and projected tier. Wait for approval. This is the part of the work most exposed to taste, so nothing goes in unapproved.

- [ ] **Step 3: Add the approved entries and regenerate**

```bash
Scripts/fetch_verses.sh
jq '[.verses[].tier] | group_by(.) | map({tier: .[0], n: length})' AyahWidget/Verses.json
```

- [ ] **Step 4: Confirm the pools now differ meaningfully**

```bash
jq '{small: ([.verses[] | select(.tier <= 0)] | length),
     medium: ([.verses[] | select(.tier <= 1)] | length),
     large: ([.verses[] | select(.tier <= 2)] | length)}' AyahWidget/Verses.json
```

If large exceeds small by fewer than 30 entries, the tiers are still decorative and the task is not done.

- [ ] **Step 5: Commit**

```bash
git add Scripts/verse_refs.txt AyahWidget/Verses.json
git commit -m "Add the longer passages the larger widgets can now carry"
```

---

### Task 7: Make the invariants mandatory

Phase 1 deliberately left `theme` and `source` optional because no entry had them. Now every entry does, so the schema and the tests should enforce it.

**Files:**
- Modify: `AyahWidget/VerseStore.swift` (the `Verse` doc comment), `Tests/VerseSelectionTests.swift`

**Interfaces:**
- Consumes: the fully tagged data from Tasks 5 and 6.
- Produces: no new symbols; `theme` and `source` stay `String?` in Swift so a stale bundled file still decodes, with the requirement enforced by test instead.

- [ ] **Step 1: Write the failing tests**

```swift
    func testEveryVerseIsThemedAndSourced() {
        for verse in verses {
            XCTAssertNotNil(verse.theme, "\(verse.reference) has no theme")
            XCTAssertNotNil(verse.source, "\(verse.reference) has no source")
            XCTAssertFalse(verse.theme?.isEmpty ?? true, "\(verse.reference) has an empty theme")
            XCTAssertFalse(verse.source?.isEmpty ?? true, "\(verse.reference) has an empty source")
        }
    }

    func testThemeVocabularyIsClosed() {
        // A closed vocabulary is what makes the balance check meaningful; a
        // typo would otherwise quietly create a new one-entry theme.
        let allowed: Set<String> = [
            "mercy", "hope", "patience", "reliance", "dua", "gratitude",
            "character", "knowledge", "justice", "tawhid", "accountability",
            "hereafter", "warning",
        ]
        for verse in verses {
            XCTAssertTrue(allowed.contains(verse.theme ?? ""),
                          "\(verse.reference) has an unknown theme: \(verse.theme ?? "nil")")
        }
    }

    func testBalanceIsComfortWeighted() {
        // The spec targets roughly 70/30. Tolerance is wide on purpose: this
        // catches a set that has drifted into a warning feed or a comfort feed,
        // not a set that is a few entries off a round number.
        let sober: Set<String> = ["accountability", "hereafter", "warning"]
        let soberCount = verses.filter { sober.contains($0.theme ?? "") }.count
        let share = Double(soberCount) / Double(verses.count)
        XCTAssertGreaterThan(share, 0.15, "the set has become a comfort feed")
        XCTAssertLessThan(share, 0.45, "the set leans too heavily on warning")
    }
```

- [ ] **Step 2: Run to verify they fail, then pass**

```bash
xcodebuild -project Ayah.xcodeproj -scheme Ayah test
```

They should pass immediately if Tasks 5 and 6 were done properly. If `testBalanceIsComfortWeighted` fails, that is a real finding about the set, not a bad test: report the actual distribution and get a decision before adjusting either the set or the tolerance.

- [ ] **Step 3: Update the schema comment**

In `AyahWidget/VerseStore.swift`, amend the comment above `tierRaw` / `theme` / `source` to record that the fields stay optional in Swift so a stale bundled file still decodes, while the tests require every shipped entry to carry them.

- [ ] **Step 4: Commit**

```bash
git add AyahWidget/VerseStore.swift Tests/VerseSelectionTests.swift
git commit -m "Require a theme and a source on every shipped verse"
```

---

### Task 8: Update the documentation

**Files:**
- Modify: `README.md`, `docs/superpowers/specs/2026-08-24-verse-curation-and-size-tiers-design.md`

- [ ] **Step 1: Describe the selection in the README**

The "How it works" section says verses rotate deterministically but says nothing about how they were chosen. Add that the set is curated to entries that read on their own, that each carries a theme and a sourced basis, and that longer passages exist precisely so a verse is not shown mid-thought.

- [ ] **Step 2: Update the verse count if it changed**

```bash
grep -n "365" README.md
```

`README.md:30` claims all 365 verses are bundled offline. Correct the number if Tasks 4 and 6 changed it.

- [ ] **Step 3: Mark the spec's phase 2 as delivered**

Record the final tier distribution and the count of entries widened, dropped, and added.

- [ ] **Step 4: Verify no em dashes**

```bash
grep -n "—" README.md docs/superpowers/specs/*.md
```

Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add README.md docs/superpowers/specs/2026-08-24-verse-curation-and-size-tiers-design.md
git commit -m "Describe the curated selection in the README"
```

---

## What this plan does not do

It does not seek religious review beyond sourcing. Malek chose to ground the selection in published collections rather than route it past a qualified reviewer, and every entry citing a recognized source is what carries that weight. If the finished set is ever meant to be presented as vetted, that is a separate step and a separate person.
