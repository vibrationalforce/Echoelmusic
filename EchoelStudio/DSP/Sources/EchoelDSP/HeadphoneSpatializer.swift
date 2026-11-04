import Foundation

/// One sound object placed around a listener on headphones: a mono source at an azimuth,
/// elevation and distance, rendered to the two ears with the cues a head gives it —
///
/// - **arrival time** (interaural time difference): the far ear hears the source later, by the
///   spherical-head model of Woodworth, `(a / c)(θ + sin θ)` for the lateral angle θ — 0.66 ms at
///   90° for a head of 8.75 cm. Read from one delay line at a fractional delay (four-point Hermite),
///   so a moving source glides instead of stepping a whole sample;
/// - **head shadow** (interaural level difference): a first-order shelf per ear above ~1.2 kHz,
///   the pole of Brown and Duda's head model, darkening the far ear by up to 14 dB and lifting the
///   near one by 2 dB, plus a small broadband dip on the far side; a source behind the head is a
///   little duller in both ears;
/// - **elevation**: a gentle tilt above ~7 kHz, brighter above the ears, darker below;
/// - **distance**: the level falls as 1/d beyond the reference distance 1, and the air takes the
///   highs away (a one-pole lowpass falling from 20 kHz at 2 to ~2 kHz at 100).
///
/// The angles follow ADM-OSC and `ADMObject`: azimuth 0 ahead, POSITIVE TO THE LEFT, −180 … 180;
/// elevation positive above, −90 … 90. Not a measured head-related transfer function and not a
/// room: a small model of the cues, the same on every device and in every export.
///
/// Every value a position sets glides over ~30 ms (`glideSeconds`), so a position that moves —
/// a pan ride, automation — never clicks. Until the first sample runs, a position takes effect at
/// once. The processor works sample by sample on its own state, so the same input and the same
/// positions give the same output whatever the block size.
///
/// Owned by the render thread: call `setPosition` and `process` from it. The delay line is
/// allocated in `init`; nothing allocates after that. A non-finite input sample is read as 0, a
/// non-finite position as the default one, so nothing non-finite reaches the state.
public final class HeadphoneSpatializer: @unchecked Sendable {
    /// Where the source is, in the ADM-OSC convention.
    public struct Position: Equatable, Sendable {
        /// Degrees, −180 … 180, 0 ahead, positive to the LEFT.
        public var azimuth: Double
        /// Degrees, −90 … 90, positive above.
        public var elevation: Double
        /// 0 … `HeadphoneSpatializer.maximumDistance`; 1 is the reference distance, heard at
        /// the source's own level.
        public var distance: Double

        public init(azimuth: Double = 0, elevation: Double = 0, distance: Double = 1) {
            self.azimuth = azimuth.isFinite ? Swift.min(180, Swift.max(-180, azimuth)) : 0
            self.elevation = elevation.isFinite ? Swift.min(90, Swift.max(-90, elevation)) : 0
            self.distance = distance.isFinite ? Swift.min(HeadphoneSpatializer.maximumDistance, Swift.max(0, distance)) : 1
        }

        /// A stereo pan (−1 hard left … 1 hard right) as a place on the horizon at the reference
        /// distance: hard left +90°, centre 0°, hard right −90° — what `ADMObject.track` sends.
        public static func pan(_ pan: Double) -> Position {
            let position = pan.isFinite ? Swift.min(1, Swift.max(-1, pan)) : 0
            return Position(azimuth: -position * 90, elevation: 0, distance: 1)
        }
    }

    /// Head radius, metres: the average adult's.
    public static let headRadius = 0.0875
    /// Speed of sound, metres per second, at room temperature.
    public static let speedOfSound = 343.0
    /// The farthest distance a position holds.
    public static let maximumDistance = 100.0
    /// How long a change of position takes to arrive.
    public static let glideSeconds = 0.03
    /// The samples every read lags behind the write, so the four-point read never reaches a
    /// sample not yet written; the same for both ears, so it is no cue.
    static let baseDelay = 2.0

    /// The arrival-time difference for `position`, in seconds: positive when the RIGHT ear hears
    /// the source later (a source on the left), negative for one on the right, 0 ahead, behind
    /// and straight above.
    public static func interauralDelay(_ position: Position) -> Double {
        let lateral = lateralAngle(position)
        return headRadius / speedOfSound * (lateral + sin(lateral))
    }

    /// The angle off the median plane, radians, positive to the left: −π/2 … π/2.
    static func lateralAngle(_ position: Position) -> Double {
        let azimuth = position.azimuth * .pi / 180, elevation = position.elevation * .pi / 180
        return asin(Swift.min(1, Swift.max(-1, exact(sin(azimuth)) * exact(cos(elevation)))))
    }

    /// A sine or cosine within a rounding of 0 as 0, so a source straight ahead, behind or above
    /// is the same in both ears to the bit.
    static func exact(_ value: Double) -> Double { Swift.abs(value) < 1e-12 ? 0 : value }

    public let sampleRate: Double
    private let capacity: Int
    private let mask: Int
    private let line: UnsafeMutablePointer<Float>
    private var write = 0
    private let glide: Double
    /// The head shadow's pole, from the head radius (Brown and Duda): fixed, so only the zero —
    /// a value that blends linearly — moves with the position.
    private let shadowScale: Double
    private let shadowFeedback: Double
    /// The one-pole that splits off the highs for the elevation tilt, at ~7 kHz.
    private let tiltCoefficient: Double

    /// The values the position sets, as they sound now and where they are going.
    private struct Cues: Equatable {
        var delayLeft: Double
        var delayRight: Double
        var shadowLeft: Double
        var shadowRight: Double
        var levelLeft: Double
        var levelRight: Double
        var tilt: Double
        var gain: Double
        var air: Double
    }
    private var now: Cues
    private var target: Cues
    private var hasRun = false
    private var airState = 0.0
    private var tiltState = 0.0
    private var shadowInLeft = 0.0, shadowOutLeft = 0.0
    private var shadowInRight = 0.0, shadowOutRight = 0.0

    public init(sampleRate: Double) {
        self.sampleRate = sampleRate > 0 && sampleRate.isFinite ? Swift.min(sampleRate, 768_000) : 48_000
        // The largest arrival-time difference plus the read's reach, as a power of two.
        let reach = Int((Self.headRadius / Self.speedOfSound * (.pi / 2 + 1) * self.sampleRate).rounded(.up)) + 8
        var size = 16
        while size < reach { size *= 2 }
        capacity = size
        mask = size - 1
        line = .allocate(capacity: size)
        line.initialize(repeating: 0, count: size)
        glide = 1 - Foundation.exp(-1 / (Self.glideSeconds * self.sampleRate))
        // Bilinear transform of (1 + α s / 2ω₀) / (1 + s / 2ω₀), ω₀ = c / a.
        let omega = Self.speedOfSound / Self.headRadius
        shadowScale = self.sampleRate / omega
        shadowFeedback = (1 - shadowScale) / (1 + shadowScale)
        tiltCoefficient = 1 - Foundation.exp(-2 * .pi * 7_000 / self.sampleRate)
        let start = Self.cues(Position(), sampleRate: self.sampleRate)
        now = start
        target = start
    }

    deinit { line.deallocate() }

    /// Where the source is from now on; it glides there, or jumps there before the first sample.
    public func setPosition(_ position: Position) {
        target = Self.cues(position, sampleRate: sampleRate)
        if !hasRun { now = target }
    }

    /// Silence in the line and the filters; the next position takes effect at once.
    public func reset() {
        line.update(repeating: 0, count: capacity)
        write = 0
        airState = 0
        tiltState = 0
        shadowInLeft = 0
        shadowOutLeft = 0
        shadowInRight = 0
        shadowOutRight = 0
        now = target
        hasRun = false
    }

    /// The two sides of `left` and `right` averaged into one source, placed, and written to the
    /// two ears in `outLeft` and `outRight` (overwritten). The input and output may not overlap.
    public func process(left: UnsafePointer<Float>, right: UnsafePointer<Float>,
                        outLeft: UnsafeMutablePointer<Float>, outRight: UnsafeMutablePointer<Float>, frames: Int) {
        guard frames > 0 else { return }
        hasRun = true
        var cues = now
        let goal = target
        let settled = cues == goal
        for i in 0..<frames {
            if !settled { Self.glide(&cues, towards: goal, by: glide) }
            var x = Double(left[i] + right[i]) * 0.5
            if !x.isFinite { x = 0 }
            // The air, then the distance's level, then the elevation's tilt: one source for both ears.
            airState += cues.air * (x - airState)
            var source = airState * cues.gain
            tiltState += tiltCoefficient * (source - tiltState)
            source += cues.tilt * (source - tiltState)
            line[write] = Float(source)
            let heardLeft = read(cues.delayLeft)
            let heardRight = read(cues.delayRight)
            write = (write + 1) & mask
            let ear = 1 + shadowScale
            let outL = ((1 + cues.shadowLeft * shadowScale) * heardLeft + (1 - cues.shadowLeft * shadowScale) * shadowInLeft) / ear
                - shadowFeedback * shadowOutLeft
            shadowInLeft = heardLeft
            shadowOutLeft = outL
            let outR = ((1 + cues.shadowRight * shadowScale) * heardRight + (1 - cues.shadowRight * shadowScale) * shadowInRight) / ear
                - shadowFeedback * shadowOutRight
            shadowInRight = heardRight
            shadowOutRight = outR
            outLeft[i] = Float(outL * cues.levelLeft)
            outRight[i] = Float(outR * cues.levelRight)
        }
        // A glide that has come within a hair of its goal ends there, so a settled source costs
        // no glide and its sound no longer depends on where the glide began.
        if !settled, Self.isClose(cues, goal) { cues = goal }
        now = cues
    }

    /// The line `delay` samples behind the sample just written, read between samples by a
    /// four-point Hermite curve.
    private func read(_ delay: Double) -> Double {
        let whole = Int(delay)
        let fraction = delay - Double(whole)
        let newest = write - whole + capacity
        let ym1 = Double(line[(newest + 1) & mask]), y0 = Double(line[newest & mask])
        let y1 = Double(line[(newest - 1) & mask]), y2 = Double(line[(newest - 2) & mask])
        let c1 = 0.5 * (y1 - ym1)
        let c2 = ym1 - 2.5 * y0 + 2 * y1 - 0.5 * y2
        let c3 = 0.5 * (y2 - ym1) + 1.5 * (y0 - y1)
        return ((c3 * fraction + c2) * fraction + c1) * fraction + y0
    }

    private static func glide(_ cues: inout Cues, towards goal: Cues, by amount: Double) {
        cues.delayLeft += (goal.delayLeft - cues.delayLeft) * amount
        cues.delayRight += (goal.delayRight - cues.delayRight) * amount
        cues.shadowLeft += (goal.shadowLeft - cues.shadowLeft) * amount
        cues.shadowRight += (goal.shadowRight - cues.shadowRight) * amount
        cues.levelLeft += (goal.levelLeft - cues.levelLeft) * amount
        cues.levelRight += (goal.levelRight - cues.levelRight) * amount
        cues.tilt += (goal.tilt - cues.tilt) * amount
        cues.gain += (goal.gain - cues.gain) * amount
        cues.air += (goal.air - cues.air) * amount
    }

    private static func isClose(_ a: Cues, _ b: Cues) -> Bool {
        let near = { (x: Double, y: Double) in Swift.abs(x - y) < 1e-7 }
        return near(a.delayLeft, b.delayLeft) && near(a.delayRight, b.delayRight) && near(a.shadowLeft, b.shadowLeft)
            && near(a.shadowRight, b.shadowRight) && near(a.levelLeft, b.levelLeft) && near(a.levelRight, b.levelRight)
            && near(a.tilt, b.tilt) && near(a.gain, b.gain) && near(a.air, b.air)
    }

    /// What `position` sets. Main or render thread; no allocation.
    private static func cues(_ position: Position, sampleRate: Double) -> Cues {
        let lateral = lateralAngle(position)
        // How far to the side, 0 … 1, positive to the left.
        let side = sin(lateral)
        let delay = interauralDelay(position) * sampleRate
        // The ear away from the source waits; the near one hears it first.
        let delayLeft = baseDelay + Swift.max(0, -delay)
        let delayRight = baseDelay + Swift.max(0, delay)
        let azimuth = position.azimuth * .pi / 180, elevation = position.elevation * .pi / 180
        // Behind the head both ears hear a little less of the highs.
        let behind = 1 - 0.25 * Swift.max(0, -exact(cos(azimuth))) * exact(cos(elevation))
        let near = 1 + 0.25 * Swift.abs(side), far = 1 - 0.8 * Swift.abs(side)
        let shadowLeft = (side >= 0 ? near : far) * behind
        let shadowRight = (side >= 0 ? far : near) * behind
        let dip = 1 - 0.15 * Swift.abs(side)
        let levelLeft = side >= 0 ? 1 : dip
        let levelRight = side >= 0 ? dip : 1
        let rise = sin(elevation)
        let tilt = rise >= 0 ? 0.4 * rise : 0.37 * rise
        let distance = position.distance
        let gain = 1 / Swift.max(distance, 1)
        // Up to the reference distance and a little past it, the air takes nothing.
        let air: Double
        if distance <= 2 {
            air = 1
        } else {
            let cutoff = Swift.min(20_000, 20_000 / (distance / 2).squareRoot())
            air = Swift.min(1, 1 - Foundation.exp(-2 * .pi * cutoff / sampleRate))
        }
        return Cues(delayLeft: delayLeft, delayRight: delayRight, shadowLeft: shadowLeft, shadowRight: shadowRight,
                    levelLeft: levelLeft, levelRight: levelRight, tilt: tilt, gain: gain, air: air)
    }
}
