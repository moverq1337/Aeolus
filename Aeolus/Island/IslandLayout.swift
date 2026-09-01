import CoreGraphics

struct IslandLayout: Equatable {
    var notchSize: CGSize

    /// Высота выреза, под которую подобраны все точечные размеры ниже:
    /// MacBook Pro 14" в дефолтном масштабе (замер 2026-09-01 — вырез 189x32pt).
    static let referenceNotchHeight: CGFloat = 32

    static let expandedSize = CGSize(width: 360, height: 166)
    /// С раскрытым слайдером громкости остров дорастает вниз.
    static let expandedVolumeSize = CGSize(width: 360, height: 194)
    static let earWidth: CGFloat = 44
    // 84: правое ухо должно вмещать «48% · 96W» целиком (текст под вырезом невидим).
    static let batteryEarWidth: CGFloat = 84
    /// Широкая тонкая пилюля смены трека (референс #13).
    static let trackIntroWidth: CGFloat = 380
    static let trackIntroGrowth: CGFloat = 30
    /// Строка текста песни дорастает раскрытый плеер вниз.
    static let lyricsExtra: CGFloat = 20
    static let peekDelta = CGSize(width: 10, height: 3)

    /// Ни одна раскрытая поверхность не может быть уже свёрнутой с ушами.
    ///
    /// Вырез физически один и тот же в любом режиме экрана, но В ПОИНТАХ он
    /// растёт вдвое между масштабами и вчетверо при 1:1 — замер 2026-09-01 по
    /// всем режимам встроенного экрана: 189pt на дефолтном 1512x982 против
    /// 378pt на 3024x1964@1x. Плеер шириной 360pt при таком вырезе целиком
    /// прячется ЗА физическим вырезом: «музыка играет, а острова нет».
    private var minimumSurfaceWidth: CGFloat { notchSize.width + 2 * Self.earWidth }

    /// Контент раскрытого плеера рисуется ПОД вырезом (верхний паддинг равен
    /// его высоте), поэтому на вырезе выше эталонного плеер обязан дорасти
    /// ровно на разницу — иначе ряду кнопок не остаётся места.
    private var heightGrowth: CGFloat {
        max(0, notchSize.height - Self.referenceNotchHeight)
    }

    func size(for state: IslandState, lyricsEnabled: Bool = false) -> CGSize {
        if state.suppressed { return notchSize }
        switch state.surface {
        case .collapsed:
            return collapsedSize(hasSession: state.hasSession)
        case .peek:
            let base = collapsedSize(hasSession: state.hasSession)
            return CGSize(width: base.width + Self.peekDelta.width,
                          height: base.height + Self.peekDelta.height)
        case .expanded:
            let lyricsExtra: CGFloat = lyricsEnabled ? Self.lyricsExtra : 0
            let base = (state.volumeShown || state.volumeOverlay)
                ? Self.expandedVolumeSize : Self.expandedSize
            return CGSize(width: max(base.width, minimumSurfaceWidth),
                          height: base.height + lyricsExtra + heightGrowth)
        case .battery, .volume, .device:
            return CGSize(width: notchSize.width + 2 * Self.batteryEarWidth,
                          height: notchSize.height)
        case .trackIntro:
            // Широкая тонкая пилюля (референс #13): между свёрнутым и раскрытым.
            return CGSize(width: max(Self.trackIntroWidth, minimumSurfaceWidth),
                          height: notchSize.height + Self.trackIntroGrowth)
        }
    }

    /// Самая большая из поверхностей — по ней считается окно. SwiftUI за
    /// границы окна не рисует: поверхность шире окна молча обрезается, и на
    /// крупных вырезах у батарейного транзиента отъедало уши.
    var widestSize: CGSize {
        let width = max(
            max(Self.expandedVolumeSize.width, minimumSurfaceWidth),
            max(Self.trackIntroWidth, notchSize.width + 2 * Self.batteryEarWidth))
        let height = max(
            Self.expandedVolumeSize.height + Self.lyricsExtra + heightGrowth,
            notchSize.height + Self.trackIntroGrowth)
        return CGSize(width: width, height: height)
    }

    /// Во сколько раз вырез крупнее эталонного. Тем же множителем живут
    /// скругления поверхностей, обнимающих вырез.
    private var notchScale: CGFloat { notchSize.height / Self.referenceNotchHeight }

    func radii(for state: IslandState) -> (top: CGFloat, bottom: CGFloat) {
        switch state.surface {
        // Раскрытый плеер и пилюля смены трека — обычные панели интерфейса:
        // их углы живут в поинтах, как шрифты и отступы, и физического выреза
        // не касаются.
        case .expanded: return (15, 20)
        case .trackIntro: return (10, 18)
        // А эти поверхности обнимают сам вырез — их углы обязаны совпасть с
        // ним. Скругление тоже физическое, а не точечное, по той же причине,
        // что и перекрытие (см. NotchGeometry): вырез один и тот же, а его
        // размер в поинтах меняется вчетверо. Фиксированные 14pt давали от
        // 23.5 до 37 физических пикселей — нижние углы формы то острее
        // настоящего выреза, то круглее его.
        case .peek: return (7 * notchScale, 16 * notchScale)
        case .collapsed, .battery, .volume, .device:
            return (6 * notchScale, 14 * notchScale)
        }
    }

    private func collapsedSize(hasSession: Bool) -> CGSize {
        hasSession
            ? CGSize(width: notchSize.width + 2 * Self.earWidth, height: notchSize.height)
            : notchSize
    }
}
