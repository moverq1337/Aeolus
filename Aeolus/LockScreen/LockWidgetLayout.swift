import CoreGraphics

/// Позиция карточки в глобальных AppKit-координатах (origin слева-внизу).
/// Карточка сидит между часами (верх) и стопкой аватар/пароль (низ); жёсткий
/// нижний зазор недостижим для зоны пароля (защита от класса багов Alcove #555).
enum LockWidgetLayout {
    static let cardSize = CGSize(width: 340, height: 150)
    static let baseOffsetBelowCenter: CGFloat = 60
    static let minBottomClearance: CGFloat = 220
    static let offsetRange: ClosedRange<CGFloat> = -160...160

    static func frame(screenFrame: CGRect, userOffset: CGFloat) -> CGRect {
        let offset = min(max(userOffset, offsetRange.lowerBound), offsetRange.upperBound)
        let originX = screenFrame.midX - cardSize.width / 2
        // Верхний край номинально на baseOffsetBelowCenter ниже центра; offset>0 — вверх.
        let nominalOriginY =
            screenFrame.midY - baseOffsetBelowCenter - cardSize.height + offset
        let minOriginY = screenFrame.minY + minBottomClearance
        let originY = max(nominalOriginY, minOriginY)
        return CGRect(x: originX, y: originY, width: cardSize.width, height: cardSize.height)
    }
}
