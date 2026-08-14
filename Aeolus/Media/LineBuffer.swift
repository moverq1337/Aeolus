import Foundation

/// Копит байты из пайпа и отдаёт завершённые строки (без \n).
struct LineBuffer {
    private var pending = Data()

    mutating func lines(appending chunk: Data) -> [Data] {
        pending.append(chunk)
        var out: [Data] = []
        while let nl = pending.firstIndex(of: 0x0A) {
            out.append(pending.subdata(in: pending.startIndex..<nl))
            pending.removeSubrange(pending.startIndex...nl)
        }
        return out
    }
}
