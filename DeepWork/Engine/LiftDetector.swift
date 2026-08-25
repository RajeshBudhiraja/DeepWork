import Foundation

/// Pure, dependency-free lift detection.
///
/// Deliberately imports only Foundation so the whole detection rulebook can be
/// unit-tested by feeding it synthetic samples — no device, no simulator motion,
/// no CoreMotion. `MotionMonitor` is the only thing that knows CoreMotion exists.
///
/// The physics: a phone at rest on a surface is in static equilibrium. Moving it
/// anywhere requires a non-zero net impulse (Newton's second law), and a human
/// hand almost always rotates it on the way up. Those are two *orthogonal*
/// signals, and each covers the other's blind spot:
///
/// - Sliding a phone flat across a desk leaves `gravity` untouched → only
///   `userAcceleration` sees it.
/// - Tilting a phone slowly in place produces almost no `userAcceleration` → only
///   `gravity` sees it.
///
/// So we watch both and trip on either.
///
/// `nonisolated` is load-bearing: this runs on CoreMotion's background queue,
/// not the main actor. The module defaults to main-actor isolation under Swift 6,
/// and inheriting that here would be a lie about where the code actually runs.
nonisolated struct LiftDetector: Sendable {

    // MARK: - Input

    /// One device-motion sample, stripped to just what detection needs.
    nonisolated struct Sample: Sendable {
        /// Unit vector pointing "down" in the device's body frame.
        let gravity: Vector3
        /// Specific force minus gravity, in g. ~zero for a stationary device.
        let userAcceleration: Vector3

        init(gravity: Vector3, userAcceleration: Vector3) {
            self.gravity = gravity
            self.userAcceleration = userAcceleration
        }
    }

    /// Why the detector tripped. Surfaced to the user verbatim, so the cases are
    /// phrased as observations rather than accusations.
    nonisolated enum Trip: Equatable, Sendable {
        /// The device's orientation changed — it was tilted, turned, or picked up.
        case tilted(degrees: Double)
        /// The device translated — it was slid, bumped hard, or lifted straight up.
        case moved(gForce: Double)
    }

    // MARK: - Tuning

    nonisolated struct Thresholds: Sendable {
        /// Orientation change from baseline that counts as movement.
        /// 15° is well beyond sensor drift but below "I nudged the desk".
        var tiltDegrees: Double = 15.0

        /// Translation magnitude that counts as movement, in g.
        /// A stationary phone reads ~0.01-0.02g of noise; a real lift spikes
        /// well past 0.2g. 0.18 sits above the noise floor with margin.
        var accelerationG: Double = 0.18

        /// Consecutive over-threshold samples required before tripping.
        /// At 20 Hz this is 150 ms — long enough to reject a single-sample spike
        /// from a door slam or a passing truck, short enough that a hand closing
        /// on the phone is caught before it clears the desk.
        var confirmationSamples: Int = 3

        /// Samples averaged at the start to learn the resting orientation.
        /// At 20 Hz this is 500 ms of stillness.
        var calibrationSamples: Int = 10

        static let `default` = Thresholds()
    }

    // MARK: - State

    private let thresholds: Thresholds
    private var calibrationBuffer: [Vector3] = []
    private var baselineGravity: Vector3?
    private var consecutiveTilt = 0
    private var consecutiveAcceleration = 0

    /// True once enough still samples have been averaged into a baseline.
    /// Before this, the detector never trips — there is nothing to deviate from.
    var isCalibrated: Bool { baselineGravity != nil }

    init(thresholds: Thresholds = .default) {
        self.thresholds = thresholds
    }

    // MARK: - Detection

    /// Feed one sample. Returns a `Trip` the instant the confirmation window
    /// fills, `nil` otherwise.
    ///
    /// Mutating rather than class-based: the detector is a value, which makes the
    /// tests trivially isolated from each other.
    mutating func process(_ sample: Sample) -> Trip? {
        guard let baseline = baselineGravity else {
            calibrate(with: sample.gravity)
            return nil
        }

        // Axis A — orientation. Angle between current and baseline gravity.
        let tilt = baseline.angleInDegrees(to: sample.gravity)
        if tilt > thresholds.tiltDegrees {
            consecutiveTilt += 1
            if consecutiveTilt >= thresholds.confirmationSamples {
                return .tilted(degrees: tilt)
            }
        } else {
            consecutiveTilt = 0
        }

        // Axis B — translation. Magnitude of acceleration excluding gravity.
        let gForce = sample.userAcceleration.magnitude
        if gForce > thresholds.accelerationG {
            consecutiveAcceleration += 1
            if consecutiveAcceleration >= thresholds.confirmationSamples {
                return .moved(gForce: gForce)
            }
        } else {
            consecutiveAcceleration = 0
        }

        return nil
    }

    /// Average the first N gravity vectors into a resting baseline.
    ///
    /// Averaging rather than snapshotting a single sample matters: one sample
    /// taken mid-wobble would bake the wobble into the baseline and skew every
    /// subsequent comparison.
    private mutating func calibrate(with gravity: Vector3) {
        calibrationBuffer.append(gravity)
        guard calibrationBuffer.count >= thresholds.calibrationSamples else { return }

        let sum = calibrationBuffer.reduce(Vector3.zero, +)
        baselineGravity = sum.normalized
        calibrationBuffer.removeAll(keepingCapacity: false)
    }

    /// Drop the baseline and start over. Used when a session re-arms.
    mutating func reset() {
        calibrationBuffer.removeAll()
        baselineGravity = nil
        consecutiveTilt = 0
        consecutiveAcceleration = 0
    }
}

// MARK: - Vector3

/// Minimal 3-vector. Exists so `LiftDetector` needs neither CoreMotion's
/// `CMAcceleration` nor simd, keeping it testable in a plain unit test target.
nonisolated struct Vector3: Equatable, Sendable {
    var x: Double
    var y: Double
    var z: Double

    static let zero = Vector3(x: 0, y: 0, z: 0)

    var magnitude: Double { (x * x + y * y + z * z).squareRoot() }

    var normalized: Vector3 {
        let m = magnitude
        guard m > 0 else { return .zero }
        return Vector3(x: x / m, y: y / m, z: z / m)
    }

    func dot(_ other: Vector3) -> Double {
        x * other.x + y * other.y + z * other.z
    }

    /// Angle to another vector, in degrees.
    ///
    /// The clamp is not decoration: floating-point error can push the dot product
    /// of two nearly-identical unit vectors to 1.0000000000000002, and `acos` of
    /// that is NaN. A NaN here would compare false against every threshold and
    /// silently disable tilt detection for the rest of the session.
    func angleInDegrees(to other: Vector3) -> Double {
        let cosine = normalized.dot(other.normalized)
        let clamped = min(1.0, max(-1.0, cosine))
        return acos(clamped) * 180.0 / .pi
    }

    static func + (lhs: Vector3, rhs: Vector3) -> Vector3 {
        Vector3(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }
}
