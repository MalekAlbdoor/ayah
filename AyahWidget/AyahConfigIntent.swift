import AppIntents

// Widget configuration parameters are limited to primitive types (Bool/String)
// on purpose: AppEnum parameters decode by fetching type metadata from linkd,
// and linkd rejects clients whose code signature has no Team ID
// ("Rejecting invalid client due to requiresValidatedBundle"). This build is
// ad-hoc signed, so enum parameters silently fall back to their defaults while
// primitives decode fine. See README "Why the options are toggles".

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

struct IntervalOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [String] {
        trace("IntervalOptionsProvider queried")
        return RefreshInterval.optionTitles
    }
}

struct AyahConfigIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Ayah Options"
    static let description = IntentDescription("Choose what is shown and how often the verse changes.")

    @Parameter(title: "Arabic text", default: true)
    var showArabic: Bool

    @Parameter(title: "English translation", default: true)
    var showEnglish: Bool

    // Stored as a display string; also accepts the raw tokens ("daily", ...)
    // that configurations saved by older builds carry under the same key.
    @Parameter(title: "New verse", default: "Every day", optionsProvider: IntervalOptionsProvider())
    var interval: String

    var displayMode: DisplayMode {
        DisplayMode(showArabic: showArabic, showEnglish: showEnglish)
    }

    var refreshInterval: RefreshInterval {
        RefreshInterval(configuredValue: interval)
    }
}
