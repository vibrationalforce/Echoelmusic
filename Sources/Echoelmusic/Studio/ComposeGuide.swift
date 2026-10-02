import Foundation

/// DMMW Phase 1 (founder 2026-09-29): "Die Oberfläche muss nach dem Start sofort zeigen, wie man
/// ein Stück erstellt. Keine leeren Platzhalter ohne Aktion." — the five steps from an empty song
/// to a saved piece, read off the song itself.
///
/// ⭐ IT OWNS NO STATE AND WRITES NOTHING. Every step is DERIVED from facts that already have one
/// owner — the document (`TimelineStore`), the clip grid (`ClipStore`), the engine's own start
/// guard (`TimelineRegionPlayer.canPlay`, asked by the Workstation's `songCanStart()`) and the
/// transport's running truth (`ProjectTransport.isRunning` — the song OR the one clock, the same
/// answer the transport row and the header show; review of 09d35f56e, MED-3). A guide that kept
/// its own "step 3 done" flag would be a second answer to "does this part have notes?", and the
/// first Undo would make the two disagree.
///
/// ⭐ EVERY STEP'S ACTION IS AN EXISTING PATH, never a new one: Add MIDI Track
/// (`MIDIImport.addMIDITrack`), New MIDI Part (`MIDIImport.addEmptyPart`), selecting the part the
/// note editor opens on (`WorkstationSelection.selectRegion`), the Workstation's one Play and
/// the app's ONE Stop (`startTimeline` / `ProjectTransport.stop`), and the Studio's Save alert
/// through the chrome door. The guide is a map of doors that already exist, in the order a
/// piece needs them.
///
/// ⚠️ STEP 3 SAYS "WRITE", NOT "RECORD", on purpose: the guide's track is the import's track, and
/// record-arm is offered on a rack track only (`RecordTake.canArm` — `.laneSynth` role), which that
/// track usually is not. A step promising "or record" would name a control its own part lacks.
///
/// ⚠️ THE MIDI TRACK IS THE IMPORT'S TRACK (`MIDIImport.firstImportableMIDILane`, the roll lane)
/// and "a part" is a USER part — composer-owned clips are excluded exactly as
/// `SessionSaveOpen.songHasUserParts` excludes them (#416): the generated take is the
/// instrument's, and it must not tick off "you wrote notes".
enum ComposeGuide {

    enum Step: Int, CaseIterable, Identifiable, Sendable {
        case track = 1, part, notes, play, save
        var id: Int { rawValue }
    }

    /// What a step shows. `next` is the ONE step to do now; `waiting` names a step whose
    /// prerequisite is missing — shown, never hidden, and disabled with the reason spoken.
    enum State: Equatable, Sendable {
        case done, next, ready, waiting
    }

    /// The facts the five steps are read from — each one owned elsewhere (see the type header).
    struct Facts: Equatable, Sendable {
        var hasMIDITrack: Bool
        var hasPart: Bool
        var hasNotes: Bool
        var canPlay: Bool
        var isPlaying: Bool
        var canSave: Bool
    }

    // MARK: - Reading the song

    /// The user's MIDI parts on the import's track, earliest first. A region whose clip is
    /// missing, not MIDI, or composer-owned is not the user's part.
    static func userParts(document: TimelineDocument, clips: [Clip]) -> [UserPart] {
        guard let lane = MIDIImport.firstImportableMIDILane(in: document) else { return [] }
        var byID: [UUID: Clip] = [:]
        for clip in clips where byID[clip.id] == nil { byID[clip.id] = clip }
        let onLane: [TimelineRegion] = document.regions
            .filter { $0.laneID == lane.id }
            .sorted { $0.startTick < $1.startTick }
        var parts: [UserPart] = []
        for region in onLane {
            guard let clip = byID[region.clipID], clip.kind == .midi, !clip.composerOwned else { continue }
            parts.append(UserPart(region: region, clip: clip))
        }
        return parts
    }

    /// One user part and the clip it plays.
    struct UserPart: Sendable {
        let region: TimelineRegion
        let clip: Clip

        /// The notes the part holds — the note editor's own count (`ClipNoteEdit.noteCount`,
        /// the grid's windowing), so the guide and the "Notes" switch never disagree.
        var noteCount: Int { ClipNoteEdit.noteCount(clip: clip, region: region) ?? 0 }
    }

    static func facts(document: TimelineDocument, clips: [Clip],
                      canPlay: Bool, isPlaying: Bool) -> Facts {
        let parts = userParts(document: document, clips: clips)
        let hasNotes = parts.contains { $0.noteCount > 0 }
        return Facts(hasMIDITrack: MIDIImport.firstImportableMIDILane(in: document) != nil,
                     hasPart: !parts.isEmpty,
                     hasNotes: hasNotes,
                     canPlay: canPlay,
                     isPlaying: isPlaying,
                     canSave: SessionSaveOpen.songHasUserParts(document, clips: clips))
    }

    /// The part "Write notes" opens: the first one still empty, else the first one. nil when
    /// there is no user part — the step is then `waiting`, never a silent no-op.
    static func partToWrite(document: TimelineDocument, clips: [Clip]) -> UUID? {
        let parts = userParts(document: document, clips: clips)
        let empty = parts.first { $0.noteCount == 0 }
        return (empty ?? parts.first)?.region.id
    }

    // MARK: - The steps

    static func state(of step: Step, _ facts: Facts) -> State {
        let base = baseState(of: step, facts)
        guard base == .ready else { return base }
        // The first step that is ready and not done is THE next step; later ready steps stay
        // ready (still tappable — adding a second track or part is legitimate work).
        let firstReady = Step.allCases.first { baseState(of: $0, facts) == .ready }
        return firstReady == step ? .next : .ready
    }

    private static func baseState(of step: Step, _ f: Facts) -> State {
        switch step {
        case .track: return f.hasMIDITrack ? .done : .ready
        case .part:  return !f.hasMIDITrack ? .waiting : (f.hasPart ? .done : .ready)
        case .notes: return !f.hasPart ? .waiting : (f.hasNotes ? .done : .ready)
        case .play:  return f.isPlaying ? .done : (f.canPlay ? .ready : .waiting)
        // Saving is never "done": nothing here can know the song has not changed since.
        case .save:  return f.canSave ? .ready : .waiting
        }
    }

    /// How many of the five steps are done.
    static func doneCount(_ facts: Facts) -> Int {
        Step.allCases.filter { state(of: $0, facts) == .done }.count
    }

    /// The step to do now, if any — what the header names.
    static func nextStep(_ facts: Facts) -> Step? {
        Step.allCases.first { state(of: $0, facts) == .next }
    }

    /// The rows the OPEN card draws (founder 2026-10-01, "Viele Bereiche sind zu groß"): every
    /// step up to the next one that is not done — normally ONE row, the step to do now. A step
    /// BEFORE it that is waiting stays in view, so its reason is still said: a written part the
    /// engine cannot play (#1440) makes Play wait while Save is next, and without the Play row
    /// "Nothing in the piece can play yet" would be said nowhere (review of c672c2adf, LOW). No
    /// done step and no later step is drawn. With no next step, all five — so the header's
    /// "Every step is available below." stays true.
    static func shownSteps(_ facts: Facts) -> [Step] {
        guard let next = nextStep(facts) else { return Step.allCases }
        return Step.allCases.filter { $0.rawValue <= next.rawValue && state(of: $0, facts) != .done }
    }

    /// Whether tapping the row does something the row's own words promise.
    /// ⚠️ A DONE "Add a MIDI track" is NOT actionable (review of c672c2adf, MED): tapping it
    /// would add a SECOND MIDI track, and step 2 always lands on the FIRST one — a checked row
    /// that silently does something else. A done "Add a part" stays actionable because its
    /// detail line says "another" part, and a done "Write notes" re-opens a part's notes.
    /// "Play" while playing is the Stop, so it stays actionable too.
    static func isActionable(_ step: Step, _ facts: Facts) -> Bool {
        let state = state(of: step, facts)
        if state == .waiting { return false }
        if step == .track, state == .done { return false }
        return true
    }

    static func title(_ step: Step, _ facts: Facts) -> String {
        switch step {
        case .track: return String(localized: "Add a MIDI track")
        case .part:  return String(localized: "Add a part")
        case .notes: return String(localized: "Write notes")
        case .play:  return facts.isPlaying ? String(localized: "Stop all playback") : String(localized: "Play the piece")
        case .save:  return String(localized: "Save the piece")
        }
    }

    /// One visible line under the title: what the tap does, or what it is waiting for.
    static func detail(_ step: Step, _ facts: Facts) -> String {
        let state = state(of: step, facts)
        if state == .waiting { return waitingReason(step, facts) }
        switch step {
        case .track: return state == .done ? String(localized: "Your piece has its MIDI track.")
                                           : String(localized: "An instrument track for the notes of your piece.")
        case .part:  return state == .done ? String(localized: "Adds another empty four-bar part after the last one.")
                                           : String(localized: "An empty four-bar part on that track.")
        case .notes: return String(localized: "Opens the part's notes on its track's Notes page.")
        case .play:  return facts.isPlaying ? String(localized: "Stops the piece, the instrument and the pulse reading.")
                                            : String(localized: "Plays the piece from the top.")
        case .save:  return String(localized: "Names the piece and saves it. Open brings it back.")
        }
    }

    /// What the card says after "Write notes": where the grid it just opened sits, because the
    /// detail area is below the canvas in portrait (beside it in landscape) and may be off screen.
    static var notesOpenedNote: String {
        String(localized: "The part's notes are open on the track's Notes page. Tap a cell to write a note.")
    }

    private static func waitingReason(_ step: Step, _ facts: Facts) -> String {
        switch step {
        case .track: return ""
        case .part:  return String(localized: "Add a MIDI track first.")
        case .notes: return String(localized: "Add a part first.")
        // Review of c672c2adf (LOW): `hasNotes` and the engine's `canPlay` can disagree (a
        // written part covered by a later one, #1440) — then "write notes" would be false.
        case .play:
            if facts.hasNotes { return String(localized: "Nothing in the piece can play yet — no part with notes is heard.") }
            return facts.hasPart ? String(localized: "Write notes into a part first.") : String(localized: "Add a part with notes first.")
        case .save:  return String(localized: "Add a part first.")
        }
    }

    /// "Step 3 of 5" — a step's place among the five, in ONE spelling (#416): the row's spoken
    /// label reads it, and so does the card's position line (founder 2026-10-01: the open card
    /// shows ONE step, so the line says which one). It names a step, never a done-count — see
    /// `headerDetail` for why a count is the wrong figure here.
    static func stepPosition(_ step: Step) -> String {
        // E4-30: typed steps — one `+` chain of eight operands is what the type-checker cannot bound (Compile Check 3106).
        let number: String = "\(step.rawValue)"
        let total: String = "\(Step.allCases.count)"
        let position: String = String(localized: "Step ") + number + String(localized: " of ") + total
        return position
    }

    /// The whole row, spoken: position, title, state. The state is words, never only a colour
    /// or an icon.
    static func spokenLabel(_ step: Step, _ facts: Facts) -> String {
        let status: String
        switch state(of: step, facts) {
        case .done:    status = step == .play ? String(localized: "playing") : String(localized: "done")
        case .next:    status = String(localized: "next step")
        case .ready:   status = String(localized: "available")
        case .waiting: status = String(localized: "not yet available")
        }
        let position: String = stepPosition(step)
        let rest: String = title(step, facts) + ", " + status
        return position + ", " + rest
    }

    /// Whether the card arrives OPEN (Workstation redesign A6, founder 2026-10-01). An empty or
    /// note-less song opens it — that is the beginner's plate the guide exists for. A song that
    /// already has notes when the piece opens arrives folded: the step to do now is still one tap
    /// away under a header that names it. Read ONCE, when the card is created — the
    /// card never folds itself while the player works (review of c672c2adf).
    static func opensExpanded(_ facts: Facts) -> Bool {
        !facts.hasNotes
    }

    /// The header's line under "Create a piece": the step to do now, never a done-count.
    /// ⛔ It was "N of 5 steps done" (review of c672c2adf): Save can never be done and Play is
    /// done only while playing, so the count peaked at 4 and fell back on Stop — a progress
    /// figure that goes backwards reads as lost work.
    static func headerDetail(_ facts: Facts) -> String {
        guard let next = nextStep(facts) else { return String(localized: "Every step is available below.") }
        return String(localized: "Next: ") + title(next, facts)
    }

    /// The header, spoken.
    static func headerLabel(_ facts: Facts) -> String {
        String(localized: "Create a piece. ") + headerDetail(facts)
    }
}
