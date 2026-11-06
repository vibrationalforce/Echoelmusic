import Foundation

/// A dish of water on a speaker (the earlier app's `FaradayDish`, ported as its proven core): the
/// surface answers a vertical drive at HALF the drive frequency (Faraday, 1831; Benjamin–Ursell
/// 1954), and the wavenumber that survives obeys the gravity–capillary relation
/// `ω² = (g·k + σ·k³/ρ)·tanh(k·h)` with `ω = 2π·f/2`. The drive's acceleration against the
/// viscous threshold `8·ν·k·ω / tanh(k·h)` decides whether a pattern appears at all — silence is
/// a mirror — and the share of capillary restoring force chooses square (gravity side) or
/// hexagonal (capillary side) lattices. Pure; valid for ONE driving frequency (a chord forces
/// combination tongues no superposition reproduces), which is why the Field drives it with the
/// strongest partial only.
public enum FaradayDish {
    /// Water at room temperature in a shallow dish, 3 mm deep.
    public struct Fluid: Equatable, Sendable {
        public var surfaceTension: Double
        public var density: Double
        public var kinematicViscosity: Double
        public var depth: Double

        public static let water = Fluid(surfaceTension: 0.0728, density: 998.0,
                                        kinematicViscosity: 1.0e-6, depth: 0.003)
    }

    /// What the surface does under one drive.
    public struct Response: Equatable, Sendable {
        /// The surface's own frequency: half the drive's.
        public var responseHz: Double
        /// Radians per metre.
        public var wavenumber: Double
        /// The capillary share of the restoring force, 0 (gravity) … 1 (surface tension).
        public var capillaryFraction: Double
        /// 0 below the threshold (a flat mirror) … 1 at a full lattice.
        public var patternStrength: Double
    }

    public static let gravity = 9.81
    public static let driveHzRange: ClosedRange<Double> = 20...20_000
    /// The acceleration of the speaker cone at full drive, m/s²: a choice (a small speaker, loud).
    public static let speakerAccelerationAtFullDrive = 200.0
    /// The excess over threshold at which the lattice is fully formed.
    public static let saturationExcess = 1.0
    static let bisectionSteps = 64
    public static let squareLatticeCapillaryFraction = 0.90
    public static let hexagonalLatticeCapillaryFraction = 0.985

    static func omegaSquared(wavenumber k: Double, fluid: Fluid) -> Double {
        (gravity * k + fluid.surfaceTension * k * k * k / fluid.density) * Foundation.tanh(k * fluid.depth)
    }

    /// The wavenumber whose waves ring at `responseHz`, by bisection over ten decades.
    public static func wavenumber(responseHz: Double, fluid: Fluid = .water) -> Double? {
        guard responseHz.isFinite, responseHz > 0 else { return nil }
        let omega = 2 * Double.pi * responseHz
        let target = omega * omega
        var low = 1e-3, high = 1e7
        for _ in 0..<bisectionSteps {
            let middle = (low * high).squareRoot()
            if omegaSquared(wavenumber: middle, fluid: fluid) < target { low = middle } else { high = middle }
        }
        return (low * high).squareRoot()
    }

    /// The surface under a drive of `driveHz` at `drive` (0 … 1 of full); nil for no frequency.
    public static func response(driveHz: Double, drive: Double, fluid: Fluid = .water) -> Response? {
        guard driveHz.isFinite, driveHz > 0 else { return nil }
        let hertz = Swift.min(Swift.max(driveHz, driveHzRange.lowerBound), driveHzRange.upperBound)
        let level = drive.isFinite ? Swift.min(Swift.max(drive, 0), 1) : 0
        let responseHz = hertz / 2
        guard let k = wavenumber(responseHz: responseHz, fluid: fluid), k > 0 else { return nil }
        let gravityTerm = gravity * k
        let capillaryTerm = fluid.surfaceTension * k * k * k / fluid.density
        let omega = 2 * Double.pi * responseHz
        let threshold = 8 * fluid.kinematicViscosity * k * omega / Foundation.tanh(k * fluid.depth)
        let excess = level * speakerAccelerationAtFullDrive / threshold - 1
        let strength = excess <= 0 ? 0 : Swift.min(1, (excess / saturationExcess).squareRoot())
        return Response(responseHz: responseHz, wavenumber: k,
                        capillaryFraction: capillaryTerm / (gravityTerm + capillaryTerm),
                        patternStrength: strength)
    }

    /// 0 = square lattice, 1 = hexagonal, smoothly between the two capillary fractions.
    public static func latticeHexagonality(capillaryFraction: Double) -> Double {
        guard capillaryFraction.isFinite else { return 0 }
        let span = hexagonalLatticeCapillaryFraction - squareLatticeCapillaryFraction
        let t = Swift.min(Swift.max((capillaryFraction - squareLatticeCapillaryFraction) / span, 0), 1)
        return t * t * (3 - 2 * t)
    }
}

/// The four looks the earlier app's Field proved on stage — Dish, Water, Aurora, Depth — as pure
/// functions on the CPU, the same arithmetic the Metal shader runs (`FieldShader.field`), so the
/// flash law can be measured here, frame by frame, without a GPU. Every look returns a scalar
/// field 0 … 1; the picture's light is `FieldPulse.ambient + (1 − ambient) · energy`, coloured by
/// the key's tone like the rings and the plate.
///
/// The rates that move a look are its `phase` multipliers on the song's bar phase (capped at
/// `FieldPulse.maximumRateHz` turns a second): Dish 0.4, Water 0.4 (its fastest wave 1.7× that),
/// Aurora 0.35, Depth 0.30 — each under one hertz of drift, and none squares its phase.
public enum FieldLook {
    /// Shader literals: written from these numbers so the GPU cannot drift from the CPU mirror.
    public static let dishPhaseRate = 0.4
    public static let waterPhaseRate = 0.4
    public static let auroraPhaseRate = 0.35
    public static let depthPhaseRate = 0.30
    /// How much water the window shows edge to edge, metres: a macro view of the dish (a choice).
    public static let dishWindowMetres = 0.024
    /// The dish lattice's spatial frequency in the shader's coordinate, radians per unit: below 3
    /// a ripple is wider than the dish; above the ceiling it aliases on a phone's pixels.
    public static let dishKRange: ClosedRange<Double> = 3...110
    /// The pitch the water and aurora are anchored at: their scale at middle C.
    public static let anchorHz = 261.63
    /// Depth caustics: the focus number at a full lattice, the intensity ceiling, three depths.
    public static let depthFocusNumber = 3.0
    public static let depthIntensityCeiling = 8.0
    public static let depthFullBright = 2.5
    public static let depthFocusRatios = SIMD3<Double>(1.0, 1.7, 2.89)
    public static let depthWeights = SIMD3<Double>(1.0, 0.55, 0.30)

    /// The moiré: two gratings at 0.2 rad to each other, each line this share of its period wide.
    public static let moireTilt = 0.2
    public static let moireLineWidth = 0.08
    /// How bright the two gratings light together, over the ambient.
    public static let moireGain = 0.45

    // MARK: - The looks, as the shader writes them

    /// Two thin line gratings, spatial frequencies `k1` and `k2` (radians per unit), the second
    /// tilted and moved by `phase` turns of its own period: where the lines fall together the
    /// moiré shows, and only the second grating moves, so no point changes faster than its drift.
    public static func moire(x: Double, y: Double, k1: Double, k2: Double, phase: Double) -> Double {
        func line(_ coordinate: Double, _ k: Double, _ shift: Double) -> Double {
            let t = coordinate * k / (2 * Double.pi) - shift
            let f = t - t.rounded(.down)
            let distance = Swift.min(f, 1 - f)
            return 1 - smoothstep(0, moireLineWidth, distance)
        }
        let tilted = x * Foundation.cos(moireTilt) + y * Foundation.sin(moireTilt)
        // The lit share of the two (max): where the lines fall together they cover less, so the
        // fringes carry light — a plain sum would hold none, only crossings.
        return clamp(2 * moireGain * Swift.max(line(x, k1, 0), line(tilted, k2, phase)), 0, 1)
    }

    /// A dish of water lit from above: a square or hexagonal standing lattice of wavenumber `k`
    /// focusing the lamp into a caustic net; at `strength` 0 a still mirror with the lamp in it.
    public static func dish(x: Double, y: Double, k: Double, strength: Double, hex: Double,
                            phase: Double, coherence: Double) -> Double {
        let square = 0.5 * (cos(x * k) + cos(y * k))
        let d2 = -0.5 * x + 0.8660254 * y, d3 = -0.5 * x - 0.8660254 * y
        let hexagonal = (cos(x * k) + cos(d2 * k) + cos(d3 * k)) * 0.3333
        let height = mix(square, hexagonal, hex)
        let breathe = 0.85 + 0.15 * sin(phase * dishPhaseRate)
        let lens = clamp(0.88 * strength * breathe, 0, 0.88)
        let caustic = (1 - lens) / (1 - lens * height)
        let net = pow(clamp(caustic, 0, 1), mix(1.5, 3.0, coherence))
        let mirror = 0.55 + 0.30 * exp(-(x * x + y * y) * 2.5)
        return clamp(mix(mirror, net, clamp(strength, 0, 1)), 0, 1)
    }

    /// Crossing wave trains on a pool floor; spacing ∝ f^⅔ (the capillary branch), anchored at
    /// middle C; the breath is the drive's amplitude, the coherence sharpens the filaments.
    public static func water(x: Double, y: Double, toneHz: Double, phase: Double,
                             coherence: Double, breath: Double) -> Double {
        let t = phase * waterPhaseRate
        let scale = clamp(5.5 * pow(Swift.max(toneHz, 20) / anchorHz, 0.6666667), 3, 24)
        var wave = sin(x * scale + t) * cos(y * (scale * 0.818) - t * 0.7)
        wave += sin((x * x + y * y).squareRoot() * (scale * 1.545) - t * 1.1)
        wave += sin((x + y) * (scale * 0.727) + t * 0.5)
        let net = clamp(0.5 + mix(0.12, 0.24, breath) * wave, 0, 1)
        return pow(net, mix(3.0, 6.0, coherence))
    }

    /// A unit-peak Chapman production profile: the height a curtain of light is brightest at.
    static func chapman(_ u: Double) -> Double {
        let e = exp(-clamp(u, -6, 40))
        return exp(clamp(1 - u - e, -30, 0))
    }

    /// Two curtains with a sharp lower edge; rays spaced by the pitch; the breath swells them.
    public static func aurora(x: Double, y: Double, toneHz: Double, phase: Double,
                              coherence: Double, breath: Double) -> Double {
        let t = phase * auroraPhaseRate
        let wave = sin(x * 2.2 + t) * 0.35 + sin(x * 4.7 - t * 0.6) * 0.15
        let height = mix(0.30, 0.14, clamp(coherence, 0, 1))
        let curtain = chapman((y - wave) / height)
        let wave2 = sin(x * 3.1 - t * 0.8) * 0.30
        let curtain2 = chapman((y + 0.4 - wave2) / (height * 1.35))
        let rays = clamp(3.0 * Swift.max(toneHz, 20) / anchorHz, 2, 14)
        let ray = 0.72 + 0.28 * cos(x * rays * 6.2831853)
        let swell = 0.80 + 0.20 * clamp(breath, 0, 1)
        return clamp((curtain + curtain2 * 0.6) * ray * swell, 0, 1)
    }

    /// The dish's surface from below: the light it focuses on the floor at three depths.
    public static func depth(x: Double, y: Double, phase: Double, coherence: Double, breath: Double,
                             k: Double, strength: Double) -> Double {
        let cxx = -0.5 * cos(x * k), cyy = -0.5 * cos(y * k)
        let breathe = 0.85 + 0.15 * sin(phase * depthPhaseRate)
        let sink = mix(0.8, 1.2, clamp(breath, 0, 1))
        let phi = depthFocusNumber * clamp(strength, 0, 1) * breathe * sink
        var lit = 0.0
        for index in 0..<3 {
            let focus = phi * depthFocusRatios[index]
            let determinant = (1 + focus * cxx) * (1 + focus * cyy)
            lit += depthWeights[index] * Swift.min(1 / Swift.max(Swift.abs(determinant), 1 / depthIntensityCeiling),
                                                   depthIntensityCeiling)
        }
        let net = clamp(lit / depthWeights.sum() / depthFullBright, 0, 1)
        return pow(net, mix(1.0, 1.6, coherence))
    }

    // MARK: - The picture's light, as the shader composes it

    /// The light at (`u`, `v`) — the picture's own coordinates, 0 … 1 from the bottom left — of
    /// `pattern` in a frame of `aspect`, before the tone's colour: what the flash law measures.
    /// `turns` is the look's phase (`FieldLookMotion.Shown.turns(fieldPhase:)`). The plate's
    /// mirror is its continuous sand (the shader's grains sample it).
    public static func light(_ pattern: FieldPattern, u: Double, v: Double, aspect: Double,
                             field: FieldMotion.Shown, look: FieldLookMotion.Shown,
                             plate: ChladniMotion.Shown, turns: Double) -> Double {
        let ambient = FieldPulse.ambient
        switch pattern {
        case .chladni:
            let side = Swift.min(aspect, 1) * 0.92
            let px = (u * aspect - 0.5 * aspect) / side + 0.5, py = (v - 0.5) / side + 0.5
            guard (0...1).contains(px), (0...1).contains(py) else { return 0 }
            return plate.luminance(x: px, y: py)
        case .rings:
            return ambient + (1 - ambient) * ringsEnergy(u: u, v: v, aspect: aspect, field: field, turns: turns)
        case .weave:
            let energy = BarWeave.light(u: u, v: v, aspect: aspect, position: look.weavePosition, seed: look.weaveSeed,
                                        level: field.levelLight, strength: look.weaveLight)
            return ambient + (1 - ambient) * energy
        case .moire:
            let d = ((u * aspect - 0.5 * aspect) * (u * aspect - 0.5 * aspect) + (v - 0.5) * (v - 0.5)).squareRoot()
            let x = (u - 0.5) * 2 * aspect, y = (v - 0.5) * 2
            let vignette = smoothstep(1.6, 0, d)
            let energy = clamp(moire(x: x, y: y, k1: look.moireK1, k2: look.moireK2, phase: look.moirePhase) * vignette, 0, 1)
            return ambient + (1 - ambient) * energy
        case .dish, .water, .aurora, .depth:
            let d = ((u * aspect - 0.5 * aspect) * (u * aspect - 0.5 * aspect) + (v - 0.5) * (v - 0.5)).squareRoot()
            let x = (u - 0.5) * 2 * aspect, y = (v - 0.5) * 2
            let phase = turns * 2 * Double.pi
            let coherence = clamp(field.coherence, 0, 1), breath = clamp(field.breath, 0, 1)
            let value: Double = switch pattern {
            case .dish: dish(x: x, y: y, k: look.dishK, strength: look.dishStrength, hex: look.dishHex,
                             phase: phase, coherence: coherence)
            case .water: water(x: x, y: y, toneHz: look.soundHz, phase: phase, coherence: coherence, breath: breath)
            case .aurora: aurora(x: x, y: y, toneHz: look.soundHz, phase: phase, coherence: coherence, breath: breath)
            default: depth(x: x, y: y, phase: phase, coherence: coherence, breath: breath,
                           k: look.dishK, strength: look.dishStrength)
            }
            let spread = 0.85 + 0.35 * breath
            let vignette = smoothstep(0.9 + 0.5 * spread, 0, d)
            let energy = clamp(value * vignette * (0.35 + 0.65 * clamp(field.levelLight, 0, 1)), 0, 1)
            return ambient + (1 - ambient) * energy
        }
    }

    /// The rings' energy (`field_fragment`'s rings branch), for the blend's flash measure.
    static func ringsEnergy(u: Double, v: Double, aspect: Double, field: FieldMotion.Shown, turns: Double) -> Double {
        let d = ((u * aspect - 0.5 * aspect) * (u * aspect - 0.5 * aspect) + (v - 0.5) * (v - 0.5)).squareRoot()
        let coherence = clamp(field.coherence, 0, 1)
        let density = clamp(field.density, 4, 120)
        let spread = 0.85 + 0.35 * clamp(field.breath, 0, 1)
        let phase = turns * 2 * Double.pi
        let vignette = smoothstep(0.9 + 0.5 * spread, 0, d)
        let pitchK = clamp(Swift.max(field.toneHz, 20) / 261.63, 0.5, 2.0)
        let k = clamp(density * pitchK, 4, 120)
        let p = phase * FieldPulse.foldDamping
        let w1 = sin(d * k - p), w2 = sin(d * k * mix(1.6, 1.02, coherence) - p * 0.5)
        let interference = (w1 + w2) * 0.5
        let rings = pow(interference * interference, mix(1.0, 2.6, coherence))
        let ringRadius = (0.12 + 0.40 * clamp(field.beatPhase, 0, 1)) * spread
        let ringT = (d - ringRadius) / 0.012
        let ring = exp(-ringT * ringT) * clamp(field.beatLight, 0, 1)
        let beat = (0.5 - 0.5 * cos(field.pulsePhase * 2 * Double.pi)) * (field.hasPulse ? 1 : 0)
        let restGlow = 0.05 + 0.18 * clamp(field.centreLight, 0, 1)
        let bloomEdge = (0.34 + 0.18 * beat) * spread
        let bloom = restGlow * (0.80 + FieldPulse.bloomSwing * beat) * smoothstep(bloomEdge, 0, d)
        let haloT = (d - (0.30 + 0.15 * coherence) * spread) / 0.010
        let halo = exp(-haloT * haloT) * 0.22 * (field.hasCoherence ? 1 : 0)
        return clamp(rings * vignette * (0.35 + 0.65 * clamp(field.levelLight, 0, 1)) + bloom + ring + halo, 0, 1)
    }

    static func mix(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
    static func clamp(_ x: Double, _ low: Double, _ high: Double) -> Double {
        x.isFinite ? Swift.min(Swift.max(x, low), high) : low
    }
    static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t = clamp((x - edge0) / (edge1 - edge0), 0, 1)
        return t * t * (3 - 2 * t)
    }
}

/// How the looks move from frame to frame and how two of them blend (the earlier app's style A /
/// style B / blend, ported as its core). The sound the looks hear is the master's partials — the
/// same analysis the Chladni plate reads: the strongest partial is the pitch that drives the dish
/// and spaces the water and the aurora, the partials' combined level is the drive. Silence glides
/// the pitch back to the key's tonic.
///
/// The flash law, held here and measured in `FieldLookTests`:
/// - the drive's lattice strength and the blend's mix pass a `FlashLimit` each, so neither swings
///   the light faster than three flashes a second, whatever the sound or a finger asks;
/// - a new partner is never cut in: the mix fades to 0, the partner changes, the mix fades back;
/// - while two looks are mixed, their shared phase runs at `blendPhaseShare` of the song's rate,
///   so the UNION of two drifting looks stays under the ceiling (the earlier app's rule).
/// Under Reduce Motion or the lowest detail (`still`) the pitch and the lattice hold; the lights
/// still follow, guarded.
public struct FieldLookMotion: Equatable, Sendable {
    /// What one frame of the looks shows, beyond `FieldMotion.Shown`.
    public struct Shown: Equatable, Sendable {
        public var primary = FieldPattern.rings
        public var partner = FieldPattern.rings
        /// How much of `partner` shows, 0 … 1, flash-guarded.
        public var mix = 0.0
        /// Added to the song's field phase (turns): the blend's slower drift, accumulated.
        public var phaseOffset = 0.0
        /// The pitch the looks hear, hertz.
        public var soundHz = FieldFrame.middleC
        /// The dish lattice in shader units, its strength (guarded) and its hexagonality.
        public var dishK = 25.0
        public var dishStrength = 0.0
        public var dishHex = 0.5
        /// The moiré's two gratings (radians per unit) and the second's drift (turns).
        public var moireK1 = 24.0
        public var moireK2 = 24.0
        public var moirePhase = 0.0
        /// The weave's shown place in bars, counted so the key's row stands complete at 1
        /// (`BarWeave.words`), and its first row.
        public var weavePosition = 1.0
        public var weaveSeed = BarWeave.seed(keyMask: 0)
        /// The weave's light, 0 … 1, flash-guarded: it fades through dark to a place it cannot glide to.
        public var weaveLight = 1.0

        public init() {}

        /// The looks' phase in turns for a frame whose song phase is `fieldPhase`.
        public func turns(fieldPhase: Double) -> Double {
            let sum = fieldPhase + phaseOffset
            guard sum.isFinite else { return 0 }
            let wrapped = sum - sum.rounded(.down)
            return wrapped >= 1 ? 0 : wrapped
        }

        /// Whether two looks are on screen at once.
        public var isBlending: Bool { mix > FieldLookMotion.blendThreshold && primary != partner }
    }

    /// The share of the song's drift two mixed looks move at.
    public static let blendPhaseShare = 0.5
    /// Under this the shader draws the primary alone.
    public static let blendThreshold = 0.001
    /// How fast the heard pitch and the lattice glide (seconds): a note change sweeps the picture.
    public static let pitchGlideSeconds = 0.3
    public static let latticeGlideSeconds = 0.4
    public static let hexGlideSeconds = 0.5

    private var shown = Shown()
    private var moirePulse = FieldPulse()
    private var mixLight = FlashLimit()
    private var strengthLight = FlashLimit()
    private var weaveLight = FlashLimit(value: 1)
    private var previousFieldPhase: Double?
    private var hasSeeded = false

    public init() {}

    /// The pitch and the drive the master's strongest partials give: the strongest partial, and
    /// the combined level mapped as the plate maps it (−54 dBFS dark … −6 dBFS full). Non-finite
    /// or non-positive partials are ignored; no partial is no pitch and no drive.
    public static func hearing(frequencies: SIMD8<Double>, amplitudes: SIMD8<Double>,
                               count: Int) -> (hertz: Double?, drive: Double) {
        let used = Swift.min(Swift.max(count, 0), 8)
        var power = 0.0, strongest = 0.0
        var hertz: Double?
        for index in 0..<used {
            let amplitude = amplitudes[index], frequency = frequencies[index]
            guard amplitude.isFinite, amplitude > 0, frequency.isFinite, frequency > 0 else { continue }
            power += amplitude * amplitude
            if amplitude > strongest {
                strongest = amplitude
                hertz = frequency
            }
        }
        guard power > 0, let hertz else { return (nil, 0) }
        let decibels = 10 * Foundation.log10(power)
        let drive = (decibels - ChladniPlate.quietDecibels) / (ChladniPlate.fullDecibels - ChladniPlate.quietDecibels)
        guard drive > 0 else { return (nil, 0) }
        return (hertz, Swift.min(drive, 1))
    }

    /// One frame `seconds` after the last. `primary` and `partner` are the chosen looks (`partner`
    /// nil for none), `mix` the chosen share 0 … 1; `hertz`/`drive` what the master sounds
    /// (`hearing`), `tonicHz` the key's tonic, `fieldPhase` this frame's song phase (turns).
    public mutating func step(primary: FieldPattern, partner: FieldPattern?, mix target: Double,
                              hertz: Double?, drive: Double, tonicHz: Double, fieldPhase: Double,
                              after seconds: Double, still: Bool, patternScale: Double,
                              beat: TuningBeat = .unison, bars: Double = 0, keyMask: UInt16 = 0) -> Shown {
        let elapsed = seconds.isFinite && seconds > 0 ? seconds : 0
        let level = drive.isFinite ? Swift.min(Swift.max(drive, 0), 1) : 0
        let wanted = hertz.flatMap { $0.isFinite && $0 > 0 && level > 0 ? $0 : nil }
            ?? (tonicHz.isFinite && tonicHz > 0 ? tonicHz : FieldFrame.middleC)
        let scale = patternScale.isFinite ? Swift.min(Swift.max(patternScale, 0.1), 1) : 1
        let ceiling = Swift.max(FieldLook.dishKRange.lowerBound, FieldLook.dishKRange.upperBound * scale)
        let dish = FaradayDish.response(driveHz: wanted, drive: level)
        if !hasSeeded {
            hasSeeded = true
            shown.primary = primary
            shown.partner = partner ?? primary
            shown.soundHz = wanted
            shown.dishK = Self.lattice(dish, ceiling: ceiling)
            shown.dishHex = FaradayDish.latticeHexagonality(capillaryFraction: dish?.capillaryFraction ?? 1)
            strengthLight = FlashLimit(value: dish?.patternStrength ?? 0)
            mixLight = FlashLimit(value: partner == nil ? 0 : target)
            previousFieldPhase = fieldPhase
            shown.weavePosition = Self.weaveTarget(bars)
            shown.weaveSeed = BarWeave.seed(keyMask: keyMask)
        }
        shown.primary = primary

        // The partner: never cut in under a visible mix — fade out, change, fade back in.
        let requested = partner ?? shown.partner
        var mixGoal = partner == nil || !target.isFinite ? 0 : Swift.min(Swift.max(target, 0), 1)
        if requested != shown.partner {
            if mixLight.value <= Self.blendThreshold { shown.partner = requested } else { mixGoal = 0 }
        }
        shown.mix = mixLight.next(towards: mixGoal, after: elapsed)

        // The shared phase: while blending, the looks drift at a share of the song's rate.
        if let previous = previousFieldPhase, fieldPhase.isFinite, previous.isFinite {
            var step = fieldPhase - previous
            if step < 0 { step += 1 }
            if shown.isBlending { shown.phaseOffset -= step * (1 - Self.blendPhaseShare) }
            shown.phaseOffset -= shown.phaseOffset.rounded(.down)
        }
        previousFieldPhase = fieldPhase

        // The sound: pitch and lattice glide (held while still), the lattice's light is guarded.
        if !still {
            shown.soundHz = Self.glideLog(shown.soundHz, wanted, tau: Self.pitchGlideSeconds, seconds: elapsed)
            shown.dishK = Self.glideLog(shown.dishK, Self.lattice(dish, ceiling: ceiling),
                                        tau: Self.latticeGlideSeconds, seconds: elapsed)
            shown.dishHex = FieldMotion.ease(shown.dishHex,
                                             FaradayDish.latticeHexagonality(capillaryFraction: dish?.capillaryFraction ?? 1),
                                             tau: Self.hexGlideSeconds, seconds: elapsed)
        }
        shown.dishStrength = strengthLight.next(towards: dish?.patternStrength ?? 0, after: elapsed)

        // The moiré: the first grating spaced by the lower note's partial, the second by the
        // upper's, so their ratio is the interval's; the second drifts at the beat's drift —
        // held while still, at the blend's share while two looks show (`FieldPulse` caps it).
        let lower = Double(beat.p) * beat.lowerHz, upper = Double(beat.q) * beat.upperHz
        if lower.isFinite, upper.isFinite, lower > 0, upper > 0 {
            let k1 = Swift.min(Swift.max(6 * lower / FieldLook.anchorHz, FieldLook.dishKRange.lowerBound), ceiling / 1.04)
            shown.moireK1 = k1
            shown.moireK2 = k1 * upper / lower
        }
        // The pulse slews and caps the beat's rate; the blend's share applies at once, as the
        // shared phase's does, so two looks never drift together at full speed.
        moirePulse.advance(towards: still ? 0 : beat.driftHz, after: elapsed)
        let advanced = shown.moirePhase + moirePulse.rateHz * (shown.isBlending ? Self.blendPhaseShare : 1) * elapsed
        shown.moirePhase = advanced.isFinite ? advanced - advanced.rounded(.down) : 0

        // The weave: its rows follow the song's bars no faster than `BarWeave.maximumRowsPerSecond`
        // (at the blend's share while two looks show). What they cannot glide to — a place behind
        // (a seek, the loop's wrap), one more than `BarWeave.maximumLead` rows ahead, a new key — is
        // never cut in: the weave's light fades, the rows change unseen in the dark, the light comes
        // back, as a new blend partner does. Held still, the rows stand where they are; a new key
        // still fades through, guarded.
        let target = Self.weaveTarget(bars)
        let seed = BarWeave.seed(keyMask: keyMask)
        let lead = target - shown.weavePosition
        var weaveGoal = 1.0
        if seed != shown.weaveSeed || (!still && (lead < -BarWeave.backwardTolerance || lead > BarWeave.maximumLead)) {
            if weaveLight.value <= Self.blendThreshold {
                if !still { shown.weavePosition = target }
                shown.weaveSeed = seed
            } else {
                weaveGoal = 0
            }
        } else if !still, lead > 0 {
            let rate = BarWeave.maximumRowsPerSecond * (shown.isBlending ? Self.blendPhaseShare : 1)
            shown.weavePosition += Swift.min(lead, rate * elapsed)
        }
        shown.weaveLight = weaveLight.next(towards: weaveGoal, after: elapsed)
        return shown
    }

    /// The weave's place for a song at `bars`: one row on, so the key's row is whole from the start.
    static func weaveTarget(_ bars: Double) -> Double {
        (bars.isFinite ? Swift.min(Swift.max(bars, 0), 1e12) : 0) + 1
    }

    /// The dish's wavenumber in the shader's coordinate (half the window spans one unit).
    static func lattice(_ dish: FaradayDish.Response?, ceiling: Double) -> Double {
        let k = (dish?.wavenumber ?? 0) * FieldLook.dishWindowMetres / 2
        return Swift.min(Swift.max(k.isFinite ? k : 0, FieldLook.dishKRange.lowerBound), ceiling)
    }

    /// Exponential glide in the logarithm: an octave takes as long at any height.
    static func glideLog(_ value: Double, _ target: Double, tau: Double, seconds: Double) -> Double {
        guard value > 0, target > 0, value.isFinite, target.isFinite else { return target > 0 ? target : value }
        return Foundation.exp(FieldMotion.ease(Foundation.log(value), Foundation.log(target), tau: tau, seconds: seconds))
    }
}

/// What the Field shows instead of a picture when the musician reads the sound: the spectrum of
/// the master, or its triggered waveform. Kept on this device (`storageKey`), never in the song; the
/// raw values are stored, never renamed, a new one goes at the end.
public enum FieldMeter: String, CaseIterable, Sendable {
    /// The picture: no meter.
    case off
    /// The master's spectrum, 20 Hz … 20 kHz on a log axis.
    case spectrum
    /// The master's waveform, triggered on a rising zero crossing so a steady tone stands still.
    case scope
    /// The master's stereo phase: a goniometer (mid up, side across) and the correlation, +1 mono,
    /// 0 unrelated, −1 cancelling in mono (`StereoPhase`).
    case phase
    /// The master's strongest partials as ratios to the lowest, each labelled with the nearest
    /// whole number and its distance in cents (`PartialRatios`): harmonic or inharmonic, measured.
    case partials

    public static let storageKey = "field.meter"

    public var title: String {
        switch self {
        case .off: "Picture"
        case .spectrum: "Spectrum"
        case .scope: "Scope"
        case .phase: "Phase"
        case .partials: "Partials"
        }
    }

    /// The stored name read back; anything unknown is the picture.
    public init(stored: String?) {
        self = stored.flatMap(FieldMeter.init(rawValue:)) ?? .off
    }
}

/// How a meter's reading follows the sound: up quickly, down slowly (a peak meter's ballistics),
/// so a level is legible and a drum hit does not strobe the line. Time-based, the same at any
/// frame rate. The meters draw thin lines, never filled areas: a line's lit area stays far below
/// the quarter of the picture a flash is measured over (WCAG 2.3.1).
public enum MeterBallistics {
    public static let attackSeconds = 0.03
    public static let releaseSeconds = 0.35

    /// `shown` one step `seconds` later towards `target`; non-finite readings are 0.
    public static func follow(_ shown: Double, _ target: Double, after seconds: Double) -> Double {
        let goal = target.isFinite ? target : 0
        let from = shown.isFinite ? shown : 0
        return FieldMotion.ease(from, goal, tau: goal > from ? attackSeconds : releaseSeconds, seconds: seconds)
    }
}
