import AppKit

// Стабильность острова при свайпе между Spaces: собственное CGS-пространство,
// показанное всегда (как boring.notch/NotchDrop). Символы резолвятся через dlsym
// (PrivateSymbols) — исчезновение любого в будущей macOS деградирует фичу, а не
// убивает приложение на старте (чего не давал прежний @_silgen_name).
@MainActor
final class NotchSpace {
    static let shared = NotchSpace()

    private typealias MainConnFn = @convention(c) () -> Int32
    private typealias SpaceCreateFn = @convention(c) (Int32, Int, NSDictionary?) -> Int
    private typealias SetLevelFn = @convention(c) (Int32, Int, Int32) -> Void
    private typealias ShowSpacesFn = @convention(c) (Int32, NSArray) -> Void
    private typealias AddWindowsFn = @convention(c) (Int32, NSArray, NSArray) -> Void

    private let available: Bool
    private var connection: Int32 = 0
    private var spaceID: Int = 0
    private let addWindowsFn: AddWindowsFn?

    private init() {
        let conn = PrivateSymbols.load("CGSMainConnectionID", from: nil, as: MainConnFn.self)
        let create = PrivateSymbols.load("CGSSpaceCreate", from: nil, as: SpaceCreateFn.self)
        let setLevel = PrivateSymbols.load(
            "CGSSpaceSetAbsoluteLevel", from: nil, as: SetLevelFn.self)
        let show = PrivateSymbols.load("CGSShowSpaces", from: nil, as: ShowSpacesFn.self)
        let add = PrivateSymbols.load("CGSAddWindowsToSpaces", from: nil, as: AddWindowsFn.self)

        guard let conn, let create, let setLevel, let show, let add else {
            available = false
            addWindowsFn = nil
            return
        }
        available = true
        addWindowsFn = add
        connection = conn()
        // Флаг 0x1 обязателен — иначе Finder перерисовывает иконки рабочего стола.
        spaceID = create(connection, 0x1, nil)
        setLevel(connection, spaceID, Int32.max)
        show(connection, [spaceID] as NSArray)
    }

    func attach(_ window: NSWindow) {
        guard available, spaceID != 0, let addWindowsFn else { return }
        addWindowsFn(connection, [window.windowNumber] as NSArray, [spaceID] as NSArray)
    }
}
