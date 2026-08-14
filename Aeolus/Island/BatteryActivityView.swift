import SwiftUI

struct BatteryActivityView: View {
    let flash: BatteryFlash
    let notchSize: CGSize

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
            Spacer(minLength: notchSize.width)
            Text("\(flash.percentage)%")
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(color)
        }
        .padding(.horizontal, 16)
        .frame(height: notchSize.height)
    }

    private var icon: String {
        switch flash.kind {
        case .pluggedIn: "bolt.fill"
        case .unplugged, .low, .critical: batteryIcon
        }
    }

    private var batteryIcon: String {
        switch flash.percentage {
        case 76...: "battery.100percent"
        case 51...75: "battery.75percent"
        case 26...50: "battery.50percent"
        case 11...25: "battery.25percent"
        default: "battery.0percent"
        }
    }

    private var color: Color {
        switch flash.kind {
        case .pluggedIn: .green
        case .unplugged: .white
        case .low: .orange
        case .critical: .red
        }
    }
}
