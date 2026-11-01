import Foundation

/// Brings a finished stereo mix to a chosen integrated loudness without letting its true peak pass
/// a ceiling — offline, after the render (CUT, 2026-11-01). First a gain; only where that gain
/// would carry the true peak past the ceiling, the `Limiter` behind it holds the peaks, and the
/// gain is raised until the limited mix lands on the target. Nothing here touches a file: the
/// caller replays the mix from its start as often as the search asks and writes the last pass.
///
/// Every reading is `LoudnessMeter`'s (BS.1770-4, the true peak by four-times oversampling), taken
/// on what comes OUT, so the target and the ceiling are checked on the result, never assumed. The
/// limiter holds the SAMPLES under its own ceiling; the peaks between samples can still pass it,
/// so that ceiling starts under the true-peak ceiling and drops by any overshoot a trial measures.
///
/// A mix with nothing above the absolute gate (silence, or no full 400 ms block) stays as it is:
/// nothing is raised that was not measured. Offline only — it allocates its scratch blocks.
public enum LoudnessNormalizer {
    /// One block of the mix: left, right, frame count. It may throw to stop the pass.
    public typealias Block = (UnsafePointer<Float>, UnsafePointer<Float>, Int) throws -> Void
    /// Hands every block of the mix, from its start and in order, to the closure it is given —
    /// each time it is called, the same frames.
    public typealias Replay = (Block) throws -> Void

    /// What one pass measured: the integrated loudness in LUFS and the true peak in dBTP, each
    /// `LoudnessMeter.silent` for silence.
    public struct Measurement: Equatable, Sendable {
        public let integrated: Double
        public let truePeak: Double

        public init(integrated: Double, truePeak: Double) {
            self.integrated = integrated
            self.truePeak = truePeak
        }

        public init(_ meter: LoudnessMeter) {
            self.init(integrated: meter.integratedLoudness, truePeak: meter.truePeak)
        }
    }

    /// What is done to the mix: a gain, then, where the gain alone would pass the ceiling, the
    /// limiter.
    public struct Settings: Equatable, Sendable {
        /// Decibels applied to every sample.
        public let gain: Double
        /// The limiter's ceiling for the samples in dBFS; nil when the gain alone keeps the true
        /// peak under the ceiling.
        public let limiterCeiling: Double?

        public init(gain: Double, limiterCeiling: Double?) {
            self.gain = gain
            self.limiterCeiling = limiterCeiling
        }

        /// The mix as it is: every sample passes bit for bit.
        public static let unchanged = Settings(gain: 0, limiterCeiling: nil)
    }

    /// The absolute gate of BS.1770, LUFS: a mix measured at or below it is not raised.
    public static let absoluteGate = -70.0
    /// A trial this close to the target, in LU, ends the search.
    public static let tolerance = 0.1
    /// The most trials a mix gets; the closest one under the ceiling wins.
    public static let maximumTrials = 8
    /// The limiter's first ceiling sits this far under the true-peak ceiling, in dB: room for the
    /// peaks between samples, which the limiter does not see.
    static let interSampleRoom = 0.5
    /// The gain alone is trusted only this far under the ceiling, in dB, so a rounding in the gain
    /// cannot leave the true peak a hair above it.
    static let gainRoom = 0.01
    /// How far one trial may move the gain, in dB.
    static let largestStep = 12.0
    /// Under this many LU per dB of gain, more gain no longer makes the mix louder.
    static let saturatedSlope = 0.05
    /// How much closer to the target, in LU, a trial must land to win over one with less gain.
    static let clearMargin = 0.02
    /// The limiter's lowest ceiling, its own range.
    static let lowestLimiterCeiling = -24.0

    /// The settings that bring a mix measured at `measured` to `target` LUFS with its true peak at
    /// or under `ceiling` dBTP. The gain alone when that keeps the peak under the ceiling — no
    /// pass needed; otherwise trial passes through `replay`, each measured, until one lands within
    /// `tolerance` under the ceiling. Some mixes go no louder: after a click far above the rest the
    /// limiter holds everything down while its detector decays, whatever the gain. Those get the
    /// closest trial under the ceiling with the least gain, and the measurement says how close it
    /// came. `.unchanged` for a target or ceiling that is not a number, and for a mix that measured
    /// nothing above the absolute gate.
    public static func settings(target: Double, ceiling: Double, measured: Measurement, sampleRate: Double,
                                replay: Replay) throws -> Settings {
        guard target.isFinite, ceiling.isFinite, measured.integrated.isFinite,
              measured.integrated > absoluteGate else { return .unchanged }
        let gain = target - measured.integrated
        // A gain moves the true peak by exactly itself.
        guard measured.truePeak.isFinite, measured.truePeak + gain > ceiling - gainRoom else {
            return Settings(gain: gain, limiterCeiling: nil)
        }
        var trial = Settings(gain: gain, limiterCeiling: Swift.max(ceiling - interSampleRoom, lowestLimiterCeiling))
        var best: (settings: Settings, miss: Double)?
        // The last trial, to learn how far the loudness moves per dB of gain at one limiter ceiling.
        var previous: (gain: Double, loudness: Double, limiter: Double?)?
        var slope = 1.0
        for _ in 0..<maximumTrials {
            let result = try apply(trial, sampleRate: sampleRate, replay: replay) { _, _, _ in }
            guard result.integrated.isFinite else { break }
            let miss = target - result.integrated
            let over = result.truePeak - ceiling
            if over <= 0 {
                if Swift.abs(miss) <= tolerance { return trial }
                // A trial wins only by a clear margin, so of two that land alike the one with less
                // gain — less limiting — stays.
                if best.map({ Swift.abs(miss) < $0.miss - clearMargin }) ?? true { best = (trial, Swift.abs(miss)) }
            }
            if let previous, previous.limiter == trial.limiterCeiling, previous.gain != trial.gain {
                let measuredSlope = (result.integrated - previous.loudness) / (trial.gain - previous.gain)
                // More gain no longer makes it louder: after each peak the limiter holds the mix down
                // as long as its detector decays, whatever the gain. This mix goes no louder.
                if miss > 0, !(measuredSlope >= saturatedSlope) { break }
                if measuredSlope.isFinite { slope = Swift.min(Swift.max(measuredSlope, 0.1), 1) }
            }
            previous = (trial.gain, result.integrated, trial.limiterCeiling)
            var limiter = trial.limiterCeiling ?? ceiling
            // The peaks between samples passed: the samples' ceiling goes down by as much, and a little.
            if over > 0 { limiter = Swift.max(limiter - over - 0.05, lowestLimiterCeiling) }
            let step = Swift.min(Swift.max(miss / slope, -largestStep), largestStep)
            trial = Settings(gain: trial.gain + step, limiterCeiling: limiter)
        }
        return best?.settings ?? trial
    }

    /// One pass of the mix through `settings` into `write`, block by block, measured on the way
    /// out. With `.unchanged` every sample reaches `write` as `replay` gave it.
    public static func apply(_ settings: Settings, sampleRate: Double, replay: Replay,
                             write: Block) throws -> Measurement {
        let stage = Stage(settings, sampleRate: sampleRate)
        var meter = LoudnessMeter(sampleRate: sampleRate)
        var left: [Float] = [], right: [Float] = []
        // `replay` calls back into `write` and nothing keeps either past this call.
        try withoutActuallyEscaping(write) { write in
            try replay { sourceLeft, sourceRight, count in
                guard count > 0 else { return }
                if left.count < count {
                    left = [Float](repeating: 0, count: count)
                    right = [Float](repeating: 0, count: count)
                }
                try left.withUnsafeMutableBufferPointer { leftBuffer in
                    try right.withUnsafeMutableBufferPointer { rightBuffer in
                        guard let l = leftBuffer.baseAddress, let r = rightBuffer.baseAddress else { return }
                        l.update(from: sourceLeft, count: count)
                        r.update(from: sourceRight, count: count)
                        stage.process(left: l, right: r, count: count)
                        meter.process(left: l, right: r, count: count)
                        try write(l, r, count)
                    }
                }
            }
        }
        return Measurement(meter)
    }

    /// The gain, then the limiter where the settings ask for one — fresh for each pass, so two
    /// passes of the same mix give the same samples.
    final class Stage {
        private let gain: Float
        private let limiter: Limiter?

        init(_ settings: Settings, sampleRate: Double) {
            let linear = Foundation.pow(10, settings.gain / 20)
            gain = linear.isFinite ? Float(linear) : 1
            limiter = settings.limiterCeiling.map { ceiling in
                Limiter(sampleRate: sampleRate, settings: Limiter.Settings(gain: 0, ceiling: ceiling))
            }
        }

        func process(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, count: Int) {
            if gain != 1 {
                for index in 0..<count {
                    left[index] *= gain
                    right[index] *= gain
                }
            }
            limiter?.process(left: left, right: right, frames: count)
        }
    }
}
