import XCTest
@testable import DeepWork

/// The detector is pure by design, so the entire lift rulebook is testable here
/// with synthetic samples — no device, no simulator motion, no CoreMotion.
final class LiftDetectorTests: XCTestCase {

    /// Phone resting flat, screen up: gravity points along -Z in body frame.
    private let restingGravity = Vector3(x: 0, y: 0, z: -1)
    private let still = Vector3.zero

    private func sample(
        gravity: Vector3? = nil,
        acceleration: Vector3? = nil
    ) -> LiftDetector.Sample {
        LiftDetector.Sample(
            gravity: gravity ?? restingGravity,
            userAcceleration: acceleration ?? still
        )
    }

    /// Feed enough still samples to complete calibration.
    private func calibrate(_ detector: inout LiftDetector) {
        for _ in 0..<LiftDetector.Thresholds.default.calibrationSamples {
            XCTAssertNil(detector.process(sample()))
        }
        XCTAssertTrue(detector.isCalibrated)
    }

    // MARK: - Calibration

    func testStartsUncalibrated() {
        let detector = LiftDetector()
        XCTAssertFalse(detector.isCalibrated)
    }

    func testCalibratesAfterEnoughSamples() {
        var detector = LiftDetector()
        calibrate(&detector)
    }

    /// ISC-19: violent motion during the arming window must not trip — the user
    /// is still in the act of setting the phone down.
    func testNeverTripsBeforeCalibration() {
        var detector = LiftDetector()
        for _ in 0..<(LiftDetector.Thresholds.default.calibrationSamples - 1) {
            let violent = sample(
                gravity: Vector3(x: 1, y: 0, z: 0),
                acceleration: Vector3(x: 2, y: 2, z: 2)
            )
            XCTAssertNil(detector.process(violent))
        }
    }

    // MARK: - Stillness

    /// ISC-11
    func testPerfectStillnessNeverTrips() {
        var detector = LiftDetector()
        calibrate(&detector)
        for _ in 0..<400 {
            XCTAssertNil(detector.process(sample()))
        }
    }

    /// ISC-12: real accelerometers read ~0.01-0.02g of noise on a still desk.
    /// If that trips the detector, no session ever survives.
    func testSensorNoiseNeverTrips() {
        var detector = LiftDetector()
        calibrate(&detector)

        for i in 0..<400 {
            let jitter = (i % 2 == 0) ? 0.02 : -0.02
            let noisy = sample(
                gravity: Vector3(x: jitter * 0.1, y: jitter * 0.1, z: -1),
                acceleration: Vector3(x: jitter, y: -jitter, z: jitter)
            )
            XCTAssertNil(detector.process(noisy), "tripped on sensor noise at sample \(i)")
        }
    }

    // MARK: - Tilt axis

    /// ISC-13
    func testSustainedTiltTrips() {
        var detector = LiftDetector()
        calibrate(&detector)

        // 45° rotation of the gravity vector in the XZ plane.
        let tilted = Vector3(x: -0.7071, y: 0, z: -0.7071)
        var trip: LiftDetector.Trip?
        for _ in 0..<LiftDetector.Thresholds.default.confirmationSamples {
            trip = detector.process(sample(gravity: tilted))
        }

        guard case .tilted(let degrees)? = trip else {
            return XCTFail("expected .tilted, got \(String(describing: trip))")
        }
        XCTAssertEqual(degrees, 45, accuracy: 1.0)
    }

    /// ISC-14: a 5° drift is a desk settling, not a lift.
    func testSmallTiltNeverTrips() {
        var detector = LiftDetector()
        calibrate(&detector)

        let slight = Vector3(x: -0.0872, y: 0, z: -0.9962) // ~5°
        for _ in 0..<200 {
            XCTAssertNil(detector.process(sample(gravity: slight)))
        }
    }

    /// ISC-18: a slow deliberate tilt produces almost no acceleration. If only
    /// the acceleration axis existed, this would go undetected.
    func testPureRotationTripsViaTilt() {
        var detector = LiftDetector()
        calibrate(&detector)

        let rotated = Vector3(x: -0.5, y: 0, z: -0.866) // 30°
        var trip: LiftDetector.Trip?
        for _ in 0..<LiftDetector.Thresholds.default.confirmationSamples {
            // Acceleration stays at the noise floor throughout.
            trip = detector.process(
                sample(gravity: rotated, acceleration: Vector3(x: 0.005, y: 0.005, z: 0.005))
            )
        }

        guard case .tilted? = trip else {
            return XCTFail("pure rotation must trip the tilt axis")
        }
    }

    // MARK: - Acceleration axis

    /// ISC-15
    func testSustainedAccelerationTrips() {
        var detector = LiftDetector()
        calibrate(&detector)

        var trip: LiftDetector.Trip?
        for _ in 0..<LiftDetector.Thresholds.default.confirmationSamples {
            trip = detector.process(sample(acceleration: Vector3(x: 0, y: 0, z: 0.5)))
        }

        guard case .moved(let g)? = trip else {
            return XCTFail("expected .moved, got \(String(describing: trip))")
        }
        XCTAssertEqual(g, 0.5, accuracy: 0.01)
    }

    /// ISC-16: a door slam or a passing truck is one spike. Killing a 50-minute
    /// session over one sample is the failure mode that gets the app deleted.
    func testSingleSpikeDoesNotTrip() {
        var detector = LiftDetector()
        calibrate(&detector)

        XCTAssertNil(detector.process(sample(acceleration: Vector3(x: 0, y: 0, z: 0.9))))
        for _ in 0..<50 {
            XCTAssertNil(detector.process(sample()))
        }
    }

    /// The confirmation counter must reset on a below-threshold sample, so two
    /// spikes separated by stillness do not accumulate into a trip.
    func testAlternatingSpikesDoNotAccumulate() {
        var detector = LiftDetector()
        calibrate(&detector)

        for _ in 0..<60 {
            XCTAssertNil(detector.process(sample(acceleration: Vector3(x: 0, y: 0, z: 0.9))))
            XCTAssertNil(detector.process(sample()))
        }
    }

    /// ISC-17: sliding a phone flat across a desk leaves gravity untouched. If
    /// only the tilt axis existed, this would go undetected.
    func testPureTranslationTripsViaAcceleration() {
        var detector = LiftDetector()
        calibrate(&detector)

        var trip: LiftDetector.Trip?
        for _ in 0..<LiftDetector.Thresholds.default.confirmationSamples {
            // Gravity identical to baseline — a flat slide.
            trip = detector.process(
                sample(gravity: restingGravity, acceleration: Vector3(x: 0.4, y: 0.2, z: 0))
            )
        }

        guard case .moved? = trip else {
            return XCTFail("flat translation must trip the acceleration axis")
        }
    }

    // MARK: - Numerics

    /// ISC-20: `acos` of a dot product nudged past 1.0 by floating-point error
    /// returns NaN, which compares false against every threshold and would
    /// silently disable tilt detection for the rest of the session.
    func testIdenticalVectorsGiveZeroNotNaN() {
        let v = Vector3(x: 0.267261, y: 0.534522, z: 0.801784)
        let angle = v.angleInDegrees(to: v)
        XCTAssertFalse(angle.isNaN)
        XCTAssertEqual(angle, 0, accuracy: 0.0001)
    }

    func testOppositeVectorsGive180() {
        let a = Vector3(x: 0, y: 0, z: -1)
        let b = Vector3(x: 0, y: 0, z: 1)
        XCTAssertEqual(a.angleInDegrees(to: b), 180, accuracy: 0.0001)
    }

    func testZeroVectorMagnitudeIsSafe() {
        XCTAssertEqual(Vector3.zero.magnitude, 0)
        XCTAssertEqual(Vector3.zero.normalized, .zero)
    }

    // MARK: - Reset

    func testResetClearsCalibration() {
        var detector = LiftDetector()
        calibrate(&detector)
        detector.reset()
        XCTAssertFalse(detector.isCalibrated)
    }

    /// Calibration averages rather than snapshots, so a baseline taken across a
    /// wobble still lands on the true resting orientation.
    func testCalibrationAveragesAcrossWobble() {
        var detector = LiftDetector()
        let count = LiftDetector.Thresholds.default.calibrationSamples

        for i in 0..<count {
            let wobble = (i % 2 == 0) ? 0.03 : -0.03
            _ = detector.process(sample(gravity: Vector3(x: wobble, y: 0, z: -1)))
        }
        XCTAssertTrue(detector.isCalibrated)

        // The averaged baseline should now treat a clean resting vector as still.
        for _ in 0..<100 {
            XCTAssertNil(detector.process(sample()))
        }
    }
}
