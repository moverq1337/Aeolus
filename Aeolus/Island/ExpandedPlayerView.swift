import SwiftUI

/// Раскрытый плеер в стиле нативного Now Playing попапа macOS (референс в спеке §4.1).
struct ExpandedPlayerView: View {
    let nowPlaying: NowPlayingStore
    let media: MediaActions
    let volume: VolumeController
    let notchHeight: CGFloat

    var body: some View {
        VStack(spacing: 10) {
            header
            progress
            controls
            VolumeSlider(
                volume: volume.volume,
                deviceIcon: volume.outputIcon,
                onChange: volume.setVolume)
        }
        .padding(.top, notchHeight + 4)
        .padding(.horizontal, 22)
        .padding(.bottom, 14)
    }

    private var header: some View {
        HStack(spacing: 10) {
            artwork
            VStack(alignment: .leading, spacing: 2) {
                Text(nowPlaying.state?.title ?? "")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(nowPlaying.state?.artist ?? "")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            EqualizerBars(animating: nowPlaying.state?.playing ?? false)
        }
    }

    @ViewBuilder private var artwork: some View {
        if let image = nowPlaying.artwork {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(0.15))
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: "music.note")
                        .foregroundStyle(.white.opacity(0.4))
                }
        }
    }

    @ViewBuilder private var progress: some View {
        if let state = nowPlaying.state, let duration = state.duration {
            TrackProgressBar(
                duration: duration,
                isPlaying: state.playing,
                position: { state.position(at: $0) },
                onSeek: media.seek)
        } else {
            Spacer().frame(height: 14) // live-стрим: прогресса нет (спека §5.5)
        }
    }

    private var controls: some View {
        HStack(spacing: 34) {
            ControlButton(systemName: "backward.fill", action: media.previous)
            ControlButton(
                systemName: (nowPlaying.state?.playing ?? false) ? "pause.fill" : "play.fill",
                size: 24,
                action: media.toggle)
            ControlButton(systemName: "forward.fill", action: media.next)
        }
    }
}
