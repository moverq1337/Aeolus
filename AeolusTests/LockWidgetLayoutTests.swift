import Testing
import CoreGraphics
@testable import Aeolus

struct LockWidgetLayoutTests {
    // Экран MacBook Pro 14" в глобальных AppKit-координатах (origin слева-внизу).
    let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)

    @Test func centeredHorizontally() {
        let f = LockWidgetLayout.frame(screenFrame: screen, userOffset: 0)
        #expect(f.midX == screen.midX)
        #expect(f.size == LockWidgetLayout.cardSize)
    }

    @Test func defaultSitsJustAbovePasswordZone() {
        let f = LockWidgetLayout.frame(screenFrame: screen, userOffset: 0)
        #expect(f.origin.y == 240) // baseBottomMargin
    }

    @Test func offsetRaisesCard() {
        let f = LockWidgetLayout.frame(screenFrame: screen, userOffset: 160)
        #expect(f.origin.y == 400) // 240 + 160
    }

    @Test func offsetClampedToRange() {
        let high = LockWidgetLayout.frame(screenFrame: screen, userOffset: 999)
        #expect(high.origin.y == 560) // 240 + 320 (верх диапазона)
        let low = LockWidgetLayout.frame(screenFrame: screen, userOffset: -50)
        #expect(low.origin.y == 240) // отрицательное усечено к 0
    }

    @Test func bottomClearanceGuardHolds() {
        // Даже при нулевом offset нижний зазор не меньше защитного минимума.
        let f = LockWidgetLayout.frame(screenFrame: screen, userOffset: 0)
        #expect(f.origin.y >= screen.minY + LockWidgetLayout.minBottomClearance)
    }

    @Test func offsetOriginRespected() {
        let offsetScreen = CGRect(x: 100, y: -50, width: 1512, height: 982)
        let f = LockWidgetLayout.frame(screenFrame: offsetScreen, userOffset: 0)
        #expect(f.midX == offsetScreen.midX)
        #expect(f.origin.y == offsetScreen.minY + 240)
    }
}
