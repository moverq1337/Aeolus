import SwiftUI

struct BatteryActivityView: View {
    let flash: BatteryFlash
    let notchSize: CGSize

    @State private var arcShown = false

    var body: some View {
        HStack {
            // Дуга заряда вокруг иконки — как у AirPods-момента в iOS.
            ZStack {
                Circle()
                    .stroke(color.opacity(0.25), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: arcShown ? CGFloat(flash.percentage) / 100 : 0)
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(color)
            }
            .frame(width: 19, height: 19)
            Spacer(minLength: notchSize.width)
            Text(detailText)
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .frame(height: notchSize.height)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15)) {
                arcShown = true
            }
        }
    }

    private var detailText: String {
        var parts = ["\(flash.percentage)%"]
        if flash.kind == .pluggedIn, let watts = flash.watts {
            parts.append("\(watts)W")
        } else if let minutes = flash.minutes {
            parts.append(String(format: "%d:%02d", minutes / 60, minutes % 60))
        }
        return parts.joined(separator: " · ")
    }

    private var icon: String {
        switch flash.kind {
        case .pluggedIn: "bolt.fill"
        case .unplugged, .low, .critical: "battery.100percent"
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
