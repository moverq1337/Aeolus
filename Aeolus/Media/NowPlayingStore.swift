import AppKit
import Observation

@MainActor
@Observable
final class NowPlayingStore {
    var state: NowPlayingState?
    var artwork: NSImage?
    var mediaAvailable = true
    /// Уведомляет IslandViewModel о смене (hasSession, playing). Ставится в AppServices.
    @ObservationIgnored var onSessionChange: ((_ hasSession: Bool, _ playing: Bool) -> Void)?
    /// Смена трека внутри живой сессии (оба названия непустые и различаются).
    @ObservationIgnored var onTrackChange: (() -> Void)?
    /// Направление последней навигации — для карусельного перехода обложки.
    @ObservationIgnored var lastNavigationDirection: TrackDirection = .forward

    private var lastArtworkData: Data?

    func apply(_ newState: NowPlayingState?) {
        let oldKey = state.map { ($0.title, $0.playing) }
        state = newState

        if newState?.artworkData != lastArtworkData {
            lastArtworkData = newState?.artworkData
            if let data = newState?.artworkData {
                Task.detached(priority: .utility) {
                    let image = NSImage(data: data)
                    await MainActor.run { self.artwork = image }
                }
            } else {
                artwork = nil
            }
        }

        let newKey = newState.map { ($0.title, $0.playing) }
        if oldKey?.0 != newKey?.0 || oldKey?.1 != newKey?.1 {
            onSessionChange?(newState != nil, newState?.playing ?? false)
        }
        if let oldTitle = oldKey?.0, let newTitle = newKey?.0, oldTitle != newTitle {
            onTrackChange?()
        }
    }
}

enum MediaCommand: Int, Sendable {
    case play = 0, pause = 1, toggle = 2, next = 4, previous = 5
}

enum TrackDirection: Sendable {
    case forward, backward
}
