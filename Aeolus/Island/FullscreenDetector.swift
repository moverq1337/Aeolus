import AppKit
import CoreGraphics

/// Детект полноэкранного приложения на встроенном экране БЕЗ приватных API
/// и без разрешений: CGWindowList отдаёт геометрию окон свободно
/// (имена окон потребовали бы Screen Recording — они нам не нужны).
enum FullscreenDetector {
    /// Чистая, тестируемая часть. Ключи совпадают с kCGWindow* константами.
    static func hasFullscreenWindow(
        windows: [[String: Any]], screenBounds: CGRect, ownPID: Int
    ) -> Bool {
        windows.contains { w in
            guard let layer = w["kCGWindowLayer"] as? Int, layer == 0,
                  let pid = w["kCGWindowOwnerPID"] as? Int, pid != ownPID,
                  let boundsDict = w["kCGWindowBounds"] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else { return false }
            return rect == screenBounds
        }
    }

    @MainActor
    static func isBuiltInScreenFullscreen() -> Bool {
        guard let screen = NSScreen.builtIn,
              let number = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else { return false }
        // CGDisplayBounds — те же CG-координаты (origin сверху-слева), что и kCGWindowBounds.
        let bounds = CGDisplayBounds(number.uint32Value)
        let raw = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
        let windows = (raw as? [[String: Any]]) ?? []
        return hasFullscreenWindow(
            windows: windows,
            screenBounds: bounds,
            ownPID: Int(ProcessInfo.processInfo.processIdentifier))
    }
}
