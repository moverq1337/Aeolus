struct DeviceFlash: Equatable, Sendable {
    var icon: String
    var name: String
    var percentage: Int?
}

struct BatteryFlash: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case pluggedIn, unplugged, low, critical
    }
    var kind: Kind
    var percentage: Int
    /// Мощность адаптера при подключении (Вт), если известна.
    var watts: Int? = nil
    /// Оценка времени (мин): до полной при зарядке, до разрядки при отключении.
    var minutes: Int? = nil
}

struct IslandState: Equatable {
    enum Surface: Equatable {
        case collapsed
        case peek
        case expanded
        case battery(BatteryFlash)
        case volume(Int)
        case trackIntro
        case device(DeviceFlash)
    }
    var surface: Surface = .collapsed
    var hasSession = false
    var isPlaying = false
    var pendingBattery: BatteryFlash?
    /// Слайдер громкости раскрыт отдельной кнопкой внутри Expanded (решение 2026-08-14).
    var volumeShown = false
    /// Временная шкала громкости в Expanded, пока идёт двухпальцевый жест.
    var volumeOverlay = false
    /// Экран заблокирован: остров сжат в голый вырез до приветствия.
    var suppressed = false
    /// Овершут громкости за пределы 0/100 (−1…1) — rubber-band на шкале.
    var volumeOvershoot: Double = 0
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
    case volumeOvershoot(Double)
    case volumeFlashEnded
    case volumeGestureEnded
    case trackChanged
    case trackIntroEnded
    case screenLocked
    case screenUnlocked
    case deviceConnected(DeviceFlash)
    case deviceFlashEnded
}

enum IslandEffect: Equatable {
    case startDwellTimer
    case cancelDwellTimer
    case startCloseDebounce
    case cancelCloseDebounce
    case scheduleBatteryEnd
    case scheduleVolumeFlashEnd
    case scheduleTrackIntroEnd
    case scheduleDeviceFlashEnd
    case haptic
}
