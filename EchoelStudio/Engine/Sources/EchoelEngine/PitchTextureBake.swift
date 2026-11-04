import EchoelCore
import EchoelDSP
import Foundation

/// The region bake's sound (W3): a stretch of the original file through pitch correction toward
/// the song's key, a granular texture, or both in that order (`RegionBaking`, `OfflineBake`).
/// Pure and off the render thread — the app runs it in a detached task and writes the frames as a
/// new file of the song. Nothing live reaches it: the key, the scale and the tone system are the
/// song's at the region's start, never a body source, so two bakes of the same settings give the
/// same frames.
public enum PitchTextureBake {
    /// The longest preview, in seconds: what the page plays before it bakes.
    public static let previewSeconds = 8.0

    /// The pitch correction's targets: the song's key and scale in its tone system, at its concert
    /// pitch — the insert's own reading (`EffectKernel`'s pitch correction).
    public static func correctorSettings(for context: MusicalContext,
                                         _ correction: RegionBaking.PitchCorrection) -> PitchCorrector.Settings {
        let mask = PitchCorrector.Settings.mask(root: context.root, steps: context.scale.intervals)
        // The tone system's offsets from the key's root; the concert pitch is the reference, so it
        // is not counted twice.
        let table = MusicalContext(root: context.root, tuning: context.tuning).centsTable()
        var cents = SIMD16<Float>.zero
        for (index, value) in table.prefix(12).enumerated() { cents[index] = Float(value) }
        return PitchCorrector.Settings(allowed: mask, cents: cents, reference: context.concertPitch,
                                       speed: correction.retune, amount: correction.strength).clamped
    }

    /// Frames `offset ..< offset + length` of `buffer`, one channel or two; nil when the stretch is
    /// not inside it.
    public static func excerpt(of buffer: SampleBuffer, offset: Int, length: Int) -> OfflineBake.Audio? {
        guard offset >= 0, length > 0, length <= buffer.frameCount - offset else { return nil }
        return buffer.withFrames { values -> OfflineBake.Audio in
            if buffer.channelCount == 2 {
                var left = [Float](repeating: 0, count: length), right = [Float](repeating: 0, count: length)
                for i in 0..<length {
                    left[i] = values[2 * (offset + i)]
                    right[i] = values[2 * (offset + i) + 1]
                }
                return OfflineBake.Audio(left: left, right: right)
            }
            return OfflineBake.Audio(left: Array(values[offset..<(offset + length)]))
        }
    }

    /// `audio` with the bake's edits, correction first. Nil when cancelled or when `bake` holds no edit.
    public static func render(_ audio: OfflineBake.Audio, sampleRate: Double, bake: RegionBaking, context: MusicalContext,
                              isCancelled: () -> Bool = { false }) -> OfflineBake.Audio? {
        guard bake.pitchCorrection != nil || bake.texture != nil else { return nil }
        var sound = audio
        if let correction = bake.pitchCorrection {
            guard let tuned = OfflineBake.pitchCorrected(sound, sampleRate: sampleRate,
                                                         settings: correctorSettings(for: context, correction),
                                                         isCancelled: isCancelled) else { return nil }
            sound = tuned
        }
        if let texture = bake.texture {
            let settings = OfflineBake.Texture(size: texture.size, density: texture.density, scatter: texture.scatter,
                                               pitch: texture.pitch,
                                               seed: UInt64(Swift.min(Swift.max(texture.seed, 0), Int(UInt32.max))))
            guard let grains = OfflineBake.texture(sound, sampleRate: sampleRate, settings: settings,
                                                   isCancelled: isCancelled) else { return nil }
            sound = grains
        }
        return sound
    }

    /// Writes `audio` to a WAV file at `url` in 32-bit float, one channel or two, as Bake Effects does.
    public static func write(_ audio: OfflineBake.Audio, to url: URL, sampleRate: Double) throws {
        let writer = try WAVWriter(url: url, sampleRate: sampleRate, bitDepth: .float32, channels: audio.right == nil ? 1 : 2)
        let right = audio.right ?? audio.left
        try audio.left.withUnsafeBufferPointer { left in
            try right.withUnsafeBufferPointer { other in
                guard let l = left.baseAddress, let r = other.baseAddress else { return }
                try writer.append(left: l, right: r, count: Swift.min(left.count, other.count))
            }
        }
        try writer.finish()
    }
}
