import CoreGraphics

/// Чистая логика двухпальцевых свайпов по острову (scroll-события с фазами).
/// Ось захватывается на весь жест по доминирующему накоплению после мёртвой
/// зоны. Горизонталь — одно срабатывание на жест (трек), вертикаль —
/// непрерывная громкость. Дельты нормализуются так, что «пальцы вверх» всегда
/// значит «громче», независимо от natural scrolling.
struct ScrollGestureRecognizer {
    enum Phase { case began, changed, ended }

    enum Action: Equatable {
        case volumeChange(Float)
        case nextTrack
        case previousTrack
    }

    static let deadZone: CGFloat = 8
    static let trackThreshold: CGFloat = 40
    static let volumePerPoint: Float = 0.004

    private enum Axis { case horizontal, vertical }

    private var accX: CGFloat = 0
    private var accY: CGFloat = 0
    private var axis: Axis?
    private var firedTrack = false

    mutating func handle(
        phase: Phase, deltaX: CGFloat, deltaY: CGFloat, inverted: Bool
    ) -> [Action] {
        switch phase {
        case .began, .ended:
            accX = 0
            accY = 0
            axis = nil
            firedTrack = false
            return []
        case .changed:
            // Нормализация: fingersUp > 0 = пальцы вверх; fingersLeft > 0 = влево.
            // natural scrolling (inverted=true): пальцы вверх дают deltaY < 0,
            // пальцы влево дают deltaX > 0; классика — наоборот.
            let fingersUp = inverted ? -deltaY : deltaY
            let fingersLeft = inverted ? deltaX : -deltaX
            accX += fingersLeft
            accY += fingersUp

            if axis == nil {
                let ax = abs(accX)
                let ay = abs(accY)
                guard max(ax, ay) > Self.deadZone else { return [] }
                axis = ax >= ay ? .horizontal : .vertical
            }

            switch axis {
            case .vertical:
                return [.volumeChange(Float(fingersUp) * Self.volumePerPoint)]
            case .horizontal:
                guard !firedTrack, abs(accX) > Self.trackThreshold else { return [] }
                firedTrack = true
                return [accX > 0 ? .nextTrack : .previousTrack]
            case nil:
                return []
            }
        }
    }
}
