import Foundation

/// Local JSON persistence plus the stats derived from it.
///
/// A file rather than `UserDefaults`: this is a growing append-only log, and
/// `UserDefaults` is the wrong shape for that. A file is also trivially
/// injectable, which is what makes the stats testable.
nonisolated final class SessionStore: @unchecked Sendable {

    /// Shared instance. Touched only from the main thread in app code; tests
    /// build their own instances against a temp directory.
    nonisolated(unsafe) static let shared = SessionStore()

    private let fileURL: URL
    private let calendar: Calendar
    private(set) var records: [SessionRecord] = []

    /// - Parameters:
    ///   - directory: defaults to Application Support. Tests pass a temp dir.
    ///   - calendar: injectable so streak tests are not at the mercy of the
    ///     machine's locale or time zone.
    init(
        directory: URL? = nil,
        calendar: Calendar = .current
    ) {
        let base = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]

        try? FileManager.default.createDirectory(
            at: base,
            withIntermediateDirectories: true
        )

        self.fileURL = base.appendingPathComponent("sessions.json")
        self.calendar = calendar
        load()
    }

    // MARK: - Persistence

    func append(_ record: SessionRecord) {
        records.append(record)
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        records = (try? decoder.decode([SessionRecord].self, from: data)) ?? []
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Stats

    var completedSessions: [SessionRecord] { records.filter(\.didComplete) }

    /// Total focused time, counting only sessions that finished. Time inside a
    /// broken session was not deep work, so it does not count.
    var totalFocusedSeconds: TimeInterval {
        completedSessions.reduce(0) { $0 + $1.elapsedDuration }
    }

    var completedToday: Int {
        completedSessions.filter { calendar.isDateInToday($0.startedAt) }.count
    }

    /// Success rate across every session ever started, 0...1.
    var successRate: Double {
        guard !records.isEmpty else { return 0 }
        return Double(completedSessions.count) / Double(records.count)
    }

    var longestSessionSeconds: TimeInterval {
        completedSessions.map(\.elapsedDuration).max() ?? 0
    }

    /// Consecutive days ending today or yesterday that contain at least one
    /// completed session.
    ///
    /// Yesterday is allowed as an anchor so the streak does not read zero all
    /// morning before the day's first session — that would punish the user for
    /// the clock rather than for their behaviour.
    var currentStreak: Int {
        let days = Set(completedSessions.map { calendar.startOfDay(for: $0.startedAt) })
        guard !days.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: Date())
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }

        var cursor: Date
        if days.contains(today) {
            cursor = today
        } else if days.contains(yesterday) {
            cursor = yesterday
        } else {
            return 0
        }

        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }
}
