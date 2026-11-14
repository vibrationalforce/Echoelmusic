import Foundation

/// The rules of the camera layer behind the drawn sky (sky source S2, founder 2026-10-31: "a good
/// picture even when it is dark … automatic, without the musician needing to know anything").
/// The drawn sky is the picture; the camera only joins it, and only as far as it carries signal.
/// Pure decisions, so every threshold is a tested number instead of a guess inside a capture queue:
///
/// - Exposure: automatic until automatic exposure is near its limit and the picture is still dark;
///   then the exposure is set by hand and follows the picture fluidly — the light, the exposure time
///   and so the frame rate each change by at most one and a half times per step, a step only after
///   half a second and three frames (a new exposure shows a few frames late), still near the target,
///   time preferred to gain. Back to automatic once automatic exposure can carry the picture easily
///   (the time is first brought down to automatic's), or after two clipped frames in a row (a light
///   switched on; one passing light is not enough).
/// - Focus: holds where autofocus settled while the exposure is set by hand: in the dark it hunts.
/// - Picture: the shadow lift and the noise reduction grow with the exposure, from 0 at the takeover.
/// - Stacking: frames are averaged, each new one weighted 1/(n+1) down to a floor, so noise falls
///   while a moving scene still updates; the stack is aligned by the phone's own attitude change
///   between frames and started over after a turn larger than a few degrees.
/// - Layer: invisible below a noise floor, fading in up to a ceiling as the stacked image brightens.
public enum SkyNightCamera {
    public enum Exposure: Equatable, Sendable {
        /// The camera's own automatic exposure.
        case automatic
        /// Set by hand: seconds per frame and the sensor's gain (ISO).
        case manual(duration: Double, iso: Double)

        public var isManual: Bool {
            if case .manual = self { return true }
            return false
        }
    }

    /// What the active camera format allows, seconds and ISO.
    public struct Limits: Equatable, Sendable {
        public var minDuration: Double
        public var maxDuration: Double
        public var minISO: Double
        public var maxISO: Double

        public init(minDuration: Double, maxDuration: Double, minISO: Double, maxISO: Double) {
            self.minDuration = minDuration
            self.maxDuration = maxDuration
            self.minISO = minISO
            self.maxISO = maxISO
        }

        public var isValid: Bool {
            [minDuration, maxDuration, minISO, maxISO].allSatisfy { $0.isFinite && $0 > 0 }
                && minDuration <= maxDuration && minISO <= maxISO
        }

        /// Time first, then gain: the exposure `value` (seconds × ISO) as the longest time it needs at
        /// the lowest gain, and gain only for what that time cannot give. From a `current` setting the
        /// time moves at most one `maximumStep` and only in the light's direction, so the frame rate
        /// never jumps; while the time covers the value the gain stays exactly at its lowest.
        func split(_ value: Double, from current: (duration: Double, iso: Double)?) -> (duration: Double, iso: Double) {
            let total = Swift.min(Swift.max(value, minDuration * minISO), maxDuration * maxISO)
            var shortest = minDuration, longest = maxDuration
            if let current, current.duration.isFinite, current.iso.isFinite, current.duration > 0, current.iso > 0 {
                let now = Swift.min(Swift.max(current.duration, minDuration), maxDuration)
                if total >= current.duration * current.iso {
                    shortest = now
                    longest = Swift.min(maxDuration, now * SkyNightCamera.maximumStep)
                } else {
                    shortest = Swift.max(minDuration, now / SkyNightCamera.maximumStep)
                    longest = now
                }
            }
            let atLowestGain = total / minISO
            let duration = Swift.min(Swift.max(atLowestGain, shortest), longest)
            let iso = atLowestGain <= duration ? minISO : Swift.min(Swift.max(total / duration, minISO), maxISO)
            return (duration, iso)
        }
    }

    /// Mean luma (0 … 1) under which the hand-set exposure may take over.
    public static let darkLuma = 0.08
    /// Mean luma at which a frame is clipped: it no longer says how much too bright it is.
    public static let clippedLuma = 0.6
    /// Clipped frames in a row that hand back to automatic: one passing light is not enough.
    public static let clippedFrames = 2
    /// The mean luma the exposure set by hand aims at.
    public static let targetLuma = 0.25
    /// Within the target divided or multiplied by this, nothing changes: no hunting near the aim.
    public static let stillBand = 1.25
    /// The most one step changes the light, and the exposure time.
    public static let maximumStep = 1.5
    /// The least time between two steps.
    public static let stepSeconds = 0.5
    /// The least frames between two steps: a new exposure shows a few frames late.
    public static let stepFrames = 3
    /// Video's automatic exposure reaches about this frame time.
    public static let automaticDuration = 1.0 / 30

    /// The most light automatic exposure gives: its frame time at the format's highest gain.
    static func automaticLimit(_ limits: Limits) -> Double { automaticDuration * limits.maxISO }

    /// The next exposure from the picture's mean `luma`, the camera's `reading` of what it uses now,
    /// the format's `limits`, the time and frames since the last step, and how many frames in a row
    /// were clipped. Nothing changes for a non-finite input or invalid limits.
    public static func nextExposure(current: Exposure, luma: Double,
                                    reading: (duration: Double, iso: Double),
                                    limits: Limits, secondsSinceLastStep: Double,
                                    framesSinceLastStep: Int, clippedFramesInARow: Int) -> Exposure {
        guard luma.isFinite, luma >= 0, limits.isValid, secondsSinceLastStep.isFinite else { return current }
        switch current {
        case .automatic:
            guard secondsSinceLastStep >= stepSeconds, framesSinceLastStep >= stepFrames, luma < darkLuma,
                  reading.duration.isFinite, reading.iso.isFinite, reading.duration > 0, reading.iso > 0 else {
                return .automatic
            }
            // Only once automatic exposure is within two stops of its limit: before that it still
            // brightens the picture itself (and a start-up frame is no reason to take over).
            let value = reading.duration * reading.iso
            guard value >= automaticLimit(limits) / 4 else { return .automatic }
            // Take over from where automatic exposure stands, so the picture does not jump.
            return step(from: (reading.duration, reading.iso), luma: luma, limits: limits)
        case let .manual(duration, iso):
            guard duration.isFinite, iso.isFinite, duration > 0, iso > 0 else { return .automatic }
            // A light switched on: automatic exposure finds its way down in a few frames.
            if luma >= clippedLuma, clippedFramesInARow >= clippedFrames { return .automatic }
            guard secondsSinceLastStep >= stepSeconds, framesSinceLastStep >= stepFrames else { return current }
            let value = duration * iso
            // Not dark, and within automatic exposure's easy reach: bring the time down to
            // automatic's, a step at a time with the gain keeping the light, then hand back.
            if value <= automaticLimit(limits) / 4, luma >= targetLuma / stillBand {
                if duration <= 2 * automaticDuration { return .automatic }
                let shorter = Swift.max(duration / maximumStep, automaticDuration, limits.minDuration)
                let gain = Swift.min(Swift.max(value / shorter, limits.minISO), limits.maxISO)
                return .manual(duration: shorter, iso: gain)
            }
            guard luma < targetLuma / stillBand || luma > targetLuma * stillBand else { return current }
            return step(from: (duration, iso), luma: luma, limits: limits)
        }
    }

    private static func step(from current: (duration: Double, iso: Double), luma: Double, limits: Limits) -> Exposure {
        // Half the correction the picture asks for, so a step never overshoots into a flap.
        let wanted = (targetLuma / Swift.max(luma, 0.001)).squareRoot()
        let factor = Swift.min(Swift.max(wanted, 1 / maximumStep), maximumStep)
        let next = limits.split(current.duration * current.iso * factor, from: current)
        return .manual(duration: next.duration, iso: next.iso)
    }

    /// Focus holds still while the exposure is set by hand: in the dark, autofocus hunts.
    public static func holdsFocus(_ exposure: Exposure) -> Bool { exposure.isManual }

    /// How far the picture is lifted out of the dark, 0 … 1: 0 under automatic exposure and at any
    /// takeover (the most light a takeover can set is automatic's limit times one step), then about
    /// 0.12 more per step up to 1 at thirty times that light. The shadow lift and the noise
    /// reduction follow it, so neither jumps when the exposure changes hands.
    public static func nightLift(_ exposure: Exposure, limits: Limits) -> Double {
        guard case let .manual(duration, iso) = exposure, limits.isValid,
              duration.isFinite, iso.isFinite, duration > 0, iso > 0 else { return 0 }
        let start = automaticLimit(limits) * maximumStep
        let lift = Foundation.log(duration * iso / start) / Foundation.log(30)
        return Swift.min(Swift.max(lift, 0), 1)
    }

    /// The stacked picture's mean luma: the stack blends the new frame in with `weight`, and a mean
    /// blends the same way. Nil before the first frame; a non-finite input keeps what was there.
    public static func stackedLuma(previous: Double?, frame: Double, weight: Double) -> Double? {
        guard frame.isFinite, weight.isFinite else { return previous }
        guard let previous, previous.isFinite else { return frame }
        let w = Swift.min(Swift.max(weight, 0), 1)
        return previous * (1 - w) + frame * w
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
