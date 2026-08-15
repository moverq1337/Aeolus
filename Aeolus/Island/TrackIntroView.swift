import SwiftUI

/// «Играет вот этот трек»: пилюля-анонс при смене трека. Референс владельца:
/// обложка слева (квадрат со скруглением), справа — название жирным сверху
/// и исполнитель приглушённым снизу.
struct TrackIntroView: View {
    let nowPlaying: NowPlayingStore
    let notchSize: CGSize

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: notchSize.height)
            ZStack {
                content
                    .id(nowPlaying.state?.title ?? "")
                    .transition(.push(
                        from: nowPlaying.lastNavigationDirection == .forward
                            ? .trailing : .leading))
            }
            .animation(
                .spring(response: 0.42, dampingFraction: 0.8),
                value: nowPlaying.state?.title)
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 24)
    }

    private var content: some View {
        HStack(spacing: 12) {
            artwork
            VStack(alignment: .leading, spacing: 2) {
                Text(nowPlaying.state?.title ?? "")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(nowPlaying.state?.artist ?? "")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder private var artwork: some View {
        if let image = nowPlaying.artwork {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "music.note")
                        .foregroundStyle(.white.opacity(0.4))
                }
        }
    }
}
