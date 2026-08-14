import ServiceManagement
import Foundation

enum LaunchAtLogin {
    /// Источник истины — система, не UserDefaults: пользователь может
    /// выключить логин-айтем в System Settings в любой момент.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(enabled: Bool) {
        #if DEBUG
        // Дебаг-сборки не регистрируем: остаются мёртвые Login Items на DerivedData.
        NSLog("LaunchAtLogin: skipped in DEBUG build")
        #else
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("LaunchAtLogin error: \(error.localizedDescription)")
        }
        #endif
    }
}
