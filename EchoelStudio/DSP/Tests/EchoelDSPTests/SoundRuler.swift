import Foundation

/// A ruler for one-shot sounds, for tests: what a hit measures as, by fixed definitions, so a
/// sound's shape can be asserted in numbers instead of by a stored waveform.
///
/// The level is the RMS over 5 ms, read every 1 ms. From it: the attack (from the first step over
/// 5 % of the peak to the peak), the fall by 20 and by 40 dB (the last step still at or above that
/// level, counted from the peak), and the length (the last step at or above −60 dB). Bursts are
/// counted on a finer level — the mean of |x| over 2 ms, per sample, in the first 80 ms: a burst
/// begins when the level passes 30 % of its peak and ends when it falls under 12 %. Brightness is
/// the number of upward zero crossings per second, early (the first 20 ms) and late (80 to 140 ms
/// after the start).
enum SoundRuler {
    struct Reading: Equatable {
        /// Milliseconds.
        var attack: Double
        var fall20: Double
        var fall40: Double
        var seconds: Double
        var bursts: Double
        /// Upward zero crossings per second.
        var crossingsEarly: Double
        var crossingsLate: Double
    }

    /// Nil for a signal shorter than one 5 ms step, or silent.
    static func measure(_ samples: [Float], sampleRate: Double = 48_000) -> Reading? {
        let window = Int(0.005 * sampleRate)
        let hop = Int(0.001 * sampleRate)
        guard window > 0, hop > 0, samples.count >= window else { return nil }
        let count = (samples.count - window) / hop + 1
        var steps = [Double](repeating: 0, count: count)
        for step in 0..<count {
            var sum = 0.0
            for sample in samples[(step * hop)..<(step * hop + window)] {
                sum += Double(sample) * Double(sample)
            }
            steps[step] = (sum / Double(window)).squareRoot()
        }
        guard let peak = steps.max(), peak > 0, let top = steps.firstIndex(of: peak) else { return nil }
        let start = steps.firstIndex { (level: Double) -> Bool in level > 0.05 * peak } ?? 0
        let last20 = steps.lastIndex { (level: Double) -> Bool in level >= peak * 0.1 } ?? top
        let last40 = steps.lastIndex { (level: Double) -> Bool in level >= peak * 0.01 } ?? top
        let last60 = steps.lastIndex { (level: Double) -> Bool in level >= peak * 0.001 } ?? top
        let early = start * hop
        return Reading(attack: Double(top - start),
                       fall20: Double(last20 - top + 1),
                       fall40: Double(last40 - top + 1),
                       seconds: Double(last60 + 5) / 1_000,
                       bursts: Double(bursts(in: samples, sampleRate: sampleRate)),
                       crossingsEarly: crossings(in: samples, from: early, frames: Int(0.02 * sampleRate), sampleRate: sampleRate),
                       crossingsLate: crossings(in: samples, from: early + Int(0.08 * sampleRate), frames: Int(0.06 * sampleRate),
                                                sampleRate: sampleRate))
    }

    /// The mean of several readings, field by field: one hit of noise is one draw, and its numbers
    /// move with the draw.
    static func mean(_ readings: [Reading]) -> Reading {
        var sum = Reading(attack: 0, fall20: 0, fall40: 0, seconds: 0, bursts: 0, crossingsEarly: 0, crossingsLate: 0)
        guard !readings.isEmpty else { return sum }
        for reading in readings {
            sum.attack += reading.attack
            sum.fall20 += reading.fall20
            sum.fall40 += reading.fall40
            sum.seconds += reading.seconds
            sum.bursts += reading.bursts
            sum.crossingsEarly += reading.crossingsEarly
            sum.crossingsLate += reading.crossingsLate
        }
        let count = Double(readings.count)
        return Reading(attack: sum.attack / count, fall20: sum.fall20 / count, fall40: sum.fall40 / count,
                       seconds: sum.seconds / count, bursts: sum.bursts / count,
                       crossingsEarly: sum.crossingsEarly / count, crossingsLate: sum.crossingsLate / count)
    }

    private static func bursts(in samples: [Float], sampleRate: Double) -> Int {
        let window = Swift.max(1, Int(0.002 * sampleRate))
        guard samples.count >= window else { return 0 }
        var fine = [Double](repeating: 0, count: samples.count - window + 1)
        var sum = 0.0
        for index in 0..<window { sum += Double(Swift.abs(samples[index])) }
        fine[0] = sum
        for index in 1..<fine.count {
            sum += Double(Swift.abs(samples[index + window - 1])) - Double(Swift.abs(samples[index - 1]))
            fine[index] = sum
        }
        guard let peak = fine.max(), peak > 0 else { return 0 }
        let begin = fine.firstIndex { (level: Double) -> Bool in level > 0.05 * peak } ?? 0
        let end = Swift.min(fine.count, begin + Int(0.08 * sampleRate))
        var found = 0
        var armed = true
        for index in begin..<end {
            let level = fine[index] / peak
            if armed, level > 0.3 {
                found += 1
                armed = false
            } else if !armed, level < 0.12 {
                armed = true
            }
        }
        return found
    }

    private static func crossings(in samples: [Float], from start: Int, frames: Int, sampleRate: Double) -> Double {
        let first = Swift.min(Swift.max(start, 0), samples.count)
        let end = Swift.min(first + Swift.max(frames, 0), samples.count)
        guard end - first >= 2 else { return 0 }
        var found = 0
        for index in first..<(end - 1) where samples[index] < 0 && samples[index + 1] >= 0 {
            found += 1
        }
        return Double(found) / (Double(end - first) / sampleRate)
    }
}
