import Carbon.HIToolbox
import AppKit

/// Пробел = play/pause, но ТОЛЬКО пока остров раскрыт: хоткей регистрируется
/// на раскрытии и снимается на сворачивании (Carbon RegisterEventHotKey —
/// без разрешений Accessibility). В остальное время пробел никому не мешает.
@MainActor
final class SpaceToggleHotKey {
    var onPressed: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    func register() {
        guard hotKeyRef == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let hotKey = Unmanaged<SpaceToggleHotKey>
                    .fromOpaque(userData).takeUnretainedValue()
                MainActor.assumeIsolated { hotKey.onPressed?() }
                return noErr
            },
            1, &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef)
        let hotKeyID = EventHotKeyID(signature: OSType(0x41454F4C) /* 'AEOL' */, id: 1)
        RegisterEventHotKey(
            UInt32(kVK_Space), 0, hotKeyID,
            GetEventDispatcherTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
    }
}
