import Foundation

// The song's light show (CUES, 2026-11-05): fixtures patched on DMX universes, a list of cues —
// each a snapshot of every fixture's values or the song's own look — and where on the timeline a
// cue starts. Pure values and pure arithmetic: the Connections module plays it through its
// Art-Net and sACN senders, an export renders it, and both run the same functions below. Optional
// inside format 4: a song without a light show stores no key, exactly as before.

public typealias FixtureID = Identifier<PatchedFixture>
public typealias CueID = Identifier<LightCue>

/// What a fixture's channel controls. Every value is 0 … 1 of the channel's travel; pan and tilt
/// travel in 16 bits (a coarse and a fine channel), everything else in 8.
public enum LightAttribute: String, Codable, CaseIterable, Sendable {
    case dimmer
    case red
    case green
    case blue
    case white
    case amber
    case uv
    case pan
    case tilt

    public var title: String {
        switch self {
        case .dimmer: "Intensity"
        case .red: "Red"
        case .green: "Green"
        case .blue: "Blue"
        case .white: "White"
        case .amber: "Amber"
        case .uv: "UV"
        case .pan: "Pan"
        case .tilt: "Tilt"
        }
    }

    /// Whether the attribute makes light. Every one of these passes the flash limit on its way to
    /// the wire; position does not, a head may turn as fast as the cue asks.
    public var isBrightness: Bool { self != .pan && self != .tilt }

    /// Pan and tilt are sent as a coarse/fine pair and interpolated on that 16-bit grid.
    public var isSixteenBit: Bool { self == .pan || self == .tilt }

    /// What a fixture shows before any cue sets it: dark, and a head pointing at its centre.
    public var restValue: Double { isBrightness ? 0 : 0.5 }
}

/// One DMX slot of a profile's layout.
public enum DMXSlot: Equatable, Sendable {
    /// An 8-bit attribute.
    case single(LightAttribute)
    /// The high byte of a 16-bit attribute.
    case coarse(LightAttribute)
    /// Its low byte, in the slot after the coarse one.
    case fine(LightAttribute)
    /// A channel Echoel always sends as this value — the strobe's own rate, held off.
    case fixed(UInt8)
}

/// The generic profiles Echoel knows. Stored by name (`StoredNamesTests`); a new one goes at the end.
public enum FixtureProfile: String, Codable, CaseIterable, Sendable {
    /// One channel of intensity.
    case dimmer
    case rgb
    case rgbw
    /// Red, green, blue, amber, ultraviolet.
    case rgbaUV
    /// Pan and tilt in 16 bits, intensity, red, green, blue — the common basic head.
    case movingHead
    /// Intensity and the fixture's own strobe rate. Echoel never runs a fixture's own strobe — its
    /// rate is out of reach of the flash limit — so that channel is always 0, which generic strobes
    /// read as "off"; the flashes Echoel makes are on the intensity channel, under the limit.
    case strobe

    public var title: String {
        switch self {
        case .dimmer: "Dimmer"
        case .rgb: "RGB"
        case .rgbw: "RGBW"
        case .rgbaUV: "RGBA + UV"
        case .movingHead: "Moving Head"
        case .strobe: "Strobe"
        }
    }

    /// The channels from the fixture's address on, in order.
    public var layout: [DMXSlot] {
        switch self {
        case .dimmer: [.single(.dimmer)]
        case .rgb: [.single(.red), .single(.green), .single(.blue)]
        case .rgbw: [.single(.red), .single(.green), .single(.blue), .single(.white)]
        case .rgbaUV: [.single(.red), .single(.green), .single(.blue), .single(.amber), .single(.uv)]
        case .movingHead: [.coarse(.pan), .fine(.pan), .coarse(.tilt), .fine(.tilt),
                           .single(.dimmer), .single(.red), .single(.green), .single(.blue)]
        case .strobe: [.single(.dimmer), .fixed(0)]
        }
    }

    public var footprint: Int { layout.count }

    /// The attributes a cue can set on this profile, in layout order.
    public var attributes: [LightAttribute] {
        var seen: [LightAttribute] = []
        for slot in layout {
            switch slot {
            case .single(let attribute), .coarse(let attribute):
                if !seen.contains(attribute) { seen.append(attribute) }
            case .fine, .fixed:
                break
            }
        }
        return seen
    }
}

/// A fixture in the rig: a profile at a universe and a first channel.
public struct PatchedFixture: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var id: FixtureID
    public var name: String
    /// The profile's stored name. A name this build does not know is kept and saved back; that
    /// fixture stays dark and holds only its first channel.
    public var profileName: String
    /// 1 … `universeRange`: universe 1 is the one set in Connections, 2 the one after it.
    public var universe: Int
    /// The first DMX channel, 1 … 512; the profile's channels follow it inside the universe.
    public var address: Int

    public init(id: FixtureID = FixtureID(), name: String, profile: FixtureProfile, universe: Int, address: Int) {
        self.id = id
        self.name = name
        self.profileName = profile.rawValue
        self.universe = universe
        self.address = address
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, universe, address
        case profileName = "profile"
    }

    public var profile: FixtureProfile? { FixtureProfile(rawValue: profileName) }

    /// How many channels the fixture takes: its profile's, or one for a profile this build does not know.
    public var footprint: Int { profile?.footprint ?? 1 }

    /// The channels it takes, 1-based.
    public var channels: ClosedRange<Int> { address...(address + footprint - 1) }

    public static let universeRange: ClosedRange<Int> = 1...64
    public static let channelRange: ClosedRange<Int> = 1...512
}

/// One fixture's values in a cue, keyed by attribute name. A key this build does not know is kept.
public struct CueFixtureValues: Codable, Equatable, Hashable, Sendable {
    public var fixture: FixtureID
    public var values: [String: Double]

    public init(fixture: FixtureID, values: [String: Double]) {
        self.fixture = fixture
        self.values = values
    }

    public func value(_ attribute: LightAttribute) -> Double? { values[attribute.rawValue] }
}

/// A scene of the light: a value per fixture and attribute — or the song's own look for the
/// light, with the snapshot's position kept — reached over `fade` seconds from what was showing.
public struct LightCue: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var id: CueID
    public var name: String
    /// Seconds, 0 … `fadeRange`: 0 cuts (and the flash limit still slows the cut).
    public var fade: Double
    /// `song` lights the fixtures from the song — the key's colour, the level and the beat, as the
    /// one-fixture light without a rig does; absent is the snapshot. A name this build does not
    /// know is kept and plays as the snapshot.
    public var look: String?
    public var values: [CueFixtureValues]

    public init(id: CueID = CueID(), name: String, fade: Double = 0, look: String? = nil, values: [CueFixtureValues] = []) {
        self.id = id
        self.name = name
        self.fade = fade
        self.look = look
        self.values = values
    }

    public static let songLook = "song"
    public static let fadeRange: ClosedRange<Double> = 0...600

    public var followsSong: Bool { look == Self.songLook }

    /// The stored value of one fixture's attribute, if the cue sets it.
    public func value(_ attribute: LightAttribute, of fixture: FixtureID) -> Double? {
        values.first { $0.fixture == fixture }?.value(attribute)
    }

    /// The cue with one value set (0 … 1 is checked by the command).
    public func setting(_ attribute: LightAttribute, of fixture: FixtureID, to value: Double) -> LightCue {
        var copy = self
        if let index = copy.values.firstIndex(where: { $0.fixture == fixture }) {
            copy.values[index].values[attribute.rawValue] = value
        } else {
            copy.values.append(CueFixtureValues(fixture: fixture, values: [attribute.rawValue: value]))
        }
        return copy
    }
}

/// Where a cue starts on the timeline. One per tick; the cue fades in from there.
public struct CuePlacement: Codable, Equatable, Hashable, Sendable {
    public var tick: Tick
    public var cue: CueID

    public init(tick: Tick, cue: CueID) {
        self.tick = tick
        self.cue = cue
    }
}

/// The whole light show of a song.
public struct Lighting: Codable, Equatable, Sendable {
    public var fixtures: [PatchedFixture]
    public var cues: [LightCue]
    /// Ticks rising, each once.
    public var placements: [CuePlacement]

    public init(fixtures: [PatchedFixture] = [], cues: [LightCue] = [], placements: [CuePlacement] = []) {
        self.fixtures = fixtures
        self.cues = cues
        self.placements = placements
    }

    public static let maximumFixtures = 512
    public static let maximumCues = 1_000
    public static let maximumPlacements = 1_000

    public var isEmpty: Bool { fixtures.isEmpty && cues.isEmpty && placements.isEmpty }

    public func fixture(_ id: FixtureID) -> PatchedFixture? { fixtures.first { $0.id == id } }
    public func cue(_ id: CueID) -> LightCue? { cues.first { $0.id == id } }

    /// The fixture whose channels `candidate` would share, if any — the reason a patch is refused.
    /// A fixture never conflicts with itself, so a move onto its own channels is free.
    public func conflict(for candidate: PatchedFixture) -> PatchedFixture? {
        fixtures.first { other in
            other.id != candidate.id && other.universe == candidate.universe && other.channels.overlaps(candidate.channels)
        }
    }

    /// The sentence the patch page shows for a refused patch.
    public func conflictMessage(for candidate: PatchedFixture) -> String? {
        if !PatchedFixture.universeRange.contains(candidate.universe) {
            return "Universe \(candidate.universe) is outside 1…\(PatchedFixture.universeRange.upperBound)."
        }
        if candidate.address < 1 || candidate.address + candidate.footprint - 1 > PatchedFixture.channelRange.upperBound {
            return "\(candidate.name) needs channels \(candidate.address)–\(candidate.address + candidate.footprint - 1); a universe ends at 512."
        }
        guard let other = conflict(for: candidate) else { return nil }
        return "Channels \(candidate.channels.lowerBound)–\(candidate.channels.upperBound) of universe \(candidate.universe) overlap \(other.name) (\(other.channels.lowerBound)–\(other.channels.upperBound))."
    }

    /// The first channel in `universe` where a fixture of `profile` fits without a conflict.
    public func freeAddress(for profile: FixtureProfile, in universe: Int) -> Int? {
        let probe = PatchedFixture(name: "probe", profile: profile, universe: universe, address: 1)
        for address in 1...(PatchedFixture.channelRange.upperBound - profile.footprint + 1) {
            var candidate = probe
            candidate.address = address
            if conflict(for: candidate) == nil { return address }
        }
        return nil
    }

    /// The next free name "<profile> N".
    public func nextFixtureName(for profile: FixtureProfile) -> String {
        let taken = Set(fixtures.map(\.name))
        var number = fixtures.filter { $0.profileName == profile.rawValue }.count + 1
        while taken.contains("\(profile.title) \(number)") { number += 1 }
        return "\(profile.title) \(number)"
    }

    /// The next free name "Cue N".
    public func nextCueName() -> String {
        let taken = Set(cues.map(\.name))
        var number = cues.count + 1
        while taken.contains("Cue \(number)") { number += 1 }
        return "Cue \(number)"
    }

    // MARK: - Validation

    static func validate(fixture: PatchedFixture) throws {
        try validateName(fixture.name, "fixtures")
        guard PatchedFixture.universeRange.contains(fixture.universe) else {
            throw Project.invalid("universe", "must be within \(PatchedFixture.universeRange)")
        }
        guard fixture.address >= 1, fixture.address + fixture.footprint - 1 <= PatchedFixture.channelRange.upperBound else {
            throw Project.invalid("address", "the fixture's channels must lie within 1…512")
        }
    }

    static func validate(cue: LightCue, in lighting: Lighting) throws {
        try validateName(cue.name, "cues")
        guard cue.fade.isFinite, LightCue.fadeRange.contains(cue.fade) else {
            throw Project.invalid("fade", "seconds within \(LightCue.fadeRange)")
        }
        var seen = Set<FixtureID>()
        for entry in cue.values {
            guard seen.insert(entry.fixture).inserted else {
                throw Project.invalid("cues", "a fixture has two value sets in one cue")
            }
            guard lighting.fixture(entry.fixture) != nil else {
                throw Project.invalid("cues", "a cue names a fixture the rig lacks")
            }
            for value in entry.values.values {
                guard value.isFinite, (0...1).contains(value) else {
                    throw Project.invalid("cues", "a value must be within 0…1")
                }
            }
        }
    }

    static func validateName(_ name: String, _ parameter: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, name.count <= 2 * Names.maximumLength else {
            throw Project.invalid(parameter, "a name is empty or longer than \(2 * Names.maximumLength) characters")
        }
    }

    /// The rules a song read from disk must keep, the same the commands enforce.
    public func validate() throws {
        guard fixtures.count <= Self.maximumFixtures, cues.count <= Self.maximumCues,
              placements.count <= Self.maximumPlacements else {
            throw Project.invalid("lighting", "too many fixtures, cues or placements")
        }
        var fixtureIDs = Set<FixtureID>()
        for fixture in fixtures {
            guard fixtureIDs.insert(fixture.id).inserted else { throw CommandError.duplicateID(fixture.id.description) }
            try Self.validate(fixture: fixture)
            if let other = conflict(for: fixture) {
                throw Project.invalid("fixtures", "\(fixture.name) and \(other.name) share channels in universe \(fixture.universe)")
            }
        }
        var cueIDs = Set<CueID>()
        for cue in cues {
            guard cueIDs.insert(cue.id).inserted else { throw CommandError.duplicateID(cue.id.description) }
            try Self.validate(cue: cue, in: self)
        }
        var previous: Tick = -1
        for placement in placements {
            guard placement.tick > previous, placement.tick <= MusicalTime.maximumTick else {
                throw Project.invalid("placements", "ticks must rise from 0 to at most \(MusicalTime.maximumTick), each once")
            }
            guard cueIDs.contains(placement.cue) else {
                throw Project.invalid("placements", "a placement names a cue the song lacks")
            }
            previous = placement.tick
        }
    }
}

extension Project {
    /// The light show, applied by the light commands (`Command.applyLight`).
    mutating func applyLight(_ change: (inout Lighting) throws -> Void) throws {
        var draft = lighting
        try change(&draft)
        lighting = draft
    }
}

// MARK: - DMX arithmetic

/// A 16-bit DMX value as its coarse and fine bytes, and back.
public enum DMXWord {
    public static func split(_ word: UInt16) -> (coarse: UInt8, fine: UInt8) {
        (UInt8(word >> 8), UInt8(word & 0xFF))
    }

    public static func join(coarse: UInt8, fine: UInt8) -> UInt16 {
        UInt16(coarse) << 8 | UInt16(fine)
    }

    /// A value 0 … 1 on the 16-bit grid.
    public static func word(_ value: Double) -> UInt16 {
        guard value.isFinite else { return 0 }
        return UInt16((Swift.min(1, Swift.max(0, value)) * 65_535).rounded())
    }

    public static func value(_ word: UInt16) -> Double { Double(word) / 65_535 }

    /// The word a share `progress` of the way from `from` to `to`, on the 16-bit grid.
    public static func interpolate(from: UInt16, to: UInt16, progress: Double) -> UInt16 {
        let share = progress.isFinite ? Swift.min(1, Swift.max(0, progress)) : 1
        let step = (Double(Int(to) - Int(from)) * share).rounded()
        return UInt16(clamping: Int(from) + Int(step))
    }

    public static func byte(_ value: Double) -> UInt8 {
        guard value.isFinite else { return 0 }
        return UInt8((Swift.min(1, Swift.max(0, value)) * 255).rounded())
    }
}

/// What every fixture shows at one moment, attribute by attribute, each 0 … 1.
public typealias RigState = [FixtureID: [LightAttribute: Double]]

extension Lighting {
    /// Every fixture at rest: dark, heads at their centre.
    public var restState: RigState {
        var state: RigState = [:]
        for fixture in fixtures {
            guard let profile = fixture.profile else { continue }
            var values: [LightAttribute: Double] = [:]
            for attribute in profile.attributes { values[attribute] = attribute.restValue }
            state[fixture.id] = values
        }
        return state
    }

    /// What `cue` asks of every fixture. A value the cue does not set rests; with the song's look,
    /// the light comes from `songLook` (dimmer, then colour) and the position from the cue.
    public func target(of cue: LightCue, songLook: LightFixture.Look) -> RigState {
        var state = restState
        for fixture in fixtures {
            guard let profile = fixture.profile, var values = state[fixture.id] else { continue }
            for attribute in profile.attributes {
                if let stored = cue.value(attribute, of: fixture.id), stored.isFinite {
                    values[attribute] = Swift.min(1, Swift.max(0, stored))
                }
            }
            if cue.followsSong { Self.light(&values, profile: profile, with: songLook) }
            state[fixture.id] = values
        }
        return state
    }

    /// The song's look on one profile: a dimmer channel takes the dimmer and the colour channels
    /// the colour; a fixture with colour and no dimmer takes the colour scaled by the dimmer.
    static func light(_ values: inout [LightAttribute: Double], profile: FixtureProfile, with look: LightFixture.Look) {
        let attributes = profile.attributes
        let hasDimmer = attributes.contains(.dimmer)
        let scale = hasDimmer ? 1 : look.dimmer
        if hasDimmer { values[.dimmer] = look.dimmer }
        if attributes.contains(.red) { values[.red] = look.red * scale }
        if attributes.contains(.green) { values[.green] = look.green * scale }
        if attributes.contains(.blue) { values[.blue] = look.blue * scale }
        for attribute in [LightAttribute.white, .amber, .uv] where attributes.contains(attribute) { values[attribute] = 0 }
    }

    /// `progress` of the way from `from` to `to`: linear, pan and tilt on their 16-bit grid.
    public static func interpolate(from: RigState, to: RigState, progress: Double) -> RigState {
        let share = progress.isFinite ? Swift.min(1, Swift.max(0, progress)) : 1
        var state = to
        for (fixture, target) in to {
            var values = target
            for (attribute, end) in target {
                let start = from[fixture]?[attribute] ?? attribute.restValue
                if attribute.isSixteenBit {
                    values[attribute] = DMXWord.value(DMXWord.interpolate(from: DMXWord.word(start), to: DMXWord.word(end),
                                                                          progress: share))
                } else {
                    values[attribute] = start + (end - start) * share
                }
            }
            state[fixture] = values
        }
        return state
    }

    /// The share of a fade `elapsed` seconds in: a cut is whole at once.
    public static func progress(elapsed: Double, fade: Double) -> Double {
        guard fade.isFinite, fade > 0 else { return 1 }
        guard elapsed.isFinite else { return 0 }
        return Swift.min(1, Swift.max(0, elapsed / fade))
    }

    /// What the timeline's cues ask for at `seconds` of the song, or nil before the first placed
    /// cue. Each cue fades from what the one before it showed at the moment it started — a fade
    /// still running is taken over from where it stands. `songLook` gives the song's look at a
    /// moment in seconds.
    public func timelineTarget(atSeconds seconds: Double, tempoMap: TempoMap,
                               songLook: (Double) -> LightFixture.Look) -> RigState? {
        var current: (cue: LightCue, start: Double, from: RigState)?
        for placement in placements {
            let start = tempoMap.seconds(at: placement.tick)
            guard start <= seconds else { break }
            guard let cue = cue(placement.cue) else { continue }
            let from: RigState
            if let running = current {
                from = Self.interpolate(from: running.from, to: target(of: running.cue, songLook: songLook(start)),
                                        progress: Self.progress(elapsed: start - running.start, fade: running.cue.fade))
            } else {
                from = restState
            }
            current = (cue, start, from)
        }
        guard let current else { return nil }
        return Self.interpolate(from: current.from, to: target(of: current.cue, songLook: songLook(seconds)),
                                progress: Self.progress(elapsed: seconds - current.start, fade: current.cue.fade))
    }

    /// The DMX universes the rig fills from `state`, each 512 slots, keyed 1 …. A fixture without
    /// a known profile sends nothing; a universe no fixture uses is not in the result.
    public func universes(_ state: RigState) -> [Int: [UInt8]] {
        var universes: [Int: [UInt8]] = [:]
        for fixture in fixtures {
            guard let profile = fixture.profile else { continue }
            var slots = universes[fixture.universe] ?? [UInt8](repeating: 0, count: PatchedFixture.channelRange.upperBound)
            let values = state[fixture.id] ?? [:]
            for (offset, slot) in profile.layout.enumerated() {
                let index = fixture.address - 1 + offset
                guard slots.indices.contains(index) else { continue }
                switch slot {
                case .single(let attribute):
                    slots[index] = DMXWord.byte(values[attribute] ?? attribute.restValue)
                case .coarse(let attribute):
                    slots[index] = DMXWord.split(DMXWord.word(values[attribute] ?? attribute.restValue)).coarse
                case .fine(let attribute):
                    slots[index] = DMXWord.split(DMXWord.word(values[attribute] ?? attribute.restValue)).fine
                case .fixed(let byte):
                    slots[index] = byte
                }
            }
            universes[fixture.universe] = slots
        }
        return universes
    }
}

/// The flash limit on every light-making channel of the rig: each follows its target no faster
/// than `FlashLimit` allows — whatever a cue, a GO pressed ten times a second or a blackout asks
/// for, no channel flashes more than three times a second. Position passes untouched.
public struct RigFlashGuard: Equatable, Sendable {
    private struct Channel: Hashable, Sendable {
        var fixture: FixtureID
        var attribute: LightAttribute
    }

    private var limits: [Channel: FlashLimit] = [:]

    public init() {}

    /// The state to send after `seconds`, on the way to `target`.
    public mutating func next(towards target: RigState, after seconds: Double) -> RigState {
        var state = target
        for (fixture, values) in target {
            var limited = values
            for (attribute, value) in values where attribute.isBrightness {
                let channel = Channel(fixture: fixture, attribute: attribute)
                var limit = limits[channel] ?? FlashLimit(value: 0)
                limited[attribute] = limit.next(towards: value, after: seconds)
                limits[channel] = limit
            }
            state[fixture] = limited
        }
        return state
    }

    /// `state` with every light at 0 — the blackout's target; position stays.
    public static func dark(_ state: RigState) -> RigState {
        state.mapValues { values in
            var dark = values
            for attribute in values.keys where attribute.isBrightness { dark[attribute] = 0 }
            return dark
        }
    }
}

/// The show rendered offline: a DMX frame every `1 / frameRate` seconds of the song, through the
/// same targets and the same flash limit the live output uses. Nothing measured enters it — no
/// meter, no body — so the same song always yields the same frames: a song look follows the key
/// and the beat and holds its level at rest.
public enum LightShowRender {
    public struct Frame: Equatable, Sendable {
        public var seconds: Double
        public var universes: [Int: [UInt8]]
    }

    public static let defaultFrameRate = 40.0

    /// The song look the render uses at `seconds`: key colour and beat, no level, no body.
    public static func songLook(of project: Project, atSeconds seconds: Double) -> LightFixture.Look {
        let tick = project.tempoMap.tick(atSeconds: seconds)
        let frame = FieldFrame.at(tick: Double(tick), meter: project.meterMap, context: project.context, level: 0,
                                  pulse: nil, hrv: nil, coherence: nil, isPlaying: true)
        return LightFixture.look(for: frame, sharesBody: false)
    }

    /// The frames from 0 to `duration` seconds (at most an hour of them).
    public static func frames(of project: Project, duration: Double, frameRate: Double = defaultFrameRate) -> [Frame] {
        let lighting = project.lighting
        guard !lighting.fixtures.isEmpty, duration.isFinite, duration >= 0, frameRate.isFinite, frameRate > 0 else { return [] }
        let count = Int(Swift.min(duration, 3_600) * frameRate) + 1
        let step = 1 / frameRate
        let map = project.tempoMap
        var guardRail = RigFlashGuard()
        var frames: [Frame] = []
        frames.reserveCapacity(count)
        for index in 0..<count {
            let seconds = Double(index) * step
            let target = lighting.timelineTarget(atSeconds: seconds, tempoMap: map) { songLook(of: project, atSeconds: $0) }
                ?? lighting.restState
            let state = guardRail.next(towards: target, after: step)
            frames.append(Frame(seconds: seconds, universes: lighting.universes(state)))
        }
        return frames
    }

    /// How long the show runs: to the last placed cue's end of fade, plus two seconds to settle.
    public static func duration(of project: Project) -> Double {
        let map = project.tempoMap
        let ends = project.lighting.placements.compactMap { placement -> Double? in
            guard let cue = project.lighting.cue(placement.cue) else { return nil }
            return map.seconds(at: placement.tick) + cue.fade
        }
        return (ends.max() ?? 0) + 2
    }

    /// The frames as text, one line per channel that changed: `seconds,universe,channel,value` —
    /// the first frame states every channel that is not 0. Plain, so any tool can replay it.
    public static func csv(_ frames: [Frame]) -> String {
        var lines = ["seconds,universe,channel,value"]
        var last: [Int: [UInt8]] = [:]
        for frame in frames {
            for universe in frame.universes.keys.sorted() {
                guard let slots = frame.universes[universe] else { continue }
                let before = last[universe]
                for (index, value) in slots.enumerated() {
                    let changed = before.map { $0.indices.contains(index) ? $0[index] != value : true } ?? (value != 0)
                    guard changed else { continue }
                    lines.append(String(format: "%.3f,%d,%d,%d", frame.seconds, universe, index + 1, Int(value)))
                }
                last[universe] = slots
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }
}

// MARK: - Edits (each one light command's apply)

extension Lighting {
    mutating func addFixture(_ fixture: PatchedFixture) throws {
        guard self.fixture(fixture.id) == nil else { throw CommandError.duplicateID(fixture.id.description) }
        guard fixtures.count < Self.maximumFixtures else {
            throw Project.invalid("fixtures", "a rig holds at most \(Self.maximumFixtures) fixtures")
        }
        guard fixture.profile != nil else { throw Project.invalid("profile", "names no fixture profile") }
        var named = fixture
        named.name = try Names.validated(fixture.name, parameter: "name")
        try Self.validate(fixture: named)
        if let message = conflictMessage(for: named) { throw Project.invalid("address", message) }
        fixtures.append(named)
    }

    mutating func patchFixture(_ id: FixtureID, universe: Int, address: Int) throws {
        guard let index = fixtures.firstIndex(where: { $0.id == id }) else {
            throw Project.invalid("fixture", "no such fixture")
        }
        var moved = fixtures[index]
        moved.universe = universe
        moved.address = address
        try Self.validate(fixture: moved)
        if let message = conflictMessage(for: moved) { throw Project.invalid("address", message) }
        fixtures[index] = moved
    }

    mutating func renameFixture(_ id: FixtureID, name: String) throws {
        guard let index = fixtures.firstIndex(where: { $0.id == id }) else {
            throw Project.invalid("fixture", "no such fixture")
        }
        fixtures[index].name = try Names.validated(name, parameter: "name")
    }

    /// Removes the fixture and its values from every cue.
    mutating func removeFixture(_ id: FixtureID) throws {
        guard fixture(id) != nil else { throw Project.invalid("fixture", "no such fixture") }
        fixtures.removeAll { $0.id == id }
        for index in cues.indices { cues[index].values.removeAll { $0.fixture == id } }
    }

    mutating func addCue(_ cue: LightCue, index: Int?) throws {
        guard self.cue(cue.id) == nil else { throw CommandError.duplicateID(cue.id.description) }
        guard cues.count < Self.maximumCues else { throw Project.invalid("cues", "a song holds at most \(Self.maximumCues) cues") }
        var named = cue
        named.name = try Names.validated(cue.name, parameter: "name")
        try Self.validate(cue: named, in: self)
        if let index {
            guard (0...cues.count).contains(index) else { throw Project.invalid("index", "outside the cue list") }
            cues.insert(named, at: index)
        } else {
            cues.append(named)
        }
    }

    /// Replaces the cue with the same id — its name, fade, look and values.
    mutating func setCue(_ cue: LightCue) throws {
        guard let index = cues.firstIndex(where: { $0.id == cue.id }) else { throw Project.invalid("cue", "no such cue") }
        var named = cue
        named.name = try Names.validated(cue.name, parameter: "name")
        try Self.validate(cue: named, in: self)
        cues[index] = named
    }

    /// Removes the cue and every place on the timeline it starts.
    mutating func removeCue(_ id: CueID) throws {
        guard cue(id) != nil else { throw Project.invalid("cue", "no such cue") }
        cues.removeAll { $0.id == id }
        placements.removeAll { $0.cue == id }
    }

    /// Starts `cue` at `tick`; a cue already starting there is replaced.
    mutating func placeCue(_ id: CueID, at tick: Tick) throws {
        guard cue(id) != nil else { throw Project.invalid("cue", "no such cue") }
        guard tick >= 0, tick <= MusicalTime.maximumTick else {
            throw Project.invalid("tick", "must be within 0…\(MusicalTime.maximumTick) ticks")
        }
        if let index = placements.firstIndex(where: { $0.tick == tick }) {
            placements[index].cue = id
            return
        }
        guard placements.count < Self.maximumPlacements else {
            throw Project.invalid("placements", "a song holds at most \(Self.maximumPlacements) placed cues")
        }
        placements.append(CuePlacement(tick: tick, cue: id))
        placements.sort { $0.tick < $1.tick }
    }

    mutating func removeCuePlacement(at tick: Tick) throws {
        guard placements.contains(where: { $0.tick == tick }) else { throw Project.invalid("tick", "no cue starts at \(tick)") }
        placements.removeAll { $0.tick == tick }
    }
}
