import Foundation

/// Фильтр источников Now Playing.
/// Конференции — всегда мимо острова (звонок не музыка). Мессенджеры — умно:
/// голосовые и кружки Telegram публикуются с маркером в поле artist
/// («video message» — проверено на живом payload), настоящая музыка проходит.
/// Пользовательское расширение: defaults write io.github.moverq1337.aeolus
/// ignoredBundleIDs -array "com.example.app" (блокирует жёстко).
enum MediaSourceFilter {
    static let conferencingBlocklist: Set<String> = [
        "org.jitsi.jitsi-meet",
        "us.zoom.xos",
        "com.microsoft.teams",
        "com.microsoft.teams2",
        "com.cisco.webexmeetingsapp",
        "com.apple.FaceTime",
        "com.skype.skype",
        "com.hnc.Discord",
        "com.tinyspeck.slackmacgap",
    ]

    static let messengerBundleIDs: Set<String> = [
        "ru.keepcoder.Telegram",
        "org.telegram.desktop",
        "net.whatsapp.WhatsApp",
        "org.whispersystems.signal-desktop",
    ]

    /// Маркеры не-музыки в поле artist у мессенджеров (нижний регистр).
    static let nonMusicMarkers: Set<String> = [
        "video message", "voice message",
        "видеосообщение", "голосовое сообщение",
    ]

    static func isBlocked(_ bundleID: String?, artist: String?, extra: [String]) -> Bool {
        guard let bundleID else { return false }
        if conferencingBlocklist.contains(bundleID) { return true }
        if extra.contains(bundleID) { return true }
        if messengerBundleIDs.contains(bundleID) {
            let marker = artist?.lowercased() ?? ""
            return nonMusicMarkers.contains(marker)
        }
        return false
    }
}
