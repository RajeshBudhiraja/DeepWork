import UIKit

/// Tapping a species opens its card: the creature at full size, its real
/// incubation period, what that costs in deep work, and — once hatched — when
/// you got it.
final class CreatureDetailViewController: UIViewController {

    private let species: Species
    private let incubator: Incubator

    /// Called when the user chooses to incubate this species.
    var onIncubate: ((Species) -> Void)?

    init(species: Species, incubator: Incubator = .shared) {
        self.species = species
        self.incubator = incubator
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.background
        buildLayout()
    }

    private func buildLayout() {
        let owned = incubator.hatchedCount(of: species.id)
        let isIncubating = incubator.currentEgg?.speciesID == species.id

        let portrait = CreaturePortraitView(diameter: 150)
        if owned > 0 { portrait.show(species) } else { portrait.showEgg() }

        let name = UILabel()
        name.text = species.name
        name.font = Theme.Font.title
        name.textColor = Theme.Color.text
        name.textAlignment = .center
        name.numberOfLines = 0

        let familyLabel = UILabel()
        familyLabel.text = species.family.title.uppercased()
        familyLabel.font = Theme.Font.caption
        familyLabel.textColor = Theme.Color.textSecondary
        familyLabel.textAlignment = .center

        let blurb = UILabel()
        blurb.text = species.blurb
        blurb.font = Theme.Font.body
        blurb.textColor = Theme.Color.textSecondary
        blurb.textAlignment = .center
        blurb.numberOfLines = 0

        let facts = makeFactsCard(owned: owned)

        let stack = UIStackView(arrangedSubviews: [
            portrait, familyLabel, name, blurb, facts
        ])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 10
        stack.setCustomSpacing(18, after: portrait)
        stack.setCustomSpacing(4, after: familyLabel)
        stack.setCustomSpacing(14, after: name)
        stack.setCustomSpacing(26, after: blurb)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        let action: UIButton
        if isIncubating {
            let button = PrimaryButton(title: "Currently incubating", role: .secondary)
            button.isEnabled = false
            action = button
        } else {
            let button = PrimaryButton(title: "Incubate this egg", role: .primary)
            button.addTarget(self, action: #selector(incubateTapped), for: .touchUpInside)
            action = button
        }
        action.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(action)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            facts.widthAnchor.constraint(equalTo: stack.widthAnchor),

            action.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.Metric.gutter),
            action.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.Metric.gutter),
            action.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    /// The real biology sits next to the cost it implies, so the conversion is
    /// visible rather than arbitrary.
    private func makeFactsCard(owned: Int) -> UIView {
        var rows: [(String, String)] = [
            ("Real incubation", "\(species.incubationDays) days"),
            ("Deep work to hatch", species.hatchCostString)
        ]

        // What is already banked toward this specific egg.
        if let egg = incubator.currentEgg, egg.speciesID == species.id {
            let percent = Int((egg.progress * 100).rounded())
            rows.append(("Already invested", "\(egg.secondsAccumulated.compactString) · \(percent)%"))
            rows.append(("Still to go", egg.remainingSeconds.compactString))
        }

        if owned > 0 {
            rows.append(("Hatched", owned == 1 ? "once" : "\(owned) times"))
            if let latest = incubator.collection
                .filter({ $0.speciesID == species.id })
                .max(by: { $0.hatchedAt < $1.hatchedAt }) {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                rows.append(("Most recent", formatter.string(from: latest.hatchedAt)))
            }
        }

        let container = UIView()
        container.backgroundColor = Theme.Color.surface
        container.layer.cornerRadius = Theme.Metric.cornerRadius
        container.layer.cornerCurve = .continuous
        container.translatesAutoresizingMaskIntoConstraints = false

        let rowViews: [UIView] = rows.map { title, value in
            let left = UILabel()
            left.text = title
            left.font = Theme.Font.body
            left.textColor = Theme.Color.textSecondary

            let right = UILabel()
            right.text = value
            right.font = .systemFont(ofSize: 16, weight: .semibold)
            right.textColor = Theme.Color.text
            right.textAlignment = .right

            let row = UIStackView(arrangedSubviews: [left, right])
            row.axis = .horizontal
            row.distribution = .equalSpacing
            return row
        }

        let footnote = UILabel()
        footnote.text = "\(Species.hoursPerIncubationDay) hours of deep work per day of real incubation. Every session counts, finished or not."
        footnote.font = Theme.Font.caption
        footnote.textColor = Theme.Color.textSecondary
        footnote.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: rowViews + [footnote])
        stack.axis = .vertical
        stack.spacing = 10
        stack.setCustomSpacing(16, after: rowViews.last!)
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -18),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18)
        ])
        return container
    }

    @objc private func incubateTapped() {
        onIncubate?(species)
    }
}
