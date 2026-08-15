import SwiftUI

/// Трёхзонная раскладка транзиентов: контент строго в «ушах», центр — мёртвая
/// зона физического выреза. Обычный Spacer(minLength:) раздаёт лишнюю ширину
/// так, что начало правого текста заезжает ПОД вырез и первые цифры невидимы
/// (баг «52% → 2%»); фиксированная центральная зона это исключает.
struct EarsLayout<Left: View, Right: View>: View {
    let notchSize: CGSize
    @ViewBuilder let left: Left
    @ViewBuilder let right: Right

    var body: some View {
        HStack(spacing: 0) {
            left.frame(maxWidth: .infinity, alignment: .leading)
            Color.clear.frame(width: notchSize.width)
            right.frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(height: notchSize.height)
    }
}
