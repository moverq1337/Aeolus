import SwiftUI

/// «Играет вот этот трек»: пилюля-анонс при смене трека — обложка и имя
/// исполнителя под вырезом, как музыкальный стикер в сторис.
struct TrackIntroView: View {
    let nowPlaying: NowPlayingStore
    let notchSize: CGSize

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: notchSize.height)
            HStack(spacing: 10) {
                artwork
                Text(nowPlaying.state?.artist ?? nowPlaying.state?.title ?? "")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder private var artwork: some View {
        if let image = nowPlaying.artwork {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(.white.opacity(0.15))
                .frame(width: 30, height: 30)
        }
    }
}
