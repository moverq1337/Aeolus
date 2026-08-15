import Testing
@testable import Aeolus

struct MediaSourceFilterTests {
    @Test func blocksMessengersAndConferencing() {
        #expect(MediaSourceFilter.isBlocked("ru.keepcoder.Telegram", extra: []))
        #expect(MediaSourceFilter.isBlocked("org.telegram.desktop", extra: []))
        #expect(MediaSourceFilter.isBlocked("org.jitsi.jitsi-meet", extra: []))
        #expect(MediaSourceFilter.isBlocked("us.zoom.xos", extra: []))
        #expect(MediaSourceFilter.isBlocked("com.hnc.Discord", extra: []))
    }

    @Test func allowsPlayersAndBrowsers() {
        #expect(!MediaSourceFilter.isBlocked("com.spotify.client", extra: []))
        #expect(!MediaSourceFilter.isBlocked("com.apple.Music", extra: []))
        #expect(!MediaSourceFilter.isBlocked("com.google.Chrome", extra: []))
        #expect(!MediaSourceFilter.isBlocked("com.apple.Safari", extra: []))
        #expect(!MediaSourceFilter.isBlocked(nil, extra: [])) // неизвестный — пускаем
    }

    @Test func userExtraListBlocks() {
        #expect(MediaSourceFilter.isBlocked(
            "com.example.weird", extra: ["com.example.weird"]))
        #expect(!MediaSourceFilter.isBlocked("com.example.weird", extra: []))
    }
}
