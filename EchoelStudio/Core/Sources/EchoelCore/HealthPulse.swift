import Foundation

/// Heart rate from Apple Health as a body source (REC-1): what the Apple Watch, or another device
/// that writes to Health, last measured. Read only, never written, never sent off the device
/// (`BioEgressPolicy.allowsEgress(.health)` is false, and the value is marked private in the
/// engine's modulation cells).
///
/// The earlier app's lesson (#1215): freshness is the age on the MEASUREMENT clock — when the
/// Watch took the reading — not when the app received it. A Watch reading arrives 4 to 5 seconds
/// late during a workout and minutes apart at rest; a reading older than `freshSeconds` reads as
/// "not measured", never as a pulse. That lag is why this source is slow modulation only and never
/// sets the beat: Flow does not follow it.
///
/// Pure: the caller supplies its monotonic clock and each reading's age.
public enum HealthPulse {
    /// The same plausible range and normalization as the chest strap: 0 … 1 over 40 … 200 bpm.
    public static let plausibleBeats = 40.0...200.0
    /// How old a reading may be and still move anything.
    public static let freshSeconds = 120.0
    public static let freshMilliseconds = Int64(freshSeconds * 1_000)
    /// The producer's clock starts this far ahead of zero, so a reading taken before the app
    /// started still has a capture time that is not negative — and is simply too old.
    public static let clockLeadMilliseconds = freshMilliseconds + 1_000
    /// Apple Health gives no quality figure; a reading it stores counts as measured.
    public static let quality = 1.0

    /// The reading normalized to 0 … 1, or nil when it is not a plausible pulse.
    public static func normalized(beatsPerMinute: Double) -> Double? {
        guard beatsPerMinute.isFinite, plausibleBeats.contains(beatsPerMinute) else { return nil }
        return (beatsPerMinute - plausibleBeats.lowerBound) / (plausibleBeats.upperBound - plausibleBeats.lowerBound)
    }

    /// One reading as a `BodyChannel` sample. Its capture time is `nowMilliseconds` minus its age:
    /// a reading dated in the future (a Watch clock slightly ahead) counts as just taken, one
    /// older than the producer's clock as taken at its start, and one without a finite age has
    /// no capture time — the channel calls that invalid.
    public static func sample(beatsPerMinute: Double, measuredSecondsAgo: Double, nowMilliseconds: Int64,
                              epoch: UInt64, sequence: Int64) -> BodyChannel.Sample {
        var captured: Int64?
        if measuredSecondsAgo.isFinite {
            let age = Swift.max(0, measuredSecondsAgo) * 1_000
            captured = age >= Double(nowMilliseconds) ? 0 : nowMilliseconds - Int64(age)
        }
        return BodyChannel.Sample(source: .health, epoch: epoch, sequence: sequence, capturedMilliseconds: captured,
                                  value: normalized(beatsPerMinute: beatsPerMinute), quality: quality)
    }
}
