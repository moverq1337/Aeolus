import AppKit

/// Пространство SkyLight уровня 400 (NotificationCenterAtScreenLock) — единственный
/// проверенный способ показать окно поверх экрана блокировки (спека §3.2).
/// Все символы через dlsym: отсутствие любого → shared == nil → фичи просто нет.
@MainActor
final class SkyLightSpace {
    static let shared: SkyLightSpace? = SkyLightSpace()

    /// Уровень 400 — единственное полевое значение; >700 клампится и не рисуется.
    private static let lockScreenLevel: Int32 = 400
    /// Магический последний аргумент AddWindowsAndRemoveFromSpaces (cargo-culted
    /// из SkyLightWindow/mew-notch): снимает окно со всех прочих пространств.
    private static let addFlag: Int32 = 7

    private typealias MainConnFn = @convention(c) () -> Int32
    private typealias SpaceCreateFn = @convention(c) (Int32, Int32, Int32) -> Int32
    private typealias SetLevelFn = @convention(c) (Int32, Int32, Int32) -> Int32
    private typealias ShowSpacesFn = @convention(c) (Int32, CFArray) -> Int32
    private typealias AddWindowsFn = @convention(c) (Int32, Int32, CFArray, Int32) -> Int32

    private let mainConnection: MainConnFn
    private let spaceCreate: SpaceCreateFn
    private let setLevel: SetLevelFn
    private let showSpaces: ShowSpacesFn
    private let addWindows: AddWindowsFn

    private var cid: Int32 = 0
    private var space: Int32 = 0
    private var created = false

    private init?() {
        let f = PrivateSymbols.skyLight
        guard
            let a = PrivateSymbols.load("SLSMainConnectionID", from: f, as: MainConnFn.self),
            let b = PrivateSymbols.load("SLSSpaceCreate", from: f, as: SpaceCreateFn.self),
            let c = PrivateSymbols.load("SLSSpaceSetAbsoluteLevel", from: f, as: SetLevelFn.self),
            let d = PrivateSymbols.load("SLSShowSpaces", from: f, as: ShowSpacesFn.self),
            let e = PrivateSymbols.load(
                "SLSSpaceAddWindowsAndRemoveFromSpaces", from: f, as: AddWindowsFn.self)
        else { return nil }
        mainConnection = a
        spaceCreate = b
        setLevel = c
        showSpaces = d
        addWindows = e
    }

    /// Делегирует окно в 400-пространство. Пространство создаётся лениво при первом
    /// вызове (никогда в тестах/CI). Идемпотентно по созданию пространства.
    func delegate(_ window: NSWindow) {
        if !created {
            cid = mainConnection()
            space = spaceCreate(cid, 1, 0)
            _ = setLevel(cid, space, Self.lockScreenLevel)
            _ = showSpaces(cid, [space] as CFArray)
            created = true
        }
        _ = addWindows(cid, space, [window.windowNumber] as CFArray, Self.addFlag)
    }
}
