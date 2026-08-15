import Testing
@testable import Aeolus

struct ScrollGestureRecognizerTests {
    // natural scrolling (inverted=true): пальцы ВВЕРХ дают deltaY < 0.

    @Test func verticalSwipeUpRaisesVolume() {
        var r = ScrollGestureRecognizer()
        #expect(r.handle(phase: .began, deltaX: 0, deltaY: 0, inverted: true).isEmpty)
        // до мёртвой зоны — тишина
        #expect(r.handle(phase: .changed, deltaX: 0, deltaY: -4, inverted: true).isEmpty)
        // порог пройден — непрерывные volumeChange, пальцы вверх => дельта > 0
        let actions = r.handle(phase: .changed, deltaX: 0, deltaY: -10, inverted: true)
        guard case .volumeChange(let d)? = actions.first else {
            Issue.record("ожидали volumeChange, получили \(actions)")
            return
        }
        #expect(d > 0)
    }

    @Test func verticalSwipeDownLowersVolumeClassicScrolling() {
        var r = ScrollGestureRecognizer()
        _ = r.handle(phase: .began, deltaX: 0, deltaY: 0, inverted: false)
        // классический скролл (inverted=false): пальцы ВНИЗ дают deltaY < 0
        let actions = r.handle(phase: .changed, deltaX: 0, deltaY: -12, inverted: false)
        guard case .volumeChange(let d)? = actions.first else {
            Issue.record("ожидали volumeChange, получили \(actions)")
            return
        }
        #expect(d < 0)
    }

    @Test func horizontalSwipeLeftFiresNextOnce() {
        var r = ScrollGestureRecognizer()
        _ = r.handle(phase: .began, deltaX: 0, deltaY: 0, inverted: true)
        // natural: пальцы ВЛЕВО дают deltaX > 0
        #expect(r.handle(phase: .changed, deltaX: 20, deltaY: 1, inverted: true).isEmpty)
        #expect(r.handle(phase: .changed, deltaX: 25, deltaY: 0, inverted: true) == [.nextTrack])
        // повторные дельты в том же жесте — не стреляем второй раз
        #expect(r.handle(phase: .changed, deltaX: 30, deltaY: 0, inverted: true).isEmpty)
        _ = r.handle(phase: .ended, deltaX: 0, deltaY: 0, inverted: true)
    }

    @Test func horizontalSwipeRightFiresPrevious() {
        var r = ScrollGestureRecognizer()
        _ = r.handle(phase: .began, deltaX: 0, deltaY: 0, inverted: true)
        _ = r.handle(phase: .changed, deltaX: -25, deltaY: 0, inverted: true)
        #expect(r.handle(phase: .changed, deltaX: -20, deltaY: 0, inverted: true) == [.previousTrack])
    }

    @Test func axisLocksToDominantDirection() {
        var r = ScrollGestureRecognizer()
        _ = r.handle(phase: .began, deltaX: 0, deltaY: 0, inverted: true)
        // горизонталь победила — вертикальные дельты того же жеста игнорируются
        _ = r.handle(phase: .changed, deltaX: 30, deltaY: 3, inverted: true)
        _ = r.handle(phase: .changed, deltaX: 15, deltaY: 0, inverted: true)
        #expect(r.handle(phase: .changed, deltaX: 0, deltaY: -30, inverted: true).isEmpty)
    }

    @Test func verticalGestureEndEmitsEndAction() {
        var r = ScrollGestureRecognizer()
        _ = r.handle(phase: .began, deltaX: 0, deltaY: 0, inverted: true)
        _ = r.handle(phase: .changed, deltaX: 0, deltaY: -15, inverted: true)
        #expect(r.handle(phase: .ended, deltaX: 0, deltaY: 0, inverted: true)
                == [.verticalGestureEnded])
    }

    @Test func horizontalGestureEndEmitsNothing() {
        var r = ScrollGestureRecognizer()
        _ = r.handle(phase: .began, deltaX: 0, deltaY: 0, inverted: true)
        _ = r.handle(phase: .changed, deltaX: 45, deltaY: 0, inverted: true)
        #expect(r.handle(phase: .ended, deltaX: 0, deltaY: 0, inverted: true).isEmpty)
    }

    @Test func newGestureResetsState() {
        var r = ScrollGestureRecognizer()
        _ = r.handle(phase: .began, deltaX: 0, deltaY: 0, inverted: true)
        _ = r.handle(phase: .changed, deltaX: 45, deltaY: 0, inverted: true) // next
        _ = r.handle(phase: .ended, deltaX: 0, deltaY: 0, inverted: true)
        // второй жест — снова может стрелять
        _ = r.handle(phase: .began, deltaX: 0, deltaY: 0, inverted: true)
        #expect(r.handle(phase: .changed, deltaX: 45, deltaY: 0, inverted: true) == [.nextTrack])
    }
}
