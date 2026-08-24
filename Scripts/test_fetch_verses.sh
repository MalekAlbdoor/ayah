#!/bin/zsh
# Runs fetch_verses.sh against a three-line refs file and checks the shape of
# the JSON it produces. Hits the live API, so it needs a network connection.
set -euo pipefail
cd "$(dirname "$0")"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/refs.txt" <<'REFS'
# short, no metadata
112:1-4
# short, with metadata
2:286 | mercy | closing du'a of al-Baqarah
# long enough to exceed tier 0
24:35 | light | the Verse of Light
REFS

REFS_FILE="$WORK/refs.txt" OUT_FILE="$WORK/out.json" ./fetch_verses.sh

fail() { echo "FAIL: $1" >&2; exit 1 }

[[ $(jq -r '.version' "$WORK/out.json") == 2 ]] || fail "version is not 2"
[[ $(jq '.verses | length' "$WORK/out.json") == 3 ]] || fail "expected 3 verses"
[[ $(jq -r '.verses[0].tier' "$WORK/out.json") == 0 ]] || fail "112:1-4 should be tier 0"
[[ $(jq -r '.verses[0] | has("theme")' "$WORK/out.json") == false ]] || fail "absent theme should be omitted"
[[ $(jq -r '.verses[1].theme' "$WORK/out.json") == "mercy" ]] || fail "theme not parsed"
[[ $(jq -r '.verses[1].source' "$WORK/out.json") == "closing du'a of al-Baqarah" ]] || fail "source not parsed"
[[ $(jq -r '.verses[2].tier' "$WORK/out.json") -gt 0 ]] || fail "24:35 should exceed tier 0"

echo "PASS"
