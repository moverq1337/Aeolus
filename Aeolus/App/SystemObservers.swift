import AppKit

/// Все системные подписки в одном месте: сон, блокировка, смена Space.
@MainActor
final class SystemObservers {
    private(set) var isLocked = false
    private let onSleep: () -> Void
    private let onWake: () -> Void
    private let onVisibilityCheckNeeded: () -> Void
    private let onUnlocked: () -> Void
    private let onLocked: () -> Void

    init(
        onSleep: @escaping () -> Void,
        onWake: @escaping () -> Void,
        onVisibilityCheckNeeded: @escaping () -> Void,
        onUnlocked: @escaping () -> Void = {},
        onLocked: @escaping () -> Void = {}
    ) {
        self.onSleep = onSleep
        self.onWake = onWake
        self.onVisibilityCheckNeeded = onVisibilityCheckNeeded
        self.onUnlocked = onUnlocked
        self.onLocked = onLocked

        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { _ in MainActor.assumeIsolated { self.onSleep() } }
        workspace.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { _ in MainActor.assumeIsolated { self.onWake() } }
        workspace.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { _ in MainActor.assumeIsolated { self.onVisibilityCheckNeeded() } }
        // Срабатывает раньше, чем com.apple.screenIsUnlocked (лаг после Touch ID) —
        // локскрин-виджет прячется без «лишней полсекунды».
        workspace.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main
        ) { _ in MainActor.assumeIsolated { self.onVisibilityCheckNeeded() } }

        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                let wasLocked = self.isLocked
                self.isLocked = true
                self.onVisibilityCheckNeeded()
                if !wasLocked { self.onLocked() }
            }
        }
        dnc.addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                let wasLocked = self.isLocked
                self.isLocked = false
                self.onVisibilityCheckNeeded()
                if wasLocked { self.onUnlocked() }
            }
        }
    }
}
