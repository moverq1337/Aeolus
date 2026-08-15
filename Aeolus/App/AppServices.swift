import SwiftUI
import Sparkle

@MainActor
final class AppServices {
    static let shared = AppServices()
    var panelController: PanelController?
    let nowPlaying = NowPlayingStore()
    let islandVM = IslandViewModel()
    let volume = VolumeController()
    let power = PowerMonitor()
    let settingsWindow = SettingsWindowController()
    let updater = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    private(set) var engine: MediaEngine?
    private(set) var mediaActions = MediaActions()
    private var observers: SystemObservers?
    private var lockWidget: LockWidgetController?
    private var scrollRecognizer = ScrollGestureRecognizer()
    private var lastVolumeHapticBucket = -1

    private init() {}

    func start() {
        Preferences.registerDefaults()
        volume.start()

        if let paths = AdapterPaths.bundled() {
            let engine = MediaEngine(paths: paths, store: nowPlaying)
            self.engine = engine
            mediaActions = MediaActions(
                toggle: { Task { await engine.send(.toggle) } },
                next: { [nowPlaying] in
                    nowPlaying.lastNavigationDirection = .forward
                    Task { await engine.send(.next) }
                },
                previous: { [nowPlaying] in
                    nowPlaying.lastNavigationDirection = .backward
                    Task { await engine.send(.previous) }
                },
                seek: { seconds in Task { await engine.seek(to: seconds) } },
                toggleShuffle: { Task { await engine.send(.shuffle) } })
            Task { await engine.start() }
        } else {
            nowPlaying.mediaAvailable = false
        }

        let lockWidget = LockWidgetController(
            content: { [nowPlaying] in
                AnyView(LockWidgetView(
                    nowPlaying: nowPlaying,
                    media: AppServices.shared.mediaActions))
            },
            hasSession: { [nowPlaying] in nowPlaying.state != nil })
        self.lockWidget = lockWidget

        nowPlaying.onSessionChange = { [islandVM, weak lockWidget] hasSession, playing in
            islandVM.handle(.musicChanged(playing: playing, hasSession: hasSession))
            lockWidget?.refresh()
        }

        nowPlaying.onTrackChange = { [islandVM] in
            islandVM.handle(.trackChanged)
        }

        power.onFlash = { [islandVM] flash in
            islandVM.handle(.battery(flash))
        }
        power.start()

        panelController = PanelController { [self] metrics in
            AnyView(IslandRootView(
                metrics: metrics,
                vm: islandVM,
                nowPlaying: nowPlaying,
                media: mediaActions,
                volume: volume))
        }

        panelController?.onScroll = { [weak self] event in
            self?.handleScroll(event)
        }

        observers = SystemObservers(
            onSleep: { [weak self] in
                Task { await self?.engine?.stop() }
            },
            onWake: { [weak self] in
                Task { await self?.engine?.start() }
                self?.lockWidget?.beginPollWindow()
            },
            onVisibilityCheckNeeded: { [weak self] in
                guard let self else { return }
                self.panelController?.updateVisibility(
                    locked: self.observers?.isLocked ?? false)
                self.lockWidget?.beginPollWindow()
            })
    }

    func stopEngine() {
        Task { await engine?.stop() }
    }

    // MARK: двухпальцевые свайпы по острову

    private func handleScroll(_ event: NSEvent) {
        guard event.momentumPhase.isEmpty else { return } // инерцию не считаем
        let phase: ScrollGestureRecognizer.Phase
        if event.phase.contains(.began) {
            phase = .began
        } else if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            phase = .ended
        } else if event.phase.contains(.changed) {
            phase = .changed
        } else {
            return // колёсико мыши без фаз — не жест
        }
        let actions = scrollRecognizer.handle(
            phase: phase,
            deltaX: event.scrollingDeltaX,
            deltaY: event.scrollingDeltaY,
            inverted: event.isDirectionInvertedFromDevice)
        for action in actions { apply(action) }
    }

    private func apply(_ action: ScrollGestureRecognizer.Action) {
        let haptics = NSHapticFeedbackManager.defaultPerformer
        switch action {
        case .volumeChange(let delta):
            let newValue = min(max(volume.volume + delta, 0), 1)
            volume.setVolume(newValue)
            islandVM.handle(.volumeGesture(Int((newValue * 100).rounded())))
            // Тактильные «ступеньки»: каждые 5%, на краях — чётче.
            let bucket = Int(newValue * 20)
            if bucket != lastVolumeHapticBucket {
                lastVolumeHapticBucket = bucket
                let pattern: NSHapticFeedbackManager.FeedbackPattern =
                    (newValue <= 0 || newValue >= 1) ? .alignment : .levelChange
                haptics.perform(pattern, performanceTime: .now)
            }
        case .nextTrack:
            mediaActions.next()
            haptics.perform(.alignment, performanceTime: .now)
        case .previousTrack:
            mediaActions.previous()
            haptics.perform(.alignment, performanceTime: .now)
        case .verticalGestureEnded:
            islandVM.handle(.volumeGestureEnded)
        }
    }
}
