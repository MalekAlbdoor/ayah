#!/usr/bin/env python3
"""Propose a theme for every verse from its translation.

Ordered rules, first match wins. This is a triage aid, not exegesis: the point
is that the balance between consoling and sobering material can be audited at
all, which an untagged set makes impossible.
"""
import json, re, sys, collections

RULES = [
    # Supplication first: a du'a is recognisable by its address, whatever it asks for.
    ("dua",            r'"?(Our Lord|My Lord)[,"]|O Allah|I seek refuge|grant (me|us)'),
    # Sobering material, before the softer words inside the same verses catch it.
    ("warning",        r"\b(Fire|Hell|Hellfire|torment|punishment|doom|wrath|blazing)\b"),
    ("hereafter",      r"\b(Day of (Resurrection|Judgement)|Hereafter|Paradise|Gardens? beneath|eternal)\b"),
    # Taqwa and return-to-Allah verses are sobering material even when the
    # wording is gentle; leaving them in the catch-all understated the balance.
    ("accountability", r"\b(recompens\w*|account|weigh\w*|every soul|what it has earned|will be shown"
                       r"|fear Allah|conscious of Allah|returned to (Allah|Him)|brought back"
                       r"|answerable|reckoning|witness over)\b"),
    # Then the consoling and instructive material.
    ("tawhid",         r"(\bno deity except|\bworship (Him|Me|Allah)|\bExalted is|\bassociate (anything|others)"
                       r"|\bHe is Allah|\bLord of the worlds|\bkeys of the unseen|\bnone knows"
                       r"|\bHe perceives|\bthe Subtle|\bHearing and (Knowing|Seeing)"
                       r"|\bin His hand|\bto Him belongs)"),
    ("patience",       r"\b(patien\w+|persever\w+|endure)\b"),
    ("reliance",       r"\b(rely upon|reliance|Sufficient for|Disposer of affairs|put .{0,12}trust|protector)\b"),
    ("gratitude",      r"\b(grateful|gratitude|thankful|thanks|favor of Allah)\b"),
    ("mercy",          r"\b(forgiv\w+|mercy|merciful|pardon\w*|repent\w*)\b"),
    ("hope",           r"\b(despair|ease|relief|good tidings|glad tidings|hardship|comfort)\b"),
    ("knowledge",      r"\b(knowledge|reflect|understanding|those of reason|ponder|taught|learn)\b"),
    ("justice",        r"\b(justice|justly|witness\w*|oppress\w*|wrong(ed|ing|doers)?|full measure|balance)\b"),
    ("character",      r"\b(speak|speech|parents|orphan|needy|humility|humble|kind|backbit|suspicion|ridicule|modest|trust)\b"),
]

def theme_for(english):
    for name, pat in RULES:
        if re.search(pat, english, re.I):
            return name
    return "character"

verses = json.load(open(sys.argv[1]))["verses"]
out = {}
for v in verses:
    ref = f'{v["surah"]}:{v["ayahStart"]}'
    if v["ayahEnd"] != v["ayahStart"]:
        ref += f'-{v["ayahEnd"]}'
    out[ref] = theme_for(v["english"])
counts = collections.Counter(out.values())
sober = sum(counts[k] for k in ("accountability", "hereafter", "warning"))
print("theme distribution:")
for k, n in counts.most_common():
    print(f"  {k:<16} {n}")
print(f"\nsober share: {sober}/{len(out)} = {100*sober/len(out):.0f}%  (target 15-45%)")
json.dump(out, open(sys.argv[2], "w"), indent=0)
