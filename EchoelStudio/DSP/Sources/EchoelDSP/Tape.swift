import Foundation

/// A tape machine's character on the sound itself (not an echo): wow and flutter — the pitch
/// warble of an uneven capstan, a short delay line read at a place a slow sine (0.6 Hz) and a fast
/// triangle (6.5 Hz) sway — then the soft compression of tape saturation and the lost top end of
/// a worn transport. Ported from the earlier app's `EchoelTape` (EchoelLoFiFX) for Echoel Studio
/// 1.0, as a value of settings and a render-thread processor like `Chorus`.
///
/// The line is read 6 ms behind, so the ±4.6 ms sway never reaches the write. That constant 6 ms
/// is the effect's latency; there is no dry path, so nothing combs. One bad sample empties the
/// line and the filter rather than ringing in them. Owned by the render thread: set `settings`
/// and call `process` from that thread. The line is allocated in `init`; nothing allocates after
/// that.
public final class Tape: @unchecked Sendable {
    public struct Settings: Equatable, Codable, Sendable {
        /// Wow and flutter, 0 … 1 (0: no warble; the line is still read at 6 ms).
        public var wow: Double
        /// Tape saturation, 0 … 1 (0: clean).
        public var saturation: Double
        /// How much top end stays, 0 … 1 (0: about 1 kHz, a worn tape; 1: about 16 kHz).
        public var tone: Double

        public init(wow: Double = 0.35, saturation: Double = 0.25, tone: Double = 0.8) {
            self.wow = wow
            self.saturation = saturation
            self.tone = tone
        }

        /// Every value inside its range; non-finite values take the default.
        public var clamped: Settings {
            let base = Settings()
            func clamp(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
                value.isFinite ? Swift.min(Swift.max(value, range.lowerBound), range.upperBound) : fallback
            }
            return Settings(wow: clamp(wow, 0...1, base.wow), saturation: clamp(saturation, 0...1, base.saturation),
                            tone: clamp(tone, 0...1, base.tone))
        }
    }

    /// Where the line is read, and the widest slow and fast sway, in seconds.
    public static let baseSeconds = 0.006
    public static let wowSeconds = 0.004
    public static let flutterSeconds = 0.0006
    public static let wowHertz = 0.6
    public static let flutterHertz = 6.5

    public var settings: Settings {
        didSet {
            settings = settings.clamped
            toneCoefficient = Self.coefficient(settings.tone, sampleRate)
        }
    }

    public let sampleRate: Double
    private let capacity: Int
    private let lineLeft: UnsafeMutablePointer<Float>
    private let lineRight: UnsafeMutablePointer<Float>
    private var write = 0
    private var wowPhase: Double = 0
    private var flutterPhase: Double = 0
    private var toneCoefficient: Float = 1
    private var lowLeft: Float = 0
    private var lowRight: Float = 0

    public init(sampleRate: Double, settings: Settings = Settings()) {
        self.sampleRate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        capacity = Int(self.sampleRate * (Self.baseSeconds + Self.wowSeconds + Self.flutterSeconds)) + 4
        lineLeft = .allocate(capacity: capacity)
        lineLeft.initialize(repeating: 0, count: capacity)
        lineRight = .allocate(capacity: capacity)
        lineRight.initialize(repeating: 0, count: capacity)
        let start = settings.clamped
        self.settings = start
        toneCoefficient = Self.coefficient(start.tone, self.sampleRate)
    }

    deinit {
        lineLeft.deallocate()
        lineRight.deallocate()
    }

    private static func coefficient(_ tone: Double, _ sampleRate: Double) -> Float {
        let hertz = Swift.min(1_000 * Foundation.pow(16, tone), 0.45 * sampleRate)
        return Float(1 - Foundation.exp(-2 * Double.pi * hertz / sampleRate))
    }

    /// Empties the line and the filter and starts the sway over.
    public func reset() {
        lineLeft.update(repeating: 0, count: capacity)
        lineRight.update(repeating: 0, count: capacity)
        wowPhase = 0
        flutterPhase = 0
        lowLeft = 0
        lowRight = 0
    }

    /// Processes `frames` samples in place.
    public func process(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        let wowStep = Self.wowHertz / sampleRate
        let flutterStep = Self.flutterHertz / sampleRate
        let base = Self.baseSeconds * sampleRate
        let wowSwing = settings.wow * Self.wowSeconds * sampleRate
        let flutterSwing = settings.wow * Self.flutterSeconds * sampleRate
        let saturation = Float(settings.saturation)
        let drive = 1 + saturation * 3
        let makeup = 1 / (1 + saturation * 1.2)
        let toneAmount = toneCoefficient
        for i in 0..<frames {
            let slow = Foundation.sin(2 * Double.pi * wowPhase)
            let fast = flutterPhase < 0.5 ? 4 * flutterPhase - 1 : 3 - 4 * flutterPhase
            wowPhase += wowStep
            if wowPhase >= 1 { wowPhase -= 1 }
            flutterPhase += flutterStep
            if flutterPhase >= 1 { flutterPhase -= 1 }
            let inLeft = left[i], inRight = right[i]
            lineLeft[write] = inLeft
            lineRight[write] = inRight
            let distance = base + slow * wowSwing + fast * flutterSwing
            var outLeft = read(lineLeft, distance: distance)
            var outRight = read(lineRight, distance: distance)
            write = write + 1 < capacity ? write + 1 : 0
            if saturation > 0 {
                outLeft = tanh(outLeft * drive) * makeup
                outRight = tanh(outRight * drive) * makeup
            }
            lowLeft += toneAmount * (outLeft - lowLeft)
            lowRight += toneAmount * (outRight - lowRight)
            guard lowLeft.isFinite, lowRight.isFinite, inLeft.isFinite, inRight.isFinite else {
                reset()
                left[i] = 0
                right[i] = 0
                continue
            }
            left[i] = lowLeft
            right[i] = lowRight
        }
    }

    /// The line `distance` samples behind the newest sample, linearly interpolated.
    @inline(__always)
    private func read(_ line: UnsafeMutablePointer<Float>, distance: Double) -> Float {
        let back = Swift.min(Swift.max(distance, 1), Double(capacity - 2))
        var position = Double(write) - back
        if position < 0 { position += Double(capacity) }
        let index = Int(position)
        let fraction = Float(position - Double(index))
        let next = index + 1 < capacity ? index + 1 : 0
        return line[index] + (line[next] - line[index]) * fraction
    }
}
