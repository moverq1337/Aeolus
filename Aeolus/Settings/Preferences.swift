import Foundation

enum Preferences {
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            "hoverDelay": 0.45,
            "hideInFullscreen": false,
            "batteryAlerts": true,
        ])
    }

    static var hoverDelay: TimeInterval {
        UserDefaults.standard.double(forKey: "hoverDelay")
    }

    static var hideInFullscreen: Bool {
        UserDefaults.standard.bool(forKey: "hideInFullscreen")
    }

    static var batteryAlerts: Bool {
        UserDefaults.standard.bool(forKey: "batteryAlerts")
    }
}
