import WidgetKit
import SwiftUI

@main
struct QuranVerseWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuranVerseWidget()
    }
}

struct QuranVerseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "QuranVerseDaily", provider: Provider()) { entry in
            VerseView(entry: entry)
        }
        .configurationDisplayName("Verse of the Day")
        .description("A daily verse from the Quran. Click to read it on quran.com.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
