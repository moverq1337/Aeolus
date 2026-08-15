import SwiftUI

struct SettingsView: View {
    let nowPlaying: NowPlayingStore

    @AppStorage("hoverDelay") private var hoverDelay = 0.45
    @AppStorage("expandOnHover") private var expandOnHover = true
    @AppStorage("hideInFullscreen") private var hideInFullscreen = false
    @AppStorage("batteryAlerts") private var batteryAlerts = true
    @AppStorage("lockScreenWidget") private var lockScreenWidget = false
    @AppStorage("lockScreenOffset") private var lockScreenOffset = 0.0
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    private var lockScreenAvailable: Bool { SkyLightSpace.shared != nil }
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
                Toggle("Synced lyrics", isOn: Binding(
                    get: { UserDefaults.standard.bool(forKey: "syncedLyrics") },
                    set: { UserDefaults.standard.set($0, forKey: "syncedLyrics") }))
                Toggle("Check for updates automatically", isOn: Binding(
                    get: { AppServices.shared.updater.updater.automaticallyChecksForUpdates },
                    set: { AppServices.shared.updater.updater.automaticallyChecksForUpdates = $0 }))
            }
            Section {
                Toggle("Expand on hover", isOn: $expandOnHover)
                if expandOnHover {
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
                } else {
                    Text("Click the island to expand it")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Lock Screen") {
                Toggle("Lock Screen widget", isOn: $lockScreenWidget)
                    .disabled(!lockScreenAvailable)
                if lockScreenWidget && lockScreenAvailable {
                    VStack(alignment: .leading) {
                        Slider(value: $lockScreenOffset, in: 0...320, step: 10) {
                            Text("Raise widget")
                        } minimumValueLabel: {
                            Text("0")
                        } maximumValueLabel: {
                            Text("320")
                        }
                        Text("Raise the widget above its spot near the password field")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if !lockScreenAvailable {
                    Text("Unavailable on this macOS")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                Text("Synced lyrics sends the track title, artist and duration to lrclib.net")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LabeledContent(
                    "Media engine",
                    value: nowPlaying.mediaAvailable ? "Active" : "Unavailable on this macOS")
                if let health = PowerMonitor.batteryHealth() {
                    LabeledContent(
                        "Battery health",
                        value: "\(health.capacityPercent)% · \(health.cycles) cycles")
                }
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
