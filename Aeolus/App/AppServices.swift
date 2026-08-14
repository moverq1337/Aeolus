import SwiftUI

@MainActor
final class AppServices {
    static let shared = AppServices()
    var panelController: PanelController?
    let nowPlaying = NowPlayingStore()
    let islandVM = IslandViewModel()
    private(set) var engine: MediaEngine?
    private(set) var mediaActions = MediaActions()

    private init() {}

    func start() {
        Preferences.registerDefaults()

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

        panelController = PanelController { [self] metrics in
            AnyView(IslandRootView(
                metrics: metrics,
                vm: islandVM,
                nowPlaying: nowPlaying,
                media: mediaActions))
        }
    }

    func stopEngine() {
        Task { await engine?.stop() }
    }
}
