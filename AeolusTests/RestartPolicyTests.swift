import Testing
@testable import Aeolus

struct RestartPolicyTests {
    @Test func exponentialBackoffThenGiveUp() {
        var p = RestartPolicy()
        #expect(p.recordFailure() == .restart(after: 1))
        #expect(p.recordFailure() == .restart(after: 2))
        #expect(p.recordFailure() == .restart(after: 4))
        #expect(p.recordFailure() == .restart(after: 8))
        #expect(p.recordFailure() == .giveUp) // 5-й подряд — спека §5.5
    }

    @Test func successResetsCounter() {
        var p = RestartPolicy()
        _ = p.recordFailure()
        _ = p.recordFailure()
        p.recordSuccess()
        #expect(p.recordFailure() == .restart(after: 1))
    }
}
