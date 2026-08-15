import Foundation
import IOKit

/// Заряд Bluetooth-аудио из IORegistry (AppleDeviceManagementHIDEventService):
/// BatteryPercent / BatteryPercentLeft/Right/Case — без разрешений, разово по событию.
enum BluetoothAudioBattery {
    struct Levels: Equatable {
        var left: Int?
        var right: Int?
        var caseLevel: Int?
        var single: Int?

        /// Минимум из известных уровней наушников (без кейса) — «честный» процент.
        var headline: Int? {
            let buds = [left, right].compactMap { $0 }
            if !buds.isEmpty { return buds.min() }
            return single
        }
    }

    static func levels(matchingName name: String?) -> Levels? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("AppleDeviceManagementHIDEventService"),
            &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        var best: Levels?
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            func prop(_ key: String) -> Int? {
                IORegistryEntryCreateCFProperty(
                    service, key as CFString, kCFAllocatorDefault, 0)?
                    .takeRetainedValue() as? Int
            }
            func strProp(_ key: String) -> String? {
                IORegistryEntryCreateCFProperty(
                    service, key as CFString, kCFAllocatorDefault, 0)?
                    .takeRetainedValue() as? String
            }
            let levels = Levels(
                left: prop("BatteryPercentLeft"),
                right: prop("BatteryPercentRight"),
                caseLevel: prop("BatteryPercentCase"),
                single: prop("BatteryPercent"))
            guard levels.headline != nil else { continue }
            if let name, let product = strProp("Product"),
               product.lowercased().contains(name.lowercased())
                || name.lowercased().contains(product.lowercased()) {
                return levels // точное совпадение по имени устройства
            }
            if best == nil { best = levels }
        }
        return best
    }
}
