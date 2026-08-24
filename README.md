# QuranVerse

A macOS desktop widget that shows one Quran verse per day and opens that verse on quran.com when clicked. Built for macOS 26 with the Liquid Glass design language.

## How it works

- A curated list of 105 well-known verses rotates deterministically by local date. The verse changes at midnight and the cycle repeats.
- Verse text (Uthmani Arabic + Saheeh International English) is bundled offline in `QuranVerseWidget/Verses.json`. The widget makes no network calls; neither target has a network entitlement.
- Widgets on macOS can only launch their containing app, so the app (`QuranVerse.app`) is an invisible `LSUIElement` agent: it receives `quranverse://` URLs from the widget, opens the matching `https://quran.com/{surah}/{ayah}` link in your default browser, and quits.
- Liquid Glass: the widget provides a frosted `.regularMaterial` container background. When the desktop widget style is set to clear or tinted, the system replaces it with real glass and the view adapts through the accented rendering mode.

## Building

Requires Xcode 26 and [XcodeGen](https://github.com/yonaskolb/XcodeGen). The `.xcodeproj` is generated, not committed.

```sh
xcodegen generate
xcodebuild -project QuranVerse.xcodeproj -scheme QuranVerse -configuration Debug build
```

Install and register:

```sh
cp -R <BUILT_PRODUCTS_DIR>/QuranVerse.app /Applications/
open /Applications/QuranVerse.app
pluginkit -m -v -p com.apple.widgetkit-extension | grep quranverse
```

Then right-click the desktop, choose Edit Widgets, and add "Verse of the Day" (medium or large).

After rebuilding, re-copy the app and run `killall chronod` to make the widget reload. If the gallery shows a stale entry, also `killall NotificationCenter`.

## Tests

```sh
xcodebuild -project QuranVerse.xcodeproj -scheme QuranVerse test
```

Covers selection determinism, midnight rollover, full-cycle coverage, and Verses.json integrity.

## Previewing another day (Debug builds)

```sh
defaults write com.malek.quranverse.widget QURAN_DEBUG_DATE 2026-08-24 && killall chronod
```

The widget extension is sandboxed, so if the override does not take effect, write into its container instead:

```sh
defaults write ~/Library/Containers/com.malek.quranverse.widget/Data/Library/Preferences/com.malek.quranverse.widget QURAN_DEBUG_DATE 2026-08-24 && killall chronod
```

Remove with `defaults delete` on the same domain.

## Regenerating verse data

Edit `Scripts/verse_refs.txt` (one `surah:ayah` or `surah:start-end` per line), then:

```sh
Scripts/fetch_verses.sh
```

Data comes from [alquran.cloud](https://alquran.cloud) (`quran-uthmani` and `en.sahih` editions). Re-run once and commit the updated `Verses.json`.
