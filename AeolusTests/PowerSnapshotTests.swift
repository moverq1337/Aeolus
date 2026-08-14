import Testing
@testable import Aeolus

struct PowerSnapshotTests {
    @Test func parsesIOKitDescription() throws {
        let desc: [String: Any] = [
            "Current Capacity": 73,
            "Max Capacity": 100,
            "Power Source State": "AC Power",
            "Is Charging": true,
        ]
        let s = try #require(PowerSnapshot(description: desc))
        #expect(s.percentage == 73)
        #expect(s.isPluggedIn)
        #expect(s.isCharging)
    }

    @Test func rejectsIncompleteDescription() {
        #expect(PowerSnapshot(description: [:]) == nil)
        #expect(PowerSnapshot(description: ["Current Capacity": 50]) == nil)
    }
}
