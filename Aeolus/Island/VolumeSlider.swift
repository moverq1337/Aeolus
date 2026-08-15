import SwiftUI

struct VolumeSlider: View {
    let volume: Float
    var showPercent = false
    var deviceIcon = "speaker.wave.3.fill"
    /// −1…1: упругое растяжение шкалы при упоре в края (rubber-band).
    var overshoot: Double = 0
    /// Клик по иконке устройства — свитчер выхода (nil = не интерактивно).
    var onDeviceTap: (() -> Void)? = nil
    let onChange: (Float) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.55))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.25))
                    Capsule().fill(.white.opacity(0.85))
                        .frame(width: max(3, geo.size.width * CGFloat(volume)))
                }
                .frame(height: 4)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            onChange(Float(min(max(v.location.x / geo.size.width, 0), 1)))
                        })
            }
            .frame(height: 12)
            .scaleEffect(
                x: 1 + abs(overshoot) * 0.18,
                y: max(0.45, 1 - abs(overshoot) * 0.5),
                anchor: overshoot < 0 ? .leading : .trailing)
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: overshoot)
            Image(systemName: deviceIcon)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(onDeviceTap != nil ? 0.8 : 0.55))
                .contentShape(Rectangle())
                .onTapGesture { onDeviceTap?() }
            if showPercent {
                Text("\(Int((volume * 100).rounded()))")
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 24, alignment: .trailing)
            }
        }
    }
}
