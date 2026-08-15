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
                flash = BatteryFlash(
                    kind: .pluggedIn, percentage: p,
                    watts: Self.adapterWatts(), minutes: snap.minutesToFull)
            case .unplugged(let p):
                flash = BatteryFlash(
                    kind: .unplugged, percentage: p, minutes: snap.minutesToEmpty)
            case .lowBattery(let p, let critical):
                guard Preferences.batteryAlerts else { continue }
                flash = BatteryFlash(
                    kind: critical ? .critical : .low, percentage: p,
                    minutes: snap.minutesToEmpty)
            }
            onFlash?(flash)
        }
    }

    /// Мощность подключённого адаптера (Вт), если система её сообщает.
    static func adapterWatts() -> Int? {
        guard let details = IOPSCopyExternalPowerAdapterDetails()?
            .takeRetainedValue() as? [String: Any] else { return nil }
        return details[kIOPSPowerAdapterWattsKey] as? Int
    }

    /// Здоровье батареи из AppleSmartBattery: (процент ёмкости, циклы).
    static func batteryHealth() -> (capacityPercent: Int, cycles: Int)? {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        func prop(_ key: String) -> Int? {
            IORegistryEntryCreateCFProperty(
                service, key as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? Int
        }
        guard let cycles = prop("CycleCount") else { return nil }
        // Яблочная математика здоровья: текущая максимальная ёмкость к паспортной.
        let nominal = prop("NominalChargeCapacity") ?? prop("AppleRawMaxCapacity")
        let design = prop("DesignCapacity")
        guard let nominal, let design, design > 0 else { return nil }
        let percent = Int((Double(nominal) / Double(design) * 100).rounded())
        return (min(percent, 100), cycles)
    }

    static func currentSnapshot() -> PowerSnapshot? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        for ps in list {
            // Get (не Copy) — объект не удерживается, takeUnretainedValue обязательно.
            guard let desc = IOPSGetPowerSourceDescription(info, ps)?
                .takeUnretainedValue() as? [String: Any] else { continue }
            // Только встроенная батарея: внешние источники (UPS и пр.) давали
            // мусорные проценты в транзиенте.
            guard (desc[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType
            else { continue }
            if let snap = PowerSnapshot(description: desc) { return snap }
        }
        return nil
    }
}
