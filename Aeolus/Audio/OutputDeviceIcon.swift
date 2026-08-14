import CoreAudio

/// SF Symbol для устройства вывода — как в Control Center:
/// AirPods рисуем как AirPods, Beats как Beats, динамик как динамик.
enum OutputDeviceIcon {
    static func symbol(deviceName: String, transportType: UInt32) -> String {
        let name = deviceName.lowercased()
        if name.contains("airpods pro") { return "airpodspro" }
        if name.contains("airpods max") { return "airpodsmax" }
        if name.contains("airpods") { return "airpods" }
        if name.contains("beats") { return "beats.headphones" }
        switch transportType {
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            return "headphones"
        case kAudioDeviceTransportTypeAirPlay:
            return "airplayaudio"
        case kAudioDeviceTransportTypeUSB,
             kAudioDeviceTransportTypeDisplayPort,
             kAudioDeviceTransportTypeHDMI,
             kAudioDeviceTransportTypeThunderbolt:
            return "hifispeaker"
        default:
            return "speaker.wave.3.fill"
        }
    }
}
