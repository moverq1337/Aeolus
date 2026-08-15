enum LockWidgetDecision {
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
