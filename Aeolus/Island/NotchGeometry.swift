import CoreGraphics

/// Все координаты — глобальные AppKit (origin слева-внизу).
struct NotchMetrics: Equatable {
    var notchRect: CGRect
    var windowFrame: CGRect
    var closedSize: CGSize
}

enum NotchGeometry {
    /// Перекрытие физического выреза по ширине — прячет шов антиалиасинга.
    static let widthOverlap: CGFloat = 4
    /// Запас окна вокруг раскрытого острова под тень.
    static let shadowPadding: CGFloat = 20

    static func metrics(
        screenFrame: CGRect,
        auxLeftWidth: CGFloat?,
        auxRightWidth: CGFloat?,
        safeAreaTop: CGFloat,
        expandedSize: CGSize
    ) -> NotchMetrics? {
        guard safeAreaTop > 0,
              let left = auxLeftWidth, left > 0,
              let right = auxRightWidth, right > 0 else { return nil }

        let notchWidth = screenFrame.width - left - right + widthOverlap
        let notchHeight = safeAreaTop
        let notchRect = CGRect(
            x: screenFrame.origin.x + (screenFrame.width - notchWidth) / 2,
            y: screenFrame.maxY - notchHeight,
            width: notchWidth,
            height: notchHeight)

        let windowSize = CGSize(
            width: max(expandedSize.width, notchWidth) + shadowPadding * 2,
            height: expandedSize.height + shadowPadding)
        let windowFrame = CGRect(
            x: screenFrame.midX - windowSize.width / 2,
            y: screenFrame.maxY - windowSize.height,
            width: windowSize.width,
            height: windowSize.height)

        return NotchMetrics(
            notchRect: notchRect,
            windowFrame: windowFrame,
            closedSize: CGSize(width: notchWidth, height: notchHeight))
    }
}
