import SwiftUI

/// «Играет вот этот трек»: широкая тонкая пилюля (референс владельца):
/// маленькая обложка в верхнем-левом углу, тонированный эквалайзер справа,
/// по центру строка «♪ Название · Артист».
struct TrackIntroView: View {
    let nowPlaying: NowPlayingStore
    let notchSize: CGSize

    var body: some View {
        ZStack(alignment: .top) {
            // Обложка крупно в верхнем-левом углу (референс #13), эквалайзер справа
            HStack(alignment: .top) {
                artwork
                    .padding(.top, 9)
                Spacer(minLength: notchSize.width)
                EqualizerBars(animating: true, tint: nowPlaying.displayAccent)
                    .frame(height: notchSize.height)
            }
            .padding(.horizontal, 20)

            // Центральная строка под вырезом
            VStack(spacing: 0) {
                Spacer().frame(height: notchSize.height - 2)
                HStack(spacing: 5) {
                    Image(systemName: "music.note")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(nowPlaying.displayAccent)
                    Text(nowPlaying.displayTitle ?? "")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("·")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                    Text(nowPlaying.displayArtist ?? "")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
                .frame(maxHeight: .infinity)
            }
            .padding(.horizontal, 56)
        }
    }

    @ViewBuilder private var artwork: some View {
        if let image = nowPlaying.displayArtwork {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(0.15))
                .frame(width: 36, height: 36)
        }
    }
}
