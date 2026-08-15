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
                == CGSize(width: 204 + 140, height: 32)) // +2*70
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

    @Test func radiiPerSurface() {
        #expect(layout.radii(for: state(.collapsed)) == (6, 14))
        #expect(layout.radii(for: state(.peek)) == (7, 16))
        #expect(layout.radii(for: state(.expanded)) == (15, 20))
        #expect(layout.radii(for: state(.trackIntro)) == (10, 18))
    }
}
