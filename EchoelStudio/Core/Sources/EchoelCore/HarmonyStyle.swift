/// The song's key as a processor on the render thread hears it: the root, the scale's pitch
/// classes and concert A — the part of `MusicalContext` that needs no names. A snapshot carries it
/// to every insert (VOX), so a harmonizer can sing in the key without reading the song, and it
/// packs into one word for an atomic.
public struct SongKey: Equatable, Sendable {
    /// The tonic as a pitch class, 0 = C … 11 = B.
    public var root: Int
    /// Bit n set: pitch class n (0 = C … 11 = B, not counted from the root) is in the scale. A
    /// chromatic scale sets all twelve.
    public var scale: UInt16
    /// The A above middle C, in hertz.
    public var concertPitch: Double

    /// Arithmetic only: the render thread unpacks a key with it.
    public init(root: Int = 0, scale: UInt16 = SongKey.chromatic, concertPitch: Double = 440) {
        self.root = ((root % 12) + 12) % 12
        self.scale = scale & Self.chromatic
        // `MusicalContext.concertPitchRange`, written out: no global to touch on the render thread.
        self.concertPitch = concertPitch.isFinite && concertPitch >= 400 && concertPitch <= 480 ? concertPitch : 440
    }

    /// The key of a song's frame. A scale this build does not know reads as chromatic, as the
    /// song plays it. Builds a set: call it where the snapshot is compiled, never on the render thread.
    public init(_ context: MusicalContext) {
        var mask: UInt16 = 0
        for step in context.scale.intervals { mask |= 1 << UInt16(((context.root + step) % 12 + 12) % 12) }
        self.init(root: context.root, scale: mask, concertPitch: context.concertPitch)
    }

    /// All twelve pitch classes.
    public static let chromatic: UInt16 = 0x0FFF
    /// The major scale on C: C D E F G A B.
    static let majorOnC: UInt16 = 0x0AB5

    /// The scale a style harmonises in: the song's, or the major scale on the root where the song
    /// frames none (chromatic, as a new song is) — a third needs a key to be major or minor.
    /// Arithmetic only: render-safe.
    public var harmonyScale: UInt16 {
        guard scale == Self.chromatic || scale.nonzeroBitCount < 5 else { return scale }
        let major = UInt32(Self.majorOnC), shift = UInt32(root)
        return UInt16(truncatingIfNeeded: ((major << shift) | (major >> (12 - shift))) & UInt32(Self.chromatic))
    }

    /// The key in one word — root, scale and concert A — for an atomic.
    public var packed: UInt64 {
        UInt64(UInt32(Float(concertPitch).bitPattern)) << 32 | UInt64(scale) << 4 | UInt64(root)
    }

    /// The key a `packed` word holds; a damaged word gives back what `init` makes of its parts.
    public init(packed: UInt64) {
        self.init(root: Int(packed & 0xF), scale: UInt16(truncatingIfNeeded: packed >> 4),
                  concertPitch: Double(Float(bitPattern: UInt32(truncatingIfNeeded: packed >> 32))))
    }
}

/// How the harmonizer sets its voices (VOX, founder 2026-11-01: "Harmonizer mit gregorianischen und
/// anderen traditionellen Chor-Stilen"). Free plays the three voices at the intervals chosen for
/// them, as the harmonizer always did; every other style is one of the ways singers added lines to
/// a chant, and sets two voices of its own, one to each side. Gregorian chant itself is a single
/// line: what these styles add is the early polyphony that grew from it — parallel organum (9th
/// century), fauxbourdon (15th century) — and the held ison of Byzantine chant.
///
/// The harmonizer stores the style as the INDEX of its choice (an Audio Unit indexed parameter, the
/// last of the effect's list), so the order is frozen like the intervals' (`StoredNamesTests`):
/// never reorder, a new style goes at the end. An insert saved before styles existed has no value
/// for it and plays Free, as it did.
public enum HarmonyStyle: Int, CaseIterable, Sendable, Identifiable {
    case free, organum, organumAtTheFourth, fauxbourdon, diatonicThirds, ison

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .free: "Free"
        case .organum: "Organum"
        case .organumAtTheFourth: "Organum at the Fourth"
        case .fauxbourdon: "Fauxbourdon"
        case .diatonicThirds: "Diatonic Thirds"
        case .ison: "Ison"
        }
    }

    /// One sentence for the effect's page: what the voices sing, and where the style comes from.
    public var summary: String {
        switch self {
        case .free: "Each voice sings the interval chosen for it."
        case .organum: "Parallel organum of the 9th century: a fifth and an octave below the melody."
        case .organumAtTheFourth: "Parallel organum at the fourth: a fourth and an octave below the melody."
        case .fauxbourdon: "Fauxbourdon of the 15th century: a fourth and a sixth below the melody, the sixth in the song's key."
        case .diatonicThirds: "A third above and a third below the melody, each major or minor as the song's key has it."
        case .ison: "The ison of Byzantine chant: one voice holds the key's root below the melody."
        }
    }

    /// Whether the voices depend on the song's key (Song Settings).
    public var followsKey: Bool {
        switch self {
        case .free, .organum, .organumAtTheFourth: false
        case .fauxbourdon, .diatonicThirds, .ison: true
        }
    }

    /// The choice at a stored index; an index this build does not know reads as Free. The render
    /// thread reads it, so it builds no list (`allCases` would).
    public init(index: Float) {
        guard index.isFinite, index >= 0, index < 1_000 else {
            self = .free
            return
        }
        self = Self(rawValue: Int(index.rounded())) ?? .free
    }

    /// The two voices for a sung note of pitch class `pitchClass` (0 = C … 11 = B), in semitones
    /// from it: the left one and the right one. Nil for Free, whose voices are the chosen
    /// intervals, and for the Ison, whose one voice is a held note (`key.root`). Arithmetic only, no
    /// allocation: the render thread works the voices out with it when the key or the style changes.
    public func sides(for pitchClass: Int, in key: SongKey) -> (left: Int, right: Int)? {
        let note = ((pitchClass % 12) + 12) % 12
        switch self {
        case .free, .ison:
            return nil
        case .organum:
            return (-7, -12)
        case .organumAtTheFourth:
            return (-5, -12)
        case .fauxbourdon:
            // The middle voice a perfect fourth below, the lowest a sixth below: the third above,
            // an octave down, so the sixth is major or minor as the key has it.
            return (-5, Self.third(from: note, upward: true, in: key.harmonyScale) - 12)
        case .diatonicThirds:
            let thirds = Self.thirds(around: note, in: key.harmonyScale)
            return (thirds.above, thirds.below)
        }
    }

    /// A third above and a third below a sung note, both in the scale. A note of the scale takes
    /// the scale's own thirds, two of its steps away, major or minor as they fall. A note outside it
    /// becomes the third of a major or a minor chord whose other two notes are in the scale, so the
    /// voices stay in the key around a passing note.
    static func thirds(around note: Int, in scale: UInt16) -> (above: Int, below: Int) {
        if !contains(scale, note) {
            let minorAbove = contains(scale, note + 3), majorAbove = contains(scale, note + 4)
            let minorBelow = contains(scale, note - 3), majorBelow = contains(scale, note - 4)
            if minorAbove && majorBelow { return (3, -4) }
            if majorAbove && minorBelow { return (4, -3) }
        }
        return (third(from: note, upward: true, in: scale), third(from: note, upward: false, in: scale))
    }

    /// The third from `note` that lands in `scale`, in signed semitones. In the scale: its own
    /// third, two scale steps away, when that is a third. Otherwise the minor or the major third,
    /// whichever the scale holds — the minor above and the major below where it holds both — and
    /// where a scale with wide gaps (a pentatonic) holds neither, the fourth, else the second.
    static func third(from note: Int, upward: Bool, in scale: UInt16) -> Int {
        let sign = upward ? 1 : -1
        if contains(scale, note) {
            let generic = steps(2 * sign, from: note, in: scale)
            if generic == 3 * sign || generic == 4 * sign { return generic }
        }
        let minor = contains(scale, note + 3 * sign), major = contains(scale, note + 4 * sign)
        if minor && major { return (upward ? 3 : 4) * sign }
        if minor { return 3 * sign }
        if major { return 4 * sign }
        if contains(scale, note + 5 * sign) { return 5 * sign }
        if contains(scale, note + 2 * sign) { return 2 * sign }
        return 4 * sign
    }

    /// Semitones from `note` to the scale tone `count` scale steps away (negative: down).
    static func steps(_ count: Int, from note: Int, in scale: UInt16) -> Int {
        guard scale & SongKey.chromatic != 0 else { return 0 }
        let direction = count < 0 ? -1 : 1
        var remaining = count < 0 ? -count : count
        var offset = 0
        while remaining > 0, offset > -24, offset < 24 {
            offset += direction
            if contains(scale, note + offset) { remaining -= 1 }
        }
        return offset
    }

    @inline(__always)
    static func contains(_ scale: UInt16, _ note: Int) -> Bool {
        scale & (1 << UInt16(((note % 12) + 12) % 12)) != 0
    }
}
