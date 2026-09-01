import Foundation

private extension String {
    /// Пустая строка от источника означает «поля нет», а не «поле пустое»:
    /// Яндекс Музыка в первом payload'е шлёт `artist:""`, `album:""` — в диффе
    /// такое поле должно оставить прежнее значение, а не затереть его.
    var nonBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}

struct AdapterEnvelope: Decodable {
    let type: String
    let diff: Bool?
    let payload: NowPlayingPayload?

    init(type: String, diff: Bool?, payload: NowPlayingPayload?) {
        self.type = type
        self.diff = diff
        self.payload = payload
    }
}

struct NowPlayingPayload: Decodable {
    var bundleIdentifier: String?
    var playing: Bool?
    var title: String?
    var artist: String?
    var album: String?
    var duration: Double?
    var elapsedTime: Double?
    /// Адаптер шлёт ISO8601-строку ("2026-08-14T19:55:36Z"); числовой epoch —
    /// запасной вариант на случай смены формата.
    var timestamp: Date?
    var artworkData: String?
    var artworkMimeType: String?
    var shuffleMode: Int?

    init(
        bundleIdentifier: String?, playing: Bool?, title: String?, artist: String?,
        album: String?, duration: Double?, elapsedTime: Double?, timestamp: Date?,
        artworkData: String?, artworkMimeType: String?, shuffleMode: Int? = nil
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.playing = playing
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.elapsedTime = elapsedTime
        self.timestamp = timestamp
        self.artworkData = artworkData
        self.artworkMimeType = artworkMimeType
        self.shuffleMode = shuffleMode
    }

    private enum CodingKeys: String, CodingKey {
        case bundleIdentifier, playing, title, artist, album
        case duration, elapsedTime, timestamp, artworkData, artworkMimeType
        case shuffleMode
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bundleIdentifier = try c.decodeIfPresent(String.self, forKey: .bundleIdentifier)
        playing = try c.decodeIfPresent(Bool.self, forKey: .playing)
        title = try c.decodeIfPresent(String.self, forKey: .title)?.nonBlank
        artist = try c.decodeIfPresent(String.self, forKey: .artist)?.nonBlank
        album = try c.decodeIfPresent(String.self, forKey: .album)?.nonBlank
        duration = try c.decodeIfPresent(Double.self, forKey: .duration)
        elapsedTime = try c.decodeIfPresent(Double.self, forKey: .elapsedTime)
        artworkData = try c.decodeIfPresent(String.self, forKey: .artworkData)
        artworkMimeType = try c.decodeIfPresent(String.self, forKey: .artworkMimeType)
        shuffleMode = try c.decodeIfPresent(Int.self, forKey: .shuffleMode)
        if let epoch = try? c.decodeIfPresent(Double.self, forKey: .timestamp) {
            timestamp = Date(timeIntervalSince1970: epoch)
        } else if let iso = try? c.decodeIfPresent(String.self, forKey: .timestamp) {
            timestamp = Self.parseISO(iso)
        } else {
            timestamp = nil
        }
    }

    private static func parseISO(_ string: String) -> Date? {
        if let date = try? Date(string, strategy: .iso8601) { return date }
        return try? Date(
            string,
            strategy: .iso8601.year().month().day()
                .timeZone(separator: .omitted)
                .time(includingFractionalSeconds: true))
    }
}

struct NowPlayingState: Equatable {
    var bundleIdentifier: String?
    var playing: Bool
    var title: String
    var artist: String?
    var album: String?
    /// nil — длительность неизвестна или бесконечна (live): прогресс-бар скрыт.
    var duration: Double?
    var elapsedTime: Double
    /// Момент, в который был снят elapsedTime; позиция интерполируется от него.
    var timestamp: Date
    var artworkData: Data?
    /// 1 = выкл, 2/3 = включён (семантика адаптера).
    var shuffleMode: Int?

    func position(at date: Date) -> Double {
        let raw = playing
            ? elapsedTime + date.timeIntervalSince(timestamp)
            : elapsedTime
        if let duration { return min(max(raw, 0), duration) }
        return max(raw, 0)
    }
}

enum NowPlayingMerge {
    static func apply(
        _ envelope: AdapterEnvelope,
        to current: NowPlayingState?,
        now: Date
    ) -> NowPlayingState? {
        guard envelope.type == "data" else { return current }
        guard let p = envelope.payload else {
            return (envelope.diff ?? false) ? current : nil
        }
        if envelope.diff ?? false, var s = current {
            if let v = p.bundleIdentifier { s.bundleIdentifier = v }
            if let v = p.playing { s.playing = v }
            if let v = p.title { s.title = v }
            if let v = p.artist { s.artist = v }
            if let v = p.album { s.album = v }
            if let v = p.duration { s.duration = sanitize(duration: v) }
            if let v = p.elapsedTime {
                s.elapsedTime = v
                s.timestamp = p.timestamp ?? now
            } else if let t = p.timestamp {
                s.timestamp = t
            }
            if let v = p.artworkData { s.artworkData = Data(base64Encoded: v) }
            if let v = p.shuffleMode { s.shuffleMode = v }
            return s
        }
        return fullState(from: p, now: now)
    }

    private static func fullState(from p: NowPlayingPayload, now: Date) -> NowPlayingState? {
        // Причуды #23/#39: пустой или безымянный payload — «ничего не играет».
        guard let title = p.title, !title.isEmpty else { return nil }
        return NowPlayingState(
            bundleIdentifier: p.bundleIdentifier,
            playing: p.playing ?? false,
            title: title,
            artist: p.artist,
            album: p.album,
            duration: p.duration.flatMap(sanitize(duration:)),
            elapsedTime: p.elapsedTime ?? 0,
            timestamp: p.timestamp ?? now,
            artworkData: p.artworkData.flatMap { Data(base64Encoded: $0) },
            shuffleMode: p.shuffleMode)
    }

    private static func sanitize(duration: Double) -> Double? {
        duration.isFinite && duration > 0 ? duration : nil
    }
}
