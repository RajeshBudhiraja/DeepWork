import XCTest
@testable import DeepWork

final class IncubatorTests: XCTestCase {

    private var directory: URL!
    private var incubator: Incubator!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        incubator = Incubator(directory: directory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    /// House Sparrow — 11 real incubation days → 264 hours of deep work.
    private var sparrow: Species { SpeciesCatalog.species(withID: "sparrow")! }
    /// Barn Owl — 31 real incubation days → 744 hours of deep work.
    private var owl: Species { SpeciesCatalog.species(withID: "owl")! }

    // MARK: - Catalog integrity

    func testEverySpeciesIDIsUnique() {
        let ids = SpeciesCatalog.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "duplicate species id would orphan hatched creatures")
    }

    func testCatalogCoversBothFamilies() {
        XCTAssertFalse(SpeciesCatalog.members(of: .bird).isEmpty)
        XCTAssertFalse(SpeciesCatalog.members(of: .reptile).isEmpty)
    }

    func testEverySpeciesRequiresPositiveTime() {
        for species in SpeciesCatalog.all {
            XCTAssertGreaterThan(species.incubationDays, 0, "\(species.id) would hatch instantly")
            XCTAssertGreaterThan(species.hatchMinutes, 0)
        }
    }

    /// Hatch cost is derived from real biology by one uniform rule, not set by
    /// hand per species. If this drifts, the numbers have become arbitrary again.
    func testHatchCostDerivesFromRealIncubation() {
        for species in SpeciesCatalog.all {
            XCTAssertEqual(
                species.hatchMinutes,
                species.incubationDays * Species.minutesPerIncubationDay,
                "\(species.id) hatch cost is not derived from its incubation period"
            )
        }
    }

    /// Real incubation periods, spot-checked against the biology.
    func testKnownIncubationPeriodsAreRealistic() {
        XCTAssertEqual(SpeciesCatalog.species(withID: "sparrow")?.incubationDays, 11)
        XCTAssertEqual(SpeciesCatalog.species(withID: "chicken")?.incubationDays, 21)
        XCTAssertEqual(SpeciesCatalog.species(withID: "albatross")?.incubationDays, 79)
        XCTAssertEqual(SpeciesCatalog.species(withID: "tuatara")?.incubationDays, 365)
    }

    /// No bird should out-incubate the tuatara, and the ramp should be wide
    /// enough that the collection has an actual difficulty curve.
    func testCatalogSpansAWideDifficultyRange() {
        let days = SpeciesCatalog.all.map(\.incubationDays)
        XCTAssertLessThanOrEqual(days.min() ?? 0, 15)
        XCTAssertGreaterThanOrEqual(days.max() ?? 0, 200)
    }

    func testCatalogIsSubstantial() {
        XCTAssertGreaterThanOrEqual(SpeciesCatalog.birds.count, 15)
        XCTAssertGreaterThanOrEqual(SpeciesCatalog.reptiles.count, 15)
    }

    /// `members(of:)` orders by real incubation length so the list reads as a ramp.
    func testMembersAreOrderedByIncubationLength() {
        for family in Family.allCases {
            let days = SpeciesCatalog.members(of: family).map(\.incubationDays)
            XCTAssertEqual(days, days.sorted(), "\(family) is not ordered by incubation length")
        }
    }

    // MARK: - Egg lifecycle

    func testStartsWithNoEgg() {
        XCTAssertNil(incubator.currentEgg)
        XCTAssertTrue(incubator.collection.isEmpty)
    }

    func testStartEggSetsCurrentEgg() {
        incubator.startEgg(sparrow)
        XCTAssertEqual(incubator.currentEgg?.speciesID, "sparrow")
        XCTAssertEqual(incubator.currentEgg?.secondsAccumulated, 0)
    }

    func testCreditAccumulatesWithoutHatching() {
        incubator.startEgg(owl)
        let hatched = incubator.credit(seconds: 50 * 60)

        XCTAssertNil(hatched)
        XCTAssertEqual(incubator.currentEgg?.secondsAccumulated, 3000)
        XCTAssertEqual(
            incubator.currentEgg?.progress ?? 0,
            3000.0 / owl.hatchSeconds,
            accuracy: 0.0001
        )
    }

    func testCreditHatchesWhenRequirementMet() {
        incubator.startEgg(sparrow)
        let hatched = incubator.credit(seconds: sparrow.hatchSeconds)

        XCTAssertNotNil(hatched)
        XCTAssertEqual(hatched?.speciesID, "sparrow")
        XCTAssertNil(incubator.currentEgg, "egg should clear once it hatches")
        XCTAssertEqual(incubator.collection.count, 1)
    }

    func testHatchRequiresAccumulationAcrossSessions() {
        incubator.startEgg(sparrow)
        let third = sparrow.hatchSeconds / 3

        XCTAssertNil(incubator.credit(seconds: third))
        XCTAssertNil(incubator.credit(seconds: third))
        XCTAssertNotNil(incubator.credit(seconds: third + 1))
        XCTAssertEqual(incubator.collection.count, 1)
    }

    /// Partial time counts, so a broken session still moves the egg. Only a
    /// zero-length contribution is a no-op.
    func testZeroCreditDoesNothing() {
        incubator.startEgg(sparrow)
        XCTAssertNil(incubator.credit(seconds: 0))
        XCTAssertEqual(incubator.currentEgg?.secondsAccumulated, 0)
    }

    func testCreditWithNoEggIsIgnored() {
        XCTAssertNil(incubator.credit(seconds: 3600))
        XCTAssertTrue(incubator.collection.isEmpty)
    }

    func testStartingNewEggDiscardsPreviousProgress() {
        incubator.startEgg(owl)
        _ = incubator.credit(seconds: 60 * 60)
        incubator.startEgg(sparrow)

        XCTAssertEqual(incubator.currentEgg?.speciesID, "sparrow")
        XCTAssertEqual(incubator.currentEgg?.secondsAccumulated, 0)
    }

    /// Real-time equivalence: one incubation day costs 24 hours of deep work.
    func testRealTimeEquivalenceConversion() {
        XCTAssertEqual(Species.hoursPerIncubationDay, 24)
        XCTAssertEqual(sparrow.hatchMinutes, 11 * 24 * 60)
        XCTAssertEqual(sparrow.hatchSeconds, 11 * 24 * 3600)
    }

    /// A session cut short at 10 minutes still credits those 10 minutes — the
    /// rule that keeps real-time hatch costs reachable at all.
    func testPartialTimeFromABrokenSessionCounts() {
        incubator.startEgg(sparrow)
        XCTAssertNil(incubator.credit(seconds: 10 * 60))
        XCTAssertEqual(incubator.currentEgg?.secondsAccumulated, 600)
    }

    func testManyPartialCreditsAccumulateToAHatch() {
        incubator.startEgg(sparrow)
        let chunk = sparrow.hatchSeconds / 10

        for _ in 0..<9 {
            XCTAssertNil(incubator.credit(seconds: chunk))
        }
        XCTAssertNotNil(incubator.credit(seconds: chunk))
        XCTAssertEqual(incubator.collection.count, 1)
    }

    // MARK: - Collection

    func testDuplicateSpeciesStacksInCollection() {
        incubator.startEgg(sparrow)
        _ = incubator.credit(seconds: sparrow.hatchSeconds)
        incubator.startEgg(sparrow)
        _ = incubator.credit(seconds: sparrow.hatchSeconds)

        XCTAssertEqual(incubator.collection.count, 2)
        XCTAssertEqual(incubator.hatchedCount(of: "sparrow"), 2)
        XCTAssertEqual(incubator.hatchedSpeciesIDs.count, 1, "distinct species should still be 1")
    }

    func testPendingHatchIsConsumedOnce() {
        incubator.startEgg(sparrow)
        _ = incubator.credit(seconds: sparrow.hatchSeconds)

        XCTAssertNotNil(incubator.consumePendingHatch())
        XCTAssertNil(incubator.consumePendingHatch(), "hatch celebration must not repeat")
    }

    func testCreaturesFilteredByFamily() {
        incubator.startEgg(sparrow)
        _ = incubator.credit(seconds: sparrow.hatchSeconds)

        XCTAssertEqual(incubator.creatures(in: .bird).count, 1)
        XCTAssertTrue(incubator.creatures(in: .reptile).isEmpty)
    }

    // MARK: - Persistence

    func testStatePersistsAcrossInstances() {
        incubator.startEgg(owl)
        _ = incubator.credit(seconds: 42 * 60)

        let reloaded = Incubator(directory: directory)
        XCTAssertEqual(reloaded.currentEgg?.speciesID, "owl")
        XCTAssertEqual(reloaded.currentEgg?.secondsAccumulated, 2520)
    }

    func testCollectionPersistsAcrossInstances() {
        incubator.startEgg(sparrow)
        _ = incubator.credit(seconds: sparrow.hatchSeconds)

        let reloaded = Incubator(directory: directory)
        XCTAssertEqual(reloaded.collection.count, 1)
        XCTAssertEqual(reloaded.collection.first?.speciesID, "sparrow")
    }
}
