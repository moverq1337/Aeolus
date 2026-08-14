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
            if !old.isPluggedIn, new.isPluggedIn {
                out.append(.pluggedIn(percentage: new.percentage))
            }
            if old.isPluggedIn, !new.isPluggedIn {
                out.append(.unplugged(percentage: new.percentage))
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
