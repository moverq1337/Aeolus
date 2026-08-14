import SwiftUI

@MainActor
final class AppServices {
    static let shared = AppServices()
    var panelController: PanelController?

    private init() {}

    func start() {
        panelController = PanelController { metrics in
            AnyView(IslandRootView(metrics: metrics))
        }
    }
}
