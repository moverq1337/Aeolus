import Testing
@testable import Aeolus

struct PowerEventDetectorTests {
    private func snap(_ pct: Int, plugged: Bool, charging: Bool = false) -> PowerSnapshot {
        PowerSnapshot(percentage: pct, isPluggedIn: plugged, isCharging: charging)
    }

    @Test func plugAndUnplugEmitEvents() {
        var d = PowerEventDetector()
        _ = d.events(from: nil, to: snap(80, plugged: false))
        #expect(d.events(from: snap(79, plugged: false), to: snap(80, plugged: true, charging: true))
                == [.pluggedIn(percentage: 79)]) // стабильный ДО-событийный процент
        #expect(d.events(from: snap(80, plugged: true), to: snap(81, plugged: false))
                == [.unplugged(percentage: 80)])
    }

    @Test func identicalSnapshotsEmitNothing() {
        // IOKit-колбэк дребезжит — одинаковые снапшоты не должны давать событий.
        var d = PowerEventDetector()
        _ = d.events(from: nil, to: snap(50, plugged: false))
        #expect(d.events(from: snap(50, plugged: false), to: snap(50, plugged: false)).isEmpty)
    }

    @Test func lowBatteryFiresOncePerCrossing() {
        var d = PowerEventDetector()
        #expect(d.events(from: snap(21, plugged: false), to: snap(20, plugged: false))
                == [.lowBattery(percentage: 20, critical: false)])
        #expect(d.events(from: snap(20, plugged: false), to: snap(18, plugged: false)).isEmpty)
        #expect(d.events(from: snap(18, plugged: false), to: snap(10, plugged: false))
                == [.lowBattery(percentage: 10, critical: true)])
        #expect(d.events(from: snap(10, plugged: false), to: snap(8, plugged: false)).isEmpty)
    }

    @Test func jumpAcrossBothThresholdsFiresSingleCriticalEvent() {
        var d = PowerEventDetector()
        #expect(d.events(from: snap(21, plugged: false), to: snap(9, plugged: false))
                == [.lowBattery(percentage: 9, critical: true)])
    }

    @Test func chargingAboveThresholdResetsLatch() {
        var d = PowerEventDetector()
        _ = d.events(from: snap(21, plugged: false), to: snap(19, plugged: false)) // low
        _ = d.events(from: snap(19, plugged: false), to: snap(60, plugged: true, charging: true))
        // Снова разрядились ниже порога — предупреждение должно повториться.
        let events = d.events(from: snap(60, plugged: true), to: snap(19, plugged: false))
        #expect(events.contains(.unplugged(percentage: 60)))
        #expect(events.contains(.lowBattery(percentage: 19, critical: false)))
    }
}
