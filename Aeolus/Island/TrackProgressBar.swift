import SwiftUI

struct TrackProgressBar: View {
    let duration: Double
    let isPlaying: Bool
    /// Позиция интерполируется локально из (elapsedTime, timestamp, playing) — спека §5.4.
    let position: (Date) -> Double
    /// Якорь позиции из источника. Меняется ровно тогда, когда источник
    /// подтвердил новую позицию, — по нему полоса отпускается после перемотки
    /// (событие, а не таймер).
    let anchor: Double
    let onSeek: (Double) -> Void

    @State private var scrubFraction: Double?
    /// Куда попросили перемотать, пока источник не подтвердил. Замер на живом
    /// стриме: Яндекс Музыка отвечает на seek через ~530 мс, и всё это время
    /// полоса показывала прежнюю позицию — отпустил палец на 0:45, полоса
    /// отскочила на 0:20 и через полсекунды прыгнула обратно.
    @State private var pinnedFraction: Double?

    var body: some View {
        // Пауза таймлайна: не играет, идёт скраб или ждём подтверждения
        // перемотки — кадры не рендерятся.
        let frozen = scrubFraction ?? pinnedFraction
        TimelineView(.animation(minimumInterval: 0.5, paused: !isPlaying || frozen != nil)) { ctx in
            let fraction = frozen
                ?? (duration > 0 ? min(position(ctx.date) / duration, 1) : 0)
            HStack(spacing: 8) {
                timeLabel(TimeFormatter.clock(fraction * duration))
                track(fraction: fraction)
                timeLabel("-" + TimeFormatter.clock((1 - fraction) * duration))
            }
        }
        .frame(height: 14)
        .onChange(of: anchor) { pinnedFraction = nil } // источник догнал
        // Страховка: источник может не подтвердить перемотку вовсе — тогда
        // отпускаем сами. Задача живёт только внутри окна ожидания.
        .task(id: pinnedFraction) {
            guard pinnedFraction != nil else { return }
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled else { return }
            pinnedFraction = nil
        }
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
                        pinnedFraction = f
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
