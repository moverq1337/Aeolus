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
    let lyrics = LyricsEngine()
    let settingsWindow = SettingsWindowController()
    let updater = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    private(set) var engine: MediaEngine?
    private(set) var mediaActions = MediaActions()
    private var observers: SystemObservers?
    private var lockWidget: LockWidgetController?
    private var scrollRecognizer = ScrollGestureRecognizer()
    private let spaceHotKey = SpaceToggleHotKey()
    private var lastVolumeHapticBucket = -1

    private init() {}

    func start() {
        Preferences.registerDefaults()
        volume.onExternalChange = { [islandVM] value in
            islandVM.handle(.volumeGesture(Int((value * 100).rounded())))
        }
        volume.onDeviceChange = { [islandVM] name, icon in
            // Мгновенный транзиент; заряд доезжает асинхронно (system_profiler ~1.5 c)
            let quick = BluetoothAudioBattery.levels(matchingName: name)?.headline
            islandVM.handle(.deviceConnected(DeviceFlash(
                icon: icon, name: name, percentage: quick)))
            if quick == nil {
                Task {
                    guard let percent = await BluetoothAudioBattery
                        .profilerHeadline(matchingName: name) else { return }
                    islandVM.handle(.deviceConnected(DeviceFlash(
                        icon: icon, name: name, percentage: percent)))
                }
            }
        }
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

        var lockWidgetRef: LockWidgetController?
        let lockWidget = LockWidgetController(
            content: { [nowPlaying] in
                AnyView(LockWidgetView(
                    nowPlaying: nowPlaying,
                    media: AppServices.shared.mediaActions,
                    presentation: lockWidgetRef?.presentation))
            },
            hasSession: { [nowPlaying] in nowPlaying.state != nil })
        lockWidgetRef = lockWidget
        self.lockWidget = lockWidget

        nowPlaying.onSessionChange = { [islandVM, weak lockWidget] hasSession, playing in
            islandVM.handle(.musicChanged(playing: playing, hasSession: hasSession))
            lockWidget?.refresh()
        }

        nowPlaying.onTrackChange = { [islandVM, nowPlaying, lyrics] in
            islandVM.handle(.trackChanged)
            lyrics.trackChanged(
                title: nowPlaying.displayTitle,
                artist: nowPlaying.displayArtist,
                duration: nowPlaying.state?.duration)
        }

        spaceHotKey.onPressed = { [weak self] in
            self?.mediaActions.toggle()
            NSHapticFeedbackManager.defaultPerformer
                .perform(.alignment, performanceTime: .now)
        }
        islandVM.onSurfaceChange = { [spaceHotKey] surface in
            if case .expanded = surface {
                spaceHotKey.register()
            } else {
                spaceHotKey.unregister()
            }
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
                volume: volume,
                lyrics: lyrics))
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
            },
            onUnlocked: { [islandVM] in
                // Замок открывается на месте (~0.7 с) → пилюля всасывается в
                // вырез (~0.4 с) → и только теперь распускаются уши острова.
                let delay: Duration = Preferences.lockScreenWidget
                    ? .milliseconds(1100) : .milliseconds(100)
                Task { @MainActor in
                    try? await Task.sleep(for: delay)
                    islandVM.handle(.screenUnlocked)
                }
            },
            onLocked: { [islandVM] in
                islandVM.handle(.screenLocked)
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
            let raw = volume.volume + delta
            let newValue = min(max(raw, 0), 1)
            volume.setVolume(newValue)
            islandVM.handle(.volumeGesture(Int((newValue * 100).rounded())))
            // Rubber-band: упёрлись в край — копим овершут с затуханием (iOS-физика).
            if raw < 0 || raw > 1 {
                let past = raw < 0 ? Double(raw) : Double(raw - 1)
                let current = islandVM.state.volumeOvershoot
                let dampened = current + past * 0.35 * (1 - abs(current))
                islandVM.handle(.volumeOvershoot(max(-1, min(1, dampened))))
            } else if islandVM.state.volumeOvershoot != 0 {
                // Плавное затухание вместо мгновенного сброса.
                let decayed = islandVM.state.volumeOvershoot * 0.5
                islandVM.handle(.volumeOvershoot(abs(decayed) < 0.02 ? 0 : decayed))
            }
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
