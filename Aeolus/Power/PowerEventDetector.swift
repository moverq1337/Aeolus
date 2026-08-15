enum PowerEvent: Equatable {
    case pluggedIn(percentage: Int)
    case unplugged(percentage: Int)
    case lowBattery(percentage: Int, critical: Bool)
}

/// Превращает дребезжащие IOKit-снапшоты в дискретные события.
/// Латч порогов: одно предупреждение на пересечение вниз (спека §4.1).
struct PowerEventDetector {
    static let thresholds = [20, 10]
    private var latched: Set<Int> = []

    mutating func events(from old: PowerSnapshot?, to new: PowerSnapshot) -> [PowerEvent] {
        var out: [PowerEvent] = []

        if let old {
            // Процент берём из СТАБИЛЬНОГО до-событийного снапшота: в момент
            // подключения powerd отдаёт переходный мусор (наблюдали 2% и 8%
            // при реальных 48-52%).
            if !old.isPluggedIn, new.isPluggedIn {
                out.append(.pluggedIn(percentage: old.percentage))
            }
            if old.isPluggedIn, !new.isPluggedIn {
                out.append(.unplugged(percentage: old.percentage))
            }
        }

        if new.isPluggedIn {
            latched.removeAll()
        } else {
            var crossed: [Int] = []
            for t in Self.thresholds where new.percentage <= t && !latched.contains(t) {
                let fromAbove = old.map { $0.percentage > t || $0.isPluggedIn } ?? true
                if fromAbove {
                    latched.insert(t)
                    crossed.append(t)
                }
            }
            if let worst = crossed.min() {
                out.append(.lowBattery(percentage: new.percentage, critical: worst <= 10))
            }
            latched = latched.filter { new.percentage <= $0 }
        }
        return out
    }
}
