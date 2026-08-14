import AppKit
import SwiftUI

extension NSScreen {
    static var builtIn: NSScreen? {
        NSScreen.screens.first { screen in
            guard let number = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
            return CGDisplayIsBuiltin(number.uint32Value) != 0
        }
    }
}

@MainActor
final class PanelController {
    private var panel: NotchPanel?
    private(set) var metrics: NotchMetrics?
    private let makeContent: @MainActor (NotchMetrics) -> AnyView
    private var hidden = false
    private var screenObserver: (any NSObjectProtocol)?

    init(makeContent: @escaping @MainActor (NotchMetrics) -> AnyView) {
        self.makeContent = makeContent
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                AppServices.shared.panelController?.rebuild()
            }
        }
        rebuild()
    }

    func rebuild() {
        panel?.orderOut(nil)
        panel = nil
        metrics = nil

        guard let screen = NSScreen.builtIn,
              let m = NotchGeometry.metrics(
                screenFrame: screen.frame,
                auxLeftWidth: screen.auxiliaryTopLeftArea?.width,
                auxRightWidth: screen.auxiliaryTopRightArea?.width,
                safeAreaTop: screen.safeAreaInsets.top,
                expandedSize: IslandLayout.expandedVolumeSize)
        else { return } // клемшелл или экран без выреза — острова нет

        metrics = m
        let p = NotchPanel(
            contentRect: m.windowFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)
        p.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 8)
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.isMovable = false
        p.isReleasedWhenClosed = false
        p.becomesKeyOnlyIfNeeded = true
        p.appearance = NSAppearance(named: .darkAqua)
        p.contentView = FirstMouseHostingView(rootView: makeContent(m))
        p.setFrame(m.windowFrame, display: true)
        panel = p
        if !hidden { p.orderFrontRegardless() }
        // Собственное CGS-пространство: остров неподвижен при свайпах между Spaces.
        NotchSpace.shared.attach(p)
    }

    func setHidden(_ value: Bool) {
        hidden = value
        if value { panel?.orderOut(nil) } else { panel?.orderFrontRegardless() }
    }

    func updateVisibility(locked: Bool) {
        let shouldHide = locked
            || (Preferences.hideInFullscreen && FullscreenDetector.isBuiltInScreenFullscreen())
        setHidden(shouldHide)
    }
}
