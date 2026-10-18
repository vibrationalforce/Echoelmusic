import Foundation

/// What the agent can do, in the shape a small language model handles well: few tools, plain
/// arguments, tracks named the way a musician names them ("Bass", "2"), positions in bars and
/// beats. Each action turns into ordinary commands, so it goes through the one door, validates
/// like every edit and undoes like every edit. Nothing here knows about the model.
public enum AgentAction: Equatable, Sendable {
    case setTempo(bpm: Double)
    /// `kind` is "instrument", "drums" or "audio"; `sound` a preset name for an instrument.
    case addTrack(name: String, kind: String, sound: String?)
    case removeTrack(track: String)
    case renameTrack(track: String, name: String)
    case setSound(track: String, sound: String)
    /// One drum of the kit as a step pattern, 16th notes: `x` hit, `X` accent, `.` rest. The
    /// pattern repeats over `bars` bars from `bar` (1-based) and replaces that drum there.
    case drumPattern(track: String, drum: String, steps: String, bar: Int, bars: Int)
    /// Notes as "pitch beat length [velocity]" separated by commas: `C4 1 1, E4+G4 2 0.5`.
    /// Beat is 1-based inside the region and may be fractional; length is in beats.
    case writeNotes(track: String, notes: String, bar: Int, bars: Int, replace: Bool)
    /// `track` may be "master"; nil leaves a value as it is.
    case mix(track: String, volumeDB: Double?, pan: Double?, mute: Bool?, solo: Bool?)
    /// One of the standard effects at the end of the track's insert chain.
    case addEffect(track: String, effect: String)
    /// The last insert of that effect on the track.
    case removeEffect(track: String, effect: String)
    /// Places the clip that starts at `bar` again `times` times, back to back after it.
    case repeatClip(track: String, bar: Int, times: Int)
    /// A movement of one parameter from the start of `fromBar` to the start of `toBar`, in the
    /// parameter's own unit (dB, −1…1, Hz, seconds). What the lane held in between is replaced;
    /// the rest of it stays. `curve` −1…1 bends the line, 0 is straight.
    case automate(track: String, parameter: String, fromBar: Int, toBar: Int, from: Double, to: Double, curve: Double)
}

public enum AgentError: Error, Equatable, Sendable, CustomStringConvertible {
    case unknownTrack(String, known: [String])
    case ambiguousTrack(String, matches: [String])
    case wrongTrack(String, reason: String)
    case invalid(String)

    /// Written for the model to read and correct itself, and for the musician to read.
    public var description: String {
        switch self {
        case let .unknownTrack(name, known):
            "There is no track \"\(name)\". Tracks: \(known.isEmpty ? "none" : known.joined(separator: ", "))."
        case let .ambiguousTrack(name, matches):
            "\"\(name)\" matches several tracks: \(matches.joined(separator: ", ")). Use the full name or the number."
        case let .wrongTrack(name, reason): "Track \"\(name)\" \(reason)."
        case let .invalid(reason): reason
        }
    }
}

public enum AgentTools {
    /// The longest region an action writes, in bars.
    public static let maximumBars = 64
    public static let maximumSteps = 64

    /// The commands for one action against the project as it is now. Throws without effect.
    public static func commands(for action: AgentAction, in project: Project) throws -> [Command] {
        switch action {
        case let .setTempo(bpm):
            guard bpm.isFinite, Tempo.range.contains(bpm) else {
                throw AgentError.invalid("A tempo must be between \(Int(Tempo.range.lowerBound)) and \(Int(Tempo.range.upperBound)) BPM.")
            }
            return [.setTempo(bpm: bpm)]

        case let .addTrack(name, kind, sound):
            let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { throw AgentError.invalid("A new track needs a name.") }
            let id = TrackID()
            switch kind.lowercased() {
            case "drums", "drum", "beat":
                let clip = ClipID()
                return [.addTrack(id: id, name: title, kind: .instrument, index: nil),
                        .setInstrumentDevice(id, .drums),
                        .createClip(track: id, id: clip, name: "Beat", length: MusicalTime.ticksPerBar(project.timeSignature)),
                        .placeClip(track: id, id: PlacementID(), clip: clip, start: 0)]
            case "instrument", "synth", "midi":
                var commands: [Command] = [.addTrack(id: id, name: title, kind: .instrument, index: nil)]
                if let sound { commands.append(.loadInstrumentPreset(id, name: try preset(sound))) }
                return commands
            case "audio":
                return [.addTrack(id: id, name: title, kind: .audio, index: nil)]
            default:
                throw AgentError.invalid("A track kind is instrument, drums or audio, not \"\(kind)\".")
            }

        case let .removeTrack(reference):
            return [.removeTrack(try track(reference, in: project).id)]

        case let .renameTrack(reference, name):
            let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { throw AgentError.invalid("A track name cannot be empty.") }
            return [.renameTrack(try track(reference, in: project).id, name: title)]

        case let .setSound(reference, sound):
            let target = try track(reference, in: project)
            guard target.kind == .instrument else { throw AgentError.wrongTrack(target.name, reason: "plays no instrument") }
            var commands: [Command] = []
            if target.instrument.device != .synth { commands.append(.setInstrumentDevice(target.id, .synth)) }
            commands.append(.loadInstrumentPreset(target.id, name: try preset(sound)))
            return commands

        case let .drumPattern(reference, drum, steps, bar, bars):
            let target = try track(reference, in: project)
            guard target.kind == .instrument, target.instrument.device == .drums else {
                throw AgentError.wrongTrack(target.name, reason: "is not a drum track")
            }
            guard let drumKey = drumPitch(drum) else {
                throw AgentError.invalid("There is no drum \"\(drum)\". Drums: \(DrumLane.standardKit.map(\.name).joined(separator: ", ")).")
            }
            let hits = try pattern(steps)
            let place = try region(on: target, bar: bar, bars: bars, in: project)
            var commands = place.commands
            let clip = place.clip, length = place.length
            // Only inside the bars asked for: a longer clip keeps the drum in its other bars.
            let old = clip.notes.filter { $0.pitch == drumKey && $0.start < length }.map(\.id)
            if !old.isEmpty { commands.append(.removeNotes(clip.id, old)) }
            let step = MusicalTime.ticksPerQuarter / 4
            var notes: [Note] = []
            var start: Tick = 0, index = 0
            while start < length {
                if let velocity = hits[index % hits.count] {
                    notes.append(Note(pitch: drumKey, velocity: velocity, start: start, length: Swift.min(step, length - start)))
                }
                start += step
                index += 1
            }
            if !notes.isEmpty { commands.append(.addNotes(clip.id, notes)) }
            return commands

        case let .writeNotes(reference, text, bar, bars, replace):
            let target = try track(reference, in: project)
            guard target.kind == .instrument else { throw AgentError.wrongTrack(target.name, reason: "plays no notes") }
            let beat = MusicalTime.ticksPerBeat(project.timeSignature)
            let place = try region(on: target, bar: bar, bars: bars, in: project)
            var commands = place.commands
            let clip = place.clip
            let notes = try parseNotes(text, beat: beat, regionLength: place.length)
            if replace, !clip.notes.isEmpty { commands.append(.removeNotes(clip.id, clip.notes.map(\.id))) }
            commands.append(.addNotes(clip.id, notes))
            return commands

        case let .mix(reference, volumeDB, pan, mute, solo):
            let mixer: MixerTarget
            let id: TrackID?
            if reference.lowercased() == "master" {
                guard mute == nil, solo == nil else { throw AgentError.invalid("The master cannot be muted or soloed.") }
                mixer = .master
                id = nil
            } else {
                let target = try track(reference, in: project)
                mixer = .track(target.id)
                id = target.id
            }
            var commands: [Command] = []
            if let volumeDB {
                guard volumeDB.isFinite, volumeDB <= MixerStrip.volumeRange.upperBound else {
                    throw AgentError.invalid("A fader goes up to +\(Int(MixerStrip.volumeRange.upperBound)) dB.")
                }
                commands.append(.setVolume(mixer, db: Swift.max(volumeDB, MixerStrip.volumeRange.lowerBound)))
            }
            if let pan {
                guard pan.isFinite, MixerStrip.panRange.contains(pan) else {
                    throw AgentError.invalid("Pan goes from -1 (left) to 1 (right).")
                }
                commands.append(.setPan(mixer, pan: pan))
            }
            if let id, let mute { commands.append(.setMute(id, mute)) }
            if let id, let solo { commands.append(.setSolo(id, solo)) }
            guard !commands.isEmpty else { throw AgentError.invalid("Nothing to change: give a volume, pan, mute or solo.") }
            return commands

        case let .addEffect(reference, name):
            let target = try track(reference, in: project)
            let effect = try standardEffect(name)
            guard target.inserts.count < Insert.maximumPerTrack else {
                throw AgentError.wrongTrack(target.name, reason: "already has \(Insert.maximumPerTrack) effects")
            }
            return [.addInsert(track: target.id, id: InsertID(), plugin: effect.component, index: nil)]

        case let .removeEffect(reference, name):
            let target = try track(reference, in: project)
            let effect = try standardEffect(name)
            guard let insert = target.inserts.last(where: { StandardEffect(component: $0.plugin) == effect }) else {
                throw AgentError.wrongTrack(target.name, reason: "has no \(effect.title)")
            }
            return [.removeInsert(track: target.id, insert.id)]

        case let .repeatClip(reference, bar, times):
            let target = try track(reference, in: project)
            guard (1...maximumBars).contains(times) else { throw AgentError.invalid("Repeat a clip 1 to \(maximumBars) times.") }
            let barTicks = MusicalTime.ticksPerBar(project.timeSignature)
            guard bar >= 1, Tick(bar) <= MusicalTime.maximumTick / barTicks else {
                throw AgentError.invalid("Bar \(bar) is not in the song.")
            }
            let start = Tick(bar - 1) * barTicks
            guard let placement = target.placements.first(where: { $0.start == start }),
                  let clip = target.clips.first(where: { $0.id == placement.clip }) else {
                throw AgentError.wrongTrack(target.name, reason: "has no clip starting at bar \(bar)")
            }
            let length = Swift.max(clip.length, 1)
            guard start + Tick(times + 1) * length <= MusicalTime.maximumTick else {
                throw AgentError.invalid("That is past the end of the song.")
            }
            return (1...times).map { copy in
                .placeClip(track: target.id, id: PlacementID(), clip: clip.id, start: start + Tick(copy) * length)
            }

        case let .automate(reference, name, fromBar, toBar, from, to, curve):
            let address = try parameter(name, on: reference, in: project)
            guard let descriptor = project.descriptor(for: address) else {
                throw AgentError.invalid("\"\(name)\" cannot be automated on \(reference).")
            }
            let barTicks = MusicalTime.ticksPerBar(project.timeSignature)
            let lastBar = Int(MusicalTime.maximumTick / barTicks)
            guard fromBar >= 1, toBar > fromBar, toBar <= lastBar else {
                throw AgentError.invalid("A movement runs from one bar to a later one, both between 1 and \(lastBar).")
            }
            let range = descriptor.range
            for value in [from, to] where !(value.isFinite && range.contains(value)) {
                throw AgentError.invalid("\(descriptor.title) goes from \(format(range.lowerBound)) to \(format(range.upperBound)), not \(format(value)).")
            }
            guard curve.isFinite, AutomationPoint.curveRange.contains(curve) else {
                throw AgentError.invalid("A curve is between -1 and 1; 0 is straight.")
            }
            let start = Tick(fromBar - 1) * barTicks, end = Tick(toBar - 1) * barTicks
            let kept = (project.automation(for: address)?.points ?? []).filter { $0.tick < start || $0.tick > end }
            let points = (kept + [AutomationPoint(tick: start, value: from, curve: curve),
                                  AutomationPoint(tick: end, value: to)]).sorted { $0.tick < $1.tick }
            return [.setAutomation(address, points: points)]
        }
    }

    /// A parameter by its plain name on a track or the master: volume, pan, or one of the synth's
    /// (cutoff, resonance …).
    public static func parameter(_ name: String, on reference: String, in project: Project) throws -> ParameterAddress {
        let key = name.lowercased().filter(\.isLetter)
        if reference.lowercased() == "master" {
            switch key {
            case "volume", "level", "fader", "gain": return ParameterAddress(.master, .volume)
            case "pan": return ParameterAddress(.master, .pan)
            default: throw AgentError.invalid("The master has volume and pan.")
            }
        }
        let target = try track(reference, in: project)
        switch key {
        case "volume", "fader", "gain": return .volume(target.id)
        case "pan", "panning": return .pan(target.id)
        default: break
        }
        let aliases = ["filter": "cutoff", "filtercutoff": "cutoff", "res": "resonance", "envelope": "filterenvelope"]
        let wanted = aliases[key] ?? key
        if target.kind == .instrument, target.instrument.device == .synth,
           let synth = SynthParameter.all.first(where: { $0.title.lowercased().filter(\.isLetter) == wanted }) {
            return ParameterAddress(.track(target.id), synth.key)
        }
        let names = ["volume", "pan"] + (target.instrument.device == .synth && target.kind == .instrument
                                          ? SynthParameter.all.map { $0.title.lowercased() } : [])
        throw AgentError.invalid("Track \"\(target.name)\" has no parameter \"\(name)\". It has: \(names.joined(separator: ", ")).")
    }

    /// A standard effect by its title or a common word for it.
    public static func standardEffect(_ name: String) throws -> StandardEffect {
        let key = name.lowercased().filter(\.isLetter)
        let aliases: [String: StandardEffect] = ["eq": .equalizer, "equalizer": .equalizer, "equaliser": .equalizer,
                                                 "compressor": .compressor, "comp": .compressor,
                                                 "delay": .delay, "echo": .delay,
                                                 "reverb": .reverb, "verb": .reverb, "hall": .reverb, "room": .reverb]
        guard let effect = aliases[key] else {
            throw AgentError.invalid("There is no effect \"\(name)\". Effects: \(StandardEffect.allCases.map(\.title).joined(separator: ", ")).")
        }
        return effect
    }

    /// One line per fact, for the model's context and for the chat: tempo, metre, every track
    /// with its number, kind, sound and the bars where it has clips.
    public static func describe(_ project: Project) -> String {
        let bar = MusicalTime.ticksPerBar(project.timeSignature)
        var lines = ["Song \"\(project.name)\": \(format(project.tempo)) BPM, \(project.timeSignature.numerator)/\(project.timeSignature.denominator)."]
        if project.tracks.isEmpty { lines.append("No tracks yet.") }
        for (index, track) in project.tracks.enumerated() {
            var parts = ["\(index + 1). \(track.name)"]
            switch track.kind {
            case .instrument:
                switch track.instrument.device {
                case .synth: parts.append("synth, sound \(track.instrument.preset)")
                case .drums: parts.append("drums")
                case .sampler: parts.append("sampler")
                case .plugin: parts.append("plugin instrument")
                }
            case .audio: parts.append("audio")
            case .returnTrack: parts.append("return")
            }
            let bars = track.placements.compactMap { placement -> String? in
                guard let clip = track.clips.first(where: { $0.id == placement.clip }) else { return nil }
                let first = placement.start / bar + 1
                let last = (placement.start + Swift.max(clip.length, 1) - 1) / bar + 1
                return first == last ? "bar \(first)" : "bars \(first)–\(last)"
            }
            if !bars.isEmpty { parts.append("clips at " + bars.joined(separator: ", ")) }
            if !track.regions.isEmpty { parts.append("\(track.regions.count) audio regions") }
            let effects = track.inserts.map { StandardEffect(component: $0.plugin)?.title ?? $0.plugin.name }
            if !effects.isEmpty { parts.append("effects " + effects.joined(separator: " → ")) }
            if track.mixer.isMuted { parts.append("muted") }
            if track.mixer.isSoloed { parts.append("soloed") }
            if track.mixer.volumeDB != 0 { parts.append("\(format(track.mixer.volumeDB)) dB") }
            lines.append(parts.joined(separator: ", ") + ".")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Names

    /// A track by number (1-based), exact name, or a name it starts with, ignoring case.
    public static func track(_ reference: String, in project: Project) throws -> Track {
        let wanted = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        let names = project.tracks.map(\.name)
        if let number = Int(wanted), project.tracks.indices.contains(number - 1) {
            return project.tracks[number - 1]
        }
        let exact = project.tracks.filter { $0.name.caseInsensitiveCompare(wanted) == .orderedSame }
        if exact.count == 1, let only = exact.first { return only }
        if exact.count > 1 { throw AgentError.ambiguousTrack(wanted, matches: exact.map(\.name)) }
        let prefix = project.tracks.filter { !wanted.isEmpty && $0.name.lowercased().hasPrefix(wanted.lowercased()) }
        if prefix.count == 1, let only = prefix.first { return only }
        if prefix.count > 1 { throw AgentError.ambiguousTrack(wanted, matches: prefix.map(\.name)) }
        throw AgentError.unknownTrack(wanted, known: names)
    }

    /// A preset's exact name, matched ignoring case.
    public static func preset(_ name: String) throws -> String {
        let wanted = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let preset = InstrumentPreset.all.first(where: { $0.name.caseInsensitiveCompare(wanted) == .orderedSame }) else {
            throw AgentError.invalid("There is no sound \"\(name)\". Sounds: \(InstrumentPreset.all.map(\.name).joined(separator: ", ")).")
        }
        return preset.name
    }

    /// A drum of the kit by name ("kick", "hi-hat", "closed hat"), or a General MIDI number.
    public static func drumPitch(_ name: String) -> Int? {
        let key = name.lowercased().filter(\.isLetter)
        if let number = Int(name.trimmingCharacters(in: .whitespaces)), Note.pitchRange.contains(number) { return number }
        if let lane = DrumLane.standardKit.first(where: { $0.name.lowercased().filter(\.isLetter) == key }) { return lane.pitch }
        let aliases: [String: Int] = ["bassdrum": 36, "bd": 36, "sd": 38, "hat": 42, "hihat": 42, "hh": 42,
                                      "closedhihat": 42, "ch": 42, "openhihat": 46, "oh": 46, "tom": 45,
                                      "cymbal": 49, "cp": 39, "handclap": 39, "rim": 37, "rimshot": 37]
        return aliases[key]
    }

    /// A pitch as a note name — `C4` is middle C, 60; sharps `#`, flats `b` — or a MIDI number.
    public static func pitch(_ name: String) -> Int? {
        let text = name.trimmingCharacters(in: .whitespaces)
        if let number = Int(text) { return Note.pitchRange.contains(number) ? number : nil }
        var characters = Substring(text)
        guard let letter = characters.first?.uppercased(),
              let base = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11][letter] else { return nil }
        characters = characters.dropFirst()
        var semitone = base
        while let accidental = characters.first, "#♯b♭".contains(accidental) {
            semitone += "#♯".contains(accidental) ? 1 : -1
            characters = characters.dropFirst()
        }
        guard let octave = Int(characters) else { return nil }
        let value = (octave + 1) * 12 + semitone
        return Note.pitchRange.contains(value) ? value : nil
    }

    // MARK: - Parsing

    /// Velocity per 16th step, nil for a rest.
    static func pattern(_ steps: String) throws -> [Int?] {
        var hits: [Int?] = []
        for character in steps where !character.isWhitespace && character != "|" {
            switch character {
            case "x", "o", "1": hits.append(StepEditing.normalVelocity)
            case "X", "O": hits.append(StepEditing.accentVelocity)
            case ".", "-", "_", "0": hits.append(nil)
            default: throw AgentError.invalid("A step pattern uses x (hit), X (accent) and . (rest), not \"\(character)\".")
            }
        }
        guard !hits.isEmpty, hits.count <= maximumSteps else {
            throw AgentError.invalid("A step pattern has 1 to \(maximumSteps) steps of a 16th note.")
        }
        return hits
    }

    static func parseNotes(_ text: String, beat: Tick, regionLength: Tick) throws -> [Note] {
        var notes: [Note] = []
        let entries = text.split(whereSeparator: { ",;\n".contains($0) })
        for entry in entries {
            let fields = entry.split(whereSeparator: \.isWhitespace)
            guard fields.count >= 3, fields.count <= 4 else {
                throw AgentError.invalid("A note is \"pitch beat length [velocity]\", like \"C4 1 1\"; got \"\(entry.trimmingCharacters(in: .whitespaces))\".")
            }
            guard let position = Double(fields[1]), position.isFinite, position >= 1,
                  let duration = Double(fields[2]), duration.isFinite, duration > 0 else {
                throw AgentError.invalid("In \"\(entry.trimmingCharacters(in: .whitespaces))\" the beat starts at 1 and the length is more than 0.")
            }
            let velocity = fields.count == 4 ? Int(fields[3]) : 100
            guard let velocity, Note.velocityRange.contains(velocity) else {
                throw AgentError.invalid("A velocity is 1 to 127.")
            }
            // Bounded while still a Double, so no model-written number can overflow a Tick.
            guard position - 1 < Double(regionLength) / Double(beat) else {
                throw AgentError.invalid("Beat \(fields[1]) lies after the end of the region.")
            }
            let start = Tick(((position - 1) * Double(beat)).rounded())
            guard start < regionLength else {
                throw AgentError.invalid("Beat \(fields[1]) lies after the end of the region.")
            }
            let beats = Swift.min(duration, Double(regionLength) / Double(beat))
            let length = Swift.max(1, Swift.min(Tick((beats * Double(beat)).rounded()), regionLength - start))
            for name in fields[0].split(separator: "+") {
                guard let key = pitch(String(name)) else {
                    throw AgentError.invalid("\"\(name)\" is not a note; write C4, F#3, Bb2 or a MIDI number.")
                }
                notes.append(Note(pitch: key, velocity: velocity, start: start, length: length))
            }
        }
        guard !notes.isEmpty else { throw AgentError.invalid("No notes given.") }
        return notes
    }

    /// The clip placed at `bar` on the track, lengthened to `bars` if shorter, or a new one.
    /// Returns the commands that make it so, the clip as it will be, and the region's length.
    private static func region(on track: Track, bar: Int, bars: Int,
                               in project: Project) throws -> (commands: [Command], clip: Clip, length: Tick) {
        guard bar >= 1, bars >= 1, bars <= maximumBars else {
            throw AgentError.invalid("A region starts at bar 1 or later and is 1 to \(maximumBars) bars long.")
        }
        let barTicks = MusicalTime.ticksPerBar(project.timeSignature)
        // Checked before multiplying, so a wild number from the model cannot overflow.
        guard Tick(bar) <= MusicalTime.maximumTick / barTicks else { throw AgentError.invalid("Bar \(bar) is not in the song.") }
        let start = Tick(bar - 1) * barTicks, length = Tick(bars) * barTicks
        guard start + length <= MusicalTime.maximumTick else { throw AgentError.invalid("That is past the end of the song.") }
        if let placement = track.placements.first(where: { $0.start == start }),
           var clip = track.clips.first(where: { $0.id == placement.clip }) {
            guard clip.audio == nil else { throw AgentError.wrongTrack(track.name, reason: "has an audio clip there") }
            var commands: [Command] = []
            if clip.length < length {
                // Lengthening a clip that also plays elsewhere, or that would run into the next
                // clip, changes more than was asked; say so instead.
                let shared = track.placements.contains { $0.clip == clip.id && $0.id != placement.id }
                let blocked = track.placements.contains { $0.start > start && $0.start < start + length }
                if shared || blocked {
                    let have = Swift.max(1, clip.length / barTicks)
                    throw AgentError.wrongTrack(track.name, reason: "has a \(have)-bar clip at bar \(bar) that \(shared ? "plays elsewhere too" : "runs into the next clip") if lengthened; write \(have) bars there, or start at a free bar")
                }
                commands.append(.setClipLength(clip.id, length: length))
                clip.length = length
            }
            return (commands, clip, length)
        }
        let clip = Clip(name: track.instrument.device == .drums ? "Beat" : "\(track.name) Clip", length: length)
        return ([.createClip(track: track.id, id: clip.id, name: clip.name, length: length),
                 .placeClip(track: track.id, id: PlacementID(), clip: clip.id, start: start)], clip, length)
    }

    private static func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }
}
