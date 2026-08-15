import AppKit
import SwiftUI
import Observation

/// Управляет пружинным появлением контента виджета.
@MainActor
@Observable
final class LockWidgetPresentation {
    var shown = false
}

@MainActor
final class LockWidgetController {
    private let content: @MainActor () -> AnyView
    private let hasSession: @MainActor () -> Bool
    private let space = SkyLightSpace.shared

    private var panel: LockWidgetPanel?
    private var notchPanel: LockWidgetPanel?
    private var visible = false
    private var notchVisible = false
    private var pollTask: Task<Void, Never>?
    let presentation = LockWidgetPresentation()

    init(content: @escaping @MainActor () -> AnyView,
         hasSession: @escaping @MainActor () -> Bool) {
        self.content = content
        self.hasSession = hasSession
    }

    /// Короткое окно опроса после системного события: события врут по времени
    /// (unlock после Touch ID запаздывает), поэтому первую секунду тикаем каждые
    /// 100 мс — чтобы карточка не висела после разблокировки, — затем ещё 4 с
    /// по 500 мс, и тишина (инвариант простоя).
    func beginPollWindow() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            for tick in 0..<18 {
                guard !Task.isCancelled else { return }
                self?.refresh()
                try? await Task.sleep(for: .milliseconds(tick < 10 ? 100 : 500))
            }
        }
    }

    func refresh() {
        let session = LockSession.current()
        let decision = LockWidgetDecision.shouldShow(
            enabled: Preferences.lockScreenWidget,
            session: session,
            hasSession: hasSession(),
            spaceAvailable: space != nil)
        if decision { show() } else { hideNow() }

        let notchDecision = LockWidgetDecision.shouldShowNotchLock(
            enabled: Preferences.lockScreenWidget,
            session: session,
            spaceAvailable: space != nil)
        if notchDecision { showNotchLock() } else { hideNotchLock() }
    }

    private func show() {
        let panel = ensurePanel()
        reposition(panel)
        guard !visible else { return }
        visible = true
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        // Кадр «до» уже на экране (контент скрыт презентацией) — пружина без рывка.
        DispatchQueue.main.async { [presentation] in
            presentation.shown = true
        }
    }

    private func hideNow() {
        // Мгновенно: истина блокировки уже сверена по CGSession-словарю, а нашу
        // панель не нужно выдёргивать из пространства (в отличие от boring.notch,
        // чья 150-мс задержка страхует undelegate) — просто прячем. Ложное
        // срабатывание самоизлечивается ближайшим тиком опроса (~100 мс).
        guard visible else { return }
        visible = false
        presentation.shown = false
        panel?.orderOut(nil)
    }

    private func showNotchLock() {
        let panel = ensureNotchPanel()
        guard !notchVisible else { return }
        notchVisible = true
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    private func hideNotchLock() {
        guard notchVisible else { return }
        notchVisible = false
        notchPanel?.orderOut(nil)
    }

    private func ensureNotchPanel() -> LockWidgetPanel {
        if let notchPanel { return notchPanel }
        let notchSize = NSScreen.builtIn.flatMap { screen -> CGSize? in
            guard let left = screen.auxiliaryTopLeftArea?.width,
                  let right = screen.auxiliaryTopRightArea?.width,
                  screen.safeAreaInsets.top > 0 else { return nil }
            return CGSize(
                width: screen.frame.width - left - right + 4,
                height: screen.safeAreaInsets.top)
        } ?? CGSize(width: 200, height: 32)
        let earWidth: CGFloat = 44
        let size = CGSize(width: notchSize.width + 2 * earWidth, height: notchSize.height)
        let p = LockWidgetPanel(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.isMovable = false
        p.isReleasedWhenClosed = false
        p.ignoresMouseEvents = true // чистый индикатор
        p.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        p.sharingType = .none
        p.appearance = NSAppearance(named: .darkAqua)
        p.contentView = FirstMouseHostingView(
            rootView: LockNotchView(notchSize: notchSize, earWidth: earWidth))
        if let screen = NSScreen.builtIn {
            p.setFrame(CGRect(
                x: screen.frame.midX - size.width / 2,
                y: screen.frame.maxY - size.height,
                width: size.width, height: size.height), display: true)
        }
        notchPanel = p
        space?.delegate(p)
        return p
    }

    private func ensurePanel() -> LockWidgetPanel {
        if let panel { return panel }
        let p = LockWidgetPanel(
            contentRect: CGRect(origin: .zero, size: LockWidgetLayout.cardSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.isMovable = false
        p.isReleasedWhenClosed = false
        p.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        p.sharingType = .none // виджет не попадает в записи экрана
        p.appearance = NSAppearance(named: .darkAqua)
        p.contentView = FirstMouseHostingView(rootView: content())
        panel = p
        space?.delegate(p) // один раз кладём в 400-пространство
        return p
    }

    private func reposition(_ panel: LockWidgetPanel) {
        guard let screen = NSScreen.builtIn else { return }
        panel.setFrame(
            LockWidgetLayout.frame(
                screenFrame: screen.frame,
                userOffset: CGFloat(Preferences.lockScreenOffset)),
            display: true)
    }
}
