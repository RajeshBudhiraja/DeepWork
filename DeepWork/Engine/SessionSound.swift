import AVFoundation
import AudioToolbox
import UIKit

/// Audible signals for the end of a session.
///
/// The sound is not decoration — it is the only channel the app has. The whole
/// premise is that the phone is face-down and out of reach, so a session that
/// ends silently is a session you find out about ten minutes late.
///
/// The audio session uses `.playback`, which means these play even with the
/// ringer switch set to silent. That is deliberate and matches how alarms
/// behave: you deliberately gave up the ability to watch the screen, so the app
/// owes you an unmissable signal.
enum SessionSound {

    /// Bright multi-tone alert — the session ran to the end.
    private static let completeID: SystemSoundID = 1025
    /// Shorter, lower tone — the session broke.
    private static let failID: SystemSoundID = 1073

    /// Prepare the audio session. Called when a session starts so the category
    /// is already active by the time a sound is needed.
    static func prepare() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.duckOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Audio is a signal, not a requirement. If the category cannot be
            // set the haptics still fire and the UI still updates.
        }
    }

    /// Release the audio session so other apps get their volume back.
    static func teardown() {
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    /// Played when the timer runs out. Repeats three times, roughly a second
    /// apart, so it carries across a room and is not missed.
    static func playCompleted() {
        chime(completeID, times: 3, interval: 1.1)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Played when the session breaks. One shot — you are almost certainly
    /// holding the phone already.
    static func playFailed() {
        chime(failID, times: 1, interval: 0)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    private static func chime(_ id: SystemSoundID, times: Int, interval: TimeInterval) {
        guard times > 0 else { return }
        AudioServicesPlaySystemSound(id)

        for repeatIndex in 1..<max(1, times) {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(repeatIndex)) {
                AudioServicesPlaySystemSound(id)
            }
        }
    }
}
