import SwiftUI

// Shown when someone opens Ayah.app directly. Without it the app looks broken:
// it is a background agent, so double-clicking it would otherwise do nothing at
// all. The widget itself is added from the desktop, so this window's job is to
// say that clearly and get out of the way.
struct WelcomeView: View {
    var onDone: () -> Void

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "Version \(short)"
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                if let icon = NSApp.applicationIconImage {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 88, height: 88)
                        .accessibilityHidden(true)
                }

                Text("Ayah")
                    .font(.system(size: 30, weight: .semibold))

                Text("A verse of the Quran on your desktop, refreshed on your schedule.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(version)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 32)
            .padding(.horizontal, 32)

            Divider()
                .padding(.vertical, 24)
                .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 14) {
                Text("Add the widget")
                    .font(.headline)

                Step(number: 1, text: "Right-click anywhere on your desktop.")
                Step(number: 2, text: "Choose Edit Widgets.")
                Step(number: 3, text: "Search for Ayah, then drag Verse of the Day onto your desktop.")

                Text("To change the language, background, or how often the verse changes, right-click the widget and choose Edit Widget.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 32)

            Spacer(minLength: 24)

            HStack {
                Link("View on GitHub", destination: URL(string: "https://github.com/MalekAlbdoor/ayah")!)
                    .font(.callout)

                Spacer()

                Button("Done", action: onDone)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .frame(width: 460)
    }
}

private struct Step: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(.tint))
                .accessibilityHidden(true)

            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number). \(text)")
    }
}
