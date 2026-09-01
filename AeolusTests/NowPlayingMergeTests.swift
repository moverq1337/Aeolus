import Foundation
import Testing
@testable import Aeolus

struct NowPlayingMergeTests {
    let now = Date(timeIntervalSince1970: 1_000_000)
    let isoTimestamp = "2026-08-14T19:55:36Z"
    var isoDate: Date { try! Date(isoTimestamp, strategy: .iso8601) }

    private func envelope(_ json: String) throws -> AdapterEnvelope {
        try JSONDecoder().decode(AdapterEnvelope.self, from: Data(json.utf8))
    }

    @Test func fullPayloadCreatesState() throws {
        // Реальный формат адаптера: timestamp — ISO8601-строка.
        let e = try envelope(#"""
        {"type":"data","diff":false,"payload":{"bundleIdentifier":"com.apple.Music",
         "playing":true,"title":"Better Off","artist":"Montell Fish",
         "duration":109.0,"elapsedTime":21.0,"timestamp":"2026-08-14T19:55:36Z"}}
        """#)
        let s = try #require(NowPlayingMerge.apply(e, to: nil, now: now))
        #expect(s.title == "Better Off")
        #expect(s.artist == "Montell Fish")
        #expect(s.playing)
        #expect(s.duration == 109.0)
        #expect(s.elapsedTime == 21.0)
        #expect(s.timestamp == isoDate)
    }

    @Test func numericTimestampAlsoAccepted() throws {
        let e = try envelope(#"""
        {"type":"data","payload":{"title":"T","playing":true,
         "elapsedTime":1.0,"timestamp":999999.0}}
        """#)
        let s = try #require(NowPlayingMerge.apply(e, to: nil, now: now))
        #expect(s.timestamp == Date(timeIntervalSince1970: 999_999))
    }

    @Test func diffMergesOnlyPresentFields() throws {
        let base = try #require(NowPlayingMerge.apply(try envelope(#"""
        {"type":"data","payload":{"title":"Better Off","artist":"Montell Fish",
         "playing":true,"duration":109.0,"elapsedTime":21.0,
         "timestamp":"2026-08-14T19:55:36Z"}}
        """#), to: nil, now: now))
        let merged = try #require(NowPlayingMerge.apply(try envelope(#"""
        {"type":"data","diff":true,"payload":{"playing":false,"elapsedTime":30.0}}
        """#), to: base, now: now))
        #expect(merged.title == "Better Off")      // не тронуто диффом
        #expect(merged.playing == false)            // обновлено
        #expect(merged.elapsedTime == 30.0)         // обновлено
        #expect(merged.timestamp == now)            // elapsed без timestamp -> берём now
    }

    @Test func emptyFirstPayloadYieldsNil() throws {
        // Причуда адаптера #23: первый payload стрима может быть пустым.
        let e = try envelope(#"{"type":"data","diff":false,"payload":{}}"#)
        #expect(NowPlayingMerge.apply(e, to: nil, now: now) == nil)
    }

    @Test func untitledSessionYieldsNil() throws {
        let e = try envelope(#"""
        {"type":"data","payload":{"playing":true,"bundleIdentifier":"com.foo"}}
        """#)
        #expect(NowPlayingMerge.apply(e, to: nil, now: now) == nil)
    }

    @Test func infiniteDurationBecomesNil() throws {
        // Причуда #28: у live-стримов duration = Infinity. JSON не умеет Infinity,
        // поэтому конструируем payload напрямую (memberwise init).
        let payload = NowPlayingPayload(
            bundleIdentifier: nil, playing: true, title: "Radio", artist: nil,
            album: nil, duration: .infinity, elapsedTime: 5, timestamp: nil,
            artworkData: nil, artworkMimeType: nil)
        let e = AdapterEnvelope(type: "data", diff: false, payload: payload)
        let s = try #require(NowPlayingMerge.apply(e, to: nil, now: now))
        #expect(s.duration == nil)
    }

    @Test func fullPayloadReplacesEntireState() throws {
        let base = try #require(NowPlayingMerge.apply(try envelope(#"""
        {"type":"data","payload":{"title":"A","artist":"X","playing":true}}
        """#), to: nil, now: now))
        let next = try #require(NowPlayingMerge.apply(try envelope(#"""
        {"type":"data","diff":false,"payload":{"title":"B","playing":false}}
        """#), to: base, now: now))
        #expect(next.title == "B")
        #expect(next.artist == nil) // полный payload замещает, а не мёржит
    }

    @Test func shuffleModePassesThrough() throws {
        let base = try #require(NowPlayingMerge.apply(try envelope(#"""
        {"type":"data","payload":{"title":"T","playing":true,"shuffleMode":1}}
        """#), to: nil, now: now))
        #expect(base.shuffleMode == 1)
        let merged = try #require(NowPlayingMerge.apply(try envelope(#"""
        {"type":"data","diff":true,"payload":{"shuffleMode":2}}
        """#), to: base, now: now))
        #expect(merged.shuffleMode == 2)
        #expect(merged.title == "T")
    }

    @Test func blankMetadataTreatedAsAbsent() throws {
        // Яндекс Музыка в первом payload'е шлёт artist:"" / album:"".
        let e = try envelope(#"""
        {"type":"data","payload":{"title":"FARTANIA","artist":"","album":"",
         "playing":true,"duration":0.0}}
        """#)
        let s = try #require(NowPlayingMerge.apply(e, to: nil, now: now))
        #expect(s.artist == nil)
        #expect(s.album == nil)
        #expect(s.duration == nil) // duration 0 — «ещё не знаем»
    }

    @Test func blankFieldInDiffKeepsPreviousValue() throws {
        let base = try #require(NowPlayingMerge.apply(try envelope(#"""
        {"type":"data","payload":{"title":"T","artist":"Real Artist","playing":true}}
        """#), to: nil, now: now))
        let merged = try #require(NowPlayingMerge.apply(try envelope(#"""
        {"type":"data","diff":true,"payload":{"artist":"  "}}
        """#), to: base, now: now))
        #expect(merged.artist == "Real Artist")
    }

    @Test func blankTitleYieldsNoSession() throws {
        let e = try envelope(#"{"type":"data","payload":{"title":"  ","playing":true}}"#)
        #expect(NowPlayingMerge.apply(e, to: nil, now: now) == nil)
    }

    @Test func positionInterpolatesWhilePlaying() throws {
        let s = NowPlayingState(
            bundleIdentifier: nil, playing: true, title: "T", artist: nil, album: nil,
            duration: 100, elapsedTime: 20, timestamp: now, artworkData: nil,
            shuffleMode: nil)
        #expect(s.position(at: now.addingTimeInterval(5)) == 25)
        var paused = s
        paused.playing = false
        #expect(paused.position(at: now.addingTimeInterval(5)) == 20)
        #expect(s.position(at: now.addingTimeInterval(1000)) == 100) // кламп к duration
    }
}
