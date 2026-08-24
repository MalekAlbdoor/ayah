import Foundation

struct Verse: Codable, Equatable {
    let surah: Int
    let ayahStart: Int
    let ayahEnd: Int
    let surahName: String
    let arabic: String
    let english: String

    var reference: String {
        ayahStart == ayahEnd
            ? "\(surahName) \(surah):\(ayahStart)"
            : "\(surahName) \(surah):\(ayahStart)-\(ayahEnd)"
    }

    var quranComPath: String {
        ayahStart == ayahEnd ? "\(surah)/\(ayahStart)" : "\(surah)/\(ayahStart)-\(ayahEnd)"
    }

    var quranComURL: URL {
        URL(string: "https://quran.com/\(quranComPath)")!
    }

    var widgetLinkURL: URL {
        URL(string: "ayah://open?surah=\(surah)&ayahStart=\(ayahStart)&ayahEnd=\(ayahEnd)")!
    }
}

enum RefreshInterval: String, CaseIterable {
    case hourly
    case every6Hours
    case daily
    case every3Days
}

enum VerseStore {
    private final class BundleLocator {}

    struct VerseFile: Codable {
        let version: Int
        let verses: [Verse]
    }

    // Shown only if Verses.json is missing or fails to decode.
    static let fallback = Verse(
        surah: 1,
        ayahStart: 5,
        ayahEnd: 5,
        surahName: "Al-Faatiha",
        arabic: "\u{0625}\u{0650}\u{064A}\u{0651}\u{064E}\u{0627}\u{0643}\u{064E} \u{0646}\u{064E}\u{0639}\u{0652}\u{0628}\u{064F}\u{062F}\u{064F} \u{0648}\u{064E}\u{0625}\u{0650}\u{064A}\u{0651}\u{064E}\u{0627}\u{0643}\u{064E} \u{0646}\u{064E}\u{0633}\u{0652}\u{062A}\u{064E}\u{0639}\u{0650}\u{064A}\u{0646}\u{064F} \u{0665}",
        english: "It is You we worship and You we ask for help."
    )

    static let verses: [Verse] = load()

    static func load(bundle: Bundle = Bundle(for: BundleLocator.self)) -> [Verse] {
        guard let url = bundle.url(forResource: "Verses", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(VerseFile.self, from: data)
        else { return [] }
        return file.verses
    }

    private static let epoch: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 1
        return Calendar.current.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }()

    static func verse(
        for date: Date,
        every interval: RefreshInterval = .daily,
        in verses: [Verse] = verses,
        calendar: Calendar = .current
    ) -> Verse {
        guard !verses.isEmpty else { return fallback }
        let period = periodIndex(for: date, every: interval, calendar: calendar)
        let index = ((period % verses.count) + verses.count) % verses.count
        return verses[index]
    }

    // Hour-based periods anchor to each day's local midnight so boundaries
    // land on wall-clock hours (0:00, 6:00, 12:00, 18:00) regardless of DST.
    static func periodIndex(for date: Date, every interval: RefreshInterval, calendar: Calendar = .current) -> Int {
        let anchor = calendar.startOfDay(for: epoch)
        let dayCount = days(from: anchor, to: date, calendar: calendar)
        switch interval {
        case .daily:
            return dayCount
        case .every3Days:
            return Int(floor(Double(dayCount) / 3))
        case .hourly:
            return dayCount * 24 + calendar.component(.hour, from: date)
        case .every6Hours:
            return dayCount * 4 + calendar.component(.hour, from: date) / 6
        }
    }

    static func nextChange(after date: Date, every interval: RefreshInterval, calendar: Calendar = .current) -> Date {
        let anchor = calendar.startOfDay(for: epoch)
        let startOfDay = calendar.startOfDay(for: date)
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: startOfDay)
            ?? date.addingTimeInterval(86400)
        switch interval {
        case .daily:
            return nextMidnight
        case .every3Days:
            let period = periodIndex(for: date, every: interval, calendar: calendar)
            return calendar.date(byAdding: .day, value: (period + 1) * 3, to: anchor) ?? nextMidnight
        case .hourly:
            return calendar.nextDate(
                after: date,
                matching: DateComponents(minute: 0, second: 0),
                matchingPolicy: .nextTime
            ) ?? date.addingTimeInterval(3600)
        case .every6Hours:
            let boundary = (calendar.component(.hour, from: date) / 6 + 1) * 6
            guard boundary < 24 else { return nextMidnight }
            return calendar.date(bySettingHour: boundary, minute: 0, second: 0, of: date) ?? nextMidnight
        }
    }

    private static func days(from anchor: Date, to date: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: anchor, to: calendar.startOfDay(for: date)).day ?? 0
    }
}
