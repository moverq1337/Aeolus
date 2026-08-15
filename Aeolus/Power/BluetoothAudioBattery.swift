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

    /// Запасной источник (AirPods Max и др.): system_profiler -json, одноразово
    /// по событию подключения. Ключи device_batteryLevelMain/Left/Right/Case.
    static func profilerHeadline(matchingName name: String) async -> Int? {
        let data: Data? = await Task.detached(priority: .utility) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
            proc.arguments = ["SPBluetoothDataType", "-json"]
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = FileHandle.nullDevice
            do { try proc.run() } catch { return nil }
            let output = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            return output
        }.value
        guard let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sections = json["SPBluetoothDataType"] as? [[String: Any]]
        else { return nil }
        for section in sections {
            guard let connected = section["device_connected"] as? [[String: Any]]
            else { continue }
            for device in connected {
                for (deviceName, rawProps) in device {
                    guard deviceName.lowercased().contains(name.lowercased())
                        || name.lowercased().contains(deviceName.lowercased()),
                        let props = rawProps as? [String: Any] else { continue }
                    func level(_ key: String) -> Int? {
                        guard let s = props[key] as? String else { return nil }
                        return Int(s.replacingOccurrences(of: "%", with: ""))
                    }
                    let buds = [level("device_batteryLevelLeft"),
                                level("device_batteryLevelRight")].compactMap { $0 }
                    if !buds.isEmpty { return buds.min() }
                    if let main = level("device_batteryLevelMain") { return main }
                }
            }
        }
        return nil
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
