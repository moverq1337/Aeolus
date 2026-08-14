import SwiftUI

struct CollapsedEarsView: View {
    let notchSize: CGSize
    let artwork: NSImage?
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 0) {
            artworkThumb
                .padding(.leading, 7)
            Spacer(minLength: notchSize.width)
            EqualizerBars(animating: isPlaying)
                .padding(.trailing, 9)
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
