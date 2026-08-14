import SwiftUI

/// Временная версия: статичная чёрная форма поверх выреза.
/// Task 8 заменяет содержимое на живой остров.
struct IslandRootView: View {
    let metrics: NotchMetrics

    private var debugTint: Bool {
        ProcessInfo.processInfo.environment["AEOLUS_DEBUG_TINT"] == "1"
    }

    var body: some View {
        NotchShape(topCornerRadius: 6, bottomCornerRadius: 14)
            .fill(debugTint ? Color.red : Color.black)
            .frame(width: metrics.closedSize.width, height: metrics.closedSize.height)
            .frame(
                width: metrics.windowFrame.width,
                height: metrics.windowFrame.height,
                alignment: .top)
    }
}
