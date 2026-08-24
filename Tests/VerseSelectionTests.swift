import XCTest

final class VerseSelectionTests: XCTestCase {
    private var verses: [Verse] = []

    override func setUp() {
        verses = VerseStore.load()
    }

    func testDataLoadsAndIsWellFormed() {
        XCTAssertGreaterThanOrEqual(verses.count, 100, "curated list should hold at least 100 verses")
        for verse in verses {
            XCTAssertFalse(verse.arabic.isEmpty, "\(verse.reference) has empty Arabic text")
            XCTAssertFalse(verse.english.isEmpty, "\(verse.reference) has empty English text")
            XCTAssertFalse(verse.surahName.isEmpty)
            XCTAssertGreaterThanOrEqual(verse.ayahEnd, verse.ayahStart)
            XCTAssertTrue((1...114).contains(verse.surah))
            XCTAssertEqual(verse.quranComURL.host, "quran.com")
        }
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

    func testDatesBeforeEpochStillSelectSafely() {
        let old = Date(timeIntervalSince1970: 0)
        XCTAssertTrue(verses.contains(VerseStore.verse(for: old, in: verses)))
    }

    func testEmptyListFallsBack() {
        XCTAssertEqual(VerseStore.verse(for: Date(), in: []), VerseStore.fallback)
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
