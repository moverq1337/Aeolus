import SwiftUI
import Testing
@testable import Aeolus

/// Регрессия: раскрытый остров не должен быть пустым чёрным прямоугольником.
/// Рендерим IslandRootView в expanded-состоянии и считаем небелые/нечёрные пиксели.
@MainActor
struct ExpandedRenderTests {
    @Test func expandedIslandRendersContent() throws {
        let store = NowPlayingStore()
        store.apply(NowPlayingState(
            bundleIdentifier: "test", playing: true, title: "Better Off",
            artist: "Montell Fish", album: nil, duration: 109, elapsedTime: 21,
            timestamp: Date(), artworkData: nil))

        let vm = IslandViewModel()
        vm.handle(.musicChanged(playing: true, hasSession: true))
        vm.handle(.hoverBegan)
        vm.handle(.dwellFired)
        #expect(vm.state.surface == .expanded)

        let metrics = try #require(NotchGeometry.metrics(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            auxLeftWidth: 656, auxRightWidth: 656, safeAreaTop: 32,
            expandedSize: IslandLayout.expandedSize))

        let view = IslandRootView(
            metrics: metrics, vm: vm, nowPlaying: store,
            media: MediaActions(), volume: VolumeController(),
            lyrics: LyricsEngine())

        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(metrics.windowFrame.size)
        let image = try #require(renderer.nsImage)
        let tiff = try #require(image.tiffRepresentation)
        let bitmap = try #require(NSBitmapImageRep(data: tiff))

        // Ищем светлые пиксели (белый текст/иконки) внутри области острова.
        var brightPixels = 0
        for x in stride(from: 0, to: bitmap.pixelsWide, by: 4) {
            for y in stride(from: 0, to: bitmap.pixelsHigh, by: 4) {
                if let c = bitmap.colorAt(x: x, y: y),
                   c.brightnessComponent > 0.6, c.alphaComponent > 0.5 {
                    brightPixels += 1
                }
            }
        }
        #expect(brightPixels > 20, "раскрытый остров отрендерился пустым (ярких пикселей: \(brightPixels))")
    }
}
