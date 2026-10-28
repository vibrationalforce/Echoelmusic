import Foundation

/// The two modulation sources a chest strap's beat-to-beat intervals carry beyond the pulse
/// (wave W2): HRV and coherence, each normalized 0 … 1, each nil while the intervals cannot
/// state it. Pure; the strap calls it with its newest intervals, oldest first.
///
/// - HRV is RMSSD over the accepted within-segment differences, mapped by `HRVNormalization`
///   (100 ms = 1). It needs `minimumForHRV` intervals.
/// - Coherence is `HRVCoherence` over the accepted intervals; it needs the spectrum's own 16.
/// Both refuse when too few intervals survive `RRIntervalHygiene` — a poor contact gives no
/// number rather than a low one (atrial fibrillation would otherwise read as calm).
public enum BeatDerivedSources {
    public static let minimumForHRV = 8

    public struct Readings: Equatable, Sendable {
        public let hrv: Double?
        public let coherence: Double?

        public init(hrv: Double?, coherence: Double?) {
            self.hrv = hrv
            self.coherence = coherence
        }
    }

    public static func readings(rrMs: [Double]) -> Readings {
        guard rrMs.count >= minimumForHRV, RRIntervalHygiene.canStateHRV(rrMs: rrMs) else {
            return Readings(hrv: nil, coherence: nil)
        }
        let segments = RRIntervalHygiene.acceptedSegments(rrMs: rrMs)
        let rmssd = HRVMetrics.rmssd(segments: segments)
        let hrv: Double? = rmssd > 0 ? HRVNormalization.normalize(rmssd) : nil
        let accepted = segments.flatMap { $0 }
        var coherence: Double?
        if accepted.count >= HRVCoherence.minIntervals {
            let reading = HRVCoherence.compute(rrMs: accepted)
            if reading.valid, reading.coherence.isFinite {
                coherence = Swift.min(1, Swift.max(0, Double(reading.coherence)))
            }
        }
        return Readings(hrv: hrv, coherence: coherence)
    }
}
