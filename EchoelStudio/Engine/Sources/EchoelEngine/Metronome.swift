import EchoelDSP
import Foundation

/// How loud the click and the count-in click play, chosen in decibels on this device
/// (2026-11-19, founder: the click's level adjustable, off by default, a quiet start). Its
/// accented downbeat peaks at the chosen level; the other beats 4.4 dB under it.
public enum ClickLevel {
    /// The levels offered, quietest first.
    public static let choices: [Double] = [-36, -30, -24, -18, -12, -6]
    /// The level a new install starts at: quiet (before 2026-11-19 the click played at −10.5 dB).
    public static let standard: Double = -24

    /// The gain for `decibels`, held between −60 dB and 0 dB; not a number is the standard level.
    public static func gain(decibels: Double) -> Float {
        let db = decibels.isFinite ? Swift.min(Swift.max(decibels, -60), 0) : standard
        return Float(pow(10, db / 20))
    }

    /// "−24 dB", with a true minus sign.
    public static func title(_ decibels: Double) -> String {
        let whole = Int(decibels.rounded())
        return whole < 0 ? "\u{2212}\(-whole) dB" : "\(whole) dB"
    }
}

/// The click: a short decaying sine burst, accented on the downbeat — or the musician's own
/// sample (`ClickSound`), handed to `render` per chunk. A value type owned by the render thread;
/// nothing allocates, and it holds no reference to a sample.
public struct Metronome: Sendable {
    public var isEnabled = true
    public var level: Float = ClickLevel.gain(decibels: ClickLevel.standard)

    private var phase: Float = 0
    private var increment: Float = 0
    private var amplitude: Float = 0
    private var remaining = 0
    /// Frames of the output since the sample started; -1 while no sample sounds.
    private var sampleElapsed: Int64 = -1
    private var sampleGain: Float = 0
    private let sampleRate: Float
    private let decay: Float

    public init(sampleRate: Float = 48_000) {
        self.sampleRate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        // About −60 dB over the 30 ms burst.
        decay = expf(logf(0.001) / (0.03 * self.sampleRate))
    }

    /// Starts a click: the sample when one is chosen (`sampled`), else the sine burst.
    public mutating func trigger(accent: Bool, sampled: Bool = false) {
        guard isEnabled else { return }
        let gain: Float = accent ? 1 : 0.6
        if sampled {
            sampleElapsed = 0
            sampleGain = gain
        } else {
            phase = 0
            increment = (accent ? 1_760 : 1_100) / sampleRate
            amplitude = gain
            remaining = Int(0.03 * sampleRate)
        }
    }

    /// Whether a click still sounds: the sound may only change while this is false
    /// (`ClickSound.drain`), so no tail is ever cut mid-waveform.
    public var isSounding: Bool { remaining > 0 || sampleElapsed >= 0 }

    /// Forgets a click whose tail no longer renders (the song stopped), so it is not heard when
    /// the song plays again and the sound may change meanwhile.
    public mutating func silence() {
        remaining = 0
        sampleElapsed = -1
    }

    /// Adds the click into both channels: `sound` when the musician chose one, else the sine burst.
    @inline(__always)
    public mutating func render(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, range: Range<Int>,
                                sound: SampleBuffer? = nil) {
        if let sound { renderSample(sound, left: left, right: right, range: range) }
        guard remaining > 0 else { return }
        for i in range {
            guard remaining > 0 else { return }
            let s = sinf(2 * Float.pi * phase) * amplitude * level
            left[i] += s
            right[i] += s
            phase += increment
            if phase >= 1 { phase -= 1 }
            amplitude *= decay
            remaining -= 1
        }
    }

    /// The sample's first `ClickSound.maximumSeconds`, read at the output's rate, with a guard at
    /// its edges and, when it is cut there, a fade over its end.
    private mutating func renderSample(_ sound: SampleBuffer, left: UnsafeMutablePointer<Float>,
                                       right: UnsafeMutablePointer<Float>, range: Range<Int>) {
        guard sampleElapsed >= 0, !range.isEmpty, sound.sampleRate.isFinite, sound.sampleRate > 0 else { return }
        let step = sound.sampleRate / Double(sampleRate)
        let longest = ClickSound.maximumSeconds * sound.sampleRate
        let cut = Double(sound.frameCount) > longest
        let length = cut ? longest : Double(sound.frameCount)
        // Only a cut end fades; a short tick plays whole, at full level.
        let envelope = RegionEnvelope(gain: sampleGain * level, fadeOut: cut ? ClickSound.fadeOutSeconds * sound.sampleRate : 0)
        sound.add(intoLeft: left + range.lowerBound, right: right + range.lowerBound, count: range.count,
                  elapsed: sampleElapsed, step: step, offset: 0, length: length,
                  fade: ClickSound.edgeSeconds * sound.sampleRate, envelope: envelope)
        sampleElapsed += Int64(range.count)
        if Double(sampleElapsed) * step >= length { sampleElapsed = -1 }
    }
}
