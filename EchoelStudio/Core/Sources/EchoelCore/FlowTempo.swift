import Foundation

/// What sets the tempo the clock plays, by name (W12; the root law's T1 holds in Echoel Studio
/// too). Exactly one at a time: a jam's host or a followed MIDI clock wins over Flow, and Flow over
/// the song's own tempo. The song's own tempo changes only by a gesture or a command — the tempo
/// field, a tap, Song Settings, closing the Flow lock, the assistant, a song opened — never by the
/// body on its own.
public enum TempoSource: String, Sendable, CaseIterable {
    /// The song's own tempo and tempo changes.
    case song
    /// The pulse, through the four stages of `FlowTempo`.
    case flow
    /// An external MIDI clock this phone follows.
    case midiClock
    /// A jam's host this phone follows.
    case jam

    /// The source that sets the pace now. Joining a jam turns Follow MIDI Clock off, so the two
    /// never both hold; were they to, the jam would win.
    public static func current(followsJam: Bool, followsMIDIClock: Bool, flows: Bool) -> TempoSource {
        if followsJam { return .jam }
        if followsMIDIClock { return .midiClock }
        return flows ? .flow : .song
    }
}

/// The tempo lock (W12): Fixed plays the song's own tempo — what the studio always did; Flow lets
/// the pulse move the tempo, through `FlowTempo`.
public enum TempoLock: String, Sendable, CaseIterable {
    case fixed
    case flow
}

/// Flow (W12, founder 2026-11-01): the tempo follows the pulse, and never directly. Four stages
/// stand between a heart rate and the clock (root CLAUDE.md T2):
///
/// 1. **Trust.** Only a pulse measured without a gap for `steadySeconds`, its readings of that time
///    no further apart than `steadySpread`, counts. Anything else holds the tempo where it is.
/// 2. **Fold.** The pulse moves by octaves into `range`, to the octave nearest the tempo playing: a
///    resting 64 can carry a song at 128, and a pulse near an octave's edge does not throw the music
///    from one octave to the other.
/// 3. **Step.** At a bar line of the song the target moves at most `stepPerBar` towards it.
/// 4. **Glide.** The tempo moves to the target in a straight line over `glideSeconds`.
///
/// While the lock is Fixed none of this runs: no pulse is read and `tempo` is nil, so the song
/// plays its own tempo. A value type with no clock of its own, like `TapTempo`: the caller says how
/// much time passed and when a bar line went by — the song's own bar lines, so nothing here counts
/// bars a second way.
public struct FlowTempo: Sendable, Equatable {
    /// How long a pulse is measured without a gap before it counts.
    public static let steadySeconds: Double = 5
    /// How far apart the readings of that time may lie, in beats per minute.
    public static let steadySpread: Double = 12
    /// Where the fold puts the pulse: wider than an octave, so every pulse has a place in it.
    public static let range: ClosedRange<Double> = 60...160
    /// The most the target moves at one bar line, in beats per minute.
    public static let stepPerBar: Double = 2
    /// How long the tempo takes to glide to a new target.
    public static let glideSeconds: Double = 2
    /// The readings kept for the trust, at most: the window holds a few seconds of them.
    static let readingLimit = 256

    /// Fixed or Flow.
    public private(set) var lock: TempoLock = .fixed
    /// The trusted pulse folded into `range` — where the target heads. Nil while the pulse is not
    /// trusted, and while the lock is Fixed.
    public private(set) var wanted: Double?
    /// The trusted pulse itself, the median of its steady readings; nil while there is none.
    public private(set) var pulse: Double?

    /// Where the tempo is in its glide, and where the glide goes; meaningful only in Flow.
    private var gliding: Double = Tempo.defaultBPM
    private var aim: Double = Tempo.defaultBPM
    private var glideFrom: Double = Tempo.defaultBPM
    private var glideStart: Double = 0
    private var clock: Double = 0
    /// When the current unbroken run of readings began; nil while no pulse is measured.
    private var runStart: Double?
    /// The readings of the last `steadySeconds`, oldest first.
    private var recent: [Reading] = []

    struct Reading: Sendable, Equatable {
        let time: Double
        let bpm: Double
    }

    public init() {}

    /// The tempo Flow plays; nil while the lock is Fixed, when the song plays its own.
    public var tempo: Double? { lock == .flow ? gliding : nil }

    /// Where the glide goes, moved only at a bar line; nil while Fixed.
    public var target: Double? { lock == .flow ? aim : nil }

    /// Whether Flow follows a trusted pulse now. It changes when the trust does, not with each look.
    public var isFollowing: Bool { wanted != nil }

    /// The tempo as a view shows it, to a tenth. It changes while the tempo glides and never while
    /// it holds, so a view that reads it is not redrawn by every look (Law 6).
    public var shownTempo: Double? { tempo.map { ($0 * 10).rounded() / 10 } }

    /// Opens the lock where the song plays now, so turning Flow on changes nothing until the pulse
    /// is trusted. Nothing happens in Flow already.
    public mutating func open(at songTempo: Double) {
        guard lock == .fixed else { return }
        let start = songTempo.isFinite
            ? Swift.min(Swift.max(songTempo, Tempo.range.lowerBound), Tempo.range.upperBound)
            : Tempo.defaultBPM
        lock = .flow
        gliding = start
        aim = start
        glideFrom = start
        glideStart = clock
        forget()
    }

    /// Closes the lock. Returns the tempo Fixed keeps — where Flow got to, to the whole beat
    /// (`kept`) — or nil when the lock was Fixed already.
    @discardableResult
    public mutating func close() -> Double? {
        guard lock == .flow else { return nil }
        let reached = gliding
        lock = .fixed
        forget()
        return Self.kept(reached)
    }

    /// `seconds` after the last look: the pulse as a body source measures it now, in beats per
    /// minute, or nil while none does. In Fixed it does nothing at all.
    public mutating func advance(seconds: Double, pulse reading: Double?) {
        guard lock == .flow, seconds.isFinite, seconds > 0 else { return }
        clock += seconds
        if let bpm = reading, bpm.isFinite, bpm > 0 {
            if runStart == nil { runStart = clock }
            recent.append(Reading(time: clock, bpm: bpm))
            let now = clock
            recent.removeAll { now - $0.time > Self.steadySeconds }
            if recent.count > Self.readingLimit { recent.removeFirst(recent.count - Self.readingLimit) }
        } else {
            runStart = nil
            recent.removeAll()
        }
        pulse = trustedPulse()
        let playing = gliding
        wanted = pulse.map { Self.fold($0, near: playing) }
        let progress = Swift.min(1, (clock - glideStart) / Self.glideSeconds)
        gliding = glideFrom + (aim - glideFrom) * progress
    }

    /// A bar line of the song went by: the target takes one step, at most `stepPerBar`, towards the
    /// trusted pulse, and the tempo glides there from where it is. Nothing moves while the pulse is
    /// not trusted, nor while the lock is Fixed.
    public mutating func bar() {
        guard lock == .flow, let wanted else { return }
        let step = Swift.min(Swift.max(wanted - aim, -Self.stepPerBar), Self.stepPerBar)
        guard step != 0 else { return }
        aim = Swift.min(Swift.max(aim + step, Tempo.range.lowerBound), Tempo.range.upperBound)
        glideFrom = gliding
        glideStart = clock
    }

    /// `pulse` moved by octaves into `range`, to the octave nearest `reference` (as a ratio). A
    /// pulse that is not a positive number leaves `reference` as it is.
    public static func fold(_ pulse: Double, near reference: Double) -> Double {
        guard pulse.isFinite, pulse > 0 else { return reference }
        var base = pulse
        while base > range.upperBound { base /= 2 }
        while base < range.lowerBound { base *= 2 }
        // The range spans more than an octave, so the octave above or below may lie in it too.
        var best = base
        for candidate in [base / 2, base * 2] where range.contains(candidate) {
            if ratio(candidate, reference) < ratio(best, reference) { best = candidate }
        }
        return best
    }

    /// The tempo Fixed keeps when the lock closes: where Flow got to, to the whole beat, within
    /// `Tempo.range`.
    public static func kept(_ tempo: Double) -> Double {
        guard tempo.isFinite else { return Tempo.defaultBPM }
        return Swift.min(Swift.max(tempo.rounded(), Tempo.range.lowerBound), Tempo.range.upperBound)
    }

    /// How far apart two tempos are as a ratio, 1 when equal; a reference that is not a positive
    /// number makes every candidate equally far.
    private static func ratio(_ a: Double, _ b: Double) -> Double {
        guard a > 0, b > 0, a.isFinite, b.isFinite else { return 1 }
        return a > b ? a / b : b / a
    }

    /// The median of the steady readings, once they have run long enough without a gap and lie
    /// close enough together; else nil.
    private func trustedPulse() -> Double? {
        guard let runStart, clock - runStart >= Self.steadySeconds, let first = recent.first else { return nil }
        var low = first.bpm
        var high = first.bpm
        for reading in recent {
            low = Swift.min(low, reading.bpm)
            high = Swift.max(high, reading.bpm)
        }
        guard high - low <= Self.steadySpread else { return nil }
        let sorted = recent.map(\.bpm).sorted()
        let middle = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
    }

    /// No pulse heard: the trust starts over.
    private mutating func forget() {
        runStart = nil
        recent.removeAll()
        wanted = nil
        pulse = nil
    }
}
