import Foundation

/// The rules of the camera layer behind the drawn sky (sky source S2, founder 2026-10-31: "a good
/// picture even when it is dark … automatic, without the musician needing to know anything").
/// The drawn sky is the picture; the camera only joins it, and only as far as it carries signal.
/// Pure decisions, so every threshold is a tested number instead of a guess inside a capture queue:
///
/// - Exposure: automatic until the scene is dark, then the longest exposure the camera's format
///   allows at its highest gain; back to automatic once it is bright again (hysteresis, so a
///   passing headlight does not make it flap).
/// - Stacking: frames are averaged, each new one weighted 1/(n+1) down to a floor, so noise falls
///   while a moving scene still updates; the stack is aligned by the phone's own attitude change
///   between frames and started over after a turn larger than a few degrees.
/// - Layer: invisible below a noise floor, fading in up to a ceiling as the stacked image brightens.
public enum SkyNightCamera {
    public enum Exposure: Equatable, Sendable {
        /// The camera's own automatic exposure.
        case automatic
        /// The longest exposure of the active format at its highest ISO.
        case longest
    }

    /// Mean luma (0 … 1) under which automatic exposure has nothing left to give.
    public static let darkLuma = 0.08
    /// Mean luma above which the long exposure is not needed any more.
    public static let brightLuma = 0.45

    public static func nextExposure(current: Exposure, luma: Double) -> Exposure {
        guard luma.isFinite else { return current }
        switch current {
        case .automatic: return luma < darkLuma ? .longest : .automatic
        case .longest: return luma > brightLuma ? .automatic : .longest
        }
    }

    /// Below this the stacked image is sensor noise: the layer stays away and the drawn sky is all.
    public static let noiseFloorLuma = 0.012
    /// From here on the layer shows at its ceiling.
    public static let fullLuma = 0.12
    /// The layer never covers the drawn stars completely.
    public static let maximumOpacity = 0.8

    /// How strongly the camera layer shows, from the stacked image's mean luma.
    public static func layerOpacity(luma: Double) -> Double {
        guard luma.isFinite, luma > noiseFloorLuma else { return 0 }
        let ramp = Swift.min(1, (luma - noiseFloorLuma) / (fullLuma - noiseFloorLuma))
        return ramp * maximumOpacity
    }

    /// The weight of the newest frame once `stacked` frames are in the average: 1, ½, ⅓ … down to ⅛.
    public static func newFrameWeight(stacked: Int) -> Double {
        let n = Swift.max(0, stacked)
        return Swift.max(1.0 / 8, 1.0 / Double(n + 1))
    }

    /// A turn larger than this between two frames starts the stack over.
    public static let restartDegrees = 3.0

    /// How far the view moved between two frames, in degrees along the old frame's right and up
    /// (the picture's content moves the other way). Nil when it moved more than `restartDegrees`,
    /// rolled by more than that, or the vectors are degenerate — the stack starts over then.
    public static func turn(fromForward oldForward: SkyVector, up oldUp: SkyVector,
                            toForward newForward: SkyVector, up newUp: SkyVector) -> (right: Double, up: Double)? {
        guard let f0 = oldForward.normalized, let f1 = newForward.normalized,
              let right0 = f0.cross(oldUp).normalized, let up1 = newUp.normalized else { return nil }
        let up0 = right0.cross(f0)
        let right = asin(Swift.min(1, Swift.max(-1, f1.dot(right0)))) * 180 / .pi
        let up = asin(Swift.min(1, Swift.max(-1, f1.dot(up0)))) * 180 / .pi
        let roll = asin(Swift.min(1, Swift.max(-1, up1.dot(right0)))) * 180 / .pi
        guard (right * right + up * up).squareRoot() <= restartDegrees, abs(roll) <= restartDegrees else { return nil }
        return (right, up)
    }

    /// The drawn sky's field of view across the screen's shorter side so that it matches a camera
    /// image shown aspect-filled: `cameraLongSideDegrees` is the camera's field along its sensor's
    /// long side, the image `imageAspect` long/short, the screen `screenAspect` long/short.
    public static func matchingFieldOfView(cameraLongSideDegrees: Double, imageAspect: Double,
                                           screenAspect: Double) -> Double? {
        guard cameraLongSideDegrees.isFinite, cameraLongSideDegrees > 1, cameraLongSideDegrees < 179,
              imageAspect.isFinite, imageAspect >= 1, screenAspect.isFinite, screenAspect >= 1 else { return nil }
        let halfLong = tan(cameraLongSideDegrees * .pi / 360)
        // Aspect fill: whichever side of the image fits the screen exactly decides the scale.
        let shortVisible: Double = screenAspect >= imageAspect
            ? halfLong / screenAspect          // the long sides match; the short side is cropped
            : halfLong / imageAspect           // the short sides match; the long side is cropped
        return 2 * atan(shortVisible) * 180 / .pi
    }
}
