import AppKit
import SwiftUI

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Первый клик по острову должен срабатывать сразу, даже когда окно не key.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    /// Проброс двухпальцевых свайпов (scroll-события) — ставится только для
    /// окна острова; nil (дефолт) отдаёт событие дальше по цепочке.
    var onScroll: ((NSEvent) -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func scrollWheel(with event: NSEvent) {
        if let onScroll {
            onScroll(event)
        } else {
            super.scrollWheel(with: event)
        }
    }
}
