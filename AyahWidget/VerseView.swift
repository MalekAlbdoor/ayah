import SwiftUI
import WidgetKit
import AppIntents

struct VerseView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    let entry: VerseEntry

    private var isLarge: Bool { family == .systemLarge }

    private var showsArabic: Bool { entry.mode != .englishOnly }

    // In both-languages mode, long verses hide the English on medium so the
    // Arabic stays readable instead of both texts shrinking or truncating.
    private var showsEnglish: Bool {
        switch entry.mode {
        case .arabicOnly: return false
        case .englishOnly: return true
        case .both:
            return isLarge || entry.verse.arabic.count + entry.verse.english.count <= 260
        }
    }

    private var arabicSize: CGFloat {
        if entry.mode == .arabicOnly {
            return isLarge ? 28 : 19
        }
        return isLarge ? 24 : 17
    }

    private var arabicLineLimit: Int {
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
                    .widgetAccentable()

                Spacer(minLength: 8)

                Button(intent: NextVerseIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .widgetAccentable()
            }

            Spacer(minLength: 0)

            if showsArabic {
                Text(entry.verse.arabic)
                    .font(QuranFont.arabic(size: arabicSize))
                    .lineSpacing(isLarge ? 2 : 0)
                    .lineLimit(arabicLineLimit)
                    .minimumScaleFactor(isLarge ? 0.55 : 0.8)
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
                    .minimumScaleFactor(entry.mode == .englishOnly ? 0.7 : 0.9)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                if entry.mode == .englishOnly {
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(12)
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
            return isLarge ? 12 : 5
        }
        return isLarge ? 4 : 3
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
        Color.clear
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
