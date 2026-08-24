#!/bin/zsh
# Fetches Uthmani Arabic + Saheeh International English for every reference in
# verse_refs.txt and writes AyahWidget/Verses.json. Run once, commit the JSON.
set -euo pipefail
cd "$(dirname "$0")"

OUT="../AyahWidget/Verses.json"
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

echo '{"version":1,"verses":[' > "$TMP"
first=1

while IFS= read -r ref; do
  [[ -z "$ref" || "$ref" == \#* ]] && continue
  surah=${ref%%:*}
  ayahs=${ref##*:}
  start=${ayahs%%-*}
  end=${ayahs##*-}

  arabic=""
  english=""
  name=""
  for ((a = start; a <= end; a++)); do
    resp=$(curl -fsS "https://api.alquran.cloud/v1/ayah/${surah}:${a}/editions/quran-uthmani,en.sahih")
    code=$(jq -r '.code' <<<"$resp")
    if [[ "$code" != "200" ]]; then
      echo "API error for ${surah}:${a} (code $code)" >&2
      exit 1
    fi
    ar=$(jq -r '.data[] | select(.edition.identifier == "quran-uthmani") | .text' <<<"$resp")
    en=$(jq -r '.data[] | select(.edition.identifier == "en.sahih") | .text' <<<"$resp")
    name=$(jq -r '.data[0].surah.englishName' <<<"$resp")
    if [[ -z "$ar" || -z "$en" ]]; then
      echo "Empty text for ${surah}:${a}" >&2
      exit 1
    fi
    # End-of-ayah medallion: the KFGQPC HAFS font encloses a bare run of
    # Arabic-Indic digits in the ornamental circle on its own; adding U+06DD
    # produces a second, empty circle, so only the digits are appended.
    hindi=$(jq -rn --arg n "$a" '$n | split("") | map({"0":"٠","1":"١","2":"٢","3":"٣","4":"٤","5":"٥","6":"٦","7":"٧","8":"٨","9":"٩"}[.]) | join("")')
    arabic+="${arabic:+ }${ar} ${hindi}"
    english+="${english:+ }${en}"
    sleep 0.3
  done

  obj=$(jq -n \
    --argjson surah "$surah" --argjson s "$start" --argjson e "$end" \
    --arg name "$name" --arg ar "$arabic" --arg en "$english" \
    '{surah: $surah, ayahStart: $s, ayahEnd: $e, surahName: $name, arabic: $ar, english: $en}')
  [[ $first == 1 ]] || echo ',' >> "$TMP"
  first=0
  printf '%s' "$obj" >> "$TMP"
  echo "OK ${ref} (${name})" >&2
done < verse_refs.txt

echo ']}' >> "$TMP"
jq . "$TMP" > "$OUT"
echo "Wrote $(jq '.verses | length' "$OUT") verses to $OUT"
