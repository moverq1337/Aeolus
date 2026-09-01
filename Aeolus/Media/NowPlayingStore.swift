import AppKit
import Observation
import SwiftUI

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
    /// Акцент из обложки (осветлён для чёрного фона); .white пока неизвестен.
    var displayAccent: Color = .white

    /// Уведомляет IslandViewModel о смене (hasSession, playing). Ставится в AppServices.
    @ObservationIgnored var onSessionChange: ((_ hasSession: Bool, _ playing: Bool) -> Void)?
    /// Смена отображаемого трека (после атомарного коммита тройки). Пилюля.
    @ObservationIgnored var onTrackChange: (() -> Void)?
    /// Смена отображаемой пары (название, исполнитель) — включая поздний
    /// приезд исполнителя у рваных источников. Тексты песен цепляются сюда:
    /// запрос к LRCLIB должен уйти по верной паре, а не по первой попавшейся.
    /// Пилюля на это НЕ реагирует — иначе она играла бы дважды на трек.
    @ObservationIgnored var onDisplayMetadataChange: (() -> Void)?
    /// Направление последней навигации — для карусельного перехода обложки.
    @ObservationIgnored var lastNavigationDirection: TrackDirection = .forward

    private var lastArtworkData: Data?
    private var decodedForData: Data?
    private var decodedAccent: NSColor?
    private var swapTask: Task<Void, Never>?

    func apply(_ newState: NowPlayingState?) {
        let oldKey = state.map { ($0.title, $0.playing) }
        state = newState

        if newState?.artworkData != lastArtworkData {
            lastArtworkData = newState?.artworkData
            if let data = newState?.artworkData {
                Task.detached(priority: .utility) {
                    let image = Self.downsampled(data: data, maxSide: 256)
                    let accent = image.flatMap { Self.accentColor(of: $0) }
                    await MainActor.run { self.artworkDecoded(image, accent: accent, for: data) }
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

    private func artworkDecoded(_ image: NSImage?, accent: NSColor?, for data: Data) {
        // Гонка быстрых переключений: декоды завершаются не по порядку, и поздний
        // результат устаревшего трека не должен перетирать актуальный.
        guard data == lastArtworkData else { return }
        artwork = image
        decodedAccent = accent
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
            let artistChanged = displayArtist != s.artist
            displayArtist = s.artist
            if artworkFresh {
                displayArtwork = artwork
                // Акцент едет вместе с обложкой. Раньше он ставился только в
                // commitDisplay — и у поздней обложки (рваный источник) кольцо
                // вокруг острова оставалось белым до конца трека.
                displayAccent = decodedAccent.map(Color.init) ?? .white
            } else if s.artworkData == nil {
                // Источник снял обложку — чужую не держим.
                displayArtwork = nil
                displayAccent = .white
            }
            if artistChanged { onDisplayMetadataChange?() }
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
        // Явная анимированная транзакция: коммит приходит из асинхронного
        // контекста, и только withAnimation гарантирует, что вставки/переходы
        // (пилюля, карусель) сыграют пружиной, а не телепортом.
        withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
            displayTitle = s.title
            displayArtist = s.artist
            displayArtwork = artworkFresh ? artwork : nil
            displayAccent = (artworkFresh ? decodedAccent.map(Color.init) : nil) ?? .white
            if let previousTitle, previousTitle != s.title {
                onTrackChange?()
            }
        }
        onDisplayMetadataChange?()
    }

    /// Даунсемпл до превью: исходники бывают 1200px+, а рисуем максимум 64pt —
    /// таскать полноразмер сквозь пружины дорого (боль boring.notch #1427).
    /// Средний цвет обложки, осветлённый и насыщенный под чёрный фон острова.
    nonisolated private static func accentColor(of image: NSImage) -> NSColor? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        var r = 0.0, g = 0.0, b = 0.0
        var count = 0.0
        let stepX = max(1, rep.pixelsWide / 16)
        let stepY = max(1, rep.pixelsHigh / 16)
        for x in stride(from: 0, to: rep.pixelsWide, by: stepX) {
            for y in stride(from: 0, to: rep.pixelsHigh, by: stepY) {
                guard let c = rep.colorAt(x: x, y: y)?
                    .usingColorSpace(.deviceRGB) else { continue }
                r += c.redComponent
                g += c.greenComponent
                b += c.blueComponent
                count += 1
            }
        }
        guard count > 0 else { return nil }
        let base = NSColor(red: r / count, green: g / count, blue: b / count, alpha: 1)
        let hue = base.hueComponent
        let sat = min(base.saturationComponent * 1.3, 1)
        let bright = max(base.brightnessComponent, 0.8)
        return NSColor(hue: hue, saturation: sat, brightness: bright, alpha: 1)
    }

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
    case play = 0, pause = 1, toggle = 2, next = 4, previous = 5, shuffle = 6
}

enum TrackDirection: Sendable {
    case forward, backward
}
