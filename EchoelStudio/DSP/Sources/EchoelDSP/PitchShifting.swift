import Foundation

/// The last few tens of milliseconds of a stereo input, for read heads that play it back at
/// another speed. Allocated in `init`; `push` and the reads never allocate.
final class StereoHistory: @unchecked Sendable {
    let capacity: Int
    private let left: UnsafeMutablePointer<Float>
    private let right: UnsafeMutablePointer<Float>
    /// Where the newest sample sits.
    private(set) var newest = 0

    init(seconds: Double, sampleRate: Double) {
        capacity = Swift.max(64, Int(seconds * sampleRate))
        left = .allocate(capacity: capacity)
        left.initialize(repeating: 0, count: capacity)
        right = .allocate(capacity: capacity)
        right.initialize(repeating: 0, count: capacity)
    }

    deinit {
        left.deallocate()
        right.deallocate()
    }

    func reset() {
        left.update(repeating: 0, count: capacity)
        right.update(repeating: 0, count: capacity)
        newest = 0
    }

    /// Writes the next sample pair; it becomes distance 0.
    @inline(__always)
    func push(_ l: Float, _ r: Float) {
        newest = newest + 1 < capacity ? newest + 1 : 0
        left[newest] = l
        right[newest] = r
    }

    /// Both sides `distance` samples behind the newest, linearly interpolated.
    @inline(__always)
    func read(_ distance: Double) -> (Float, Float) {
        let back = Swift.min(Swift.max(distance.isFinite ? distance : 0, 0), Double(capacity - 2))
        var position = Double(newest) - back
        if position < 0 { position += Double(capacity) }
        let index = Swift.min(Int(position), capacity - 1)
        let fraction = Float(position - Double(index))
        let next = index + 1 < capacity ? index + 1 : 0
        return (left[index] + (left[next] - left[index]) * fraction,
                right[index] + (right[next] - right[index]) * fraction)
    }
}

/// A read head on a `StereoHistory` that plays it `ratio` times as fast: it drifts by `1 − ratio`
/// samples per sample, and when it leaves its window it jumps back by whole periods of the input
/// and cross-fades from where it was. Two heads a whole number of periods apart read the same
/// point of the waveform, so the splice is in phase and inaudible on a held note; without a
/// pitch (a consonant, a chord) it jumps half its window. At `ratio` 1 the head stands still — a
/// plain delay, no comb, no flutter. This is the pitch-synchronous form of the two-tap shifter the
/// earlier app's harmonizer used, whose fixed half-window cross-fade combed a steady tone.
struct SpliceHead {
    /// The window the head stays in, in seconds behind the newest sample. Its lower edge is wide
    /// enough that an octave up still cannot overtake the input during a cross-fade.
    static let nearest = 0.008
    static let farthest = 0.030
    static let fadeSeconds = 0.006
    /// The mean delay a shifted voice carries.
    static var delaySeconds: Double { (nearest + farthest) / 2 }

    private let lower: Double
    private let upper: Double
    private let centre: Double
    private let fadeLength: Int
    private(set) var distance: Double
    private var previous: Double
    private var fade: Int

    init(sampleRate: Double) {
        lower = Self.nearest * sampleRate
        upper = Self.farthest * sampleRate
        centre = (lower + upper) / 2
        fadeLength = Swift.max(1, Int(Self.fadeSeconds * sampleRate))
        distance = centre
        previous = centre
        fade = fadeLength
    }

    mutating func reset() {
        distance = centre
        previous = centre
        fade = fadeLength
    }

    /// One sample on: moves by the ratio, and splices when the head has left its window.
    /// `period` is the input's, in samples, or 0 when it has none.
    @inline(__always)
    mutating func advance(ratio: Double, period: Double) {
        let move = 1 - ratio
        distance += move
        previous += move
        guard fade >= fadeLength, distance < lower || distance > upper else { return }
        let step = period > 0 && period.isFinite ? period : (upper - lower) / 2
        let toward: Double = centre > distance ? 1 : -1
        var count = Swift.max(1, ((centre - distance) * toward / step).rounded())
        while count > 1, !(lower...upper).contains(distance + toward * count * step) { count -= 1 }
        previous = distance
        distance += toward * count * step
        fade = 0
    }

    /// The head's sound now, cross-fading from the old place while a splice runs.
    @inline(__always)
    mutating func read(_ history: StereoHistory) -> (Float, Float) {
        let now = history.read(distance)
        guard fade < fadeLength else { return now }
        fade += 1
        let weight = Float(fade) / Float(fadeLength)
        let old = history.read(previous)
        return (old.0 + (now.0 - old.0) * weight, old.1 + (now.1 - old.1) * weight)
    }
}
