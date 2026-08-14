import Testing
@testable import Aeolus

struct TimeFormatterTests {
    @Test func formatsMinutesSeconds() {
        #expect(TimeFormatter.clock(0) == "0:00")
        #expect(TimeFormatter.clock(21) == "0:21")
        #expect(TimeFormatter.clock(81) == "1:21")
        #expect(TimeFormatter.clock(599.9) == "9:59")
    }

    @Test func formatsHours() {
        #expect(TimeFormatter.clock(3661) == "1:01:01")
    }

    @Test func clampsNegative() {
        #expect(TimeFormatter.clock(-5) == "0:00")
    }
}
