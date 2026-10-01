// SongMIDIExport.swift
// Echoel — the whole SONG as a Standard MIDI File: every MIDI track of the timeline, each note
// where the song plays it (Workstation redesign B4, founder 2026-10-01 — „Gestalte alles so um,
// dass ich Echoelmusic als Workstation ernsthaft vertreten kann").
//
// WHY: the only MIDI export until B4 was the instrument's TAKE (`exportMIDI()` in the studio):
// one melody, N bars, the composer's loop. A workstation hands a DAW the ARRANGEMENT — every
// track, every part, at its place in the song. This file decides which notes that is.
//
// ⭐ IT ADDS NO SECOND RULE ABOUT WHAT SOUNDS. Three decisions the player already owns are ASKED,
// never restated (#416):
//   · which tracks are MIDI tracks — `TimelineDocument.midiLaneIDs` (non-bio `.midi` lanes);
//   · which notes a part holds — `TimelineRegionPlayer.executableNotes(of:in:bpm:)`, the window
//     the loader and the Play predicate share (trim-in, region end, the legacy seconds offset);
//   · which part wins where parts overlap — `TimelineScheduling.activeRegion`, the ONE definition
//     of overlap precedence (#1440). A note is written only where its own part is the winner at
//     the note's start, and it is cut where another part takes the track over.
// ⚠️ THE ONE PLACE THIS IS FINER THAN THE PLAYER, said so it is not mistaken for a disagreement:
// the transport asks `activeRegion` on its 16th-step grid, this file at the note's own tick. For
// parts that start and end on the grid (everything the editor places) the two answers are the
// same; for an off-grid boundary the file is exact where the transport rounds to the step.
//
// What the file does NOT carry, and the door's hint says so: a track's level, pan, Mute and Solo
// (mix decisions the DAW makes again), the sound of each voice (a General MIDI player chooses its
// own), audio and bio tracks. Muted tracks ARE written — the DAW is where they are unmuted.
//
// Foundation-only and deterministic: the byte layout lives in `MIDIFileExporter.exportSong`.

import Foundation

public enum SongMIDIExport {

    /// One MIDI track of the song: its name, its channel (0-based) and its notes in SONG ticks
    /// (the timeline's tick space, `Note.ticksPerQuarter` per quarter — the file's own division).
    public struct Track: Equatable, Sendable {
        public let name: String
        public let channel: UInt8
        public let notes: [Note]

        public init(name: String, channel: UInt8, notes: [Note]) {
            self.name = name
            self.channel = channel
            self.notes = notes
        }
    }

    /// The channels the tracks take, in track order: 1–16 without 10, which General MIDI reserves
    /// for percussion — a melodic track written there would open as a drum kit. The 16th MIDI
    /// track and later share a channel with an earlier one (the file stays valid; the DAW splits
    /// tracks, not channels).
    public static let channels: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15]

    /// Every MIDI track of `document`, in track order, with the notes the song plays on it. A
    /// track with no notes is still written, named and empty, so the DAW sees the song's layout.
    public static func tracks(of document: TimelineDocument, clip: (UUID) -> Clip?,
                              bpm: Double) -> [Track] {
        var result: [Track] = []
        for (index, laneID) in document.midiLaneIDs.enumerated() {
            guard let lane = document.lanes.first(where: { $0.id == laneID }) else { continue }
            result.append(Track(name: lane.name, channel: channels[index % channels.count],
                                notes: songNotes(of: laneID, in: document, clip: clip, bpm: bpm)))
        }
        return result
    }

    /// The notes one MIDI track plays across the whole song, at song ticks, sorted by start then
    /// pitch. Each part contributes its executable notes; a note is kept only where its part WINS
    /// the track at the note's start (`activeRegion`), and it ends where another part takes over.
    public static func songNotes(of laneID: UUID, in document: TimelineDocument,
                                 clip: (UUID) -> Clip?, bpm: Double) -> [Note] {
        let regions = document.regions.filter { $0.laneID == laneID }
        // The winner can only change where a part starts or ends — the same fact
        // `TimelineScheduling.candidateSampleTicks` is built on — so those are the only cut points.
        let edges = Set(regions.flatMap { [$0.startTick, $0.endTick] }).sorted()
        var notes: [Note] = []
        for region in regions {
            guard let content = clip(region.clipID) else { continue }
            for windowed in TimelineRegionPlayer.executableNotes(of: content, in: region, bpm: bpm) {
                let start = region.startTick + windowed.startTick
                guard wins(region, laneID: laneID, at: start, in: document) else { continue }
                let end = start + windowed.lengthTicks
                let cut = edges.first { $0 > start && $0 < end
                    && !wins(region, laneID: laneID, at: $0, in: document) } ?? end
                var placed = windowed
                placed.startTick = start
                placed.lengthTicks = Swift.max(1, cut - start)
                notes.append(placed)
            }
        }
        return notes.sorted { ($0.startTick, $0.pitch) < ($1.startTick, $1.pitch) }
    }

    /// Whether the song holds at least one note to write — the door's enabled state. Asks the
    /// same two questions as `songNotes` and stops at the first note, so the door costs little to
    /// draw on a long song.
    public static func hasNotes(_ document: TimelineDocument, clip: (UUID) -> Clip?,
                                bpm: Double) -> Bool {
        for laneID in document.midiLaneIDs {
            for region in document.regions where region.laneID == laneID {
                guard let content = clip(region.clipID) else { continue }
                for windowed in TimelineRegionPlayer.executableNotes(of: content, in: region, bpm: bpm)
                where wins(region, laneID: laneID, at: region.startTick + windowed.startTick, in: document) {
                    return true
                }
            }
        }
        return false
    }

    /// The song as Standard MIDI File bytes: a conductor track (tempo, 4/4, key, name) plus one
    /// track per MIDI track. Every track ends at the song's last whole bar
    /// (`TimelineRegionPlayer.loopTicks` — the loop point the player uses), so the file spans the
    /// song in the DAW exactly as it does here.
    public static func file(of document: TimelineDocument, clip: (UUID) -> Clip?, bpm: Double,
                            keyRootPitchClass: Int, keyIsMinor: Bool) -> Data {
        MIDIFileExporter.exportSong(tracks: tracks(of: document, clip: clip, bpm: bpm),
                                    tempo: bpm,
                                    endTick: TimelineRegionPlayer.loopTicks(for: document),
                                    keyRootPitchClass: keyRootPitchClass, keyIsMinor: keyIsMinor)
    }

    /// Whether `region` is the part the track plays at `tick` — overlap precedence asked, never
    /// re-derived (#1440).
    private static func wins(_ region: TimelineRegion, laneID: UUID, at tick: Int,
                             in document: TimelineDocument) -> Bool {
        TimelineScheduling.activeRegion(in: document, laneID: laneID, at: tick)?.id == region.id
    }
}
