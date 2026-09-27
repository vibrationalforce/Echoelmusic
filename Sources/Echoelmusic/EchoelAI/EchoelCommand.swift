// EchoelCommand.swift
// Echoel — EchoelAI as an operating agent, step 1 (founder order 2026-09-27): the TYPED action
// layer that the agent and the surface share.
//
// ⭐ WHAT THIS IS. Every user function the agent may perform is a registered `EchoelCommand` with a
// stable id, typed parameters, targets named by stable ids (or "the selection", resolved at
// execution), stated preconditions, its effect, its undo behaviour and its permission class
// (`EchoelCommandSpec`). A model never writes state: it PROPOSES `EchoelProposedAction`s — plain
// data — and `EchoelCommandParser` turns each into a command or a concrete error. Only
// `EchoelCommandExecutor` executes, and it executes through the SAME store paths the buttons use
// (`TrackMix.setLevel`, `TrackParts.duplicate`, `TrackParts.remove`) — no second engine, no second
// timeline, no simulated taps.
//
// ⭐ WHAT IS NOT HERE, SAID PLAINLY. No language model proposes these actions yet. The existing
// `EchoelLanguageModel` / `EchoelAIRouter` answer text; `FoundationModelsBrain` has no caller and
// has never run on a device. Step 1 delivers the tested action interface; the language binding is
// the named next step, not a keyword matcher dressed up as understanding.
//
// ⚠️ PERMISSIONS COME FROM THE PERSON, NEVER FROM THE PROPOSAL. A proposal's arguments are data:
// an imported file, its metadata or a transcript can end up inside them, and nothing in them can
// grant a consent. `EchoelActionPlan.consents` is filled by the surface, from a tap.
//
// Foundation only. Nothing here runs on the audio thread, and nothing here owns a clock.

import Foundation

// MARK: - Identity

/// The stable id of a registered command. The raw value is what a planner names; it never changes
/// once shipped (a transcript or a saved plan may carry it).
enum EchoelCommandID: String, CaseIterable, Sendable, Codable {
    /// Read the selection and the project state. Changes nothing.
    case describeState = "project.describeState"
    /// Change the selected (or a named) track's level, in decibels.
    case setTrackLevel = "track.setLevel"
    /// Put a copy of the selected (or a named) part directly after it, on the same track.
    case duplicatePart = "part.duplicateAfter"
    /// Take back the agent's own last change — and only that.
    case undoAgentChange = "agent.undoLast"
}

/// A command's target: whatever is selected when it runs, or one stable id.
enum EchoelTarget: Equatable, Sendable {
    case selected
    case id(UUID)
}

/// How a level changes. Decibels, because that is how the inspector reads a level.
enum EchoelLevelChange: Equatable, Sendable {
    /// Up or down by this many dB from where the track is now.
    case relativeDecibels(Double)
    /// To this many dB.
    case absoluteDecibels(Double)
}

/// A registered command with its typed parameters.
enum EchoelCommand: Equatable, Sendable {
    case describeState
    case setTrackLevel(track: EchoelTarget, change: EchoelLevelChange)
    case duplicatePart(part: EchoelTarget)
    case undoAgentChange

    var id: EchoelCommandID {
        switch self {
        case .describeState: return .describeState
        case .setTrackLevel: return .setTrackLevel
        case .duplicatePart: return .duplicatePart
        case .undoAgentChange: return .undoAgentChange
        }
    }
}

// MARK: - Specification

/// What a command needs from the person before it may run.
enum EchoelPermission: Equatable, Sendable {
    /// Reads only.
    case readOnly
    /// A reversible edit: runs directly, and the agent's Undo takes it back.
    case reversibleEdit
    /// Runs only with this consent in the plan. No step-1 command is in this class.
    case explicitConsent(EchoelConsent)
}

/// The consents the founder order names. A plan carries the ones the person gave, by tap.
enum EchoelConsent: String, CaseIterable, Sendable, Codable {
    case publish
    case sendOrUpload
    case deleteOriginal
    case overwriteExport
}

/// How a command is taken back.
enum EchoelUndoBehaviour: Equatable, Sendable {
    /// Nothing to take back — it changes nothing.
    case none
    /// The agent records the exact inverse and checks, before applying it, that nothing has
    /// changed the same value since.
    case agentJournal
    /// This command IS the agent's undo.
    case isTheUndo
}

struct EchoelCommandSpec: Equatable, Sendable {
    let id: EchoelCommandID
    let summary: String
    let parameters: [String]
    let preconditions: [String]
    let effect: String
    let undo: EchoelUndoBehaviour
    let permission: EchoelPermission

    var changesProject: Bool { undo != .none }
}

/// The ONE registry. A command that is not in it cannot be parsed, planned or executed.
enum EchoelCommandRegistry {

    static func spec(_ id: EchoelCommandID) -> EchoelCommandSpec {
        switch id {
        case .describeState:
            return EchoelCommandSpec(
                id: id, summary: "Say what is selected and what the song holds",
                parameters: [],
                preconditions: [],
                effect: "None — it reads the selection and the song.",
                undo: .none, permission: .readOnly)
        case .setTrackLevel:
            return EchoelCommandSpec(
                id: id, summary: "Make a track louder or quieter",
                parameters: ["track: selected | track id",
                             "decibels: a finite number",
                             "mode: relative | absolute"],
                preconditions: ["the track exists",
                                "the track has a level (not a bio curve, not a track without a voice)",
                                "the result stays inside the track's range, up to +6.0 dB",
                                "a relative change needs a track that is not silent"],
                effect: "Sets the track's level through the inspector's own writer.",
                undo: .agentJournal, permission: .reversibleEdit)
        case .duplicatePart:
            return EchoelCommandSpec(
                id: id, summary: "Copy a part to right after it",
                parameters: ["part: selected | part id"],
                preconditions: ["the part exists and sits on the selected track",
                                "its track holds arrangeable parts (MIDI or audio, not bio)"],
                effect: "Adds one copy that starts where the part ends, on the same track, "
                    + "playing the same clip — the part bar's Copy.",
                undo: .agentJournal, permission: .reversibleEdit)
        case .undoAgentChange:
            return EchoelCommandSpec(
                id: id, summary: "Take back the agent's last change",
                parameters: [],
                preconditions: ["the agent changed something",
                                "each value is still what the agent left — a value changed since is kept"],
                effect: "Restores each value the agent's last request changed.",
                undo: .isTheUndo, permission: .reversibleEdit)
        }
    }

    static var all: [EchoelCommandSpec] { EchoelCommandID.allCases.map(spec) }
}

// MARK: - Errors, in plain words

enum EchoelCommandError: Error, Equatable, Sendable {
    case unregistered(String)
    case invalidArgument(String)
    case nothingSelected(String)
    case targetGone(String)
    case noLevel(String)
    case levelIsSilent
    case outOfRange(String)
    case notArrangeable
    case projectChanged
    case consentRequired(EchoelConsent)
    case busy
    case nothingToUndo
    case changedSince(String)
    case verificationFailed(String)
    case modelUnavailable
    case modelFailed

    /// What the person reads. Plain, specific, never "error".
    var message: String {
        switch self {
        case .unregistered(let name):
            return "\"\(name)\" is not something Echoel can do yet."
        case .invalidArgument(let what):
            return "I could not use \(what)."
        case .nothingSelected(let what):
            return "No \(what) is selected. Select one first."
        case .targetGone(let what):
            return "That \(what) is no longer in the song."
        case .noLevel(let device):
            return "This track has no level to change (\(device))."
        case .levelIsSilent:
            return "The track is silent, so it cannot get louder or quieter by a step. Give it a level in decibels."
        case .outOfRange(let detail):
            return detail
        case .notArrangeable:
            return "Parts on this track cannot be copied."
        case .projectChanged:
            return "The song or the selection changed since I read it. Please ask again."
        case .consentRequired(let consent):
            return "This needs your permission first (\(consent.rawValue))."
        case .busy:
            return "I am still working on the previous request."
        case .nothingToUndo:
            return "I have not changed anything to take back."
        case .changedSince(let what):
            return "\(what) changed after my edit, so I left it as it is."
        case .verificationFailed(let what):
            return "I could not confirm the change: \(what)."
        case .modelUnavailable:
            return "No language model is connected. The buttons do all of this without one."
        case .modelFailed:
            return "The language model did not answer. Nothing was changed."
        }
    }
}

// MARK: - Level arithmetic (one place, pure)

enum EchoelLevelMath {

    /// The loudest level a track takes, in dB — derived from the inspector's own range (#416).
    static var maxDecibels: Double { 20 * log10(TrackMix.levelRange.upperBound) }

    /// The linear level `change` asks for from `current`, or why not. Nothing is clamped: a
    /// request past the range is refused, never quietly shortened.
    static func target(current: Double, change: EchoelLevelChange) -> Result<Double, EchoelCommandError> {
        let linear: Double
        switch change {
        case .relativeDecibels(let db):
            guard db.isFinite else { return .failure(.invalidArgument("that number of decibels")) }
            guard current.isFinite, current > 0 else { return .failure(.levelIsSilent) }
            linear = current * pow(10, db / 20)
        case .absoluteDecibels(let db):
            guard db.isFinite else { return .failure(.invalidArgument("that number of decibels")) }
            linear = pow(10, db / 20)
        }
        guard linear.isFinite, linear > 0 else { return .failure(.invalidArgument("that number of decibels")) }
        guard linear <= TrackMix.levelRange.upperBound else {
            return .failure(.outOfRange("That would pass "
                + TrackMix.decibelText(TrackMix.levelRange.upperBound)
                + ", the loudest this track goes. It is at " + TrackMix.decibelText(current) + " now."))
        }
        return .success(linear)
    }
}

// MARK: - What a planner proposes (data) → a command (typed)

/// One action as a planner writes it: a command id and string arguments. DATA — it grants nothing.
struct EchoelProposedAction: Equatable, Sendable, Codable {
    let command: String
    let arguments: [String: String]
}

enum EchoelCommandParser {

    static func parse(_ proposal: EchoelProposedAction) -> Result<EchoelCommand, EchoelCommandError> {
        guard let id = EchoelCommandID(rawValue: proposal.command) else {
            return .failure(.unregistered(String(proposal.command.prefix(60))))
        }
        switch id {
        case .describeState:
            return .success(.describeState)
        case .undoAgentChange:
            return .success(.undoAgentChange)
        case .duplicatePart:
            return target(proposal.arguments["part"], naming: "that part").map { EchoelCommand.duplicatePart(part: $0) }
        case .setTrackLevel:
            let track: EchoelTarget
            switch target(proposal.arguments["track"], naming: "that track") {
            case .success(let t): track = t
            case .failure(let e): return .failure(e)
            }
            guard let raw = proposal.arguments["decibels"],
                  let db = Double(raw.replacingOccurrences(of: "\u{2212}", with: "-")
                    .trimmingCharacters(in: .whitespaces)),
                  db.isFinite else {
                return .failure(.invalidArgument("that number of decibels"))
            }
            switch proposal.arguments["mode"] ?? "" {
            case "relative": return .success(.setTrackLevel(track: track, change: .relativeDecibels(db)))
            case "absolute": return .success(.setTrackLevel(track: track, change: .absoluteDecibels(db)))
            default: return .failure(.invalidArgument("the level mode — relative or absolute"))
            }
        }
    }

    private static func target(_ raw: String?, naming what: String) -> Result<EchoelTarget, EchoelCommandError> {
        guard let raw else { return .failure(.invalidArgument(what)) }
        if raw == "selected" { return .success(.selected) }
        guard let id = UUID(uuidString: raw) else { return .failure(.invalidArgument(what)) }
        return .success(.id(id))
    }
}

// MARK: - A plan, and what came of it

/// What the agent saw when it planned. Execution refuses to start when the live state differs,
/// so a plan made against an old selection never lands on a new one.
struct EchoelProjectSnapshot: Equatable, Sendable {
    struct Track: Equatable, Sendable {
        let id: UUID
        let name: String
        let device: String
        let hasLevel: Bool
        let level: Float
    }
    struct Part: Equatable, Sendable {
        let id: UUID
        let laneID: UUID
        let clipID: UUID
        let startTick: Int
        let lengthTicks: Int
    }
    let track: Track?
    let part: Part?
    let trackCount: Int
    let partCount: Int
    let agentCanUndo: Bool
}

/// A request: its id (a repeat of the same id never runs twice), its steps in order, the state
/// it was planned against, and the consents the PERSON gave.
struct EchoelActionPlan: Equatable, Sendable {
    let requestID: UUID
    let steps: [EchoelCommand]
    let basis: EchoelProjectSnapshot
    let consents: Set<EchoelConsent>
}

/// The five states a request shows. The founder's words are in the comments; the app speaks English.
enum EchoelAgentState: Equatable, Sendable {
    case understood          // Verstanden
    case running             // Wird ausgeführt
    case done                // Fertig
    case needsAnswer(String) // Rückfrage nötig
    case failed(String)      // Fehlgeschlagen

    var title: String {
        switch self {
        case .understood: return "Understood"
        case .running: return "Working"
        case .done: return "Done"
        case .needsAnswer: return "Question"
        case .failed: return "Failed"
        }
    }
}

struct EchoelStepResult: Equatable, Sendable {
    enum Outcome: Equatable, Sendable {
        case done(String)
        case failed(EchoelCommandError)
        case cancelled
        case notRun
    }
    let command: EchoelCommand
    let outcome: Outcome
}

struct EchoelExecutionReport: Equatable, Sendable {
    let requestID: UUID
    let steps: [EchoelStepResult]
    /// True when this is the stored report of a request that already ran.
    let replayed: Bool
    /// Set when the request did not start (a changed project, a missing consent, busy).
    let refusal: EchoelCommandError?

    var completed: Int { steps.filter { if case .done = $0.outcome { return true } else { return false } }.count }
    var isPartial: Bool { completed > 0 && completed < steps.count }

    var state: EchoelAgentState {
        if let refusal {
            return refusal == .projectChanged ? .needsAnswer(refusal.message) : .failed(refusal.message)
        }
        if completed == steps.count { return .done }
        let failure = steps.lazy.compactMap { step -> String? in
            if case .failed(let e) = step.outcome { return e.message }
            return nil
        }.first
        let reason = failure ?? "Cancelled."
        return .failed(isPartial ? "\(completed) of \(steps.count) done. \(reason)" : reason)
    }
}

// MARK: - The seam a language model fills (none is connected today)

/// What a planner — a language model, on the device or opted into the cloud — must do: read the
/// request and the state it is shown, and PROPOSE actions as data. It never executes.
protocol EchoelActionPlanning: Sendable {
    func propose(_ request: String, state: EchoelProjectSnapshot) async throws -> [EchoelProposedAction]
}

enum EchoelPlanning {

    /// A planner's proposal as a plan, or why not. All or nothing: one unregistered or malformed
    /// action rejects the whole proposal, so a half-understood request never half-runs. No planner,
    /// or a planner that throws (model or network), changes nothing and says so. The plan carries
    /// NO consent — only the person adds one.
    static func plan(requestID: UUID, request: String, planner: (any EchoelActionPlanning)?,
                     basis: EchoelProjectSnapshot) async -> Result<EchoelActionPlan, EchoelCommandError> {
        guard let planner else { return .failure(.modelUnavailable) }
        let proposals: [EchoelProposedAction]
        do {
            proposals = try await planner.propose(request, state: basis)
        } catch {
            return .failure(.modelFailed)
        }
        guard !proposals.isEmpty else { return .failure(.invalidArgument("an empty answer")) }
        var steps: [EchoelCommand] = []
        for proposal in proposals {
            switch EchoelCommandParser.parse(proposal) {
            case .success(let command): steps.append(command)
            case .failure(let error): return .failure(error)
            }
        }
        return .success(EchoelActionPlan(requestID: requestID, steps: steps, basis: basis, consents: []))
    }
}
