// TheAgentHasOneProductionDoorTests.swift
// Echoel — GMMW AI-1/AI-2 (founder 2026-10-08: "EchoelAI integriert"). The tested command layer
// (`EchoelCommandExecutor`, `EchoelPlanning`) gets its first production caller: typed App Intents
// post a proposal, ONE executor runs it, and the outcome shows with an Undo.
//
// WHAT THIS GUARDS.
//   1. END-TO-END BEHAVIOUR (`EchoelAgentInbox.decide`): a posted request reads back whole; one taken
//      more than `maxAgeSeconds` after it was posted — in either direction — is EXPIRED; bytes that
//      do not decode are UNREADABLE. A stale request never runs.
//   2. END-TO-END BEHAVIOUR (`EchoelAgentDesk.handle`, the real executor on the real store): a level
//      request moves the selected track and the notice says what it did, with Undo; the desk's Undo
//      takes it back through the same path; a copy request adds one part.
//   3. END-TO-END BEHAVIOUR: what is NOT run is still SHOWN — an unregistered command, nothing
//      selected, a stale or unreadable request each leave a failed notice and the piece unchanged.
//   4. SOURCE-TEXT SCAN: ONE production door. Exactly one `EchoelCommandExecutor(` outside its own
//      file — in the app's `bindAgentDesk` — one `EchoelPlanning.plan(` and one `.execute(` on it,
//      both in the desk; the intents only POST (three of them, each naming a registered command id),
//      write no consent, and never touch the executor or the planner.
//   5. SOURCE-TEXT SCAN: the app binds once and runs the mailbox at startup and on `.active`.
//   6. SOURCE-TEXT SCAN (the 10.76.41/50 law and the sheet ceiling): the notice is its own leaf in
//      the root's column — the root mounts it once and reads nothing of the desk; the leaf carries no
//      presentation modifier; the instrument's sheet chain does not know it.
//   7. COUNTERWEIGHT: the four commands the intents name are reversible edits that need no consent,
//      so the empty consent set every plan carries is enough — and only for them.
//   8. AI-1b (pure + `handle`): requests posted before any take QUEUE, oldest first — a second post
//      no longer replaces the first; an older build's single stored request is a queue of one; past
//      `maxQueued` the new post is refused and later reported (`.overflowed`) with a notice; several
//      requests run in one drain show one notice with each sentence, and a refusal is never hidden by
//      a later "Done", and that notice says its one Undo takes back only the last. The STORE half
//      (`post`/`take` with a throwaway `UserDefaults` suite, never the App-Group key) is driven
//      too, so reverting `post` to replace-the-first goes red (review of 9d75ea6). GRADING: forward — `enqueued`/`dequeued`/`.overflowed`/`combined` are created
//      by the same commit, so nothing here compiles against the parent (#486).
//   9. AI-1b (`handle` + SOURCE-TEXT SCAN): each agent intent answers Siri with ITS OWN request's
//      outcome (`spokenOutcome(of:)`) — a refusal is heard; before the desk ran it, or for another
//      request's notice, it says it waits. Forward (`spokenOutcome` is new).
//
// ⚠️ HONEST GRADING (#433). Claims 1–3 drive `EchoelAgentInbox`, `EchoelAgentDesk` and
// `EchoelPostedRequest`, which this same commit creates, so this file does NOT compile against the
// parent's `Sources/` — no assertion has a verdict there; they are FORWARD, one absence (#486).
// Claims 4–6 were transcribed in Python against both trees: RED on the parent (the door, the bind and
// the leaf do not exist), GREEN here. Claim 7 is a COUNTERWEIGHT, green on both.
//
// ⚠️ THE LIMIT. Nothing here runs Siri. Whether the phrases are recognised, whether `perform()` runs
// in the app's process before or after it becomes active, and whether the notice reads well are
// DEVICE PROBES (NEEDS-FOUNDER-VERIFY in `EchoelAppIntents.swift`). The tests never touch the
// App-Group key: the CI host is the app itself, and its own desk reads that key.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheAgentHasOneProductionDoorTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar
    private static let clip = UUID()
    private static let keysLane = TimelineLane(name: "Keys", kind: .midi)
    private static let loopLane = TimelineLane(name: "Loop", kind: .audio)
    private static let loopPart = TimelineRegion(laneID: loopLane.id, clipID: clip, startTick: bar,
                                                 lengthTicks: 2 * bar)
    private static let fixture = TimelineDocument(lanes: [keysLane, loopLane], regions: [loopPart])

    private static let appPath = "Sources/Echoelmusic/EchoelmusicApp.swift"
    private static let deskPath = "Sources/Echoelmusic/EchoelAI/EchoelAgentDesk.swift"
    private static let intentsPath = "Sources/Echoelmusic/Studio/EchoelAppIntents.swift"
    private static let bannerPath = "Sources/Echoelmusic/Studio/AgentReportBanner.swift"
    private static let rootPath = "Sources/Echoelmusic/Studio/WorkspaceView.swift"
    private static let instrumentPath = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let executorPath = "Sources/Echoelmusic/EchoelAI/EchoelCommandExecutor.swift"
    private static let commandPath = "Sources/Echoelmusic/EchoelAI/EchoelCommand.swift"

    // MARK: 1 — the mailbox reads a request back whole, and drops a stale one

    func testAStaleOrUnreadableRequestNeverRuns() throws {
        let posted = EchoelPostedRequest(
            requestID: UUID(), request: "Copy the selected part",
            actions: [EchoelProposedAction(command: EchoelCommandID.duplicatePart.rawValue, arguments: ["part": "selected"])],
            postedAt: Date(timeIntervalSinceReferenceDate: 1_000_000))
        let data = try JSONEncoder().encode(posted)
        let limit = EchoelAgentInbox.maxAgeSeconds
        XCTAssertGreaterThan(limit, 0, "a limit of zero would drop every request")
        XCTAssertEqual(EchoelAgentInbox.decide(data, now: posted.postedAt.addingTimeInterval(1)), .request(posted),
                       "a request taken a second later reads back whole")
        XCTAssertEqual(EchoelAgentInbox.decide(data, now: posted.postedAt.addingTimeInterval(limit)), .request(posted),
                       "at the limit it still runs")
        XCTAssertEqual(EchoelAgentInbox.decide(data, now: posted.postedAt.addingTimeInterval(limit + 1)), .expired,
                       "past the limit the selection it would act on is no longer the one in view")
        XCTAssertEqual(EchoelAgentInbox.decide(data, now: posted.postedAt.addingTimeInterval(-(limit + 1))), .expired,
                       "a clock set back must not turn an old request into a fresh one")
        XCTAssertEqual(EchoelAgentInbox.decide(Data("not a request".utf8), now: posted.postedAt), .unreadable)
    }

    // MARK: 8 — AI-1b: requests posted before any take queue up, oldest first; none is replaced

    func testQueuedRequestsRunInTheOrderAskedAndNoneIsSilentlyReplaced() throws {
        let first = Data("first".utf8), second = Data("second".utf8)
        let one = try XCTUnwrap(EchoelAgentInbox.enqueued(first, onto: nil), "an empty mailbox takes a request")
        let two = try XCTUnwrap(EchoelAgentInbox.enqueued(second, onto: one))
        XCTAssertEqual(two, [first, second], "a second post waits BEHIND the first — it no longer replaces it")
        let taken = EchoelAgentInbox.dequeued(two)
        XCTAssertEqual(taken.first, first, "the oldest request is taken first")
        XCTAssertEqual(taken.rest, [second], "and the newer one stays for the next take")
        XCTAssertFalse(taken.unreadable)

        // A request an older build posted (the mailbox held ONE `Data`) is a queue of one.
        let legacy = EchoelAgentInbox.dequeued(first)
        XCTAssertEqual(legacy.first, first)
        XCTAssertEqual(legacy.rest, [])
        XCTAssertEqual(EchoelAgentInbox.enqueued(second, onto: first), [first, second])
        // A stored value that is no queue at all is reported unreadable, and a post replaces it.
        XCTAssertTrue(EchoelAgentInbox.dequeued("not a queue").unreadable)
        XCTAssertEqual(EchoelAgentInbox.enqueued(first, onto: "not a queue"), [first])
        XCTAssertNil(EchoelAgentInbox.dequeued(nil).first)

        // A full queue keeps what it holds and refuses the new post — the caller counts it as not run.
        let full = Array(repeating: first, count: EchoelAgentInbox.maxQueued)
        XCTAssertGreaterThan(EchoelAgentInbox.maxQueued, 1, "a queue of one is the old replace-the-first mailbox")
        XCTAssertNil(EchoelAgentInbox.enqueued(second, onto: full), "past the cap the new post is not stored")
        XCTAssertEqual(EchoelAgentInbox.enqueued(second, onto: Array(full.dropLast())),
                       Array(full.dropLast()) + [second], "one under the cap still takes it")
    }

    /// The store half, driven on a throwaway suite (never the App-Group key the host app reads): a
    /// second post waits behind the first, `take` leaves the rest, and a full queue's extra posts are
    /// reported once, after the stored ones.
    func testTheStoreQueuesInOrderAndReportsWhatAFullQueueRefused() throws {
        let suite = "echoel.tests.agentMailboxQueue"
        let store = try XCTUnwrap(UserDefaults(suiteName: suite))
        store.removePersistentDomain(forName: suite)
        defer { store.removePersistentDomain(forName: suite) }
        let now = Date()
        let first = EchoelAgentInbox.post(request: "first", actions: [], now: now, in: store)
        let second = EchoelAgentInbox.post(request: "second", actions: [], now: now, in: store)
        guard case .request(let a)? = EchoelAgentInbox.take(now: now, in: store) else {
            return XCTFail("the first post must be taken first")
        }
        XCTAssertEqual(a.requestID, first, "oldest first — the second post did not replace the first")
        guard case .request(let b)? = EchoelAgentInbox.take(now: now, in: store) else {
            return XCTFail("the second post must still be there after the first was taken")
        }
        XCTAssertEqual(b.requestID, second)
        XCTAssertNil(EchoelAgentInbox.take(now: now, in: store), "taken exactly once each")

        for i in 0..<(EchoelAgentInbox.maxQueued + 2) {
            EchoelAgentInbox.post(request: "ask \(i)", actions: [], now: now, in: store)
        }
        for i in 0..<EchoelAgentInbox.maxQueued {
            guard case .request(let r)? = EchoelAgentInbox.take(now: now, in: store) else {
                return XCTFail("stored request \(i) of \(EchoelAgentInbox.maxQueued) is missing")
            }
            XCTAssertEqual(r.request, "ask \(i)", "the queue holds its cap, in the order asked")
        }
        XCTAssertEqual(EchoelAgentInbox.take(now: now, in: store), EchoelAgentInbox.Taken.overflowed(2),
                       "the posts a full queue refused are reported, never dropped silently")
        XCTAssertNil(EchoelAgentInbox.take(now: now, in: store), "and reported once")
    }

    func testRequestsAFullQueueDidNotStoreAreReported() async throws {
        let (timeline, _, desk, original) = rig()
        defer { timeline.replaceDocument(original) }
        let before = timeline.document
        await desk.handle(.overflowed(3))
        let notice = try XCTUnwrap(desk.notice, "requests that were not run are shown, never dropped silently")
        XCTAssertEqual(notice.state, .failed(EchoelAgentDesk.overflowMessage(3)))
        XCTAssertTrue(notice.message.contains("3 more requests"), "the notice says how many: \(notice.message)")
        XCTAssertTrue(EchoelAgentDesk.overflowMessage(1).contains("1 more request "), "and speaks of one as one")
        XCTAssertEqual(timeline.document, before, "and nothing in the piece changed")
    }

    func testSeveralRequestsRunInOneGoSayEachAndARefusalIsNeverHidden() throws {
        let refused = EchoelAgentNotice(requestID: UUID(), state: .failed("Nothing is selected."),
                                        message: "Nothing is selected.", canUndo: false)
        let done = EchoelAgentNotice(requestID: UUID(), state: .done, message: "Loop: 0.0 dB → −3.0 dB.",
                                     canUndo: true)
        let both = try XCTUnwrap(EchoelAgentNotice.combined([refused, done]))
        XCTAssertEqual(both.message, "Nothing is selected. Loop: 0.0 dB → −3.0 dB. " + EchoelAgentNotice.undoesTheLastSentence,
                       "each request's sentence, in order — and the one Undo says it takes back only the last")
        guard case .failed = both.state else {
            return XCTFail("a later Done must not hide an earlier refusal: \(both.state)")
        }
        XCTAssertTrue(both.canUndo, "Undo follows the last request — the agent's last change")
        XCTAssertEqual(both.requestID, done.requestID)
        let twoDone = try XCTUnwrap(EchoelAgentNotice.combined([done, done]))
        XCTAssertEqual(twoDone.state, .done)
        XCTAssertEqual(EchoelAgentNotice.combined([done]), done, "one notice stays as it is")
        XCTAssertNil(EchoelAgentNotice.combined([]))
        // The desk's drain is what combines them (source scan: one place, after the loop).
        let desk = try source(Self.deskPath)
        XCTAssertTrue(desk.contains("if drained.count > 1 { notice = EchoelAgentNotice.combined(drained) }"),
                      "runPending combines the notices of the requests it ran in one go")
    }

    func testSiriAnswersWithThisRequestsOwnOutcome() async throws {
        let (timeline, _, desk, original) = rig()
        defer { timeline.replaceDocument(original) }
        let asked = UUID()
        XCTAssertEqual(desk.spokenOutcome(of: asked), EchoelAgentDesk.waitingSentence,
                       "before the desk ran it, Siri says it waits — never another request's answer")
        // Nothing is selected, so the request is refused — and the refusal is what Siri says.
        await desk.handle(.request(EchoelPostedRequest(
            requestID: asked, request: "Copy the selected part",
            actions: [EchoelProposedAction(command: EchoelCommandID.duplicatePart.rawValue, arguments: ["part": "selected"])],
            postedAt: Date())))
        let notice = try XCTUnwrap(desk.notice)
        XCTAssertEqual(notice.requestID, asked)
        guard case .failed = notice.state else { return XCTFail("nothing selected must refuse: \(notice.state)") }
        XCTAssertFalse(notice.message.isEmpty)
        XCTAssertEqual(desk.spokenOutcome(of: asked), notice.message, "the refusal is heard, not only shown")
        XCTAssertEqual(desk.spokenOutcome(of: UUID()), EchoelAgentDesk.waitingSentence,
                       "another request's notice is never read out as this one's answer")
        let intents = try source(Self.intentsPath)
        XCTAssertEqual(occurrences(of: "return .result(dialog: \"\\(EchoelAgentDesk.shared.spokenOutcome(of: requestID))\")",
                                   in: intents), 4, "each of the four agent intents answers with its own outcome")
    }

    // MARK: 2 — a request runs through the one executor, and its Undo through the same desk

    /// A fresh desk on the real store, the store's prior document handed back for the restore.
    private func rig() -> (TimelineStore, WorkstationSelection, EchoelAgentDesk, TimelineDocument) {
        let timeline = TimelineStore()
        let original = timeline.document
        timeline.replaceDocument(Self.fixture)
        let selection = WorkstationSelection()
        // No claim applies a media look, so these defaults are never written; a fixed suite name keeps
        // the app's own domain untouched.
        let looks = UserDefaults(suiteName: "echoel.tests.agentProductionDoor") ?? UserDefaults()
        let desk = EchoelAgentDesk()
        desk.bind(EchoelCommandExecutor(timeline: timeline, clips: ClipStore(), selection: selection, voiceCapacity: { 4 },
                                        mediaLooks: MediaLookUndo(), visualDefaults: looks))
        return (timeline, selection, desk, original)
    }

    private func request(_ command: String, _ arguments: [String: String] = [:]) -> EchoelAgentInbox.Taken {
        .request(EchoelPostedRequest(requestID: UUID(), request: "test request",
                                     actions: [EchoelProposedAction(command: command, arguments: arguments)],
                                     postedAt: Date()))
    }

    private func level(_ lane: TimelineLane, in timeline: TimelineStore) -> Float? {
        timeline.document.lanes.first(where: { $0.id == lane.id })?.level
    }

    func testARequestRunsThroughTheOneExecutorAndItsUndoTakesItBack() async throws {
        let (timeline, selection, desk, original) = rig()
        defer { timeline.replaceDocument(original) }
        XCTAssertTrue(desk.isBound)
        selection.toggleTrack(Self.loopLane.id)

        await desk.handle(request(EchoelCommandID.setTrackLevel.rawValue,
                                  ["track": "selected", "decibels": "-3.0", "mode": "relative"]))
        let done = try XCTUnwrap(desk.notice, "a request that ran leaves a notice")
        XCTAssertEqual(done.state, .done)
        XCTAssertEqual(done.message, "Loop: 0.0 dB → −3.0 dB.", "the notice says what changed, in the executor's words")
        XCTAssertTrue(done.canUndo, "the agent can take it back, and the notice offers it")
        XCTAssertFalse(desk.isWorking)
        let quieter = try XCTUnwrap(level(Self.loopLane, in: timeline))
        XCTAssertEqual(quieter, Float(pow(10, -3.0 / 20)), "the level reads back as asked")
        XCTAssertEqual(level(Self.keysLane, in: timeline), 1, "the neighbour is untouched")

        await desk.undoLast()
        let undone = try XCTUnwrap(desk.notice)
        XCTAssertEqual(undone.state, .done)
        XCTAssertEqual(undone.message, EchoelUndoSummary.text(restored: 1, alreadyUndone: 0))
        XCTAssertFalse(undone.canUndo, "nothing is left to take back")
        XCTAssertEqual(level(Self.loopLane, in: timeline), 1, "the desk's Undo restored the level")

        let beforeClose = timeline.document
        desk.dismiss()
        XCTAssertNil(desk.notice, "Close hides the notice")
        XCTAssertEqual(timeline.document, beforeClose, "and changes nothing in the piece")
    }

    func testACopyRequestAddsOnePart() async throws {
        let (timeline, selection, desk, original) = rig()
        defer { timeline.replaceDocument(original) }
        selection.selectRegion(Self.loopPart.id, in: timeline.document)
        await desk.handle(request(EchoelCommandID.duplicatePart.rawValue, ["part": "selected"]))
        XCTAssertEqual(desk.notice?.state, .done)
        XCTAssertEqual(timeline.document.regions.count, 2, "one copy, not two")
        let copy = try XCTUnwrap(timeline.document.regions.first { $0.id != Self.loopPart.id })
        XCTAssertEqual(copy.startTick, Self.loopPart.endTick, "the copy starts where the part ends")
        XCTAssertEqual(copy.laneID, Self.loopLane.id)
    }

    // MARK: 3 — what does not run is still shown

    func testWhatIsNotRunIsShownAndChangesNothing() async throws {
        let (timeline, _, desk, original) = rig()
        defer { timeline.replaceDocument(original) }

        await desk.handle(request("share.publish"))
        XCTAssertEqual(desk.notice?.state, .failed(EchoelCommandError.unregistered("share.publish").message),
                       "an id the registry does not know is refused by the parser, visibly")

        await desk.handle(request(EchoelCommandID.setTrackLevel.rawValue,
                                  ["track": "selected", "decibels": "-3", "mode": "relative"]))
        XCTAssertEqual(desk.notice?.state, .failed(EchoelCommandError.nothingSelected("track").message),
                       "with nothing selected the request is refused before its first step")

        await desk.handle(.expired)
        XCTAssertEqual(desk.notice?.message, EchoelAgentDesk.expiredMessage)
        await desk.handle(.unreadable)
        XCTAssertEqual(desk.notice?.message, EchoelAgentDesk.unreadableMessage)
        guard let dropped = desk.notice?.state, case .failed = dropped else {
            return XCTFail("a dropped request reads as failed, never done")
        }

        XCTAssertEqual(timeline.document, Self.fixture, "nothing that was not run changed the piece")
        XCTAssertFalse(desk.isWorking)
    }

    // MARK: 4 — one production door

    func testThereIsOneExecutorOnePlannerCallAndTheIntentsOnlyPost() throws {
        var constructions: [String] = []
        var plans: [String] = []
        var executions: [String] = []
        for (path, code) in try swiftSources() {
            let n = occurrences(of: "EchoelCommandExecutor(", in: code)
            if n > 0, path != Self.executorPath { constructions += Array(repeating: path, count: n) }
            let p = occurrences(of: "EchoelPlanning.plan(", in: code)
            if p > 0, path != Self.commandPath { plans += Array(repeating: path, count: p) }
            let e = occurrences(of: "executor.execute(", in: code)
            if e > 0 { executions += Array(repeating: path, count: e) }
        }
        XCTAssertEqual(constructions, [Self.appPath], """
            The agent's executor is constructed exactly once in production, by the app \
            (`bindAgentDesk`). A second one would keep a second journal — an Undo that cannot see \
            the other's changes, and two "the selection" readers.
            """)
        XCTAssertEqual(plans, [Self.deskPath], "every request is planned in one place, the desk")
        XCTAssertEqual(executions, [Self.deskPath], "and run in one place, the desk")

        let app = try source(Self.appPath)
        let bind = try member("private func bindAgentDesk() {", in: app)
        XCTAssertTrue(bind.contains("EchoelCommandExecutor("), "the one construction sits in `bindAgentDesk`")
        XCTAssertTrue(bind.contains("guard !EchoelAgentDesk.shared.isBound else { return }"),
                      "and it runs once — the guard stands before the construction")

        let intents = try source(Self.intentsPath)
        for banned in ["consents", "EchoelConsent", "EchoelCommandExecutor", "EchoelPlanning", "EchoelActionPlan("] {
            XCTAssertFalse(intents.contains(banned), """
                `\(banned)` in the intents. An intent POSTS a proposal — data that grants nothing; the \
                plan, its consents and its execution belong to the app's one desk.
                """)
        }
        XCTAssertEqual(occurrences(of: "EchoelAgentInbox.post(", in: intents), 4, "four typed intents post (AI-6b added Edit a Copy)")
        XCTAssertEqual(occurrences(of: "await EchoelAgentDesk.shared.runPending(now: Date())", in: intents), 4,
                       "each asks the desk to run it at once — the app may already be active")
        for id in ["EchoelCommandID.setTrackLevel.rawValue", "EchoelCommandID.duplicatePart.rawValue",
                   "EchoelCommandID.undoAgentChange.rawValue", "EchoelCommandID.keepTake.rawValue"] {
            XCTAssertEqual(occurrences(of: id, in: intents), 1, "`\(id)`: each intent names a REGISTERED command by its id")
        }

        let desk = try source(Self.deskPath)
        XCTAssertFalse(desk.contains("consents:"), "the desk writes no consent — `EchoelPlanning.plan` gives the empty set")
        XCTAssertTrue(desk.contains("planner: EchoelPostedPlanner(actions: actions)"),
                      "the planner hands back what the intent wrote — no model, no keyword matcher")
    }

    // MARK: 5 — the app binds once and runs the mailbox at startup and on `.active`

    func testTheAppBindsOnceAndRunsTheMailboxAtStartupAndOnReturn() throws {
        let app = try source(Self.appPath)
        XCTAssertEqual(occurrences(of: "bindAgentDesk()", in: app), 2, "declared once, called once")
        XCTAssertEqual(occurrences(of: "EchoelAgentDesk.shared.runPending(now: Date())", in: app), 2,
                       "two triggers in the app: after startup binds, and on every return to the foreground")
        // The call is searched AFTER the core-ready line, so neither an indent nor the declaration (which
        // sits above it in the file) can satisfy it: a call moved before the core is live finds nothing.
        guard let ready = app.range(of: "EchoelCrashLog.breadcrumb(\"startup 4/4: core ready — instrument live\")") else {
            return XCTFail("ANCHOR MISSING: the core-ready line (#408)")
        }
        guard let bind = app.range(of: "bindAgentDesk()", range: ready.upperBound..<app.endIndex) else {
            return XCTFail("the executor is bound after the core is live — no `bindAgentDesk()` call follows that line")
        }
        guard let firstRun = app.range(of: "EchoelAgentDesk.shared.runPending(now: Date())") else {
            return XCTFail("ANCHOR MISSING: the first run (#408)")
        }
        XCTAssertLessThan(bind.lowerBound, firstRun.lowerBound, "the startup binds BEFORE it runs the mailbox")
        guard let handler = app.range(of: ".onChange(of: scenePhase)"),
              let active = app.range(of: "case .active:", range: handler.upperBound..<app.endIndex),
              let background = app.range(of: "wasBackgrounded = true", range: active.upperBound..<app.endIndex) else {
            return XCTFail("ANCHOR MISSING: the scene-phase `.active` branch (#408)")
        }
        XCTAssertTrue(String(app[active.upperBound..<background.lowerBound])
                        .contains("EchoelAgentDesk.shared.runPending(now: Date())"),
                      "a request waiting while the app was away runs when it returns")
    }

    // MARK: 6 — the notice is its own leaf

    func testTheNoticeIsALeafWithNoModal() throws {
        let root = try source(Self.rootPath)
        XCTAssertEqual(occurrences(of: "AgentReportBanner()", in: root), 1, "the root mounts the notice once")
        XCTAssertFalse(root.contains("EchoelAgentDesk"), """
            The root reads the desk. `WorkspaceView` sits above every menu host; a read in its body \
            rebuilds the whole subtree (10.76.50). The notice reads the desk in its own body.
            """)
        let banner = try source(Self.bannerPath)
        XCTAssertTrue(banner.contains("if let notice = desk.notice {"), "the leaf reads the notice itself")
        for modal in [".sheet(", ".fullScreenCover(", ".alert(", ".popover(", ".confirmationDialog("] {
            XCTAssertFalse(banner.contains(modal), "`\(modal)` in the notice — it is a row in the column, never a modal")
        }
        XCTAssertTrue(banner.contains("Task { await desk.undoLast() }"), "Undo runs through the same desk")
        let instrument = try source(Self.instrumentPath)
        for name in ["AgentReportBanner", "EchoelAgentDesk"] {
            XCTAssertFalse(instrument.contains(name), "`\(name)` on the instrument — its sheet chain stays as it is")
        }
    }

    // MARK: 7 — the four commands need no consent

    func testTheIntentsNameOnlyReversibleEdits() {
        for id in [EchoelCommandID.setTrackLevel, .duplicatePart, .undoAgentChange, .keepTake] {
            XCTAssertEqual(EchoelCommandRegistry.spec(id).permission, .reversibleEdit, """
                `\(id.rawValue)` is no longer a reversible edit. Every plan from an intent carries the \
                EMPTY consent set; a command that needs a consent would be refused there by design, and \
                its intent would have to go.
                """)
        }
        XCTAssertNotEqual(EchoelCommandRegistry.spec(.undoAgentChange).undo, .nothing,
                          "COUNTERWEIGHT: Undo changes the piece, so it is planned and journalled like any change")
    }

    // MARK: helpers

    private struct AnchorMissing: Error { let reason: String }

    /// The text between the brace that opens after `head` and its matching close (#408).
    private func member(_ head: String, in text: String) throws -> String {
        guard head.hasSuffix("{"), let start = text.range(of: head) else {
            XCTFail("ANCHOR MISSING: `\(head)` (#408)")
            throw AnchorMissing(reason: head)
        }
        let from = text.index(before: start.upperBound)
        var depth = 0
        var index = from
        while index < text.endIndex {
            switch text[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return String(text[text.index(after: from)..<index]) }
            default: break
            }
            index = text.index(after: index)
        }
        XCTFail("UNBALANCED after `\(head)`")
        throw AnchorMissing(reason: head)
    }

    private func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    private func repoRoot() throws -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) { return dir }
            dir = dir.deletingLastPathComponent()
        }
        throw XCTSkip("source tree not present above \(#filePath)")
    }

    private func source(_ relativePath: String) throws -> String {
        let url = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            // The tree is here, so a missing file is a move, not a missing checkout (#454).
            XCTFail("`\(relativePath)` is gone — renamed or moved? Point this guard at its new home.")
            throw AnchorMissing(reason: relativePath)
        }
        return SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
    }

    /// Every Swift file under `Sources/`, comment-stripped, keyed by its repo path (the
    /// `TheSpacingSitsOnTheScaleTests` walk).
    private func swiftSources() throws -> [(String, String)] {
        let sources = try repoRoot().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil) else {
            XCTFail("ANCHOR MISSING: cannot walk Sources/ (#454)")
            throw AnchorMissing(reason: "Sources/")
        }
        var out: [(String, String)] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            guard let cut = url.path.range(of: "/Sources/", options: .backwards) else { continue }
            out.append(("Sources/" + String(url.path[cut.upperBound...]), SourceText.codeOnly(text)))
        }
        guard out.count > 100 else {
            XCTFail("the Sources/ walk found only \(out.count) Swift files — the census cannot be trusted")
            throw AnchorMissing(reason: "Sources/ walk")
        }
        return out
    }
}
