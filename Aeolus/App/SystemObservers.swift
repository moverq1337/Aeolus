import AppKit

/// Все системные подписки в одном месте: сон, блокировка, смена Space.
@MainActor
final class SystemObservers {
    private(set) var isLocked = false
    private let onSleep: () -> Void
    private let onWake: () -> Void
    private let onVisibilityCheckNeeded: () -> Void

    init(
        onSleep: @escaping () -> Void,
        onWake: @escaping () -> Void,
        onVisibilityCheckNeeded: @escaping () -> Void
    ) {
        self.onSleep = onSleep
        self.onWake = onWake
        self.onVisibilityCheckNeeded = onVisibilityCheckNeeded

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

        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                self.isLocked = true
                self.onVisibilityCheckNeeded()
            }
        }
        dnc.addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                self.isLocked = false
                self.onVisibilityCheckNeeded()
            }
        }
    }
}
