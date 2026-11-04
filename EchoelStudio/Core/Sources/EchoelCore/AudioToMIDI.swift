import Foundation

/// One note heard in an audio region (A2M), as the app hands it over from EchoelDSP's
/// `NoteTranscriber`: seconds from the region's first frame, its fundamental in hertz and a
/// velocity. Core does not know the transcriber; this is the plain result it reads.
public struct HeardNote: Equatable, Sendable {
    public var start: Double
    public var length: Double
    public var hertz: Double
    public var velocity: Int

    public init(start: Double, length: Double, hertz: Double, velocity: Int) {
        self.start = start
        self.length = length
        self.hertz = hertz
        self.velocity = velocity
    }
}

/// Convert to MIDI (A2M, 2026-11-04): the notes heard in an audio region become a MIDI clip at the
/// region's place on the timeline, on a new instrument track or a chosen one — through the one door,
/// as ONE undo step (`ProjectStore.perform(_:title:)`). Pure: the hearing happens in the app, off
/// the main thread; this turns seconds into ticks over the song's tempo map (or the region's warp),
/// optionally onto the magnet's grid and into the song's key, and builds the commands. Monophonic:
/// one voice in, one voice out — a later note cuts the one before it.
public enum AudioToMIDI {
    /// What the musician chose: the grid the notes land on (`.off` keeps them where they were
    /// heard) and whether their pitches move into the song's key and scale.
    public struct Options: Equatable, Sendable {
        public var snap: SnapGrid
        public var snapsToKey: Bool

        public init(snap: SnapGrid = .off, snapsToKey: Bool = false) {
            self.snap = snap
            self.snapsToKey = snapsToKey
        }
    }

    /// Where the clip goes: a new instrument track (inserted right after the region's track) or an
    /// instrument track already in the song.
    public enum Destination: Equatable, Sendable {
        case newTrack(TrackID)
        case track(TrackID)
    }

    /// The title of the undo step.
    public static let title = "Convert to MIDI"

    /// The MIDI pitch of `hertz` at the song's concert pitch, in 0 … 127; nil for no pitch.
    public static func pitch(ofHertz hertz: Double, concertPitch: Double = 440) -> Int? {
        guard hertz.isFinite, hertz > 0 else { return nil }
        let reference = concertPitch.isFinite && concertPitch > 0 ? concertPitch : 440
        let value = 69 + 12 * Foundation.log2(hertz / reference)
        guard value.isFinite else { return nil }
        return Swift.min(Swift.max(Int(value.rounded()), Note.pitchRange.lowerBound), Note.pitchRange.upperBound)
    }

    /// The clip for `heard` in `region` of `project`: its notes, in ticks from the region's start,
    /// and its length — the region's span on the timeline. Notes outside the region, without a
    /// pitch or with a non-finite number are dropped; each note ends where the next begins at the
    /// latest, so the clip stays one voice. Nil when the song no longer has the region's file.
    public static func clip(heard: [HeardNote], region: AudioRegion, in project: Project,
                            options: Options = Options()) -> (notes: [Note], length: Tick)? {
        guard let file = project.mediaFile(region.media), file.sampleRate > 0, file.sampleRate.isFinite,
              let endPosition = project.position(of: region, atFileFrames: Double(region.length)),
              endPosition.isFinite else { return nil }
        let regionEnd = MusicalTime.integer(endPosition.rounded())
        let length = Swift.max(1, regionEnd - region.start)
        let meter = project.meterMap
        func tick(_ seconds: Double) -> Tick? {
            guard let position = project.position(of: region, atFileFrames: seconds * file.sampleRate),
                  position.isFinite else { return nil }
            return MusicalTime.integer(position.rounded()) - region.start
        }
        func snapped(_ offset: Tick) -> Tick {
            guard options.snap != .off else { return offset }
            return options.snap.nearest(region.start + offset, meter: meter) - region.start
        }
        let regionSeconds = Double(region.length) / file.sampleRate
        var notes: [Note] = []
        for note in heard.sorted(by: { $0.start < $1.start }) {
            guard note.start.isFinite, note.length.isFinite, note.length > 0, note.start < regionSeconds,
                  var pitch = pitch(ofHertz: note.hertz, concertPitch: project.context.concertPitch),
                  let from = tick(Swift.max(0, note.start)),
                  let to = tick(Swift.min(regionSeconds, note.start + note.length)) else { continue }
            if options.snapsToKey { pitch = project.context.nearest(pitch) }
            var start = snapped(from)
            var stop = snapped(to)
            if stop <= start {
                // A note shorter than the grid keeps one step of it.
                let step = options.snap.step(at: region.start + start, meter: meter) ?? 0
                stop = start + Swift.max(1, step, to - from)
            }
            start = Swift.min(Swift.max(0, start), length - 1)
            stop = Swift.min(stop, length)
            guard stop > start else { continue }
            let velocity = Swift.min(Swift.max(note.velocity, Note.velocityRange.lowerBound), Note.velocityRange.upperBound)
            notes.append(Note(id: NoteID(), pitch: pitch, velocity: velocity, start: start, length: stop - start))
        }
        // One voice: of two notes on the same tick the first heard stays, and a note ends where
        // the next begins.
        var voice: [Note] = []
        for note in notes {
            if let last = voice.last, last.start == note.start { continue }
            if let last = voice.last, last.start + last.length > note.start {
                voice[voice.count - 1].length = note.start - last.start
            }
            voice.append(note)
        }
        return (voice, length)
    }

    /// The commands of Convert to MIDI: the new track if one is asked for, the clip named after
    /// the file, its notes and its placement at the region's start. Nil when nothing was heard, the
    /// region or its file is gone, or the destination is not an instrument track. Perform them as
    /// one step with `title`.
    public static func commands(heard: [HeardNote], region regionID: RegionID, on trackID: TrackID,
                                in project: Project, destination: Destination, options: Options = Options(),
                                clip clipID: ClipID = ClipID(), placement: PlacementID = PlacementID()) -> [Command]? {
        guard let source = project.track(trackID), let region = source.regions.first(where: { $0.id == regionID }),
              let file = project.mediaFile(region.media),
              let made = clip(heard: heard, region: region, in: project, options: options),
              !made.notes.isEmpty else { return nil }
        let trimmed = file.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = String((trimmed.isEmpty ? "Audio" : trimmed).prefix(Names.maximumLength))
        var commands: [Command] = []
        let target: TrackID
        switch destination {
        case .newTrack(let id):
            guard project.canAddTrack(.instrument) else { return nil }
            let trackName = String("\(name) MIDI".prefix(Names.maximumLength))
            let index = project.trackIndex(trackID).map { $0 + 1 }
            commands.append(.addTrack(id: id, name: trackName, kind: .instrument, index: index))
            target = id
        case .track(let id):
            guard project.track(id)?.kind == .instrument else { return nil }
            target = id
        }
        commands.append(.createClip(track: target, id: clipID, name: name, length: made.length))
        commands.append(.addNotes(clipID, made.notes))
        commands.append(.placeClip(track: target, id: placement, clip: clipID, start: region.start))
        return commands
    }
}
