import Foundation

/// A creature the user has hatched.
nonisolated struct HatchedCreature: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let speciesID: String
    /// Wall-clock stamp for display only.
    let hatchedAt: Date
    /// Deep work seconds that went into this specific egg.
    let secondsInvested: TimeInterval

    var species: Species? { SpeciesCatalog.species(withID: speciesID) }

    init(
        id: UUID = UUID(),
        speciesID: String,
        hatchedAt: Date = Date(),
        secondsInvested: TimeInterval
    ) {
        self.id = id
        self.speciesID = speciesID
        // Whole seconds, so the record round-trips through JSON exactly.
        self.hatchedAt = Date(timeIntervalSince1970: hatchedAt.timeIntervalSince1970.rounded())
        self.secondsInvested = secondsInvested
    }
}

/// The egg currently being incubated.
nonisolated struct Egg: Codable, Equatable, Sendable {
    let speciesID: String
    /// Completed deep work seconds credited so far.
    var secondsAccumulated: TimeInterval
    let startedAt: Date

    var species: Species? { SpeciesCatalog.species(withID: speciesID) }

    var requiredSeconds: TimeInterval { species?.hatchSeconds ?? 0 }

    var progress: Double {
        guard requiredSeconds > 0 else { return 0 }
        return min(1, secondsAccumulated / requiredSeconds)
    }

    var remainingSeconds: TimeInterval {
        max(0, requiredSeconds - secondsAccumulated)
    }

    var isReadyToHatch: Bool { secondsAccumulated >= requiredSeconds }
}

/// Owns the egg-and-collection loop and persists it.
///
/// **Every second of focus counts** — a session you broke at minute 10 still
/// credits those 10 minutes. With hatch costs set at real-time equivalence
/// (24 hours of deep work per incubation day), discarding partial time would put
/// every creature out of reach. The failure still stands in the record; it just
/// does not erase the work you actually did.
nonisolated final class Incubator: @unchecked Sendable {

    /// Shared instance. Touched only from the main thread in app code; tests
    /// build their own instances against a temp directory.
    nonisolated(unsafe) static let shared = Incubator()

    private let fileURL: URL

    private(set) var currentEgg: Egg?
    private(set) var collection: [HatchedCreature] = []

    /// Set by `credit(seconds:)` when an egg completes, so the UI can present
    /// the hatch moment once and then clear it.
    private(set) var pendingHatch: HatchedCreature?

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]

        try? FileManager.default.createDirectory(
            at: base,
            withIntermediateDirectories: true
        )

        self.fileURL = base.appendingPathComponent("incubator.json")
        load()
    }

    // MARK: - Egg lifecycle

    /// Begin incubating a species. Replaces any egg in progress — the previous
    /// egg's accumulated time is discarded, which is why the UI confirms first.
    func startEgg(_ species: Species) {
        currentEgg = Egg(
            speciesID: species.id,
            secondsAccumulated: 0,
            startedAt: Date()
        )
        save()
    }

    /// Credit deep work to the current egg.
    ///
    /// - Parameter seconds: elapsed focus from any session — completed or cut
    ///   short. Partial time counts.
    /// - Returns: the creature if this credit hatched the egg, otherwise `nil`.
    @discardableResult
    func credit(seconds: TimeInterval) -> HatchedCreature? {
        guard seconds > 0, var egg = currentEgg else { return nil }

        egg.secondsAccumulated += seconds
        currentEgg = egg

        guard egg.isReadyToHatch else {
            save()
            return nil
        }

        let creature = HatchedCreature(
            speciesID: egg.speciesID,
            secondsInvested: egg.secondsAccumulated
        )
        collection.append(creature)
        currentEgg = nil
        pendingHatch = creature
        save()
        return creature
    }

    func consumePendingHatch() -> HatchedCreature? {
        defer { pendingHatch = nil }
        return pendingHatch
    }

    // MARK: - Collection queries

    var hatchedSpeciesIDs: Set<String> {
        Set(collection.map(\.speciesID))
    }

    func hatchedCount(of speciesID: String) -> Int {
        collection.filter { $0.speciesID == speciesID }.count
    }

    func creatures(in family: Family) -> [HatchedCreature] {
        collection.filter { $0.species?.family == family }
    }

    /// Distinct species collected, over the total available.
    var completionFraction: Double {
        guard !SpeciesCatalog.all.isEmpty else { return 0 }
        return Double(hatchedSpeciesIDs.count) / Double(SpeciesCatalog.all.count)
    }

    // MARK: - Persistence

    private struct Payload: Codable {
        var currentEgg: Egg?
        var collection: [HatchedCreature]
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let payload = try? decoder.decode(Payload.self, from: data) else { return }
        currentEgg = payload.currentEgg
        collection = payload.collection
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let payload = Payload(currentEgg: currentEgg, collection: collection)
        guard let data = try? encoder.encode(payload) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
