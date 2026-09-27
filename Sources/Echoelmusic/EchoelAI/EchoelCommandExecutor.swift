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
//
// ⭐ THE AGENT'S UNDO IS ITS OWN, AND IT CHECKS. The level is not in the song's history (the store
// keeps mixer moves out of it on purpose), so the agent keeps a journal of exact inverses, one
// group per request. "Take back your last change" restores each value ONLY if it still reads
// what the agent left; a value a person moved since is kept, and the report says so. The song's
// own Undo button is untouched — a taken-back copy is removed through the store, which records
// that removal as one ordinary song step.
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
        case level(laneID: UUID, before: Float, after: Float)
        case removeCopy(TimelineRegion)
    }

    private let timeline: TimelineStore
    private let selection: WorkstationSelection
    /// `TimelineRegionPlayer.laneVoiceCapacity` — asked, never assumed (#431: which lanes have a
    /// level depends on it, exactly as it does for the inspector).
    private let voiceCapacity: () -> Int

    private var journal: [[Inverse]] = []
    private var finished: [UUID: (steps: [EchoelCommand], report: EchoelExecutionReport)] = [:]
    private var finishedOrder: [UUID] = []
    private(set) var runningRequest: UUID?
    private var cancelRequested = false

    init(timeline: TimelineStore, selection: WorkstationSelection, voiceCapacity: @escaping () -> Int) {
        self.timeline = timeline
        self.selection = selection
        self.voiceCapacity = voiceCapacity
    }

    var canUndoAgentChange: Bool { !journal.isEmpty }

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
        return EchoelProjectSnapshot(track: track, part: part, trackCount: document.lanes.count,
                                     partCount: document.regions.count, agentCanUndo: canUndoAgentChange)
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
        guard snapshot() == plan.basis else { return refused(plan, .projectChanged) }

        runningRequest = plan.requestID
        cancelRequested = false
        var group: [Inverse] = []
        var results: [EchoelStepResult] = []
        var stopped = false
        for (index, command) in plan.steps.enumerated() {
            if index > 0 { await Task.yield() }
            if stopped {
                results.append(EchoelStepResult(command: command, outcome: .notRun))
                continue
            }
            if cancelRequested || Task.isCancelled {
                results.append(EchoelStepResult(command: command, outcome: .cancelled))
                continue
            }
            let outcome = run(Self.pinned(command, to: plan.basis), into: &group)
            if case .failed = outcome { stopped = true }
            results.append(EchoelStepResult(command: command, outcome: outcome))
        }
        if !group.isEmpty {
            journal.append(group)
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

    /// "The selection" as the plan saw it. A plan made with nothing selected keeps `.selected`,
    /// which then resolves live — and, since the basis matched, live is also nothing.
    private static func pinned(_ command: EchoelCommand, to basis: EchoelProjectSnapshot) -> EchoelCommand {
        switch command {
        case .setTrackLevel(.selected, let change):
            guard let id = basis.track?.id else { return command }
            return .setTrackLevel(track: .id(id), change: change)
        case .duplicatePart(.selected):
            guard let id = basis.part?.id else { return command }
            return .duplicatePart(part: .id(id))
        case .describeState, .setTrackLevel, .duplicatePart, .undoAgentChange:
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

    private func run(_ command: EchoelCommand, into group: inout [Inverse]) -> EchoelStepResult.Outcome {
        switch command {
        case .describeState:
            return .done(EchoelStateText.describe(snapshot()))
        case .setTrackLevel(let target, let change):
            return setLevel(target, change, into: &group)
        case .duplicatePart(let target):
            return duplicate(target, into: &group)
        case .undoAgentChange:
            return undoLast(&group)
        }
    }

    // MARK: Targets

    private func track(_ target: EchoelTarget, in document: TimelineDocument) -> Result<UUID, EchoelCommandError> {
        switch target {
        case .selected:
            guard selection.trackID != nil else { return .failure(.nothingSelected("track")) }
            guard let id = WorkstationSelection.resolvedTrack(selection.trackID, in: document) else {
                return .failure(.targetGone("track"))
            }
            return .success(id)
        case .id(let id):
            return document.lanes.contains(where: { $0.id == id }) ? .success(id) : .failure(.targetGone("track"))
        }
    }

    private func part(_ target: EchoelTarget, in document: TimelineDocument) -> Result<TimelineRegion, EchoelCommandError> {
        let id: UUID
        switch target {
        case .selected:
            guard selection.regionID != nil else { return .failure(.nothingSelected("part")) }
            let track = WorkstationSelection.resolvedTrack(selection.trackID, in: document)
            guard let resolved = WorkstationSelection.resolvedRegion(selection.regionID, track: track,
                                                                     in: document) else {
                return .failure(.targetGone("part"))
            }
            id = resolved
        case .id(let named):
            id = named
        }
        guard let region = document.regions.first(where: { $0.id == id }) else { return .failure(.targetGone("part")) }
        return .success(region)
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
        guard let after = timeline.document.lanes.first(where: { $0.id == laneID })?.level else {
            return .failed(.verificationFailed("the track is gone"))
        }
        if after != before { group.append(.level(laneID: laneID, before: before, after: after)) }
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
        // The copy lands at the original's end. A part already starting inside that place would be
        // stacked under — the song gains a part nobody hears, while the report says "copied".
        let place = original.endTick..<(original.endTick + original.lengthTicks)
        if document.regions.contains(where: { $0.laneID == original.laneID && $0.id != original.id
                                              && place.contains($0.startTick) }) {
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

    private func undoLast(_ group: inout [Inverse]) -> EchoelStepResult.Outcome {
        // A change made earlier in THIS request is the last change; otherwise the last request's.
        let entries: [Inverse]
        if !group.isEmpty {
            entries = group
            group.removeAll()
        } else if let last = journal.popLast() {
            entries = last
        } else {
            return .failed(.nothingToUndo)
        }
        var restored = 0
        var kept: [String] = []
        for entry in entries.reversed() {
            switch entry {
            case .level(let laneID, let before, let after):
                guard let lane = timeline.document.lanes.first(where: { $0.id == laneID }) else {
                    kept.append("A removed track")
                    continue
                }
                guard lane.level == after else {
                    kept.append("The level of \(lane.name)")
                    continue
                }
                TrackMix.setLevel(Double(before), laneID: laneID, timeline: timeline)
                if timeline.document.lanes.first(where: { $0.id == laneID })?.level == before {
                    restored += 1
                } else {
                    kept.append("The level of \(lane.name)")
                }
            case .removeCopy(let copy):
                guard let live = timeline.document.regions.first(where: { $0.id == copy.id }) else {
                    restored += 1   // already gone: the song is as it was before the copy
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
            }
        }
        guard kept.isEmpty else {
            let what = kept.joined(separator: ", ")
            return .failed(restored > 0 ? .partlyUndone(restored: restored, kept: what) : .changedSince(what))
        }
        return .done(restored == 1 ? "Took back my last change." : "Took back my last \(restored) changes.")
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
        if state.agentCanUndo { lines.append("I can take back my last change.") }
        return lines.joined(separator: " ")
    }

    nonisolated private static func count(_ n: Int, _ noun: String) -> String {
        n == 1 ? "1 \(noun)" : "\(n) \(noun)s"
    }
}
