// EchoelCommandExecutor.swift
// Echoel — EchoelAI as an operating agent, step 1 (founder order 2026-09-27): the ONE place a
// planned request becomes a change, and the place it is checked.
//
// ⭐ SAME PATHS AS THE BUTTONS. A level goes through `TrackMix.setLevel` (the inspector's Level
// field), a copy through `TrackParts.duplicate` (the part bar's Copy), a taken-back copy through
// `TrackParts.remove` (its Remove). The executor holds no document of its own and draws no second
// timeline: it reads `TimelineStore.document` and `WorkstationSelection` — the canonical owners —
// before each step and again after it.
//
// ⭐ SUCCESS IS REPORTED ONLY AFTER IT IS SEEN. Every mutating step re-reads the store: a level
// must read back as the value asked for, a copy must exist exactly once, on the same track, the
// same clip, starting where the original ends. Anything else is a failure with its reason.
//
// ⭐ ONE REQUEST RUNS ONCE. A request id that already ran returns its stored report, marked
// `replayed`, and changes nothing — a repeated "copy that" never makes two copies. A second
// request while one runs is refused as busy. A plan made against a selection or song that has
// changed since is refused before its first step (the question state), never re-targeted:
// "the selection" is resolved ONCE, from the state the plan was made against, so a tap during
// the request (it yields between steps) cannot move a later step onto another track or part.
// The song's GENERATION is checked again after every suspension between steps: a project opened
// again inside that gap ends the request before its next step (`.projectChanged` on that step, the
// rest not run), and the journal group is stamped with the generation the steps ran in, never the
// one found afterwards (review 5.1). After a final stop no further between-step suspension runs.
// A step that names "the selection" while the plan saw NONE is refused before the first step,
// as a clear error ("No track is selected") — never resolved live when it runs, because live
// would adopt a selection made after the plan, a target the person never saw the agent aim at
// (review repair 2a). The live selection is read in exactly one place: `snapshot()`.
//
// ⭐ THE AGENT'S UNDO IS ITS OWN, AND IT CHECKS. The level is not in the song's history (the store
// keeps mixer moves out of it on purpose), so the agent keeps a journal of exact inverses, one
// group per request. "Take back your last change" restores each value ONLY if it still reads
// what the agent left AND nobody has written that level since (`TimelineStore.laneLevelWrites`,
// counted per write, so the same number entered again by hand is a later decision — review
// repair 2b); a value a person moved since is kept, and the report says so. The agent's OWN later
// writes to that lane — a second change, an Undo — move the journal's marks with them, so they never
// block an earlier entry of its own (review 5.2). The report tells
// three results apart (review repair 2c): taken back now · had already been taken back (the
// song's Undo removed the copy, a card's Undo took the look back) · kept because a person changed
// it since. The song's own Undo button is untouched — a taken-back copy is removed through the
// store, which records that removal as one ordinary song step.
//
// ⭐ A MEDIA LOOK GOES THROUGH THE CARDS' OWN OWNER (step 2b). "Use the colours of this photo" is
// `MediaLookUndo.apply(photo:on:)` — the call the photo card's Apply makes — with the seed that
// card has read and SHOWS; the video likewise. The executor never writes a visual setting itself:
// it hands the owner the defaults and reads the look back to confirm it. One look at a time, as on
// the cards: while one is applied, a second is refused until it is taken back. The agent's Undo
// asks the same owner, only while the look it applied is still the pending one; a setting a person
// moved since is kept, as the card's Undo keeps it.
//
// ⚠️ CANCEL. Steps are instant main-actor writes; a request yields between them. Cancel (or the
// surrounding task's cancellation) ends every step not yet started; a step that has run stays
// done and is reported as done — Undo is the way back, not Cancel.
//
// Main actor only. No model, no file, no network, nothing on the audio thread, no clock.

import Foundation

@MainActor
final class EchoelCommandExecutor {

    /// How many finished requests are remembered for duplicate detection.
    static let rememberedRequests = 64
    /// How many of the agent's own changes Undo can walk back through.
    static let journalDepth = 20

    private enum Inverse {
        /// `write` is the store's write count for that lane right after the agent's write.
        case level(laneID: UUID, before: Float, after: Float, write: Int)
        case removeCopy(TimelineRegion)
        /// The look and the owner's `generation` right after it was recorded — an equal look
        /// applied again by hand is a different generation, and is the person's (review MED-2).
        case mediaLook(MediaSeedApplication, generation: Int)
    }

    private let timeline: TimelineStore
    private let selection: WorkstationSelection
    /// `TimelineRegionPlayer.laneVoiceCapacity` — asked, never assumed (#431: which lanes have a
    /// level depends on it, exactly as it does for the inspector).
    private let voiceCapacity: () -> Int
    /// The one owner of a media look — `MediaLookUndo.shared` in the app, a fresh one in a test.
    private let mediaLooks: MediaLookUndo
    /// Where the visual look lives. Handed to `mediaLooks`, and read back only to confirm.
    private let visualDefaults: UserDefaults
    /// The suspension between two steps. In the app a plain yield; a test hands in what happens in
    /// that gap (a tap, an Open) so the gap is driven, not left to scheduling (review 5.1).
    private let betweenSteps: @MainActor () async -> Void

    /// Each group is stamped with the song generation it was written in. An Open replaces the
    /// whole song and clears the store's own undo for that reason (`replaceDocument`); the agent's
    /// journal follows the same rule — inverses of the song before an Open are not offered against
    /// the song after it, even when that song is the same file opened again (Codex finding 1).
    private var journal: [(generation: Int, entries: [Inverse])] = []
    private var finished: [UUID: (steps: [EchoelCommand], report: EchoelExecutionReport)] = [:]
    private var finishedOrder: [UUID] = []
    private(set) var runningRequest: UUID?
    private var cancelRequested = false

    init(timeline: TimelineStore, selection: WorkstationSelection, voiceCapacity: @escaping () -> Int,
         mediaLooks: MediaLookUndo, visualDefaults: UserDefaults,
         betweenSteps: @escaping @MainActor () async -> Void = { await Task.yield() }) {
        self.timeline = timeline
        self.selection = selection
        self.voiceCapacity = voiceCapacity
        self.mediaLooks = mediaLooks
        self.visualDefaults = visualDefaults
        self.betweenSteps = betweenSteps
    }

    var canUndoAgentChange: Bool {
        pruneJournal()
        return !journal.isEmpty
    }

    /// Drops every journal group written before the current song generation (see `journal`).
    private func pruneJournal() {
        journal.removeAll { $0.generation != timeline.documentGeneration }
    }

    // MARK: Reading

    /// The selection and the song as the owners hold them now. Stale ids resolve to nothing.
    func snapshot() -> EchoelProjectSnapshot {
        let document = timeline.document
        let trackID = WorkstationSelection.resolvedTrack(selection.trackID, in: document)
        let partID = WorkstationSelection.resolvedRegion(selection.regionID, track: trackID, in: document)
        var track: EchoelProjectSnapshot.Track?
        if let trackID, let lane = document.lanes.first(where: { $0.id == trackID }),
           let controls = TrackMix.controls(of: trackID, in: document, voiceCapacity: voiceCapacity()) {
            track = EchoelProjectSnapshot.Track(id: trackID, name: lane.name,
                                                device: TrackMix.deviceName(controls.role),
                                                hasLevel: controls.level, level: lane.level)
        }
        var part: EchoelProjectSnapshot.Part?
        if let partID, let region = document.regions.first(where: { $0.id == partID }) {
            part = EchoelProjectSnapshot.Part(id: region.id, laneID: region.laneID, clipID: region.clipID,
                                              startTick: region.startTick, lengthTicks: region.lengthTicks)
        }
        let media = EchoelProjectSnapshot.Media(photo: mediaLooks.shownPhoto, video: mediaLooks.shownVideo,
                                                appliedLook: mediaLooks.pending,
                                                appliedFrom: mediaLooks.pending == nil ? "" : mediaLooks.medium)
        return EchoelProjectSnapshot(track: track, part: part, trackCount: document.lanes.count,
                                     partCount: document.regions.count, agentCanUndo: canUndoAgentChange,
                                     media: media, documentGeneration: timeline.documentGeneration)
    }

    // MARK: Running

    /// Ends every step of the running request that has not started yet.
    func cancel() {
        if runningRequest != nil { cancelRequested = true }
    }

    func execute(_ plan: EchoelActionPlan) async -> EchoelExecutionReport {
        if let earlier = finished[plan.requestID] {
            guard earlier.steps == plan.steps else { return refused(plan, .requestIDReused) }
            return EchoelExecutionReport(requestID: earlier.report.requestID, steps: earlier.report.steps,
                                         replayed: true, refusal: earlier.report.refusal)
        }
        guard runningRequest == nil else { return refused(plan, .busy) }
        for command in plan.steps {
            if case .explicitConsent(let consent) = EchoelCommandRegistry.spec(command.id).permission,
               !plan.consents.contains(consent) {
                return refused(plan, .consentRequired(consent))
            }
        }
        if let missing = Self.missingTarget(in: plan) { return refused(plan, missing) }
        guard snapshot() == plan.basis else { return refused(plan, .projectChanged) }

        runningRequest = plan.requestID
        cancelRequested = false
        var group: [Inverse] = []
        var results: [EchoelStepResult] = []
        var stopped = false
        for (index, command) in plan.steps.enumerated() {
            // The suspension between two steps exists for the NEXT writer; once the request has
            // stopped for good there is no next writer, so no hook runs either (the xcresult of
            // e9999dc58 showed the Open hook firing a second time behind a stopped step).
            if index > 0, !stopped {
                await betweenSteps()
                // The project may have been opened again while this request was suspended — the
                // same file too, which no content check can see (review 5.1). No further writer
                // runs against it: this step fails as a changed project, the rest do not run.
                if timeline.documentGeneration != plan.basis.documentGeneration {
                    results.append(EchoelStepResult(command: command, outcome: .failed(.projectChanged)))
                    stopped = true
                    continue
                }
            }
            if stopped {
                results.append(EchoelStepResult(command: command, outcome: .notRun))
                continue
            }
            if cancelRequested || Task.isCancelled {
                results.append(EchoelStepResult(command: command, outcome: .cancelled))
                continue
            }
            let outcome = run(Self.pinned(command, to: plan.basis), seen: plan.basis, into: &group)
            if case .failed = outcome { stopped = true }
            results.append(EchoelStepResult(command: command, outcome: outcome))
        }
        if !group.isEmpty {
            // Stamped with the generation the steps RAN in (the check above guarantees they all did),
            // never with one found afterwards.
            journal.append((generation: plan.basis.documentGeneration, entries: group))
            if journal.count > Self.journalDepth { journal.removeFirst() }
        }
        let report = EchoelExecutionReport(requestID: plan.requestID, steps: results, replayed: false,
                                           refusal: nil)
        remember(report, steps: plan.steps)
        runningRequest = nil
        cancelRequested = false
        return report
    }

    /// A request that did not start. Not remembered: nothing ran, so asking again is allowed.
    private func refused(_ plan: EchoelActionPlan, _ reason: EchoelCommandError) -> EchoelExecutionReport {
        EchoelExecutionReport(requestID: plan.requestID,
                              steps: plan.steps.map { EchoelStepResult(command: $0, outcome: .notRun) },
                              replayed: false, refusal: reason)
    }

    /// A step that names "the selection" while the plan saw none: refused BEFORE the first step,
    /// so no step ever runs against a target the plan did not carry (review repair 2a).
    private static func missingTarget(in plan: EchoelActionPlan) -> EchoelCommandError? {
        for command in plan.steps {
            switch command {
            case .setTrackLevel(.selected, _) where plan.basis.track == nil:
                return .nothingSelected("track")
            case .duplicatePart(.selected) where plan.basis.part == nil:
                return .nothingSelected("part")
            case .describeState, .setTrackLevel, .duplicatePart, .undoAgentChange, .applyMediaLook:
                continue
            }
        }
        return nil
    }

    /// "The selection" as the plan saw it — an id, because `missingTarget` refused the plan
    /// otherwise. Should `.selected` ever get past both, the resolvers refuse it (below); they
    /// never read the live selection.
    private static func pinned(_ command: EchoelCommand, to basis: EchoelProjectSnapshot) -> EchoelCommand {
        switch command {
        case .setTrackLevel(.selected, let change):
            guard let id = basis.track?.id else { return command }
            return .setTrackLevel(track: .id(id), change: change)
        case .duplicatePart(.selected):
            guard let id = basis.part?.id else { return command }
            return .duplicatePart(part: .id(id))
        case .describeState, .setTrackLevel, .duplicatePart, .undoAgentChange, .applyMediaLook:
            return command
        }
    }

    private func remember(_ report: EchoelExecutionReport, steps: [EchoelCommand]) {
        finished[report.requestID] = (steps, report)
        finishedOrder.append(report.requestID)
        if finishedOrder.count > Self.rememberedRequests {
            finished[finishedOrder.removeFirst()] = nil
        }
    }

    private func run(_ command: EchoelCommand, seen basis: EchoelProjectSnapshot,
                     into group: inout [Inverse]) -> EchoelStepResult.Outcome {
        switch command {
        case .describeState:
            return .done(EchoelStateText.describe(snapshot()))
        case .setTrackLevel(let target, let change):
            return setLevel(target, change, into: &group)
        case .duplicatePart(let target):
            return duplicate(target, into: &group)
        case .undoAgentChange:
            return undoLast(&group)
        case .applyMediaLook(let medium):
            return applyLook(medium, seen: basis.media, into: &group)
        }
    }

    // MARK: Targets

    private func track(_ target: EchoelTarget, in document: TimelineDocument) -> Result<UUID, EchoelCommandError> {
        switch target {
        case .selected:
            // Never resolved here (see `missingTarget` / `pinned`): reading the live selection at
            // step time is how a selection made after the plan would become the target.
            return .failure(.nothingSelected("track"))
        case .id(let id):
            return document.lanes.contains(where: { $0.id == id }) ? .success(id) : .failure(.targetGone("track"))
        }
    }

    private func part(_ target: EchoelTarget, in document: TimelineDocument) -> Result<TimelineRegion, EchoelCommandError> {
        let id: UUID
        switch target {
        case .selected:
            // Never resolved here, for the same reason as `track(_:in:)`.
            return .failure(.nothingSelected("part"))
        case .id(let named):
            id = named
        }
        guard let region = document.regions.first(where: { $0.id == id }) else { return .failure(.targetGone("part")) }
        return .success(region)
    }

    /// Every write the agent itself makes to a lane's level — a change, or a restore in Undo — moves
    /// that lane's store count by one, and the journal's `write` marks for that lane move with it.
    /// So an earlier entry of the agent's own still reads as the agent's after its later change or
    /// its Undo, while a write that moved NO mark is a person's and blocks (review 5.2). Called
    /// right after the write and before a new entry is appended; `pending` is whatever the caller
    /// holds outside the journal (the request's group, or the entries an Undo is walking).
    private func noteOwnLevelWrite(on laneID: UUID, pending: inout [Inverse]) {
        func advanced(_ entry: Inverse) -> Inverse {
            if case .level(let id, let before, let after, let write) = entry, id == laneID {
                return .level(laneID: id, before: before, after: after, write: write + 1)
            }
            return entry
        }
        pending = pending.map(advanced)
        journal = journal.map { (generation: $0.generation, entries: $0.entries.map(advanced)) }
    }

    // MARK: Commands

    private func setLevel(_ target: EchoelTarget, _ change: EchoelLevelChange,
                          into group: inout [Inverse]) -> EchoelStepResult.Outcome {
        let document = timeline.document
        let laneID: UUID
        switch track(target, in: document) {
        case .success(let id): laneID = id
        case .failure(let error): return .failed(error)
        }
        guard let lane = document.lanes.first(where: { $0.id == laneID }),
              let controls = TrackMix.controls(of: laneID, in: document, voiceCapacity: voiceCapacity()) else {
            return .failed(.targetGone("track"))
        }
        guard controls.level else { return .failed(.noLevel(TrackMix.deviceName(controls.role))) }
        let before = lane.level
        let linear: Double
        switch EchoelLevelMath.target(current: Double(before), change: change) {
        case .success(let value): linear = value
        case .failure(let error): return .failed(error)
        }
        let asked = Float(linear)
        if asked == before {
            return .done("\(lane.name) is already at \(TrackMix.decibelText(Double(before))).")
        }
        TrackMix.setLevel(linear, laneID: laneID, timeline: timeline)
        noteOwnLevelWrite(on: laneID, pending: &group)
        guard let after = timeline.document.lanes.first(where: { $0.id == laneID })?.level else {
            return .failed(.verificationFailed("the track is gone"))
        }
        if after != before {
            group.append(.level(laneID: laneID, before: before, after: after,
                                write: timeline.laneLevelWrites[laneID] ?? 0))
        }
        guard after == asked else {
            return .failed(.verificationFailed("the level reads \(TrackMix.decibelText(Double(after))), "
                + "not \(TrackMix.decibelText(linear))"))
        }
        return .done("\(lane.name): \(TrackMix.decibelText(Double(before))) → \(TrackMix.decibelText(Double(after))).")
    }

    private func duplicate(_ target: EchoelTarget, into group: inout [Inverse]) -> EchoelStepResult.Outcome {
        let document = timeline.document
        let original: TimelineRegion
        switch part(target, in: document) {
        case .success(let region): original = region
        case .failure(let error): return .failed(error)
        }
        guard TrackParts.arrangeable(original.laneID, in: document) else { return .failed(.notArrangeable) }
        // The copy lands at the original's end. Any part that OVERLAPS that place holds it — one
        // starting inside it, and one that starts earlier and reaches into it (review repair 3b:
        // the first version asked only where a part STARTS, so a long part's tail was copied over;
        // the later-placed copy then wins the shared ticks, #1440, and the person hears the copy
        // where the older part was, while the report says "copied").
        let place = original.endTick..<(original.endTick + original.lengthTicks)
        if document.regions.contains(where: { $0.laneID == original.laneID && $0.id != original.id
                                              && $0.startTick < place.upperBound && $0.endTick > place.lowerBound }) {
            return .failed(.placeTaken)
        }
        let known = Set(document.regions.map(\.id))
        TrackParts.duplicate(TrackParts.Part(id: original.id, startTick: original.startTick,
                                             lengthTicks: original.lengthTicks), timeline: timeline)
        let added = timeline.document.regions.filter { !known.contains($0.id) }
        for copy in added { group.append(.removeCopy(copy)) }
        guard added.count == 1, let copy = added.first else {
            return .failed(.verificationFailed(added.isEmpty ? "no copy appeared" : "more than one copy appeared"))
        }
        guard copy.laneID == original.laneID, copy.clipID == original.clipID,
              copy.lengthTicks == original.lengthTicks, copy.startTick == original.endTick else {
            return .failed(.verificationFailed("the copy is not directly after the part"))
        }
        let placed = TrackParts.Part(id: copy.id, startTick: copy.startTick, lengthTicks: copy.lengthTicks)
        return .done("Copied the part to \(TrackParts.title(placed)).")
    }

    /// "This photo" is the one the card showed when the plan was made. A card that has since
    /// read another one, or none, is a changed project — never a different photo applied.
    private func applyLook(_ medium: EchoelMedium, seen: EchoelProjectSnapshot.Media,
                           into group: inout [Inverse]) -> EchoelStepResult.Outcome {
        guard mediaLooks.pending == nil else { return .failed(.lookStillApplied(mediaLooks.medium)) }
        let applied: MediaSeedApplication?
        let hasColour: Bool
        switch medium {
        case .photo:
            guard let seed = mediaLooks.shownPhoto else { return .failed(.nothingShown(.photo)) }
            guard seed == seen.photo else { return .failed(.projectChanged) }
            hasColour = seed.hasDominantColour
            applied = mediaLooks.apply(photo: seed, on: visualDefaults)
        case .video:
            guard let seed = mediaLooks.shownVideo else { return .failed(.nothingShown(.video)) }
            guard seed == seen.video else { return .failed(.projectChanged) }
            hasColour = seed.hasDominantColour
            applied = mediaLooks.apply(video: seed, on: visualDefaults)
        }
        guard let application = applied else {
            return .failed(.invalidArgument("that \(medium.rawValue)'s reading"))
        }
        group.append(.mediaLook(application, generation: mediaLooks.generation))
        guard mediaLooks.pending == application,
              VisualLookSnapshot.read(from: visualDefaults) == application.after else {
            return .failed(.verificationFailed("the visual look does not read as the \(medium.rawValue) set it"))
        }
        // A grey photo or video leaves the hue as it was (`MediaSeedLook`), so it says so rather
        // than claiming its colours (review LOW-4).
        guard hasColour else {
            return .done("The visuals now use the look of the \(medium.rawValue). It has no main colour, so the hue stays.")
        }
        switch medium {
        case .photo: return .done("The visuals now use the colours of the photo.")
        case .video: return .done("The visuals now use the colour and motion of the video.")
        }
    }

    /// The look settings a taken-back look could NOT put back, in plain words, or nil when all
    /// of them read as before — as the rows DISPLAY them (`settingsDifferingOnDisplay`, the one
    /// comparison the card's Undo uses too; review repair 2d).
    private static func keptSettings(_ live: VisualLookSnapshot, before: VisualLookSnapshot) -> String? {
        let kept = live.settingsDifferingOnDisplay(from: before)
        guard let last = kept.last else { return nil }
        let list = kept.count == 1 ? last : kept.dropLast().joined(separator: ", ") + " and " + last
        return "The visual \(list)"
    }

    private func undoLast(_ group: inout [Inverse]) -> EchoelStepResult.Outcome {
        // A change made earlier in THIS request is the last change; otherwise the last request's.
        pruneJournal()
        var entries: [Inverse]
        if !group.isEmpty {
            entries = group
            group.removeAll()
        } else if let last = journal.popLast() {
            entries = last.entries
        } else {
            return .failed(.nothingToUndo)
        }
        var restored = 0
        var alreadyUndone = 0   // taken back before this Undo — by the song's Undo, a card's Undo
        var kept: [String] = []
        for index in entries.indices.reversed() {
            switch entries[index] {
            case .level(let laneID, let before, let after, let write):
                guard let lane = timeline.document.lanes.first(where: { $0.id == laneID }) else {
                    kept.append("A removed track")
                    continue
                }
                // Moved since, OR written since — even to the same number: that is the person's
                // decision now, not the agent's leftover.
                guard lane.level == after, timeline.laneLevelWrites[laneID] ?? 0 == write else {
                    kept.append("The level of \(lane.name)")
                    continue
                }
                TrackMix.setLevel(Double(before), laneID: laneID, timeline: timeline)
                noteOwnLevelWrite(on: laneID, pending: &entries)   // `group` is empty here by construction
                if timeline.document.lanes.first(where: { $0.id == laneID })?.level == before {
                    restored += 1
                } else {
                    kept.append("The level of \(lane.name)")
                }
            case .removeCopy(let copy):
                guard let live = timeline.document.regions.first(where: { $0.id == copy.id }) else {
                    alreadyUndone += 1   // the song's Undo or Remove took it back before this
                    continue
                }
                guard live == copy else {
                    kept.append("The copied part")
                    continue
                }
                TrackParts.remove(TrackParts.Part(id: copy.id, startTick: copy.startTick,
                                                  lengthTicks: copy.lengthTicks), timeline: timeline)
                if timeline.document.regions.contains(where: { $0.id == copy.id }) {
                    kept.append("The copied part")
                } else {
                    restored += 1
                }
            case .mediaLook(let application, let generation):
                // Not the pending look any more — a card's Undo took it back, and anything applied
                // since, even an equal look, is the person's.
                guard mediaLooks.pending == application, mediaLooks.generation == generation else {
                    alreadyUndone += 1
                    continue
                }
                let beforeUndo = VisualLookSnapshot.read(from: visualDefaults)
                mediaLooks.undo(on: visualDefaults)
                let afterUndo = VisualLookSnapshot.read(from: visualDefaults)
                guard let settings = Self.keptSettings(afterUndo, before: application.before) else {
                    restored += 1
                    continue
                }
                // Some settings went back and some a person had moved: both are said (review LOW-1).
                if afterUndo != beforeUndo { restored += 1 }
                kept.append(settings)
            }
        }
        guard kept.isEmpty else {
            let what = kept.joined(separator: ", ")
            guard restored > 0 || alreadyUndone > 0 else { return .failed(.changedSince(what)) }
            return .failed(.partlyUndone(restored: restored, alreadyUndone: alreadyUndone, kept: what))
        }
        return .done(EchoelUndoSummary.text(restored: restored, alreadyUndone: alreadyUndone))
    }
}

// MARK: - The state, in plain words

enum EchoelStateText {

    nonisolated static func describe(_ state: EchoelProjectSnapshot) -> String {
        var lines: [String] = []
        if let track = state.track {
            let level = track.hasLevel ? "level \(TrackMix.decibelText(Double(track.level)))" : "no level"
            lines.append("Selected track: \(track.name) — \(track.device), \(level).")
        } else {
            lines.append("No track is selected.")
        }
        if let part = state.part {
            let span = TrackParts.spanTitle(TrackParts.Part(id: part.id, startTick: part.startTick,
                                                            lengthTicks: part.lengthTicks))
            lines.append("Selected part: \(span).")
        }
        lines.append("The song has \(count(state.trackCount, "track")) and \(count(state.partCount, "part")).")
        if state.media.photo != nil { lines.append("A photo is open on its card.") }
        if state.media.video != nil { lines.append("A video is open on its card.") }
        if state.media.appliedLook != nil {
            lines.append("The visuals use the look of a \(state.media.appliedFrom).")
        }
        if state.agentCanUndo { lines.append("I can take back my last change.") }
        return lines.joined(separator: " ")
    }

    nonisolated private static func count(_ n: Int, _ noun: String) -> String {
        n == 1 ? "1 \(noun)" : "\(n) \(noun)s"
    }
}
