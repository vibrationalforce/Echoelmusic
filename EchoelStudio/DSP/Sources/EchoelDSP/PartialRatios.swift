import Foundation

/// The measured partials of the master as ratios to the lowest one: what makes a sound harmonic
/// (whole numbers — a string, a voice) or inharmonic (a bell's 2.76, a plate's 4.2), read off the
/// same analysis the Field hears (`SpectralPeaks`). Each ratio is labelled with the nearest whole
/// number and how far it lies from it, in cents. Pure; built at a meter's pace, off the render thread.
///
/// The reference is the lowest partial at least `floor` of the strongest: a quiet rumble does not
/// become the "1". It is the lowest MEASURED partial — a sound without its fundamental reads from
/// its second harmonic, and the label says so ("ratios to the lowest partial", never "to the
/// fundamental").
public struct PartialRatios: Equatable, Sendable {
    public struct Entry: Equatable, Sendable {
        /// The partial's frequency over the lowest one's.
        public var ratio: Double
        /// The nearest whole number, at least 1.
        public var harmonic: Int
        /// How far the ratio lies from `harmonic`, in cents (+ sharp, − flat).
        public var cents: Double
        /// The partial's level against the strongest, 0 … 1.
        public var level: Double
    }

    /// Lowest ratio first.
    public var entries: [Entry]
    /// The partial every ratio is taken against; nil for silence.
    public var lowestHz: Double?

    /// A partial weaker than this share of the strongest is left out.
    public static let floor = 0.01
    /// A distance from the whole number under this many cents is not shown: the analysis (4096
    /// points, about 12 Hz a bin at 48 kHz) does not resolve finer at a low reference.
    public static let centsShown = 10.0

    public static let silent = PartialRatios(entries: [], lowestHz: nil)

    public init(entries: [Entry], lowestHz: Double?) {
        self.entries = entries
        self.lowestHz = lowestHz
    }

    public static func of(_ peaks: SpectralPeaks) -> PartialRatios {
        let used = Swift.min(Swift.max(peaks.count, 0), SpectralPeaks.capacity)
        var strongest = 0.0
        for index in 0..<used where peaks.amplitudes[index].isFinite {
            strongest = Swift.max(strongest, peaks.amplitudes[index])
        }
        guard strongest > 0 else { return .silent }
        var kept: [(frequency: Double, level: Double)] = []
        for index in 0..<used {
            let frequency = peaks.frequencies[index], amplitude = peaks.amplitudes[index]
            guard frequency.isFinite, frequency > 0, amplitude.isFinite, amplitude >= floor * strongest else { continue }
            kept.append((frequency, amplitude / strongest))
        }
        guard let lowest = kept.map(\.frequency).min() else { return .silent }
        let entries = kept.sorted { $0.frequency < $1.frequency }.map { (partial: (frequency: Double, level: Double)) -> Entry in
            let ratio = partial.frequency / lowest
            let harmonic = Swift.max(1, Int(ratio.rounded()))
            let cents = 1200 * Foundation.log2(ratio / Double(harmonic))
            return Entry(ratio: ratio, harmonic: harmonic, cents: cents, level: partial.level)
        }
        return PartialRatios(entries: entries, lowestHz: lowest)
    }

    /// What VoiceOver says: the lowest partial's pitch, then each ratio to two decimals, with
    /// its distance from the nearest whole number where it is at least `centsShown`.
    public var spoken: String {
        guard let lowestHz else { return "No partials" }
        let ratios = entries.map { (entry: Entry) -> String in
            let ratio = String(format: "%.2f", entry.ratio)
            let cents = Int(entry.cents.rounded())
            guard Swift.abs(entry.cents) >= Self.centsShown else { return ratio }
            return "\(ratio), \(Swift.abs(cents)) cents \(cents < 0 ? "flat of" : "sharp of") \(entry.harmonic)"
        }.joined(separator: "; ")
        return "Partials as ratios to the lowest, \(Int(lowestHz.rounded())) hertz: \(ratios)"
    }
}
