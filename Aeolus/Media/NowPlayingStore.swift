import AppKit
import Observation

@MainActor
@Observable
final class NowPlayingStore {
    var state: NowPlayingState?
    var artwork: NSImage?
    var mediaAvailable = true

    // «Отображаемый трек»: тройка коммитится атомарно, когда обложка доехала
    // (или по таймауту), — UI никогда не показывает новый текст со старой обложкой.
    var displayTitle: String?
    var displayArtist: String?
    var displayArtwork: NSImage?

    /// Уведомляет IslandViewModel о смене (hasSession, playing). Ставится в AppServices.
    @ObservationIgnored var onSessionChange: ((_ hasSession: Bool, _ playing: Bool) -> Void)?
    /// Смена отображаемого трека (после атомарного коммита тройки).
    @ObservationIgnored var onTrackChange: (() -> Void)?
    /// Направление последней навигации — для карусельного перехода обложки.
    @ObservationIgnored var lastNavigationDirection: TrackDirection = .forward

    private var lastArtworkData: Data?
    private var decodedForData: Data?
    private var swapTask: Task<Void, Never>?

    func apply(_ newState: NowPlayingState?) {
        let oldKey = state.map { ($0.title, $0.playing) }
        state = newState

        if newState?.artworkData != lastArtworkData {
            lastArtworkData = newState?.artworkData
            if let data = newState?.artworkData {
                Task.detached(priority: .utility) {
                    let image = Self.downsampled(data: data, maxSide: 256)
                    await MainActor.run { self.artworkDecoded(image, for: data) }
                }
            } else {
                artwork = nil
                decodedForData = nil
            }
        }

        let newKey = newState.map { ($0.title, $0.playing) }
        if oldKey?.0 != newKey?.0 || oldKey?.1 != newKey?.1 {
            onSessionChange?(newState != nil, newState?.playing ?? false)
        }
        syncDisplay()
    }

    private func artworkDecoded(_ image: NSImage?, for data: Data) {
        artwork = image
        decodedForData = data
        syncDisplay()
    }

    private func syncDisplay() {
        guard let s = state else {
            swapTask?.cancel()
            swapTask = nil
            displayTitle = nil
            displayArtist = nil
            displayArtwork = nil
            return
        }

        let artworkFresh = s.artworkData != nil && decodedForData == s.artworkData

        if s.title == displayTitle {
            // Тот же трек: метаданные/обложка могли доехать позже.
            displayArtist = s.artist
            if artworkFresh { displayArtwork = artwork }
            return
        }

        // Новый трек: коммитим сразу, если обложка готова, иначе ждём её недолго.
        if artworkFresh {
            commitDisplay()
        } else if swapTask == nil {
            swapTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled else { return }
                self?.commitDisplay()
            }
        }
    }

    private func commitDisplay() {
        swapTask?.cancel()
        swapTask = nil
        guard let s = state else { return }
        let previousTitle = displayTitle
        let artworkFresh = s.artworkData != nil && decodedForData == s.artworkData
        displayTitle = s.title
        displayArtist = s.artist
        displayArtwork = artworkFresh ? artwork : nil
        if let previousTitle, previousTitle != s.title {
            onTrackChange?()
        }
    }

    /// Даунсемпл до превью: исходники бывают 1200px+, а рисуем максимум 64pt —
    /// таскать полноразмер сквозь пружины дорого (боль boring.notch #1427).
    nonisolated private static func downsampled(data: Data, maxSide: CGFloat) -> NSImage? {
        guard let source = NSImage(data: data) else { return nil }
        let size = source.size
        guard size.width > maxSide || size.height > maxSide else { return source }
        let scale = maxSide / max(size.width, size.height)
        let target = NSSize(width: size.width * scale, height: size.height * scale)
        let result = NSImage(size: target)
        result.lockFocus()
        source.draw(in: NSRect(origin: .zero, size: target),
                    from: .zero, operation: .copy, fraction: 1)
        result.unlockFocus()
        return result
    }
}

enum MediaCommand: Int, Sendable {
    case play = 0, pause = 1, toggle = 2, next = 4, previous = 5
}

enum TrackDirection: Sendable {
    case forward, backward
}
