import WidgetKit
import Foundation

struct VerseEntry: TimelineEntry {
    let date: Date
    let verse: Verse
    let mode: DisplayMode
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> VerseEntry {
        entry(for: now(), mode: .both)
    }

    func snapshot(for configuration: AyahConfigIntent, in context: Context) async -> VerseEntry {
        entry(for: now(), mode: configuration.mode)
    }

    func timeline(for configuration: AyahConfigIntent, in context: Context) async -> Timeline<VerseEntry> {
        let calendar = Calendar.current
        let current = now()
        let today = calendar.startOfDay(for: current)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86400)
        // Two entries so the verse still rolls over at midnight even if the
        // system is late asking for a new timeline.
        let entries = [
            entry(for: current, mode: configuration.mode),
            entry(for: tomorrow, mode: configuration.mode),
        ]
        return Timeline(entries: entries, policy: .after(tomorrow))
    }

    private func now() -> Date {
        #if DEBUG
        // Set from the CLI to preview another day:
        //   defaults write com.malek.ayah.widget QURAN_DEBUG_DATE 2026-08-25 && killall chronod
        if let override = UserDefaults.standard.string(forKey: "QURAN_DEBUG_DATE") {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: override) {
                return date
            }
        }
        #endif
        return Date()
    }

    private func entry(for date: Date, mode: DisplayMode) -> VerseEntry {
        VerseEntry(date: date, verse: VerseStore.verse(for: date), mode: mode)
    }
}
