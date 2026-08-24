import SwiftUI
import WidgetKit

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
            Text(entry.verse.reference)
                .font(.caption.smallCaps().weight(.semibold))
                .foregroundStyle(.secondary)
                .widgetAccentable()

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
        .containerBackground(for: .widget) {
            GlassBackground()
        }
        .widgetURL(entry.verse.widgetLinkURL)
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

// Widgets render off-screen, so blur materials cannot sample the wallpaper and
// collapse to flat colors. This builds the glass look from translucency instead:
// the wallpaper shows through a soft white wash with a lit rim.
private struct GlassBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color.white.opacity(0.18), Color.white.opacity(0.06)]
                    : [Color.white.opacity(0.60), Color.white.opacity(0.30)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            ContainerRelativeShape()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.40 : 0.75),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
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
