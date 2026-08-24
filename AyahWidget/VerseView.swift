import SwiftUI
import WidgetKit
import AppIntents

struct VerseView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    let entry: VerseEntry

    private var isLarge: Bool { family == .systemLarge }
    private var isSmall: Bool { family == .systemSmall }

    private var showsArabic: Bool { entry.mode != .englishOnly }

    // The rule lives on Verse so it can be tested without a widget host.
    private var showsEnglish: Bool {
        entry.verse.showsEnglish(sizeClass: VerseSizeClass(family: family), mode: entry.mode)
    }

    // VoiceOver otherwise spells Arabic out letter by letter in the reader's
    // own locale; tagging the run makes it speak as Arabic.
    private var arabicText: AttributedString {
        var text = AttributedString(entry.verse.arabic)
        text.languageIdentifier = "ar"
        return text
    }

    private var arabicSize: CGFloat {
        if isSmall { return 15 }
        if entry.mode == .arabicOnly {
            return isLarge ? 28 : 19
        }
        return isLarge ? 24 : 17
    }

    private var arabicLineLimit: Int {
        if isSmall { return 6 }
        if entry.mode == .arabicOnly {
            return isLarge ? 10 : 4
        }
        return isLarge ? 9 : (showsEnglish ? 3 : 4)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isLarge ? 8 : 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.verse.reference)
                    .font(.caption.smallCaps().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .widgetAccentable()
                    .accessibilityLabel(entry.verse.spokenReference)

                Spacer(minLength: 8)

                Button(intent: NextVerseIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .widgetAccentable()
                .accessibilityLabel("Show another verse")
            }

            Spacer(minLength: 0)

            if showsArabic {
                Text(arabicText)
                    .font(QuranFont.arabic(size: arabicSize))
                    .lineSpacing(isLarge ? 2 : 0)
                    .lineLimit(arabicLineLimit)
                    .minimumScaleFactor(isSmall ? 0.5 : (isLarge ? 0.55 : 0.8))
                    .truncationMode(.tail)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .layoutPriority(2)

                Spacer(minLength: 0)
            }

            if showsEnglish {
                Text(entry.verse.english)
                    .font(englishFont)
                    .foregroundStyle(englishStyle)
                    .lineLimit(englishLineLimit)
                    .minimumScaleFactor(englishScaleFactor)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                if entry.mode == .englishOnly {
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(isSmall ? 10 : 12)
        .environment(\.colorScheme, contentColorScheme)
        .containerBackground(for: .widget) {
            if let colors = entry.background.gradientColors {
                ColorBackground(colors: colors)
            } else if entry.background == .system {
                SystemBackground()
            } else {
                GlassBackground()
            }
        }
        .widgetURL(entry.verse.widgetLinkURL)
    }

    // Fixed-color backgrounds pin the text's scheme so it stays readable in
    // either system appearance. In the accented (tinted) desktop style the
    // system strips the background and tints content itself, so inherit.
    @Environment(\.colorScheme) private var systemColorScheme
    private var contentColorScheme: ColorScheme {
        guard renderingMode == .fullColor, let forced = entry.background.forcedColorScheme else {
            return systemColorScheme
        }
        return forced
    }

    private var englishFont: Font {
        if entry.mode == .englishOnly {
            if isSmall { return .system(.footnote, design: .serif) }
            return .system(isLarge ? .title2 : .body, design: .serif)
        }
        return isLarge ? .callout : .footnote
    }

    private var englishStyle: some ShapeStyle {
        if entry.mode == .englishOnly {
            return AnyShapeStyle(.primary)
        }
        return AnyShapeStyle(renderingMode == .accented ? .primary : .secondary)
    }

    private var englishLineLimit: Int {
        if entry.mode == .englishOnly {
            if isSmall { return 11 }
            // 18 rather than 12 on large: the box has the height for it, and
            // the line limit was what stopped a long passage's translation from
            // fitting. Measured 2026-08-24 at 15.3pt, where 800 scalars needs
            // 18 lines. Below that the English cap bound tier 2 to roughly 487
            // Arabic scalars, barely above tier 1, making the long tier moot.
            return isLarge ? 18 : 5
        }
        return isLarge ? 4 : 3
    }

    // Small has the least room, so let the translation shrink further before
    // truncating: cutting scripture mid-sentence is worse than smaller type.
    private var englishScaleFactor: CGFloat {
        guard entry.mode == .englishOnly else { return 0.9 }
        return isSmall ? 0.55 : 0.7
    }
}

// Solid color choice: a soft diagonal gradient with the same lit rim as the
// glass look so every background reads as part of one family.
private struct ColorBackground: View {
    let colors: [Color]

    var body: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            ContainerRelativeShape()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }
}

// On the desktop the system already composites widgets over a frosted-glass
// backdrop that samples the wallpaper (white frost in light mode, dark frost
// in dark mode). Real liquid glass is therefore mostly staying out of the
// way: only a whisper of wash and a lit rim on top of the system's frost.
// Anything heavier reads as a flat card.
// The macOS 26 desktop composites every widget on a Liquid Glass platter that
// samples the wallpaper. Any paint layered on top of it congeals into a flat
// card (the dimmed-desktop look everyone wants IS the platter with the custom
// background removed), so real glass means drawing nothing at all.
private struct GlassBackground: View {
    var body: some View {
        // Test: nearly clear but non-empty, to check whether the dark platter
        // fill is a system fallback for empty backgrounds.
        Color.white.opacity(0.01)
    }
}

// Follows the system appearance: a white card in light mode, charcoal in dark.
private struct SystemBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ColorBackground(
            colors: (colorScheme == .dark ? WidgetBackground.charcoal : WidgetBackground.white).gradientColors!
        )
    }
}

#Preview("Medium", as: .systemMedium) {
    AyahWidget()
} timeline: {
    VerseEntry(date: .now, verse: VerseStore.fallback, mode: .both)
}

#Preview("Large", as: .systemLarge) {
    AyahWidget()
} timeline: {
    VerseEntry(date: .now, verse: VerseStore.fallback, mode: .both)
}
