import XCTest
import WidgetKit

final class VerseSelectionTests: XCTestCase {
    private var verses: [Verse] = []

    override func setUp() {
        verses = VerseStore.load()
    }

    func testDataLoadsAndIsWellFormed() {
        XCTAssertEqual(verses.count, 365, "one verse per day of the year")
        for verse in verses {
            XCTAssertFalse(verse.arabic.isEmpty, "\(verse.reference) has empty Arabic text")
            XCTAssertFalse(verse.english.isEmpty, "\(verse.reference) has empty English text")
            XCTAssertFalse(verse.surahName.isEmpty)
            XCTAssertGreaterThanOrEqual(verse.ayahEnd, verse.ayahStart)
            XCTAssertTrue((1...114).contains(verse.surah))
            XCTAssertEqual(verse.quranComURL.host, "quran.com")
        }
    }

    // MARK: - Tier decoding

    private func decodeVerse(_ json: String) throws -> Verse {
        try JSONDecoder().decode(Verse.self, from: Data(json.utf8))
    }

    func testVerseWithoutTierDecodesAsShort() throws {
        // A version 1 Verses.json has no tier key. It must still load, and it
        // must land in the smallest pool rather than a pool it may not fit.
        let verse = try decodeVerse("""
        {"surah":112,"ayahStart":1,"ayahEnd":4,"surahName":"Al-Ikhlaas",
         "arabic":"a","english":"b"}
        """)
        XCTAssertEqual(verse.tier, .short)
        XCTAssertNil(verse.theme)
        XCTAssertNil(verse.source)
    }

    func testVerseWithTierDecodesIt() throws {
        let verse = try decodeVerse("""
        {"surah":31,"ayahStart":12,"ayahEnd":19,"surahName":"Luqman",
         "arabic":"a","english":"b","tier":2,"theme":"gratitude",
         "source":"Luqman's counsel"}
        """)
        XCTAssertEqual(verse.tier, .long)
        XCTAssertEqual(verse.theme, "gratitude")
        XCTAssertEqual(verse.source, "Luqman's counsel")
    }

    func testUnknownTierValueFallsBackToShort() throws {
        // Forward compatibility: a future tier 3 must not crash an old build.
        let verse = try decodeVerse("""
        {"surah":2,"ayahStart":1,"ayahEnd":1,"surahName":"Al-Baqara",
         "arabic":"a","english":"b","tier":7}
        """)
        XCTAssertEqual(verse.tier, .short)
    }

    // MARK: - Size-class pools

    private func stub(_ surah: Int, tier: VerseTier) -> Verse {
        Verse(
            surah: surah, ayahStart: 1, ayahEnd: 1, surahName: "S\(surah)",
            arabic: "a", english: "b", tierRaw: tier.rawValue
        )
    }

    private var mixedPool: [Verse] {
        (1...30).map { stub($0, tier: VerseTier(rawValue: $0 % 3)!) }
    }

    func testPoolsNest() {
        // A large widget must still be able to show a short verse. Anything
        // else would make short verses vanish as the widget grows.
        let small = VerseStore.pool(for: .small, in: mixedPool).map(\.reference)
        let medium = VerseStore.pool(for: .medium, in: mixedPool).map(\.reference)
        let large = VerseStore.pool(for: .large, in: mixedPool).map(\.reference)
        XCTAssertTrue(Set(small).isSubset(of: Set(medium)))
        XCTAssertTrue(Set(medium).isSubset(of: Set(large)))
        XCTAssertEqual(large.count, mixedPool.count)
    }

    func testSmallPoolHoldsOnlyShortVerses() {
        for verse in VerseStore.pool(for: .small, in: mixedPool) {
            XCTAssertEqual(verse.tier, .short)
        }
    }

    func testSizeClassesUseDifferentOrders() {
        // With a shared seed the three sizes would march in step and two
        // widgets on one desktop would correlate. Distinct seeds decorrelate.
        // Compare whole cycles, not one date: two permutations agreeing at a
        // single position is ordinary coincidence and would make this flaky.
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let onlyShort = (1...30).map { stub($0, tier: .short) }
        var small: [String] = []
        var large: [String] = []
        for offset in 0..<onlyShort.count {
            let day = calendar.date(byAdding: .day, value: offset, to: start)!
            small.append(VerseStore.verse(for: day, sizeClass: .small, in: onlyShort).reference)
            large.append(VerseStore.verse(for: day, sizeClass: .large, in: onlyShort).reference)
        }
        XCTAssertEqual(Set(small), Set(large), "identical pools should hold identical verses")
        XCTAssertNotEqual(small, large, "distinct seeds should give distinct orders")
    }

    func testEachPoolCyclesWithoutRepeats() {
        // The guarantee is per pool now, and each pool cycles at its own
        // natural length rather than being padded to 365.
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        for sizeClass in VerseSizeClass.allCases {
            let pool = VerseStore.pool(for: sizeClass, in: mixedPool)
            var seen = Set<String>()
            for offset in 0..<pool.count {
                let day = calendar.date(byAdding: .day, value: offset, to: start)!
                seen.insert(
                    VerseStore.verse(for: day, sizeClass: sizeClass, in: mixedPool).reference
                )
            }
            XCTAssertEqual(seen.count, pool.count, "\(sizeClass) repeated inside one cycle")
        }
    }

    func testSizeClassWithAnEmptyPoolFallsBack() {
        // Nothing in the small pool must not crash; it degrades to the fallback.
        let noShortVerses = (1...5).map { stub($0, tier: .long) }
        XCTAssertEqual(
            VerseStore.verse(for: Date(), sizeClass: .small, in: noShortVerses),
            VerseStore.fallback
        )
    }

    // MARK: - Family mapping

    func testWidgetFamilyMapsToSizeClass() {
        XCTAssertEqual(VerseSizeClass(family: .systemSmall), .small)
        XCTAssertEqual(VerseSizeClass(family: .systemMedium), .medium)
        XCTAssertEqual(VerseSizeClass(family: .systemLarge), .large)
    }

    func testUnsupportedFamilyFallsBackToSmall() {
        // supportedFamilies lists only the three system sizes, but the
        // initializer must be total. Small is the safe answer: its verses
        // render at any size. Use .systemExtraLarge here, not one of the
        // accessory families, which do not exist on macOS and would fail to
        // compile.
        XCTAssertEqual(VerseSizeClass(family: .systemExtraLarge), .small)
    }

    // MARK: - English visibility

    private func sized(arabic: Int, english: Int) -> Verse {
        Verse(surah: 2, ayahStart: 1, ayahEnd: 1, surahName: "Al-Baqara",
              arabic: String(repeating: "a", count: arabic),
              english: String(repeating: "b", count: english))
    }

    func testSmallNeverShowsEnglishInBothMode() {
        // Small has room for one language, and Arabic is the one that carries
        // the widget. This is why the small pool is capped on Arabic alone.
        XCTAssertFalse(sized(arabic: 10, english: 10).showsEnglish(sizeClass: .small, mode: .both))
    }

    func testMediumDropsEnglishPastItsThreshold() {
        XCTAssertTrue(sized(arabic: 130, english: 130).showsEnglish(sizeClass: .medium, mode: .both))
        XCTAssertFalse(sized(arabic: 131, english: 130).showsEnglish(sizeClass: .medium, mode: .both))
    }

    func testLargeDropsEnglishPastItsThreshold() {
        // Large used to show English unconditionally, which truncated the
        // translation on 17 of the curated verses. It now adapts like medium.
        XCTAssertTrue(sized(arabic: 200, english: 190).showsEnglish(sizeClass: .large, mode: .both))
        XCTAssertFalse(sized(arabic: 200, english: 191).showsEnglish(sizeClass: .large, mode: .both))
    }

    func testExplicitModesIgnoreLength() {
        let long = sized(arabic: 900, english: 900)
        XCTAssertTrue(long.showsEnglish(sizeClass: .small, mode: .englishOnly))
        XCTAssertFalse(long.showsEnglish(sizeClass: .large, mode: .arabicOnly))
    }

    func testSelectionIsDeterministic() {
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        let first = VerseStore.verse(for: date, in: verses)
        let second = VerseStore.verse(for: date, in: verses)
        XCTAssertEqual(first, second)
    }

    func testSameDayDifferentTimesGiveSameVerse() {
        let calendar = Calendar.current
        let morning = calendar.date(from: DateComponents(year: 2026, month: 8, day: 23, hour: 6))!
        let night = calendar.date(from: DateComponents(year: 2026, month: 8, day: 23, hour: 23, minute: 59))!
        XCTAssertEqual(
            VerseStore.verse(for: morning, in: verses),
            VerseStore.verse(for: night, in: verses)
        )
    }

    func testMidnightBoundaryAdvancesVerse() {
        let calendar = Calendar.current
        let beforeMidnight = calendar.date(from: DateComponents(year: 2026, month: 8, day: 23, hour: 23, minute: 59))!
        let afterMidnight = calendar.date(from: DateComponents(year: 2026, month: 8, day: 24, hour: 0, minute: 1))!
        XCTAssertNotEqual(
            VerseStore.verse(for: beforeMidnight, in: verses),
            VerseStore.verse(for: afterMidnight, in: verses)
        )
    }

    func testFullCycleCoversEveryVerse() {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        var seen = Set<String>()
        for offset in 0..<verses.count {
            let day = calendar.date(byAdding: .day, value: offset, to: start)!
            let verse = VerseStore.verse(for: day, in: verses)
            seen.insert(verse.reference)
        }
        XCTAssertEqual(seen.count, verses.count, "one full cycle should visit every verse exactly once")
    }

    func testNoVerseIsUnreasonablyLongForAWidget() {
        // 24:35, the Verse of Light, is the longest of the curated set and the
        // worst case the small layout has to survive. Anything materially
        // longer than that would not fit at a readable size.
        for verse in verses {
            XCTAssertLessThanOrEqual(
                verse.arabic.count, 500,
                "\(verse.reference) is too long to render in a widget"
            )
        }
    }

    func testEveryVerseIsUnique() {
        let references = verses.map(\.reference)
        XCTAssertEqual(Set(references).count, references.count, "the curated list repeats a verse")
    }

    func testReadingOrderIsAPermutation() {
        let order = VerseStore.readingOrder(count: verses.count)
        XCTAssertEqual(order.count, verses.count)
        XCTAssertEqual(Set(order), Set(0..<verses.count), "every verse index must appear exactly once")
    }

    func testReadingOrderIsStable() {
        XCTAssertEqual(
            VerseStore.readingOrder(count: verses.count),
            VerseStore.readingOrder(count: verses.count),
            "the shuffle must be reproducible, not random per run"
        )
    }

    func testReadingOrderHandlesDegenerateCounts() {
        XCTAssertEqual(VerseStore.readingOrder(count: 0), [])
        XCTAssertEqual(VerseStore.readingOrder(count: 1), [0])
    }

    func testConsecutiveDaysDoNotClusterBySurah() {
        // Stored in mushaf order, walking the array directly would show long
        // runs from the same surah. The shuffle should break those up.
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        var sameSurahAsPrevious = 0
        var previous: Int?
        for offset in 0..<verses.count {
            let day = calendar.date(byAdding: .day, value: offset, to: start)!
            let surah = VerseStore.verse(for: day, in: verses).surah
            if surah == previous { sameSurahAsPrevious += 1 }
            previous = surah
        }
        // A handful of neighbouring pairs is normal in any shuffle; the mushaf
        // ordering produces dozens.
        XCTAssertLessThan(
            sameSurahAsPrevious,
            verses.count / 10,
            "consecutive days should rarely repeat a surah"
        )
    }

    func testAnyWindowOfOneCycleHasNoRepeats() {
        // Stronger than covering one aligned cycle: because the same permutation
        // repeats, ANY run of `count` consecutive days must be repeat-free.
        let calendar = Calendar.current
        let base = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        for startOffset in [0, 1, 7, 43, 200] {
            let start = calendar.date(byAdding: .day, value: startOffset, to: base)!
            var seen = Set<String>()
            for offset in 0..<verses.count {
                let day = calendar.date(byAdding: .day, value: offset, to: start)!
                seen.insert(VerseStore.verse(for: day, in: verses).reference)
            }
            XCTAssertEqual(
                seen.count,
                verses.count,
                "a \(verses.count)-day window starting at +\(startOffset) repeated a verse"
            )
        }
    }

    func testDatesBeforeEpochStillSelectSafely() {
        let old = Date(timeIntervalSince1970: 0)
        XCTAssertTrue(verses.contains(VerseStore.verse(for: old, in: verses)))
    }

    func testEmptyListFallsBack() {
        XCTAssertEqual(VerseStore.verse(for: Date(), in: []), VerseStore.fallback)
    }

    func testManualOffsetAdvancesAndWraps() {
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        let base = VerseStore.verse(for: date, in: verses)
        XCTAssertNotEqual(VerseStore.verse(for: date, offset: 1, in: verses), base)
        XCTAssertEqual(VerseStore.verse(for: date, offset: verses.count, in: verses), base)
    }

    func testHourlyChangesEachHour() {
        let calendar = Calendar.current
        let base = calendar.date(from: DateComponents(year: 2026, month: 8, day: 24, hour: 10, minute: 30))!
        let nextHour = calendar.date(from: DateComponents(year: 2026, month: 8, day: 24, hour: 11, minute: 5))!
        XCTAssertNotEqual(
            VerseStore.verse(for: base, every: .hourly, in: verses),
            VerseStore.verse(for: nextHour, every: .hourly, in: verses)
        )
        XCTAssertEqual(
            VerseStore.verse(for: base, every: .hourly, in: verses),
            VerseStore.verse(for: base.addingTimeInterval(600), every: .hourly, in: verses)
        )
    }

    func testEvery3DaysIsStableWithinPeriod() {
        let calendar = Calendar.current
        let period = VerseStore.periodIndex(for: Date(), every: .every3Days)
        let start = VerseStore.nextChange(after: Date(), every: .every3Days)
        let justBefore = start.addingTimeInterval(-60)
        let justAfter = start.addingTimeInterval(60)
        XCTAssertEqual(VerseStore.periodIndex(for: justBefore, every: .every3Days, calendar: calendar), period)
        XCTAssertEqual(VerseStore.periodIndex(for: justAfter, every: .every3Days, calendar: calendar), period + 1)
        XCTAssertNotEqual(
            VerseStore.verse(for: justBefore, every: .every3Days, in: verses),
            VerseStore.verse(for: justAfter, every: .every3Days, in: verses)
        )
    }

    func testNextChangeBoundaries() {
        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(year: 2026, month: 8, day: 24, hour: 10, minute: 30))!

        let nextHour = VerseStore.nextChange(after: date, every: .hourly)
        XCTAssertEqual(calendar.component(.minute, from: nextHour), 0)
        XCTAssertEqual(calendar.component(.hour, from: nextHour), 11)

        let nextDay = VerseStore.nextChange(after: date, every: .daily)
        XCTAssertEqual(nextDay, calendar.date(from: DateComponents(year: 2026, month: 8, day: 25))!)

        let next6h = VerseStore.nextChange(after: date, every: .every6Hours)
        XCTAssertEqual(calendar.component(.hour, from: next6h), 12)

        let next3d = VerseStore.nextChange(after: date, every: .every3Days)
        XCTAssertGreaterThan(next3d, date)
        XCTAssertEqual(calendar.component(.hour, from: next3d), 0)
    }
}
