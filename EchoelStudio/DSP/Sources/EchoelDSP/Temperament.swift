import Foundation

/// Where each of the twelve pitch classes sits, as a tuned voice plays it: lane n (0 = C … 11 = B)
/// holds the cents that pitch class lies away from twelve equal steps at A = 440 Hz, the song's
/// tone system and concert pitch folded into one number (`MusicalContext.centsTable` in Core
/// computes it; this module does not know the song). Lanes 12…15 are unused and stay zero.
///
/// A plain value of sixteen floats: the snapshot carries it to the render thread, and a voice reads
/// one lane at a note-on. Nothing here allocates.
public struct Temperament: Equatable, Sendable {
    /// Twelve equal steps at A = 440 Hz: zero everywhere, the MIDI standard.
    public static let standard = Temperament()

    /// The cents of each pitch class from twelve equal steps at A = 440 Hz.
    public let cents: SIMD16<Float>

    /// The farthest a pitch class may sit from its equal-tempered place, either way. A concert
    /// pitch of 400…480 Hz moves every class by −165…+151 cents and a tone system by at most a
    /// quarter tone more; anything beyond an octave is damage, not a tuning.
    public static let limit: Float = 1_200

    /// A value that is not a number counts as zero, one beyond `limit` as the limit; lanes 12…15
    /// are cleared. Arithmetic only: render-safe.
    public init(cents: SIMD16<Float> = .zero) {
        var lanes = SIMD16<Float>.zero
        for index in 0..<12 {
            let value = cents[index]
            lanes[index] = value.isFinite ? Swift.min(Swift.max(value, -Self.limit), Self.limit) : 0
        }
        self.cents = lanes
    }

    /// The cents of a MIDI pitch's class (any integer; its class is taken modulo 12).
    @inline(__always)
    public func cents(of pitch: Int) -> Float {
        cents[((pitch % 12) + 12) % 12]
    }

    /// The frequency of a MIDI pitch in this temperament, in hertz. Render-safe.
    @inline(__always)
    public func frequency(of pitch: Int) -> Float {
        440 * exp2f((Float(pitch) - 69 + cents(of: pitch) / 100) / 12)
    }

    /// How much faster than at `root` a pitch plays: the ratio of its frequency here to `root`'s
    /// frequency in twelve equal steps at A = 440 Hz. For a sample recorded at `root`, so that a
    /// sample's root note sounds as recorded only where the temperament leaves that class alone.
    /// Render-safe.
    @inline(__always)
    public func ratio(of pitch: Int, from root: Int) -> Double {
        let semitones = Double(pitch - root) + Double(cents(of: pitch)) / 100
        return Foundation.pow(2, semitones / 12)
    }
}
