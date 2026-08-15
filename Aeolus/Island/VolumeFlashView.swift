import SwiftUI

/// Транзиент громкости при двухпальцевом вертикальном свайпе: иконка
/// устройства вывода слева, тонкая полоска + процент справа.
struct VolumeFlashView: View {
    let percent: Int
    let deviceIcon: String
    let notchSize: CGSize
    var overshoot: Double = 0

    var body: some View {
        HStack {
            Image(systemName: deviceIcon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
            Spacer(minLength: notchSize.width)
            HStack(spacing: 6) {
                Capsule().fill(.white.opacity(0.25))
                    .frame(width: 30, height: 3)
                    .scaleEffect(
                        x: 1 + abs(overshoot) * 0.15,
                        y: max(0.5, 1 - abs(overshoot) * 0.4),
                        anchor: overshoot < 0 ? .leading : .trailing)
                    .animation(.spring(response: 0.3, dampingFraction: 0.55), value: overshoot)
                    .overlay(alignment: .leading) {
                        Capsule().fill(.white)
                            .frame(width: max(2, 30 * CGFloat(percent) / 100))
                    }
                Text("\(percent)")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: notchSize.height)
    }
}
