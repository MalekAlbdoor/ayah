import SwiftUI

// Background choices for the widget. Stored in the configuration as the
// display string (a primitive String parameter; see AyahConfigIntent for why
// enums cannot be used here).
enum WidgetBackground: String, CaseIterable {
    case liquidGlass
    case system
    case white
    case sand
    case ocean
    case forest
    case plum
    case midnight
    case charcoal

    static let titles: [(WidgetBackground, String)] = [
        (.liquidGlass, "Liquid Glass"),
        (.system, "System (light/dark)"),
        (.white, "White"),
        (.sand, "Sand"),
        (.ocean, "Ocean"),
        (.forest, "Forest"),
        (.plum, "Plum"),
        (.midnight, "Midnight"),
        (.charcoal, "Charcoal"),
    ]

    static var optionTitles: [String] { titles.map(\.1) }

    var title: String { Self.titles.first(where: { $0.0 == self })!.1 }

    init(configuredValue: String) {
        if let match = Self.titles.first(where: { $0.1 == configuredValue })?.0 {
            self = match
        } else if let match = WidgetBackground(rawValue: configuredValue) {
            self = match
        } else {
            self = .liquidGlass
        }
    }

    // Fixed-color backgrounds pin the content's color scheme so text stays
    // legible regardless of the system appearance. Liquid Glass sits on the
    // system's frosted backdrop (white frost in light mode, dark frost in
    // dark), so its text must follow the system scheme; System likewise.
    var forcedColorScheme: ColorScheme? {
        switch self {
        case .liquidGlass, .system: return nil
        case .white, .sand: return .light
        case .ocean, .forest, .plum, .midnight, .charcoal: return .dark
        }
    }

    var gradientColors: [Color]? {
        switch self {
        case .liquidGlass, .system:
            return nil
        case .white:
            return [Color.white, Color(red: 0.93, green: 0.93, blue: 0.95)]
        case .sand:
            return [Color(red: 0.96, green: 0.93, blue: 0.86), Color(red: 0.89, green: 0.83, blue: 0.72)]
        case .ocean:
            return [Color(red: 0.12, green: 0.35, blue: 0.60), Color(red: 0.05, green: 0.19, blue: 0.38)]
        case .forest:
            return [Color(red: 0.13, green: 0.38, blue: 0.28), Color(red: 0.05, green: 0.22, blue: 0.16)]
        case .plum:
            return [Color(red: 0.36, green: 0.22, blue: 0.50), Color(red: 0.20, green: 0.10, blue: 0.32)]
        case .midnight:
            return [Color(red: 0.10, green: 0.14, blue: 0.30), Color(red: 0.04, green: 0.06, blue: 0.16)]
        case .charcoal:
            return [Color(red: 0.22, green: 0.22, blue: 0.24), Color(red: 0.11, green: 0.11, blue: 0.13)]
        }
    }
}
