import SwiftUI
import WidgetKit

struct VerseView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    let entry: VerseEntry

    private var isLarge: Bool { family == .systemLarge }

    // On medium, very long verses hide the English so the Arabic can wrap
    // and scale to fit instead of truncating.
    private var showsEnglish: Bool {
        isLarge || entry.verse.arabic.count <= 140
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isLarge ? 8 : 4) {
            Text(entry.verse.reference)
                .font(.caption.smallCaps().weight(.semibold))
                .foregroundStyle(.secondary)
                .widgetAccentable()

            Spacer(minLength: 0)

            Text(entry.verse.arabic)
                .font(QuranFont.arabic(size: isLarge ? 24 : 17))
                .lineSpacing(isLarge ? 2 : 0)
                .lineLimit(isLarge ? 9 : (showsEnglish ? 3 : 4))
                .minimumScaleFactor(isLarge ? 0.55 : 0.6)
                .truncationMode(.tail)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .layoutPriority(2)

            Spacer(minLength: 0)

            if showsEnglish {
                Text(entry.verse.english)
                    .font(isLarge ? .callout : .footnote)
                    .foregroundStyle(renderingMode == .accented ? .primary : .secondary)
                    .lineLimit(isLarge ? 4 : 2)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)
            }
        }
        .containerBackground(for: .widget) {
            GlassBackground()
        }
        .widgetURL(entry.verse.widgetLinkURL)
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
    QuranVerseWidget()
} timeline: {
    VerseEntry(date: .now, verse: VerseStore.fallback)
}

#Preview("Large", as: .systemLarge) {
    QuranVerseWidget()
} timeline: {
    VerseEntry(date: .now, verse: VerseStore.fallback)
}
