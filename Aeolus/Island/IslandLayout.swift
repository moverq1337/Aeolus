import CoreGraphics

struct IslandLayout: Equatable {
    var notchSize: CGSize

    static let expandedSize = CGSize(width: 360, height: 166)
    /// С раскрытым слайдером громкости остров дорастает вниз.
    static let expandedVolumeSize = CGSize(width: 360, height: 194)
    static let earWidth: CGFloat = 44
    static let batteryEarWidth: CGFloat = 70
    static let peekDelta = CGSize(width: 10, height: 3)

    func size(for state: IslandState) -> CGSize {
        if state.suppressed { return notchSize }
        switch state.surface {
        case .collapsed:
            return collapsedSize(hasSession: state.hasSession)
        case .peek:
            let base = collapsedSize(hasSession: state.hasSession)
            return CGSize(width: base.width + Self.peekDelta.width,
                          height: base.height + Self.peekDelta.height)
        case .expanded:
            let lyricsExtra: CGFloat = Preferences.syncedLyrics ? 20 : 0
            let base = (state.volumeShown || state.volumeOverlay)
                ? Self.expandedVolumeSize : Self.expandedSize
            return CGSize(width: base.width, height: base.height + lyricsExtra)
        case .battery, .volume, .device:
            return CGSize(width: notchSize.width + 2 * Self.batteryEarWidth,
                          height: notchSize.height)
        case .trackIntro:
            // Широкая тонкая пилюля (референс #13): между свёрнутым и раскрытым.
            return CGSize(width: 380, height: notchSize.height + 30)
        }
    }

    func radii(for state: IslandState) -> (top: CGFloat, bottom: CGFloat) {
        switch state.surface {
        case .expanded: return (15, 20)
        case .trackIntro: return (10, 18)
        case .peek: return (7, 16)
        case .collapsed, .battery, .volume, .device: return (6, 14)
        }
    }

    private func collapsedSize(hasSession: Bool) -> CGSize {
        hasSession
            ? CGSize(width: notchSize.width + 2 * Self.earWidth, height: notchSize.height)
            : notchSize
    }
}
