import UIKit

/// Every session ever started, newest first — completed and broken alike.
///
/// Failures stay in the list on purpose. A history that only shows wins is one
/// you stop believing, and the point of the app is an honest record.
final class HistoryViewController: UIViewController {

    private let store: SessionStore
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var sections: [(title: String, records: [SessionRecord])] = []

    private let emptyLabel = UILabel()

    init(store: SessionStore = .shared) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "History"
        view.backgroundColor = Theme.Color.background
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationItem.largeTitleDisplayMode = .never

        buildLayout()
        reload()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    private func buildLayout() {
        tableView.backgroundColor = Theme.Color.background
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(SessionCell.self, forCellReuseIdentifier: SessionCell.reuseID)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        emptyLabel.text = "No sessions yet.\nYour first block will show up here."
        emptyLabel.font = Theme.Font.body
        emptyLabel.textColor = Theme.Color.textSecondary
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
    }

    /// Group by calendar day, newest day first, newest session first inside each.
    private func reload() {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: store.records) {
            calendar.startOfDay(for: $0.startedAt)
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none

        sections = grouped.keys.sorted(by: >).map { day in
            let label: String
            if calendar.isDateInToday(day) {
                label = "Today"
            } else if calendar.isDateInYesterday(day) {
                label = "Yesterday"
            } else {
                label = formatter.string(from: day)
            }
            let records = (grouped[day] ?? []).sorted { $0.startedAt > $1.startedAt }
            return (label, records)
        }

        emptyLabel.isHidden = !store.records.isEmpty
        tableView.isHidden = store.records.isEmpty
        tableView.reloadData()
    }
}

// MARK: - Table

extension HistoryViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].records.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: SessionCell.reuseID, for: indexPath
        ) as! SessionCell
        cell.configure(with: sections[indexPath.section].records[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = Theme.Color.background

        let label = UILabel()
        label.text = sections[section].title
        label.font = Theme.Font.caption
        label.textColor = Theme.Color.textSecondary

        let total = sections[section].records.reduce(0) { $0 + $1.elapsedDuration }
        let detail = UILabel()
        detail.text = total.compactString
        detail.font = Theme.Font.caption
        detail.textColor = Theme.Color.textSecondary

        let stack = UIStackView(arrangedSubviews: [label, UIView(), detail])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: Theme.Metric.gutter),
            stack.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -Theme.Metric.gutter),
            stack.centerYAnchor.constraint(equalTo: header.centerYAnchor)
        ])
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 36 }
}

// MARK: - Cell

private final class SessionCell: UITableViewCell {

    static let reuseID = "SessionCell"

    private let card = UIView()
    private let statusBar = UIView()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let notesLabel = UILabel()
    private let durationLabel = UILabel()
    private let timeLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = Theme.Metric.cornerRadius
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)

        // A colour stripe down the left edge reads the outcome at a glance
        // without needing a word for it.
        statusBar.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(statusBar)

        // Full text, wrapped. A history entry that truncates its own title is
        // not a record of anything — the cell grows instead.
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = Theme.Color.text
        titleLabel.numberOfLines = 0
        titleLabel.lineBreakMode = .byWordWrapping

        detailLabel.font = Theme.Font.caption
        detailLabel.numberOfLines = 0
        detailLabel.lineBreakMode = .byWordWrapping

        notesLabel.font = Theme.Font.caption
        notesLabel.textColor = Theme.Color.textSecondary
        notesLabel.numberOfLines = 0
        notesLabel.lineBreakMode = .byWordWrapping

        durationLabel.font = .monospacedDigitSystemFont(ofSize: 17, weight: .semibold)
        durationLabel.textColor = Theme.Color.text
        durationLabel.textAlignment = .right

        timeLabel.font = Theme.Font.caption
        timeLabel.textColor = Theme.Color.textSecondary
        timeLabel.textAlignment = .right

        // The right column never yields: a truncated clock time ("5:5…") is
        // useless, and it is the one thing here with a known maximum width.
        for label in [durationLabel, timeLabel] {
            label.setContentHuggingPriority(.required, for: .horizontal)
            label.setContentCompressionResistancePriority(.required, for: .horizontal)
        }

        // The text column yields instead, and wraps into whatever is left.
        for label in [titleLabel, detailLabel, notesLabel] {
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        }

        let rightStack = UIStackView(arrangedSubviews: [durationLabel, timeLabel])
        rightStack.axis = .vertical
        rightStack.alignment = .trailing
        rightStack.spacing = 2
        rightStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(rightStack)

        let leftStack = UIStackView(arrangedSubviews: [titleLabel, detailLabel, notesLabel])
        leftStack.axis = .vertical
        leftStack.alignment = .leading
        leftStack.spacing = 3
        leftStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(leftStack)

        // Explicit constraints rather than a horizontal stack: the text column's
        // width has to be pinned before the labels can decide where to wrap, and
        // stack-view arbitration was resolving that ambiguity by starving the
        // text instead of the clock.
        let cardBottom = card.bottomAnchor.constraint(
            greaterThanOrEqualTo: rightStack.bottomAnchor, constant: 14
        )
        cardBottom.priority = .defaultHigh

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Metric.gutter),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Metric.gutter),

            statusBar.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            statusBar.topAnchor.constraint(equalTo: card.topAnchor),
            statusBar.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            statusBar.widthAnchor.constraint(equalToConstant: 4),

            rightStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            rightStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            cardBottom,

            leftStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            leftStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            leftStack.leadingAnchor.constraint(equalTo: statusBar.trailingAnchor, constant: 14),
            leftStack.trailingAnchor.constraint(equalTo: rightStack.leadingAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        notesLabel.isHidden = false
    }

    func configure(with record: SessionRecord) {
        titleLabel.text = record.displayTitle

        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        timeLabel.text = formatter.string(from: record.startedAt)

        durationLabel.text = record.elapsedDuration.compactString

        var parts: [String] = []
        if let reason = record.failureReason {
            parts.append(reason.headline)
            statusBar.backgroundColor = Theme.Color.error
            detailLabel.textColor = Theme.Color.error
        } else {
            parts.append("Completed")
            statusBar.backgroundColor = Theme.Color.success
            detailLabel.textColor = Theme.Color.success
        }
        parts.append("of \(record.targetDuration.compactString) target")

        if let speciesID = record.eggSpeciesID,
           let species = SpeciesCatalog.species(withID: speciesID) {
            parts.append("→ \(species.name)")
        }
        detailLabel.text = parts.joined(separator: " · ")

        let trimmed = record.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        notesLabel.text = trimmed
        notesLabel.isHidden = (trimmed?.isEmpty ?? true)
    }
}
