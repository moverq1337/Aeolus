import Foundation
import IOKit.ps

struct PowerSnapshot: Equatable {
    var percentage: Int
    var isPluggedIn: Bool
    var isCharging: Bool

    init(percentage: Int, isPluggedIn: Bool, isCharging: Bool) {
        self.percentage = percentage
        self.isPluggedIn = isPluggedIn
        self.isCharging = isCharging
    }

    /// kIOPSCurrentCapacityKey == "Current Capacity" и т.д. — строковые ключи IOKit.
    init?(description: [String: Any]) {
        guard let current = description[kIOPSCurrentCapacityKey] as? Int,
              let max = description[kIOPSMaxCapacityKey] as? Int, max > 0,
              let state = description[kIOPSPowerSourceStateKey] as? String
        else { return nil }
        percentage = Int((Double(current) / Double(max) * 100).rounded())
        isPluggedIn = state == kIOPSACPowerValue
        isCharging = description[kIOPSIsChargingKey] as? Bool ?? false
    }
}
