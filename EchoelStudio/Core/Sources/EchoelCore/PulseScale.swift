import Foundation

/// The scale a heart rate moves the song on: 0 … 1 over 40 … 200 bpm, so one beat per minute is
/// 1/160 of a route's travel. The camera's pulse and Apple Health's are placed on it here
/// (`HealthPulse` names the same scale); the strap's whole beats land on the same points.
///
/// A rate is placed as it was measured, never rounded to a whole beat first (BR-12; founder
/// 2026-11-27: values are never rounded). The camera's analyzer estimates between whole beats, and
/// 72.4 bpm moves the song to its own point, not to 72's. A rate outside 40 … 200 bpm, or one that
/// is no number, is no pulse: nil, and a `BodyChannel` given nil holds no value.
public enum PulseScale {
    /// The rates that are a pulse, in beats per minute.
    public static let plausibleBeats: ClosedRange<Double> = 40...200

    /// `beatsPerMinute` on the scale, exactly as measured; nil when it is not a plausible pulse.
    public static func normalized(beatsPerMinute: Double) -> Double? {
        guard beatsPerMinute.isFinite, plausibleBeats.contains(beatsPerMinute) else { return nil }
        return (beatsPerMinute - plausibleBeats.lowerBound) / (plausibleBeats.upperBound - plausibleBeats.lowerBound)
    }
}
