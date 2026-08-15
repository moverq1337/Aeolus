import SwiftUI

/// Плеер на экране блокировки в стиле нативного iOS-виджета (референс #11):
/// морозное стекло с тонированием акцентом обложки, крупная обложка,
/// прогресс с временами по краям, пять контролов внизу.
struct LockWidgetView: View {
    let nowPlaying: NowPlayingStore
    let media: MediaActions
    var presentation: LockWidgetPresentation? = nil

    private var shown: Bool { presentation?.shown ?? true }

    var body: some View {
        VStack(spacing: 10) {
            header
            progress
            controls
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(width: LockWidgetLayout.cardSize.width,
               height: LockWidgetLayout.cardSize.height)
        .background {
            ZStack {
                VisualEffectBackground()
                nowPlaying.displayAccent.opacity(0.12)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .scaleEffect(shown ? 1 : 0.94)
        .opacity(shown ? 1 : 0)
        .offset(y: shown ? 0 : 12)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: shown)
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        HStack(spacing: 12) {
            artwork
            VStack(alignment: .leading, spacing: 2) {
                Text(nowPlaying.displayTitle ?? "")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(nowPlaying.displayArtist ?? "")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
        }
    }

    @ViewBuilder private var artwork: some View {
        if let image = nowPlaying.displayArtwork {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(.white.opacity(0.18))
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "music.note")
                        .foregroundStyle(.white.opacity(0.45))
                }
        }
    }

    @ViewBuilder private var progress: some View {
        let state = nowPlaying.state
        let duration = state?.duration
        TimelineView(.animation(minimumInterval: 0.5, paused: !(state?.playing ?? false))) { ctx in
            let position = state.map { $0.position(at: ctx.date) } ?? 0
            HStack(spacing: 8) {
                timeLabel(duration != nil ? TimeFormatter.clock(position) : "-:--")
                Capsule().fill(.white.opacity(0.25))
                    .frame(height: 4)
                    .overlay(alignment: .leading) {
                        GeometryReader { geo in
                            if let duration, duration > 0 {
                                Capsule().fill(.white.opacity(0.9))
                                    .frame(width: max(3, geo.size.width
                                        * min(position / duration, 1)))
                            }
                        }
                    }
                timeLabel(duration != nil
                    ? "-" + TimeFormatter.clock(max((duration ?? 0) - position, 0))
                    : "-:--")
            }
        }
        .frame(height: 14)
    }

    private func timeLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium).monospacedDigit())
            .foregroundStyle(.white.opacity(0.6))
            .frame(minWidth: 34)
    }

    private var controls: some View {
        HStack {
            ControlButton(
                systemName: "shuffle", size: 15,
                tint: shuffleOn ? nowPlaying.displayAccent : .white,
                action: media.toggleShuffle)
                .opacity(shuffleOn ? 1 : 0.45)
            Spacer()
            ControlButton(systemName: "backward.fill", size: 19, action: media.previous)
            Spacer()
            ControlButton(
                systemName: (nowPlaying.state?.playing ?? false) ? "pause.fill" : "play.fill",
                size: 25,
                action: media.toggle)
            Spacer()
            ControlButton(systemName: "forward.fill", size: 19, action: media.next)
            Spacer()
            Image(systemName: "macbook")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 40, height: 32)
        }
        .padding(.horizontal, 4)
    }

    private var shuffleOn: Bool {
        (nowPlaying.state?.shuffleMode ?? 1) >= 2
    }
}

/// Морозное стекло: системный материал за окном (лок-скрин размывает обои сам).
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
