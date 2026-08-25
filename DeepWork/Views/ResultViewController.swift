import UIKit

/// What happened, stated plainly.
///
/// The failure copy reports a fact and assigns no blame. A session can end
/// because of an incoming call or a low-battery alert, and an app that scolds
/// the user for those gets deleted. An app that keeps an honest record gets
/// trusted.
final class ResultViewController: UIViewController {

    private let record: SessionRecord
    private let hatched: HatchedCreature?

    var onDismiss: (() -> Void)?

    init(record: SessionRecord, hatched: HatchedCreature?) {
        self.record = record
        self.hatched = hatched
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.background
        buildLayout()
    }

    private func buildLayout() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        let portrait = CreaturePortraitView(diameter: 150)
        let glyph = UILabel()
        glyph.font = .systemFont(ofSize: 72)
        glyph.textAlignment = .center

        let headline = UILabel()
        headline.font = Theme.Font.title
        headline.textAlignment = .center
        headline.numberOfLines = 0

        let detail = UILabel()
        detail.font = Theme.Font.body
        detail.textColor = Theme.Color.textSecondary
        detail.textAlignment = .center
        detail.numberOfLines = 0

        let elapsed = UILabel()
        elapsed.font = Theme.Font.timer(44)
        elapsed.textColor = Theme.Color.text
        elapsed.textAlignment = .center
        elapsed.text = record.elapsedDuration.clockString

        let elapsedCaption = UILabel()
        elapsedCaption.font = Theme.Font.caption
        elapsedCaption.textColor = Theme.Color.textSecondary
        elapsedCaption.textAlignment = .center

        if let hatched, let species = hatched.species {
            // The hatch takes over the screen — it is the payoff and should not
            // share space with statistics.
            portrait.show(species)
            glyph.isHidden = true
            headline.textColor = Theme.Color.success
            headline.text = "A \(species.name) hatched"
            detail.text = species.blurb
            elapsedCaption.text = "\(hatched.secondsInvested.compactString) of deep work went into it — \(species.incubationDays) real incubation days"
            elapsed.text = record.elapsedDuration.clockString
        } else if record.didComplete {
            glyph.text = "🥚"
            headline.textColor = Theme.Color.success
            headline.text = "Session complete"
            detail.text = eggProgressLine()
            elapsedCaption.text = "credited to your egg"
        } else if let reason = record.failureReason {
            glyph.text = "🥚"
            glyph.alpha = Theme.State.disabled
            headline.textColor = Theme.Color.error
            headline.text = reason.headline
            detail.text = reason.detail + " " + eggProgressLine()
            elapsedCaption.text = "credited to your egg anyway"
        }

        stack.addArrangedSubview(portrait)
        stack.addArrangedSubview(glyph)
        stack.addArrangedSubview(headline)
        portrait.isHidden = (hatched == nil)
        stack.addArrangedSubview(detail)
        stack.setCustomSpacing(30, after: detail)
        stack.addArrangedSubview(elapsed)
        stack.addArrangedSubview(elapsedCaption)

        let done = PrimaryButton(
            title: hatched != nil ? "Add to collection" : "Done",
            role: record.didComplete ? .primary : .secondary
        )
        done.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        done.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(done)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            done.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.Metric.gutter),
            done.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.Metric.gutter),
            done.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])

        if hatched != nil {
            portrait.animateHatch()
        }
    }

    private func eggProgressLine() -> String {
        guard let egg = Incubator.shared.currentEgg, let species = egg.species else {
            return "Choose an egg to start collecting."
        }
        return "\(egg.remainingSeconds.compactString) of focus until your \(species.name) hatches."
    }

    @objc private func doneTapped() {
        SessionSound.teardown()
        dismiss(animated: true) { [weak self] in
            self?.onDismiss?()
        }
    }
}
