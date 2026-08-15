import SwiftUI

struct CollapsedEarsView: View {
    let notchSize: CGSize
    let artwork: NSImage?
    let isPlaying: Bool
    var accent: Color = .white
    var trackKey: String = ""
    var direction: TrackDirection = .forward

    var body: some View {
        HStack(spacing: 0) {
            // Карусель: вперёд — новая въезжает справа, назад — слева.
            // ZStack-обёртка живёт всегда — анимация insert/remove работает на ней.
            ZStack {
                artworkThumb
                    .id(trackKey)
                    .transition(.carousel(direction))
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.8), value: trackKey)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .padding(.leading, 13)
            Spacer(minLength: notchSize.width)
            EqualizerBars(animating: isPlaying, tint: accent)
                .padding(.trailing, 14)
        }
        .frame(height: notchSize.height)
    }

    @ViewBuilder private var artworkThumb: some View {
        let side = notchSize.height - 10
        if let artwork {
            Image(nsImage: artwork)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(.white.opacity(0.15))
                .frame(width: side, height: side)
        }
    }
}
