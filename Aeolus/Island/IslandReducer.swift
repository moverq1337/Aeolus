enum IslandReducer {
    static func reduce(_ s: inout IslandState, _ e: IslandEvent) -> [IslandEffect] {
        switch e {
        case let .musicChanged(playing, hasSession):
            s.isPlaying = playing
            s.hasSession = hasSession
            if !hasSession {
                switch s.surface {
                case .expanded:
                    s.surface = .collapsed
                    s.volumeShown = false
                    s.volumeOverlay = false
                    return [.cancelCloseDebounce]
                case .peek:
                    s.surface = .collapsed
                    return [.cancelDwellTimer]
                case .trackIntro:
                    s.surface = .collapsed
                    return []
                default:
                    return []
                }
            }
            return []

        case .hoverBegan:
            switch s.surface {
            case .collapsed, .trackIntro:
                s.surface = .peek
                return s.hasSession ? [.haptic, .startDwellTimer] : [.haptic]
            case .expanded:
                return [.cancelCloseDebounce]
            default:
                return []
            }

        case .hoverEnded:
            switch s.surface {
            case .peek:
                s.surface = .collapsed
                return [.cancelDwellTimer]
            case .expanded:
                return [.startCloseDebounce]
            default:
                return []
            }

        case .dwellFired:
            guard s.surface == .peek, s.hasSession else { return [] }
            s.surface = .expanded
            return [.haptic]

        case .tapped:
            switch s.surface {
            case .collapsed, .peek, .trackIntro:
                guard s.hasSession else { return [] }
                s.surface = .expanded
                return [.haptic, .cancelDwellTimer]
            default:
                return []
            }

        case .closeDebounceFired, .clickedOutside:
            guard s.surface == .expanded else { return [] }
            s.volumeShown = false
            s.volumeOverlay = false
            if let flash = s.pendingBattery {
                s.pendingBattery = nil
                s.surface = .battery(flash)
                return [.scheduleBatteryEnd]
            }
            s.surface = .collapsed
            return []

        case let .battery(flash):
            switch s.surface {
            case .expanded:
                s.pendingBattery = flash
                return []
            case .peek:
                s.surface = .battery(flash)
                return [.cancelDwellTimer, .scheduleBatteryEnd]
            case .collapsed, .battery, .volume, .trackIntro:
                s.surface = .battery(flash)
                return [.scheduleBatteryEnd]
            }

        case .batteryFlashEnded:
            guard case .battery = s.surface else { return [] }
            s.surface = .collapsed
            return []

        case .volumeToggled:
            guard s.surface == .expanded else { return [] }
            s.volumeShown.toggle()
            return [.haptic]

        case let .volumeGesture(percent):
            switch s.surface {
            case .expanded:
                // Живой оверлей громкости на время жеста + страховочный таймер.
                s.volumeOverlay = true
                return [.scheduleVolumeFlashEnd]
            case .peek:
                s.surface = .volume(percent)
                return [.cancelDwellTimer, .scheduleVolumeFlashEnd]
            case .collapsed, .battery, .volume, .trackIntro:
                s.surface = .volume(percent)
                return [.scheduleVolumeFlashEnd]
            }

        case .volumeFlashEnded:
            if s.volumeOverlay { s.volumeOverlay = false }
            guard case .volume = s.surface else { return [] }
            s.surface = .collapsed
            return []

        case .volumeGestureEnded:
            s.volumeOverlay = false
            return []

        case .trackChanged:
            switch s.surface {
            case .expanded, .battery:
                return []
            case .peek:
                s.surface = .trackIntro
                return [.cancelDwellTimer, .scheduleTrackIntroEnd]
            case .collapsed, .volume, .trackIntro:
                s.surface = .trackIntro
                return [.scheduleTrackIntroEnd]
            }

        case .trackIntroEnded:
            guard case .trackIntro = s.surface else { return [] }
            s.surface = .collapsed
            return []
        }
    }
}
