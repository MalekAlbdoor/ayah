# Ayah

A Quran verse on your Mac desktop, refreshed on your schedule. Click it to open that verse on quran.com.

Built for macOS 26 with the Liquid Glass design language. Small, medium, and large sizes, in Arabic, English, or both.

![Ayah widget in three sizes on a macOS desktop](docs/hero.png)

## Install

```sh
brew install --cask malekalbdoor/tap/ayah
```

Then right-click your desktop, choose **Edit Widgets**, search for **Ayah**, and drag **Verse of the Day** where you want it.

Prefer not to use Homebrew? Download the zip from [Releases](https://github.com/MalekAlbdoor/ayah/releases/latest), move `Ayah.app` to `/Applications`, then run this once so macOS will open it:

```sh
xattr -r -d com.apple.quarantine /Applications/Ayah.app
```

### What you are trusting

Ayah is not notarized by Apple. Notarizing requires a paid Apple Developer membership, and this is a free app. macOS attaches a quarantine flag to anything downloaded and refuses to open un-notarized quarantined apps, so that flag has to be cleared once. The cask does it for you during install and prints a note saying so, which is why the Homebrew install is a single command. (Homebrew used to offer `--no-quarantine` for this, but [removed it in Homebrew 6 with no replacement](https://github.com/Homebrew/brew/issues/20755).)

Clearing a security check on your behalf is not something to wave through, so here is exactly what you are trusting:

- **Every line of source is in this repository**, and the app is built from it with `xcodebuild`. Nothing is minified or obfuscated.
- **It cannot reach the network.** Neither the app nor the widget requests the network entitlement, so the sandbox denies outbound connections at the OS level, not by promise. All 365 verses are bundled offline in `AyahWidget/Verses.json`.
- **Both targets are sandboxed** (`com.apple.security.app-sandbox`), so they cannot read your files or your other apps' data.
- **It collects nothing.** There is no analytics, no telemetry, and no account.
- The only thing it opens is a `quran.com` link in your default browser, when you click the widget.

If you would rather not rely on any of that, [build it from source](#building-from-source). Quarantine never applies to something you compiled yourself.

## Options

Right-click the widget and choose **Edit Widget**:

- **Arabic text** and **English translation**: two toggles. Both on shows both, or turn one off for a single language. Arabic only uses a larger mushaf script with more lines; English only switches to a serif treatment at a larger size.
- **New verse**: every hour, every 6 hours, every day, or every 3 days. Hour-based intervals change on wall-clock boundaries, so 6:00, 12:00, 18:00, and midnight.
- **Background**: Liquid Glass, System (follows light and dark mode), or one of White, Sand, Ocean, Forest, Plum, Midnight, and Charcoal.

There is a refresh button in the corner of the widget to jump to another verse immediately.

## How it works

- 365 curated verses rotate deterministically by date, so every Mac shows the same verse on the same day, and the whole year passes before one repeats. The order is a fixed shuffle rather than mushaf order, so consecutive days do not all come from the same surah.
- The verse changes at local midnight, or on the interval you choose.
- Widgets on macOS can only launch their containing app, so `Ayah.app` is a background agent. It receives `ayah://` URLs from the widget, opens the matching quran.com link, and quits. Opening the app directly shows a window explaining how to add the widget.
- On the desktop, macOS composites every widget over its own Liquid Glass platter that samples your wallpaper. The Liquid Glass background paints nothing on top of it, so the wallpaper shows through. The other backgrounds paint over that platter as solid cards.

## Building from source

Requires macOS 26, Xcode 26, and [XcodeGen](https://github.com/yonaskolb/XcodeGen). The `.xcodeproj` is generated rather than committed.

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project Ayah.xcodeproj -scheme Ayah -configuration Debug build
```

Install and register the widget:

```sh
cp -R "$(xcodebuild -project Ayah.xcodeproj -scheme Ayah -showBuildSettings \
  | awk '/BUILT_PRODUCTS_DIR/{print $3}')/Ayah.app" /Applications/
open /Applications/Ayah.app
```

After rebuilding, re-copy the app and run `killall chronod` to make the widget reload. If the gallery shows a stale entry, also `killall NotificationCenter`.

## Tests

```sh
xcodebuild -project Ayah.xcodeproj -scheme Ayah test
```

Covers selection determinism, midnight rollover, the shuffled reading order and its no-repeat guarantee, configuration mapping, and the integrity of `Verses.json`.

## Credits

- Arabic text: the Uthmani script edition from [alquran.cloud](https://alquran.cloud).
- English translation: Saheeh International, from the same source.
- Typeface: [KFGQPC Uthmanic Script HAFS](https://fonts.qurancomplex.gov.sa) from the King Fahd Glorious Quran Printing Complex, the same Madinah Mushaf face quran.com uses. It is bundled unmodified and registered at runtime through CTFontManager.

See [NOTICE](NOTICE) for the full third-party terms. The ayah-end medallion is drawn by the font itself, which encloses a trailing run of Arabic-Indic digits in the ornamental circle.

## License

[MIT](LICENSE) for the source code. The bundled Quranic text, translation, and font remain under their own terms, described in [NOTICE](NOTICE).

---

## Developer notes

### Why the widget options are toggles rather than a single dropdown

Configuration parameters deliberately use only primitive types. `AppEnum` parameters are decoded by fetching type metadata from `linkd`, and on macOS 26 linkd rejects processes whose code signature carries no Team ID, logging `Rejecting invalid client due to requiresValidatedBundle` and `Unable to get teamId`. This project is ad-hoc signed, so enum parameters silently decode to their defaults while `Bool` and `String` parameters arrive intact. `String` parameters backed by a `DynamicOptionsProvider` still present a proper dropdown, which is how **New verse** and **Background** work. If the project is ever signed with a real Apple Development certificate, `AppEnum` parameters would work again.

### Regenerating verse data

Edit `Scripts/verse_refs.txt`, one `surah:ayah` or `surah:start-end` per line, then:

```sh
Scripts/fetch_verses.sh
```

Re-run once and commit the updated `Verses.json`.

### Previewing another day

Debug builds honor a date override:

```sh
defaults write com.malek.ayah.widget QURAN_DEBUG_DATE 2026-08-25 && killall chronod
```

The widget extension is sandboxed, so if the override does not take effect, write into its container instead:

```sh
defaults write ~/Library/Containers/com.malek.ayah.widget/Data/Library/Preferences/com.malek.ayah.widget \
  QURAN_DEBUG_DATE 2026-08-25 && killall chronod
```

Remove it with `defaults delete` on the same domain.

### Debugging delivered configuration

Debug builds append every provider call, with the raw and resolved configuration values, to:

```
~/Library/Containers/com.malek.ayah.widget/Data/Library/Application Support/trace.log
```

The configuration itself is stored by Notification Center in its preferences under `widgets.instances`, as a keyed archive holding length-prefixed serialized parameters. After changing it, `killall NotificationCenter chronod` pushes the new value through to the extension.
