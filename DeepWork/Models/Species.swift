import Foundation

/// The two branches of the collection. Both are egg-layers — which is the whole
/// conceit: you are incubating something, and incubation takes time you cannot
/// fake.
nonisolated enum Family: String, Codable, CaseIterable, Sendable {
    case bird
    case reptile

    var title: String {
        switch self {
        case .bird:    return "Birds"
        case .reptile: return "Reptiles"
        }
    }

    var symbol: String {
        switch self {
        case .bird:    return "bird.fill"
        case .reptile: return "lizard.fill"
        }
    }
}

/// One collectable creature.
///
/// `id` is persisted, so ids are frozen once shipped. Adding species is safe;
/// renaming an existing `id` orphans anything already hatched.
nonisolated struct Species: Codable, Equatable, Identifiable, Hashable, Sendable {

    /// **The conversion.** One real day of incubation costs a full day —
    /// twenty-four hours — of deep work. Real-time equivalence: the egg takes
    /// exactly as long to hatch in focus as it would in life.
    ///
    /// This makes the collection a multi-year undertaking by design. A house
    /// sparrow is 264 hours; a tuatara is 8,760. Partial time from every session
    /// counts toward it, which is what keeps it reachable.
    static let hoursPerIncubationDay = 24
    static let minutesPerIncubationDay = hoursPerIncubationDay * 60

    let id: String
    let name: String
    let family: Family
    /// Emoji shown for the hatched creature.
    let glyph: String
    /// **Real** incubation period in days, from the species' actual biology.
    let incubationDays: Int
    /// One line about the animal — true, and specific enough to be worth reading.
    let blurb: String

    /// Deep work required to hatch, derived from the real incubation period.
    /// Every session contributes, finished or not.
    var hatchMinutes: Int { incubationDays * Self.minutesPerIncubationDay }

    var hatchSeconds: TimeInterval { TimeInterval(hatchMinutes * 60) }

    /// Human-readable hatch cost, e.g. "5h 30m".
    var hatchCostString: String { TimeInterval(hatchMinutes * 60).compactString }

    /// Banding by real incubation length, used for ordering within a family.
    var tier: Int {
        switch incubationDays {
        case ..<20:   return 1
        case ..<35:   return 2
        case ..<70:   return 3
        case ..<150:  return 4
        default:      return 5
        }
    }
}

// MARK: - Catalog

/// Incubation periods are real averages for each species. Where a range is
/// normally quoted, the midpoint is used.
nonisolated enum SpeciesCatalog {

    static let all: [Species] = birds + reptiles

    static let birds: [Species] = [
        Species(
            id: "sparrow", name: "House Sparrow", family: .bird, glyph: "🐦",
            incubationDays: 11,
            blurb: "Eleven days in the nest. The shortest incubation of any bird you'll meet on a street."
        ),
        Species(
            id: "robin", name: "Robin", family: .bird, glyph: "🐦‍🔥",
            incubationDays: 13,
            blurb: "The female sits almost continuously, leaving only minutes at a time."
        ),
        Species(
            id: "hummingbird", name: "Hummingbird", family: .bird, glyph: "🦢",
            incubationDays: 15,
            blurb: "An egg the size of a pea, in a nest that stretches as the chicks grow."
        ),
        Species(
            id: "budgerigar", name: "Budgerigar", family: .bird, glyph: "🦜",
            incubationDays: 18,
            blurb: "Lays every other day, so one nest holds chicks of visibly different ages."
        ),
        Species(
            id: "crow", name: "Crow", family: .bird, glyph: "🐦‍⬛",
            incubationDays: 18,
            blurb: "Grown offspring stay on to help raise the next brood."
        ),
        Species(
            id: "chicken", name: "Chicken", family: .bird, glyph: "🐔",
            incubationDays: 21,
            blurb: "Twenty-one days — the most precisely known incubation period on Earth."
        ),
        Species(
            id: "macaw", name: "Macaw", family: .bird, glyph: "🦜",
            incubationDays: 26,
            blurb: "Pairs bond for life and travel wingtip to wingtip."
        ),
        Species(
            id: "duck", name: "Mallard", family: .bird, glyph: "🦆",
            incubationDays: 28,
            blurb: "Ducklings hatch ready to walk, swim, and feed themselves the same day."
        ),
        Species(
            id: "flamingo", name: "Flamingo", family: .bird, glyph: "🦩",
            incubationDays: 29,
            blurb: "Both parents feed the chick crop milk — bright red, and produced by the throat."
        ),
        Species(
            id: "pelican", name: "Pelican", family: .bird, glyph: "🦅",
            incubationDays: 30,
            blurb: "Incubates its eggs under the webbing of its feet."
        ),
        Species(
            id: "owl", name: "Barn Owl", family: .bird, glyph: "🦉",
            incubationDays: 31,
            blurb: "Wing feathers with a fringed edge break up turbulence. It hunts in silence."
        ),
        Species(
            id: "falcon", name: "Peregrine Falcon", family: .bird, glyph: "🪶",
            incubationDays: 33,
            blurb: "Stoops at over 300 km/h. The fastest animal that has ever been measured."
        ),
        Species(
            id: "eagle", name: "Bald Eagle", family: .bird, glyph: "🦅",
            incubationDays: 35,
            blurb: "Returns to the same nest for decades, adding to it each year until it weighs a tonne."
        ),
        Species(
            id: "swan", name: "Mute Swan", family: .bird, glyph: "🦢",
            incubationDays: 36,
            blurb: "Calm on the surface. You know what it took underneath."
        ),
        Species(
            id: "puffin", name: "Atlantic Puffin", family: .bird, glyph: "🐧",
            incubationDays: 40,
            blurb: "Carries a dozen fish crosswise in its beak at once, held by a spined tongue."
        ),
        Species(
            id: "ostrich", name: "Ostrich", family: .bird, glyph: "🦤",
            incubationDays: 42,
            blurb: "The largest egg of any living animal — around 1.4 kg."
        ),
        Species(
            id: "cassowary", name: "Cassowary", family: .bird, glyph: "🦃",
            incubationDays: 52,
            blurb: "The male incubates alone for seven weeks, barely eating."
        ),
        Species(
            id: "emu", name: "Emu", family: .bird, glyph: "🦃",
            incubationDays: 56,
            blurb: "The male loses a third of his body weight sitting on the nest."
        ),
        Species(
            id: "penguin", name: "Emperor Penguin", family: .bird, glyph: "🐧",
            incubationDays: 64,
            blurb: "Balances the egg on his feet through the Antarctic winter, in the dark, without food."
        ),
        Species(
            id: "albatross", name: "Wandering Albatross", family: .bird, glyph: "🕊️",
            incubationDays: 79,
            blurb: "The longest incubation of any bird. It can fly for years without touching land."
        )
    ]

    static let reptiles: [Species] = [
        Species(
            id: "anole", name: "Green Anole", family: .reptile, glyph: "🦎",
            incubationDays: 35,
            blurb: "Lays a single egg at a time, every couple of weeks, all summer."
        ),
        Species(
            id: "gecko", name: "House Gecko", family: .reptile, glyph: "🦎",
            incubationDays: 45,
            blurb: "Millions of microscopic hairs let it hold to glass by molecular attraction alone."
        ),
        Species(
            id: "ballpython", name: "Ball Python", family: .reptile, glyph: "🐍",
            incubationDays: 55,
            blurb: "The female coils around the clutch and shivers to keep it warm."
        ),
        Species(
            id: "leopardgecko", name: "Leopard Gecko", family: .reptile, glyph: "🦎",
            incubationDays: 55,
            blurb: "Incubation temperature, not chromosomes, decides whether it hatches male or female."
        ),
        Species(
            id: "cornsnake", name: "Corn Snake", family: .reptile, glyph: "🐍",
            incubationDays: 60,
            blurb: "Lays and leaves. The hatchlings are entirely on their own."
        ),
        Species(
            id: "beardeddragon", name: "Bearded Dragon", family: .reptile, glyph: "🦎",
            incubationDays: 60,
            blurb: "Waves one arm slowly to signal submission to a larger dragon."
        ),
        Species(
            id: "seaturtle", name: "Green Sea Turtle", family: .reptile, glyph: "🐢",
            incubationDays: 60,
            blurb: "Returns to the beach where it hatched, navigating by the Earth's magnetic field."
        ),
        Species(
            id: "alligator", name: "American Alligator", family: .reptile, glyph: "🐊",
            incubationDays: 65,
            blurb: "The mother carries her hatchlings to water in her mouth."
        ),
        Species(
            id: "kingcobra", name: "King Cobra", family: .reptile, glyph: "🐍",
            incubationDays: 70,
            blurb: "The only snake in the world that builds a nest for its eggs."
        ),
        Species(
            id: "boxturtle", name: "Box Turtle", family: .reptile, glyph: "🐢",
            incubationDays: 70,
            blurb: "A hinged shell that closes completely. It can outlive the person who found it."
        ),
        Species(
            id: "iguana", name: "Green Iguana", family: .reptile, glyph: "🦎",
            incubationDays: 90,
            blurb: "A third eye on top of its head senses light and shadow from above."
        ),
        Species(
            id: "crocodile", name: "Nile Crocodile", family: .reptile, glyph: "🐊",
            incubationDays: 90,
            blurb: "Essentially unchanged for 200 million years. It found what works."
        ),
        Species(
            id: "snappingturtle", name: "Snapping Turtle", family: .reptile, glyph: "🐢",
            incubationDays: 90,
            blurb: "Lies motionless with its mouth open, wriggling a worm-shaped tongue as bait."
        ),
        Species(
            id: "tortoise", name: "Galápagos Tortoise", family: .reptile, glyph: "🐢",
            incubationDays: 130,
            blurb: "Over a century of life, and it can go a year without food or water."
        ),
        Species(
            id: "monitor", name: "Monitor Lizard", family: .reptile, glyph: "🦎",
            incubationDays: 170,
            blurb: "Can count. Tested to at least six."
        ),
        Species(
            id: "chameleon", name: "Veiled Chameleon", family: .reptile, glyph: "🦎",
            incubationDays: 180,
            blurb: "Each eye rotates independently — two separate fields of view at once."
        ),
        Species(
            id: "komodo", name: "Komodo Dragon", family: .reptile, glyph: "🐉",
            incubationDays: 210,
            blurb: "Seven months underground. The largest lizard alive."
        ),
        Species(
            id: "tuatara", name: "Tuatara", family: .reptile, glyph: "🦖",
            incubationDays: 365,
            blurb: "A full year to hatch — the longest of any reptile. Its lineage predates the dinosaurs."
        )
    ]

    static func species(withID id: String) -> Species? {
        all.first { $0.id == id }
    }

    /// Ordered by real incubation length, so the list reads as a difficulty ramp.
    static func members(of family: Family) -> [Species] {
        (family == .bird ? birds : reptiles).sorted { $0.incubationDays < $1.incubationDays }
    }
}
