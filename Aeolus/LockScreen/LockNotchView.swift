import SwiftUI

/// Замочек у выреза на экране блокировки (как у Alcove): чёрная пилюля формы
/// острова, закрытый замок в левом ушке.
struct LockNotchView: View {
    let notchSize: CGSize
    let earWidth: CGFloat

    var body: some View {
        NotchShape(topCornerRadius: 6, bottomCornerRadius: 14)
            .fill(Color.black)
            .overlay {
                HStack {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer(minLength: notchSize.width)
                    Spacer().frame(width: 18)
                }
                .padding(.horizontal, 15)
            }
            .frame(width: notchSize.width + 2 * earWidth, height: notchSize.height)
            .environment(\.colorScheme, .dark)
    }
}
