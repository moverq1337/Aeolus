import SwiftUI

struct SettingsView: View {
    let nowPlaying: NowPlayingStore

    @AppStorage("hoverDelay") private var hoverDelay = 0.45
    @AppStorage("hideInFullscreen") private var hideInFullscreen = false
    @AppStorage("batteryAlerts") private var batteryAlerts = true
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @Environment(\.appearsActive) private var appearsActive

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        LaunchAtLogin.set(enabled: newValue)
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
                Toggle("Hide in full screen", isOn: $hideInFullscreen)
                Toggle("Battery alerts", isOn: $batteryAlerts)
            }
            Section {
                VStack(alignment: .leading) {
                    Slider(value: $hoverDelay, in: 0...1, step: 0.05) {
                        Text("Hover delay")
                    } minimumValueLabel: {
                        Text("0s")
                    } maximumValueLabel: {
                        Text("1s")
                    }
                    Text(String(format: "Open after %.2f s of hover", hoverDelay))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                LabeledContent(
                    "Media engine",
                    value: nowPlaying.mediaAvailable ? "Active" : "Unavailable on this macOS")
                LabeledContent(
                    "Version",
                    value: Bundle.main.infoDictionary?["CFBundleShortVersionString"]
                        as? String ?? "—")
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .fixedSize()
        .onChange(of: appearsActive) { _, active in
            // Пользователь мог убрать логин-айтем в System Settings — пересинхронизируем.
            if active { launchAtLogin = LaunchAtLogin.isEnabled }
        }
    }
}
