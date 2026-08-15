import Foundation

/// Фильтр источников Now Playing: мессенджеры и конференции публикуют сессии
/// для голосовых/кружков/звонков — это не музыка, остров их игнорирует.
/// Пользователь может расширить список: defaults write io.github.moverq1337.aeolus
/// ignoredBundleIDs -array "com.example.app"
enum MediaSourceFilter {
    static let builtinBlocklist: Set<String> = [
        // Telegram (нативный и tdesktop)
        "ru.keepcoder.Telegram",
        "org.telegram.desktop",
        // Конференции
        "org.jitsi.jitsi-meet",
        "us.zoom.xos",
        "com.microsoft.teams",
        "com.microsoft.teams2",
        "com.cisco.webexmeetingsapp",
        "com.apple.FaceTime",
        // Мессенджеры с голосовыми
        "com.hnc.Discord",
        "com.tinyspeck.slackmacgap",
        "net.whatsapp.WhatsApp",
        "org.whispersystems.signal-desktop",
        "com.skype.skype",
    ]

    static func isBlocked(_ bundleID: String?, extra: [String]) -> Bool {
        guard let bundleID else { return false }
        return builtinBlocklist.contains(bundleID) || extra.contains(bundleID)
    }
}
