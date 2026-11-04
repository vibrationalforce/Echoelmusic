import Foundation

/// The iPhone itself as a body source (Recovery 9): four modulation sources from its motion
/// sensors, each normalized 0 … 1 and smoothed. Pure — the app's CoreMotion owner hands it one
/// `Reading` per sample (60 Hz) on its own queue; nothing here reads a sensor, a clock or the main
/// actor.
///
/// - **Tilt X / Tilt Y** (`motionTiltX`, `motionTiltY`): roll and pitch of the attitude as
///   `0.5 + 0.5·sin(angle)` — 0.5 lying flat, 0 and 1 a quarter turn either way. The sine has no
///   seam where the attitude's angle wraps at ±180°, so turning the phone over never jumps.
/// - **Rotation** (`motionRotation`): the turning rate about the screen's axis (yaw rate when the
///   phone lies flat), 0.5 at rest, 1 at `fullRotationRadiansPerSecond` counter-clockwise, 0 as fast
///   clockwise.
/// - **Energy** (`motionEnergy`): the length of the acceleration WITHOUT gravity (CoreMotion's
///   user acceleration, in g) above `restG`, up to `fullEnergyG`. A phone lying still reads 0 —
///   gravity never counts as movement.
///
/// Each channel stands on its own: a non-finite number in one leaves that one absent and the
/// others measured. A sample whose time does not move forward is ignored; a gap longer than
/// `maximumGapSeconds` starts every channel afresh at its new value rather than gliding across it.
/// No value is ever invented: before the first sample, and after `reset()`, all four are absent.
public struct PhoneMotion: Equatable, Sendable {
    /// One sensor sample as CoreMotion reports it.
    public struct Reading: Equatable, Sendable {
        /// The sample's time in seconds on a monotonic clock (CoreMotion's `timestamp`).
        public var seconds: Double
        /// Attitude, radians.
        public var roll: Double
        public var pitch: Double
        /// Rotation rate about the device's z axis, radians per second.
        public var yawRate: Double
        /// User acceleration (gravity removed), in g.
        public var accelerationX: Double
        public var accelerationY: Double
        public var accelerationZ: Double

        public init(seconds: Double, roll: Double, pitch: Double, yawRate: Double,
                    accelerationX: Double, accelerationY: Double, accelerationZ: Double) {
            self.seconds = seconds
            self.roll = roll
            self.pitch = pitch
            self.yawRate = yawRate
            self.accelerationX = accelerationX
            self.accelerationY = accelerationY
            self.accelerationZ = accelerationZ
        }
    }

    /// The four channels, each nil while not measured.
    public struct Values: Equatable, Sendable {
        public var tiltX: Double?
        public var tiltY: Double?
        public var rotation: Double?
        public var energy: Double?

        public init(tiltX: Double? = nil, tiltY: Double? = nil, rotation: Double? = nil, energy: Double? = nil) {
            self.tiltX = tiltX
            self.tiltY = tiltY
            self.rotation = rotation
            self.energy = energy
        }

        public static let absent = Values()

        /// The value for one modulation source; nil for a source that is not one of the four.
        public func value(for source: ModulationSource) -> Double? {
            switch source {
            case .motionTiltX: tiltX
            case .motionTiltY: tiltY
            case .motionRotation: rotation
            case .motionEnergy: energy
            default: nil
            }
        }
    }

    /// The sources this type feeds, in their order in `ModulationSource`.
    public static let sources: [ModulationSource] = [.motionTiltX, .motionTiltY, .motionRotation, .motionEnergy]

    /// One full swing of the rotation channel: half a turn per second.
    public static let fullRotationRadiansPerSecond = Double.pi
    /// Below this the sensor's own noise on a phone lying still (a few thousandths of a g) and a
    /// steady hand: no movement.
    public static let restG = 0.03
    /// A brisk shake reaches the top.
    public static let fullEnergyG = 1.0
    /// Time constants of the smoothing, seconds: tilt and turning follow the hand within about a
    /// tenth of a second without trembling; energy settles a little slower, so a single jolt is a
    /// swell rather than a click.
    public static let tiltSmoothingSeconds = 0.08
    public static let rotationSmoothingSeconds = 0.1
    public static let energySmoothingSeconds = 0.2
    /// Longer than this between two samples (an interruption, the app in the background), and the
    /// next sample starts afresh.
    public static let maximumGapSeconds = 0.5

    public private(set) var values = Values.absent
    private var lastSeconds: Double?

    public init() {}

    /// Every channel absent again and the next sample starts afresh: a stop, an interruption.
    public mutating func reset() {
        values = .absent
        lastSeconds = nil
    }

    /// Takes one sample and returns the four channels after it.
    @discardableResult
    public mutating func take(_ reading: Reading) -> Values {
        guard reading.seconds.isFinite else {
            reset()
            return values
        }
        // The same or an earlier time: a duplicate or a reordered sample moves nothing.
        if let last = lastSeconds, reading.seconds <= last { return values }
        let elapsed = lastSeconds.map { reading.seconds - $0 }
        lastSeconds = reading.seconds
        let fresh = elapsed.map { $0 > Self.maximumGapSeconds } ?? true
        values.tiltX = Self.glide(values.tiltX, towards: Self.tilt(reading.roll), elapsed: elapsed,
                                  seconds: Self.tiltSmoothingSeconds, fresh: fresh)
        values.tiltY = Self.glide(values.tiltY, towards: Self.tilt(reading.pitch), elapsed: elapsed,
                                  seconds: Self.tiltSmoothingSeconds, fresh: fresh)
        values.rotation = Self.glide(values.rotation, towards: Self.rotation(reading.yawRate), elapsed: elapsed,
                                     seconds: Self.rotationSmoothingSeconds, fresh: fresh)
        values.energy = Self.glide(values.energy,
                                   towards: Self.energy(reading.accelerationX, reading.accelerationY, reading.accelerationZ),
                                   elapsed: elapsed, seconds: Self.energySmoothingSeconds, fresh: fresh)
        return values
    }

    // MARK: - Normalization

    /// An attitude angle as 0 … 1, 0.5 level; nil when not finite.
    public static func tilt(_ radians: Double) -> Double? {
        guard radians.isFinite else { return nil }
        return clampUnit(0.5 + 0.5 * Foundation.sin(radians))
    }

    /// A turning rate as 0 … 1, 0.5 at rest; nil when not finite.
    public static func rotation(_ radiansPerSecond: Double) -> Double? {
        guard radiansPerSecond.isFinite else { return nil }
        let share = Swift.min(1, Swift.max(-1, radiansPerSecond / fullRotationRadiansPerSecond))
        return clampUnit(0.5 + 0.5 * share)
    }

    /// Acceleration without gravity as 0 … 1, 0 still; nil when any component is not finite.
    public static func energy(_ x: Double, _ y: Double, _ z: Double) -> Double? {
        guard x.isFinite, y.isFinite, z.isFinite else { return nil }
        let length = (x * x + y * y + z * z).squareRoot()
        guard length.isFinite else { return nil }
        return clampUnit((length - restG) / (fullEnergyG - restG))
    }

    // MARK: - Smoothing

    /// One step of a one-pole glide towards `target`, by the time that passed. Absent target,
    /// absent value; the first sample, or one after a gap, lands on its target at once. Both ends
    /// lie in 0 … 1, so every step does too.
    static func glide(_ current: Double?, towards target: Double?, elapsed: Double?, seconds: Double,
                      fresh: Bool) -> Double? {
        guard let target else { return nil }
        guard !fresh, let current, let elapsed, elapsed > 0, seconds > 0 else { return target }
        let factor = 1 - Foundation.exp(-elapsed / seconds)
        return clampUnit(current + (target - current) * factor)
    }

    private static func clampUnit(_ value: Double) -> Double {
        Swift.min(1, Swift.max(0, value))
    }
}
