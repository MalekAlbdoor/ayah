import SwiftUI
import WidgetKit

struct VerseView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    let entry: VerseEntry

    private var isLarge: Bool { family == .systemLarge }

    var body: some View {
        VStack(alignment: .leading, spacing: isLarge ? 10 : 6) {
            Text(entry.verse.reference)
                .font(.caption.smallCaps().weight(.semibold))
                .foregroundStyle(.secondary)
                .widgetAccentable()

            Spacer(minLength: 0)

            Text(entry.verse.arabic)
                .font(QuranFont.arabic(size: isLarge ? 25 : 20))
                .lineSpacing(isLarge ? 4 : 2)
                .lineLimit(isLarge ? 6 : 3)
                .minimumScaleFactor(0.85)
                .truncationMode(.tail)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 2)

            Spacer(minLength: 0)

            Text(entry.verse.english)
                .font(isLarge ? .callout : .footnote)
                .foregroundStyle(renderingMode == .accented ? .primary : .secondary)
                .lineLimit(isLarge ? 4 : 2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
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
