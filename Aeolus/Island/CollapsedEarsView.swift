import SwiftUI

struct CollapsedEarsView: View {
    let notchSize: CGSize
    let artwork: NSImage?
    let isPlaying: Bool
    var trackKey: String = ""

    var body: some View {
        HStack(spacing: 0) {
            artworkThumb
                .id(trackKey) // смена трека — новая обложка въезжает справа
                .transition(.push(from: .trailing))
                .animation(.spring(response: 0.42, dampingFraction: 0.8), value: trackKey)
                .padding(.leading, 13)
            Spacer(minLength: notchSize.width)
            EqualizerBars(animating: isPlaying)
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
