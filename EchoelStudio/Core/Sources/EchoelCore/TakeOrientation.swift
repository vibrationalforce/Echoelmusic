import Foundation

/// Which way a video take is turned (wave W7): the phone's hold decides the capture rotation and
/// so whether the stored picture is tall or wide. The camera's sensor is wide; the capture
/// connection turns each frame by `angle` (0, 90, 180 or 270 degrees, the values
/// `AVCaptureConnection.videoRotationAngle` takes). A phone lying flat says nothing about which
/// way is up, so it keeps the last answer. Once a take runs the angle is fixed: a take that
/// turned halfway would be half sideways. A value type; the app feeds it what the camera's
/// rotation coordinator and the phone report.
public struct TakeOrientation: Equatable, Sendable {
    /// The lens the take films through. The front lens faces the musician, so its landscape
    /// angles are the back lens's turned half a circle.
    public enum Lens: Equatable, Sendable {
        case back
        case front
    }

    /// How the phone is held (the device orientation, in the platform's own terms).
    public enum Hold: Equatable, Sendable {
        case portrait
        case portraitUpsideDown
        /// Turned with the top to the left (the side button facing up).
        case landscapeLeft
        /// Turned with the top to the right.
        case landscapeRight
        case faceUp
        case faceDown
        case unknown
    }

    /// The capture rotation now, in degrees. Upright portrait until the phone says otherwise.
    public private(set) var angle: Double = 90
    /// A take runs: the angle stays where it was when it began.
    public private(set) var isLocked = false

    public init() {}

    /// The capture rotation for `hold` through `lens`; nil when the hold names no up (flat, unknown).
    public static func angle(for hold: Hold, lens: Lens) -> Double? {
        let degrees: Double
        switch hold {
        case .portrait: degrees = 90
        case .portraitUpsideDown: degrees = 270
        case .landscapeLeft: degrees = lens == .back ? 0 : 180
        case .landscapeRight: degrees = lens == .back ? 180 : 0
        case .faceUp, .faceDown, .unknown: return nil
        }
        return degrees
    }

    /// The phone reports how it is held. Flat or unknown keeps the last angle; a running take keeps it too.
    public mutating func held(_ hold: Hold, lens: Lens) {
        guard !isLocked, let next = Self.angle(for: hold, lens: lens) else { return }
        angle = next
    }

    /// The camera's rotation coordinator reports its horizon-level capture angle. Snapped to the
    /// nearest quarter turn; a non-finite reading changes nothing, nor does a running take.
    public mutating func captured(angle reading: Double) {
        guard !isLocked, reading.isFinite else { return }
        let quarters = (reading / 90).rounded()
        var snapped = quarters.truncatingRemainder(dividingBy: 4) * 90
        if snapped < 0 { snapped += 360 }
        angle = snapped
    }

    /// A take begins: from now until `endTake()` the angle does not move.
    public mutating func beginTake() { isLocked = true }

    /// The take ended: the angle follows the phone again.
    public mutating func endTake() { isLocked = false }

    /// Whether the stored picture is wider than tall.
    public var isLandscape: Bool { angle == 0 || angle == 180 }

    /// The stored picture's size for a sensor that delivers `width` × `height` (the wide side
    /// first or not — the sensor is wide, so the longer side is taken as its width). A quarter
    /// turn stands the picture up.
    public func frameSize(sensorWidth width: Int, sensorHeight height: Int) -> (width: Int, height: Int) {
        let long = Swift.max(width, height)
        let short = Swift.min(width, height)
        return isLandscape ? (long, short) : (short, long)
    }
}
