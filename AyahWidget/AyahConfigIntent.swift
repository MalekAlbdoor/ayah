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

struct AyahConfigIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Ayah Options"
    static let description = IntentDescription("Choose how the daily verse is shown.")

    @Parameter(title: "Show", default: .both)
    var mode: DisplayMode
}
