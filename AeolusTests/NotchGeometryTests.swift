import Testing
import CoreGraphics
@testable import Aeolus

struct NotchGeometryTests {
    // Числа в духе MacBook Pro 14": экран 1512x982, вырез ~200pt, safe area 32pt.
    let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let expanded = CGSize(width: 400, height: 210)

    @Test func notchScreenProducesMetrics() throws {
        let m = try #require(NotchGeometry.metrics(
            screenFrame: screen, auxLeftWidth: 656, auxRightWidth: 656,
            safeAreaTop: 32, expandedSize: expanded))
        // 1512 - 656 - 656 + 4 (перекрытие) = 204
        #expect(m.closedSize == CGSize(width: 204, height: 32))
        #expect(m.notchRect == CGRect(x: 654, y: 950, width: 204, height: 32))
        // Окно: max(400, 204) + 2*20 запаса = 440 ширина; 210 + 20 = 230 высота
        #expect(m.windowFrame == CGRect(x: 536, y: 752, width: 440, height: 230))
    }

    @Test func noNotchReturnsNil() {
        #expect(NotchGeometry.metrics(
            screenFrame: screen, auxLeftWidth: nil, auxRightWidth: nil,
            safeAreaTop: 0, expandedSize: expanded) == nil)
        #expect(NotchGeometry.metrics(
            screenFrame: screen, auxLeftWidth: 0, auxRightWidth: 0,
            safeAreaTop: 24, expandedSize: expanded) == nil)
    }

    @Test func offsetScreenOriginIsRespected() throws {
        let offset = CGRect(x: 1512, y: -200, width: 1512, height: 982)
        let m = try #require(NotchGeometry.metrics(
            screenFrame: offset, auxLeftWidth: 656, auxRightWidth: 656,
            safeAreaTop: 32, expandedSize: expanded))
        #expect(m.notchRect.origin == CGPoint(x: 1512 + 654, y: -200 + 950))
        #expect(m.windowFrame.midX == offset.midX)
    }
}
