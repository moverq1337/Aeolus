import SwiftUI

/// AirPods-момент: устройство подключилось — иконка слева, справа дуга заряда
/// с процентом (как у iOS Dynamic Island).
struct DeviceFlashView: View {
    let flash: DeviceFlash
    let notchSize: CGSize

    @State private var arcShown = false

    var body: some View {
        EarsLayout(notchSize: notchSize) {
            Image(systemName: flash.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        } right: {
            if let percent = flash.percentage {
                HStack(spacing: 6) {
                    ZStack {
                        Circle().stroke(arcColor(percent).opacity(0.25), lineWidth: 2)
                        Circle()
                            .trim(from: 0, to: arcShown ? CGFloat(percent) / 100 : 0)
                            .stroke(arcColor(percent),
                                    style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 15, height: 15)
                    Text("\(percent)%")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white)
                }
            } else {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.green)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                arcShown = true
            }
        }
    }

    private func arcColor(_ percent: Int) -> Color {
        percent <= 20 ? .orange : .green
    }
}
