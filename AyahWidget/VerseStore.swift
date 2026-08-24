import Foundation

// Length tier, computed at fetch time by Scripts/fetch_verses.sh and stored in
// Verses.json. Never set by hand: a hand-written tier drifts from what actually
// fits, a measured one cannot.
enum VerseTier: Int, Codable, CaseIterable {
    case short = 0
    case medium = 1
    case long = 2
}

// Which tiers a given widget size may draw from. Pools nest, so a large widget
// sees short verses too; it simply has more to choose from.
enum VerseSizeClass: CaseIterable {
    case small
    case medium
    case large

    var maxTier: VerseTier {
        switch self {
        case .small: return .short
        case .medium: return .medium
        case .large: return .long
        }
    }
}

struct Verse: Codable, Equatable {
    let surah: Int
    let ayahStart: Int
    let ayahEnd: Int
    let surahName: String
    let arabic: String
    let english: String
    // Optional so a version 1 Verses.json still decodes. A bundled file that
    // predates tiering degrades to short, which every widget size can render,
    // rather than failing to load and dropping the user to the fallback verse.
    let tierRaw: Int?
    let theme: String?
    let source: String?

    enum CodingKeys: String, CodingKey {
        case surah, ayahStart, ayahEnd, surahName, arabic, english
        case tierRaw = "tier"
        case theme, source
    }

    var tier: VerseTier { VerseTier(rawValue: tierRaw ?? 0) ?? .short }

    init(
        surah: Int,
        ayahStart: Int,
        ayahEnd: Int,
        surahName: String,
        arabic: String,
        english: String,
        tierRaw: Int? = nil,
        theme: String? = nil,
        source: String? = nil
    ) {
        self.surah = surah
        self.ayahStart = ayahStart
        self.ayahEnd = ayahEnd
        self.surahName = surahName
        self.arabic = arabic
        self.english = english
        self.tierRaw = tierRaw
        self.theme = theme
        self.source = source
    }

    var reference: String {
        ayahStart == ayahEnd
            ? "\(surahName) \(surah):\(ayahStart)"
            : "\(surahName) \(surah):\(ayahStart)-\(ayahEnd)"
    }

    // VoiceOver reads "13:28" as a clock time, so spell the reference out.
    var spokenReference: String {
        ayahStart == ayahEnd
            ? "\(surahName), chapter \(surah), verse \(ayahStart)"
            : "\(surahName), chapter \(surah), verses \(ayahStart) to \(ayahEnd)"
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

enum DisplayMode: String {
    case both
    case arabicOnly
    case englishOnly

    init(showArabic: Bool, showEnglish: Bool) {
        switch (showArabic, showEnglish) {
        case (true, false): self = .arabicOnly
        case (false, true): self = .englishOnly
        default: self = .both  // both on, or both off (nothing to show is not useful)
        }
    }
}

enum RefreshInterval: String, CaseIterable {
    case hourly
    case every6Hours
    case daily
    case every3Days

    static let titles: [(RefreshInterval, String)] = [
        (.hourly, "Every hour"),
        (.every6Hours, "Every 6 hours"),
        (.daily, "Every day"),
        (.every3Days, "Every 3 days"),
    ]

    static var optionTitles: [String] { titles.map(\.1) }

    init(configuredValue: String) {
        if let match = Self.titles.first(where: { $0.1 == configuredValue })?.0 {
            self = match
        } else if let match = RefreshInterval(rawValue: configuredValue) {
            self = match  // legacy token from configs saved by the AppEnum build
        } else {
            self = .daily
        }
    }
}

// SplitMix64: a small, fully specified PRNG. Written out here so the verse
// order is reproducible across Swift versions, platforms, and machines.
private struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    // Rejection sampling, so every value below the bound is equally likely.
    mutating func next(upperBound: UInt64) -> UInt64 {
        precondition(upperBound > 0)
        let limit = UInt64.max - (UInt64.max % upperBound)
        var value = next()
        while value >= limit { value = next() }
        return value % upperBound
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

    static func pool(for sizeClass: VerseSizeClass, in verses: [Verse] = verses) -> [Verse] {
        verses.filter { $0.tier.rawValue <= sizeClass.maxTier.rawValue }
    }

    // A distinct seed per size. Sharing one seed would advance all three pools
    // in step, so a small and a large widget on the same desktop would show
    // correlated verses. Small keeps the original seed so its order is
    // unchanged from the shipped version.
    private static func seed(for sizeClass: VerseSizeClass) -> UInt64 {
        switch sizeClass {
        case .small: return 0x4179_6168_5665_7273   // "AyahVers"
        case .medium: return 0x4179_6168_4D65_6473  // "AyahMeds"
        case .large: return 0x4179_6168_4C61_7267   // "AyahLarg"
        }
    }

    static func verse(
        for date: Date,
        every interval: RefreshInterval = .daily,
        offset: Int = 0,
        sizeClass: VerseSizeClass = .small,
        in verses: [Verse] = verses,
        calendar: Calendar = .current
    ) -> Verse {
        let pool = pool(for: sizeClass, in: verses)
        guard !pool.isEmpty else { return fallback }
        let period = periodIndex(for: date, every: interval, calendar: calendar) + offset
        let position = ((period % pool.count) + pool.count) % pool.count
        return pool[readingOrder(count: pool.count, seed: seed(for: sizeClass))[position]]
    }

    // Verses.json is stored in mushaf order, so walking it directly would show
    // several verses from the same surah on consecutive days. This spreads them
    // out with a fixed seeded shuffle: still fully deterministic and stateless,
    // and because the same permutation repeats every cycle, any run of `count`
    // consecutive periods shows every verse exactly once.
    static func readingOrder(count: Int, seed: UInt64 = 0x4179_6168_5665_7273) -> [Int] {
        guard count > 1 else { return Array(0..<max(count, 0)) }
        var order = Array(0..<count)
        var rng = SplitMix64(seed: seed)
        // Fisher-Yates, written out rather than using shuffle(using:) so the
        // order can never shift under us when the standard library changes.
        for i in stride(from: count - 1, to: 0, by: -1) {
            let j = Int(rng.next(upperBound: UInt64(i + 1)))
            order.swapAt(i, j)
        }
        return order
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
