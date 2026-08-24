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
