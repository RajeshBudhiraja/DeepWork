import UIKit

/// The hatched creature, rendered large.
///
/// The glyph is drawn into a circular `accent` disc with a ring, so a hatched
/// animal reads as a portrait rather than as loose text. Emoji is the image
/// source deliberately: it ships with the OS, renders crisply at any size, needs
/// no bundled assets or network, and carries no licensing question — which
/// photographs of real animals would.
final class CreaturePortraitView: UIView {

    private let disc = UIView()
    private let glyphLabel = UILabel()
    private var diameter: CGFloat

    /// - Parameter diameter: outer size of the disc in points.
    init(diameter: CGFloat = 140) {
        self.diameter = diameter
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false

        disc.translatesAutoresizingMaskIntoConstraints = false
        disc.backgroundColor = Theme.Color.accent
        disc.layer.cornerRadius = diameter / 2
        disc.layer.borderWidth = 2
        disc.layer.borderColor = Theme.Color.border.resolved(for: self).cgColor
        addSubview(disc)

        // The glyph is scaled to the disc so the creature fills its portrait.
        glyphLabel.font = .systemFont(ofSize: diameter * 0.52)
        glyphLabel.textAlignment = .center
        glyphLabel.adjustsFontSizeToFitWidth = true
        glyphLabel.minimumScaleFactor = 0.5
        glyphLabel.translatesAutoresizingMaskIntoConstraints = false
        disc.addSubview(glyphLabel)

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: CreaturePortraitView, _) in
            view.disc.layer.borderColor = Theme.Color.border.resolved(for: view).cgColor
        }

        NSLayoutConstraint.activate([
            disc.widthAnchor.constraint(equalToConstant: diameter),
            disc.heightAnchor.constraint(equalToConstant: diameter),
            disc.topAnchor.constraint(equalTo: topAnchor),
            disc.bottomAnchor.constraint(equalTo: bottomAnchor),
            disc.centerXAnchor.constraint(equalTo: centerXAnchor),
            disc.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            disc.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),

            glyphLabel.centerXAnchor.constraint(equalTo: disc.centerXAnchor),
            glyphLabel.centerYAnchor.constraint(equalTo: disc.centerYAnchor),
            glyphLabel.widthAnchor.constraint(equalTo: disc.widthAnchor, multiplier: 0.7)
        ])
    }

    /// Show a hatched creature.
    func show(_ species: Species) {
        glyphLabel.text = species.glyph
        glyphLabel.alpha = 1
        disc.backgroundColor = Theme.Color.accent
    }

    /// Show the un-hatched egg state for a species not yet collected.
    func showEgg() {
        glyphLabel.text = "🥚"
        glyphLabel.alpha = Theme.State.disabled
        disc.backgroundColor = Theme.Color.surface
    }

    /// Spring the portrait in. Used for the hatch moment.
    func animateHatch(delay: TimeInterval = 0.15) {
        disc.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        disc.alpha = 0
        UIView.animate(
            withDuration: 0.75,
            delay: delay,
            usingSpringWithDamping: 0.52,
            initialSpringVelocity: 0.7
        ) {
            self.disc.transform = .identity
            self.disc.alpha = 1
        }
    }
}
