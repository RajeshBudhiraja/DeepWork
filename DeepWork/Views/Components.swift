import UIKit

/// A selectable duration tile: big number, small label.
final class DurationTile: UIControl {

    let duration: DeepWorkDuration

    private let numberLabel = UILabel()
    private let unitLabel = UILabel()
    private let nameLabel = UILabel()

    override var isSelected: Bool {
        didSet { updateAppearance() }
    }

    init(duration: DeepWorkDuration) {
        self.duration = duration
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = Theme.Metric.cornerRadius
        layer.cornerCurve = .continuous
        layer.borderWidth = 1

        numberLabel.font = .systemFont(ofSize: 30, weight: .semibold)
        numberLabel.text = duration.title
        numberLabel.textAlignment = .center

        unitLabel.font = Theme.Font.caption
        unitLabel.text = "min"
        unitLabel.textAlignment = .center

        nameLabel.font = Theme.Font.caption
        nameLabel.text = duration.subtitle
        nameLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [numberLabel, unitLabel, nameLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 0
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        stack.setCustomSpacing(6, after: unitLabel)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 104)
        ])

        registerThemeObserver()
        updateAppearance()
    }

    /// `CGColor` snapshots a dynamic `UIColor` at assignment and never
    /// re-resolves, so layer colours must be re-applied when the theme flips.
    private func registerThemeObserver() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: DurationTile, _) in
            view.updateAppearance()
        }
    }

    /// Both states carry a dark fill — `primary` when selected, `accent` when
    /// not — so the tile text stays white in light and dark alike. Selection is
    /// signalled by the stronger fill plus a border ring, not by a text colour
    /// change.
    private func updateAppearance() {
        backgroundColor = isSelected ? Theme.Color.primary : Theme.Color.accent
        layer.borderColor = (isSelected ? Theme.Color.onFilled : UIColor.clear)
            .resolved(for: self).cgColor
        layer.borderWidth = isSelected ? 2 : 0

        numberLabel.textColor = Theme.Color.onFilled
        unitLabel.textColor = Theme.Color.onFilled
        nameLabel.textColor = Theme.Color.onFilled
        unitLabel.alpha = isSelected ? 1.0 : 0.75
        nameLabel.alpha = isSelected ? 1.0 : 0.75
    }

}

/// Full-width primary action button.
final class PrimaryButton: UIButton {

    init(title: String, role: Role = .primary) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = role.fill
        config.baseForegroundColor = role.foreground
        config.cornerStyle = .large
        config.attributedTitle = AttributedString(
            title,
            attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: 17, weight: .semibold)])
        )
        configuration = config

        // Pressed state varies the token's opacity rather than introducing a new
        // hue, per the design rules.
        configurationUpdateHandler = { button in
            button.alpha = button.isHighlighted ? Theme.State.pressed : 1.0
            button.alpha = button.isEnabled ? button.alpha : Theme.State.disabled
        }

        heightAnchor.constraint(equalToConstant: Theme.Metric.buttonHeight).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    enum Role {
        /// primary actions and key emphasis
        case primary
        /// secondary actions and quieter emphasis
        case secondary
        /// destructive actions and failure status
        case destructive

        var fill: UIColor {
            switch self {
            case .primary:     return Theme.Color.primary
            case .secondary:   return Theme.Color.secondary
            case .destructive: return Theme.Color.error
            }
        }

        var foreground: UIColor { Theme.Color.onFilled }
    }
}

/// Bordered, low-emphasis button for tertiary actions.
final class QuietButton: UIButton {

    init(title: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = Theme.Color.secondary
        config.attributedTitle = AttributedString(
            title,
            attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: 15, weight: .medium)])
        )
        configuration = config

        configurationUpdateHandler = { button in
            button.alpha = button.isHighlighted ? Theme.State.pressed : 1.0
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// One number plus its label, used in the stats row.
final class StatTile: UIView {

    private let valueLabel = UILabel()
    private let captionLabel = UILabel()

    init(caption: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        valueLabel.font = Theme.Font.statValue
        valueLabel.textColor = Theme.Color.text
        valueLabel.textAlignment = .center
        valueLabel.text = "0"

        captionLabel.font = Theme.Font.caption
        captionLabel.textColor = Theme.Color.textSecondary
        captionLabel.textAlignment = .center
        captionLabel.text = caption
        captionLabel.numberOfLines = 1
        captionLabel.adjustsFontSizeToFitWidth = true
        captionLabel.minimumScaleFactor = 0.8

        let stack = UIStackView(arrangedSubviews: [valueLabel, captionLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setValue(_ value: String) {
        valueLabel.text = value
    }
}

/// The egg-in-progress card on the home screen: glyph, species, progress bar,
/// and how much focus is left before it hatches.
final class EggCard: UIControl {

    private let glyphLabel = UILabel()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let progressTrack = UIView()
    private let progressFill = UIView()
    private var fillWidth: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = Theme.Color.surface
        layer.cornerRadius = Theme.Metric.cornerRadius
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = Theme.Color.border.resolved(for: self).cgColor
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: EggCard, _) in
            view.layer.borderColor = Theme.Color.border.resolved(for: view).cgColor
        }

        glyphLabel.font = .systemFont(ofSize: 40)
        glyphLabel.textAlignment = .center
        glyphLabel.setContentHuggingPriority(.required, for: .horizontal)

        titleLabel.font = Theme.Font.heading
        titleLabel.textColor = Theme.Color.text

        detailLabel.font = Theme.Font.caption
        detailLabel.textColor = Theme.Color.textSecondary
        detailLabel.numberOfLines = 2

        progressTrack.backgroundColor = Theme.Color.border.withAlphaComponent(Theme.State.subtle)
        progressTrack.layer.cornerRadius = 4
        progressTrack.translatesAutoresizingMaskIntoConstraints = false

        progressFill.backgroundColor = Theme.Color.primary
        progressFill.layer.cornerRadius = 4
        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressTrack.addSubview(progressFill)

        let textStack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.alignment = .leading

        let topStack = UIStackView(arrangedSubviews: [glyphLabel, textStack])
        topStack.axis = .horizontal
        topStack.spacing = 14
        topStack.alignment = .center

        let outer = UIStackView(arrangedSubviews: [topStack, progressTrack])
        outer.axis = .vertical
        outer.spacing = 14
        outer.isUserInteractionEnabled = false
        outer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(outer)

        let fill = progressFill.widthAnchor.constraint(equalToConstant: 0)
        fillWidth = fill

        NSLayoutConstraint.activate([
            outer.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            outer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18),
            outer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            outer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            progressTrack.heightAnchor.constraint(equalToConstant: 8),
            progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
            progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),
            fill
        ])
    }

    /// Render an egg in progress, or the empty "choose an egg" state.
    func configure(with egg: Egg?) {
        guard let egg, let species = egg.species else {
            glyphLabel.text = "🥚"
            titleLabel.text = "No egg yet"
            detailLabel.text = "Choose a bird or reptile to start incubating."
            progressTrack.isHidden = true
            return
        }

        progressTrack.isHidden = false
        glyphLabel.text = "🥚"
        titleLabel.text = "\(species.name) egg"

        // Show what is banked as well as what is left — progress you cannot see
        // is progress that does not motivate.
        let banked = egg.secondsAccumulated
        let remaining = egg.remainingSeconds
        let percent = Int((egg.progress * 100).rounded())

        detailLabel.text = remaining > 0
            ? "\(banked.compactString) in · \(remaining.compactString) to go · \(percent)%"
            : "Ready to hatch"

        setNeedsLayout()
        layoutIfNeeded()
        fillWidth?.constant = progressTrack.bounds.width * CGFloat(egg.progress)
        UIView.animate(withDuration: 0.35) { self.layoutIfNeeded() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Re-derive the fill width after any bounds change so rotation and
        // dynamic type do not desync the bar from its value.
        if let egg = currentEgg {
            fillWidth?.constant = progressTrack.bounds.width * CGFloat(egg.progress)
        }
    }

    private var currentEgg: Egg?

    func setEgg(_ egg: Egg?) {
        currentEgg = egg
        configure(with: egg)
    }
}
