import SwiftUI

struct TrackProgressBar: View {
    let duration: Double
    let isPlaying: Bool
    /// Позиция интерполируется локально из (elapsedTime, timestamp, playing) — спека §5.4.
    let position: (Date) -> Double
    let onSeek: (Double) -> Void

    @State private var scrubFraction: Double?

    var body: some View {
        // Пауза таймлайна: не играет или идёт скраб — кадры не рендерятся.
        TimelineView(.animation(minimumInterval: 0.5, paused: !isPlaying || scrubFraction != nil)) { ctx in
            let fraction = scrubFraction
                ?? (duration > 0 ? min(position(ctx.date) / duration, 1) : 0)
            HStack(spacing: 8) {
                timeLabel(TimeFormatter.clock(fraction * duration))
                track(fraction: fraction)
                timeLabel("-" + TimeFormatter.clock((1 - fraction) * duration))
            }
        }
        .frame(height: 14)
    }

    private func track(fraction: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.25))
                Capsule().fill(.white.opacity(0.85))
                    .frame(width: max(4, geo.size.width * fraction))
            }
            .frame(height: 4)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        scrubFraction = min(max(v.location.x / geo.size.width, 0), 1)
                    }
                    .onEnded { v in
                        let f = min(max(v.location.x / geo.size.width, 0), 1)
                        onSeek(f * duration)
                        scrubFraction = nil
                    })
        }
        .frame(height: 12)
    }

    private func timeLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium).monospacedDigit())
            .foregroundStyle(.white.opacity(0.55))
            .frame(minWidth: 34)
    }
}
