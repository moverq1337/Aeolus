import SwiftUI

/// «Открыто»: короткий транзиент после разблокировки — открытый замочек в ушке.
struct UnlockFlashView: View {
    let notchSize: CGSize

    var body: some View {
        HStack {
            Image(systemName: "lock.open.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .transition(.scale.combined(with: .opacity))
            Spacer(minLength: notchSize.width)
            Spacer().frame(width: 20)
        }
        .padding(.horizontal, 16)
        .frame(height: notchSize.height)
    }
}
