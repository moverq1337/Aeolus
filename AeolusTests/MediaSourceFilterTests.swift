import Testing
@testable import Aeolus

struct MediaSourceFilterTests {
    @Test func conferencingAlwaysBlocked() {
        #expect(MediaSourceFilter.isBlocked(
            "org.jitsi.jitsi-meet", artist: "Somebody", extra: []))
        #expect(MediaSourceFilter.isBlocked(
            "us.zoom.xos", artist: nil, extra: []))
        #expect(MediaSourceFilter.isBlocked(
            "com.apple.FaceTime", artist: nil, extra: []))
    }

    @Test func telegramVoiceAndCirclesBlockedByMarker() {
        #expect(MediaSourceFilter.isBlocked(
            "ru.keepcoder.Telegram", artist: "video message", extra: []))
        #expect(MediaSourceFilter.isBlocked(
            "ru.keepcoder.Telegram", artist: "Voice Message", extra: []))
        #expect(MediaSourceFilter.isBlocked(
            "org.telegram.desktop", artist: "видеосообщение", extra: []))
    }

    @Test func telegramRealMusicAllowed() {
        #expect(!MediaSourceFilter.isBlocked(
            "ru.keepcoder.Telegram", artist: "SKY RAE", extra: []))
        #expect(!MediaSourceFilter.isBlocked(
            "ru.keepcoder.Telegram", artist: nil, extra: []))
    }

    @Test func playersAndBrowsersAllowed() {
        #expect(!MediaSourceFilter.isBlocked(
            "com.spotify.client", artist: "Asal", extra: []))
        #expect(!MediaSourceFilter.isBlocked(
            "com.google.Chrome", artist: nil, extra: []))
        #expect(!MediaSourceFilter.isBlocked(nil, artist: nil, extra: []))
    }

    @Test func userExtraListBlocksHard() {
        #expect(MediaSourceFilter.isBlocked(
            "com.example.weird", artist: "Artist", extra: ["com.example.weird"]))
    }
}
