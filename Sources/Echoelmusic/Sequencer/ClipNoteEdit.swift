// ClipNoteEdit.swift
// Echoelmusic — Sequencer (Phase 3 / MIDI editor, slice M1)
//
// The PURE half of the selected-part note editor: which part may be edited, which of its notes
// the part shows, and the whole-value edits (add one note, remove a set). Foundation-only and
// deterministic — the view (`Studio/PartNoteEditor.swift`) only classifies a tap and hands the
// result to `TimelineStore.setClipNotes`, the one writer and the one undo step.
//
// ⭐ OWNERSHIP, stated once: a MIDI part's notes live in `ClipStore` (`Clip.melody.notes`,
// clip-relative ticks), addressed by `TimelineRegion.clipID`. A part is a WINDOW onto them,
// `[offset, offset + lengthTicks)`. Every function here takes the clip's notes and returns the
// clip's notes — never region-relative ones — so there is no second copy of the content.
//
// ⚠️ THE WINDOW IS THE PLAYER'S. `RegionNoteWindow.windowed` is what `TimelineRegionPlayer`
// plays; the editor shows exactly that and creates only inside it, so a note the player would
// skip is never offered (#416: one windowing rule).

import Foundation

enum ClipNoteEdit {

    /// Why a part's notes cannot be edited here. Each case is one sentence on screen.
    enum Refusal: Equatable, Sendable {
        /// The part names a clip the grid no longer holds.
        case missing
        /// An audio part — its content is a file, not notes.
        case notMIDI
        /// The composer rewrites this clip on every evolve; an edit would be overwritten.
        case composerOwned
        /// A part saved before tick offsets existed: its window needs a tempo to place.
        case legacyOffset

        var sentence: String {
            switch self {
            case .missing: return "This part's notes are missing from the clip grid."
            case .notMIDI: return "This is an audio part — it has no notes to edit."
            case .composerOwned:
                return "The composer rewrites this part as it evolves, so its notes are shown, not edited."
            case .legacyOffset:
                return "This part was saved by an older build; its notes cannot be shown or edited here."
            }
        }
    }

    /// Whether `clip` may be edited through `region`, or why not.
    nonisolated static func refusal(clip: Clip?, region: TimelineRegion) -> Refusal? {
        guard let clip else { return .missing }
        guard clip.kind == .midi else { return .notMIDI }
        guard !clip.composerOwned else { return .composerOwned }
        guard windowOffset(of: region) != nil else { return .legacyOffset }
        return nil
    }

    /// Whether the clip itself (whatever part shows it) accepts note edits — the store's gate.
    nonisolated static func acceptsEdits(_ clip: Clip) -> Bool {
        clip.kind == .midi && !clip.composerOwned
    }

    /// The clip tick where `region`'s window starts, or nil for a LEGACY part (tick twin 0,
    /// seconds offset set) whose window needs the live tempo — `RegionNoteWindow
    /// .effectiveOffsetTicks` is the rule, and it only needs a tempo in that one case.
    nonisolated static func windowOffset(of region: TimelineRegion) -> Int? {
        if region.contentOffsetTicks <= 0, region.contentOffsetSeconds > 0 { return nil }
        // No seconds conversion can happen on this path, so the tempo argument is inert.
        return RegionNoteWindow.effectiveOffsetTicks(of: region, bpm: 120)
    }

    /// The notes the part shows and plays, region-relative (the player's own windowing).
    nonisolated static func visibleNotes(_ clipNotes: [Note], offsetTicks: Int,
                                         lengthTicks: Int) -> [Note] {
        RegionNoteWindow.windowed(notes: clipNotes, offsetTicks: offsetTicks,
                                  lengthTicks: lengthTicks)
    }

    /// Step columns the part spans: `ceil(length / step)`, at least one.
    nonisolated static func stepCount(lengthTicks: Int) -> Int {
        let step = Note.ticksPerStep
        return Swift.max(1, (Swift.max(0, lengthTicks) + step - 1) / step)
    }

    /// Columns the GRID draws: the part's steps, widened when a visible note's rounded start
    /// lands past them. An unquantized note in the last half-step of a part rounds to
    /// `startStep == stepCount` — the player still sounds it, so the grid must still show it
    /// (drawn outside the frame it could be neither seen, selected nor deleted — M1 review).
    /// Creation stays bounded by `adding`, which refuses a step outside the part.
    nonisolated static func columnCount(lengthTicks: Int, visible: [Note]) -> Int {
        let lastStart = visible.map(\.startStep).max() ?? -1
        return Swift.max(stepCount(lengthTicks: lengthTicks), lastStart + 1)
    }

    /// The clip's notes with ONE new note at region-relative `step` and `pitch`: one step long
    /// (shortened to the part's end), velocity 0.8, appended so it draws on top. nil when the
    /// step lies outside the part — nothing the player would skip is created.
    nonisolated static func adding(pitch: Int, step: Int, to clipNotes: [Note],
                                   offsetTicks: Int, lengthTicks: Int,
                                   id: UUID = UUID()) -> (notes: [Note], id: UUID)? {
        guard step >= 0, lengthTicks > 0, (0...127).contains(pitch) else { return nil }
        let relative = step * Note.ticksPerStep
        guard relative < lengthTicks else { return nil }
        let start = Swift.max(0, offsetTicks) + relative
        let length = Swift.min(Note.ticksPerStep, lengthTicks - relative)
        let note = Note(id: id, pitch: pitch, startTick: start, lengthTicks: length)
        return (clipNotes + [note], id)
    }

    /// The clip's notes without `ids`. Order of the survivors is kept.
    nonisolated static func removing(_ ids: Set<UUID>, from clipNotes: [Note]) -> [Note] {
        clipNotes.filter { !ids.contains($0.id) }
    }

    /// Where the rows centre when a part's grid opens: its median pitch, C4 when empty. The
    /// view takes this ONCE and keeps it — recomputing it from the live notes moved the rows
    /// under the finger after every add, delete and undo, so a second tap on the note just
    /// placed created one an octave away (M1 review).
    nonisolated static func centrePitch(of visible: [Note]) -> Int {
        RollFitMath.medianPitch(of: visible.map(\.pitch), fallback: 60)
    }

    /// Rows shown: two octaves around `centre`, moved by whole octaves, kept inside MIDI
    /// 0…127 without shrinking.
    nonisolated static func pitchRange(centre: Int, octaveShift: Int) -> ClosedRange<Int> {
        let span = 24
        let low = Swift.min(Swift.max(0, centre - span / 2 + octaveShift * 12), 127 - span)
        return low...(low + span)
    }
}
