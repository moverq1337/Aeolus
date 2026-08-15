import SwiftUI

/// «Открыто»: замочек появляется закрытым и через мгновение открывается
/// (symbol replace анимирует дужку) — остров «узнал» хозяина.
struct UnlockFlashView: View {
    let notchSize: CGSize

    @State private var opened = false

    var body: some View {
        HStack {
            Image(systemName: opened ? "lock.open.fill" : "lock.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
            Spacer(minLength: notchSize.width)
            Spacer().frame(width: 20)
        }
        .padding(.horizontal, 16)
        .frame(height: notchSize.height)
        .onAppear {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
                    opened = true
                }
            }
        }
    }
}
