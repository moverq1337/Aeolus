import Foundation
import os

actor MediaEngine {
    private static let log = Logger(subsystem: "io.github.moverq1337.aeolus", category: "media")
    private let paths: AdapterPaths
    private let store: NowPlayingStore
    private var process: Process?
    private var streamPipe: Pipe?
    /// Поколение потока. Колбэки убитого perl-процесса доезжают и после
    /// `terminate()` — с состоянием, снятым ДО сна. Без метки поколения такой
    /// хвост публикуется поверх свежего трека, и остров залипает на прошлой
    /// песне («проснулся — играет новое, показано старое»).
    private var generation = 0
    /// Счётчик событий питания. Сон и пробуждение приезжают разными задачами,
    /// а между ними процесс замораживают — поэтому «уснули» умеет доехать до
    /// актора уже ПОСЛЕ «проснулись» и убить только что поднятый поток.
    /// Порядку задач не верим, считаем события.
    private var powerEpoch = 0
    private var lineBuffer = LineBuffer()
    /// Истина стрима: последнее смёрженное состояние.
    private var current: NowPlayingState?
    /// Что из этой истины показывать острову — см. NowPlayingCoalescer.
    private var coalescer = NowPlayingCoalescer()
    private var holdTask: Task<Void, Never>?
    private var policy = RestartPolicy()
    private var stopped = true
    private var hadFirstPayload = false

    init(paths: AdapterPaths, store: NowPlayingStore) {
        self.paths = paths
        self.store = store
    }

    // MARK: lifecycle

    func start() async {
        guard stopped else { return }
        stopped = false
        policy.recordSuccess()
        let ok = await runTest(timeout: 10)
        guard !stopped else { return }
        guard ok else {
            Self.log.warning("adapter test failed — media unavailable")
            // stopped = true по той же причине, что и в giveUp: иначе будущий
            // start() (пробуждение) упрётся в guard и движок останется мёртвым
            // до перезапуска приложения.
            stopped = true
            await setAvailable(false)
            return
        }
        await setAvailable(true)
        spawnStream()
    }

    func stop() async {
        stopped = true
        teardownStream()
        current = nil
        coalescer.reset()
        cancelHold()
        await pushState(nil)
    }

    // MARK: сон и пробуждение

    /// `epoch` минтится на MainActor в момент события — см. `powerEpoch`.
    func suspend(epoch: Int) async {
        guard epoch > powerEpoch else { return } // событие устарело
        powerEpoch = epoch
        await stop()
    }

    /// Пробуждение перезапускает поток безусловно: во-первых, «уснули» могло не
    /// успеть выполниться до заморозки процесса (тогда `stopped == false` и
    /// обычный `start()` молча вернулся бы), во-вторых, MediaRemote после сна
    /// не всегда досылает состояние в поток, переживший сон формально живым.
    func resume(epoch: Int) async {
        guard epoch > powerEpoch else { return }
        powerEpoch = epoch
        await stop()
        await start()
    }

    /// Снимает поток целиком: без снятого readabilityHandler хвост из трубы
    /// убитого процесса продолжает капать в актор (и держит `self`).
    private func teardownStream() {
        generation &+= 1
        streamPipe?.fileHandleForReading.readabilityHandler = nil
        streamPipe = nil
        process?.terminate()
        process = nil
        lineBuffer = LineBuffer()
    }

    // MARK: commands

    func send(_ command: MediaCommand) {
        runOneShot(["send", String(command.rawValue)])
    }

    func seek(to seconds: Double) {
        runOneShot(["seek", String(Int(seconds * 1_000_000))])
    }

    // MARK: internals

    private func spawnStream() {
        guard !stopped else { return }
        hadFirstPayload = false
        generation &+= 1
        let generation = generation
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        proc.arguments = [paths.script, paths.framework, "stream", "--debounce=100"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task { await self.ingest(data, generation: generation) }
        }
        proc.terminationHandler = { _ in
            Task { await self.streamEnded(generation: generation) }
        }
        do {
            try proc.run()
            process = proc
            streamPipe = pipe
            Self.log.info("adapter stream started (pid \(proc.processIdentifier))")
        } catch {
            Self.log.error("adapter spawn failed: \(error.localizedDescription)")
            Task { await self.streamEnded(generation: generation) }
        }
    }

    private func ingest(_ chunk: Data, generation: Int) async {
        guard generation == self.generation else { return } // хвост убитого потока
        for line in lineBuffer.lines(appending: chunk) {
            guard let envelope = try? JSONDecoder().decode(AdapterEnvelope.self, from: line)
            else { continue }
            let merged = NowPlayingMerge.apply(envelope, to: current, now: Date())
            if merged != nil, !hadFirstPayload {
                hadFirstPayload = true
                policy.recordSuccess()
            }
            if merged != current {
                current = merged
                await settle(merged)
            }
        }
    }

    // MARK: схождение рваных обновлений

    /// Пропускает состояние через NowPlayingCoalescer: либо публикует сразу,
    /// либо придерживает до дедлайна, давая источнику дослать остальные поля.
    private func settle(_ state: NowPlayingState?) async {
        switch coalescer.feed(state, now: Date()) {
        case .publish(let final):
            holdTask?.cancel()
            holdTask = nil
            await commit(final)
        case .hold(let deadline):
            holdTask?.cancel()
            holdTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow)))
                guard !Task.isCancelled else { return }
                await self?.holdExpired()
            }
        case .holding:
            break // дедлайн уже тикает
        case .verify:
            break // из feed не возвращается — только из deadlineReached
        }
    }

    /// Источник не дослал остальное — публикуем лучшее из имеющегося.
    private func holdExpired() async {
        guard coalescer.isHolding else { return }
        holdTask = nil
        let outcome = coalescer.deadlineReached()
        if case .verify = outcome {
            // Мост истёк на играющем треке — спрашиваем факт вместо догадки.
            let answer = await queryNowPlaying()
            let confirmed = answer.ok ? answer.state : coalescer.published
            if case .publish(let state) = coalescer.confirm(confirmed) {
                Self.log.warning(
                    "session bridge expired, source says \(state?.title ?? "nothing", privacy: .public)")
                await commit(state)
            }
            return
        }
        guard case .publish(let state) = outcome else { return }
        // Единственный полевой сигнал схождения: источник не уложился в окно.
        // Название в сообщении различает случаи — пусто значит истёк мост
        // через провал сессии, непусто — окно рваной идентичности.
        Self.log.warning(
            "coalescer window expired, publishing \(state?.title ?? "nothing", privacy: .public)")
        await commit(state)
    }

    private func cancelHold() {
        holdTask?.cancel()
        holdTask = nil
    }

    private func commit(_ state: NowPlayingState?) async {
        // Фильтр — чистая функция, Preferences читает UserDefaults (потокобезопасно).
        // Прыжок на MainActor здесь заставлял КАЖДЫЙ payload ждать главный поток:
        // пока тот занят (например, пересборкой окна на смене разрешения), актор
        // движка стоял, следующий payload не разбирался — а окно схождения тикало
        // и истекало на ровном месте, показывая рваное состояние.
        let blocked = MediaSourceFilter.isBlocked(
            state?.bundleIdentifier,
            artist: state?.artist,
            extra: Preferences.ignoredBundleIDs)
        await pushState(blocked ? nil : state)
    }

    private func streamEnded(generation: Int) async {
        guard !stopped, generation == self.generation else { return }
        process = nil
        streamPipe?.fileHandleForReading.readabilityHandler = nil
        streamPipe = nil
        switch policy.recordFailure() {
        case .restart(let delay):
            Self.log.warning("adapter stream died; restart in \(delay)s")
            try? await Task.sleep(for: .seconds(delay))
            guard !stopped else { return }
            spawnStream()
        case .giveUp:
            Self.log.error("adapter failed 5x — giving up, media unavailable")
            // stopped = true, иначе будущий start() (пробуждение) упрётся в guard
            // и движок останется мёртвым до перезапуска приложения.
            stopped = true
            coalescer.reset()
            cancelHold()
            await setAvailable(false)
            await pushState(nil)
        }
    }

    private func runTest(timeout: TimeInterval) async -> Bool {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        proc.arguments = [paths.script, paths.framework, "test"]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        do { try proc.run() } catch { return false }
        let deadline = ContinuousClock.now.advanced(by: .seconds(timeout))
        while proc.isRunning, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
        if proc.isRunning {
            proc.terminate()
            return false
        }
        return proc.terminationStatus == 0
    }

    /// Разовый снимок состояния источника (`get`, замер ~25 мс). Запускается
    /// только по событию — истёкшему мосту, — поэтому инвариант «ноль опросов
    /// в простое» (спека §6.7) цел. `ok == false` означает, что спросить не
    /// удалось: тогда лучше оставить остров как есть, чем гасить его догадкой.
    private func queryNowPlaying() async -> (ok: Bool, state: NowPlayingState?) {
        let paths = paths
        let output = await Task.detached(priority: .userInitiated) { () -> Data? in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
            proc.arguments = [paths.script, paths.framework, "get"]
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = FileHandle.nullDevice
            do { try proc.run() } catch { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            return proc.terminationStatus == 0 ? data : nil
        }.value
        guard let output else { return (false, nil) }
        // `get` печатает голый payload, без конверта потока.
        guard let payload = try? JSONDecoder().decode(NowPlayingPayload.self, from: output)
        else { return (true, nil) } // пустой ответ = сессии нет, это тоже факт
        return (true, NowPlayingMerge.apply(
            AdapterEnvelope(type: "data", diff: false, payload: payload),
            to: nil, now: Date()))
    }

    private func runOneShot(_ args: [String]) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        proc.arguments = [paths.script, paths.framework] + args
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
    }

    private func pushState(_ state: NowPlayingState?) async {
        await MainActor.run { self.store.apply(state) }
    }

    private func setAvailable(_ value: Bool) async {
        await MainActor.run { self.store.mediaAvailable = value }
    }
}
