import XCTest

final class ConfigMappingTests: XCTestCase {
    func testDisplayModeFromToggles() {
        XCTAssertEqual(DisplayMode(showArabic: true, showEnglish: true), .both)
        XCTAssertEqual(DisplayMode(showArabic: true, showEnglish: false), .arabicOnly)
        XCTAssertEqual(DisplayMode(showArabic: false, showEnglish: true), .englishOnly)
        XCTAssertEqual(DisplayMode(showArabic: false, showEnglish: false), .both)
    }

    func testRefreshIntervalFromOptionTitles() {
        XCTAssertEqual(RefreshInterval(configuredValue: "Every hour"), .hourly)
        XCTAssertEqual(RefreshInterval(configuredValue: "Every 6 hours"), .every6Hours)
        XCTAssertEqual(RefreshInterval(configuredValue: "Every day"), .daily)
        XCTAssertEqual(RefreshInterval(configuredValue: "Every 3 days"), .every3Days)
    }

    func testRefreshIntervalFromLegacyTokens() {
        XCTAssertEqual(RefreshInterval(configuredValue: "hourly"), .hourly)
        XCTAssertEqual(RefreshInterval(configuredValue: "every6Hours"), .every6Hours)
        XCTAssertEqual(RefreshInterval(configuredValue: "daily"), .daily)
        XCTAssertEqual(RefreshInterval(configuredValue: "every3Days"), .every3Days)
    }

    func testRefreshIntervalFallsBackToDaily() {
        XCTAssertEqual(RefreshInterval(configuredValue: ""), .daily)
        XCTAssertEqual(RefreshInterval(configuredValue: "garbage"), .daily)
    }

    func testEveryOptionTitleRoundTrips() {
        for (interval, title) in RefreshInterval.titles {
            XCTAssertEqual(RefreshInterval(configuredValue: title), interval)
        }
        XCTAssertEqual(RefreshInterval.optionTitles.count, RefreshInterval.allCases.count)
    }
}
