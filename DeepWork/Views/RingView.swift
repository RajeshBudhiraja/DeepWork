import UIKit

/// Circular progress ring drawn with `CAShapeLayer`.
///
/// Layers rather than `draw(_:)`: `strokeEnd` animates on the compositor and
/// costs no main-thread redraw, which matters when the view is on screen for 90
/// minutes straight.
final class RingView: UIView {

    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()

    var lineWidth: CGFloat = 3 {
        didSet {
            trackLayer.lineWidth = lineWidth
            progressLayer.lineWidth = lineWidth
            setNeedsLayout()
        }
    }

    var progressColor: UIColor = Theme.Color.primary {
        didSet { progressLayer.strokeColor = progressColor.resolved(for: self).cgColor }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        backgroundColor = .clear

        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.lineWidth = lineWidth
        trackLayer.lineCap = .round
        layer.addSublayer(trackLayer)

        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.lineWidth = lineWidth
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0
        layer.addSublayer(progressLayer)

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: RingView, _) in
            view.applyColors()
        }
        applyColors()
    }

    /// `CGColor` snapshots a dynamic `UIColor` at assignment time and does not
    /// re-resolve, so layer strokes must be re-applied whenever the theme flips.
    private func applyColors() {
        trackLayer.strokeColor = Theme.Color.border.resolved(for: self).cgColor
        progressLayer.strokeColor = progressColor.resolved(for: self).cgColor
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let inset = lineWidth / 2
        let rect = bounds.insetBy(dx: inset, dy: inset)
        let radius = min(rect.width, rect.height) / 2

        // Start at 12 o'clock rather than 3 — a clock that starts anywhere else
        // reads as a chart, not a timer.
        let path = UIBezierPath(
            arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
            radius: radius,
            startAngle: -.pi / 2,
            endAngle: 1.5 * .pi,
            clockwise: true
        )

        trackLayer.frame = bounds
        progressLayer.frame = bounds
        trackLayer.path = path.cgPath
        progressLayer.path = path.cgPath
    }

    /// - Parameter progress: 0...1.
    func setProgress(_ progress: Double, animated: Bool = true) {
        let clamped = CGFloat(min(1, max(0, progress)))
        guard animated else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            progressLayer.strokeEnd = clamped
            CATransaction.commit()
            return
        }
        progressLayer.strokeEnd = clamped
    }
}
