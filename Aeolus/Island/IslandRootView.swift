import SwiftUI

struct IslandRootView: View {
    let metrics: NotchMetrics
    let vm: IslandViewModel
    let nowPlaying: NowPlayingStore
    let media: MediaActions
    let volume: VolumeController

    private var layout: IslandLayout { IslandLayout(notchSize: metrics.closedSize) }

    var body: some View {
        let size = layout.size(for: vm.state)
        let radii = layout.radii(for: vm.state)

        ZStack(alignment: .top) {
            NotchShape(topCornerRadius: radii.top, bottomCornerRadius: radii.bottom)
                .fill(Color.black)
            islandContent
        }
        .clipShape(NotchShape(topCornerRadius: radii.top, bottomCornerRadius: radii.bottom))
        // 1px чёрная полоска у кромки — прячет шов между окном и бесселем (спека §6)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.black)
                .frame(height: 1)
                .padding(.horizontal, radii.top)
        }
        .compositingGroup()
        .shadow(
            color: .black.opacity(vm.state.surface == .expanded ? 0.55 : 0),
            radius: 6, y: 2)
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .onHover { inside in
            vm.handle(inside ? .hoverBegan : .hoverEnded)
        }
        .onTapGesture { vm.handle(.tapped) }
        .animation(animation(for: vm.state.surface), value: vm.state)
        .frame(
            width: metrics.windowFrame.width,
            height: metrics.windowFrame.height,
            alignment: .top)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder private var islandContent: some View {
        switch vm.state.surface {
        case .collapsed, .peek:
            if vm.state.hasSession {
                CollapsedEarsView(
                    notchSize: metrics.closedSize,
                    artwork: nowPlaying.artwork,
                    isPlaying: vm.state.isPlaying)
            }
        case .expanded:
            ExpandedPlayerView(
                nowPlaying: nowPlaying,
                media: media,
                volume: volume,
                volumeShown: vm.state.volumeShown,
                onToggleVolume: { vm.handle(.volumeToggled) },
                notchHeight: metrics.closedSize.height)
        case .battery(let flash):
            batteryContent(flash)
        }
    }

    @ViewBuilder private func batteryContent(_ flash: BatteryFlash) -> some View {
        BatteryActivityView(flash: flash, notchSize: metrics.closedSize)
    }

    private func animation(for surface: IslandState.Surface) -> Animation {
        switch surface {
        case .expanded: .spring(response: 0.42, dampingFraction: 0.8)
        case .peek: .interactiveSpring(response: 0.38, dampingFraction: 0.8)
        case .collapsed, .battery: .spring(response: 0.45, dampingFraction: 1.0)
        }
    }
}
