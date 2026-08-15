import AppKit

/// Панель локскрин-виджета: не забирает фокус клавиатуры (нельзя украсть у поля
/// пароля), но принимает клики мышью (кнопки виджета).
final class LockWidgetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
