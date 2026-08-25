import XCTest
@testable import DeepWork

final class SessionStoreTests: XCTestCase {

    private var directory: URL!
    private var calendar: Calendar!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        // Pinned so streak maths does not depend on the machine's locale.
        calendar = {
            var c = Calendar(identifier: .gregorian)
            c.timeZone = TimeZone(secondsFromGMT: 0)!
            return c
        }()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeStore() -> SessionStore {
        SessionStore(directory: directory, calendar: calendar)
    }

    private func daysAgo(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: -days, to: Date())!
    }

    private func record(
        completed: Bool,
        daysAgo days: Int = 0,
        minutes: Int = 50
    ) -> SessionRecord {
        let target = TimeInterval(minutes * 60)
        return SessionRecord(
            targetDuration: target,
            elapsedDuration: completed ? target : target / 2,
            startedAt: daysAgo(days),
            failureReason: completed ? nil : .movedPhone,
            title: "Ship the parser",
            notes: "Finish the tokeniser and get the tests green.",
            eggSpeciesID: "sparrow"
        )
    }

    // MARK: - Round trip

    func testAppendPersistsAcrossInstances() {
        let store = makeStore()
        store.append(record(completed: true))

        let reloaded = makeStore()
        XCTAssertEqual(reloaded.records.count, 1)
        XCTAssertEqual(reloaded.records.first, store.records.first)
    }

    /// Failures are kept deliberately. A record that only stores wins is a
    /// record you stop believing.
    func testFailedSessionsArePersisted() {
        let store = makeStore()
        store.append(record(completed: false))

        let reloaded = makeStore()
        XCTAssertEqual(reloaded.records.count, 1)
        XCTAssertEqual(reloaded.records.first?.failureReason, .movedPhone)
    }

    func testRecordEncodesAndDecodesIdentically() throws {
        let original = record(completed: false)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SessionRecord.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testOptionalTitleAndNotesRoundTrip() {
        let store = makeStore()
        store.append(record(completed: true))

        let reloaded = makeStore()
        XCTAssertEqual(reloaded.records.first?.title, "Ship the parser")
        XCTAssertEqual(reloaded.records.first?.notes, "Finish the tokeniser and get the tests green.")
        XCTAssertEqual(reloaded.records.first?.eggSpeciesID, "sparrow")
    }

    /// Title and notes are optional; a record without them must still decode and
    /// must not show an empty heading in history.
    func testUntitledSessionFallsBackToAStandIn() {
        let bare = SessionRecord(
            targetDuration: 1500, elapsedDuration: 1500,
            startedAt: Date(), failureReason: nil
        )
        XCTAssertNil(bare.title)
        XCTAssertEqual(bare.displayTitle, "Untitled session")
    }

    func testBlankTitleFallsBackToAStandIn() {
        let blank = SessionRecord(
            targetDuration: 1500, elapsedDuration: 1500,
            startedAt: Date(), failureReason: nil, title: "   "
        )
        XCTAssertEqual(blank.displayTitle, "Untitled session")
    }

    // MARK: - Totals

    /// Time inside a broken session was not deep work, so it is not counted.
    func testTotalFocusExcludesFailedSessions() {
        let store = makeStore()
        store.append(record(completed: true, minutes: 50))
        store.append(record(completed: false, minutes: 50))

        XCTAssertEqual(store.totalFocusedSeconds, 3000)
    }

    func testCompletedTodayCountsOnlyToday() {
        let store = makeStore()
        store.append(record(completed: true, daysAgo: 0))
        store.append(record(completed: true, daysAgo: 0))
        store.append(record(completed: true, daysAgo: 3))

        XCTAssertEqual(store.completedToday, 2)
    }

    func testSuccessRate() {
        let store = makeStore()
        store.append(record(completed: true))
        store.append(record(completed: true))
        store.append(record(completed: false))
        store.append(record(completed: false))

        XCTAssertEqual(store.successRate, 0.5, accuracy: 0.0001)
    }

    func testSuccessRateWithNoRecordsIsZero() {
        XCTAssertEqual(makeStore().successRate, 0)
    }

    func testLongestSession() {
        let store = makeStore()
        store.append(record(completed: true, minutes: 25))
        store.append(record(completed: true, minutes: 90))
        store.append(record(completed: false, minutes: 120))

        XCTAssertEqual(store.longestSessionSeconds, 90 * 60)
    }

    // MARK: - Streak

    func testStreakIsZeroWithNoSessions() {
        XCTAssertEqual(makeStore().currentStreak, 0)
    }

    func testStreakCountsConsecutiveDays() {
        let store = makeStore()
        store.append(record(completed: true, daysAgo: 0))
        store.append(record(completed: true, daysAgo: 1))
        store.append(record(completed: true, daysAgo: 2))

        XCTAssertEqual(store.currentStreak, 3)
    }

    func testStreakBreaksOnGap() {
        let store = makeStore()
        store.append(record(completed: true, daysAgo: 0))
        store.append(record(completed: true, daysAgo: 1))
        store.append(record(completed: true, daysAgo: 4))

        XCTAssertEqual(store.currentStreak, 2)
    }

    /// Yesterday anchors the streak so it does not read zero all morning before
    /// the day's first session — that would punish the clock, not the behaviour.
    func testStreakSurvivesUntilEndOfToday() {
        let store = makeStore()
        store.append(record(completed: true, daysAgo: 1))
        store.append(record(completed: true, daysAgo: 2))

        XCTAssertEqual(store.currentStreak, 2)
    }

    func testStreakIsZeroWhenLastSessionIsStale() {
        let store = makeStore()
        store.append(record(completed: true, daysAgo: 3))

        XCTAssertEqual(store.currentStreak, 0)
    }

    /// A day containing only failures is not a day you did deep work.
    func testFailedSessionsDoNotSustainStreak() {
        let store = makeStore()
        store.append(record(completed: false, daysAgo: 0))
        store.append(record(completed: true, daysAgo: 1))
        store.append(record(completed: true, daysAgo: 2))

        // Today has only a failure, so the streak anchors on yesterday.
        XCTAssertEqual(store.currentStreak, 2)
    }

    func testMultipleSessionsSameDayCountAsOneStreakDay() {
        let store = makeStore()
        store.append(record(completed: true, daysAgo: 0))
        store.append(record(completed: true, daysAgo: 0))
        store.append(record(completed: true, daysAgo: 1))

        XCTAssertEqual(store.currentStreak, 2)
    }
}
