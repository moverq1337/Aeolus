import AppKit
import Observation

@MainActor
@Observable
final class IslandViewModel {
    private(set) var state = IslandState()

    @ObservationIgnored private var dwellTask: Task<Void, Never>?
    @ObservationIgnored private var closeTask: Task<Void, Never>?
    @ObservationIgnored private var batteryTask: Task<Void, Never>?
    @ObservationIgnored private var volumeFlashTask: Task<Void, Never>?
    @ObservationIgnored private var trackIntroTask: Task<Void, Never>?
    @ObservationIgnored private var unlockFlashTask: Task<Void, Never>?

    func handle(_ event: IslandEvent) {
        for effect in IslandReducer.reduce(&state, event) {
            run(effect)
        }
    }

    private func run(_ effect: IslandEffect) {
        switch effect {
        case .startDwellTimer:
            // Настройка «Expand on hover» выключена — раскрытие только по клику.
            guard Preferences.expandOnHover else { return }
            dwellTask?.cancel()
            dwellTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(Preferences.hoverDelay))
                guard !Task.isCancelled else { return }
                self?.handle(.dwellFired)
            }
        case .cancelDwellTimer:
            dwellTask?.cancel()
        case .startCloseDebounce:
            closeTask?.cancel()
            closeTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                self?.handle(.closeDebounceFired)
            }
        case .cancelCloseDebounce:
            closeTask?.cancel()
        case .scheduleBatteryEnd:
            batteryTask?.cancel()
            batteryTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(2.5))
                guard !Task.isCancelled else { return }
                self?.handle(.batteryFlashEnded)
            }
        case .scheduleVolumeFlashEnd:
            // Продление таймера продолжающимся жестом — желаемое поведение.
            volumeFlashTask?.cancel()
            volumeFlashTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(1.0))
                guard !Task.isCancelled else { return }
                self?.handle(.volumeFlashEnded)
            }
        case .scheduleTrackIntroEnd:
            trackIntroTask?.cancel()
            trackIntroTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(2.5))
                guard !Task.isCancelled else { return }
                self?.handle(.trackIntroEnded)
            }
        case .scheduleUnlockFlashEnd:
            unlockFlashTask?.cancel()
            unlockFlashTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                self?.handle(.unlockFlashEnded)
            }
        case .haptic:
            NSHapticFeedbackManager.defaultPerformer
                .perform(.alignment, performanceTime: .default)
        }
    }
}
