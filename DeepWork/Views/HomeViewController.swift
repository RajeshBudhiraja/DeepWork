import UIKit

/// Duration picker, current egg, and the stats that hold you accountable.
final class HomeViewController: UIViewController {

    private let incubator = Incubator.shared
    private let store = SessionStore.shared

    private var selectedDuration: DeepWorkDuration = .block
    private var tiles: [DurationTile] = []

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let eggCard = EggCard()
    private let startButton = PrimaryButton(title: "Start Deep Work")
    private let titleField = UITextField()
    private let notesField = UITextView()
    private let notesPlaceholder = UILabel()

    private let streakTile = StatTile(caption: "Day streak")
    private let todayTile = StatTile(caption: "Today")
    private let focusTile = StatTile(caption: "Total focus")
    private let collectionTile = StatTile(caption: "Collected")

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.background
        buildLayout()
        observeKeyboard()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }

    /// Inset the scroll view by the keyboard's height and scroll the focused
    /// field into view. Without this the keyboard covers the title and
    /// description fields entirely — they sit near the bottom of the page.
    private func observeKeyboard() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChange(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc private func keyboardWillChange(_ note: Notification) {
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else { return }

        let keyboardTop = view.convert(frame, from: nil).minY
        let overlap = max(0, view.bounds.maxY - keyboardTop)

        scrollView.contentInset.bottom = overlap
        scrollView.verticalScrollIndicatorInsets.bottom = overlap

        scrollFocusedFieldAboveKeyboard(overlap: overlap)
    }

    /// Scroll so the field being edited clears the keyboard.
    ///
    /// The offset is computed explicitly rather than left to
    /// `scrollRectToVisible`, which measures against the scroll view's bounds and
    /// so treats a field sitting under the keyboard as already visible.
    fileprivate func scrollFocusedFieldAboveKeyboard(overlap: CGFloat) {
        let focused: UIView? = titleField.isFirstResponder ? titleField
            : (notesField.isFirstResponder ? notesField : nil)
        guard let focused, overlap > 0 else { return }

        view.layoutIfNeeded()

        let fieldFrame = focused.convert(focused.bounds, to: scrollView)
        let visibleHeight = scrollView.bounds.height - overlap
        let padding: CGFloat = 20
        let desiredOffsetY = fieldFrame.maxY + padding - visibleHeight

        guard desiredOffsetY > scrollView.contentOffset.y else { return }
        scrollView.setContentOffset(CGPoint(x: 0, y: desiredOffsetY), animated: true)
    }

    @objc private func keyboardWillHide() {
        scrollView.contentInset.bottom = 0
        scrollView.verticalScrollIndicatorInsets.bottom = 0
    }

    // MARK: - Layout

    private func buildLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 22
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -40),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: Theme.Metric.gutter),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -Theme.Metric.gutter)
        ])

        contentStack.addArrangedSubview(makeHeader())
        contentStack.addArrangedSubview(makeStatsRow())
        contentStack.addArrangedSubview(makeSectionLabel("Your egg"))
        contentStack.addArrangedSubview(eggCard)
        contentStack.addArrangedSubview(makeSectionLabel("How long"))
        contentStack.addArrangedSubview(makeDurationGrid())
        contentStack.addArrangedSubview(makeSectionLabel("What are you working on (optional)"))
        contentStack.addArrangedSubview(makeNotesCard())
        contentStack.addArrangedSubview(makeRulesCard())
        contentStack.addArrangedSubview(startButton)

        contentStack.setCustomSpacing(10, after: contentStack.arrangedSubviews[2])
        contentStack.setCustomSpacing(10, after: contentStack.arrangedSubviews[4])
        contentStack.setCustomSpacing(10, after: contentStack.arrangedSubviews[6])

        eggCard.addTarget(self, action: #selector(openCollection), for: .touchUpInside)
        startButton.addTarget(self, action: #selector(startTapped), for: .touchUpInside)

        // Tapping away from the fields should dismiss the keyboard.
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    private func makeHeader() -> UIView {
        let title = UILabel()
        title.text = "DeepWork"
        title.font = Theme.Font.largeTitle
        title.textColor = Theme.Color.text

        let subtitle = UILabel()
        subtitle.text = "Put the phone down. Don't touch it."
        subtitle.font = Theme.Font.body
        subtitle.textColor = Theme.Color.textSecondary

        let historyButton = QuietButton(title: "History")
        historyButton.addTarget(self, action: #selector(openHistory), for: .touchUpInside)
        historyButton.setContentHuggingPriority(.required, for: .horizontal)

        let collectionButton = QuietButton(title: "Collection")
        collectionButton.addTarget(self, action: #selector(openCollection), for: .touchUpInside)
        collectionButton.setContentHuggingPriority(.required, for: .horizontal)

        let titleRow = UIStackView(arrangedSubviews: [title, historyButton, collectionButton])
        titleRow.axis = .horizontal
        titleRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [titleRow, subtitle])
        stack.axis = .vertical
        stack.spacing = 4
        return stack
    }

    private func makeStatsRow() -> UIView {
        let stack = UIStackView(arrangedSubviews: [streakTile, todayTile, focusTile, collectionTile])
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 8

        let container = UIView()
        container.backgroundColor = Theme.Color.surface
        container.layer.cornerRadius = Theme.Metric.cornerRadius
        container.layer.cornerCurve = .continuous
        container.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12)
        ])
        return container
    }

    private func makeSectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text.uppercased()
        label.font = Theme.Font.caption
        label.textColor = Theme.Color.textSecondary
        return label
    }

    private func makeDurationGrid() -> UIView {
        tiles = DeepWorkDuration.allCases.map { duration in
            let tile = DurationTile(duration: duration)
            tile.isSelected = duration == selectedDuration
            tile.addTarget(self, action: #selector(durationTapped(_:)), for: .touchUpInside)
            return tile
        }

        let stack = UIStackView(arrangedSubviews: tiles)
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 10
        return stack
    }

    /// The rules are stated up front, before the session starts. Someone who is
    /// surprised by the failure condition will feel cheated; someone who agreed
    /// to it in advance will not.
    private func makeRulesCard() -> UIView {
        let container = UIView()
        container.backgroundColor = Theme.Color.surface
        container.layer.cornerRadius = Theme.Metric.cornerRadius
        container.layer.cornerCurve = .continuous

        let heading = UILabel()
        heading.text = "The session ends if you"
        heading.font = Theme.Font.caption
        heading.textColor = Theme.Color.textSecondary

        let rules = ["Switch to another app", "Pick up or move the phone"]
        let ruleLabels: [UIView] = rules.map { text in
            let dot = UIView()
            dot.backgroundColor = Theme.Color.warning
            dot.layer.cornerRadius = 3
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: 6).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 6).isActive = true

            let label = UILabel()
            label.text = text
            label.font = Theme.Font.body
            label.textColor = Theme.Color.text
            label.numberOfLines = 0

            let row = UIStackView(arrangedSubviews: [dot, label])
            row.axis = .horizontal
            row.spacing = 10
            row.alignment = .center
            return row
        }

        let stack = UIStackView(arrangedSubviews: [heading] + ruleLabels)
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18)
        ])
        return container
    }

    /// Optional context for the session. Never required — the app must never
    /// stand between you and starting.
    private func makeNotesCard() -> UIView {
        let container = UIView()
        container.backgroundColor = Theme.Color.surface
        container.layer.cornerRadius = Theme.Metric.cornerRadius
        container.layer.cornerCurve = .continuous

        titleField.placeholder = "Title"
        titleField.font = Theme.Font.body
        titleField.textColor = Theme.Color.text
        titleField.returnKeyType = .next
        titleField.delegate = self
        titleField.attributedPlaceholder = NSAttributedString(
            string: "Title",
            attributes: [.foregroundColor: Theme.Color.textSecondary]
        )

        let divider = UIView()
        divider.backgroundColor = Theme.Color.border.withAlphaComponent(Theme.State.subtle)
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true

        notesField.font = Theme.Font.body
        notesField.textColor = Theme.Color.text
        notesField.backgroundColor = .clear
        notesField.textContainerInset = .zero
        notesField.textContainer.lineFragmentPadding = 0
        notesField.isScrollEnabled = false
        notesField.delegate = self
        notesField.translatesAutoresizingMaskIntoConstraints = false
        notesField.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true

        notesPlaceholder.text = "Description"
        notesPlaceholder.font = Theme.Font.body
        notesPlaceholder.textColor = Theme.Color.textSecondary
        notesPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        notesField.addSubview(notesPlaceholder)

        let stack = UIStackView(arrangedSubviews: [titleField, divider, notesField])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),

            notesPlaceholder.topAnchor.constraint(equalTo: notesField.topAnchor),
            notesPlaceholder.leadingAnchor.constraint(equalTo: notesField.leadingAnchor)
        ])
        return container
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func openHistory() {
        navigationController?.pushViewController(HistoryViewController(), animated: true)
    }

    // MARK: - State

    private func refresh() {
        eggCard.setEgg(incubator.currentEgg)

        streakTile.setValue("\(store.currentStreak)")
        todayTile.setValue("\(store.completedToday)")
        focusTile.setValue(store.totalFocusedSeconds.compactString)
        collectionTile.setValue("\(incubator.hatchedSpeciesIDs.count)/\(SpeciesCatalog.all.count)")

        let hasEgg = incubator.currentEgg != nil
        startButton.isEnabled = hasEgg
        startButton.configuration?.attributedTitle = AttributedString(
            hasEgg ? "Start Deep Work" : "Choose an egg first",
            attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: 17, weight: .semibold)])
        )
    }

    // MARK: - Actions

    @objc private func durationTapped(_ sender: DurationTile) {
        selectedDuration = sender.duration
        tiles.forEach { $0.isSelected = $0.duration == selectedDuration }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    @objc private func openCollection() {
        navigationController?.pushViewController(CollectionViewController(), animated: true)
    }

    @objc private func startTapped() {
        guard incubator.currentEgg != nil else {
            openCollection()
            return
        }
        view.endEditing(true)
        let trimmedTitle = titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notesField.text?.trimmingCharacters(in: .whitespacesAndNewlines)

        let session = SessionViewController(
            duration: selectedDuration.seconds,
            title: (trimmedTitle?.isEmpty ?? true) ? nil : trimmedTitle,
            notes: (trimmedNotes?.isEmpty ?? true) ? nil : trimmedNotes
        )
        session.modalPresentationStyle = .fullScreen
        present(session, animated: true)
    }
}

// MARK: - Text input

extension HomeViewController: UITextFieldDelegate, UITextViewDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        notesField.becomeFirstResponder()
        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        nudgeFocusedFieldIntoView()
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        nudgeFocusedFieldIntoView()
    }

    /// Moving between fields does not re-fire the keyboard-frame notification,
    /// so re-run the scroll against the inset already in place.
    private func nudgeFocusedFieldIntoView() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.scrollFocusedFieldAboveKeyboard(overlap: self.scrollView.contentInset.bottom)
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        notesPlaceholder.isHidden = !textView.text.isEmpty
    }
}
