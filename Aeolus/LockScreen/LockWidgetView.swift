import SwiftUI

/// Карточка Now Playing для экрана блокировки. Прогресс — только отображение
/// (без перемотки на локскрине). Кнопки работают до аутентификации.
struct LockWidgetView: View {
    let nowPlaying: NowPlayingStore
    let media: MediaActions

    var body: some View {
        HStack(spacing: 14) {
            artwork
            VStack(alignment: .leading, spacing: 4) {
                Text(nowPlaying.state?.title ?? "")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(nowPlaying.state?.artist ?? "")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                progress
                controls
            }
        }
        .padding(16)
        .frame(width: LockWidgetLayout.cardSize.width,
               height: LockWidgetLayout.cardSize.height)
        .background(Color.black.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder private var artwork: some View {
        if let image = nowPlaying.artwork {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.15))
                .frame(width: 88, height: 88)
                .overlay {
                    Image(systemName: "music.note")
                        .foregroundStyle(.white.opacity(0.4))
                }
        }
    }

    @ViewBuilder private var progress: some View {
        if let state = nowPlaying.state, let duration = state.duration {
            TimelineView(.animation(minimumInterval: 0.5, paused: !state.playing)) { ctx in
                let fraction = duration > 0
                    ? min(state.position(at: ctx.date) / duration, 1) : 0
                Capsule().fill(.white.opacity(0.25))
                    .frame(height: 3)
                    .overlay(alignment: .leading) {
                        GeometryReader { geo in
                            Capsule().fill(.white.opacity(0.85))
                                .frame(width: max(2, geo.size.width * fraction))
                        }
                    }
            }
            .frame(height: 3)
        } else {
            Spacer().frame(height: 3)
        }
    }

    private var controls: some View {
        HStack(spacing: 24) {
            ControlButton(systemName: "backward.fill", size: 13, action: media.previous)
            ControlButton(
                systemName: (nowPlaying.state?.playing ?? false) ? "pause.fill" : "play.fill",
                size: 18,
                action: media.toggle)
            ControlButton(systemName: "forward.fill", size: 13, action: media.next)
        }
    }
}
