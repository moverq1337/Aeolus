import CoreGraphics

/// Истина о блокировке из публичного CGSessionCopyCurrentDictionary.
/// Событиям screenIsLocked/Unlocked доверять нельзя: первое приходит уже при
/// старте заставки, второе после Touch ID иногда опаздывает (спека §3.3).
struct LockSession: Equatable {
    var isLocked: Bool
    var onConsole: Bool

    init(dictionary: [String: Any]) {
        isLocked = (dictionary["CGSSessionScreenIsLocked"] as? Int ?? 0) != 0
        onConsole = (dictionary["kCGSSessionOnConsoleKey"] as? Int ?? 0) != 0
    }

    static func current() -> LockSession? {
        guard let dict = CGSessionCopyCurrentDictionary() as? [String: Any] else { return nil }
        return LockSession(dictionary: dict)
    }
}
