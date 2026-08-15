import SwiftUI
import Observation

/// Управляет вырастанием/сжатием пилюли замочка.
@MainActor
@Observable
final class LockNotchPresentation {
    var grown = false
}

/// Замочек у выреза на экране блокировки: пилюля ВЫРАСТАЕТ из выреза пружиной
/// (никакой прозрачности — морфинг размеров, как живёт сам остров).
struct LockNotchView: View {
    let notchSize: CGSize
    let earWidth: CGFloat
    var presentation: LockNotchPresentation

    private var grown: Bool { presentation.grown }

    var body: some View {
        NotchShape(topCornerRadius: 6, bottomCornerRadius: 14)
            .fill(Color.black)
            .overlay {
                HStack {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .opacity(grown ? 1 : 0)
                    Spacer(minLength: notchSize.width)
                    Spacer().frame(width: 18)
                }
                .padding(.horizontal, 15)
            }
            .frame(
                width: grown ? notchSize.width + 2 * earWidth : notchSize.width,
                height: notchSize.height)
            .animation(
                grown
                    ? .spring(response: 0.42, dampingFraction: 0.8)
                    : .spring(response: 0.35, dampingFraction: 1.0),
                value: grown)
            .frame(maxWidth: .infinity, alignment: .center)
            .environment(\.colorScheme, .dark)
    }
}
