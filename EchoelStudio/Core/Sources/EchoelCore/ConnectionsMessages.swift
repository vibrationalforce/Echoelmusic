import Foundation

/// One OSC message as values, before it is bytes: what the builders below decide to say.
public struct OSCMessage: Equatable, Sendable {
    public var address: String
    public var floats: [Float]

    public init(_ address: String, _ floats: [Float]) {
        self.address = address
        self.floats = floats
    }

    public var encoded: Data { OSCPacket.message(address: address, floats: floats) }
}

/// What the body offers a connection at one moment, with the source it came from. Each field is
/// nil while it is not measured — the builders then say nothing on that address, so a receiver
/// holds its last value instead of reading a zero it cannot tell from a measurement.
public struct BodyEgressReading: Equatable, Sendable {
    public var source: BodyChannel.Source
    /// Beats per minute, as measured; plausible between 40 and 200.
    public var beatsPerMinute: Double?
    /// HRV and coherence, each normalized 0 … 1.
    public var hrv: Double?
    public var coherence: Double?
    /// Breaths per minute (plausible 3 … 40) and the breath's phase 0 … 1 (0 = exhale begins).
    public var breathRate: Double?
    public var breathPhase: Double?

    public init(source: BodyChannel.Source, beatsPerMinute: Double? = nil, hrv: Double? = nil,
                coherence: Double? = nil, breathRate: Double? = nil, breathPhase: Double? = nil) {
        self.source = source
        self.beatsPerMinute = beatsPerMinute
        self.hrv = hrv
        self.coherence = coherence
        self.breathRate = breathRate
        self.breathPhase = breathPhase
    }

    public static let plausibleBeats: ClosedRange<Double> = 40...200
    public static let plausibleBreaths: ClosedRange<Double> = 3...40
}

/// The OSC address set the earlier app published (`/echoelmusic/bio/*`, `/echoelmusic/music/*`),
/// built from Studio's values. Pure, so every rule is a test: an address rides the measurement of
/// its own channel and is absent otherwise (the earlier app's #245 law — a structural zero on
/// `/heart/bpm` slewed a lighting desk to black), HRV and coherence need a pulse as well as their
/// own value (both derive from the beat series; a value beside no pulse is a bug upstream, not a
/// reading), and a batch that says nothing at all is empty rather than a bare flag.
///
/// Classification and consent are NOT applied here — `BioEgressPolicy.allowsEgress(address:
/// source:consent:)` is asked per message by the one sender, so the rule has one home.
public enum ConnectionsOSC {
    public static let synthetic = "/echoelmusic/bio/synthetic"
    public static let heartRate = "/echoelmusic/bio/heart/bpm"
    public static let hrv = "/echoelmusic/bio/heart/hrv"
    public static let coherence = "/echoelmusic/bio/coherence"
    public static let breathRate = "/echoelmusic/bio/breath/rate"
    public static let breathPhase = "/echoelmusic/bio/breath/phase"
    public static let tempo = "/echoelmusic/music/tempo"
    public static let keyRoot = "/echoelmusic/music/key/root"
    public static let beatPhase = "/echoelmusic/music/beat/phase"
    public static let masterLevel = "/echoelmusic/music/level/master"

    /// The body batch. `/bio/synthetic` leads every non-empty batch and is 0: Studio has no demo
    /// generator, so what it measures is a body — kept on the wire because receivers written for
    /// the earlier app latch it as state. Not sent: `/bio/motion` (nothing measures motion) and
    /// the clinical trio (nothing here derives RMSSD, SDNN or pNN50 in medical units).
    public static func bioMessages(for reading: BodyEgressReading) -> [OSCMessage] {
        var messages: [OSCMessage] = []
        let pulse = reading.beatsPerMinute.flatMap { bpm -> Double? in
            bpm.isFinite && BodyEgressReading.plausibleBeats.contains(bpm) ? bpm : nil
        }
        if let pulse {
            messages.append(OSCMessage(heartRate, [Float(pulse)]))
            if let variability = unit(reading.hrv) { messages.append(OSCMessage(hrv, [Float(variability)])) }
            if let coherent = unit(reading.coherence) { messages.append(OSCMessage(coherence, [Float(coherent)])) }
        }
        if let breaths = reading.breathRate, breaths.isFinite, BodyEgressReading.plausibleBreaths.contains(breaths) {
            messages.append(OSCMessage(breathRate, [Float(breaths)]))
            // The phase has no "unknown" value of its own (0 is a real position), so it rides the
            // rate: a source with a rate and no waveform sends no phase.
            if let phase = unit(reading.breathPhase) { messages.append(OSCMessage(breathPhase, [Float(phase)])) }
        }
        if !messages.isEmpty { messages.insert(OSCMessage(synthetic, [0]), at: 0) }
        return messages
    }

    /// The song's batch: the tempo the transport plays, the key's root (0 = C … 11 = B), where the
    /// playhead stands in its beat, and the master's level 0 … 1. The tempo is the song's written
    /// tempo (or the clock it follows) — a body never sets it here, so it carries no body.
    /// `0` for tempo and level while stopped means stopped, and is sent as such: a receiver can
    /// tell "transport stopped" from "Echoel went away". `/music/note/count` is not built: nothing
    /// counts sounding notes in Studio, and a constant would read as a measurement.
    public static func musicMessages(tempo: Double, root: Int, beatPhase: Double, masterLevel: Double) -> [OSCMessage] {
        [
            OSCMessage(Self.tempo, [Float(tempo.isFinite && tempo > 0 ? tempo : 0)]),
            OSCMessage(keyRoot, [Float(((root % 12) + 12) % 12)]),
            OSCMessage(Self.beatPhase, [Float(clamped(beatPhase))]),
            // A level past full scale is a clipping mix, and reads as 1 — not as silence.
            OSCMessage(Self.masterLevel, [Float(clamped(masterLevel))]),
        ]
    }

    /// A reading 0 … 1, or nil for anything that is not one: the body builders say nothing then.
    static func unit(_ value: Double?) -> Double? {
        guard let value, value.isFinite, (0...1).contains(value) else { return nil }
        return value
    }

    /// A song value held to 0 … 1; the song always has one, so nothing is withheld.
    static func clamped(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return Swift.min(1, Swift.max(0, value))
    }
}

/// ADM-OSC (github.com/immersive-audio-live/ADM-OSC): every track of the song as one audio
/// object, object `n` = track `n` in song order, 1-based. Its position is the track's pan on the
/// horizontal circle at the reference distance — what a stereo pan means in a room — sent as the
/// packed `/aed` the standard's minimum implementation requires of a sender (and lets a receiver
/// ignore the single leaves); its gain is the track's live level. Nothing of the body is in it:
/// the namespace belongs to the renderer and carries no provenance flag.
public struct ADMObject: Equatable, Sendable {
    /// 1-based; the standard has no object 0.
    public var index: Int
    /// Degrees, −180 … 180, positive to the LEFT (the standard's convention).
    public var azimuth: Float
    /// Degrees, −90 … 90.
    public var elevation: Float
    /// Normalized, 0 … 1; 1 is the loudspeaker circle.
    public var distance: Float
    /// Linear, 0 … 1.
    public var gain: Float

    public init(index: Int, azimuth: Float, elevation: Float, distance: Float, gain: Float) {
        self.index = Swift.max(1, index)
        self.azimuth = Swift.min(180, Swift.max(-180, azimuth.isFinite ? azimuth : 0))
        self.elevation = Swift.min(90, Swift.max(-90, elevation.isFinite ? elevation : 0))
        self.distance = Swift.min(1, Swift.max(0, distance.isFinite ? distance : 1))
        self.gain = Swift.min(1, Swift.max(0, gain.isFinite ? gain : 0))
    }

    /// Track `index` panned `pan` (−1 hard left … 1 hard right) at `level` (0 … 1): hard left is
    /// +90° (the standard counts left positive), centre 0°, hard right −90°, on the horizon at the
    /// reference distance.
    public static func track(index: Int, pan: Double, level: Double) -> ADMObject {
        let position = pan.isFinite ? Swift.min(1, Swift.max(-1, pan)) : 0
        return ADMObject(index: index, azimuth: Float(-position * 90), elevation: 0, distance: 1,
                         gain: Float(level.isFinite ? level : 0))
    }

    public var prefix: String { "/adm/obj/\(index)" }

    /// The complete position as one packed message, so a renderer never draws an object half-way
    /// between two frames.
    public var positionMessage: OSCMessage { OSCMessage("\(prefix)/aed", [azimuth, elevation, distance]) }
    public var gainMessage: OSCMessage { OSCMessage("\(prefix)/gain", [gain]) }

    /// Everything the object says: its position, then its gain.
    public var messages: [OSCMessage] { [positionMessage, gainMessage] }

    public func hasSamePosition(as other: ADMObject) -> Bool {
        index == other.index && azimuth == other.azimuth && elevation == other.elevation && distance == other.distance
    }
}

/// The light Echoel drives: one fixture of dimmer and red, green, blue, as DMX channels. The song
/// sets it — the key is the colour (its hue on the circle of fifths), the level and the beat are
/// the brightness — and with body sharing on, a measured coherence lifts the brightness floor.
/// Every channel passes a `FlashLimit` on its way to the wire (`LightSlew`), so whatever the
/// values ask for, the fixture never flashes more than three times a second.
public enum LightFixture {
    /// DMX value size per channel. 16-bit sends each value as a coarse/fine pair (65 536 steps),
    /// the professional form for a fade without steps; 8-bit is what a simple fixture reads.
    public enum Resolution: String, Sendable, CaseIterable {
        case eightBit
        case sixteenBit

        public var channelCount: Int { self == .eightBit ? 4 : 8 }
    }

    /// The fixture's four values, each 0 … 1.
    public struct Look: Equatable, Sendable {
        public var dimmer: Double
        public var red: Double
        public var green: Double
        public var blue: Double

        public init(dimmer: Double, red: Double, green: Double, blue: Double) {
            self.dimmer = LightFixture.unit(dimmer)
            self.red = LightFixture.unit(red)
            self.green = LightFixture.unit(green)
            self.blue = LightFixture.unit(blue)
        }

        public static let dark = Look(dimmer: 0, red: 0, green: 0, blue: 0)
    }

    /// The brightness floor of a lit fixture, and how far a fully coherent body raises it.
    public static let restingDimmer = 0.2
    public static let coherenceLift = 0.5
    /// How much the level and the beat each add on top of the floor while the song plays.
    public static let levelSwing = 0.6
    public static let beatSwing = 0.2
    public static let channelRange: ClosedRange<Int> = 1...512

    /// What the fixture asks for from one frame. Without body sharing the body half of the frame
    /// is not read at all, so an unshared body cannot reach a lamp by any path.
    public static func look(for frame: FieldFrame, sharesBody: Bool) -> Look {
        var floor = restingDimmer
        if sharesBody, let coherence = frame.coherence { floor += coherenceLift * coherence }
        let song = frame.isPlaying ? levelSwing * frame.level + beatSwing * (1 - frame.beatPhase) : 0
        let colour = rgb(hue: frame.keyHue)
        return Look(dimmer: floor + song, red: colour.red, green: colour.green, blue: colour.blue)
    }

    /// A fully saturated colour from a hue 0 ..< 1.
    public static func rgb(hue: Double) -> (red: Double, green: Double, blue: Double) {
        let turn = unit(hue) * 6
        let sector = Int(turn.rounded(.down)) % 6
        let fraction = turn - turn.rounded(.down)
        switch sector {
        case 0: return (1, fraction, 0)
        case 1: return (1 - fraction, 1, 0)
        case 2: return (0, 1, fraction)
        case 3: return (0, 1 - fraction, 1)
        case 4: return (fraction, 0, 1)
        default: return (1, 0, 1 - fraction)
        }
    }

    /// The DMX channels: dimmer, red, green, blue in that order from slot `startChannel`
    /// (1-based), as bytes or as coarse/fine pairs; the slots before it are zero.
    public static func channels(_ look: Look, resolution: Resolution, startChannel: Int = 1) -> [UInt8] {
        let start = Swift.min(Swift.max(startChannel, channelRange.lowerBound), channelRange.upperBound)
        var channels = [UInt8](repeating: 0, count: start - 1)
        for value in [look.dimmer, look.red, look.green, look.blue] {
            switch resolution {
            case .eightBit: channels.append(byte(value))
            case .sixteenBit: channels.append(contentsOf: word(value))
            }
        }
        return Array(channels.prefix(channelRange.upperBound))
    }

    static func unit(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return Swift.min(1, Swift.max(0, value))
    }

    static func byte(_ value: Double) -> UInt8 {
        UInt8((unit(value) * 255).rounded())
    }

    static func word(_ value: Double) -> [UInt8] {
        let scaled = UInt16((unit(value) * 65535).rounded())
        return [UInt8(scaled >> 8), UInt8(scaled & 0xFF)]
    }
}

/// The fixture's four flash guards: each channel follows its target no faster than `FlashLimit`
/// allows, measured in the caller's seconds. One guard per channel, because a colour swing at a
/// steady dimmer is a luminance swing too.
public struct LightSlew: Equatable, Sendable {
    private var dimmer = FlashLimit()
    private var red = FlashLimit()
    private var green = FlashLimit()
    private var blue = FlashLimit()

    public init() {}

    /// The look to send after `seconds`, on the way to `target`.
    public mutating func next(towards target: LightFixture.Look, after seconds: Double) -> LightFixture.Look {
        LightFixture.Look(dimmer: dimmer.next(towards: target.dimmer, after: seconds),
                          red: red.next(towards: target.red, after: seconds),
                          green: green.next(towards: target.green, after: seconds),
                          blue: blue.next(towards: target.blue, after: seconds))
    }

    /// Where the guards stand now.
    public var current: LightFixture.Look {
        LightFixture.Look(dimmer: dimmer.value, red: red.value, green: green.value, blue: blue.value)
    }
}
