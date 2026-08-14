import Foundation
import IOKit.ps

@MainActor
final class PowerMonitor {
    var onFlash: ((BatteryFlash) -> Void)?
    private var detector = PowerEventDetector()
    private var lastSnapshot: PowerSnapshot?
    private var source: CFRunLoopSource?

    func start() {
        refresh(emitEvents: false) // базовая линия: без транзиентов при запуске
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        guard let src = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(context).takeUnretainedValue()
            // Колбэк приходит на ран-лупе, куда добавлен source, — это main.
            MainActor.assumeIsolated { monitor.refresh(emitEvents: true) }
        }, ctx)?.takeRetainedValue() else { return }
        source = src
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .defaultMode)
    }

    func stop() {
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        }
        source = nil
    }

    private func refresh(emitEvents: Bool) {
        guard let snap = Self.currentSnapshot() else { return }
        let events = detector.events(from: lastSnapshot, to: snap)
        lastSnapshot = snap
        guard emitEvents else { return }
        for event in events {
            let flash: BatteryFlash
            switch event {
            case .pluggedIn(let p):
                flash = BatteryFlash(kind: .pluggedIn, percentage: p)
            case .unplugged(let p):
                flash = BatteryFlash(kind: .unplugged, percentage: p)
            case .lowBattery(let p, let critical):
                guard Preferences.batteryAlerts else { continue }
                flash = BatteryFlash(kind: critical ? .critical : .low, percentage: p)
            }
            onFlash?(flash)
        }
    }

    static func currentSnapshot() -> PowerSnapshot? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        for ps in list {
            // Get (не Copy) — объект не удерживается, takeUnretainedValue обязательно.
            if let desc = IOPSGetPowerSourceDescription(info, ps)?
                .takeUnretainedValue() as? [String: Any],
               let snap = PowerSnapshot(description: desc) {
                return snap
            }
        }
        return nil
    }
}
