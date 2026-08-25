import CoreMotion
import Foundation

/// Thin CoreMotion wrapper. Owns the hardware; owns no rules.
///
/// Everything that decides what counts as a lift lives in `LiftDetector`. This
/// type only converts `CMDeviceMotion` into `LiftDetector.Sample` and forwards
/// the verdict to the main queue.
///
/// Concurrency: CoreMotion delivers samples on a background `OperationQueue`,
/// so this type is `nonisolated` rather than inheriting the module's main-actor
/// default. Mutable state is guarded by `lock`; the `onTrip` / `onCalibrated`
/// callbacks are always invoked on the main queue so callers can touch UIKit
/// directly.
///
/// Note on permissions: device-motion from `CMMotionManager` requires no
/// authorization and shows no prompt. Only `CMPedometer` and
/// `CMMotionActivityManager` need `NSMotionUsageDescription`.
nonisolated final class MotionMonitor: @unchecked Sendable {

    /// 20 Hz. A human lift takes 200-400 ms, which is 4-8 samples here — ample
    /// for a 3-sample confirmation window. Sampling faster costs battery across a
    /// 50-minute session and buys no accuracy.
    static let updateFrequency: Double = 20.0

    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    private let lock = NSLock()

    // All guarded by `lock`.
    private var detector = LiftDetector()
    private var running = false
    private var hasReportedCalibration = false

    /// Fires once, on the main queue, the first time the detector trips.
    var onTrip: ((LiftDetector.Trip) -> Void)?

    /// Fires on the main queue when calibration finishes, so the UI can switch
    /// from "hold still" to "watching".
    var onCalibrated: (() -> Void)?

    var isRunning: Bool {
        lock.withLock { running }
    }

    var isAvailable: Bool { motionManager.isDeviceMotionAvailable }

    init() {
        queue.name = "com.example.DeepWork.motion"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
    }

    deinit {
        motionManager.stopDeviceMotionUpdates()
    }

    /// Begin sampling. The first ~500 ms is spent learning the resting
    /// orientation; the detector cannot trip during that window.
    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }

        lock.withLock {
            guard !running else { return }
            detector.reset()
            hasReportedCalibration = false
            running = true
        }

        motionManager.deviceMotionUpdateInterval = 1.0 / Self.updateFrequency
        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.handle(motion)
        }
    }

    func stop() {
        let wasRunning: Bool = lock.withLock {
            defer { running = false }
            return running
        }
        guard wasRunning else { return }

        motionManager.stopDeviceMotionUpdates()
        lock.withLock { detector.reset() }
    }

    private func handle(_ motion: CMDeviceMotion) {
        let sample = LiftDetector.Sample(
            gravity: Vector3(
                x: motion.gravity.x,
                y: motion.gravity.y,
                z: motion.gravity.z
            ),
            userAcceleration: Vector3(
                x: motion.userAcceleration.x,
                y: motion.userAcceleration.y,
                z: motion.userAcceleration.z
            )
        )

        enum Outcome {
            case nothing
            case calibrated
            case tripped(LiftDetector.Trip)
        }

        let outcome: Outcome = lock.withLock {
            guard running else { return .nothing }

            if let trip = detector.process(sample) {
                // Latch immediately so no further samples race this callback —
                // the session is already over and a second trip is noise.
                running = false
                return .tripped(trip)
            }

            if detector.isCalibrated, !hasReportedCalibration {
                hasReportedCalibration = true
                return .calibrated
            }
            return .nothing
        }

        switch outcome {
        case .nothing:
            break

        case .calibrated:
            DispatchQueue.main.async { [weak self] in
                self?.onCalibrated?()
            }

        case .tripped(let trip):
            motionManager.stopDeviceMotionUpdates()
            DispatchQueue.main.async { [weak self] in
                self?.onTrip?(trip)
            }
        }
    }
}
