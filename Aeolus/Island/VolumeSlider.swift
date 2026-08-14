import SwiftUI

struct VolumeSlider: View {
    let volume: Float
    let deviceIcon: String
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
            Image(systemName: deviceIcon)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.55))
        }
    }
}
