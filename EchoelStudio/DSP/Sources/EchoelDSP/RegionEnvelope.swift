import Foundation

/// How a region's fade moves between silence and full level — the render side of the song's
/// `FadeCurve`, which this package cannot see. The engine's tests pin that the two agree.
public enum FadeShape: UInt8, Sendable, CaseIterable {
    case linear, equalPower, exponential, sCurve

    /// The steepest slope of the curve over its unit length: a fade of this shape is never shorter
    /// than this many edges, so it never bends harder than the plain region's linear edge.
    public var steepness: Double {
        switch self {
        case .linear: 1
        case .equalPower: Double.pi / 2
        case .exponential: 2
        case .sCurve: 1.5
        }
    }

    /// The level 0…1 at `progress` 0…1 into a fade-in. Render-thread safe.
    @inline(__always)
    public func level(_ progress: Double) -> Double {
        let x = progress > 0 ? (progress < 1 ? progress : 1) : 0
        switch self {
        case .linear: return x
        case .equalPower: return sin(x * Double.pi / 2)
        case .exponential: return x * x
        case .sCurve: return x * x * (3 - 2 * x)
        }
    }
}

/// A region's own level and fades as one stretch of a buffer plays them (AUD-2): the gain, and the
/// fade-in and fade-out lengths in BUFFER frames from the stretch's first frame and up to its last.
/// A fade shorter than the stretch's edge (the click guard every region has), times its curve's
/// steepness, plays over that length instead, so a fade never bends harder than the plain region's edge. Pure; render-thread safe.
public struct RegionEnvelope: Sendable, Equatable {
    public var gain: Float
    public var fadeIn: Double
    public var fadeOut: Double
    public var fadeInShape: FadeShape
    public var fadeOutShape: FadeShape

    public static let unity = RegionEnvelope()

    public init(gain: Float = 1, fadeIn: Double = 0, fadeOut: Double = 0,
                fadeInShape: FadeShape = .linear, fadeOutShape: FadeShape = .linear) {
        self.gain = gain.isFinite ? gain : 0
        self.fadeIn = fadeIn.isFinite && fadeIn > 0 ? fadeIn : 0
        self.fadeOut = fadeOut.isFinite && fadeOut > 0 ? fadeOut : 0
        self.fadeInShape = fadeInShape
        self.fadeOutShape = fadeOutShape
    }

    /// Whether this is the plain region: full level, no fades.
    public var isUnity: Bool { gain == 1 && fadeIn == 0 && fadeOut == 0 }

    /// The level `since` frames after the stretch's first frame and `until` frames before its end,
    /// with `edge` frames of click guard at each end.
    @inline(__always)
    public func level(since: Double, until: Double, edge: Double) -> Float {
        if isUnity {
            // Exactly the plain region's edge, as every build before played it.
            guard edge > 0 else { return 1 }
            let near = since < until ? since : until
            return near < edge ? Float(near / edge) : 1
        }
        var level = 1.0
        if fadeIn > 0 {
            let shortest = edge * fadeInShape.steepness
            let length = fadeIn > shortest ? fadeIn : shortest
            if since < length { level = fadeInShape.level(since / length) }
        } else if edge > 0, since < edge {
            level = since / edge
        }
        if fadeOut > 0 {
            let shortest = edge * fadeOutShape.steepness
            let length = fadeOut > shortest ? fadeOut : shortest
            if until < length { level *= fadeOutShape.level(until / length) }
        } else if edge > 0, until < edge {
            level *= until / edge
        }
        return Float(level) * gain
    }
}
