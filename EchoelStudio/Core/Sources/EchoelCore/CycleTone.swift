import Foundation

/// A natural cycle heard as a tone. Its frequency, one over its period, is doubled by whole octaves
/// until it lies between C3 and C4, each less 50 cents at A = 440 Hz, so its key is always in
/// octave 3; the same tone seven octaves lower, times 60, is its tempo; and the concert pitch that
/// puts the tone exactly on its key is the one a song can take from it. This is octave
/// transposition after Hans Cousto (*Die Kosmische Oktave*, 1984): a calculation from the period,
/// shown with its numbers. It claims no effect.
public struct CycleTone: Equatable, Sendable {
    /// C3 less 50 cents at A = 440 Hz: the lowest tone a cycle is moved to.
    public static let lowestHertz = 440 * Foundation.pow(2, -21.5 / 12)
    /// One octave above `lowestHertz`, not included.
    public static let highestHertz = 2 * lowestHertz
    /// The tempo is the tone this many octaves lower.
    public static let tempoOctaves = 7

    public let periodSeconds: Double
    /// The cycle's own frequency, one over its period.
    public let cycleHertz: Double
    /// How many times the cycle's frequency was doubled to reach the tone (negative: halved).
    public let octaves: Int
    /// The tone, in `lowestHertz ..< highestHertz`.
    public let hertz: Double

    /// Nil for a period that is not a time (zero, negative, not finite).
    public init?(periodSeconds: Double) {
        guard periodSeconds.isFinite, periodSeconds > 0 else { return nil }
        let cycle = 1 / periodSeconds
        guard cycle.isFinite, cycle > 0 else { return nil }
        // Whole octaves, counted from the logarithm and then settled exactly at the window's edges.
        let estimate = (Foundation.log2(Self.lowestHertz / cycle)).rounded(.up)
        guard estimate.isFinite, abs(estimate) < 1_000 else { return nil }
        var octaves = Int(estimate)
        var tone = cycle * Foundation.pow(2, Double(octaves))
        // At most a step or two either way once the estimate is in; a tone that is not finite
        // (a period at the very edge of what a Double holds) has no tone.
        guard tone.isFinite, tone > 0 else { return nil }
        for _ in 0..<4 where tone < Self.lowestHertz { tone *= 2; octaves += 1 }
        for _ in 0..<4 where tone >= Self.highestHertz { tone /= 2; octaves -= 1 }
        guard tone.isFinite, tone >= Self.lowestHertz, tone < Self.highestHertz else { return nil }
        self.periodSeconds = periodSeconds
        self.cycleHertz = cycle
        self.octaves = octaves
        self.hertz = tone
    }

    /// Beats per minute: the tone `tempoOctaves` octaves lower, per minute.
    public var tempo: Double { hertz * 60 / Double(1 << Self.tempoOctaves) }

    /// Semitones from A4 = 440 Hz, not rounded.
    private var semitonesFromA: Double { 12 * Foundation.log2(hertz / 440) }

    /// The tone's key in equal temperament at A = 440 Hz (MIDI number, 48 … 59). A tone halfway
    /// between two keys belongs to the upper one, so the window's lowest tone is C3.
    public var pitch: Int { 69 + Int((semitonesFromA + 0.5).rounded(.down)) }

    /// How far the tone lies from its key at A = 440 Hz, cents (−50 … +50).
    public var centsFromKey: Double { 100 * (semitonesFromA - Double(pitch - 69)) }

    /// The concert pitch A at which the tone is exactly its key; always inside 400 … 480 Hz.
    public var concertPitch: Double { 440 * Foundation.pow(2, centsFromKey / 1200) }
}

/// One natural cycle of the library: a body, the cycle, its period and where the period comes from.
public struct NaturalCycle: Equatable, Sendable, Identifiable {
    public enum Group: String, CaseIterable, Sendable {
        case earth, moon, planet, minorPlanet, planetMoon

        /// The section title on the Cycle Tones page. Pluto stands with the planets, as in the
        /// tables, and the title says so.
        public var title: String {
            switch self {
            case .earth: "Earth"
            case .moon: "Moon"
            case .planet: "Planets and Pluto"
            case .minorPlanet: "Minor Planets"
            case .planetMoon: "Moons"
            }
        }
    }

    /// Stable name, `body.cycle` (never stored in a song).
    public let id: String
    public let body: String
    public let cycle: String
    public let group: Group
    public let periodDays: Double
    public let source: String

    public var tone: CycleTone? { CycleTone(periodSeconds: periodDays * 86_400) }
}

/// The cycles the Sky can play: Earth, its Moon, the planets' orbits, synodic periods and rotations,
/// minor and dwarf planets, and the planets' moons. Periods as H. Cousto tabulates them from NASA
/// and JPL data (the minor planets with the date of the last observation used there); each tone is
/// computed here, not copied. The page's paragraphs, section titles and the sky's one-word cycle
/// names live here too, so a test reads them (Law 8).
public enum CycleLibrary {
    static let tables = "H. Cousto, tuning data, after NASA"
    static let smallBodies = "H. Cousto, tuning data, after the JPL Small-Body Database"
    /// How every number on the page is made, and what the page does — the top of the Cycle Tones page.
    public static let method = "Each tone is an astronomical cycle's frequency, one over its period, doubled by whole "
        + "octaves until its nearest key lies in octave 3, C3 to B3. Its tempo is the same tone seven octaves lower, "
        + "in beats per minute. Its concert pitch is the A at which, in twelve equal steps, the tone is exactly its "
        + "key. The tuning fork beside a cycle sets the song's key, concert pitch or tempo to it, and Undo takes it "
        + "back. These are calculations from the periods; they claim nothing about what a tone does to a listener."

    /// Whose method and whose numbers — the foot of the page.
    public static let credit = "Method after Hans Cousto, Die Kosmische Oktave (1984). Periods as Cousto tabulates "
        + "them, after NASA and the JPL Small-Body Database."

    /// The cycle a body is known by, in one word, for the line under it in the sky.
    public static func word(of body: SkyBodies.Body) -> String {
        switch body {
        case .sun: "Year"
        case .moon: "Month"
        default: "Orbit"
        }
    }

    private static func row(_ id: String, _ body: String, _ cycle: String, _ group: NaturalCycle.Group,
                            days: Double, source: String = tables) -> NaturalCycle {
        NaturalCycle(id: id, body: body, cycle: cycle, group: group, periodDays: days, source: source)
    }

    private static func hours(_ value: Double) -> Double { value / 24 }

    public static let all: [NaturalCycle] = earth + moon + planets + minorPlanets + planetMoons

    /// The cycles of a body the sky draws, the one it is known by first: the Sun's are the Earth's
    /// day and year (the year leads), the Moon's are its months and long cycles (the synodic month
    /// leads), a planet's are its orbit, synodic period and rotation (the orbit leads).
    public static func cycles(of body: SkyBodies.Body) -> [NaturalCycle] {
        switch body {
        case .sun:
            let days = earth.filter { $0.id != "earth.year" }
            return earth.filter { $0.id == "earth.year" } + days
        case .moon:
            return moon
        default:
            return planets.filter { $0.id.hasPrefix(body.rawValue + ".") }
        }
    }

    /// The cycle a body is known by, nil only for a body without cycles.
    public static func primaryCycle(of body: SkyBodies.Body) -> NaturalCycle? {
        cycles(of: body).first
    }

    static let earth: [NaturalCycle] = [
        row("earth.day", "Earth", "Solar day", .earth, days: 1),
        row("earth.siderealDay", "Earth", "Sidereal day", .earth, days: 0.99727),
        row("earth.year", "Earth", "Tropical year", .earth, days: 365.2422),
    ]

    static let moon: [NaturalCycle] = [
        row("moon.synodicMonth", "Moon", "Synodic month", .moon, days: 29.5306),
        row("moon.siderealMonth", "Moon", "Sidereal month", .moon, days: 27.3217),
        row("moon.lunarDay", "Moon", "Lunar day (culmination)", .moon, days: 1.03505),
        row("moon.nodalCycle", "Moon", "Nodal cycle", .moon, days: 6793.3951),
        row("moon.saros", "Moon", "Saros cycle", .moon, days: 6585.3211),
        row("moon.apsidalCycle", "Moon", "Apsidal cycle", .moon, days: 3232.6854),
        row("moon.metonicCycle", "Moon", "Metonic cycle", .moon, days: 6939.6882),
    ]

    static let planets: [NaturalCycle] = [
        row("mercury.orbit", "Mercury", "Orbit (sidereal)", .planet, days: 87.969),
        row("venus.orbit", "Venus", "Orbit (sidereal)", .planet, days: 224.701),
        row("mars.orbit", "Mars", "Orbit (sidereal)", .planet, days: 686.98),
        row("jupiter.orbit", "Jupiter", "Orbit (sidereal)", .planet, days: 4332.59),
        row("saturn.orbit", "Saturn", "Orbit (sidereal)", .planet, days: 10759.2),
        row("uranus.orbit", "Uranus", "Orbit (sidereal)", .planet, days: 30685.9),
        row("neptune.orbit", "Neptune", "Orbit (sidereal)", .planet, days: 60187.6),
        row("pluto.orbit", "Pluto", "Orbit (sidereal)", .planet, days: 90487.3),
        row("mercury.synodic", "Mercury", "Synodic period", .planet, days: 115.8774),
        row("venus.synodic", "Venus", "Synodic period", .planet, days: 583.9205),
        row("mars.synodic", "Mars", "Synodic period", .planet, days: 779.9382),
        row("jupiter.synodic", "Jupiter", "Synodic period", .planet, days: 398.8864),
        row("saturn.synodic", "Saturn", "Synodic period", .planet, days: 378.0929),
        row("uranus.synodic", "Uranus", "Synodic period", .planet, days: 369.66),
        row("neptune.synodic", "Neptune", "Synodic period", .planet, days: 367.49),
        row("mercury.rotation", "Mercury", "Rotation (sidereal)", .planet, days: hours(1407.6)),
        row("venus.rotation", "Venus", "Rotation (sidereal, retrograde)", .planet, days: hours(5832.6)),
        row("mars.rotation", "Mars", "Rotation (sidereal)", .planet, days: hours(24.623)),
        row("jupiter.rotation", "Jupiter", "Rotation (sidereal)", .planet, days: hours(9.925)),
        row("saturn.rotation", "Saturn", "Rotation (sidereal)", .planet, days: hours(10.656)),
        row("uranus.rotation", "Uranus", "Rotation (sidereal, retrograde)", .planet, days: hours(17.24)),
        row("neptune.rotation", "Neptune", "Rotation (sidereal)", .planet, days: hours(16.11)),
    ]

    static let minorPlanets: [NaturalCycle] = [
        row("vesta.orbit", "4 Vesta", "Orbit", .minorPlanet, days: 1325.935, source: smallBodies),
        row("ceres.orbit", "1 Ceres", "Orbit", .minorPlanet, days: 1681.771, source: smallBodies),
        row("pallas.orbit", "2 Pallas", "Orbit", .minorPlanet, days: 1687.411, source: smallBodies),
        row("orcus.orbit", "90482 Orcus", "Orbit", .minorPlanet, days: 89556.926, source: smallBodies),
        row("ixion.orbit", "28978 Ixion", "Orbit", .minorPlanet, days: 91769.411, source: smallBodies),
        row("varuna.orbit", "20000 Varuna", "Orbit", .minorPlanet, days: 101980.237, source: smallBodies),
        row("haumea.orbit", "136108 Haumea", "Orbit", .minorPlanet, days: 103647.163, source: smallBodies),
        row("quaoar.orbit", "50000 Quaoar", "Orbit", .minorPlanet, days: 105494.678, source: smallBodies),
        row("makemake.orbit", "136472 Makemake", "Orbit", .minorPlanet, days: 111844.724, source: smallBodies),
        row("eris.orbit", "136199 Eris", "Orbit", .minorPlanet, days: 204199.413, source: smallBodies),
        row("sedna.orbit", "90377 Sedna", "Orbit", .minorPlanet, days: 4211224.803, source: smallBodies),
    ]

    static let planetMoons: [NaturalCycle] = [
        row("phobos.orbit", "Phobos (Mars)", "Orbit", .planetMoon, days: 0.3189),
        row("deimos.orbit", "Deimos (Mars)", "Orbit", .planetMoon, days: 1.2624),
        row("io.orbit", "Io (Jupiter)", "Orbit", .planetMoon, days: 1.769138),
        row("europa.orbit", "Europa (Jupiter)", "Orbit", .planetMoon, days: 3.551181),
        row("ganymede.orbit", "Ganymede (Jupiter)", "Orbit", .planetMoon, days: 7.155),
        row("callisto.orbit", "Callisto (Jupiter)", "Orbit", .planetMoon, days: 16.689017),
        row("mimas.orbit", "Mimas (Saturn)", "Orbit", .planetMoon, days: 0.942422),
        row("enceladus.orbit", "Enceladus (Saturn)", "Orbit", .planetMoon, days: 1.370218),
        row("tethys.orbit", "Tethys (Saturn)", "Orbit", .planetMoon, days: 1.887802),
        row("dione.orbit", "Dione (Saturn)", "Orbit", .planetMoon, days: 2.736915),
        row("rhea.orbit", "Rhea (Saturn)", "Orbit", .planetMoon, days: 4.5175),
        row("titan.orbit", "Titan (Saturn)", "Orbit", .planetMoon, days: 15.945421),
        row("hyperion.orbit", "Hyperion (Saturn)", "Orbit", .planetMoon, days: 21.276609),
        row("iapetus.orbit", "Iapetus (Saturn)", "Orbit", .planetMoon, days: 79.330183),
        row("miranda.orbit", "Miranda (Uranus)", "Orbit", .planetMoon, days: 1.413479),
        row("ariel.orbit", "Ariel (Uranus)", "Orbit", .planetMoon, days: 2.520379),
        row("umbriel.orbit", "Umbriel (Uranus)", "Orbit", .planetMoon, days: 4.144176),
        row("titania.orbit", "Titania (Uranus)", "Orbit", .planetMoon, days: 8.705867),
        row("oberon.orbit", "Oberon (Uranus)", "Orbit", .planetMoon, days: 13.463234),
        row("naiad.orbit", "Naiad (Neptune)", "Orbit", .planetMoon, days: 0.294396),
        row("thalassa.orbit", "Thalassa (Neptune)", "Orbit", .planetMoon, days: 0.311485),
        row("despina.orbit", "Despina (Neptune)", "Orbit", .planetMoon, days: 0.334655),
        row("galatea.orbit", "Galatea (Neptune)", "Orbit", .planetMoon, days: 0.428745),
        row("larissa.orbit", "Larissa (Neptune)", "Orbit", .planetMoon, days: 0.554654),
        row("hippocamp.orbit", "Hippocamp (Neptune)", "Orbit", .planetMoon, days: 0.95),
        row("proteus.orbit", "Proteus (Neptune)", "Orbit", .planetMoon, days: 1.122315),
        row("triton.orbit", "Triton (Neptune)", "Orbit (retrograde)", .planetMoon, days: 5.877),
        row("nereid.orbit", "Nereid (Neptune)", "Orbit", .planetMoon, days: 360.13619),
        row("charon.orbit", "Charon (Pluto)", "Orbit", .planetMoon, days: 6.387),
        row("namaka.orbit", "Namaka (Haumea)", "Orbit", .planetMoon, days: 18.2783),
        row("dysnomia.orbit", "Dysnomia (Eris)", "Orbit", .planetMoon, days: 15.774),
    ]
}
