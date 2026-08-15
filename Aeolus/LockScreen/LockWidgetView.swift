import SwiftUI

/// Карточка Now Playing для экрана блокировки: длинная и тонкая, как
/// лайв-активити (фидбек владельца 2026-08-15). Прогресс — только отображение;
/// кнопки работают до аутентификации.
struct LockWidgetView: View {
    let nowPlaying: NowPlayingStore
    let media: MediaActions

    var body: some View {
        HStack(spacing: 12) {
            artwork
            VStack(alignment: .leading, spacing: 3) {
                Text(nowPlaying.state?.title ?? "")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(nowPlaying.state?.artist ?? "")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                progress
            }
            Spacer(minLength: 10)
            controls
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: LockWidgetLayout.cardSize.width,
               height: LockWidgetLayout.cardSize.height)
        .background(Color.black.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder private var artwork: some View {
        if let image = nowPlaying.artwork {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(0.15))
                .frame(width: 64, height: 64)
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
            .padding(.top, 3)
        } else {
            Spacer().frame(height: 6)
        }
    }

    private var controls: some View {
        HStack(spacing: 14) {
            ControlButton(systemName: "backward.fill", size: 12, action: media.previous)
            ControlButton(
                systemName: (nowPlaying.state?.playing ?? false) ? "pause.fill" : "play.fill",
                size: 17,
                action: media.toggle)
            ControlButton(systemName: "forward.fill", size: 12, action: media.next)
        }
    }
}
