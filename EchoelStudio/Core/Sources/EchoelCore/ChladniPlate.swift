import Foundation

/// Which picture the Field draws. Kept on this device (`storageKey`), never in the song: the song
/// format does not change. The raw values are what the device stores, so they are never renamed,
/// and a new pattern goes at the end.
public enum FieldPattern: String, CaseIterable, Sendable {
    /// The interference rings the Field has drawn since W3.
    case rings
    /// A square plate's standing waves, chosen by the partials of the master output, with sand
    /// gathering on the lines that do not move (`ChladniPlate`).
    case chladni
    /// A dish of water on a speaker, lit from above: the sounding pitch sets the ripple lattice,
    /// the loudness whether it appears at all (`FaradayDish`; silence is a mirror).
    case dish
    /// Sun on a pool floor: a caustic net whose spacing follows the sounding pitch (k ∝ f^⅔).
    case water
    /// A curtain of light: Chapman-profile bands, rays spaced by the sounding pitch, swelling with
    /// the breath.
    case aurora
    /// The dish's ripples seen from under the water: the caustic network on the floor below.
    case depth

    public static let storageKey = "field.pattern"
    /// The pattern blended over the first one (`FieldLookMotion`); absent or unknown is none.
    public static let blendStorageKey = "field.pattern.blend"
    /// How much of the blended pattern shows, in percent 0 … 100.
    public static let blendMixStorageKey = "field.pattern.mix"
    /// The blend's share before the musician sets one: an even mix.
    public static let standardMixPercent = 50

    public var title: String {
        switch self {
        case .rings: "Rings"
        case .chladni: "Chladni Plate"
        case .dish: "Dish"
        case .water: "Water"
        case .aurora: "Aurora"
        case .depth: "Depth"
        }
    }

    /// The pattern's number in the shader's `Look` struct (`FieldShader.field`): its place in
    /// `allCases`, so the shader's branches follow the order the device stores.
    public var shaderIndex: Double {
        Double(FieldPattern.allCases.firstIndex(of: self) ?? 0)
    }

    /// Whether the picture listens to the master's partials: every pattern but the rings, which
    /// move with the song's bar and the body alone.
    public var listensToSound: Bool { self != .rings }

    /// A stored blend partner read back; anything unknown or empty is no blend.
    public static func blend(stored: String?) -> FieldPattern? {
        stored.flatMap(FieldPattern.init(rawValue:))
    }

    /// The stored name read back; anything unknown is the rings.
    public init(stored: String?) {
        self = stored.flatMap(FieldPattern.init(rawValue:)) ?? .rings
    }
}

/// Up to four plate modes and how strongly each one rings, plus how loud the sound driving them
/// is. A plain value with no array, so it crosses to the GPU as it is and costs no allocation.
public struct ChladniModes: Equatable, Sendable {
    /// The mode indices along x and y; a mode with weight 0 is unused.
    public var m: SIMD4<Double>
    public var n: SIMD4<Double>
    /// The share of each mode in the plate's motion; the used weights sum to 1.
    public var weight: SIMD4<Double>
    /// How loud the driving sound is, 0 (silence) … 1 (−6 dBFS and up).
    public var drive: Double

    public init(m: SIMD4<Double> = .zero, n: SIMD4<Double> = .zero, weight: SIMD4<Double> = .zero, drive: Double = 0) {
        self.m = m
        self.n = n
        self.weight = weight
        self.drive = drive.isFinite ? Swift.min(1, Swift.max(0, drive)) : 0
    }

    /// No sound: the plate lies still, the sand spread evenly and unlit.
    public static let calm = ChladniModes()

    public var isCalm: Bool { weight == .zero }

    /// The strongest mode, or nil on a calm plate.
    public var dominant: (m: Int, n: Int)? {
        isCalm ? nil : (Int(m[0]), Int(n[0]))
    }

    /// Whether the plate would show a different figure: other modes, or weights apart by more
    /// than `ChladniMotion.weightTolerance`.
    func figureDiffers(from other: ChladniModes) -> Bool {
        if m != other.m || n != other.n { return true }
        let difference = weight - other.weight
        for index in 0..<4 where Swift.abs(difference[index]) > ChladniMotion.weightTolerance { return true }
        return false
    }
}

/// A square plate driven by sound, as Chladni drove his with a bow (1787). The plate's modes on
/// the unit square are the classic Chladni figures — for m ≠ n the degenerate pair superposed,
/// `cos(mπx)cos(nπy) − cos(nπx)cos(mπy)`, for m = n the single product — and a mode (m, n) rings
/// at `baseHertz · (m² + n²)`: the m² + n² law of a thin plate's flexural modes (Kirchhoff), an
/// approximation for the free plate that is exact for the simply supported one. The base is
/// A0, 27.5 Hz, so the A's land on modes: 440 Hz is (0, 4), 1760 Hz is (0, 8).
///
/// The sound chooses the figure as a real plate would: each partial excites every mode by its
/// resonance response, a Lorentzian of quality `quality` around the mode's frequency, and the
/// `ChladniModes.count` modes that respond most make the figure, weighted by their response. Sand
/// gathers where the plate does not move — on the nodal lines, where the displacement is 0.
///
/// Pure, deterministic and allocation-free: the same partials give the same figure, every time.
/// The Metal shader evaluates `displacement` and `sand` with the same constants.
public enum ChladniPlate {
    public static let baseHertz = 27.5
    /// The finest mode index; (12, 12) rings at 7.9 kHz, finer figures are not legible.
    public static let maximumIndex = 12
    /// How sharply a mode responds: its half-power bandwidth is its frequency over this.
    public static let quality = 12.0
    /// How many modes make one figure.
    public static let count = 4
    /// The displacement under which sand still gathers, as a share of the plate's peak.
    public static let sandWidth = 0.08
    /// `sandWidth` as the Metal shader writes it.
    public static let sandWidthLiteral = "0.08"
    /// The sound's level at which the plate starts to show (−54 dBFS) and is fully lit (−6 dBFS).
    public static let quietDecibels = -54.0
    public static let fullDecibels = -6.0

    /// The frequency the mode (m, n) rings at.
    public static func frequency(m: Int, n: Int) -> Double {
        baseHertz * Double(m * m + n * n)
    }

    /// The figure the partials choose: the `count` modes that respond most, strongest first, and
    /// the drive from the partials' combined level. No partial, or partials too quiet to move a
    /// plate, is the calm plate. Non-finite or non-positive partials are ignored.
    public static func modes(frequencies: SIMD8<Double>, amplitudes: SIMD8<Double>, count partials: Int) -> ChladniModes {
        let used = Swift.min(Swift.max(partials, 0), 8)
        var power = 0.0
        for index in 0..<used {
            let amplitude = amplitudes[index]
            guard amplitude.isFinite, amplitude > 0, frequencies[index].isFinite, frequencies[index] > 0 else { continue }
            power += amplitude * amplitude
        }
        guard power > 0 else { return .calm }
        let decibels = 10 * Foundation.log10(power)
        let drive = (decibels - quietDecibels) / (fullDecibels - quietDecibels)
        guard drive > 0 else { return .calm }

        var bestM = SIMD4<Double>.zero, bestN = SIMD4<Double>.zero, best = SIMD4<Double>.zero
        for m in 0...maximumIndex {
            for n in m...maximumIndex where m + n > 0 {
                let modeHertz = frequency(m: m, n: n)
                var response = 0.0
                for index in 0..<used {
                    let amplitude = amplitudes[index], hertz = frequencies[index]
                    guard amplitude.isFinite, amplitude > 0, hertz.isFinite, hertz > 0 else { continue }
                    let detune = quality * (hertz - modeHertz) / modeHertz
                    response += amplitude / (1 + detune * detune)
                }
                // Keep the four strongest, strongest first; a tie keeps the lower mode.
                var slot = count
                while slot > 0, best[slot - 1] < response { slot -= 1 }
                guard slot < count else { continue }
                var move = count - 1
                while move > slot {
                    best[move] = best[move - 1]
                    bestM[move] = bestM[move - 1]
                    bestN[move] = bestN[move - 1]
                    move -= 1
                }
                best[slot] = response
                bestM[slot] = Double(m)
                bestN[slot] = Double(n)
            }
        }
        let total = best.sum()
        guard total > 0, total.isFinite else { return .calm }
        return ChladniModes(m: bestM, n: bestN, weight: best / total, drive: drive)
    }

    /// One mode's shape at (x, y) on the unit square, −1 … 1.
    public static func shape(m: Double, n: Double, x: Double, y: Double) -> Double {
        let mx = Foundation.cos(m * Double.pi * x), ny = Foundation.cos(n * Double.pi * y)
        if m == n { return mx * ny }
        let nx = Foundation.cos(n * Double.pi * x), my = Foundation.cos(m * Double.pi * y)
        return 0.5 * (mx * ny - nx * my)
    }

    /// The plate's displacement at (x, y): the modes' shapes by their weights, −1 … 1.
    public static func displacement(x: Double, y: Double, modes: ChladniModes) -> Double {
        var sum = 0.0
        for index in 0..<count where modes.weight[index] > 0 {
            sum += modes.weight[index] * shape(m: modes.m[index], n: modes.n[index], x: x, y: y)
        }
        return sum
    }

    /// How much sand lies where the plate moves by `displacement`: 1 on a nodal line, falling off
    /// over `sandWidth`.
    public static func sand(_ displacement: Double) -> Double {
        guard displacement.isFinite else { return 0 }
        let t = displacement / sandWidth
        return Foundation.exp(-t * t)
    }

    /// The light a point of the picture shows: never below the Field's ambient, and as bright as
    /// its sand times the (flash-guarded) drive.
    public static func luminance(sand: Double, drive: Double) -> Double {
        let lit = Swift.min(1, Swift.max(0, sand.isFinite ? sand : 0)) * Swift.min(1, Swift.max(0, drive.isFinite ? drive : 0))
        return FieldPulse.ambient + (1 - FieldPulse.ambient) * lit
    }
}

/// How the plate moves from one figure to the next, frame by frame. A new figure is never cut
/// in: the plate cross-fades from the figure it shows to the new one over `morphSeconds`, and only
/// takes the next figure once that fade is done — so it changes figure at most 1 / `morphSeconds`
/// times a second, whatever the sound does. The drive's brightness passes the Field's
/// `FlashLimit`. Together that keeps the plate under WCAG 2.3.1's three flashes a second.
public struct ChladniMotion: Equatable, Sendable {
    public struct Shown: Equatable, Sendable {
        public var from = ChladniModes.calm
        public var to = ChladniModes.calm
        /// 0 shows `from`, 1 shows `to`; eased, so a fade starts and ends without a kink.
        public var mix = 1.0
        /// The flash-guarded brightness of the sand, 0 … 1.
        public var light = 0.0

        public init() {}

        /// The plate's displacement at (x, y) in this frame.
        public func displacement(x: Double, y: Double) -> Double {
            let a = ChladniPlate.displacement(x: x, y: y, modes: from)
            let b = ChladniPlate.displacement(x: x, y: y, modes: to)
            return a + (b - a) * mix
        }

        /// The light at (x, y) in this frame.
        public func luminance(x: Double, y: Double) -> Double {
            ChladniPlate.luminance(sand: ChladniPlate.sand(displacement(x: x, y: y)), drive: light)
        }
    }

    public static let morphSeconds = 0.6
    /// Weight changes smaller than this keep the figure: the sound's small wobbles do not restart fades.
    public static let weightTolerance = 0.05

    private var from = ChladniModes.calm
    private var to = ChladniModes.calm
    private var progress = 1.0
    private var light = FlashLimit()
    private var hasSeeded = false
    /// How many figures this motion has taken, for tests and the log.
    public private(set) var figuresTaken = 0

    public init() {}

    /// One frame `seconds` after the last, towards `target`. `still` (Reduce Motion, the lowest
    /// detail) holds the figure; the brightness still follows, guarded.
    public mutating func step(towards target: ChladniModes, after seconds: Double, still: Bool) -> Shown {
        if !hasSeeded {
            hasSeeded = true
            from = target
            to = target
            progress = 1
            light = FlashLimit(value: target.drive)
        }
        let elapsed = seconds.isFinite && seconds > 0 ? seconds : 0
        if !still {
            if progress >= 1, target.figureDiffers(from: to) {
                from = to
                to = target
                progress = 0
                figuresTaken += 1
            }
            progress = Swift.min(1, progress + elapsed / Self.morphSeconds)
        }
        var shown = Shown()
        shown.from = from
        shown.to = to
        shown.mix = progress * progress * (3 - 2 * progress)
        shown.light = light.next(towards: target.drive, after: elapsed)
        return shown
    }
}
