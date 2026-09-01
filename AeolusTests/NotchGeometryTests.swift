import Testing
import CoreGraphics
@testable import Aeolus

struct NotchGeometryTests {
    // Числа в духе MacBook Pro 14": экран 1512x982, вырез ~200pt, safe area 32pt.
    let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)

    @Test func notchScreenProducesMetrics() throws {
        let m = try #require(NotchGeometry.metrics(
            screenFrame: screen, auxLeftWidth: 656, auxRightWidth: 656,
            safeAreaTop: 32))
        // Голый вырез 1512 - 656 - 656 = 200pt; перекрытие round(200 * 4/185) = 4.
        #expect(m.closedSize == CGSize(width: 204, height: 32))
        #expect(m.notchRect == CGRect(x: 654, y: 950, width: 204, height: 32))
        // Окно — по самому широкому состоянию (пилюля смены трека, 380pt)
        // плюс 20pt тени с каждой стороны: 420 ширина, 214 + 20 = 234 высота.
        #expect(m.windowFrame == CGRect(x: 546, y: 748, width: 420, height: 234))
    }

    /// Окно обязано вмещать ЛЮБОЕ состояние острова: SwiftUI за его границы не
    /// рисует. Раньше ширина считалась от фиксированного размера плеера, и на
    /// крупном вырезе уши батарейного транзиента обрезались.
    @Test func windowFitsEverySurface() throws {
        for (frame, bare, safeTop) in [(1512.0, 185.0, 32.0), (1800.0, 220.0, 38.0),
                                       (3024.0, 370.0, 64.0)] {
            let aux = (frame - bare) / 2
            let m = try #require(NotchGeometry.metrics(
                screenFrame: CGRect(x: 0, y: 0, width: frame, height: frame * 0.65),
                auxLeftWidth: aux, auxRightWidth: aux, safeAreaTop: safeTop))
            let layout = IslandLayout(notchSize: m.closedSize)
            var state = IslandState()
            state.hasSession = true
            let surfaces: [IslandState.Surface] = [
                .collapsed, .peek, .expanded, .trackIntro, .volume(50),
                .battery(BatteryFlash(kind: .pluggedIn, percentage: 90)),
                .device(DeviceFlash(icon: "airpods", name: "AirPods", percentage: 80)),
            ]
            for surface in surfaces {
                state.surface = surface
                for lyrics in [false, true] {
                    let size = layout.size(for: state, lyricsEnabled: lyrics)
                    #expect(size.width <= m.windowFrame.width,
                            "\(Int(frame)): \(surface) шире окна")
                    #expect(size.height <= m.windowFrame.height,
                            "\(Int(frame)): \(surface) выше окна")
                }
            }
        }
    }

    @Test func noNotchReturnsNil() {
        #expect(NotchGeometry.metrics(
            screenFrame: screen, auxLeftWidth: nil, auxRightWidth: nil,
            safeAreaTop: 0) == nil)
        #expect(NotchGeometry.metrics(
            screenFrame: screen, auxLeftWidth: 0, auxRightWidth: 0,
            safeAreaTop: 24) == nil)
    }

    /// Регрессия «сменил разрешение — чёрная форма не совпала с вырезом».
    /// Замер 2026-09-01 по всем режимам встроенного экрана MacBook Pro 14":
    /// вырез физически один и тот же (~370 px), а в поинтах меняется вчетверо.
    /// Перекрытие обязано оставаться постоянным в ФИЗИЧЕСКИХ пикселях, иначе
    /// на мелком масштабе форма вылезает за вырез, а на крупном оголяет шов.
    /// Фиксированные 4pt давали разброс 6.7…11.8 px.
    @Test func overlapStaysConstantInPhysicalPixels() throws {
        let panelPixels: CGFloat = 3024 // физическая ширина панели
        let modes: [(frame: CGFloat, bareNotch: CGFloat, safeTop: CGFloat)] = [
            (1024, 126, 22), (1147, 141, 24), (1352, 166, 29),
            (1512, 185, 32), (1800, 220, 38),
            (2048, 250, 43), (2294, 280, 48), (2704, 330, 57), (3024, 370, 64),
        ]
        for mode in modes {
            let aux = (mode.frame - mode.bareNotch) / 2
            let m = try #require(NotchGeometry.metrics(
                screenFrame: CGRect(x: 0, y: 0, width: mode.frame, height: 982),
                auxLeftWidth: aux, auxRightWidth: aux, safeAreaTop: mode.safeTop))
            let pixelsPerPoint = panelPixels / mode.frame
            let overlapPixels = (m.closedSize.width - mode.bareNotch) * pixelsPerPoint
            // Эталон — 8 физических пикселей, подобранные на дефолтном масштабе.
            #expect(abs(overlapPixels - 8) <= 1,
                    "режим \(Int(mode.frame)): перекрытие \(overlapPixels) физ.px")
        }
    }

    @Test func offsetScreenOriginIsRespected() throws {
        let offset = CGRect(x: 1512, y: -200, width: 1512, height: 982)
        let m = try #require(NotchGeometry.metrics(
            screenFrame: offset, auxLeftWidth: 656, auxRightWidth: 656,
            safeAreaTop: 32))
        #expect(m.notchRect.origin == CGPoint(x: 1512 + 654, y: -200 + 950))
        #expect(m.windowFrame.midX == offset.midX)
    }
}
