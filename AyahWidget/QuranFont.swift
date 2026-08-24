import SwiftUI
import CoreText

// KFGQPC Uthmanic Script HAFS, the Madinah Mushaf font used by quran.com.
// Registered at runtime so the extension needs no font-related plist keys.
enum QuranFont {
    static let postScriptName = "KFGQPCUthmanicScriptHAFS"

    private final class BundleLocator {}

    static let isRegistered: Bool = {
        guard let url = Bundle(for: BundleLocator.self).url(forResource: "UthmanicHafs", withExtension: "otf") else {
            return false
        }
        return CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }()

    static func arabic(size: CGFloat) -> Font {
        isRegistered ? .custom(postScriptName, size: size) : .system(size: size, weight: .medium)
    }
}
