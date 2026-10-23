/// The whole song as plain values. Nothing here knows about audio, views or files —
/// the engine compiles it into a playback plan, the UI draws it, the codec stores it.
/// The only way to change it is a `Command` performed through `ProjectStore`.
public struct Project: Codable, Equatable, Sendable {
    /// Bumped whenever the stored shape changes. A file with a NEWER number is refused
    /// (`ProjectCodec`), so an old build never silently drops what it does not understand.
    /// 2 (2026-10-20): a parameter address is stored as its text form (`docs/FORMAT.md`).
    public static let currentFormatVersion = 2

    /// Always `currentFormatVersion` in memory: an older file is read into today's shape, so the
    /// next save writes today's number over today's shape and never an old number over it.
    public private(set) var formatVersion: Int
    public var name: String
    /// The tempo from tick 0 until the first change.
    public var tempo: Double
    /// Later tempo changes, sorted by tick, each after tick 0 and at a distinct tick.
    public var tempoChanges: [TempoChange]
    public var timeSignature: TimeSignature
    /// Key, scale, tone system, concert pitch and swing — the frame the musician sets.
    public var context: MusicalContext
    public var tracks: [Track]
    public var scenes: [Scene]
    public var master: MixerStrip
    /// Effects on the master mix, in order, after the master fader — where a final limiter goes.
    /// Tracks on their own outputs skip the master, and its inserts with it.
    public var masterInserts: [Insert]
    /// Audio files imported into the song, in import order.
    public var media: [MediaFile]
    /// Controllers learned for this song, one target per control.
    public var midiMappings: [MIDIMapping]
    /// Parameters that move over time, one lane per parameter.
    public var automation: [AutomationLane]

    public init(
        name: String = "Untitled",
        tempo: Double = Tempo.defaultBPM,
        tempoChanges: [TempoChange] = [],
        timeSignature: TimeSignature = .common,
        tracks: [Track] = [],
        scenes: [Scene] = [],
        master: MixerStrip = MixerStrip(),
        media: [MediaFile] = [],
        midiMappings: [MIDIMapping] = [],
        automation: [AutomationLane] = [],
        masterInserts: [Insert] = [],
        context: MusicalContext = MusicalContext()
    ) {
        self.formatVersion = Self.currentFormatVersion
        self.name = name
        self.tempo = tempo
        self.tempoChanges = tempoChanges
        self.timeSignature = timeSignature
        self.context = context
        self.tracks = tracks
        self.scenes = scenes
        self.master = master
        self.media = media
        self.midiMappings = midiMappings
        self.automation = automation
        self.masterInserts = masterInserts
    }

    private enum CodingKeys: String, CodingKey {
        case formatVersion, name, tempo, tempoChanges, timeSignature, tracks, scenes, master, media, midiMappings, automation
        case masterInserts, context
    }

    /// Fields added after format 1 shipped decode with their default when absent.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let stored = try c.decode(Int.self, forKey: .formatVersion)
        guard (1...Self.currentFormatVersion).contains(stored) else {
            throw DecodingError.dataCorruptedError(forKey: .formatVersion, in: c,
                                                   debugDescription: "format \(stored) is not 1…\(Self.currentFormatVersion)")
        }
        formatVersion = Self.currentFormatVersion
        name = try c.decode(String.self, forKey: .name)
        tempo = try c.decode(Double.self, forKey: .tempo)
        tempoChanges = try c.decodeIfPresent([TempoChange].self, forKey: .tempoChanges) ?? []
        timeSignature = try c.decode(TimeSignature.self, forKey: .timeSignature)
        tracks = try c.decode([Track].self, forKey: .tracks)
        scenes = try c.decode([Scene].self, forKey: .scenes)
        master = try c.decode(MixerStrip.self, forKey: .master)
        media = try c.decodeIfPresent([MediaFile].self, forKey: .media) ?? []
        midiMappings = try c.decodeIfPresent([MIDIMapping].self, forKey: .midiMappings) ?? []
        automation = try c.decodeIfPresent([AutomationLane].self, forKey: .automation) ?? []
        masterInserts = try c.decodeIfPresent([Insert].self, forKey: .masterInserts) ?? []
        context = try c.decodeIfPresent(MusicalContext.self, forKey: .context) ?? MusicalContext()
    }

    /// Whether one more track of `kind` fits (`Track.limit(for:)`).
    public func canAddTrack(_ kind: TrackKind) -> Bool {
        tracks.lazy.filter { $0.kind == kind }.count < Track.limit(for: kind)
    }

    public func trackIndex(_ id: TrackID) -> Int? {
        tracks.firstIndex { $0.id == id }
    }

    public func track(_ id: TrackID) -> Track? {
        trackIndex(id).map { tracks[$0] }
    }

    /// Where a clip lives. Clip ids are unique across the whole project.
    public func clipLocation(_ id: ClipID) -> (track: Int, clip: Int)? {
        for (t, track) in tracks.enumerated() {
            if let c = track.clips.firstIndex(where: { $0.id == id }) {
                return (t, c)
            }
        }
        return nil
    }

    public func clip(_ id: ClipID) -> Clip? {
        clipLocation(id).map { tracks[$0.track].clips[$0.clip] }
    }

    public func sceneIndex(_ id: SceneID) -> Int? {
        scenes.firstIndex { $0.id == id }
    }
}

/// When an audio track plays its input through its own channel strip.
public enum MonitorMode: String, Codable, Sendable, CaseIterable {
    /// While the track is armed — and only where it cannot howl: the device's own microphone is
    /// heard in headphones or through an interface, never on a speaker in the room.
    case auto
    /// Always, armed or not — under the same rule as `auto`.
    case input = "in"
    /// Never; the interface or the mixer monitors directly.
    case off
}

public enum TrackKind: String, Codable, Sendable, CaseIterable {
    /// Plays MIDI clips into an instrument (own or AUv3).
    case instrument
    /// Plays audio regions (and, later, records from an input).
    case audio
    /// Receives sends from other tracks; holds effects only, no clips.
    case returnTrack
}

public struct Track: Codable, Equatable, Sendable, Identifiable {
    public var id: TrackID
    public var name: String
    public var kind: TrackKind
    /// Index into the UI palette; the document stores the choice, not a colour value.
    public var colorIndex: Int
    public var mixer: MixerStrip
    /// The clips this track owns. Arrangement placements and session slots refer to them.
    public var clips: [Clip]
    /// Clips on the arrangement timeline.
    public var placements: [Placement]
    /// Session view: which clip sits in which scene's slot.
    public var slots: [SlotAssignment]
    /// Audio on the timeline, sorted by start. Only audio tracks have any.
    public var regions: [AudioRegion]
    /// The synth sound. Instrument tracks play it; other kinds keep the default and ignore it.
    public var instrument: InstrumentSettings
    /// Effects on the track's signal, in order, before its fader and pan.
    public var inserts: [Insert]
    /// Post-fader sends into return tracks, one per return at most. A return track has none.
    public var sends: [Send]
    /// Where the track plays: nil into the master, or the first channel (0-based, even) of a
    /// stereo pair on the audio interface — channel 2 is outputs 3/4. Such a track skips the
    /// master fader; its sends still reach the returns.
    public var output: Int?
    /// The interface input an audio track records from, 0-based; nil is the first. A channel the
    /// interface lacks is kept, and the track records the first until it is back.
    public var input: Int?
    /// When an audio track hears its input; other kinds keep `auto` and ignore it. A mode this
    /// build does not know reads as `auto` and is kept under its own name until one is chosen.
    public var monitor: MonitorMode {
        get { MonitorMode(rawValue: monitorName) ?? .auto }
        set { monitorName = newValue.rawValue }
    }
    /// The stored name of a monitoring mode this build does not know, if that is what the track holds.
    public var unrecognizedMonitor: String? { MonitorMode(rawValue: monitorName) == nil ? monitorName : nil }
    private var monitorName = MonitorMode.auto.rawValue

    /// How many tracks of a kind one song may hold: the engine has exactly this many instrument
    /// voices, smoothed audio channels and return buses, and a track past them would play
    /// silently. The command that would add one is refused instead.
    public static func limit(for kind: TrackKind) -> Int {
        switch kind {
        case .instrument: 32
        case .audio: 64
        case .returnTrack: 8
        }
    }

    /// Interface channels a track may name; the device decides how many exist.
    public static let outputChannelLimit = 64
    public static let inputChannelLimit = 64

    public init(
        id: TrackID = TrackID(),
        name: String,
        kind: TrackKind,
        colorIndex: Int = 0,
        mixer: MixerStrip = MixerStrip(),
        clips: [Clip] = [],
        placements: [Placement] = [],
        slots: [SlotAssignment] = [],
        instrument: InstrumentSettings = InstrumentSettings(),
        regions: [AudioRegion] = [],
        inserts: [Insert] = [],
        sends: [Send] = []
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.colorIndex = colorIndex
        self.mixer = mixer
        self.clips = clips
        self.placements = placements
        self.slots = slots
        self.instrument = instrument
        self.regions = regions
        self.inserts = inserts
        self.sends = sends
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, kind, colorIndex, mixer, clips, placements, slots, instrument, regions, inserts, sends, output, input
        case monitorName = "monitor"
    }

    /// Fields added after format 1 shipped decode with their default when absent.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(TrackID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        kind = try c.decode(TrackKind.self, forKey: .kind)
        colorIndex = try c.decode(Int.self, forKey: .colorIndex)
        mixer = try c.decode(MixerStrip.self, forKey: .mixer)
        clips = try c.decode([Clip].self, forKey: .clips)
        placements = try c.decode([Placement].self, forKey: .placements)
        slots = try c.decode([SlotAssignment].self, forKey: .slots)
        instrument = try c.decodeIfPresent(InstrumentSettings.self, forKey: .instrument) ?? InstrumentSettings()
        regions = try c.decodeIfPresent([AudioRegion].self, forKey: .regions) ?? []
        inserts = try c.decodeIfPresent([Insert].self, forKey: .inserts) ?? []
        sends = try c.decodeIfPresent([Send].self, forKey: .sends) ?? []
        output = try c.decodeIfPresent(Int.self, forKey: .output)
        input = try c.decodeIfPresent(Int.self, forKey: .input)
        monitorName = try c.decodeIfPresent(String.self, forKey: .monitorName) ?? MonitorMode.auto.rawValue
    }

    public func clipIndex(_ id: ClipID) -> Int? {
        clips.firstIndex { $0.id == id }
    }

    public func placementIndex(_ id: PlacementID) -> Int? {
        placements.firstIndex { $0.id == id }
    }

    public func clipInSlot(_ scene: SceneID) -> ClipID? {
        slots.first { $0.scene == scene }?.clip
    }
}

public struct MixerStrip: Codable, Equatable, Sendable {
    /// Fader level in dB. The floor stands for silence (−∞ on screen).
    public var volumeDB: Double
    /// −1 is hard left, +1 hard right.
    public var pan: Double
    public var isMuted: Bool
    public var isSoloed: Bool

    public static let volumeRange: ClosedRange<Double> = -144...6
    public static let panRange: ClosedRange<Double> = -1...1

    public init(volumeDB: Double = 0, pan: Double = 0, isMuted: Bool = false, isSoloed: Bool = false) {
        self.volumeDB = volumeDB
        self.pan = pan
        self.isMuted = isMuted
        self.isSoloed = isSoloed
    }
}

public struct Clip: Codable, Equatable, Sendable, Identifiable {
    public var id: ClipID
    public var name: String
    /// Loop length. Notes are positioned relative to the clip start.
    public var length: Tick
    public var notes: [Note]
    /// Set for an audio clip, a session loop on an audio track: the stretch of a file it plays,
    /// from the start of each pass. An audio clip has no notes.
    public var audio: ClipAudio?
    /// Pitch bends and controllers, sorted by start. Only a MIDI clip has them.
    public var controls: [ControlChange]

    public init(id: ClipID = ClipID(), name: String, length: Tick, notes: [Note] = [], audio: ClipAudio? = nil,
                controls: [ControlChange] = []) {
        self.id = id
        self.name = name
        self.length = length
        self.notes = notes
        self.audio = audio
        self.controls = controls
    }

    private enum CodingKeys: String, CodingKey { case id, name, length, notes, audio, controls }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(ClipID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        length = try c.decode(Tick.self, forKey: .length)
        notes = try c.decode([Note].self, forKey: .notes)
        audio = try c.decodeIfPresent(ClipAudio.self, forKey: .audio)
        controls = try c.decodeIfPresent([ControlChange].self, forKey: .controls) ?? []
    }
}

/// The audio an audio clip plays: `length` frames of a song file from `offset`, at the file's
/// own speed. A pass shorter than the clip's loop leaves silence until the next; a longer one is
/// cut at the loop.
public struct ClipAudio: Codable, Equatable, Sendable {
    public var media: MediaID
    public var offset: Int
    public var length: Int

    public init(media: MediaID, offset: Int = 0, length: Int) {
        self.media = media
        self.offset = offset
        self.length = length
    }
}

public struct Note: Codable, Equatable, Sendable, Identifiable {
    public var id: NoteID
    public var pitch: Int
    public var velocity: Int
    public var start: Tick
    public var length: Tick

    public init(id: NoteID = NoteID(), pitch: Int, velocity: Int = 100, start: Tick, length: Tick) {
        self.id = id
        self.pitch = pitch
        self.velocity = velocity
        self.start = start
        self.length = length
    }

    public static let pitchRange: ClosedRange<Int> = 0...127
    public static let velocityRange: ClosedRange<Int> = 1...127
}

/// A clip on the arrangement timeline. It plays the clip from `start` for one clip length.
public struct Placement: Codable, Equatable, Sendable, Identifiable {
    public var id: PlacementID
    public var clip: ClipID
    public var start: Tick

    public init(id: PlacementID = PlacementID(), clip: ClipID, start: Tick) {
        self.id = id
        self.clip = clip
        self.start = start
    }
}

public struct Scene: Codable, Equatable, Sendable, Identifiable {
    public var id: SceneID
    public var name: String

    public init(id: SceneID = SceneID(), name: String) {
        self.id = id
        self.name = name
    }
}

public struct SlotAssignment: Codable, Equatable, Sendable {
    public var scene: SceneID
    public var clip: ClipID

    public init(scene: SceneID, clip: ClipID) {
        self.scene = scene
        self.clip = clip
    }
}
