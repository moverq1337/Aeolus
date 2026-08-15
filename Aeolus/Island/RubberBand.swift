import SwiftUI

/// Канонический iOS 17 rubber-band (анализ 2026-08-15, Kavsoft/Control Center):
/// заполнение никогда не покидает 0…100% — деформируется капсула целиком,
/// растягиваясь в сторону упора с лёгким утоньшением (squash-and-stretch).
enum RubberBandMath {
    /// Асимптотическое сопротивление Apple (WWDC18 Fluid Interfaces):
    /// f(x) = (x·c·d)/(d + c·x), c = 0.55 — приближается к d, не достигая.
    /// Возвращает долю максимального растяжения −1…1, знак = направление.
    static func dampedFraction(excessPoints: Double, dimension: Double = 60) -> Double {
        guard excessPoints != 0 else { return 0 }
        let x = abs(excessPoints)
        let damped = (x * 0.55 * dimension) / (dimension + 0.55 * x)
        return (excessPoints < 0 ? -1 : 1) * damped / dimension
    }

    /// Прирост длины бара как доля ширины: 10% ширины, но не больше 8pt —
    /// иначе широкая строка плеера задевает соседей.
    static func stretch(overshoot: Double, barWidth: Double) -> Double {
        guard barWidth > 0 else { return 0 }
        return abs(overshoot) * min(barWidth * 0.10, 8) / barWidth
    }
}

/// Растяжение применяется ПОСЛЕ clip — силуэт тянется, содержимое не вылезает.
/// Якорь — дальний конец: капсула удлиняется только в сторону, куда давят.
struct RubberBandStretch: ViewModifier {
    let overshoot: Double
    let barWidth: CGFloat

    func body(content: Content) -> some View {
        let s = CGFloat(RubberBandMath.stretch(
            overshoot: overshoot, barWidth: Double(barWidth)))
        content
            .scaleEffect(
                x: 1 + s,
                y: 1 - s * 0.25,
                anchor: overshoot > 0 ? .leading : .trailing)
            .animation(
                overshoot == 0
                    ? .spring(response: 0.35, dampingFraction: 0.7)
                    : .interactiveSpring(response: 0.15, dampingFraction: 0.9),
                value: overshoot)
    }
}

extension View {
    func rubberBandStretch(_ overshoot: Double, barWidth: CGFloat) -> some View {
        modifier(RubberBandStretch(overshoot: overshoot, barWidth: barWidth))
    }
}
