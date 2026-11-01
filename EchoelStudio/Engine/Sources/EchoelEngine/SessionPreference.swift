import Foundation

/// What the app asks the audio session for (AUD, 2026-11-01), ported from the earlier app's
/// `AudioConfiguration`, where both values were measured on devices: 48 kHz, and a buffer of 512
/// frames — 10.7 ms. That app had shipped 256 frames (5.3 ms) and heard dropouts and crackle
/// under dense chords (10.76.49, "Aussetzer / Kratzen"); 512 doubled the time each render has
/// and stayed inside its 15 ms latency line. Studio asked for nothing until here, so it played at
/// whatever buffer another app or the route had left the device at.
///
/// iOS takes both as wishes (Apple QA1631) and the buffer as a duration, which it turns back into
/// frames at the rate it actually runs: a device that grants 44.1 kHz against the 48 kHz asked
/// would give 470 frames. So the granted rate is read after the session is active and the buffer
/// asked again in frames at that rate — the earlier app's #961.
public enum SessionPreference {
    /// The rate the app asks for.
    public static let sampleRate: Double = 48_000
    /// The buffer the app asks for, in frames.
    public static let bufferFrames = 512

    /// The duration that holds `bufferFrames` at `rate`; at the asked rate for one that is not a
    /// positive, finite number.
    public static func bufferDuration(atRate rate: Double) -> Double {
        let usable = rate.isFinite && rate > 0 ? rate : sampleRate
        return Double(bufferFrames) / usable
    }

    /// Whether the session runs at another rate than the one the buffer was asked at, so the buffer
    /// is asked again: more than a hertz apart, and only for a rate the session really reports.
    public static func asksAgain(asked: Double, granted: Double) -> Bool {
        granted.isFinite && granted > 0 && Swift.abs(granted - asked) > 1
    }
}
