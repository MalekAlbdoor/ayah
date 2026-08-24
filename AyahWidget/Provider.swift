import WidgetKit
import Foundation
import os

struct VerseEntry: TimelineEntry {
    let date: Date
    let verse: Verse
    let mode: DisplayMode
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> VerseEntry {
        entry(for: now(), mode: .both, interval: .daily)
    }

    func snapshot(for configuration: AyahConfigIntent, in context: Context) async -> VerseEntry {
        entry(for: now(), mode: configuration.mode, interval: configuration.interval)
    }

    func timeline(for configuration: AyahConfigIntent, in context: Context) async -> Timeline<VerseEntry> {
        let current = now()
        let next = VerseStore.nextChange(after: current, every: configuration.interval)
        #if DEBUG
        Logger(subsystem: "com.malek.ayah.widget", category: "provider")
            .info("timeline family=\(String(describing: context.family), privacy: .public) size=\(String(describing: context.displaySize), privacy: .public) mode=\(configuration.mode.rawValue, privacy: .public) interval=\(configuration.interval.rawValue, privacy: .public)")
        #endif
        // Two entries so the verse still rolls over on time even if the
        // system is late asking for a new timeline.
        let entries = [
            entry(for: current, mode: configuration.mode, interval: configuration.interval),
            entry(for: next, mode: configuration.mode, interval: configuration.interval),
        ]
        return Timeline(entries: entries, policy: .after(next))
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

    private func entry(for date: Date, mode: DisplayMode, interval: RefreshInterval) -> VerseEntry {
        VerseEntry(date: date, verse: VerseStore.verse(for: date, every: interval), mode: mode)
    }
}
