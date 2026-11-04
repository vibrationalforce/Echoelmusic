import Foundation

/// What a region's bake did (W3): pitch correction toward the song's key, a granular texture, or
/// both in that order, rendered off the render thread into a new file of the song. The region
/// plays that file; this record keeps the file it was baked from and the settings, so the bake can
/// be opened again with the same values, baked anew from the original, or reverted.
///
/// Stored as the region's optional `bake` (added inside format 4, 2026-11-04). The baked file
/// starts at frame `sourceOffset` of `source` and runs frame for frame with it, at its rate, so a
/// region on the baked file at `offset` plays what the original plays at `sourceOffset + offset`
/// — a trim or a split of a baked region reverts to the same stretch of the original.
public struct RegionBaking: Codable, Equatable, Sendable {
    /// The file the bake was made from.
    public var source: MediaID
    /// The frame of `source` the baked file's first frame came from.
    public var sourceOffset: Int
    public var pitchCorrection: PitchCorrection?
    public var texture: GrainTexture?

    public init(source: MediaID, sourceOffset: Int, pitchCorrection: PitchCorrection? = nil, texture: GrainTexture? = nil) {
        self.source = source
        self.sourceOffset = sourceOffset
        self.pitchCorrection = pitchCorrection
        self.texture = texture
    }

    /// Notes pulled toward the nearest pitch of the song's key and scale, in its tone system.
    public struct PitchCorrection: Codable, Equatable, Sendable {
        /// How much of the correction applies, 0 … 1 (shown as a percentage).
        public var strength: Double
        /// Seconds the voice takes to arrive at its note, 0 … 0.5; 0 snaps.
        public var retune: Double

        public static let strengthRange: ClosedRange<Double> = 0...1
        public static let retuneRange: ClosedRange<Double> = 0...0.5

        public init(strength: Double = 1, retune: Double = 0.04) {
            self.strength = strength
            self.retune = retune
        }

        public var isValid: Bool {
            strength.isFinite && Self.strengthRange.contains(strength) && retune.isFinite && Self.retuneRange.contains(retune)
        }
    }

    /// A cloud of short grains read around the moment they play.
    public struct GrainTexture: Codable, Equatable, Sendable {
        /// Grain length in seconds, 0.01 … 0.5.
        public var size: Double
        /// 0 … 1: from half a grain at once to three and a half.
        public var density: Double
        /// How far around its moment a grain may read, in seconds, 0 … 0.5.
        public var scatter: Double
        /// Transposition in semitones, −24 … 24.
        public var pitch: Double
        /// The grains' random sequence, 0 … 4294967295: the same seed gives the same texture.
        public var seed: Int

        public static let sizeRange: ClosedRange<Double> = 0.01...0.5
        public static let densityRange: ClosedRange<Double> = 0...1
        public static let scatterRange: ClosedRange<Double> = 0...0.5
        public static let pitchRange: ClosedRange<Double> = -24...24
        public static let seedRange: ClosedRange<Int> = 0...Int(UInt32.max)

        public init(size: Double = 0.08, density: Double = 0.5, scatter: Double = 0.05, pitch: Double = 0, seed: Int = 1) {
            self.size = size
            self.density = density
            self.scatter = scatter
            self.pitch = pitch
            self.seed = seed
        }

        public var isValid: Bool {
            func inside(_ value: Double, _ range: ClosedRange<Double>) -> Bool { value.isFinite && range.contains(value) }
            return inside(size, Self.sizeRange) && inside(density, Self.densityRange) && inside(scatter, Self.scatterRange)
                && inside(pitch, Self.pitchRange) && Self.seedRange.contains(seed)
        }
    }

    /// At least one edit, each inside its ranges, and a first frame inside a file.
    public var isValid: Bool {
        guard pitchCorrection != nil || texture != nil, sourceOffset >= 0 else { return false }
        return (pitchCorrection?.isValid ?? true) && (texture?.isValid ?? true)
    }
}

extension AudioRegion {
    /// The original this region plays, bake or not: the file and the frame of it at `offset`.
    public var original: (media: MediaID, offset: Int) {
        guard let bake else { return (media, offset) }
        return (bake.source, bake.sourceOffset + offset)
    }
}

extension Project {
    /// Whether `region`'s bake names an audio file of the song that holds the region's stretch.
    func bakeFits(_ region: AudioRegion) -> Bool {
        guard let bake = region.bake else { return true }
        guard bake.isValid, let source = mediaFile(bake.source), source.kind == .audio else { return false }
        let (first, overflow) = bake.sourceOffset.addingReportingOverflow(region.offset)
        return !overflow && first >= 0 && region.length <= source.frameCount - first
    }
}
