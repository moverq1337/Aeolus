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

    @Test func clickOutsideCollapsesExpanded() {
        var s = playingState()
        _ = IslandReducer.reduce(&s, .hoverBegan)
        _ = IslandReducer.reduce(&s, .dwellFired)
        _ = IslandReducer.reduce(&s, .clickedOutside)
        #expect(s.surface == .collapsed)
    }
}
