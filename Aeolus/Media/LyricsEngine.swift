import Foundation
import Observation

/// Синхронизированный текст через LRCLIB (бесплатный API без ключей).
/// Строго opt-in: запрос уходит только при включённой настройке (наружу
/// передаются название/исполнитель/длительность трека — и ничего больше).
@MainActor
@Observable
final class LyricsEngine {
    private(set) var lines: [LyricsParser.Line] = []
    private(set) var trackKey = ""

    @ObservationIgnored private var fetchTask: Task<Void, Never>?
    @ObservationIgnored private var cache: [String: [LyricsParser.Line]] = [:]

    func trackChanged(title: String?, artist: String?, duration: Double?) {
        guard Preferences.syncedLyrics else {
            lines = []
            return
        }
        guard let title, let artist else {
            lines = []
            return
        }
        let key = "\(title)|\(artist)"
        guard key != trackKey else { return }
        trackKey = key
        if let cached = cache[key] {
            lines = cached
            return
        }
        lines = []
        fetchTask?.cancel()
        fetchTask = Task { [weak self] in
            guard var components = URLComponents(string: "https://lrclib.net/api/get")
            else { return }
            var query = [
                URLQueryItem(name: "track_name", value: title),
                URLQueryItem(name: "artist_name", value: artist),
            ]
            if let duration {
                query.append(URLQueryItem(name: "duration", value: String(Int(duration))))
            }
            components.queryItems = query
            guard let url = components.url else { return }
            guard let (data, response) = try? await URLSession.shared.data(from: url),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let lrc = json["syncedLyrics"] as? String else { return }
            let parsed = LyricsParser.parse(lrc)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.trackKey == key else { return }
                self.cache[key] = parsed
                self.lines = parsed
            }
        }
    }
}
