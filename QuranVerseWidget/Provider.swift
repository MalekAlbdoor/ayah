import WidgetKit
import Foundation

struct VerseEntry: TimelineEntry {
    let date: Date
    let verse: Verse
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> VerseEntry {
        entry(for: now())
    }

    func getSnapshot(in context: Context, completion: @escaping (VerseEntry) -> Void) {
        completion(entry(for: now()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VerseEntry>) -> Void) {
        let calendar = Calendar.current
        let current = now()
        let today = calendar.startOfDay(for: current)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86400)
        // Two entries so the verse still rolls over at midnight even if the
        // system is late asking for a new timeline.
        let entries = [entry(for: current), entry(for: tomorrow)]
        completion(Timeline(entries: entries, policy: .after(tomorrow)))
    }

    private func now() -> Date {
        #if DEBUG
        // Set from the CLI to preview another day:
        //   defaults write com.malek.quranverse.widget QURAN_DEBUG_DATE 2026-08-24 && killall chronod
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

    private func entry(for date: Date) -> VerseEntry {
        VerseEntry(date: date, verse: VerseStore.verse(for: date))
    }
}
