import AppKit
import ImageIO
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
                    let decoded = Self.decodeArtwork(data: data, maxSide: 256)
                    await MainActor.run {
                        self.artworkDecoded(
                            decoded?.image, accent: decoded?.accent, for: data)
                    }
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

    /// Декод обложки целиком в фоне: даунсемпл до превью и акцентный цвет.
    ///
    /// Через ImageIO, а не через `NSImage.lockFocus()`. Прежняя реализация
    /// рисовала средствами AppKit из `Task.detached` — рисование NSImage вне
    /// главного потока не поддерживается, и результат зависел от того, что в
    /// этот момент делал UI. ImageIO потокобезопасен, декодирует прямо в
    /// нужный размер (а не в полный, чтобы потом ужать) и не тащит картинку
    /// через TIFF ради усреднения цвета.
    ///
    /// Даунсемпл нужен, потому что исходники бывают 1200px+, а рисуем максимум
    /// 64pt — таскать полноразмер сквозь пружины дорого (боль boring.notch #1427).
    nonisolated static func decodeArtwork(
        data: Data, maxSide: Int
    ) -> (image: NSImage, accent: NSColor?)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            // Всегда из самой картинки: встроенная EXIF-миниатюра бывает
            // обрезанной или вовсе от другого кадра.
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSide,
            // Декодировать здесь, в фоне, а не лениво при первой отрисовке —
            // иначе работа всё равно всплывёт на главном потоке.
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(
            source, 0, options as CFDictionary) else { return nil }
        let image = NSImage(
            cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        return (image, accentColor(of: cg))
    }

    /// Средний цвет обложки, осветлённый и насыщенный под чёрный фон острова.
    /// Считается по отрисовке в контекст 16x16: усреднение и подвыборка одним
    /// движением, без промежуточного TIFF.
    nonisolated private static func accentColor(of image: CGImage) -> NSColor? {
        let side = 16
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let context = pixels.withUnsafeMutableBytes({ buffer in
            CGContext(
                data: buffer.baseAddress, width: side, height: side,
                bitsPerComponent: 8, bytesPerRow: side * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        }) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))

        var r = 0.0, g = 0.0, b = 0.0
        for pixel in stride(from: 0, to: pixels.count, by: 4) {
            r += Double(pixels[pixel])
            g += Double(pixels[pixel + 1])
            b += Double(pixels[pixel + 2])
        }
        let total = Double(side * side) * 255
        let base = NSColor(
            red: r / total, green: g / total, blue: b / total, alpha: 1)
        return NSColor(
            hue: base.hueComponent,
            saturation: min(base.saturationComponent * 1.3, 1),
            brightness: max(base.brightnessComponent, 0.8),
            alpha: 1)
    }
}

enum MediaCommand: Int, Sendable {
    case play = 0, pause = 1, toggle = 2, next = 4, previous = 5, shuffle = 6
}

enum TrackDirection: Sendable {
    case forward, backward
}
