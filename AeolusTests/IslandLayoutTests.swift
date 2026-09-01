import Testing
import CoreGraphics
@testable import Aeolus

struct IslandLayoutTests {
    let layout = IslandLayout(notchSize: CGSize(width: 204, height: 32))

    private func state(_ surface: IslandState.Surface, session: Bool = true) -> IslandState {
        var s = IslandState()
        s.surface = surface
        s.hasSession = session
        return s
    }

    @Test func collapsedWithoutSessionMatchesNotch() {
        #expect(layout.size(for: state(.collapsed, session: false))
                == CGSize(width: 204, height: 32))
    }

    @Test func collapsedWithSessionAddsEars() {
        #expect(layout.size(for: state(.collapsed))
                == CGSize(width: 204 + 88, height: 32)) // +2*44
    }

    @Test func peekAddsBreath() {
        #expect(layout.size(for: state(.peek, session: false))
                == CGSize(width: 214, height: 35)) // +10 / +3
        #expect(layout.size(for: state(.peek))
                == CGSize(width: 204 + 88 + 10, height: 35))
    }

    @Test func expandedUsesFixedSize() {
        #expect(layout.size(for: state(.expanded)) == IslandLayout.expandedSize)
    }

    @Test func expandedGrowsWhenVolumeShown() {
        var s = state(.expanded)
        s.volumeShown = true
        #expect(layout.size(for: s) == IslandLayout.expandedVolumeSize)
        #expect(IslandLayout.expandedVolumeSize.height > IslandLayout.expandedSize.height)
    }

    @Test func batteryAddsWideEars() {
        let flash = BatteryFlash(kind: .pluggedIn, percentage: 90)
        #expect(layout.size(for: state(.battery(flash)))
                == CGSize(width: 372, height: 32)) // 204 + 2*84
    }

    @Test func expandedGrowsWithVolumeOverlay() {
        var s = state(.expanded)
        s.volumeOverlay = true
        #expect(layout.size(for: s) == IslandLayout.expandedVolumeSize)
    }

    @Test func trackIntroSitsBetweenCollapsedAndExpanded() {
        let intro = layout.size(for: state(.trackIntro))
        let playing = layout.size(for: state(.collapsed))
        #expect(intro == CGSize(width: 380, height: 32 + 30))
        #expect(intro.width * intro.height > playing.width * playing.height)
        #expect(intro.width * intro.height
                < IslandLayout.expandedSize.width * IslandLayout.expandedSize.height)
    }

    @Test func suppressedAlwaysBareNotch() {
        var s = state(.expanded)
        s.suppressed = true
        #expect(layout.size(for: s) == CGSize(width: 204, height: 32))
    }

    /// Регрессия «на самом большом разрешении острова просто нет».
    /// При масштабе 1:1 вырез вырастает до 378pt (замер 3024x1964@1x), и
    /// раскрытый плеер шириной 360pt целиком прячется ЗА вырезом.
    @Test func expandedNeverNarrowerThanNotchWithEars() {
        let big = IslandLayout(notchSize: CGSize(width: 378, height: 64))
        var s = IslandState()
        s.surface = .expanded
        s.hasSession = true
        let expanded = big.size(for: s)
        #expect(expanded.width == 378 + 88)          // не уже свёрнутого с ушами
        #expect(expanded.width > 378)                 // видно из-за выреза
        #expect(expanded.width > IslandLayout.expandedSize.width)
        // Контент рисуется под вырезом — высота растёт на разницу с эталоном.
        #expect(expanded.height == IslandLayout.expandedSize.height + (64 - 32))
    }

    @Test func trackIntroNeverNarrowerThanNotchWithEars() {
        let big = IslandLayout(notchSize: CGSize(width: 378, height: 64))
        var s = IslandState()
        s.surface = .trackIntro
        #expect(big.size(for: s).width == 378 + 88)
    }

    @Test func widestSizeCoversEverySurface() {
        for notch in [CGSize(width: 129, height: 22), CGSize(width: 189, height: 32),
                      CGSize(width: 225, height: 38), CGSize(width: 378, height: 64)] {
            let l = IslandLayout(notchSize: notch)
            let widest = l.widestSize
            var s = IslandState()
            s.hasSession = true
            let surfaces: [IslandState.Surface] = [
                .collapsed, .peek, .expanded, .trackIntro, .volume(50),
                .battery(BatteryFlash(kind: .low, percentage: 20)),
                .device(DeviceFlash(icon: "airpods", name: "AirPods", percentage: 80)),
            ]
            for surface in surfaces {
                s.surface = surface
                s.volumeShown = surface == .expanded
                for lyrics in [false, true] {
                    let size = l.size(for: s, lyricsEnabled: lyrics)
                    #expect(size.width <= widest.width)
                    #expect(size.height <= widest.height)
                }
            }
        }
    }

    @Test func radiiPerSurface() {
        #expect(layout.radii(for: state(.collapsed)) == (6, 14))
        #expect(layout.radii(for: state(.peek)) == (7, 16))
        #expect(layout.radii(for: state(.expanded)) == (15, 20))
        #expect(layout.radii(for: state(.trackIntro)) == (10, 18))
    }
}
