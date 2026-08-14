import Testing
import CoreGraphics
@testable import Aeolus

struct FullscreenDetectorTests {
    let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)

    private func window(
        layer: Int = 0, pid: Int = 500, rect: CGRect
    ) -> [String: Any] {
        [
            "kCGWindowLayer": layer,
            "kCGWindowOwnerPID": pid,
            "kCGWindowBounds": [
                "X": rect.origin.x, "Y": rect.origin.y,
                "Width": rect.width, "Height": rect.height,
            ] as [String: Any],
        ]
    }

    @Test func fullscreenWindowDetected() {
        #expect(FullscreenDetector.hasFullscreenWindow(
            windows: [window(rect: screen)], screenBounds: screen, ownPID: 1))
    }

    @Test func normalWindowIgnored() {
        // Максимизированное (но не fullscreen) окно не накрывает зону меню-бара.
        let maximized = CGRect(x: 0, y: 38, width: 1512, height: 944)
        #expect(!FullscreenDetector.hasFullscreenWindow(
            windows: [window(rect: maximized)], screenBounds: screen, ownPID: 1))
    }

    @Test func ownWindowIgnored() {
        #expect(!FullscreenDetector.hasFullscreenWindow(
            windows: [window(pid: 42, rect: screen)], screenBounds: screen, ownPID: 42))
    }

    @Test func nonBaseLayerIgnored() {
        // Меню-бар/оверлеи живут на слоях > 0.
        #expect(!FullscreenDetector.hasFullscreenWindow(
            windows: [window(layer: 25, rect: screen)], screenBounds: screen, ownPID: 1))
    }
}
