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
    /// Живёт только внутри окна схождения геометрии — см. ScreenSettle.
    private var settleTask: Task<Void, Never>?
    /// Обработчик двухпальцевых свайпов; переустанавливается при rebuild.
    var onScroll: ((NSEvent) -> Void)?

    init(makeContent: @escaping @MainActor (NotchMetrics) -> AnyView) {
        self.makeContent = makeContent
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                AppServices.shared.panelController?.screenParametersChanged()
            }
        }
        apply(currentMetrics())
    }

    /// Смена разрешения, подключение монитора, клемшелл, пробуждение.
    /// Сверяемся сразу и ещё несколько раз по затухающему графику: AppKit
    /// сообщает о смене раньше, чем NSScreen начинает отдавать новую правду.
    func screenParametersChanged() {
        settleTask?.cancel()
        apply(currentMetrics())
        // Реконфигурация дисплея сбрасывает пространству уровень и видимость —
        // без этого остров уезжает под чужие окна.
        NotchSpace.shared.refresh()
        if let panel { NotchSpace.shared.attach(panel) }
        settleTask = Task { [weak self] in
            for delay in ScreenSettle.probeDelays {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled, let self else { return }
                apply(currentMetrics())
            }
            self?.settleTask = nil
        }
    }

    private func currentMetrics() -> NotchMetrics? {
        guard let screen = NSScreen.builtIn else { return nil }
        return NotchGeometry.metrics(
            screenFrame: screen.frame,
            auxLeftWidth: screen.auxiliaryTopLeftArea?.width,
            auxRightWidth: screen.auxiliaryTopRightArea?.width,
            safeAreaTop: screen.safeAreaInsets.top)
    }

    private func apply(_ fresh: NotchMetrics?) {
        guard ScreenSettle.step(current: metrics, fresh: fresh) == .rebuild else { return }
        metrics = fresh
        guard let fresh else {
            // Клемшелл, экран без выреза или момент перехода между режимами.
            panel?.orderOut(nil)
            panel = nil
            return
        }
        rebuild(with: fresh)
    }

    private func rebuild(with m: NotchMetrics) {
        panel?.orderOut(nil)
        panel = nil

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
        let host = FirstMouseHostingView(rootView: makeContent(m))
        host.onScroll = { [weak self] event in self?.onScroll?(event) }
        p.contentView = host
        p.setFrame(m.windowFrame, display: true)
        panel = p
        if !hidden { p.orderFrontRegardless() }
        // Собственное CGS-пространство: остров неподвижен при свайпах между Spaces.
        NotchSpace.shared.attach(p)
    }

    func setHidden(_ value: Bool) {
        hidden = value
        guard let panel else { return }
        if value {
            // Без прозрачности: остров сжимается в вырез (suppressed в редьюсере),
            // окно снимаем после того, как пружина доиграла.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, self.hidden else { return }
                    panel.orderOut(nil)
                }
            }
        } else {
            panel.alphaValue = 1
            panel.orderFrontRegardless()
        }
    }

    func updateVisibility(locked: Bool) {
        let shouldHide = locked
            || (Preferences.hideInFullscreen && FullscreenDetector.isBuiltInScreenFullscreen())
        setHidden(shouldHide)
    }
}
