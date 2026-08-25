import Foundation

/// Why a session ended early.
///
/// Raw values are persisted, so they must not change once shipped.
nonisolated enum FailureReason: String, Codable, Equatable, Sendable {
    /// The app lost foreground-active state: home swipe, app switcher, Control
    /// Centre, Notification Centre, screen lock, or an incoming call.
    case leftApp
    /// The phone was tilted, slid, or picked up.
    case movedPhone
    /// The user tapped Give Up. Honest, and recorded like any other failure.
    case abandoned

    /// User-facing headline. Reports the fact, never scolds — a tool that
    /// moralises gets deleted; one that keeps an honest record gets trusted.
    var headline: String {
        switch self {
        case .leftApp:    return "You left the app"
        case .movedPhone: return "You moved your phone"
        case .abandoned:  return "You ended it early"
        }
    }

    var detail: String {
        switch self {
        case .leftApp:    return "The session ends when DeepWork stops being the app in front of you."
        case .movedPhone: return "The session ends when the phone moves from where you set it down."
        case .abandoned:  return "Stopped by hand before the timer ran out."
        }
    }
}

/// One finished session — completed or failed. Both are kept: a record that
/// only stores wins is a record you stop believing.
nonisolated struct SessionRecord: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    /// What the user committed to, in seconds.
    let targetDuration: TimeInterval
    /// What they actually got, in seconds. Equals `targetDuration` on success.
    let elapsedDuration: TimeInterval
    /// Wall-clock timestamp — display and streak grouping only, never duration.
    let startedAt: Date
    /// `nil` means the session ran clean to the end.
    let failureReason: FailureReason?
    /// What you sat down to do. Optional — the app never blocks on it.
    let title: String?
    /// Longer note about the session. Optional.
    let notes: String?
    /// Species incubating at the time, so history reads correctly even after you
    /// switch eggs.
    let eggSpeciesID: String?

    var didComplete: Bool { failureReason == nil }

    /// Title if one was given, otherwise a neutral stand-in.
    var displayTitle: String {
        if let title, !title.trimmingCharacters(in: .whitespaces).isEmpty { return title }
        return "Untitled session"
    }

    init(
        id: UUID = UUID(),
        targetDuration: TimeInterval,
        elapsedDuration: TimeInterval,
        startedAt: Date,
        failureReason: FailureReason?,
        title: String? = nil,
        notes: String? = nil,
        eggSpeciesID: String? = nil
    ) {
        self.id = id
        self.targetDuration = targetDuration
        self.elapsedDuration = elapsedDuration
        // Whole-second resolution. `Date` carries sub-microsecond precision that
        // does not survive a JSON round-trip as a Double, so a record would not
        // compare equal to itself after a save/load. Sub-second precision on a
        // session start stamp is meaningless anyway.
        self.startedAt = Date(timeIntervalSince1970: startedAt.timeIntervalSince1970.rounded())
        self.failureReason = failureReason
        self.title = title
        self.notes = notes
        self.eggSpeciesID = eggSpeciesID
    }
}

/// The durations offered on the home screen.
nonisolated enum DeepWorkDuration: Int, CaseIterable, Identifiable, Sendable {
    case sprint = 15
    case pomodoro = 25
    case block = 50
    case deep = 90

    var id: Int { rawValue }
    var minutes: Int { rawValue }
    var seconds: TimeInterval { TimeInterval(rawValue * 60) }

    var title: String { "\(rawValue)" }

    var subtitle: String {
        switch self {
        case .sprint:   return "Sprint"
        case .pomodoro: return "Pomodoro"
        case .block:    return "Block"
        case .deep:     return "Deep"
        }
    }
}
