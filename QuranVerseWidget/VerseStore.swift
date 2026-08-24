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
        URL(string: "quranverse://open?surah=\(surah)&ayahStart=\(ayahStart)&ayahEnd=\(ayahEnd)")!
    }
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

    static func verse(for date: Date, in verses: [Verse] = verses, calendar: Calendar = .current) -> Verse {
        guard !verses.isEmpty else { return fallback }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: epoch),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
        let index = ((days % verses.count) + verses.count) % verses.count
        return verses[index]
    }
}
