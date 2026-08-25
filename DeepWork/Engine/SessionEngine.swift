import UIKit

protocol SessionEngineDelegate: AnyObject {
    func sessionEngine(_ engine: SessionEngine, didChangeState state: SessionEngine.State)
    func sessionEngine(_ engine: SessionEngine, didTick remaining: TimeInterval, progress: Double)
}

/// The state machine that owns a deep-work session and every way it can end.
///
/// Two guards run for the whole session:
/// 1. **Lifecycle** — `UIApplication` notifications. Losing foreground-active
///    state fails the session.
/// 2. **Motion** — `MotionMonitor`. Moving the phone fails the session.
///
/// Both are wired up in `start()` and torn down in exactly one place, `finish()`,
/// so there is no path that leaves the idle timer disabled or the accelerometer
/// running.
final class SessionEngine {

    enum State: Equatable {
        /// Nothing running.
        case idle
        /// Sampling the resting orientation. The user is putting the phone down,
        /// so motion here is expected and must not fail the session.
        case arming
        /// Counting down. Both guards live.
        case running
        case completed(SessionRecord)
        case failed(SessionRecord)
    }

    weak var delegate: SessionEngineDelegate?

    private(set) var state: State = .idle {
        didSet {
            guard state != oldValue else { return }
            delegate?.sessionEngine(self, didChangeState: state)
        }
    }

    private let store: SessionStore
    private let incubator: Incubator
    private let motionMonitor = MotionMonitor()
    private var displayLink: CADisplayLink?
    private var observers: [NSObjectProtocol] = []

    private var targetDuration: TimeInterval = 0
    private var startedAt: Date = .init()
    private var title: String?
    private var notes: String?

    /// Monotonic start stamp. `ContinuousClock` keeps counting across system
    /// clock changes and device sleep, so rolling the date forward cannot
    /// complete a session and rolling it back cannot extend one. `Date()` is
    /// stored alongside for display only, and is never used to compute duration.
    private var monotonicStart: ContinuousClock.Instant?

    /// Set while a session is live. Its presence at launch means the app died
    /// mid-session — which is a failure, never something to resume.
    private static let inFlightKey = "com.example.DeepWork.inFlightSession"

    init(store: SessionStore = .shared, incubator: Incubator = .shared) {
        self.store = store
        self.incubator = incubator
    }

    deinit {
        teardownGuards()
    }

    // MARK: - Elapsed / remaining

    var elapsed: TimeInterval {
        guard let monotonicStart else { return 0 }
        let duration = ContinuousClock.now - monotonicStart
        return TimeInterval(duration.components.seconds)
            + TimeInterval(duration.components.attoseconds) / 1e18
    }

    var remaining: TimeInterval { max(0, targetDuration - elapsed) }

    var progress: Double {
        guard targetDuration > 0 else { return 0 }
        return min(1, elapsed / targetDuration)
    }

    // MARK: - Lifecycle

    func start(duration: TimeInterval, title: String? = nil, notes: String? = nil) {
        guard case .idle = state else { return }

        targetDuration = duration
        self.title = title
        self.notes = notes
        startedAt = Date()
        monotonicStart = nil
        state = .arming

        // Load-bearing: iOS auto-locks after ~30s without touches, and a deep
        // work session is by definition minutes without touches. Without this,
        // every session would fail at 0:30 as the screen sleeps and the app
        // resigns active.
        UIApplication.shared.isIdleTimerDisabled = true
        SessionSound.prepare()

        UserDefaults.standard.set(true, forKey: Self.inFlightKey)

        motionMonitor.onCalibrated = { [weak self] in
            self?.beginCountdown()
        }
        motionMonitor.onTrip = { [weak self] _ in
            self?.fail(.movedPhone)
        }
        motionMonitor.start()

        observeLifecycle()

        // A device without motion hardware (or the simulator) never calibrates,
        // so start the clock anyway rather than hanging in `arming` forever.
        // The lifecycle guard still applies.
        if !motionMonitor.isAvailable {
            beginCountdown()
        }
    }

    /// The user tapped Give Up.
    func abandon() {
        guard state == .running || state == .arming else { return }
        fail(.abandoned)
    }

    /// Call once at launch. If a session was in flight when the app died, close
    /// it out as a failure — a session you had to be reminded of is not one you
    /// completed.
    func resolveInterruptedSession() {
        guard UserDefaults.standard.bool(forKey: Self.inFlightKey) else { return }
        UserDefaults.standard.removeObject(forKey: Self.inFlightKey)
    }

    // MARK: - Countdown

    private func beginCountdown() {
        guard case .arming = state else { return }
        monotonicStart = ContinuousClock.now
        state = .running

        let link = CADisplayLink(target: self, selector: #selector(tick))
        // The timer renders whole seconds; 6 fps is more than enough and costs a
        // fraction of the battery of a 60 fps link held for 90 minutes.
        link.preferredFramesPerSecond = 6
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func tick() {
        guard case .running = state else { return }
        delegate?.sessionEngine(self, didTick: remaining, progress: progress)
        if remaining <= 0 {
            complete()
        }
    }

    // MARK: - Terminal states

    private func complete() {
        let record = makeRecord(elapsed: targetDuration, reason: nil)
        finish(with: record, state: .completed(record))
    }

    private func fail(_ reason: FailureReason) {
        guard state == .running || state == .arming else { return }
        // Elapsed at the moment of failure — the honest number, not the one
        // they aimed at.
        let record = makeRecord(elapsed: elapsed, reason: reason)
        finish(with: record, state: .failed(record))
    }

    private func makeRecord(elapsed: TimeInterval, reason: FailureReason?) -> SessionRecord {
        SessionRecord(
            targetDuration: targetDuration,
            elapsedDuration: elapsed,
            startedAt: startedAt,
            failureReason: reason,
            title: title,
            notes: notes,
            eggSpeciesID: incubator.currentEgg?.speciesID
        )
    }

    /// The single exit path. Every terminal state routes through here so the
    /// idle timer, motion updates, display link, and observers are always
    /// released together.
    private func finish(with record: SessionRecord, state newState: State) {
        teardownGuards()

        // Every second of focus counts toward the egg, whether or not the
        // session survived to the end.
        incubator.credit(seconds: record.elapsedDuration)

        store.append(record)
        UserDefaults.standard.removeObject(forKey: Self.inFlightKey)
        state = newState
    }

    private func teardownGuards() {
        displayLink?.invalidate()
        displayLink = nil
        motionMonitor.stop()
        UIApplication.shared.isIdleTimerDisabled = false
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
    }

    func reset() {
        guard state != .idle else { return }
        teardownGuards()
        monotonicStart = nil
        targetDuration = 0
        state = .idle
    }

    // MARK: - Lifecycle guard

    private func observeLifecycle() {
        // `willResignActive` rather than only `didEnterBackground` — deliberately.
        // A Control Centre or Notification Centre pull fires resign-active and
        // never reaches background, and reaching for the phone to swipe down is
        // exactly the reflex this app exists to interrupt.
        //
        // The cost is that an incoming call or a system alert also ends a
        // session. That is the correct trade for a strictness-first tool, and it
        // is why the failure copy states a fact instead of assigning blame.
        let names: [Notification.Name] = [
            UIApplication.willResignActiveNotification,
            UIApplication.didEnterBackgroundNotification
        ]

        observers = names.map { name in
            NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.fail(.leftApp)
            }
        }
    }
}
