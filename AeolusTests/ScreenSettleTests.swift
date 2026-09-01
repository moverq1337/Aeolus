import Testing
import CoreGraphics
@testable import Aeolus

struct ScreenSettleTests {
    // Замеры с живого MacBook Pro 14" (2026-09-01): встроенный экран в
    // дефолтном масштабе отдаёт ровно эти числа.
    let native = CGRect(x: 0, y: 0, width: 1512, height: 982)

    private func metrics(
        frame: CGRect, aux: (CGFloat, CGFloat), safeTop: CGFloat
    ) -> NotchMetrics? {
        NotchGeometry.metrics(
            screenFrame: frame, auxLeftWidth: aux.0, auxRightWidth: aux.1,
            safeAreaTop: safeTop)
    }

    @Test func sameGeometryDoesNotRebuild() throws {
        let m = try #require(metrics(frame: native, aux: (663, 664), safeTop: 32))
        #expect(ScreenSettle.step(current: m, fresh: m) == .keep)
    }

    @Test func absentScreenStaysAbsent() {
        // Клемшелл: экрана нет и до, и после события — окно не трогаем.
        #expect(ScreenSettle.step(current: nil, fresh: nil) == .keep)
    }

    @Test func screenAppearingRebuilds() throws {
        let m = try #require(metrics(frame: native, aux: (663, 664), safeTop: 32))
        #expect(ScreenSettle.step(current: nil, fresh: m) == .rebuild)
    }

    @Test func screenVanishingRebuilds() throws {
        let m = try #require(metrics(frame: native, aux: (663, 664), safeTop: 32))
        #expect(ScreenSettle.step(current: m, fresh: nil) == .rebuild)
    }

    /// Главный регрессионный случай: смена разрешения меняет вырез в поинтах —
    /// физически он тот же, но экран стал шире, и остров обязан пересобраться.
    @Test func resolutionChangeRebuilds() throws {
        let scaled = CGRect(x: 0, y: 0, width: 1800, height: 1169)
        let before = try #require(metrics(frame: native, aux: (663, 664), safeTop: 32))
        let after = try #require(
            metrics(frame: scaled, aux: (789.5, 790.5), safeTop: 38))
        #expect(before.closedSize != after.closedSize)
        #expect(ScreenSettle.step(current: before, fresh: after) == .rebuild)
    }

    @Test func probeScheduleIsFiniteAndGrowing() throws {
        let delays = ScreenSettle.probeDelays
        #expect(!delays.isEmpty)
        #expect(delays == delays.sorted())
        #expect(Set(delays).count == delays.count)
        // Первая проба должна успеть за быстрым переключением масштаба…
        #expect(try #require(delays.first) <= .milliseconds(250))
        // …последняя — пережить медленное (пробуждение, приход монитора).
        #expect(try #require(delays.last) >= .seconds(3))
    }
}
