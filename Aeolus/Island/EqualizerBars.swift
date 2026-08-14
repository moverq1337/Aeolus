import SwiftUI

/// 5 «дышащих» полосок. Анимация живёт ТОЛЬКО пока animating == true —
/// TimelineView на паузе не рендерит кадры (инвариант простоя, спека §6).
struct EqualizerBars: View {
    var animating: Bool
    var barCount = 5

    var body: some View {
        // Пауза и в Low Power Mode (спека §5.6): кадры не рендерятся.
        TimelineView(.animation(
            minimumInterval: 1.0 / 30.0,
            paused: !animating || ProcessInfo.processInfo.isLowPowerModeEnabled)
        ) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2) {
                ForEach(0..<barCount, id: \.self) { i in
                    Capsule(style: .continuous)
                        .frame(width: 2, height: barHeight(t: t, index: i))
                }
            }
            .foregroundStyle(.white)
            .frame(height: 14)
        }
    }

    private func barHeight(t: TimeInterval, index: Int) -> CGFloat {
        guard animating else { return 3 }
        let phase = Double(index) * 1.7
        let speed = 1.6 + Double(index % 3) * 0.35
        return 3 + 9 * abs(sin(t * speed + phase))
    }
}
