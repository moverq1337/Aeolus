import SwiftUI

struct ControlButton: View {
    let systemName: String
    var size: CGFloat = 16
    var tint: Color = .white
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(tint)
            .contentTransition(.symbolEffect(.replace))
            .animation(.spring(response: 0.42, dampingFraction: 0.8), value: systemName)
            .frame(width: 40, height: 32)
            .contentShape(Rectangle())
            .scaleEffect(pressed ? 0.86 : 1)
            .animation(.interactiveSpring(response: 0.38, dampingFraction: 0.8), value: pressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in pressed = true }
                    .onEnded { v in
                        pressed = false
                        if abs(v.translation.width) < 8, abs(v.translation.height) < 8 {
                            action()
                        }
                    })
    }
}
