import Foundation

/// Offline edits of a stretch of audio, for a region's bake (W3): pitch correction and a granular
/// texture, computed off the render thread over the whole stretch at once, never live. Both are
/// the insert processors (`PitchCorrector`'s splice head, `Granulator`) driven over a finished
/// recording, so a bake and the insert share their sound; what the offline form adds is that it
/// can look ahead.
///
/// · **Pitch correction** hears the whole stretch first with the one `PitchTracker` (YIN), every
///   ~5 ms. Each voiced analysis is placed at the middle of its window, and the pitch it pulls
///   toward the nearest allowed note is the note's CENTRE — the mean of the voiced analyses within
///   `vibratoSeconds` either side that lie within `centreSpan` semitones — not the pitch of the
///   moment. A vibrato swings around its centre, so the centre moves onto the note and the swing
///   stays; a correction toward the pitch of the moment would iron it flat. Strength scales the
///   correction (0 changes nothing, 1 lands the centre on the note), the retune time glides it
///   (0 snaps). The head shifts by reading the input faster or slower (`SpliceHead`), so the
///   formants move with the pitch: this is not formant-preserving, and the correction never
///   exceeds `PitchCorrector.reach` semitones. The splice head's delay is taken back out, so the
///   result lines up with the original frame for frame.
/// · **Granular texture** is `Granulator` fully wet over the stretch, the grains reading around
///   the moment they play: the read position is set back by exactly what the output is set back
///   by, so the texture stays where its material was. The same input, settings and seed give the
///   same frames, bit for bit.
///
/// Every input value that is not a number is read as silence; every output value is finite.
/// `isCancelled` is asked every few thousand frames; a bake it stops returns nil.
public enum OfflineBake {
    /// One channel, or two.
    public struct Audio: Equatable, Sendable {
        public var left: [Float]
        /// Nil for one channel.
        public var right: [Float]?

        public init(left: [Float], right: [Float]? = nil) {
            self.left = left
            self.right = right.map { $0.count == left.count ? $0 : Self.fitted($0, to: left.count) }
        }

        public var frameCount: Int { left.count }

        private static func fitted(_ side: [Float], to count: Int) -> [Float] {
            side.count >= count ? Array(side.prefix(count)) : side + [Float](repeating: 0, count: count - side.count)
        }
    }

    /// The granular texture's settings.
    public struct Texture: Equatable, Sendable {
        /// Grain length in seconds, 0.01 … 0.5.
        public var size: Double
        /// 0 … 1 → 0.5 … 3.5 grains at once.
        public var density: Double
        /// How far around its moment a grain may read, in seconds, 0 … 0.5.
        public var scatter: Double
        /// Grain transposition in semitones, −24 … 24.
        public var pitch: Double
        /// The grains' random sequence.
        public var seed: UInt64

        public init(size: Double = 0.08, density: Double = 0.5, scatter: Double = 0.05, pitch: Double = 0, seed: UInt64 = 1) {
            self.size = size
            self.density = density
            self.scatter = scatter
            self.pitch = pitch
            self.seed = seed
        }
    }

    /// How far either side of an analysis its note's centre is measured, in seconds: more than a
    /// whole cycle of a sung vibrato (5 … 7 Hz) either way.
    public static let vibratoSeconds = 0.15
    /// Analyses further than this from the one being centred, in semitones, belong to another note.
    public static let centreSpan = 1.5
    /// Frames between two looks at `isCancelled`.
    static let cancelStride = 8_192

    // MARK: - Pitch correction

    /// `audio` with every voiced note pulled toward the nearest pitch `settings` allow, by
    /// `settings.amount` (strength) over `settings.speed` seconds (retune time). The output has the
    /// input's length and channels. At strength 0, or where nothing is voiced or nothing is
    /// allowed, it is the input itself.
    public static func pitchCorrected(_ audio: Audio, sampleRate: Double, settings: PitchCorrector.Settings,
                                      isCancelled: () -> Bool = { false }) -> Audio? {
        let s = settings.clamped
        let rate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        let count = audio.frameCount
        let left = audio.left.map(Self.finite)
        let right = audio.right.map { $0.map(Self.finite) }
        let clean = Audio(left: left, right: right)
        guard s.amount > 0, s.allowed != 0, count > 0 else { return clean }
        guard let frames = analyse(left: left, right: right, sampleRate: rate, settings: s, isCancelled: isCancelled) else {
            return nil
        }
        guard frames.contains(where: { $0.deviation != 0 }) else { return clean }

        let history = StereoHistory(seconds: 0.08, sampleRate: rate)
        var head = SpliceHead(sampleRate: rate)
        let lead = Int((SpliceHead.delaySeconds * rate).rounded())
        let glide = s.speed < 0.001 ? 1 : 1 - Foundation.exp(-1 / (s.speed * rate))
        var outLeft = [Float](repeating: 0, count: count)
        var outRight: [Float]? = right == nil ? nil : [Float](repeating: 0, count: count)
        var correction = 0.0
        var frame = -1
        for i in 0..<(count + lead) {
            if i % cancelStride == 0, isCancelled() { return nil }
            // The head reads about `lead` frames behind what it is given: the correction it plays
            // now belongs to that frame of the input.
            let reading = i - lead
            while frame + 1 < frames.count, frames[frame + 1].time <= reading { frame += 1 }
            let wanted = frame >= 0 ? frames[frame].deviation : 0
            let period = frame >= 0 ? frames[frame].period : 0
            correction += (wanted - correction) * glide
            let ratio = Foundation.pow(2, correction * s.amount / 12)
            let l = i < count ? left[i] : 0
            let r = i < count ? (right?[i] ?? l) : 0
            history.push(l, r)
            head.advance(ratio: ratio, period: period)
            let (oL, oR) = head.read(history)
            guard reading >= 0 else { continue }
            outLeft[reading] = oL.isFinite ? oL : 0
            if outRight != nil { outRight?[reading] = oR.isFinite ? oR : 0 }
        }
        return Audio(left: outLeft, right: outRight)
    }

    /// One analysis: where its window's middle falls (a frame of the input), the period it heard
    /// (input frames, 0 for none) and the correction it asks for, in semitones.
    struct Analysis: Equatable {
        var time: Int
        var period: Double
        var deviation: Double
    }

    /// The tracker over the whole stretch, then each voiced analysis's note centre, its target and
    /// the correction that reaches it. Nil when cancelled.
    static func analyse(left: [Float], right: [Float]?, sampleRate rate: Double, settings s: PitchCorrector.Settings,
                        isCancelled: () -> Bool) -> [Analysis]? {
        let tracker = PitchTracker(sampleRate: rate)
        // The tracker's window in input frames, as it builds it: two periods of its lowest pitch.
        let window = 2 * Int(rate / Double(tracker.factor) / PitchTracker.minimumHertz) * tracker.factor
        var times: [Int] = [], periods: [Double] = [], notes: [Double] = []
        for i in 0..<left.count {
            if i % cancelStride == 0, isCancelled() { return nil }
            let sample = right.map { 0.5 * (left[i] + $0[i]) } ?? left[i]
            guard tracker.push(sample) else { continue }
            times.append(i - window / 2)
            periods.append(tracker.period)
            let note = tracker.period > 0 ? 69 + 12 * Foundation.log2(tracker.frequency / s.reference) : Double.nan
            notes.append(note.isFinite ? note : .nan)
        }
        let reach = Swift.max(1, Int((vibratoSeconds * rate / Double(tracker.hop)).rounded()))
        let patience = Int(PitchCorrector.release * rate) / tracker.hop + 1
        var analyses: [Analysis] = []
        analyses.reserveCapacity(times.count)
        var held: Int?
        var lastDeviation = 0.0, lastPeriod = 0.0
        var silent = 0
        for k in 0..<times.count {
            let note = notes[k]
            guard !note.isNaN else {
                // A consonant or a breath: the correction holds through a short gap and lets go after
                // `PitchCorrector.release`, as the insert does.
                silent += 1
                if silent >= patience {
                    held = nil
                    lastDeviation = 0
                    lastPeriod = 0
                }
                analyses.append(Analysis(time: times[k], period: lastPeriod, deviation: lastDeviation))
                continue
            }
            if silent >= patience { held = nil }
            silent = 0
            var total = 0.0, counted = 0.0
            var j = k
            while j >= 0, k - j <= reach, !notes[j].isNaN {
                if Swift.abs(notes[j] - note) <= centreSpan { total += notes[j]; counted += 1 }
                j -= 1
            }
            j = k + 1
            while j < times.count, j - k <= reach, !notes[j].isNaN {
                if Swift.abs(notes[j] - note) <= centreSpan { total += notes[j]; counted += 1 }
                j += 1
            }
            let centre = counted > 0 ? total / counted : note
            guard let target = choose(near: centre, held: held, settings: s) else {
                held = nil
                lastDeviation = 0
                analyses.append(Analysis(time: times[k], period: periods[k], deviation: 0))
                continue
            }
            held = target
            let deviation = Swift.min(Swift.max(pitch(of: target, s) - centre, -PitchCorrector.reach), PitchCorrector.reach)
            lastDeviation = deviation.isFinite ? deviation : 0
            lastPeriod = periods[k]
            analyses.append(Analysis(time: times[k], period: periods[k], deviation: lastDeviation))
        }
        return analyses
    }

    /// The nearest allowed note to `note`, keeping `held` unless another is clearly nearer
    /// (`PitchCorrector.hysteresis`), as the insert chooses.
    static func choose(near note: Double, held: Int?, settings s: PitchCorrector.Settings) -> Int? {
        guard s.allowed != 0, note.isFinite else { return nil }
        let base = Int(note.rounded(.down))
        var best: Int?
        var bestDistance = Double.greatestFiniteMagnitude
        for candidate in (base - 4)...(base + 5) where isAllowed(candidate, s.allowed) {
            let distance = Swift.abs(note - pitch(of: candidate, s))
            if distance < bestDistance {
                bestDistance = distance
                best = candidate
            }
        }
        if let held, isAllowed(held, s.allowed), Swift.abs(note - pitch(of: held, s)) <= bestDistance + PitchCorrector.hysteresis {
            return held
        }
        return best
    }

    private static func isAllowed(_ note: Int, _ allowed: UInt16) -> Bool {
        allowed & (1 << UInt16(((note % 12) + 12) % 12)) != 0
    }

    private static func pitch(of note: Int, _ s: PitchCorrector.Settings) -> Double {
        Double(note) + Double(s.cents[((note % 12) + 12) % 12]) / 100
    }

    // MARK: - Granular texture

    /// `audio` as a cloud of grains, fully wet, in two channels, the input's length. Silence stays
    /// silence.
    public static func texture(_ audio: Audio, sampleRate: Double, settings: Texture,
                               isCancelled: () -> Bool = { false }) -> Audio? {
        let rate = sampleRate > 0 && sampleRate.isFinite ? Swift.min(sampleRate, 384_000) : 48_000
        let count = audio.frameCount
        guard count > 0 else { return Audio(left: [], right: []) }
        var grain = Granulator.Settings(size: settings.size, density: settings.density, pitch: settings.pitch,
                                        position: 0, spray: settings.scatter, spread: 0.5, mix: 1).clamped
        let ratio = Foundation.pow(2, grain.pitch / 12)
        // Far enough behind that no grain reads past the newest frame (a grain pitched up gains on
        // the input), and that far plus half a grain's drift is what the output is set back by.
        grain.position = Swift.min(2, grain.spray + grain.size * Swift.max(0, ratio - 1) + 0.005)
        let lag = Swift.max(0, Int(((grain.position + (1 - ratio) * grain.size / 2) * rate).rounded()))
        let granulator = Granulator(sampleRate: rate, settings: grain, seed: settings.seed)
        let total = count + lag
        let block = 1_024
        var bufferLeft = [Float](repeating: 0, count: block)
        var bufferRight = [Float](repeating: 0, count: block)
        var outLeft = [Float](repeating: 0, count: count)
        var outRight = [Float](repeating: 0, count: count)
        var done = 0
        var sinceCheck = 0
        while done < total {
            if sinceCheck >= cancelStride {
                sinceCheck = 0
                if isCancelled() { return nil }
            }
            let frames = Swift.min(block, total - done)
            for i in 0..<frames {
                let index = done + i
                let l = index < count ? Self.finite(audio.left[index]) : 0
                bufferLeft[i] = l
                bufferRight[i] = index < count ? Self.finite(audio.right?[index] ?? l) : 0
            }
            bufferLeft.withUnsafeMutableBufferPointer { l in
                bufferRight.withUnsafeMutableBufferPointer { r in
                    guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                    granulator.process(left: lp, right: rp, frames: frames)
                }
            }
            for i in 0..<frames {
                let at = done + i - lag
                guard at >= 0, at < count else { continue }
                outLeft[at] = bufferLeft[i].isFinite ? bufferLeft[i] : 0
                outRight[at] = bufferRight[i].isFinite ? bufferRight[i] : 0
            }
            done += frames
            sinceCheck += frames
        }
        return Audio(left: outLeft, right: outRight)
    }

    @inline(__always)
    private static func finite(_ value: Float) -> Float { value.isFinite ? value : 0 }
}
