import Foundation

struct RestartPolicy: Equatable {
    enum Action: Equatable {
        case restart(after: TimeInterval)
        case giveUp
    }

    var maxConsecutiveFailures = 5
    private(set) var consecutiveFailures = 0

    mutating func recordFailure() -> Action {
        consecutiveFailures += 1
        if consecutiveFailures >= maxConsecutiveFailures { return .giveUp }
        return .restart(after: min(pow(2, Double(consecutiveFailures - 1)), 30))
    }

    mutating func recordSuccess() {
        consecutiveFailures = 0
    }
}
