import AppKit
import SwiftUI
import WidgetKit

// Two jobs. Launched by the widget with an ayah:// URL, this is an invisible
// relay: it opens the verse on quran.com and quits. Opened directly from
// Finder or the Dock, it shows the welcome window explaining how to add the
// widget, because a background agent that shows nothing reads as broken.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var welcomeWindow: NSWindow?
    private var didHandleURL = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Launching the app nudges chronod to re-request timelines, so a
        // plain `open Ayah.app` refreshes the widget after updates.
        WidgetCenter.shared.reloadAllTimelines()

        // A URL launch arrives as an Apple Event just after this point, so we
        // cannot tell yet which of the two jobs this is. Wait one beat: if no
        // URL shows up, this was a direct launch and the window is wanted.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self, !self.didHandleURL else { return }
            self.showWelcomeWindow()
        }
    }

    private func showWelcomeWindow() {
        // The app is an LSUIElement agent, so it has no Dock icon or menu bar
        // until it actually has something to show. Promote it for the window's
        // lifetime so it can take focus and be switched to like a normal app.
        NSApp.setActivationPolicy(.regular)

        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Ayah"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.contentView = NSHostingView(
            rootView: WelcomeView { NSApp.terminate(nil) }
        )
        window.delegate = self
        window.center()
        window.isReleasedWhenClosed = false

        welcomeWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
        didHandleURL = true

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

extension AppDelegate: NSWindowDelegate {
    // Closing the welcome window is the only way out of a direct launch, so
    // treat it as quitting rather than leaving an invisible process behind.
    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === welcomeWindow else { return }
        NSApp.terminate(nil)
    }
}
