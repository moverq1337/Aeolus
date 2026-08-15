import Foundation

enum Preferences {
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            "hoverDelay": 0.45,
            "expandOnHover": true,
            "hideInFullscreen": false,
            "batteryAlerts": true,
            "lockScreenWidget": false,
            "lockScreenOffset": 0.0,
        ])
    }

    static var hoverDelay: TimeInterval {
        UserDefaults.standard.double(forKey: "hoverDelay")
    }

    static var expandOnHover: Bool {
        UserDefaults.standard.bool(forKey: "expandOnHover")
    }

    static var hideInFullscreen: Bool {
        UserDefaults.standard.bool(forKey: "hideInFullscreen")
    }

    static var batteryAlerts: Bool {
        UserDefaults.standard.bool(forKey: "batteryAlerts")
    }

    static var lockScreenWidget: Bool {
        UserDefaults.standard.bool(forKey: "lockScreenWidget")
    }

    static var lockScreenOffset: Double {
        UserDefaults.standard.double(forKey: "lockScreenOffset")
    }
}
