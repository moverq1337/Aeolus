import AppKit
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Aeolus

/// Декод обложки. Раньше он рисовал средствами AppKit (`NSImage.lockFocus`)
/// из фонового Task — рисование NSImage вне главного потока не поддерживается,
/// и весь этот путь не был покрыт ни одним тестом.
struct ArtworkDecodeTests {
    /// JPEG нужного размера и цвета — ровно то, что приезжает из адаптера
    /// base64-строкой.
    private func jpeg(side: Int, red: Double, green: Double, blue: Double) throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(red: red, green: green, blue: blue, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        let image = try #require(context.makeImage())
        let out = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(
            out, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return out as Data
    }

    @Test func largeArtworkIsDownsampledToThePreviewSize() throws {
        let data = try jpeg(side: 1200, red: 0.2, green: 0.4, blue: 0.9)
        let decoded = try #require(NowPlayingStore.decodeArtwork(data: data, maxSide: 256))
        #expect(decoded.image.size.width <= 256)
        #expect(decoded.image.size.height <= 256)
        #expect(decoded.image.size.width > 0)
    }

    @Test func smallArtworkIsNotUpscaled() throws {
        let data = try jpeg(side: 64, red: 0.5, green: 0.5, blue: 0.5)
        let decoded = try #require(NowPlayingStore.decodeArtwork(data: data, maxSide: 256))
        #expect(decoded.image.size.width == 64)
    }

    @Test func accentKeepsTheDominantHue() throws {
        let data = try jpeg(side: 300, red: 0.75, green: 0.1, blue: 0.1)
        let accent = try #require(
            NowPlayingStore.decodeArtwork(data: data, maxSide: 256)?.accent)
        let rgb = try #require(accent.usingColorSpace(.deviceRGB))
        #expect(rgb.redComponent > rgb.greenComponent)
        #expect(rgb.redComponent > rgb.blueComponent)
    }

    /// Остров живёт на чистом чёрном — тёмная обложка обязана быть осветлена,
    /// иначе акцентное свечение сливается с фоном.
    @Test func accentIsLiftedForDarkArtwork() throws {
        let data = try jpeg(side: 128, red: 0.05, green: 0.05, blue: 0.08)
        let accent = try #require(
            NowPlayingStore.decodeArtwork(data: data, maxSide: 256)?.accent)
        #expect(accent.brightnessComponent >= 0.8)
    }

    @Test func garbageDataDecodesToNothing() {
        #expect(NowPlayingStore.decodeArtwork(
            data: Data([0x00, 0x01, 0x02, 0x03]), maxSide: 256) == nil)
    }
}
