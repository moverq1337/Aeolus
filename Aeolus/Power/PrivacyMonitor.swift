import Foundation
import CoreMediaIO
import CoreAudio
import Observation

/// Точки приватности: камера (зелёная) и микрофон (оранжевая) — read-only
/// наблюдение «устройство сейчас используется», без TCC-запросов и поллинга.
@MainActor
@Observable
final class PrivacyMonitor {
    private(set) var cameraActive = false
    private(set) var micActive = false

    @ObservationIgnored private var listeners: [(AudioObjectID, AudioObjectPropertyAddress)] = []

    func start() {
        refresh()
        // Микрофон: default input device running-somewhere
        var inputAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &inputAddr, .main
        ) { _, _ in
            MainActor.assumeIsolated { self.refresh(); self.listenMic() }
        }
        listenMic()
        listenCameras()
    }

    private func listenMic() {
        guard let device = Self.defaultInputDevice() else { return }
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        AudioObjectAddPropertyListenerBlock(device, &addr, .main) { _, _ in
            MainActor.assumeIsolated { self.refresh() }
        }
    }

    private func listenCameras() {
        for camera in Self.cameraDevices() {
            var addr = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
            CMIOObjectAddPropertyListenerBlock(camera, &addr, .main) { _, _ in
                MainActor.assumeIsolated { self.refresh() }
            }
        }
    }

    private func refresh() {
        micActive = Self.isMicRunning()
        cameraActive = Self.isAnyCameraRunning()
    }

    // MARK: - чтения

    private static func defaultInputDevice() -> AudioObjectID? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &device) == noErr,
            device != kAudioObjectUnknown else { return nil }
        return device
    }

    private static func isMicRunning() -> Bool {
        guard let device = defaultInputDevice() else { return false }
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &running) == noErr
        else { return false }
        return running != 0
    }

    private static func cameraDevices() -> [CMIOObjectID] {
        var addr = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(
            CMIOObjectID(kCMIOObjectSystemObject), &addr, 0, nil, &size) == noErr,
            size > 0 else { return [] }
        let count = Int(size) / MemoryLayout<CMIOObjectID>.size
        var devices = [CMIOObjectID](repeating: 0, count: count)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(
            CMIOObjectID(kCMIOObjectSystemObject), &addr, 0, nil, size, &used, &devices) == noErr
        else { return [] }
        return devices
    }

    private static func isAnyCameraRunning() -> Bool {
        for camera in cameraDevices() {
            var addr = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
            var running: UInt32 = 0
            var size = UInt32(MemoryLayout<UInt32>.size)
            if CMIOObjectGetPropertyData(camera, &addr, 0, nil, size, &size, &running) == noErr,
               running != 0 {
                return true
            }
        }
        return false
    }
}
