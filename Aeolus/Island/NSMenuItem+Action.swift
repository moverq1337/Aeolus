import AppKit

/// NSMenuItem с замыканием вместо target/action-пары.
private final class MenuItemActionBox: NSObject {
    let handler: () -> Void
    init(_ handler: @escaping () -> Void) { self.handler = handler }
    @objc func invoke() { handler() }
}

extension NSMenuItem {
    private nonisolated(unsafe) static var boxKey: UInt8 = 0

    func setAction(_ handler: @escaping () -> Void) {
        let box = MenuItemActionBox(handler)
        objc_setAssociatedObject(
            self, &Self.boxKey, box, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        target = box
        action = #selector(MenuItemActionBox.invoke)
    }
}
