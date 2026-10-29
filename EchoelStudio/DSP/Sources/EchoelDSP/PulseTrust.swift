// Ported from the earlier app (Sources/Echoelmusic/Bio/CameraRPPGBioPublisher.swift, the trust
// predicates) for Echoel Studio 1.0, wave W1 "body": the one bar a camera pulse must clear before
// it is shown or moves anything. Pure, Foundation only.

import Foundation

/// When a camera pulse reading may be trusted. Confidence alone can be inflated by the peak counter
/// agreeing with itself on a poorly placed finger (device: red saturated, periodicity 0.14,
/// confidence 0.90, a wrong 79 bpm against a true 54), so a reading needs confidence AND real
/// periodicity — or periodicity so strong it proves the pulse on its own (device: 0.6–0.7 with a
/// stable 56 bpm while the confidence sat at 0.01). The number shown and the number that moves a
/// parameter clear the SAME bar.
public enum PulseTrust {
    /// Confidence a reading needs when its periodicity is merely usable.
    public static let displayThreshold = 0.6
    /// Periodicity a confident reading must at least carry; junk tops out near 0.29.
    public static let trustAutoFloor = 0.4
    /// Periodicity that proves a pulse whatever the confidence says.
    public static let strongAutoFloor = 0.6

    /// Confident AND corroborated, or strongly periodic on its own.
    public static func isTrustworthy(confidence: Double, autoStrength: Double) -> Bool {
        guard confidence.isFinite, autoStrength.isFinite else { return false }
        return (confidence >= displayThreshold && autoStrength >= trustAutoFloor)
            || autoStrength >= strongAutoFloor
    }

    /// A rate exists and the reading is trustworthy.
    public static func shouldPublish(bpm: Double, confidence: Double, autoStrength: Double) -> Bool {
        bpm.isFinite && bpm > 0 && isTrustworthy(confidence: confidence, autoStrength: autoStrength)
    }

    /// The channel quality a trustworthy reading carries, 0 … 1: the stronger of the two witnesses,
    /// so a strongly periodic reading at low confidence still passes a quality floor of
    /// `displayThreshold`. 0 for a reading that is not trustworthy.
    public static func quality(confidence: Double, autoStrength: Double) -> Double {
        guard isTrustworthy(confidence: confidence, autoStrength: autoStrength) else { return 0 }
        return Swift.min(1, Swift.max(0, Swift.max(confidence, autoStrength)))
    }
}
