import AppKit

// Приватные CGS-символы WindowServer. Единственный способ (проверенный
// boring.notch и NotchDrop) сделать так, чтобы остров НЕ уезжал и не мерцал
// при свайпе между Spaces: собственное CGS-пространство, которое показано всегда.
// Доступность символов проверяется через dlsym до первого вызова —
// при отсутствии тихо откатываемся к обычному поведению панели.
@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> Int32

@_silgen_name("CGSSpaceCreate")
private func CGSSpaceCreate(_ cid: Int32, _ unknown: Int, _ options: NSDictionary?) -> Int

@_silgen_name("CGSSpaceSetAbsoluteLevel")
private func CGSSpaceSetAbsoluteLevel(_ cid: Int32, _ space: Int, _ level: Int32)

@_silgen_name("CGSShowSpaces")
private func CGSShowSpaces(_ cid: Int32, _ spaces: NSArray)

@_silgen_name("CGSAddWindowsToSpaces")
private func CGSAddWindowsToSpaces(_ cid: Int32, _ windows: NSArray, _ spaces: NSArray)

@MainActor
final class NotchSpace {
    static let shared = NotchSpace()

    private let available: Bool
    private var connection: Int32 = 0
    private var spaceID: Int = 0

    private init() {
        let handle = dlopen(nil, RTLD_LAZY)
        available = dlsym(handle, "CGSSpaceCreate") != nil
            && dlsym(handle, "CGSMainConnectionID") != nil
            && dlsym(handle, "CGSSpaceSetAbsoluteLevel") != nil
            && dlsym(handle, "CGSShowSpaces") != nil
            && dlsym(handle, "CGSAddWindowsToSpaces") != nil
        guard available else { return }
        connection = CGSMainConnectionID()
        // Флаг 0x1 обязателен — иначе Finder перерисовывает иконки рабочего стола.
        spaceID = CGSSpaceCreate(connection, 0x1, nil)
        CGSSpaceSetAbsoluteLevel(connection, spaceID, Int32.max)
        CGSShowSpaces(connection, [spaceID] as NSArray)
    }

    func attach(_ window: NSWindow) {
        guard available, spaceID != 0 else { return }
        CGSAddWindowsToSpaces(
            connection, [window.windowNumber] as NSArray, [spaceID] as NSArray)
    }
}
