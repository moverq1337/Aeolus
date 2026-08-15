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
    /// Внешнее изменение громкости (клавиши, Control Center) — для транзиента.
    @ObservationIgnored var onExternalChange: ((Float) -> Void)?
    /// Смена устройства вывода: (имя, SF Symbol) — для AirPods-момента.
    @ObservationIgnored var onDeviceChange: ((String, String) -> Void)?
    @ObservationIgnored private var lastDeviceName: String?
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

    /// Список устройств вывода: (id, имя) — для свитчера.
    func outputDevices() -> [(id: AudioObjectID, name: String)] {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr
        else { return [] }
        let count = Int(size) / MemoryLayout<AudioObjectID>.size
        var ids = [AudioObjectID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids) == noErr
        else { return [] }
        var result: [(AudioObjectID, String)] = []
        for id in ids {
            // только устройства с выходными каналами
            var outAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain)
            var confSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &outAddr, 0, nil, &confSize) == noErr,
                  confSize > 0 else { continue }
            let bufferList = UnsafeMutablePointer<AudioBufferList>
                .allocate(capacity: Int(confSize))
            defer { bufferList.deallocate() }
            guard AudioObjectGetPropertyData(
                id, &outAddr, 0, nil, &confSize, bufferList) == noErr,
                bufferList.pointee.mNumberBuffers > 0 else { continue }
            var nameAddr = AudioObjectPropertyAddress(
                mSelector: kAudioObjectPropertyName,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            var name: CFString = "" as CFString
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            let ok = withUnsafeMutablePointer(to: &name) { ptr in
                AudioObjectGetPropertyData(id, &nameAddr, 0, nil, &nameSize, ptr) == noErr
            }
            guard ok else { continue }
            result.append((id, name as String))
        }
        return result
    }

    func setDefaultOutput(_ id: AudioObjectID) {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var device = id
        AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil,
            UInt32(MemoryLayout<AudioObjectID>.size), &device)
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
            let changed = abs(v - volume) > 0.001
            volume = v
            if changed { onExternalChange?(v) }
        }
    }

    private func updateOutputIcon() {
        let previousName = lastDeviceName
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

        let deviceName = name as String
        let candidate = OutputDeviceIcon.symbol(
            deviceName: deviceName, transportType: transport)
        // Защита от отсутствующего символа на конкретной версии macOS.
        outputIcon = NSImage(systemSymbolName: candidate, accessibilityDescription: nil) != nil
            ? candidate
            : "speaker.wave.3.fill"
        lastDeviceName = deviceName
        // AirPods-момент только на реальную СМЕНУ на беспроводное аудио.
        let isWireless = transport == kAudioDeviceTransportTypeBluetooth
            || transport == kAudioDeviceTransportTypeBluetoothLE
        if let previousName, previousName != deviceName, isWireless {
            onDeviceChange?(deviceName, outputIcon)
        }
    }
}
