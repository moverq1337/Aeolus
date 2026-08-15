import SwiftUI

/// Раскрытый плеер в стиле нативного Now Playing попапа macOS (референс в спеке §4.1).
/// Громкость скрыта за кнопкой-иконкой устройства (снизу справа, как в референсе);
/// по нажатию остров дорастает и показывает слайдер.
struct ExpandedPlayerView: View {
    let nowPlaying: NowPlayingStore
    let media: MediaActions
    let volume: VolumeController
    let volumeShown: Bool
    let onToggleVolume: () -> Void
    let notchHeight: CGFloat

    var body: some View {
        VStack(spacing: 8) {
            header
            progress
            controlsRow
            if volumeShown {
                VolumeSlider(
                    volume: volume.volume,
                    showPercent: true,
                    onChange: volume.setVolume)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.top, notchHeight - 2)
        .padding(.horizontal, 22)
        .padding(.bottom, 12)
    }

    private var header: some View {
        HStack(spacing: 10) {
            artwork
            VStack(alignment: .leading, spacing: 2) {
                Text(nowPlaying.displayTitle ?? "")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(nowPlaying.displayArtist ?? "")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            EqualizerBars(animating: nowPlaying.state?.playing ?? false, tint: nowPlaying.displayAccent)
        }
    }

    @ViewBuilder private var artwork: some View {
        if let image = nowPlaying.displayArtwork {
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

    private var controlsRow: some View {
        // Референс #12: пять контролов в ряд — shuffle | назад | play | вперёд | устройство.
        HStack {
            ControlButton(systemName: "shuffle", size: 15, action: media.toggleShuffle)
                .opacity(shuffleOn ? 1 : 0.45)
                .foregroundStyle(shuffleOn ? AnyShapeStyle(nowPlaying.displayAccent)
                                           : AnyShapeStyle(.white))
            Spacer()
            ControlButton(systemName: "backward.fill", size: 20, action: media.previous)
            Spacer()
            ControlButton(
                systemName: (nowPlaying.state?.playing ?? false) ? "pause.fill" : "play.fill",
                size: 26,
                action: media.toggle)
            Spacer()
            ControlButton(systemName: "forward.fill", size: 20, action: media.next)
            Spacer()
            ControlButton(systemName: volume.outputIcon, size: 15, action: onToggleVolume)
                .opacity(volumeShown ? 1 : 0.45)
        }
        .padding(.horizontal, 6)
    }

    private var shuffleOn: Bool {
        (nowPlaying.state?.shuffleMode ?? 1) >= 2
    }
}
