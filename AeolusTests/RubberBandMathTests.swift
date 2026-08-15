import Testing
@testable import Aeolus

@Suite("RubberBandMath")
struct RubberBandMathTests {
    @Test func zeroExcessGivesZero() {
        #expect(RubberBandMath.dampedFraction(excessPoints: 0) == 0)
    }

    @Test func preservesSign() {
        #expect(RubberBandMath.dampedFraction(excessPoints: 30) > 0)
        #expect(RubberBandMath.dampedFraction(excessPoints: -30) < 0)
    }

    @Test func neverReachesLimit() {
        // Асимптота Apple: даже гигантский ход не достигает 1.
        #expect(RubberBandMath.dampedFraction(excessPoints: 10_000) < 1)
        #expect(RubberBandMath.dampedFraction(excessPoints: -10_000) > -1)
    }

    @Test func monotonicResistance() {
        let a = RubberBandMath.dampedFraction(excessPoints: 20)
        let b = RubberBandMath.dampedFraction(excessPoints: 40)
        let c = RubberBandMath.dampedFraction(excessPoints: 80)
        #expect(a < b && b < c)
        // Сопротивление растёт: второй шаг даёт меньше первого.
        #expect(b - a < a)
    }

    @Test func stretchCapsTenPercentOnNarrowBar() {
        // 30pt бар: максимум 10% ширины (3pt < кап 8pt).
        #expect(RubberBandMath.stretch(overshoot: 1, barWidth: 30) == 0.1)
    }

    @Test func stretchCapsEightPointsOnWideBar() {
        // 250pt строка плеера: 10% было бы 25pt — кап 8pt.
        let s = RubberBandMath.stretch(overshoot: 1, barWidth: 250)
        #expect(s == 8.0 / 250.0)
    }

    @Test func stretchScalesWithOvershoot() {
        let half = RubberBandMath.stretch(overshoot: 0.5, barWidth: 30)
        #expect(half == 0.05)
        #expect(RubberBandMath.stretch(overshoot: -0.5, barWidth: 30) == half)
    }

    @Test func stretchZeroWidthSafe() {
        #expect(RubberBandMath.stretch(overshoot: 1, barWidth: 0) == 0)
    }
}
