import AppKit
import CoreAudio
import Observation

/// Системная громкость default output устройства.
/// Селектор 'vmvc' (kAudioHardwareServiceDeviceProperty_VirtualMainVolume):
/// работает и для устройств без физического master-канала.
@MainActor
@Observable
final class VolumeController {
    private(set) var volume: Float = 0
    /// SF Symbol текущего устройства вывода (AirPods и т.п.) для правой
    /// иконки слайдера.
    private(set) var outputIcon = "speaker.wave.3.fill"

    @ObservationIgnored private var deviceID = AudioObjectID(kAudioObjectUnknown)
    @ObservationIgnored private var volumeAddress = AudioObjectPropertyAddress(
        mSelector: AudioObjectPropertySelector(0x766D_7663), // 'vmvc'
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)
    @ObservationIgnored private var defaultDeviceAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)

    func start() {
        attachToDefaultDevice()
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddress,
            .main
        ) { _, _ in
            MainActor.assumeIsolated { self.attachToDefaultDevice() }
        }
    }

    func setVolume(_ value: Float) {
        guard deviceID != kAudioObjectUnknown else { return }
        var v = min(max(value, 0), 1)
        AudioObjectSetPropertyData(
            deviceID, &volumeAddress, 0, nil,
            UInt32(MemoryLayout<Float32>.size), &v)
        volume = v
    }

    private func attachToDefaultDevice() {
        var id = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddress, 0, nil, &size, &id)
        guard status == noErr, id != kAudioObjectUnknown else { return }
        deviceID = id
        readVolume()
        updateOutputIcon()
        AudioObjectAddPropertyListenerBlock(deviceID, &volumeAddress, .main) { _, _ in
            MainActor.assumeIsolated { self.readVolume() }
        }
    }

    private func readVolume() {
        guard deviceID != kAudioObjectUnknown else { return }
        var v: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        if AudioObjectGetPropertyData(deviceID, &volumeAddress, 0, nil, &size, &v) == noErr {
            volume = v
        }
    }

    private func updateOutputIcon() {
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var name: CFString = "" as CFString
        var nameSize = UInt32(MemoryLayout<CFString>.size)
        _ = withUnsafeMutablePointer(to: &name) { ptr in
            AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, ptr)
        }

        var transportAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var transport: UInt32 = 0
        var transportSize = UInt32(MemoryLayout<UInt32>.size)
        _ = AudioObjectGetPropertyData(
            deviceID, &transportAddress, 0, nil, &transportSize, &transport)

        let candidate = OutputDeviceIcon.symbol(
            deviceName: name as String, transportType: transport)
        // Защита от отсутствующего символа на конкретной версии macOS.
        outputIcon = NSImage(systemSymbolName: candidate, accessibilityDescription: nil) != nil
            ? candidate
            : "speaker.wave.3.fill"
    }
}
