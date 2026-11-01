import Foundation

/// The click hunt's measuring device (AUD, 2026-11-01): finds the samples where a rendered signal
/// jumps further than the sound around it can carry.
///
/// It reads the second difference, x[n] − 2·x[n−1] + x[n−2], a high-pass that keeps a smooth
/// waveform small (a sine of amplitude A at ω radians per sample gives A·(2 − 2·cos ω)) and turns a
/// step into a spike. A sample is a candidate when its spike stands more than `ratio` times above
/// the tallest spike within `window` samples on either side of it, leaving out the `guardBand`
/// samples next to it, which a step's own spikes share. The neighbourhood carries the signal's own
/// sharp edges, so music is not mistaken for a click: a band-limited saw resets every period with
/// the same edge, noise is rough throughout, a note that swells has taller edges after its start
/// than before it and one that dies has them before. 2,048 samples on either side hold a whole
/// period of every pitch down to 23 Hz at 48 kHz.
///
/// A step into a bright sound hides in that sound's own rough second difference (an FM tone whose
/// index jumps, first sweep). The fourth difference finds it: it rises 24 dB an octave where the
/// second rises 12, so a tone's partials a few kilohertz up fall far below a step, whose energy
/// reaches Nyquist. The same ratio makes it a candidate.
///
/// A candidate is then measured where its second difference is largest, and judged by its kind.
/// A STEP in value leaves a pair of spikes, +s then −s: it counts from `stepFloor` of the loudest
/// sample nearby. A KINK — a ramp that starts or stops, one spike alone — is far quieter than a
/// step of the same height (its spectrum falls 12 dB an octave faster) and counts from
/// `kinkFloor`: a linear fade of a millisecond or more on a full-level sound, the house rule the
/// envelopes keep (`Envelope`, at least 1 ms a segment) and the regions' 64-frame edges, stays
/// under it. Both need `absoluteFloor` too, −60 dBFS: the kit's voices stop where they fall below
/// −60 dB, a last step of −67 dBFS no speaker plays audibly over anything — the hunt is for clicks
/// a musician hears (first sweep, 2026-11-01).
///
/// Two clicks within a window of each other hide each other there, and a click at every block
/// boundary — the classic crackle — hides in a crowd of its own kind. Smooth test material
/// closes that gap: a sine of amplitude A at ω radians per sample bends at most A·(2 − 2·cos ω)
/// a sample, so given that as `expectedRoughness` every sample is measured against it instead of
/// against its neighbours (`ClickDetector.forSine`).
///
/// A test tool, not the app's: it allocates, and it reads a finished render.
struct ClickDetector {
    struct Click: Equatable, CustomStringConvertible {
        /// The sample the step or kink lands on.
        let index: Int
        /// The second difference there: a step's height, a kink's change of slope.
        let size: Float
        /// Whether the value stepped (a pair of spikes) rather than the slope (one).
        let isStep: Bool
        /// The size against the loudest sample nearby.
        let share: Float

        var description: String {
            String(format: "sample %d: %@ %.5f (%.1f %% of the level)", index, isStep ? "step" : "kink", size, share * 100)
        }
    }

    var window = 2_048
    var guardBand = 3
    var ratio: Float = 4
    var absoluteFloor: Float = 1e-3
    var stepFloor: Float = 0.01
    var kinkFloor: Float = 0.025
    /// For smooth material: the largest second difference the sound itself has, which then
    /// replaces the neighbourhood (see the type's note). Nil for music.
    var expectedRoughness: Float?

    /// A detector for material made of sines no higher than `hertz` and no louder than
    /// `amplitude`, at `sampleRate`.
    static func forSine(hertz: Double, amplitude: Float, sampleRate: Double = 48_000) -> ClickDetector {
        var detector = ClickDetector()
        let omega = 2 * Double.pi * hertz / sampleRate
        detector.expectedRoughness = amplitude * Float(2 - 2 * cos(omega))
        return detector
    }

    /// Every click in `signal`, one per step (a step's spikes count once), in order.
    func clicks(in signal: [Float]) -> [Click] {
        let count = signal.count
        guard count > 4, window > guardBand else { return [] }
        var second = [Float](repeating: 0, count: count)
        var levels = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let x = signal[i]
            levels[i] = x.isFinite ? Swift.abs(x) : .infinity
            guard i >= 2 else { continue }
            let d = x - 2 * signal[i - 1] + signal[i - 2]
            second[i] = d.isFinite ? d : .infinity
        }
        var spikes = [Float](repeating: 0, count: count)
        var sharp = [Float](repeating: 0, count: count)
        for i in 0..<count {
            spikes[i] = Swift.abs(second[i])
            guard i >= 4 else { continue }
            let d = second[i] - 2 * second[i - 1] + second[i - 2]
            sharp[i] = d.isFinite ? Swift.abs(d) : .infinity
        }
        let spikesAround = Neighbourhood(spikes, window: window, guardBand: guardBand)
        let sharpAround = Neighbourhood(sharp, window: window, guardBand: guardBand)
        let loudest = Self.slidingMaximum(levels, width: 2 * window + 1)

        var found: [Click] = []
        for i in 2..<count {
            let candidate: Bool
            if let expectedRoughness {
                candidate = spikes[i] > ratio * expectedRoughness
            } else {
                candidate = spikes[i] > ratio * spikesAround.largest(around: i)
                    || sharp[i] > ratio * sharpAround.largest(around: i)
            }
            guard candidate else { continue }
            // The fourth difference rings a few samples after its step: measure where the second
            // difference is largest, from three samples back.
            var at = i
            for j in Swift.max(2, i - guardBand)...i where spikes[j] > spikes[at] { at = j }
            let size = spikes[at]
            let next = at + 1 < count ? second[at + 1] : 0
            let isStep = second[at] * next < 0 && Swift.abs(next) >= 0.5 * size
            let level = loudest[Swift.max(0, at - window)]
            let floor = Swift.max(absoluteFloor, (isStep ? stepFloor : kinkFloor) * level)
            guard size > floor else { continue }
            let click = Click(index: at, size: size, isStep: isStep, share: level > 0 ? size / level : .infinity)
            if let last = found.last, at - last.index <= guardBand {
                if click.size > last.size {
                    found[found.count - 1] = Click(index: last.index, size: click.size, isStep: click.isStep || last.isStep,
                                                   share: click.share)
                }
            } else {
                found.append(click)
            }
        }
        return found
    }

    /// The largest value within `window` samples on either side of a sample, the `guardBand`
    /// samples next to it left out.
    private struct Neighbourhood {
        let window: Int
        let guardBand: Int
        let count: Int
        /// `ahead[i]` is the largest value in i ..< i + window − guardBand; `upTo[i]` in 0 ... i.
        let ahead: [Float]
        let upTo: [Float]

        init(_ values: [Float], window: Int, guardBand: Int) {
            self.window = window
            self.guardBand = guardBand
            count = values.count
            ahead = ClickDetector.slidingMaximum(values, width: window - guardBand)
            var running = values
            for i in 1..<Swift.max(values.count, 1) { running[i] = Swift.max(running[i - 1], values[i]) }
            upTo = running
        }

        func largest(around i: Int) -> Float {
            let left: Float
            if i - window >= 0 {
                left = ahead[i - window]
            } else {
                left = i - guardBand - 1 >= 0 ? upTo[i - guardBand - 1] : 0
            }
            let right = i + guardBand + 1 < count ? ahead[i + guardBand + 1] : 0
            return Swift.max(left, right)
        }
    }

    /// The clicks of both sides of a stereo render, each side's own.
    func clicks(left: [Float], right: [Float]) -> (left: [Click], right: [Click]) {
        (clicks(in: left), clicks(in: right))
    }

    /// `result[i]` is the largest of `values[i ..< min(i + width, count)]`, for every `i`, in linear
    /// time (van Herk / Gil-Werman: maxima from the start and from the end of each block of `width`).
    static func slidingMaximum(_ values: [Float], width: Int) -> [Float] {
        let count = values.count
        guard count > 0, width > 1 else { return values }
        var fromStart = values
        var fromEnd = values
        var blockStart = 0
        while blockStart < count {
            let blockEnd = Swift.min(blockStart + width, count)
            for i in (blockStart + 1)..<blockEnd { fromStart[i] = Swift.max(fromStart[i - 1], values[i]) }
            var i = blockEnd - 2
            while i >= blockStart {
                fromEnd[i] = Swift.max(fromEnd[i + 1], values[i])
                i -= 1
            }
            blockStart = blockEnd
        }
        var result = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let last = Swift.min(i + width, count) - 1
            // In one block the window runs from `i` to that block's end: the maximum from the end
            // is all of it, and the one from the start would reach back before `i`.
            result[i] = i / width == last / width ? fromEnd[i] : Swift.max(fromEnd[i], fromStart[last])
        }
        return result
    }
}
