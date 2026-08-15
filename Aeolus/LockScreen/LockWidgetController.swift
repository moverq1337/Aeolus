import AppKit
import SwiftUI

@MainActor
final class LockWidgetController {
    private let content: @MainActor () -> AnyView
    private let hasSession: @MainActor () -> Bool
    private let space = SkyLightSpace.shared

    private var panel: LockWidgetPanel?
    private var visible = false
    private var hideTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?

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
        let decision = LockWidgetDecision.shouldShow(
            enabled: Preferences.lockScreenWidget,
            session: LockSession.current(),
            hasSession: hasSession(),
            spaceAvailable: space != nil)
        if decision { show() } else { scheduleHide() }
    }

    private func show() {
        hideTask?.cancel()
        let panel = ensurePanel()
        reposition(panel)
        guard !visible else { return }
        visible = true
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    private func scheduleHide() {
        guard visible else { return }
        hideTask?.cancel()
        // 150 мс — анти-мерцание на кроссфейде разблокировки (проверено boring.notch).
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            self?.visible = false
            self?.panel?.orderOut(nil)
        }
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
