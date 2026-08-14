import SwiftUI

@MainActor
final class AppServices {
    static let shared = AppServices()
    var panelController: PanelController?
    let nowPlaying = NowPlayingStore()
    let islandVM = IslandViewModel()
    let volume = VolumeController()
    let power = PowerMonitor()
    let settingsWindow = SettingsWindowController()
    private(set) var engine: MediaEngine?
    private(set) var mediaActions = MediaActions()
    private var observers: SystemObservers?

    private init() {}

    func start() {
        Preferences.registerDefaults()
        volume.start()

        if let paths = AdapterPaths.bundled() {
            let engine = MediaEngine(paths: paths, store: nowPlaying)
            self.engine = engine
            mediaActions = MediaActions(
                toggle: { Task { await engine.send(.toggle) } },
                next: { Task { await engine.send(.next) } },
                previous: { Task { await engine.send(.previous) } },
                seek: { seconds in Task { await engine.seek(to: seconds) } })
            Task { await engine.start() }
        } else {
            nowPlaying.mediaAvailable = false
        }

        nowPlaying.onSessionChange = { [islandVM] hasSession, playing in
            islandVM.handle(.musicChanged(playing: playing, hasSession: hasSession))
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

        observers = SystemObservers(
            onSleep: { [weak self] in
                Task { await self?.engine?.stop() }
            },
            onWake: { [weak self] in
                Task { await self?.engine?.start() }
            },
            onVisibilityCheckNeeded: { [weak self] in
                guard let self else { return }
                self.panelController?.updateVisibility(
                    locked: self.observers?.isLocked ?? false)
            })
    }

    func stopEngine() {
        Task { await engine?.stop() }
    }
}
