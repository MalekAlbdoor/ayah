import AppKit

// Invisible relay: the widget can only launch its containing app, so this app
// translates ayah:// URLs into quran.com links, opens the browser, and quits.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach(handle)
    }

    @objc private func handleGetURL(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        guard let string = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: string) else { return }
        handle(url)
    }

    private func handle(_ url: URL) {
        guard url.scheme == "ayah",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }

        var surah: Int?
        var start: Int?
        var end: Int?
        for item in components.queryItems ?? [] {
            switch item.name {
            case "surah": surah = item.value.flatMap(Int.init)
            case "ayahStart": start = item.value.flatMap(Int.init)
            case "ayahEnd": end = item.value.flatMap(Int.init)
            default: break
            }
        }
        guard let surah, let start else { return }

        let path = (end ?? start) > start ? "\(surah)/\(start)-\(end ?? start)" : "\(surah)/\(start)"
        if let target = URL(string: "https://quran.com/\(path)") {
            NSWorkspace.shared.open(target)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            NSApp.terminate(nil)
        }
    }
}
