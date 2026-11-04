import Foundation

/// A formant filter: three resonant band-passes at the first three formants of a sung vowel,
/// summed, so any sound takes on the colour of "a", "e", "i", "o" or "u". The vowel is a number
/// from 0 ("a") to 4 ("u") and morphs between neighbours — 0.5 sits halfway from "a" to "e" —
/// so it can be swept by hand, automation or a route. Written new for Echoel Studio
/// (ECHOELTOOLS catalog B9: the earlier app named it and never rendered it), as a value of
/// settings and a render-thread processor like `Chorus`.
///
/// The formants are the classic averages of an adult voice (Peterson & Barney 1952, rounded):
/// a 730/1090/2440 Hz, e 530/1840/2480, i 270/2290/3010, o 570/840/2410, u 300/870/2240, the
/// second and third formants 6 and 12 dB below the first. Resonance sets the bands' Q from 3 to
/// 25. Each band runs as a zero-delay-feedback state-variable stage (`ZDFStage`), whose
/// frequency and damping glide per sample in ~10 ms toward a new setting, so a thrown vowel or
/// resonance sweeps rather than steps; the mix glides the same. One bad sample empties the bands
/// and comes out as silence. Owned by the render thread: set `settings` and call `process` from
/// that thread. Nothing allocates.
public final class FormantFilter: @unchecked Sendable {
    public struct Settings: Equatable, Codable, Sendable {
        /// 0 "a" · 1 "e" · 2 "i" · 3 "o" · 4 "u", morphing in between.
        public var vowel: Double
        /// 0 (broad, Q 3) … 1 (sharp, Q 25).
        public var resonance: Double
        /// Dry 0 … filtered 1.
        public var mix: Double

        public init(vowel: Double = 0, resonance: Double = 0.5, mix: Double = 1) {
            self.vowel = vowel
            self.resonance = resonance
            self.mix = mix
        }

        /// Every value inside its range; non-finite values take the default.
        public var clamped: Settings {
            let base = Settings()
            func clamp(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
                value.isFinite ? Swift.min(Swift.max(value, range.lowerBound), range.upperBound) : fallback
            }
            return Settings(vowel: clamp(vowel, 0...4, base.vowel), resonance: clamp(resonance, 0...1, base.resonance),
                            mix: clamp(mix, 0...1, base.mix))
        }
    }

    /// The five vowels' formants in Hz, "a" first.
    static let vowelTable: [(Double, Double, Double)] = [
        (730, 1_090, 2_440), (530, 1_840, 2_480), (270, 2_290, 3_010), (570, 840, 2_410), (300, 870, 2_240),
    ]
    /// The bands' levels: the second formant 6 dB, the third 12 dB below the first.
    static let bandLevels: (Float, Float, Float) = (1, 0.5, 0.25)
    /// The summed bands' level against the dry sound: a band-pass passes a narrow part of a full
    /// sound, so the vowel is brought up to sit near the dry level.
    static let outputGain: Float = 2

    /// The formants of a morph position, interpolated linearly between the two vowels around it.
    public static func formants(at vowel: Double) -> (Double, Double, Double) {
        let position = vowel.isFinite ? Swift.min(Swift.max(vowel, 0), 4) : 0
        let lower = Swift.min(Int(position), 3)
        let t = position - Double(lower)
        let a = vowelTable[lower], b = vowelTable[lower + 1]
        return (a.0 + (b.0 - a.0) * t, a.1 + (b.1 - a.1) * t, a.2 + (b.2 - a.2) * t)
    }

    /// The damping `1/Q` for a resonance.
    static func damping(_ resonance: Double) -> Float {
        let q = 3 + 22 * Swift.min(Swift.max(resonance, 0), 1)
        return Float(1 / q)
    }

    public var settings: Settings {
        didSet {
            settings = settings.clamped
            updateTargets()
        }
    }

    public let sampleRate: Double
    private var bands: [ZDFStage]
    private var gTarget = SIMD3<Float>(repeating: 0)
    private var gNow = SIMD3<Float>(repeating: 0)
    private var kTarget: Float = 0
    private var kNow: Float = 0
    private var wetNow: Float
    private let glide: Float

    public init(sampleRate: Double, settings: Settings = Settings()) {
        self.sampleRate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        glide = Float(1 - Foundation.exp(-1 / (Compressor.gainGlideSeconds * self.sampleRate)))
        bands = [ZDFStage](repeating: ZDFStage(), count: 6)
        let start = settings.clamped
        self.settings = start
        wetNow = Float(start.mix)
        updateTargets()
        gNow = gTarget
        kNow = kTarget
    }

    private func updateTargets() {
        let f = Self.formants(at: settings.vowel)
        gTarget = SIMD3(ZDFStage.g(f.0, sampleRate: sampleRate), ZDFStage.g(f.1, sampleRate: sampleRate),
                        ZDFStage.g(f.2, sampleRate: sampleRate))
        kTarget = Self.damping(settings.resonance)
    }

    /// Empties the bands; the coefficients take their settings at once.
    public func reset() {
        for index in bands.indices { bands[index].reset() }
        gNow = gTarget
        kNow = kTarget
        wetNow = Float(settings.mix)
    }

    /// Processes `frames` samples in place.
    public func process(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        let wetTarget = Float(settings.mix)
        let levels = Self.bandLevels
        var wet = wetNow, g = gNow, k = kNow
        bands.withUnsafeMutableBufferPointer { stage in
            for i in 0..<frames {
                wet = Compressor.glided(wet, toward: wetTarget, by: glide)
                k = Compressor.glided(k, toward: kTarget, by: glide)
                for band in 0..<3 { g[band] = Compressor.glided(g[band], toward: gTarget[band], by: glide) }
                let inLeft = left[i], inRight = right[i]
                guard inLeft.isFinite, inRight.isFinite else {
                    for index in stage.indices { stage[index].reset() }
                    left[i] = 0
                    right[i] = 0
                    continue
                }
                // `k · band` is a band-pass of unity peak, so the resonance changes the width, not the level.
                let l0 = stage[0].process(inLeft, g: g[0], k: k).band
                let l1 = stage[1].process(inLeft, g: g[1], k: k).band
                let l2 = stage[2].process(inLeft, g: g[2], k: k).band
                let r0 = stage[3].process(inRight, g: g[0], k: k).band
                let r1 = stage[4].process(inRight, g: g[1], k: k).band
                let r2 = stage[5].process(inRight, g: g[2], k: k).band
                let vowelLeft = k * (l0 * levels.0 + l1 * levels.1 + l2 * levels.2) * Self.outputGain
                let vowelRight = k * (r0 * levels.0 + r1 * levels.1 + r2 * levels.2) * Self.outputGain
                let outLeft = inLeft + (vowelLeft - inLeft) * wet
                let outRight = inRight + (vowelRight - inRight) * wet
                guard outLeft.isFinite, outRight.isFinite else {
                    for index in stage.indices { stage[index].reset() }
                    left[i] = 0
                    right[i] = 0
                    continue
                }
                left[i] = outLeft
                right[i] = outRight
            }
        }
        wetNow = wet
        gNow = g
        kNow = k
    }
}
