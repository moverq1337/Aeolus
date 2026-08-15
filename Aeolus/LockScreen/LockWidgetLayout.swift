import CoreGraphics

/// Позиция карточки в глобальных AppKit-координатах (origin слева-внизу).
/// Карточка длинная и тонкая, прибита вниз — прямо над зоной аватара/пароля
/// (фидбек владельца 2026-08-15); слайдер только поднимает. Жёсткий нижний
/// зазор защищает зону пароля (класс багов Alcove #555).
enum LockWidgetLayout {
    static let cardSize = CGSize(width: 400, height: 178)
    /// Дефолтный отступ нижнего края карточки от низа экрана.
    static let baseBottomMargin: CGFloat = 240
    static let minBottomClearance: CGFloat = 220
    /// Слайдер поднимает карточку от дефолтной точки.
    static let offsetRange: ClosedRange<CGFloat> = 0...320

    static func frame(screenFrame: CGRect, userOffset: CGFloat) -> CGRect {
        let offset = min(max(userOffset, offsetRange.lowerBound), offsetRange.upperBound)
        let originX = screenFrame.midX - cardSize.width / 2
        let originY = max(
            screenFrame.minY + baseBottomMargin + offset,
            screenFrame.minY + minBottomClearance)
        return CGRect(x: originX, y: originY, width: cardSize.width, height: cardSize.height)
    }
}
