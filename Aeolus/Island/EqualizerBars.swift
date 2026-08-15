import AppKit
import SwiftUI

/// 5 «дышащих» полосок. Анимация — CABasicAnimation(repeatCount: .infinity):
/// интерполирует render-сервер, процесс приложения не тратит ни одного кадра
/// CPU (инвариант простоя, спека §6). SwiftUI-анимации здесь не подходят —
/// они тикают на главном потоке с частотой ProMotion (~8-10% CPU, проверено
/// сэмплером). В Low Power Mode полоски статичны (§5.6).
struct EqualizerBars: NSViewRepresentable {
    var animating: Bool
    var barCount = 5
    var tint: Color = .white

    func makeNSView(context: Context) -> EqualizerBarsView {
        EqualizerBarsView(barCount: barCount)
    }

    func updateNSView(_ view: EqualizerBarsView, context: Context) {
        view.setAnimating(
            animating && !ProcessInfo.processInfo.isLowPowerModeEnabled)
        view.setTint(NSColor(tint))
    }

    // Без этого representable растягивается на всю предложенную ширину
    // и полоски уезжают от правого края к заголовку.
    func sizeThatFits(
        _ proposal: ProposedViewSize, nsView: EqualizerBarsView, context: Context
    ) -> CGSize? {
        CGSize(width: CGFloat(barCount * 4 - 2), height: 14)
    }
}

final class EqualizerBarsView: NSView {
    /// Верхние точки «дыхания» — живой, несинхронный ритм.
    private static let topScales: [CGFloat] = [1.0, 0.62, 0.88, 0.55, 0.92]
    private static let restScale: CGFloat = 0.25

    private var bars: [CALayer] = []
    private let barCount: Int
    private var animating = false

    init(barCount: Int) {
        self.barCount = barCount
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = false
        for _ in 0..<barCount {
            let bar = CALayer()
            bar.backgroundColor = NSColor.white.cgColor
            bar.cornerRadius = 1
            bar.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            bar.transform = CATransform3DMakeScale(1, Self.restScale, 1)
            layer?.addSublayer(bar)
            bars.append(bar)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    override var intrinsicContentSize: NSSize {
        NSSize(width: barCount * 4 - 2, height: 14)
    }

    override func layout() {
        super.layout()
        let height: CGFloat = 12
        let midY = bounds.height / 2
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (i, bar) in bars.enumerated() {
            bar.bounds = CGRect(x: 0, y: 0, width: 2, height: height)
            bar.position = CGPoint(x: CGFloat(i) * 4 + 1, y: midY)
        }
        CATransaction.commit()
    }

    func setTint(_ color: NSColor) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for bar in bars { bar.backgroundColor = color.cgColor }
        CATransaction.commit()
    }

    func setAnimating(_ on: Bool) {
        guard on != animating else { return }
        animating = on
        if on {
            for (i, bar) in bars.enumerated() {
                let anim = CABasicAnimation(keyPath: "transform.scale.y")
                anim.fromValue = Self.restScale
                anim.toValue = Self.topScales[i % Self.topScales.count]
                anim.duration = 0.42 + Double(i) * 0.07
                anim.autoreverses = true
                anim.repeatCount = .infinity
                anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                anim.beginTime = CACurrentMediaTime() + Double(i) * 0.1
                bar.add(anim, forKey: "breathe")
            }
        } else {
            for bar in bars {
                bar.removeAnimation(forKey: "breathe")
            }
        }
    }
}
