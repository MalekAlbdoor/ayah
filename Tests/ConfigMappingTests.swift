import SwiftUI
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

    func testBackgroundFromOptionTitles() {
        for (background, title) in WidgetBackground.titles {
            XCTAssertEqual(WidgetBackground(configuredValue: title), background)
        }
        XCTAssertEqual(WidgetBackground.optionTitles.count, WidgetBackground.allCases.count)
    }

    func testBackgroundFallsBackToLiquidGlass() {
        XCTAssertEqual(WidgetBackground(configuredValue: ""), .liquidGlass)
        XCTAssertEqual(WidgetBackground(configuredValue: "garbage"), .liquidGlass)
        XCTAssertEqual(WidgetBackground(configuredValue: "ocean"), .ocean)  // raw token
    }

    func testEveryBackgroundKeepsTextLegible() {
        for background in WidgetBackground.allCases where background != .liquidGlass && background != .system {
            XCTAssertNotNil(background.forcedColorScheme, "\(background) must pin a color scheme")
            XCTAssertNotNil(background.gradientColors, "\(background) must define colors")
        }
        // Liquid Glass is a translucent smoke wash, so it pins light text.
        XCTAssertEqual(WidgetBackground.liquidGlass.forcedColorScheme, .dark)
        XCTAssertNil(WidgetBackground.liquidGlass.gradientColors)
        // System follows the appearance setting.
        XCTAssertNil(WidgetBackground.system.forcedColorScheme)
        XCTAssertNil(WidgetBackground.system.gradientColors)
    }

    func testEveryOptionTitleRoundTrips() {
        for (interval, title) in RefreshInterval.titles {
            XCTAssertEqual(RefreshInterval(configuredValue: title), interval)
        }
        XCTAssertEqual(RefreshInterval.optionTitles.count, RefreshInterval.allCases.count)
    }
}
