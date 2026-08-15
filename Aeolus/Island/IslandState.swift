struct BatteryFlash: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case pluggedIn, unplugged, low, critical
    }
    var kind: Kind
    var percentage: Int
}

struct IslandState: Equatable {
    enum Surface: Equatable {
        case collapsed
        case peek
        case expanded
        case battery(BatteryFlash)
        case volume(Int)
    }
    var surface: Surface = .collapsed
    var hasSession = false
    var isPlaying = false
    var pendingBattery: BatteryFlash?
    /// Слайдер громкости раскрыт отдельной кнопкой внутри Expanded (решение 2026-08-14).
    var volumeShown = false
}

enum IslandEvent: Equatable {
    case musicChanged(playing: Bool, hasSession: Bool)
    case hoverBegan
    case hoverEnded
    case dwellFired
    case closeDebounceFired
    case tapped
    case clickedOutside
    case battery(BatteryFlash)
    case batteryFlashEnded
    case volumeToggled
    case volumeGesture(Int)
    case volumeFlashEnded
}

enum IslandEffect: Equatable {
    case startDwellTimer
    case cancelDwellTimer
    case startCloseDebounce
    case cancelCloseDebounce
    case scheduleBatteryEnd
    case scheduleVolumeFlashEnd
    case haptic
}
