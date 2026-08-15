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

    @Test func topEdgeSixtyBelowCenterAtZeroOffset() {
        let f = LockWidgetLayout.frame(screenFrame: screen, userOffset: 0)
        // midY=491; верхний край = 491-60 = 431; origin.y = 431-150 = 281
        #expect(f.maxY == screen.midY - 60)
        #expect(f.origin.y == 281)
    }

    @Test func positiveOffsetMovesUp() {
        let f = LockWidgetLayout.frame(screenFrame: screen, userOffset: 160)
        #expect(f.origin.y == 441) // 281 + 160
    }

    @Test func bottomClearanceClampAtMaxDownOffset() {
        // Смещение вниз ограничено зазором ≥220pt от низа экрана.
        let f = LockWidgetLayout.frame(screenFrame: screen, userOffset: -160)
        #expect(f.origin.y == screen.minY + 220) // 281-160=121 < 220 -> клампится к 220
    }

    @Test func offsetClampedToRange() {
        // Значения за пределами ±160 усекаются перед расчётом.
        let f = LockWidgetLayout.frame(screenFrame: screen, userOffset: 999)
        #expect(f.origin.y == 441) // 281 + 160
    }

    @Test func offsetOriginRespected() {
        let offsetScreen = CGRect(x: 100, y: -50, width: 1512, height: 982)
        let f = LockWidgetLayout.frame(screenFrame: offsetScreen, userOffset: 0)
        #expect(f.midX == offsetScreen.midX)
        #expect(f.maxY == offsetScreen.midY - 60)
    }
}
