#!/bin/zsh
# Fetches Uthmani Arabic + Saheeh International English for every reference in
# verse_refs.txt and writes AyahWidget/Verses.json. Run once, commit the JSON.
set -euo pipefail
cd "$(dirname "$0")"

OUT="${OUT_FILE:-../AyahWidget/Verses.json}"
REFS="${REFS_FILE:-verse_refs.txt}"

# Tier caps in Unicode scalars. ${#var} counts scalars in zsh, matching
# unicodeScalars.count in the Swift tests. Swift's String.count counts grapheme
# clusters and would disagree on Uthmani text, which is dense with combining
# marks, so never compare against that.
#
# Arabic and English get separate caps because they are drawn under different
# constraints. Arabic decides placement: it is the one text every size renders.
# The Arabic caps are the length at which each family still draws at roughly
# 14pt, measured by laying the real Uthmani font out in each family's box:
# 15pt/6 lines on small, 17pt/4 on medium, 24pt/9 on large.
#
# The English caps come from english-only mode, the only place a long
# translation cannot be dropped. Medium's is no larger than small's because it
# uses a bigger font over fewer lines. In both-languages mode a long English is
# hidden rather than shrunk, so it does not constrain placement there.
#
# Measured 2026-08-24; see
# docs/superpowers/specs/2026-08-24-verse-curation-and-size-tiers-design.md
ARABIC_CAPS=(250 400 700)
ENGLISH_CAPS=(300 300 550)

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

echo '{"version":2,"verses":[' > "$TMP"
first=1

while IFS= read -r line; do
  [[ -z "$line" || "$line" == \#* ]] && continue
  ref=$(printf '%s' "${line%%|*}" | sed 's/[[:space:]]*$//')
  theme=""
  source_note=""
  if [[ "$line" == *"|"* ]]; then
    rest=${line#*|}
    theme=$(printf '%s' "${rest%%|*}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    if [[ "$rest" == *"|"* ]]; then
      source_note=$(printf '%s' "${rest#*|}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    fi
  fi
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

  # Lowest tier whose caps BOTH texts clear. Rejecting rather than clamping is
  # deliberate: a passage too long for the large widget is a curation mistake,
  # and filing it under tier 2 anyway would ship a verse nobody can read.
  tier=""
  for i in 1 2 3; do
    if [[ ${#arabic} -le ${ARABIC_CAPS[$i]} && ${#english} -le ${ENGLISH_CAPS[$i]} ]]; then
      tier=$((i - 1))
      break
    fi
  done
  if [[ -z "$tier" ]]; then
    echo "${ref} does not fit any tier: arabic=${#arabic} english=${#english} scalars" \
         "(caps ${ARABIC_CAPS[3]} / ${ENGLISH_CAPS[3]}). Shorten the range or drop it." >&2
    exit 1
  fi

  obj=$(jq -n \
    --argjson surah "$surah" --argjson s "$start" --argjson e "$end" \
    --argjson tier "$tier" \
    --arg name "$name" --arg ar "$arabic" --arg en "$english" \
    --arg theme "$theme" --arg source "$source_note" \
    '{surah: $surah, ayahStart: $s, ayahEnd: $e, surahName: $name,
      arabic: $ar, english: $en, tier: $tier}
     + (if $theme == "" then {} else {theme: $theme} end)
     + (if $source == "" then {} else {source: $source} end)')
  [[ $first == 1 ]] || echo ',' >> "$TMP"
  first=0
  printf '%s' "$obj" >> "$TMP"
  echo "OK ${ref} (${name}) tier=${tier}" >&2
done < "$REFS"

echo ']}' >> "$TMP"
jq . "$TMP" > "$OUT"
echo "Wrote $(jq '.verses | length' "$OUT") verses to $OUT"
