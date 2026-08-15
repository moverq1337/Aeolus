enum LockWidgetDecision {
    /// Замочек у выреза на локскрине: не требует медиа-сессии.
    static func shouldShowNotchLock(
        enabled: Bool,
        session: LockSession?,
        spaceAvailable: Bool
    ) -> Bool {
        guard enabled, spaceAvailable, let session else { return false }
        return session.isLocked && session.onConsole
    }

    static func shouldShow(
        enabled: Bool,
        session: LockSession?,
        hasSession: Bool,
        spaceAvailable: Bool
    ) -> Bool {
        guard enabled, spaceAvailable, hasSession, let session else { return false }
        return session.isLocked && session.onConsole
    }
}
