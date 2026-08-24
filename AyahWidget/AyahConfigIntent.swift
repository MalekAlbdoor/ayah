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

// Interactive widget button: advances to another verse immediately by bumping
// a stored offset that the provider adds to the schedule-based index.
struct NextVerseIntent: AppIntent {
    static let title: LocalizedStringResource = "New Verse"
    static let description = IntentDescription("Show another verse now.")

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: "manualOffset") + 1, forKey: "manualOffset")
        trace("NextVerseIntent performed, offset now \(defaults.integer(forKey: "manualOffset"))")
        return .result()
    }
}

struct AyahConfigIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Ayah Options"
    static let description = IntentDescription("Choose how the verse is shown and how often it changes.")

    @Parameter(title: "Show", default: .both)
    var mode: DisplayMode

    @Parameter(title: "New verse", default: .daily)
    var interval: RefreshInterval
}
