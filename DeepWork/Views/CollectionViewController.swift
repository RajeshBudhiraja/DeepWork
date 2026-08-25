import UIKit

/// The collection: every species, sectioned by family, showing what has hatched
/// and what has not. Tapping an un-hatched species starts incubating it.
///
/// Locked species are shown rather than hidden — the point of a collection is
/// knowing what you do not have yet.
final class CollectionViewController: UIViewController {

    private let incubator = Incubator.shared
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Family, Species>!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Collection"
        view.backgroundColor = Theme.Color.background
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationItem.largeTitleDisplayMode = .never

        configureCollectionView()
        configureDataSource()
        applySnapshot()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    // MARK: - Layout

    private func configureCollectionView() {
        let layout = UICollectionViewCompositionalLayout { _, environment in
            let item = NSCollectionLayoutItem(
                layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0 / 3.0),
                    heightDimension: .fractionalHeight(1.0)
                )
            )
            item.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)

            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(178)
                ),
                subitems: [item]
            )

            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(
                top: 8, leading: Theme.Metric.gutter - 5,
                bottom: 20, trailing: Theme.Metric.gutter - 5
            )
            section.boundarySupplementaryItems = [
                NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1.0),
                        heightDimension: .absolute(38)
                    ),
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top
                )
            ]
            _ = environment
            return section
        }

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = Theme.Color.background
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func configureDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<SpeciesCell, Species> { [weak self] cell, _, species in
            guard let self else { return }
            let isIncubating = self.incubator.currentEgg?.speciesID == species.id
            var label = "Incubating"
            if isIncubating, let egg = self.incubator.currentEgg {
                label = "\(Int((egg.progress * 100).rounded()))% · \(egg.secondsAccumulated.compactString)"
            }
            cell.configure(
                species: species,
                hatchedCount: self.incubator.hatchedCount(of: species.id),
                isIncubating: isIncubating,
                incubatingLabel: label
            )
        }

        let headerRegistration = UICollectionView.SupplementaryRegistration<SectionHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] header, _, indexPath in
            guard let self, let family = self.dataSource.sectionIdentifier(for: indexPath.section) else { return }
            let owned = self.incubator.creatures(in: family).map(\.speciesID)
            header.configure(
                title: family.title,
                detail: "\(Set(owned).count)/\(SpeciesCatalog.members(of: family).count)"
            )
        }

        dataSource = UICollectionViewDiffableDataSource<Family, Species>(
            collectionView: collectionView
        ) { collectionView, indexPath, species in
            collectionView.dequeueConfiguredReusableCell(
                using: cellRegistration, for: indexPath, item: species
            )
        }

        dataSource.supplementaryViewProvider = { collectionView, _, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(
                using: headerRegistration, for: indexPath
            )
        }
    }

    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Family, Species>()
        for family in Family.allCases {
            snapshot.appendSections([family])
            snapshot.appendItems(SpeciesCatalog.members(of: family), toSection: family)
        }
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - Selection

extension CollectionViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let species = dataSource.itemIdentifier(for: indexPath) else { return }

        // The card shows the creature at full size plus its real incubation
        // period; incubating is a deliberate action taken from there.
        let detail = CreatureDetailViewController(species: species)
        detail.onIncubate = { [weak self] chosen in
            self?.dismiss(animated: true) {
                self?.requestIncubation(of: chosen)
            }
        }
        detail.modalPresentationStyle = .pageSheet
        if let sheet = detail.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(detail, animated: true)
    }

    private func requestIncubation(of species: Species) {
        guard incubator.currentEgg?.speciesID != species.id else { return }

        // Switching eggs discards the current egg's accumulated focus, so it is
        // confirmed rather than done silently.
        if let existing = incubator.currentEgg,
           let existingSpecies = existing.species,
           existing.secondsAccumulated > 0 {
            let alert = UIAlertController(
                title: "Swap eggs?",
                message: "Your \(existingSpecies.name) egg has \(existing.secondsAccumulated.compactString) in it. Starting a \(species.name) egg discards that progress.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Keep \(existingSpecies.name)", style: .cancel))
            alert.addAction(UIAlertAction(title: "Swap", style: .destructive) { [weak self] _ in
                self?.beginIncubating(species)
            })
            present(alert, animated: true)
            return
        }

        beginIncubating(species)
    }

    private func beginIncubating(_ species: Species) {
        incubator.startEgg(species)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        applySnapshot()
        collectionView.reloadData()
    }
}

// MARK: - Cell

private final class SpeciesCell: UICollectionViewCell {

    private let glyphLabel = UILabel()
    private let nameLabel = UILabel()
    private let costLabel = UILabel()
    private let badgeLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = Theme.Color.surface
        contentView.layer.cornerRadius = Theme.Metric.cornerRadius
        contentView.layer.cornerCurve = .continuous
        contentView.layer.borderWidth = 1

        glyphLabel.font = .systemFont(ofSize: 40)
        glyphLabel.textAlignment = .center

        nameLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        nameLabel.textColor = Theme.Color.text
        nameLabel.textAlignment = .center
        // Full species names, wrapped rather than truncated — "Peregrine Fa…"
        // tells you nothing.
        nameLabel.numberOfLines = 2
        nameLabel.lineBreakMode = .byWordWrapping
        nameLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        costLabel.font = Theme.Font.caption
        costLabel.textColor = Theme.Color.textSecondary
        costLabel.textAlignment = .center

        badgeLabel.font = .systemFont(ofSize: 11, weight: .bold)
        badgeLabel.textAlignment = .center
        badgeLabel.layer.cornerRadius = 8
        badgeLabel.layer.masksToBounds = true
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [glyphLabel, nameLabel, costLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 3
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        contentView.addSubview(badgeLabel)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),

            badgeLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            badgeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            badgeLabel.heightAnchor.constraint(equalToConstant: 16),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 22)
        ])

        // CGColor does not re-resolve on a theme change; re-apply the border.
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (cell: SpeciesCell, _) in
            cell.contentView.layer.borderColor = cell.currentBorderToken
                .resolvedColor(with: cell.traitCollection).cgColor
        }
    }

    private var currentBorderToken: UIColor = Theme.Color.border

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(
        species: Species,
        hatchedCount: Int,
        isIncubating: Bool,
        incubatingLabel: String = "Incubating"
    ) {
        let isOwned = hatchedCount > 0

        glyphLabel.text = isOwned ? species.glyph : "🥚"
        // Un-hatched species are dimmed by opacity, not by a different colour —
        // the design rules permit varying a token's alpha and nothing else.
        glyphLabel.alpha = isOwned ? 1.0 : Theme.State.disabled

        nameLabel.text = species.name
        nameLabel.alpha = isOwned ? 1.0 : Theme.State.disabled

        costLabel.text = isIncubating ? incubatingLabel : species.hatchCostString
        costLabel.textColor = isIncubating ? Theme.Color.primary : Theme.Color.textSecondary

        currentBorderToken = isIncubating ? Theme.Color.primary : Theme.Color.border
        contentView.layer.borderColor = currentBorderToken
            .resolvedColor(with: traitCollection).cgColor

        if hatchedCount > 1 {
            badgeLabel.isHidden = false
            badgeLabel.text = " ×\(hatchedCount) "
            badgeLabel.backgroundColor = Theme.Color.accent
            badgeLabel.textColor = Theme.Color.onFilled
        } else {
            badgeLabel.isHidden = true
        }
    }

}

// MARK: - Section header

private final class SectionHeaderView: UICollectionReusableView {

    private let titleLabel = UILabel()
    private let detailLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        titleLabel.font = Theme.Font.heading
        titleLabel.textColor = Theme.Color.text

        detailLabel.font = Theme.Font.caption
        detailLabel.textColor = Theme.Color.textSecondary

        let stack = UIStackView(arrangedSubviews: [titleLabel, UIView(), detailLabel])
        stack.axis = .horizontal
        stack.alignment = .firstBaseline
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Theme.Metric.gutter),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Theme.Metric.gutter),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, detail: String) {
        titleLabel.text = title
        detailLabel.text = detail
    }
}
