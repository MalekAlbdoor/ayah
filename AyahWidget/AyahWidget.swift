import WidgetKit
import SwiftUI

@main
struct AyahWidgetBundle: WidgetBundle {
    var body: some Widget {
        AyahWidget()
    }
}

struct AyahWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "AyahDaily",
            intent: AyahConfigIntent.self,
            provider: Provider()
        ) { entry in
            VerseView(entry: entry)
        }
        .configurationDisplayName("Verse of the Day")
        .description("A daily verse from the Quran. Click to read it on quran.com.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
