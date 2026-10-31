import Foundation

/// Stereo width by mid and side: the side signal (the difference between left and right) is
/// scaled, the mid (their average) stays — 0 folds to mono, 1 leaves the sound as it is, 2
/// doubles the side. Ported from the earlier app's `EchoelStereoWidener` (EchoelLoFiFX) for Echoel
/// Studio 1.0, as a value of settings and a render-thread processor like `Chorus`.
///
/// The width glides in ~10 ms instead of stepping. A bad sample comes out as silence. Owned by
/// the render thread: set `settings` and call `process` from that thread. Nothing allocates.
public final class StereoWidth: @unchecked Sendable {
    public struct Settings: Equatable, Codable, Sendable {
        /// 0 (mono) … 1 (unchanged) … 2 (twice the side).
        public var width: Double

        public init(width: Double = 1.4) {
            self.width = width
        }

        /// The width inside its range; a non-finite one takes the default.
        public var clamped: Settings {
            Settings(width: width.isFinite ? Swift.min(Swift.max(width, 0), 2) : Settings().width)
        }
    }

    public var settings: Settings {
        didSet { settings = settings.clamped }
    }

    public let sampleRate: Double
    private var widthNow: Float
    private let glide: Float

    public init(sampleRate: Double, settings: Settings = Settings()) {
        self.sampleRate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        glide = Float(1 - Foundation.exp(-1 / (Compressor.gainGlideSeconds * self.sampleRate)))
        let start = settings.clamped
        self.settings = start
        widthNow = Float(start.width)
    }

    public func reset() {
        widthNow = Float(settings.width)
    }

    /// Processes `frames` samples in place.
    public func process(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        let widthTarget = Float(settings.width)
        var width = widthNow
        for i in 0..<frames {
            width = Compressor.glided(width, toward: widthTarget, by: glide)
            let inLeft = left[i], inRight = right[i]
            guard inLeft.isFinite, inRight.isFinite else {
                left[i] = 0
                right[i] = 0
                continue
            }
            let mid = (inLeft + inRight) * 0.5
            let side = (inLeft - inRight) * 0.5 * width
            left[i] = mid + side
            right[i] = mid - side
        }
        widthNow = width
    }
}
