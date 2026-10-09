// EchoelAgentDesk.swift
// Echoel — GMMW AI-1/AI-2 (founder 2026-10-08: "EchoelAI integriert"): the ONE place a request from
// outside the screen — Siri, the Shortcuts app, Spotlight — becomes a change, and the one place its
// outcome is shown.
//
// ⭐ THE FIRST PRODUCTION CALLER OF THE TESTED COMMAND LAYER. `EchoelCommandExecutor` and
// `EchoelPlanning` were built and guarded (`TheAgentActsThroughTheButtonsPathsTests`,
// `TheAgentProposesOnlyRegisteredCommandsTests`) and had no caller. This file is it, and it adds no
// second path: a request is planned by `EchoelPlanning.plan` and run by `EchoelCommandExecutor
// .execute` — the same paths the buttons use, the same "success only after it is seen", the same
// refusal of a plan whose selection or song changed since.
//
// ⭐ NO MODEL, NO KEYWORD MATCHER. The App Intents are TYPED: each one names one registered command
// and fills its arguments from typed parameters (`EchoelAppIntents.swift`). What an intent posts is
// `EchoelProposedAction` data, exactly what a language model would one day propose, and it goes
// through the same parser — an intent cannot reach a command a model could not. `EchoelPostedPlanner`
// is the planner here, and it plans nothing: it hands back what the intent wrote.
//
// ⚠️ PERMISSIONS COME FROM THE PERSON, NEVER FROM THE REQUEST. Nothing in this file, and nothing in
// the intents, grants a consent: every plan reaches the executor with the empty set
// `EchoelPlanning.plan` gives it, so a command that needs one is refused, visibly. The three typed
// intents need none — each is a reversible edit with the agent's own Undo.
//
// ⭐ THE MAILBOX IS READ ONCE, AND A STALE REQUEST IS DROPPED, NOT RUN. An intent may run before the
// app's startup has bound the executor (a cold launch), so it posts to an App-Group key and the app
// takes it when it can: right away from the intent (in this process), after startup binds, and on
// every return to the foreground. Whichever comes first takes it; the others find nothing. A request
// older than `EchoelAgentInbox.maxAgeSeconds` when it is taken would act on a selection the person
// has long stopped looking at — it is dropped and the notice says so.
//
// ⭐ EVERY OUTCOME IS VISIBLE (AI-2). `notice` is what `AgentReportBanner` shows: done, refused,
// failed, too old, unreadable — never a silent change and never a silent drop. The banner's Undo runs
// `agent.undoLast` through this same desk, so the way back is the same path as the way there.
//
// Main actor only. No file but the App-Group key, no network, nothing on the audio thread.

import Foundation
import Observation

// MARK: - The request an intent posts (data)

/// One request from Siri or Shortcuts: what it asks for in words (for the notice — never parsed),
/// the typed actions, and when it was posted. DATA — it grants nothing.
struct EchoelPostedRequest: Codable, Equatable, Sendable {
    let requestID: UUID
    let request: String
    let actions: [EchoelProposedAction]
    let postedAt: Date
}

/// The App-Group mailbox between an intent and the app. One request at a time, read once.
enum EchoelAgentInbox {
    static let key = "pendingAgentRequest"
    /// A request taken later than this after it was posted is dropped. An intent opens the app, so
    /// the normal gap is a second or two; minutes mean the app was not opened for it (a locked phone,
    /// a dismissed prompt) and the selection it would act on is no longer the one in view.
    static let maxAgeSeconds: TimeInterval = 120

    /// What `take` found.
    enum Taken: Equatable, Sendable {
        case request(EchoelPostedRequest)
        /// Too old — dropped, and the notice says so.
        case expired
        /// Present but not decodable (another build's format) — dropped, and the notice says so.
        case unreadable
    }

    private static var defaults: UserDefaults? { UserDefaults(suiteName: AppGroupStore.appGroupID) }

    /// Posts one request. A request posted while another still WAITS replaces it — the latest ask wins.
    /// ⚠️ That replacement is the one drop without a notice, and it is named here rather than hidden: it
    /// needs two posts before any take, i.e. a multi-action Shortcut on a cold launch, before startup
    /// binds the desk (otherwise each intent's own `runPending` takes its request first). A queue in the
    /// mailbox is the repair (GMMW AI-1b).
    static func post(request: String, actions: [EchoelProposedAction], now: Date) {
        let posted = EchoelPostedRequest(requestID: UUID(), request: request, actions: actions, postedAt: now)
        guard let data = try? JSONEncoder().encode(posted) else { return }
        defaults?.set(data, forKey: key)
    }

    /// Reads and clears the waiting request, so it is taken exactly once.
    static func take(now: Date) -> Taken? {
        guard let store = defaults, let data = store.data(forKey: key) else { return nil }
        store.removeObject(forKey: key)
        return decide(data, now: now)
    }

    /// The pure half of `take`: what the stored bytes mean at `now`.
    static func decide(_ data: Data, now: Date) -> Taken {
        guard let posted = try? JSONDecoder().decode(EchoelPostedRequest.self, from: data) else {
            return .unreadable
        }
        let age = now.timeIntervalSince(posted.postedAt)
        // Both directions: a clock set back by hours must not turn an old request into a fresh one.
        guard age.isFinite, abs(age) <= maxAgeSeconds else { return .expired }
        return .request(posted)
    }
}

/// The planner for a posted request: it proposes exactly what the intent wrote. Not a model.
struct EchoelPostedPlanner: EchoelActionPlanning {
    let actions: [EchoelProposedAction]

    func propose(_ request: String, state: EchoelProjectSnapshot) async throws -> [EchoelProposedAction] {
        actions
    }
}

// MARK: - What the banner shows

/// The outcome of the last request, in one state and one sentence, and whether Undo can act.
struct EchoelAgentNotice: Equatable, Sendable {
    /// The request it reports. A new request replaces the notice even when the words repeat.
    let requestID: UUID
    let state: EchoelAgentState
    let message: String
    let canUndo: Bool

    /// The notice for a finished request. Done steps say what they did; anything else says why not.
    static func from(_ report: EchoelExecutionReport, canUndo: Bool) -> EchoelAgentNotice {
        let state = report.state
        let message: String
        switch state {
        case .failed(let reason), .needsAnswer(let reason):
            message = reason
        case .done, .understood, .running:
            let done = report.steps.compactMap { step -> String? in
                if case .done(let text) = step.outcome { return text }
                return nil
            }
            message = done.joined(separator: " ")
        }
        return EchoelAgentNotice(requestID: report.requestID, state: state, message: message, canUndo: canUndo)
    }
}

// MARK: - The desk

@MainActor
@Observable
final class EchoelAgentDesk {

    /// The one desk. The app binds its executor once (`EchoelmusicApp.bindAgentDesk`); the banner
    /// reads `notice` in its own leaf. Only this desk reads the App-Group mailbox (`runPending`).
    static let shared = EchoelAgentDesk()

    /// The one executor. Nil until the app's startup binds it; a request waits in the mailbox until then.
    @ObservationIgnored private var executor: EchoelCommandExecutor?
    /// The last request's outcome, until the person dismisses it or the next request replaces it.
    private(set) var notice: EchoelAgentNotice?
    /// True while a request runs — the banner's Undo is disabled then.
    private(set) var isWorking = false

    var isBound: Bool { executor != nil }

    /// Hands the desk its executor. Only the first call counts: there is one executor per process.
    func bind(_ executor: EchoelCommandExecutor) {
        guard self.executor == nil else { return }
        self.executor = executor
    }

    /// Takes the waiting request, if any, and runs it — and again after each run, because a request
    /// that arrived while one was running found the desk busy and returned without it. Without an
    /// executor the request stays in the mailbox for the next call. Only the app's desk (`shared`)
    /// reads the mailbox: a test's own desk must never take the running host app's request.
    func runPending(now: Date) async {
        guard self === Self.shared else { return }
        var clock = now
        while executor != nil, !isWorking, let taken = EchoelAgentInbox.take(now: clock) {
            await handle(taken)
            clock = Date()
        }
    }

    /// What a taken request does: a request runs, a stale or unreadable one is dropped with a notice.
    /// Separate from the mailbox so a test can hand a request in without touching the App-Group key
    /// the running host app reads.
    func handle(_ taken: EchoelAgentInbox.Taken) async {
        guard let executor, !isWorking else { return }
        switch taken {
        case .request(let posted):
            await run(requestID: posted.requestID, request: posted.request, actions: posted.actions, on: executor)
        case .expired:
            dropped(Self.expiredMessage, on: executor)
        case .unreadable:
            dropped(Self.unreadableMessage, on: executor)
        }
    }

    static let expiredMessage =
        "The request from Siri or Shortcuts waited too long, so nothing was changed. Please ask again."
    static let unreadableMessage =
        "The request from Siri or Shortcuts could not be read, so nothing was changed."

    /// A request that was taken and not run still gets a notice — a silent drop reads as "done".
    private func dropped(_ message: String, on executor: EchoelCommandExecutor) {
        EchoelCrashLog.breadcrumb("agent: request dropped before it ran")
        notice = EchoelAgentNotice(requestID: UUID(), state: .failed(message), message: message,
                                   canUndo: executor.canUndoAgentChange)
    }

    /// The banner's Undo: `agent.undoLast`, planned and run like any other request.
    func undoLast() async {
        guard let executor, !isWorking else { return }
        let undo = EchoelProposedAction(command: EchoelCommandID.undoAgentChange.rawValue, arguments: [:])
        await run(requestID: UUID(), request: "Undo Echoel's last change", actions: [undo], on: executor)
        // A request that arrived while the Undo ran found the desk busy — take it now, not at the next return.
        await runPending(now: Date())
    }

    /// Hides the notice. Changes nothing in the piece.
    func dismiss() {
        notice = nil
    }

    private func run(requestID: UUID, request: String, actions: [EchoelProposedAction],
                     on executor: EchoelCommandExecutor) async {
        isWorking = true
        defer { isWorking = false }
        let basis = executor.snapshot()
        let planned = await EchoelPlanning.plan(requestID: requestID, request: request,
                                                planner: EchoelPostedPlanner(actions: actions), basis: basis)
        switch planned {
        case .failure(let error):
            notice = EchoelAgentNotice(requestID: requestID, state: .failed(error.message), message: error.message,
                                       canUndo: executor.canUndoAgentChange)
        case .success(let plan):
            notice = EchoelAgentNotice(requestID: requestID, state: .running, message: request,
                                       canUndo: false)
            // The rung stands BEFORE the call (#859); it names command ids only, never a value or a name.
            EchoelCrashLog.breadcrumb("agent: run " + plan.steps.map(\.id.rawValue).joined(separator: ", "))
            let report = await executor.execute(plan)
            let finished = EchoelAgentNotice.from(report, canUndo: executor.canUndoAgentChange)
            EchoelCrashLog.breadcrumb("agent: " + finished.state.title.lowercased())
            notice = finished
        }
    }
}
