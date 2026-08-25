# Self-containment triage

Every entry flagged by `Scripts/audit_verses.py` was read against one question:
read cold, with nothing before or after it, does this say something complete?
Not "is this a good verse", which is a different question.

Of 98 flagged entries, 86 were false positives. An opening "And" is ordinary in
Quranic translation, a named prophet supplies its own subject, and a du'a is
self-contained by nature. The 12 below are the real dependencies.

Decisions made by Claude on 2026-08-24 under instruction to use its own
judgment. Every one is reversible: revert the commit and the previous
`verse_refs.txt` comes back.

## Dropped

| Reference | Reason |
|---|---|
| 12:92 | "No blame will there be upon you today" is Yusuf forgiving his brothers. Both the speaker and the addressee live outside the verse, and no widening short of the whole reunion fixes it. |
| 71:10-11 | Opens "And said," with the verb dangling. Nuh is nowhere in the text. Widening forward keeps the dangling opener because the subject sits behind it. |
| 68:52 | "But it is not except a reminder to the worlds." The "it" is the Qur'an, established two ayat earlier, and 68:51 is about the disbelievers' gaze rather than anything that would complete the thought. |

## Widened

| Was | Now | Reason |
|---|---|---|
| 20:44 | 20:43-44 | "Speak to him with gentle speech" gives no clue who "him" is. 20:43 names Pharaoh, and the pair is the whole instruction. |
| 20:46 | 20:45-46 | "I am with you both" needs the two who feared, named in 20:45. |
| 51:17-18 | 51:15-18 | "They used to sleep but little of the night" describes the righteous, introduced in 51:15. |
| 91:9-10 | 91:7-10 | "He has succeeded who purifies it" leaves "it", the soul, undefined until 91:7 supplies it. |
| 109:6 | 109:1-6 | The closing line of al-Kafirun read alone is a bare disclaimer. The surah is short enough to carry whole. |
| 25:63 | 25:63-65 | The description of the servants of the Most Merciful is one unit; a single ayah stops mid-portrait. |
| 31:13 | 31:13-15 | Luqman's counsel to his son is one address. Note the full 31:12-19 is 1229 scalars and exceeds every cap, so 13-15 is the largest coherent slice that fits. |

## Merged

| Was | Now | Reason |
|---|---|---|
| 26:78-79 and 26:80 | 26:78-80 | Two entries split one sentence of Ibrahim's speech. "And when I am ill, it is He who cures me" was stranded from the clauses it parallels. |
| 21:87 and 21:88 | 21:87-88 | "So We responded to him and saved him" refers to the man of the fish, named only in the preceding entry. |

## Kept despite flags, worth noting

These were close calls, kept because the meaning lands without the story:

- **12:53**, **12:86**, **19:4**, **28:24**, **27:19**: each opens inside a
  narrative, but each is a famous du'a or reflection that carries itself.
- **3:147**, **3:173**: the surrounding battle is not needed to read the du'a.
- **76:8-9**: "they" is the righteous, and the verse describes them well enough
  that the antecedent adds nothing.
