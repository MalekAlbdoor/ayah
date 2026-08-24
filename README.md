# Ayah

A macOS desktop widget that shows one Quran verse per day and opens that verse on quran.com when clicked. Built for macOS 26 with the Liquid Glass design language.

## How it works

- A curated list of 105 well-known verses rotates deterministically by local date. The verse changes at midnight and the cycle repeats.
- Verse text (Uthmani Arabic + Saheeh International English) is bundled offline in `AyahWidget/Verses.json`. The widget makes no network calls; neither target has a network entitlement.
- Widgets on macOS can only launch their containing app, so `Ayah.app` is an invisible `LSUIElement` agent: it receives `ayah://` URLs from the widget, opens the matching `https://quran.com/{surah}/{ayah}` link in your default browser, and quits.
- Liquid Glass: the widget provides a translucent glass container background. When the desktop widget style is set to a tinted mode, the system replaces it with real glass and the view adapts through the accented rendering mode.

## Widget options

Right-click the widget and choose Edit Widget to set **Show**:

- **Arabic and English** (default)
- **Arabic only** - larger mushaf script with more lines
- **English only** - serif treatment at a larger size

## Building

Requires Xcode 26 and [XcodeGen](https://github.com/yonaskolb/XcodeGen). The `.xcodeproj` is generated, not committed.

```sh
xcodegen generate
xcodebuild -project Ayah.xcodeproj -scheme Ayah -configuration Debug build
```

Install and register:

```sh
cp -R <BUILT_PRODUCTS_DIR>/Ayah.app /Applications/
open /Applications/Ayah.app
pluginkit -m -v -p com.apple.widgetkit-extension | grep ayah
```

Then right-click the desktop, choose Edit Widgets, and add "Verse of the Day" under Ayah (medium or large).

After rebuilding, re-copy the app and run `killall chronod` to make the widget reload. If the gallery shows a stale entry, also `killall NotificationCenter`.

## Tests

```sh
xcodebuild -project Ayah.xcodeproj -scheme Ayah test
```

Covers selection determinism, midnight rollover, full-cycle coverage, and Verses.json integrity.

## Previewing another day (Debug builds)

```sh
defaults write com.malek.ayah.widget QURAN_DEBUG_DATE 2026-08-25 && killall chronod
```

The widget extension is sandboxed, so if the override does not take effect, write into its container instead:

```sh
defaults write ~/Library/Containers/com.malek.ayah.widget/Data/Library/Preferences/com.malek.ayah.widget QURAN_DEBUG_DATE 2026-08-25 && killall chronod
```

Remove with `defaults delete` on the same domain.

## Regenerating verse data

Edit `Scripts/verse_refs.txt` (one `surah:ayah` or `surah:start-end` per line), then:

```sh
Scripts/fetch_verses.sh
```

Data comes from [alquran.cloud](https://alquran.cloud) (`quran-uthmani` and `en.sahih` editions). Re-run once and commit the updated `Verses.json`.

## Arabic typography

The widget bundles the KFGQPC Uthmanic Script HAFS font from the King Fahd Quran Printing Complex (`AyahWidget/Fonts/UthmanicHafs.otf`), the same Madinah Mushaf face quran.com uses. It is registered at runtime via CTFontManager, no plist keys needed. The ayah-end medallion comes from the font itself: it encloses a trailing run of Arabic-Indic digits in the ornamental circle (do not prepend U+06DD with this font version; that draws an extra empty circle). The app icon is that medallion glyph, drawn programmatically on a midnight blue gradient.
