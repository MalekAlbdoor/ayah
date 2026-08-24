import AppIntents

enum DisplayMode: String, AppEnum {
    case both
    case arabicOnly
    case englishOnly

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Display"

    static let caseDisplayRepresentations: [DisplayMode: DisplayRepresentation] = [
        .both: "Arabic and English",
        .arabicOnly: "Arabic only",
        .englishOnly: "English only",
    ]
}

extension RefreshInterval: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "New verse"

    static let caseDisplayRepresentations: [RefreshInterval: DisplayRepresentation] = [
        .hourly: "Every hour",
        .every6Hours: "Every 6 hours",
        .daily: "Every day",
        .every3Days: "Every 3 days",
    ]
}

struct AyahConfigIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Ayah Options"
    static let description = IntentDescription("Choose how the verse is shown and how often it changes.")

    @Parameter(title: "Show", default: .both)
    var mode: DisplayMode

    @Parameter(title: "New verse", default: .daily)
    var interval: RefreshInterval
}
