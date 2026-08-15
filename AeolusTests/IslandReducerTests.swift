import Testing
@testable import Aeolus

struct IslandReducerTests {
    private func playingState() -> IslandState {
        var s = IslandState()
        _ = IslandReducer.reduce(&s, .musicChanged(playing: true, hasSession: true))
        return s
    }

    @Test func hoverOnCollapsedWithSessionPeeksAndStartsDwell() {
        var s = playingState()
        let fx = IslandReducer.reduce(&s, .hoverBegan)
        #expect(s.surface == .peek)
        #expect(fx == [.haptic, .startDwellTimer])
    }

    @Test func hoverWithoutSessionOnlyPeeks() {
        var s = IslandState()
        let fx = IslandReducer.reduce(&s, .hoverBegan)
        #expect(s.surface == .peek)
        #expect(fx == [.haptic]) // раскрывать нечего — dwell не запускаем
    }

    @Test func dwellExpandsOnlyFromPeekWithSession() {
        var s = playingState()
        _ = IslandReducer.reduce(&s, .hoverBegan)
        let fx = IslandReducer.reduce(&s, .dwellFired)
        #expect(s.surface == .expanded)
        #expect(fx == [.haptic])

        var empty = IslandState()
        _ = IslandReducer.reduce(&empty, .hoverBegan)
        _ = IslandReducer.reduce(&empty, .dwellFired)
        #expect(empty.surface == .peek)
    }

    @Test func hoverExitFromPeekCollapses() {
        var s = playingState()
        _ = IslandReducer.reduce(&s, .hoverBegan)
        let fx = IslandReducer.reduce(&s, .hoverEnded)
        #expect(s.surface == .collapsed)
        #expect(fx == [.cancelDwellTimer])
    }

    @Test func hoverExitFromExpandedStartsDebounceAndReturnCancels() {
        var s = playingState()
        _ = IslandReducer.reduce(&s, .hoverBegan)
        _ = IslandReducer.reduce(&s, .dwellFired)
        #expect(IslandReducer.reduce(&s, .hoverEnded) == [.startCloseDebounce])
        #expect(s.surface == .expanded) // ещё не закрылся
        #expect(IslandReducer.reduce(&s, .hoverBegan) == [.cancelCloseDebounce])
        _ = IslandReducer.reduce(&s, .hoverEnded)
        _ = IslandReducer.reduce(&s, .closeDebounceFired)
        #expect(s.surface == .collapsed)
    }

    @Test func tapExpandsImmediately() {
        var s = playingState()
        _ = IslandReducer.reduce(&s, .hoverBegan)
        let fx = IslandReducer.reduce(&s, .tapped)
        #expect(s.surface == .expanded)
        #expect(fx == [.haptic, .cancelDwellTimer])
    }

    @Test func musicStopWhileExpandedCollapses() {
        var s = playingState()
        _ = IslandReducer.reduce(&s, .hoverBegan)
        _ = IslandReducer.reduce(&s, .dwellFired)
        _ = IslandReducer.reduce(&s, .musicChanged(playing: false, hasSession: false))
        #expect(s.surface == .collapsed)
        #expect(!s.hasSession)
    }

    @Test func batteryFlashShowsAndEnds() {
        var s = IslandState()
        let flash = BatteryFlash(kind: .pluggedIn, percentage: 80)
        let fx = IslandReducer.reduce(&s, .battery(flash))
        #expect(s.surface == .battery(flash))
        #expect(fx == [.scheduleBatteryEnd])
        _ = IslandReducer.reduce(&s, .batteryFlashEnded)
        #expect(s.surface == .collapsed)
    }

    @Test func batteryWhileExpandedDefersUntilCollapse() {
        var s = playingState()
        _ = IslandReducer.reduce(&s, .hoverBegan)
        _ = IslandReducer.reduce(&s, .dwellFired)
        let flash = BatteryFlash(kind: .low, percentage: 19)
        #expect(IslandReducer.reduce(&s, .battery(flash)).isEmpty)
        #expect(s.surface == .expanded)          // раскрытие не прерываем
        #expect(s.pendingBattery == flash)
        _ = IslandReducer.reduce(&s, .hoverEnded)
        let fx = IslandReducer.reduce(&s, .closeDebounceFired)
        #expect(s.surface == .battery(flash))    // отложенный транзиент показан
        #expect(s.pendingBattery == nil)
        #expect(fx == [.scheduleBatteryEnd])
    }

    @Test func batteryDuringPeekCancelsDwell() {
        var s = playingState()
        _ = IslandReducer.reduce(&s, .hoverBegan)
        let flash = BatteryFlash(kind: .unplugged, percentage: 55)
        let fx = IslandReducer.reduce(&s, .battery(flash))
        #expect(s.surface == .battery(flash))
        #expect(fx == [.cancelDwellTimer, .scheduleBatteryEnd])
    }

    @Test func volumeTogglesOnlyWhileExpanded() {
        var s = playingState()
        #expect(IslandReducer.reduce(&s, .volumeToggled).isEmpty) // collapsed — игнор
        _ = IslandReducer.reduce(&s, .hoverBegan)
        _ = IslandReducer.reduce(&s, .dwellFired)
        #expect(IslandReducer.reduce(&s, .volumeToggled) == [.haptic])
        #expect(s.volumeShown)
        _ = IslandReducer.reduce(&s, .volumeToggled)
        #expect(!s.volumeShown)
    }

    @Test func collapseResetsVolumeShown() {
        var s = playingState()
        _ = IslandReducer.reduce(&s, .hoverBegan)
        _ = IslandReducer.reduce(&s, .dwellFired)
        _ = IslandReducer.reduce(&s, .volumeToggled)
        _ = IslandReducer.reduce(&s, .hoverEnded)
        _ = IslandReducer.reduce(&s, .closeDebounceFired)
        #expect(s.surface == .collapsed)
        #expect(!s.volumeShown)
    }

    @Test func volumeGestureShowsFlashFromCollapsed() {
        var s = playingState()
        let fx = IslandReducer.reduce(&s, .volumeGesture(55))
        #expect(s.surface == .volume(55))
        #expect(fx == [.scheduleVolumeFlashEnd])
        // продолжение жеста обновляет процент и продлевает таймер
        let fx2 = IslandReducer.reduce(&s, .volumeGesture(60))
        #expect(s.surface == .volume(60))
        #expect(fx2 == [.scheduleVolumeFlashEnd])
        _ = IslandReducer.reduce(&s, .volumeFlashEnded)
        #expect(s.surface == .collapsed)
    }

    @Test func volumeGestureFromPeekCancelsDwell() {
        var s = playingState()
        _ = IslandReducer.reduce(&s, .hoverBegan)
        let fx = IslandReducer.reduce(&s, .volumeGesture(30))
        #expect(s.surface == .volume(30))
        #expect(fx == [.cancelDwellTimer, .scheduleVolumeFlashEnd])
    }

    @Test func batteryOverridesVolumeFlash() {
        var s = playingState()
        _ = IslandReducer.reduce(&s, .volumeGesture(40))
        let flash = BatteryFlash(kind: .pluggedIn, percentage: 88)
        _ = IslandReducer.reduce(&s, .battery(flash))
        #expect(s.surface == .battery(flash))
        // залипший volumeFlashEnded не роняет батарейный транзиент
        _ = IslandReducer.reduce(&s, .volumeFlashEnded)
        #expect(s.surface == .battery(flash))
    }

    @Test func volumeGestureInExpandedShowsOverlay() {
        var s = playingState()
        _ = IslandReducer.reduce(&s, .hoverBegan)
        _ = IslandReducer.reduce(&s, .dwellFired)
        let fx = IslandReducer.reduce(&s, .volumeGesture(65))
        #expect(s.surface == .expanded)
        #expect(s.volumeOverlay)
        #expect(fx == [.scheduleVolumeFlashEnd]) // страховочный таймер
        // отпустили пальцы — оверлей прячется сразу
        _ = IslandReducer.reduce(&s, .volumeGestureEnded)
        #expect(!s.volumeOverlay)
        #expect(s.surface == .expanded)
    }

    @Test func volumeOverlayFallbackTimerHides() {
        var s = playingState()
        _ = IslandReducer.reduce(&s, .hoverBegan)
        _ = IslandReducer.reduce(&s, .dwellFired)
        _ = IslandReducer.reduce(&s, .volumeGesture(65))
        _ = IslandReducer.reduce(&s, .volumeFlashEnded)
        #expect(!s.volumeOverlay)
    }

    @Test func collapseResetsVolumeOverlay() {
        var s = playingState()
        _ = IslandReducer.reduce(&s, .hoverBegan)
        _ = IslandReducer.reduce(&s, .dwellFired)
        _ = IslandReducer.reduce(&s, .volumeGesture(65))
        _ = IslandReducer.reduce(&s, .hoverEnded)
        _ = IslandReducer.reduce(&s, .closeDebounceFired)
        #expect(s.surface == .collapsed)
        #expect(!s.volumeOverlay)
    }

    @Test func screenLockSuppressesIslandAndUnlockReleases() {
        var s = playingState()
        _ = IslandReducer.reduce(&s, .hoverBegan)
        let fx = IslandReducer.reduce(&s, .screenLocked)
        #expect(s.suppressed)
        #expect(s.surface == .collapsed)
        #expect(fx == [.cancelDwellTimer, .cancelCloseDebounce])
        // пока подавлен — уши не возвращаются даже при живой музыке
        _ = IslandReducer.reduce(&s, .musicChanged(playing: true, hasSession: true))
        #expect(s.suppressed)
        // разблокировка снимает подавление, уши распускаются сами
        _ = IslandReducer.reduce(&s, .screenUnlocked)
        #expect(!s.suppressed)
        #expect(s.surface == .collapsed)
    }

    @Test func trackChangeShowsIntroAndEnds() {
        var s = playingState()
        let fx = IslandReducer.reduce(&s, .trackChanged)
        #expect(s.surface == .trackIntro)
        #expect(fx == [.scheduleTrackIntroEnd])
        _ = IslandReducer.reduce(&s, .trackIntroEnded)
        #expect(s.surface == .collapsed)
    }

    @Test func trackChangeIgnoredWhileExpandedAndBattery() {
        var s = playingState()
        _ = IslandReducer.reduce(&s, .hoverBegan)
        _ = IslandReducer.reduce(&s, .dwellFired)
        #expect(IslandReducer.reduce(&s, .trackChanged).isEmpty)
        #expect(s.surface == .expanded)

        var b = playingState()
        let flash = BatteryFlash(kind: .pluggedIn, percentage: 50)
        _ = IslandReducer.reduce(&b, .battery(flash))
        #expect(IslandReducer.reduce(&b, .trackChanged).isEmpty)
        #expect(b.surface == .battery(flash))
    }

    @Test func hoverDuringIntroPeeks() {
        var s = playingState()
        _ = IslandReducer.reduce(&s, .trackChanged)
        let fx = IslandReducer.reduce(&s, .hoverBegan)
        #expect(s.surface == .peek)
        #expect(fx == [.haptic, .startDwellTimer])
    }

    @Test func tapDuringIntroExpands() {
        var s = playingState()
        _ = IslandReducer.reduce(&s, .trackChanged)
        _ = IslandReducer.reduce(&s, .tapped)
        #expect(s.surface == .expanded)
    }

    @Test func batteryOverridesIntro() {
        var s = playingState()
        _ = IslandReducer.reduce(&s, .trackChanged)
        let flash = BatteryFlash(kind: .unplugged, percentage: 42)
        _ = IslandReducer.reduce(&s, .battery(flash))
        #expect(s.surface == .battery(flash))
        _ = IslandReducer.reduce(&s, .trackIntroEnded)
        #expect(s.surface == .battery(flash)) // залипший таймер не роняет батарею
    }

    @Test func sessionEndDuringIntroCollapses() {
        var s = playingState()
        _ = IslandReducer.reduce(&s, .trackChanged)
        _ = IslandReducer.reduce(&s, .musicChanged(playing: false, hasSession: false))
        #expect(s.surface == .collapsed)
    }

    @Test func clickOutsideCollapsesExpanded() {
        var s = playingState()
        _ = IslandReducer.reduce(&s, .hoverBegan)
        _ = IslandReducer.reduce(&s, .dwellFired)
        _ = IslandReducer.reduce(&s, .clickedOutside)
        #expect(s.surface == .collapsed)
    }
}
