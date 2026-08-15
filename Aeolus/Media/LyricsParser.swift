import Foundation

/// Парсер LRC-текста (формат LRCLIB): [mm:ss.xx] строка.
enum LyricsParser {
    struct Line: Equatable {
        var time: TimeInterval
        var text: String
    }

    static func parse(_ lrc: String) -> [Line] {
        var lines: [Line] = []
        for raw in lrc.split(separator: "\n") {
            let s = raw.trimmingCharacters(in: .whitespaces)
            guard s.hasPrefix("["),
                  let close = s.firstIndex(of: "]") else { continue }
            let stamp = String(s[s.index(after: s.startIndex)..<close])
            let parts = stamp.split(separator: ":")
            guard parts.count == 2,
                  let minutes = Double(parts[0]),
                  let seconds = Double(parts[1]) else { continue }
            let text = String(s[s.index(after: close)...])
                .trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }
            lines.append(Line(time: minutes * 60 + seconds, text: text))
        }
        return lines.sorted { $0.time < $1.time }
    }

    /// Активная строка на позиции воспроизведения (последняя с time <= position).
    static func currentLine(_ lines: [Line], at position: TimeInterval) -> Line? {
        var result: Line?
        for line in lines {
            if line.time <= position { result = line } else { break }
        }
        return result
    }
}
