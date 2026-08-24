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
                .font(.system(size: isLarge ? 24 : 19, weight: .medium))
                .lineSpacing(isLarge ? 8 : 5)
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
            Rectangle().fill(.regularMaterial)
        }
        .widgetURL(entry.verse.widgetLinkURL)
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
