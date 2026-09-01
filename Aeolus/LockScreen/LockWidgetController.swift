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
    private let notchPresentation = LockNotchPresentation()
    private var unlockSound: NSSound?
    /// Геометрия выреза, под которую собран notchPanel; nil — панели ещё нет.
    private var notchGeometry: CGSize?
    private var screenObserver: (any NSObjectProtocol)?
    private var settleTask: Task<Void, Never>?
    private static let notchEarWidth: CGFloat = 44

    init(content: @escaping @MainActor () -> AnyView,
         hasSession: @escaping @MainActor () -> Bool) {
        self.content = content
        self.hasSession = hasSession
        // Панели виджета собираются один раз и живут до выхода — без этого
        // после смены разрешения пилюля у выреза остаётся прежнего размера,
        // а карточка — на прежнем месте.
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.screenParametersChanged() }
        }
    }

    /// Та же логика схождения, что у острова (см. ScreenSettle): NSScreen
    /// отдаёт новую геометрию не в момент нотификации.
    private func screenParametersChanged() {
        settleTask?.cancel()
        applyScreenGeometry()
        settleTask = Task { [weak self] in
            for delay in ScreenSettle.probeDelays {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled, let self else { return }
                applyScreenGeometry()
            }
            self?.settleTask = nil
        }
    }

    private func applyScreenGeometry() {
        if let panel, visible { reposition(panel) }
        guard let notchPanel, notchGeometry != Self.notchSize() else { return }
        layOutNotchPanel(notchPanel)
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
        notchPresentation.grown = false
        notchPresentation.opened = false
        panel.alphaValue = 1
        panel.orderFrontRegardless() // голый вырез — визуально ничего
        // Хореография: остров сжался (~0.5 с) → пилюля вырастает из выреза.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.notchVisible else { return }
                self.notchPresentation.grown = true
            }
        }
    }

    private func hideNotchLock() {
        guard notchVisible else { return }
        notchVisible = false
        // Непрерывная история разблокировки: замок открывается НА МЕСТЕ,
        // держится мгновение, затем пилюля всасывается в вырез.
        notchPresentation.opened = true
        // «Тсык» в момент открытия дужки: сухой системный клик (ближайший к
        // iPhone-щелчку из имеющихся на каждом Маке). Проигрываем с диска
        // пользователя — в бандл ничего не вшиваем (копирайт Apple). Нет файла —
        // пробуем запасной, иначе тишина.
        let candidates = [
            "/System/Library/PrivateFrameworks/ScreenReader.framework"
                + "/Versions/A/Resources/Sounds/SingleClick.aiff",
            "/System/Library/Frameworks/SecurityInterface.framework"
                + "/Versions/A/Resources/lockOpening.aif",
        ]
        if let path = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }),
           let sound = NSSound(contentsOfFile: path, byReference: true) {
            sound.volume = 0.6
            unlockSound = sound
            sound.play()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.notchVisible else { return }
                self.notchPresentation.grown = false
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.notchVisible else { return }
                self.notchPanel?.orderOut(nil)
                self.notchPresentation.opened = false
            }
        }
    }

    /// Размер выреза встроенного экрана. Запасное значение — на случай, когда
    /// экрана с вырезом нет вовсе (панель тогда всё равно не показывается).
    private static func notchSize() -> CGSize {
        let metrics = NSScreen.builtIn.flatMap { screen in
            NotchGeometry.metrics(
                screenFrame: screen.frame,
                auxLeftWidth: screen.auxiliaryTopLeftArea?.width,
                auxRightWidth: screen.auxiliaryTopRightArea?.width,
                safeAreaTop: screen.safeAreaInsets.top)
        }
        return metrics?.closedSize ?? CGSize(width: 200, height: 32)
    }

    /// Пересобирает содержимое и фрейм пилюли под текущий вырез. Панель при
    /// этом та же — она уже делегирована в 400-пространство, а состояние
    /// анимации живёт снаружи, в notchPresentation.
    private func layOutNotchPanel(_ panel: LockWidgetPanel) {
        let notchSize = Self.notchSize()
        notchGeometry = notchSize
        let size = CGSize(
            width: notchSize.width + 2 * Self.notchEarWidth, height: notchSize.height)
        panel.contentView = FirstMouseHostingView(
            rootView: LockNotchView(
                notchSize: notchSize,
                earWidth: Self.notchEarWidth,
                presentation: notchPresentation))
        guard let screen = NSScreen.builtIn else { return }
        panel.setFrame(CGRect(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height,
            width: size.width, height: size.height), display: true)
    }

    private func ensureNotchPanel() -> LockWidgetPanel {
        if let notchPanel { return notchPanel }
        let p = LockWidgetPanel(
            contentRect: CGRect(origin: .zero, size: Self.notchSize()),
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
        layOutNotchPanel(p)
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
