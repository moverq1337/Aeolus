import SwiftUI

@MainActor
final class AppServices {
    static let shared = AppServices()
    var panelController: PanelController?
    let nowPlaying = NowPlayingStore()
    private(set) var engine: MediaEngine?

    private init() {}

    func start() {
        if let paths = AdapterPaths.bundled() {
            let engine = MediaEngine(paths: paths, store: nowPlaying)
            self.engine = engine
            Task { await engine.start() }
        } else {
            nowPlaying.mediaAvailable = false
        }
        panelController = PanelController { metrics in
            AnyView(IslandRootView(metrics: metrics))
        }
    }

    func stopEngine() {
        Task { await engine?.stop() }
    }
}
