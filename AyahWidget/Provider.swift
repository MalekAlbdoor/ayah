import WidgetKit
import Foundation
import os

struct VerseEntry: TimelineEntry {
    let date: Date
    let verse: Verse
    let mode: DisplayMode
    var background: WidgetBackground = .liquidGlass
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> VerseEntry {
        trace("placeholder size=\(context.displaySize)")
        return entry(for: now(), mode: .both, interval: .daily, background: .liquidGlass)
    }

    func snapshot(for configuration: AyahConfigIntent, in context: Context) async -> VerseEntry {
        trace("snapshot arabic=\(configuration.showArabic) english=\(configuration.showEnglish) mode=\(configuration.displayMode.rawValue) interval=\(configuration.interval) -> \(configuration.refreshInterval.rawValue) background=\(configuration.background) -> \(configuration.widgetBackground.rawValue)")
        return entry(for: now(), mode: configuration.displayMode, interval: configuration.refreshInterval, background: configuration.widgetBackground)
    }

    func timeline(for configuration: AyahConfigIntent, in context: Context) async -> Timeline<VerseEntry> {
        let current = now()
        let next = VerseStore.nextChange(after: current, every: configuration.refreshInterval)
        trace("timeline family=\(context.family) size=\(context.displaySize) arabic=\(configuration.showArabic) english=\(configuration.showEnglish) mode=\(configuration.displayMode.rawValue) interval=\(configuration.interval) -> \(configuration.refreshInterval.rawValue) background=\(configuration.background) -> \(configuration.widgetBackground.rawValue)")
        // Two entries so the verse still rolls over on time even if the
        // system is late asking for a new timeline.
        let entries = [
            entry(for: current, mode: configuration.displayMode, interval: configuration.refreshInterval, background: configuration.widgetBackground),
            entry(for: next, mode: configuration.displayMode, interval: configuration.refreshInterval, background: configuration.widgetBackground),
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

    private func entry(for date: Date, mode: DisplayMode, interval: RefreshInterval, background: WidgetBackground) -> VerseEntry {
        let offset = UserDefaults.standard.integer(forKey: "manualOffset")
        return VerseEntry(date: date, verse: VerseStore.verse(for: date, every: interval, offset: offset), mode: mode, background: background)
    }
}
