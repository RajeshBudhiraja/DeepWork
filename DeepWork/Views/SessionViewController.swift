import UIKit

/// The live session. Deliberately almost empty: one number, one ring, one way
/// out. Anything else on this screen is something to look at, and looking at the
/// phone is the behaviour being trained away.
final class SessionViewController: UIViewController, SessionEngineDelegate {

    private let engine = SessionEngine()
    private let duration: TimeInterval
    private let sessionTitle: String?
    private let sessionNotes: String?

    private let ring = RingView()
    private let timeLabel = UILabel()
    private let statusLabel = UILabel()
    private let hintLabel = UILabel()
    private let giveUpButton = QuietButton(title: "Give up")

    init(duration: TimeInterval, title: String? = nil, notes: String? = nil) {
        self.duration = duration
        self.sessionTitle = title
        self.sessionNotes = notes
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.background
        buildLayout()

        engine.delegate = self
        engine.start(duration: duration, title: sessionTitle, notes: sessionNotes)
    }

    /// The whole point is that the phone is face-down on a desk. Keeping the
    /// orientation fixed avoids a rotation animation firing the instant it is
    /// set down.
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }

    override var prefersStatusBarHidden: Bool { true }

    // MARK: - Layout

    private func buildLayout() {
        ring.translatesAutoresizingMaskIntoConstraints = false
        ring.lineWidth = 3
        view.addSubview(ring)

        timeLabel.font = Theme.Font.timer(72)
        timeLabel.textColor = Theme.Color.text
        timeLabel.textAlignment = .center
        timeLabel.text = duration.clockString
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(timeLabel)

        statusLabel.font = Theme.Font.caption
        statusLabel.textColor = Theme.Color.textSecondary
        statusLabel.textAlignment = .center
        statusLabel.text = "CALIBRATING"
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        hintLabel.font = Theme.Font.body
        hintLabel.textColor = Theme.Color.textSecondary
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 0
        hintLabel.text = sessionTitle ?? "Set the phone down and hold still."
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hintLabel)

        giveUpButton.addTarget(self, action: #selector(giveUpTapped), for: .touchUpInside)
        view.addSubview(giveUpButton)

        NSLayoutConstraint.activate([
            ring.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            ring.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
            ring.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.72),
            ring.heightAnchor.constraint(equalTo: ring.widthAnchor),

            timeLabel.centerXAnchor.constraint(equalTo: ring.centerXAnchor),
            timeLabel.centerYAnchor.constraint(equalTo: ring.centerYAnchor),

            statusLabel.centerXAnchor.constraint(equalTo: ring.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: timeLabel.bottomAnchor, constant: 6),

            hintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hintLabel.topAnchor.constraint(equalTo: ring.bottomAnchor, constant: 36),
            hintLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 48),
            hintLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -48),

            giveUpButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            giveUpButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }

    // MARK: - SessionEngineDelegate

    func sessionEngine(_ engine: SessionEngine, didTick remaining: TimeInterval, progress: Double) {
        timeLabel.text = remaining.clockString
        ring.setProgress(progress, animated: false)
    }

    func sessionEngine(_ engine: SessionEngine, didChangeState state: SessionEngine.State) {
        switch state {
        case .idle, .arming:
            break

        case .running:
            statusLabel.text = "WATCHING"
            hintLabel.text = "Leave it where it is."
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        case .completed(let record):
            SessionSound.playCompleted()
            presentResult(for: record)

        case .failed(let record):
            SessionSound.playFailed()
            ring.progressColor = Theme.Color.error
            presentResult(for: record)
        }
    }

    private func presentResult(for record: SessionRecord) {
        let hatched = Incubator.shared.consumePendingHatch()
        let result = ResultViewController(record: record, hatched: hatched)
        result.onDismiss = { [weak self] in
            self?.dismiss(animated: true)
        }
        result.modalPresentationStyle = .fullScreen

        // The give-up alert may still be on screen; presenting on top of it
        // would silently fail. Dismiss it first, then present.
        if let presented = presentedViewController {
            presented.dismiss(animated: false) { [weak self] in
                self?.present(result, animated: true)
            }
        } else {
            present(result, animated: true)
        }
    }

    // MARK: - Actions

    @objc private func giveUpTapped() {
        let alert = UIAlertController(
            title: "End the session?",
            message: "It goes down as a failure, but the time you have already put in still counts toward your egg.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Keep going", style: .cancel))
        alert.addAction(UIAlertAction(title: "End it", style: .destructive) { [weak self] _ in
            self?.engine.abandon()
        })
        present(alert, animated: true)
    }
}
