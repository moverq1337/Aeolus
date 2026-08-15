import Foundation

/// Индикатор режима фокусирования: следим за ~/Library/DoNotDisturb/DB/Assertions.json
/// через DispatchSource (событийно, ноль поллинга). Меняется файл — читаем, активен
/// ли фокус, и дёргаем колбэк.
@MainActor
final class FocusMonitor {
    var onChange: ((Bool) -> Void)?

    private var source: DispatchSourceFileSystemObject?
    private var descriptor: CInt = -1
    private var lastActive: Bool?

    private var path: String {
        NSHomeDirectory() + "/Library/DoNotDisturb/DB/Assertions.json"
    }

    func start() {
        check() // базовая линия без события
        watch()
    }

    private func watch() {
        stopWatching()
        descriptor = open(path, O_EVTONLY)
        guard descriptor >= 0 else { return } // файла нет — фичи нет
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename],
            queue: .main)
        src.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                self?.check()
                // rename/delete при перезаписи — перевешиваем вотчер
                self?.watch()
            }
        }
        src.setCancelHandler { [descriptor] in close(descriptor) }
        src.resume()
        source = src
    }

    private func stopWatching() {
        source?.cancel()
        source = nil
    }

    private func check() {
        let active = Self.isFocusActive(path: path)
        guard active != lastActive else { return }
        let hadBaseline = lastActive != nil
        lastActive = active
        if hadBaseline { onChange?(active) }
    }

    static func isFocusActive(path: String) -> Bool {
        guard let data = FileManager.default.contents(atPath: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let records = json["data"] as? [[String: Any]] else { return false }
        for record in records {
            if let assertions = record["storeAssertionRecords"] as? [[String: Any]],
               !assertions.isEmpty {
                return true
            }
        }
        return false
    }
}
