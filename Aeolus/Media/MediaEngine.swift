import Foundation
import os

actor MediaEngine {
    private static let log = Logger(subsystem: "io.github.moverq1337.aeolus", category: "media")
    private let paths: AdapterPaths
    private let store: NowPlayingStore
    private var process: Process?
    private var lineBuffer = LineBuffer()
    private var current: NowPlayingState?
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
            await setAvailable(false)
            return
        }
        await setAvailable(true)
        spawnStream()
    }

    func stop() {
        stopped = true
        process?.terminate()
        process = nil
        current = nil
        lineBuffer = LineBuffer()
        Task { await pushState(nil) }
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
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        proc.arguments = [paths.script, paths.framework, "stream", "--debounce=100"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task { await self.ingest(data) }
        }
        proc.terminationHandler = { _ in
            Task { await self.streamEnded() }
        }
        do {
            try proc.run()
            process = proc
            Self.log.info("adapter stream started (pid \(proc.processIdentifier))")
        } catch {
            Self.log.error("adapter spawn failed: \(error.localizedDescription)")
            Task { await self.streamEnded() }
        }
    }

    private func ingest(_ chunk: Data) async {
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
                let blocked = await MainActor.run {
                    MediaSourceFilter.isBlocked(
                        merged?.bundleIdentifier,
                        artist: merged?.artist,
                        extra: Preferences.ignoredBundleIDs)
                }
                await pushState(blocked ? nil : merged)
            }
        }
    }

    private func streamEnded() async {
        guard !stopped else { return }
        process = nil
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
