import Testing
@testable import Aeolus

struct PowerSnapshotTests {
    @Test func parsesIOKitDescription() throws {
        let desc: [String: Any] = [
            "Current Capacity": 73,
            "Max Capacity": 100,
            "Power Source State": "AC Power",
            "Is Charging": true,
            "Time to Full Charge": 42,
        ]
        let s = try #require(PowerSnapshot(description: desc))
        #expect(s.percentage == 73)
        #expect(s.isPluggedIn)
        #expect(s.isCharging)
        #expect(s.minutesToFull == 42)
    }

    @Test func minusOneTimeIsCalculating() throws {
        // -1 от powerd = «ещё считаю», показывать нельзя (спека v1 §5.6).
        let desc: [String: Any] = [
            "Current Capacity": 50,
            "Max Capacity": 100,
            "Power Source State": "Battery Power",
            "Time to Empty": -1,
        ]
        let s = try #require(PowerSnapshot(description: desc))
        #expect(s.minutesToEmpty == nil)
    }

    @Test func rejectsIncompleteDescription() {
        #expect(PowerSnapshot(description: [:]) == nil)
        #expect(PowerSnapshot(description: ["Current Capacity": 50]) == nil)
    }
}
