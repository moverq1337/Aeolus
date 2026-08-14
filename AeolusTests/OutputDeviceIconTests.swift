import CoreAudio
import Testing
@testable import Aeolus

struct OutputDeviceIconTests {
    @Test func airPodsFamilyByName() {
        #expect(OutputDeviceIcon.symbol(
            deviceName: "Павел's AirPods Pro",
            transportType: kAudioDeviceTransportTypeBluetooth) == "airpodspro")
        #expect(OutputDeviceIcon.symbol(
            deviceName: "AirPods Max",
            transportType: kAudioDeviceTransportTypeBluetooth) == "airpodsmax")
        #expect(OutputDeviceIcon.symbol(
            deviceName: "Мои AirPods",
            transportType: kAudioDeviceTransportTypeBluetooth) == "airpods")
    }

    @Test func beatsByName() {
        #expect(OutputDeviceIcon.symbol(
            deviceName: "Beats Studio Pro",
            transportType: kAudioDeviceTransportTypeBluetooth) == "beats.headphones")
    }

    @Test func genericBluetoothIsHeadphones() {
        #expect(OutputDeviceIcon.symbol(
            deviceName: "WH-1000XM5",
            transportType: kAudioDeviceTransportTypeBluetooth) == "headphones")
        #expect(OutputDeviceIcon.symbol(
            deviceName: "Buds",
            transportType: kAudioDeviceTransportTypeBluetoothLE) == "headphones")
    }

    @Test func builtInIsSpeaker() {
        #expect(OutputDeviceIcon.symbol(
            deviceName: "MacBook Pro Speakers",
            transportType: kAudioDeviceTransportTypeBuiltIn) == "speaker.wave.3.fill")
    }

    @Test func airPlayAndWiredFallbacks() {
        #expect(OutputDeviceIcon.symbol(
            deviceName: "Гостиная",
            transportType: kAudioDeviceTransportTypeAirPlay) == "airplayaudio")
        #expect(OutputDeviceIcon.symbol(
            deviceName: "External DAC",
            transportType: kAudioDeviceTransportTypeUSB) == "hifispeaker")
        #expect(OutputDeviceIcon.symbol(
            deviceName: "???",
            transportType: 0) == "speaker.wave.3.fill")
    }
}
