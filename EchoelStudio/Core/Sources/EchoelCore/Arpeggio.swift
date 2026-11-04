/// A per-track MIDI effect (EDIT-2, 2026-11-04): while it is on, the notes a track plays — its
/// clips and the keys played into it — are not heard as chords but one after another on a grid of
/// the song. It only re-times and re-orders what the player holds; it never invents a pitch the
/// player did not hold (an octave above one is the same key, as on every hardware arpeggiator).
///
/// Ported from the earlier app's `ArpFigure` (orders up, down, up-down, down-up, as played,
/// random; octaves) — the core of picking a note, not its subsystem: here the grid is the song's
/// own (`TempoMap` through ticks, `MeterMap` for bars), so a tempo ramp or a change of signature
/// moves the steps exactly as it moves every other event, and the export plays what the engine
/// plays: clip notes are arpeggiated when the plan is compiled (`PlaybackPlan`), keys played live
/// by the engine through the same `ArpPattern` and `ArpGrid`.
///
/// Stored inside format 4 as an optional track field `arpeggio` (absent: no arpeggiator). The rate
/// and the order are stored by NAME; a name this build does not know is kept and plays as the
/// fallback (a sixteenth, up), like every other choice of how a song plays.
public struct Arpeggio: Codable, Equatable, Hashable, Sendable {
    public var isOn: Bool
    public var octaves: Int
    /// The share of each step a note sounds, `gateRange`; 1 is legato.
    public var gate: Double
    /// Keys stay held after they are let go, until the next chord is played on released keys —
    /// or, for a clip, until its placement ends.
    public var latch: Bool
    /// The random order's seed: the same seed plays the same sequence in every pass and every export.
    public var seed: Int

    public var rate: ArpRate {
        get { ArpRate(rawValue: rateName) ?? .sixteenth }
        set { rateName = newValue.rawValue }
    }

    public var order: ArpOrder {
        get { ArpOrder(rawValue: orderName) ?? .up }
        set { orderName = newValue.rawValue }
    }

    /// The stored names of a rate or order this build does not know, if the song holds one.
    public var unrecognizedRate: String? { ArpRate(rawValue: rateName) == nil ? rateName : nil }
    public var unrecognizedOrder: String? { ArpOrder(rawValue: orderName) == nil ? orderName : nil }

    private var rateName: String
    private var orderName: String

    public static let octaveRange: ClosedRange<Int> = 1...4
    public static let gateRange: ClosedRange<Double> = 0.05...1
    public static let seedRange: ClosedRange<Int> = 0...Int(UInt32.max)

    public init(isOn: Bool = true, rate: ArpRate = .sixteenth, order: ArpOrder = .up, octaves: Int = 1,
                gate: Double = 0.5, latch: Bool = false, seed: Int = 1) {
        self.isOn = isOn
        rateName = rate.rawValue
        orderName = order.rawValue
        self.octaves = octaves
        self.gate = gate
        self.latch = latch
        self.seed = seed
    }

    private enum CodingKeys: String, CodingKey {
        case isOn = "on"
        case rateName = "rate"
        case orderName = "order"
        case octaves, gate, latch, seed
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isOn = try c.decodeIfPresent(Bool.self, forKey: .isOn) ?? true
        rateName = try c.decodeIfPresent(String.self, forKey: .rateName) ?? ArpRate.sixteenth.rawValue
        orderName = try c.decodeIfPresent(String.self, forKey: .orderName) ?? ArpOrder.up.rawValue
        octaves = try c.decodeIfPresent(Int.self, forKey: .octaves) ?? 1
        gate = try c.decodeIfPresent(Double.self, forKey: .gate) ?? 0.5
        latch = try c.decodeIfPresent(Bool.self, forKey: .latch) ?? false
        seed = try c.decodeIfPresent(Int.self, forKey: .seed) ?? 1
    }

    /// Why these settings cannot be stored, or nil: the ranges the editor keeps.
    public var problem: String? {
        if !Self.octaveRange.contains(octaves) { return "octaves must be within 1…4" }
        if !(gate.isFinite && Self.gateRange.contains(gate)) { return "gate must be within 0.05…1" }
        if !Self.seedRange.contains(seed) { return "seed must be within 0…\(UInt32.max)" }
        if rateName.isEmpty || rateName.count > 32 || orderName.isEmpty || orderName.count > 32 {
            return "rate and order need a name"
        }
        return nil
    }

    /// The steps' length in ticks.
    public var stepTicks: Tick { rate.ticks }
}

/// How long one step is. Stored by name; a new rate goes at the end.
public enum ArpRate: String, Codable, CaseIterable, Sendable {
    case quarter, eighth, sixteenth, thirtySecond
    case quarterTriplet, eighthTriplet, sixteenthTriplet, thirtySecondTriplet

    public var ticks: Tick {
        let quarter = MusicalTime.ticksPerQuarter
        switch self {
        case .quarter: return quarter
        case .eighth: return quarter / 2
        case .sixteenth: return quarter / 4
        case .thirtySecond: return quarter / 8
        case .quarterTriplet: return quarter * 2 / 3
        case .eighthTriplet: return quarter / 3
        case .sixteenthTriplet: return quarter / 6
        case .thirtySecondTriplet: return quarter / 12
        }
    }

    /// As a musician reads it: "1/16", "1/8T".
    public var label: String {
        switch self {
        case .quarter: "1/4"
        case .eighth: "1/8"
        case .sixteenth: "1/16"
        case .thirtySecond: "1/32"
        case .quarterTriplet: "1/4T"
        case .eighthTriplet: "1/8T"
        case .sixteenthTriplet: "1/16T"
        case .thirtySecondTriplet: "1/32T"
        }
    }
}

/// In which order the held notes play. Stored by name; a new order goes at the end.
public enum ArpOrder: String, Codable, CaseIterable, Sendable {
    case up, down, upDown, downUp, asPlayed, random

    public var label: String {
        switch self {
        case .up: "Up"
        case .down: "Down"
        case .upDown: "Up-Down"
        case .downUp: "Down-Up"
        case .asPlayed: "As Played"
        case .random: "Random"
        }
    }

    /// The order counts the notes as they were pressed, not by pitch.
    public var usesPlayedOrder: Bool { self == .asPlayed }
}

/// Which held note a step plays. Pure arithmetic, no allocation: the render thread calls it for
/// keys played live, the plan for clip notes.
public enum ArpPattern {
    /// The note of step `step` (counted from the phrase's first step) among `count` held notes over
    /// `octaves` octaves: an index into the held notes — sorted from low to high, or in the order
    /// they were pressed for `asPlayed` — and how many octaves above it. Up-down and down-up turn on
    /// the top and the bottom note without playing it twice.
    public static func pick(step: Int, count: Int, octaves: Int, order: ArpOrder, seed: UInt32) -> (index: Int, octave: Int) {
        guard count > 0 else { return (0, 0) }
        let octaveCount = Swift.min(Swift.max(octaves, 1), Arpeggio.octaveRange.upperBound)
        let length = count * octaveCount
        let s = Swift.max(step, 0)
        var position: Int
        switch order {
        case .up, .asPlayed:
            position = s % length
        case .down:
            position = length - 1 - s % length
        case .upDown, .downUp:
            if length == 1 {
                position = 0
            } else {
                let cycle = 2 * length - 2
                let k = s % cycle
                position = k < length ? k : cycle - k
                if order == .downUp { position = length - 1 - position }
            }
        case .random:
            position = Int(mix(UInt64(seed) << 32 | UInt64(UInt32(truncatingIfNeeded: s))) % UInt64(length))
        }
        return (position % count, position / count)
    }

    /// `pitch` raised by `octave` octaves, folded back by octaves while it lies above the MIDI range.
    public static func pitch(_ pitch: Int, octave: Int) -> Int {
        var raised = pitch + 12 * Swift.max(octave, 0)
        while raised > Note.pitchRange.upperBound { raised -= 12 }
        return Swift.min(Swift.max(raised, Note.pitchRange.lowerBound), Note.pitchRange.upperBound)
    }

    /// SplitMix64's finaliser: a well-spread value for each step, the same on every platform.
    static func mix(_ value: UInt64) -> UInt64 {
        var z = value &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Where the steps fall: on the song's grid, counted from every bar line, so a bar of 7/8 ends on
/// a short step and the next bar starts on the beat. Pure and allocation-free.
public enum ArpGrid {
    /// The first step at or after `tick`.
    public static func start(atOrAfter tick: Tick, step: Tick, meter: MeterMap) -> Tick {
        let size = Swift.max(step, 1)
        let bar = meter.barStart(at: tick)
        let next = bar + meter.ticksPerBar(at: tick)
        let into = tick - bar
        let candidate = bar + (into + size - 1) / size * size
        return candidate >= next ? next : candidate
    }

    /// Where the step that starts at `start` ends: one step later, or at the bar line.
    public static func end(ofStepAt start: Tick, step: Tick, meter: MeterMap) -> Tick {
        let next = meter.barStart(at: start) + meter.ticksPerBar(at: start)
        return Swift.min(start + Swift.max(step, 1), next)
    }

    /// How long a note sounds in a step from `start` to `end` at `gate`: at least one tick.
    public static func noteLength(from start: Tick, to end: Tick, gate: Double) -> Tick {
        let g = gate.isFinite ? Swift.min(Swift.max(gate, Arpeggio.gateRange.lowerBound), 1) : 0.5
        return Swift.max(1, Tick((Double(end - start) * g).rounded()))
    }
}

extension PlaybackPlan {
    /// The notes `intervals` hold, as the arpeggiator plays them: per step one held note, sorted
    /// by pitch or by when it was pressed, with that note's velocity. A phrase starts on the first
    /// step at or after its first key and ends when no key is held (with latch: at the next chord
    /// on released keys, or where the placement holding its keys ends, `Interval.limit`). Nothing
    /// sounds past `cap` (a session clip's length). Main thread; it allocates.
    static func arpeggiate(_ intervals: [Interval], _ arp: Arpeggio, meter: MeterMap, cap: Tick = .max) -> [Interval] {
        guard !intervals.isEmpty else { return [] }
        let step = arp.stepTicks
        let seed = UInt32(clamping: arp.seed)
        let presses = intervals.sorted { $0.start != $1.start ? $0.start < $1.start : $0.pitch < $1.pitch }
        var boundaries = Set<Tick>()
        for interval in intervals {
            boundaries.insert(interval.start)
            boundaries.insert(interval.end)
            if arp.latch, interval.limit != .max { boundaries.insert(interval.limit) }
        }
        if cap != .max { boundaries.insert(cap) }
        let times = boundaries.sorted()
        var physical: [Interval] = []
        var latched: [Interval] = []
        var latchLimit: Tick = .max
        var next: Tick?
        var stepIndex = 0
        var cursor = 0
        var result: [Interval] = []
        for (i, at) in times.enumerated() {
            guard at < cap else { break }
            physical.removeAll { $0.end <= at }
            var pressed: [Interval] = []
            while cursor < presses.count, presses[cursor].start == at {
                pressed.append(presses[cursor])
                cursor += 1
            }
            if arp.latch {
                if at >= latchLimit {
                    latched.removeAll()
                    latchLimit = .max
                }
                if !pressed.isEmpty {
                    if physical.isEmpty { latched.removeAll() }
                    for key in pressed where !latched.contains(where: { $0.pitch == key.pitch }) { latched.append(key) }
                    latchLimit = latched.map(\.limit).max() ?? .max
                }
            }
            physical.append(contentsOf: pressed)
            let held = arp.latch ? latched : physical
            guard !held.isEmpty else {
                next = nil
                continue
            }
            if next == nil {
                stepIndex = 0
                next = ArpGrid.start(atOrAfter: at, step: step, meter: meter)
            }
            var until = i + 1 < times.count ? times[i + 1] : at
            if arp.latch, i + 1 >= times.count { until = Swift.min(latchLimit, cap) }
            until = Swift.min(until, cap)
            guard until != .max else { continue }
            let byPitch = held.sorted { $0.pitch < $1.pitch }
            let ordered = arp.order.usesPlayedOrder ? held : byPitch
            while let start = next, start < until {
                let end = ArpGrid.end(ofStepAt: start, step: step, meter: meter)
                let choice = ArpPattern.pick(step: stepIndex, count: ordered.count, octaves: arp.octaves,
                                             order: arp.order, seed: seed)
                let key = ordered[choice.index]
                var stop = start + ArpGrid.noteLength(from: start, to: end, gate: arp.gate)
                if arp.latch { stop = Swift.min(stop, latchLimit) }
                stop = Swift.min(stop, cap)
                if stop > start {
                    result.append(Interval(start: start, end: stop, pitch: ArpPattern.pitch(key.pitch, octave: choice.octave),
                                           velocity: key.velocity))
                }
                stepIndex += 1
                next = end
            }
        }
        return resolvingOverlaps(result)
    }
}
