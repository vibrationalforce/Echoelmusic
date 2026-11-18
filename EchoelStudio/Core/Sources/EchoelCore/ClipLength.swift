import Foundation

/// A note clip's length, chosen in its editor (2026-11-18). Until then nothing on the surface set
/// the length of a drum or synth clip: a new clip was one bar (a drum track's) or four, and
/// sixteen bars took a clip placed again and again in Arrange, by doors with no word on them.
/// Pure: it returns the commands, and the editor performs them as one undo step.
public enum ClipLength {
    /// The lengths the editor offers, in bars of the clip's own meter.
    public static let choices: [Int] = [1, 2, 4, 8, 16]

    /// Why a clip cannot take a length.
    public enum Refusal: Error, Equatable, Sendable {
        case audio
        case runsIntoNextClip
        case tooLong

        /// One sentence for the editor's menu.
        public var text: String {
            switch self {
            case .audio: "An audio clip's length is set in Session."
            case .runsIntoNextClip: "Longer would run into the next clip on this track."
            case .tooLong: "That is longer than a song can hold."
            }
        }
    }

    /// `bars` bars of the clip's meter, from its start.
    public static func ticks(bars: Int, of clip: ClipID, in project: Project) -> Tick {
        Arranging.ticks(movingBars: Int64(bars), from: 0, meter: project.clipMeter(clip))
    }

    /// The clip's length in whole bars of its meter; nil when it ends inside a bar.
    public static func bars(of clip: Clip, in project: Project) -> Int? {
        choices.first { ticks(bars: $0, of: clip.id, in: project) == clip.length }
            ?? wholeBars(of: clip, in: project)
    }

    private static func wholeBars(of clip: Clip, in project: Project) -> Int? {
        let meter = project.clipMeter(clip.id)
        let count = meter.bar(at: clip.length)
        guard count > 0, count <= Int64(Int.max), meter.tick(ofBar: count) == clip.length else { return nil }
        return Int(count)
    }

    /// The commands that make `clip` `bars` bars long. Longer and `repeating`, its notes and
    /// controller changes repeat after one another until the new end, so a one-bar beat becomes
    /// sixteen bars of that beat; a note that rang past the old end — where playback cut it — is
    /// cut there in every copy and in the original, so the repeat sounds as the clip did. Longer
    /// and not repeating, the new bars are empty. Shorter drops what starts past the new end
    /// (`Command.setClipLength`). Empty when the clip has that length.
    public static func commands(for clip: ClipID, bars: Int, repeating: Bool,
                                in project: Project) -> Result<[Command], Refusal> {
        guard let location = project.clipLocation(clip) else { return .success([]) }
        let track = project.tracks[location.track]
        let held = track.clips[location.clip]
        guard held.audio == nil else { return .failure(.audio) }
        let length = ticks(bars: bars, of: clip, in: project)
        guard bars > 0, length > 0, length <= MusicalTime.maximumTick else { return .failure(.tooLong) }
        guard length != held.length else { return .success([]) }
        if length > held.length {
            // Each place the clip plays must have room up to the new end: a longer clip would
            // otherwise sound over the clip that follows it.
            for placement in track.placements where placement.clip == clip {
                guard placement.start <= MusicalTime.maximumTick - length else { return .failure(.tooLong) }
                let end = placement.start + length
                let blocked = track.placements.contains { $0.id != placement.id && $0.start > placement.start && $0.start < end }
                if blocked { return .failure(.runsIntoNextClip) }
            }
        }
        var steps: [Command] = [.setClipLength(clip, length: length)]
        guard repeating, length > held.length else { return .success(steps) }
        // As heard: a note sounded only to the old end (`PlaybackPlan` cuts it there).
        func heard(_ note: Note) -> Tick { Swift.min(note.length, held.length - note.start) }
        let cut = held.notes.filter { heard($0) < $0.length }.map { note -> Note in
            var shortened = note
            shortened.length = heard(note)
            return shortened
        }
        var notes: [Note] = []
        var controls: [ControlChange] = []
        var offset = held.length
        while offset < length {
            notes += held.notes.compactMap { note in
                let start = note.start + offset
                return start < length ? Note(pitch: note.pitch, velocity: note.velocity, start: start, length: heard(note)) : nil
            }
            controls += held.controls.compactMap { change in
                let start = change.start + offset
                return start < length ? ControlChange(kind: change.kind, start: start, value: change.value) : nil
            }
            offset += held.length
        }
        if !cut.isEmpty { steps.append(.updateNotes(clip, cut)) }
        if !notes.isEmpty { steps.append(.addNotes(clip, notes)) }
        if !controls.isEmpty { steps.append(.setControls(clip, held.controls + controls)) }
        return .success(steps)
    }
}
