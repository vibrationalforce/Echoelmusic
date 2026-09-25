// ClipNoteEdit.swift
// Echoelmusic — Sequencer (Phase 3 / MIDI editor, slice M1)
//
// The PURE half of the selected-part note editor: which part may be edited, which of its notes
// the part shows, and the whole-value edits (add one note, remove a set; since M2 move a set,
// stretch one). Foundation-only and deterministic — the view (`Studio/PartNoteEditor.swift`) only
// classifies a tap or a finished gesture and hands the result to `TimelineStore.setClipNotes`,
// the one writer and the one undo step.
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

    /// The clip's notes with `ids` moved by whole semitones and whole steps (M2) — nil when
    /// nothing changes, so a slide back to the start commits no step. Each start stays inside
    /// the part's window `[offset, offset + length)`, where the player plays it; a note's offset
    /// from the step grid is kept, so an unquantized note moves with its feel intact.
    nonisolated static func moving(_ ids: Set<UUID>, dPitch: Int, dStep: Int, in clipNotes: [Note],
                                   offsetTicks: Int, lengthTicks: Int) -> [Note]? {
        guard !ids.isEmpty, dPitch != 0 || dStep != 0, lengthTicks > 0 else { return nil }
        let first = Swift.max(0, offsetTicks)
        let last = first + lengthTicks - 1
        var changed = false
        let moved = clipNotes.map { note -> Note in
            guard ids.contains(note.id) else { return note }
            var shifted = note
            shifted.pitch = Swift.min(Swift.max(note.pitch + dPitch, 0), 127)
            shifted.startTick = Swift.min(Swift.max(note.startTick + dStep * Note.ticksPerStep, first),
                                          last)
            if shifted != note { changed = true }
            return shifted
        }
        return changed ? moved : nil
    }

    /// The clip's notes with note `id`'s END moved by `dSteps` whole steps (M2) — nil when it is
    /// gone, when `dSteps` is zero, or when nothing changes.
    ///
    /// The end that moves is the one THIS PART DRAWS: a note the part cuts off ends, on screen, at
    /// the part's end, so a shortening moves that end (WYSIWYG — every part playing the clip
    /// hears it, which the editor's hint says). A lengthening stops at the part's end and never
    /// shortens a note that already runs past it. A shortening keeps at least one step (or the
    /// note's own length, if shorter). An unquantized length keeps its offset: 455 ticks + 1 step
    /// is 575, not 600. `NoteGridGesture.resolve` bounds `dSteps` the same way for the preview.
    nonisolated static func resizing(_ id: UUID, bySteps dSteps: Int, in clipNotes: [Note],
                                     offsetTicks: Int, lengthTicks: Int) -> [Note]? {
        guard dSteps != 0, lengthTicks > 0,
              let index = clipNotes.firstIndex(where: { $0.id == id }) else { return nil }
        let note = clipNotes[index]
        let windowEnd = Swift.max(0, offsetTicks) + lengthTicks
        let drawnEnd = Swift.min(note.endTick, windowEnd)
        let newLength: Int
        if dSteps > 0 {
            let end = Swift.min(drawnEnd + dSteps * Note.ticksPerStep, windowEnd)
            newLength = Swift.max(note.lengthTicks, end - note.startTick)
        } else {
            let shortest = Swift.min(note.lengthTicks, Note.ticksPerStep)
            newLength = Swift.max(shortest, drawnEnd + dSteps * Note.ticksPerStep - note.startTick)
        }
        guard newLength != note.lengthTicks else { return nil }
        var resized = clipNotes
        resized[index].lengthTicks = newLength
        return resized
    }

    // MARK: - M3: operations on a selection
    //
    // Each takes the ids to act on and the CLIP's notes, returns the clip's notes whole, and
    // returns nil when nothing would change — so a button that would do nothing commits no step.
    // Which ids: `targets` — the on-screen selection, or every note the part shows when nothing
    // is selected (the usual editor rule, stated once here and not in the view).

    /// The ids an M3 operation acts on. NOTHING selected → every note of the part. Something
    /// selected → only the selected notes ON SCREEN (`onScreen`), and possibly none: a selection
    /// that scrolled or moved off the rows shown must never widen to the whole part (M3 review —
    /// the Delete law, "never removed unseen", for every operation). `selected` is the selection
    /// restricted to notes the part still has, so an id an Undo removed does not count.
    nonisolated static func targets(selected: Set<UUID>, onScreen: Set<UUID>,
                                    visible: [Note]) -> Set<UUID> {
        selected.isEmpty ? Set(visible.map(\.id)) : onScreen.intersection(selected)
    }

    /// `ids` moved by `semitones`, clamped as a GROUP to MIDI 0…127 so the chord keeps its shape.
    nonisolated static func transposing(_ ids: Set<UUID>, by semitones: Int,
                                        in clipNotes: [Note]) -> [Note]? {
        let pitches = clipNotes.filter { ids.contains($0.id) }.map(\.pitch)
        guard let low = pitches.min(), let high = pitches.max() else { return nil }
        let delta = Swift.min(Swift.max(semitones, -low), 127 - high)
        guard delta != 0 else { return nil }
        return clipNotes.map { note in
            guard ids.contains(note.id) else { return note }
            var moved = note
            moved.pitch = note.pitch + delta
            return moved
        }
    }

    /// `ids` with their starts snapped to the nearest sixteenth OF THE PART (the grid the editor
    /// draws), each kept inside the part's window; lengths untouched.
    nonisolated static func quantizing(_ ids: Set<UUID>, in clipNotes: [Note], offsetTicks: Int,
                                       lengthTicks: Int) -> [Note]? {
        guard !ids.isEmpty, lengthTicks > 0 else { return nil }
        let offset = Swift.max(0, offsetTicks)
        let lastStep = stepCount(lengthTicks: lengthTicks) - 1
        var changed = false
        let snapped = clipNotes.map { note -> Note in
            guard ids.contains(note.id) else { return note }
            let relative = note.startTick - offset
            guard relative >= 0, relative < lengthTicks else { return note }
            let step = Swift.min((relative + Note.ticksPerStep / 2) / Note.ticksPerStep, lastStep)
            var moved = note
            moved.startTick = offset + step * Note.ticksPerStep
            if moved.startTick != note.startTick { changed = true }
            return moved
        }
        return changed ? snapped : nil
    }

    /// `ids` set to one velocity (NaN-safe, 0…1); nil when every one already has it.
    nonisolated static func settingVelocity(_ ids: Set<UUID>, to velocity: Float,
                                            in clipNotes: [Note]) -> [Note]? {
        let value = velocity.clamped(to: 0...1)
        var changed = false
        let updated = clipNotes.map { note -> Note in
            guard ids.contains(note.id), note.velocity != value else { return note }
            var loud = note
            loud.velocity = value
            changed = true
            return loud
        }
        return changed ? updated : nil
    }

    /// The mean velocity of `ids` — what the velocity row shows for a mixed selection.
    nonisolated static func meanVelocity(_ ids: Set<UUID>, in clipNotes: [Note]) -> Float? {
        let values = clipNotes.filter { ids.contains($0.id) }.map(\.velocity)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Float(values.count)
    }

    /// `ids` copied once, right after themselves: the copies start one selection-span later
    /// (the span from the first start to the last end, rounded up to whole steps). nil when a
    /// copy would start outside the part — nothing the player would skip is created. The copies
    /// get new ids and are appended, so they draw on top; their ids are returned to select them.
    nonisolated static func duplicating(_ ids: Set<UUID>, in clipNotes: [Note], offsetTicks: Int,
                                        lengthTicks: Int) -> (notes: [Note], ids: Set<UUID>)? {
        let picked = clipNotes.filter { ids.contains($0.id) }
        guard let first = picked.map(\.startTick).min(), let end = picked.map(\.endTick).max(),
              lengthTicks > 0 else { return nil }
        let span = Swift.max(1, (end - first + Note.ticksPerStep - 1) / Note.ticksPerStep)
            * Note.ticksPerStep
        let windowEnd = Swift.max(0, offsetTicks) + lengthTicks
        var copies: [Note] = []
        for note in picked {
            var copy = note
            copy.id = UUID()
            copy.startTick = note.startTick + span
            guard copy.startTick < windowEnd else { return nil }
            copies.append(copy)
        }
        return (clipNotes + copies, Set(copies.map(\.id)))
    }

    // MARK: - M4: operations that know the key
    //
    // The key is `SessionContext.key`, read by the caller and handed in — this file never owns
    // or writes it (`SessionContext` is the one owner of `echoel.keyRoot`/`echoel.keyScale`).

    /// `ids` with each pitch moved to the nearest note of `key` (`MusicalKey.quantize`, lower
    /// wins a tie); nil when every one is already in the key.
    nonisolated static func fittingToKey(_ ids: Set<UUID>, key: MusicalKey,
                                         in clipNotes: [Note]) -> [Note]? {
        var changed = false
        let fitted = clipNotes.map { note -> Note in
            guard ids.contains(note.id) else { return note }
            let pitch = key.quantize(note.pitch)
            guard pitch != note.pitch, (0...127).contains(pitch) else { return note }
            var moved = note
            moved.pitch = pitch
            changed = true
            return moved
        }
        return changed ? fitted : nil
    }

    /// `ids` moved by `degrees` steps OF THE KEY'S SCALE (a diatonic transpose: C→E→G in C major
    /// is one step each, not four semitones). A note outside the key is first fitted to it, so the
    /// result is always in the key. nil when a note would leave MIDI 0…127 — the whole group
    /// refuses rather than folding one note back, which would break the chord's shape — or when
    /// nothing changes.
    nonisolated static func transposingInKey(_ ids: Set<UUID>, by degrees: Int, key: MusicalKey,
                                             in clipNotes: [Note]) -> [Note]? {
        let intervals = key.scale.intervals
        let perOctave = intervals.count
        guard perOctave > 0, degrees != 0, clipNotes.contains(where: { ids.contains($0.id) })
        else { return nil }
        var moved: [Note] = []
        moved.reserveCapacity(clipNotes.count)
        for note in clipNotes {
            guard ids.contains(note.id) else { moved.append(note); continue }
            let relative = key.quantize(note.pitch) - key.root
            let octave = Int((Double(relative) / 12).rounded(.down))
            guard let step = intervals.firstIndex(of: relative - 12 * octave) else { return nil }
            let index = octave * perOctave + step + degrees
            let newOctave = Int((Double(index) / Double(perOctave)).rounded(.down))
            let pitch = key.root + 12 * newOctave + intervals[index - newOctave * perOctave]
            guard (0...127).contains(pitch) else { return nil }
            var copy = note
            copy.pitch = pitch
            moved.append(copy)
        }
        return moved == clipNotes ? nil : moved
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
