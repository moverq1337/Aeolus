import SwiftUI
import Testing
@testable import Aeolus

@MainActor
struct LockWidgetRenderTests {
    @Test func rendersTrackContent() throws {
        let store = NowPlayingStore()
        store.apply(NowPlayingState(
            bundleIdentifier: "test", playing: true, title: "Racer Material",
            artist: "SKY RAE", album: nil, duration: 143, elapsedTime: 44,
            timestamp: Date(), artworkData: nil))

        let view = LockWidgetView(nowPlaying: store, media: MediaActions())
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(LockWidgetLayout.cardSize)
        let image = try #require(renderer.nsImage)
        let tiff = try #require(image.tiffRepresentation)
        let bitmap = try #require(NSBitmapImageRep(data: tiff))

        var bright = 0
        for x in stride(from: 0, to: bitmap.pixelsWide, by: 4) {
            for y in stride(from: 0, to: bitmap.pixelsHigh, by: 4) {
                if let c = bitmap.colorAt(x: x, y: y),
                   c.brightnessComponent > 0.6, c.alphaComponent > 0.5 {
                    bright += 1
                }
            }
        }
        #expect(bright > 20, "карточка отрендерилась пустой (ярких пикселей: \(bright))")
    }
}
