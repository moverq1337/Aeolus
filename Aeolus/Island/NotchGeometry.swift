import CoreGraphics

/// Все координаты — глобальные AppKit (origin слева-внизу).
struct NotchMetrics: Equatable {
    var notchRect: CGRect
    var windowFrame: CGRect
    var closedSize: CGSize
}

enum NotchGeometry {
    /// Перекрытие физического выреза по ширине — прячет шов антиалиасинга.
    ///
    /// Задано ДОЛЕЙ от самого выреза, а не поинтами. Вырез физически один и тот
    /// же в любом режиме экрана (~370 px на MacBook Pro 14"), но в поинтах он
    /// меняется вдвое между масштабами и вчетверо при 1:1 — замер 2026-09-01 по
    /// всем режимам встроенного экрана: 126pt на 1024x665, 185pt на 1512x982,
    /// 220pt на 1800x1169, 370pt на 3024x1964@1x.
    /// Фиксированные 4pt давали от 6.7 до 11.8 физических пикселей перекрытия:
    /// на мелком масштабе чёрная форма вылезала за вырез губой, на крупном
    /// оголялся шов. Доля держит ~8 физических пикселей в любом режиме.
    /// 4/185 — та самая четвёрка, подобранная на дефолтном масштабе.
    static let widthOverlapRatio: CGFloat = 4.0 / 185.0
    /// Запас окна вокруг раскрытого острова под тень.
    static let shadowPadding: CGFloat = 20

    /// Перекрытие в поинтах. Округляем до целого: ширина выреза в поинтах у
    /// macOS всегда целая, и дробное перекрытие увело бы края формы на половину
    /// пикселя — антиалиасинг нарисовал бы ровно тот шов, который мы прячем.
    static func widthOverlap(notchWidth: CGFloat) -> CGFloat {
        max(1, (notchWidth * widthOverlapRatio).rounded())
    }

    static func metrics(
        screenFrame: CGRect,
        auxLeftWidth: CGFloat?,
        auxRightWidth: CGFloat?,
        safeAreaTop: CGFloat
    ) -> NotchMetrics? {
        guard safeAreaTop > 0,
              let left = auxLeftWidth, left > 0,
              let right = auxRightWidth, right > 0 else { return nil }

        let bareWidth = screenFrame.width - left - right
        let notchWidth = bareWidth + widthOverlap(notchWidth: bareWidth)
        let notchHeight = safeAreaTop
        let notchRect = CGRect(
            x: screenFrame.origin.x + (screenFrame.width - notchWidth) / 2,
            y: screenFrame.maxY - notchHeight,
            width: notchWidth,
            height: notchHeight)
        let closedSize = CGSize(width: notchWidth, height: notchHeight)

        // Окно должно вмещать САМОЕ БОЛЬШОЕ состояние острова плюс запас под
        // тень. Раньше здесь стоял фиксированный размер раскрытого плеера, и
        // на крупных вырезах окно оказывалось уже острова: уши батарейного
        // транзиента обрезались, а при 1:1 плеер вовсе прятался за вырезом.
        let widest = IslandLayout(notchSize: closedSize).widestSize
        let windowSize = CGSize(
            width: widest.width + shadowPadding * 2,
            height: widest.height + shadowPadding)
        let windowFrame = CGRect(
            x: screenFrame.midX - windowSize.width / 2,
            y: screenFrame.maxY - windowSize.height,
            width: windowSize.width,
            height: windowSize.height)

        return NotchMetrics(
            notchRect: notchRect,
            windowFrame: windowFrame,
            closedSize: closedSize)
    }
}
