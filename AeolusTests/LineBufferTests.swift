import Foundation
import Testing
@testable import Aeolus

struct LineBufferTests {
    @Test func splitsCompleteLines() {
        var b = LineBuffer()
        let lines = b.lines(appending: Data("one\ntwo\n".utf8))
        #expect(lines == [Data("one".utf8), Data("two".utf8)])
    }

    @Test func buffersPartialChunks() {
        var b = LineBuffer()
        #expect(b.lines(appending: Data("par".utf8)).isEmpty)
        #expect(b.lines(appending: Data("tial\nrest".utf8)) == [Data("partial".utf8)])
        #expect(b.lines(appending: Data("\n".utf8)) == [Data("rest".utf8)])
    }
}
