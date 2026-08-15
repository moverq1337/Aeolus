import Testing
@testable import Aeolus

struct LockWidgetDecisionTests {
    @Test func parsesLockedOnConsole() {
        let s = LockSession(dictionary: [
            "CGSSessionScreenIsLocked": 1,
            "kCGSSessionOnConsoleKey": 1,
        ])
        #expect(s.isLocked)
        #expect(s.onConsole)
    }

    @Test func parsesUnlockedAbsentKeys() {
        // Ключ CGSSessionScreenIsLocked отсутствует, когда экран разблокирован.
        let s = LockSession(dictionary: ["kCGSSessionOnConsoleKey": 1])
        #expect(!s.isLocked)
        #expect(s.onConsole)
    }

    @Test func showsOnlyWhenLockedOnConsoleWithSessionAndSpace() {
        let locked = LockSession(dictionary: [
            "CGSSessionScreenIsLocked": 1, "kCGSSessionOnConsoleKey": 1])
        #expect(LockWidgetDecision.shouldShow(
            enabled: true, session: locked, hasSession: true, spaceAvailable: true))
    }

    @Test func hiddenWhenDisabled() {
        let locked = LockSession(dictionary: [
            "CGSSessionScreenIsLocked": 1, "kCGSSessionOnConsoleKey": 1])
        #expect(!LockWidgetDecision.shouldShow(
            enabled: false, session: locked, hasSession: true, spaceAvailable: true))
    }

    @Test func hiddenWhenNoMediaSession() {
        let locked = LockSession(dictionary: [
            "CGSSessionScreenIsLocked": 1, "kCGSSessionOnConsoleKey": 1])
        #expect(!LockWidgetDecision.shouldShow(
            enabled: true, session: locked, hasSession: false, spaceAvailable: true))
    }

    @Test func hiddenWhenSpaceUnavailable() {
        let locked = LockSession(dictionary: [
            "CGSSessionScreenIsLocked": 1, "kCGSSessionOnConsoleKey": 1])
        #expect(!LockWidgetDecision.shouldShow(
            enabled: true, session: locked, hasSession: true, spaceAvailable: false))
    }

    @Test func hiddenWhenUnlocked() {
        let unlocked = LockSession(dictionary: ["kCGSSessionOnConsoleKey": 1])
        #expect(!LockWidgetDecision.shouldShow(
            enabled: true, session: unlocked, hasSession: true, spaceAvailable: true))
    }

    @Test func hiddenWhenOffConsoleFastUserSwitching() {
        // Экран заблокирован, но сессия не на консоли (fast user switching) —
        // рисовать в чужой сессии нельзя.
        let other = LockSession(dictionary: ["CGSSessionScreenIsLocked": 1])
        #expect(!LockWidgetDecision.shouldShow(
            enabled: true, session: other, hasSession: true, spaceAvailable: true))
    }

    @Test func hiddenWhenSessionNil() {
        #expect(!LockWidgetDecision.shouldShow(
            enabled: true, session: nil, hasSession: true, spaceAvailable: true))
    }
}
