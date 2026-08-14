import CoreGraphics

struct IslandLayout: Equatable {
    var notchSize: CGSize

    static let expandedSize = CGSize(width: 360, height: 178)
    /// С раскрытым слайдером громкости остров дорастает вниз.
    static let expandedVolumeSize = CGSize(width: 360, height: 206)
    static let earWidth: CGFloat = 44
    static let batteryEarWidth: CGFloat = 70
    static let peekDelta = CGSize(width: 10, height: 3)

    func size(for state: IslandState) -> CGSize {
        switch state.surface {
        case .collapsed:
            return collapsedSize(hasSession: state.hasSession)
        case .peek:
            let base = collapsedSize(hasSession: state.hasSession)
            return CGSize(width: base.width + Self.peekDelta.width,
                          height: base.height + Self.peekDelta.height)
        case .expanded:
            return state.volumeShown ? Self.expandedVolumeSize : Self.expandedSize
        case .battery:
            return CGSize(width: notchSize.width + 2 * Self.batteryEarWidth,
                          height: notchSize.height)
        }
    }

    func radii(for state: IslandState) -> (top: CGFloat, bottom: CGFloat) {
        switch state.surface {
        case .expanded: return (15, 20)
        case .peek: return (7, 16)
        case .collapsed, .battery: return (6, 14)
        }
    }

    private func collapsedSize(hasSession: Bool) -> CGSize {
        hasSession
            ? CGSize(width: notchSize.width + 2 * Self.earWidth, height: notchSize.height)
            : notchSize
    }
}
