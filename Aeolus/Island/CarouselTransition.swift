import SwiftUI

extension AnyTransition {
    /// Карусель треков: вперёд — новое въезжает справа, старое уезжает влево;
    /// назад — зеркально. .move+.opacity вместо .push — тот стабилен на macOS.
    static func carousel(_ direction: TrackDirection) -> AnyTransition {
        .asymmetric(
            insertion: .move(edge: direction == .forward ? .trailing : .leading)
                .combined(with: .opacity),
            removal: .move(edge: direction == .forward ? .leading : .trailing)
                .combined(with: .opacity))
    }
}
