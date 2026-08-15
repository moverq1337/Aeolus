import Foundation
import IOKit.ps

struct PowerSnapshot: Equatable {
    var percentage: Int
    var isPluggedIn: Bool
    var isCharging: Bool
    /// Минуты до полной зарядки; nil = неизвестно/считается (-1 от powerd).
    var minutesToFull: Int?
    /// Минуты до разрядки; nil = неизвестно/считается.
    var minutesToEmpty: Int?

    init(percentage: Int, isPluggedIn: Bool, isCharging: Bool,
         minutesToFull: Int? = nil, minutesToEmpty: Int? = nil) {
        self.percentage = percentage
        self.isPluggedIn = isPluggedIn
        self.isCharging = isCharging
        self.minutesToFull = minutesToFull
        self.minutesToEmpty = minutesToEmpty
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
        let toFull = description[kIOPSTimeToFullChargeKey] as? Int ?? -1
        minutesToFull = toFull > 0 ? toFull : nil
        let toEmpty = description[kIOPSTimeToEmptyKey] as? Int ?? -1
        minutesToEmpty = toEmpty > 0 ? toEmpty : nil
    }
}
