// TheOffMainDispatchHandlerIsSendableTests.swift
// Echoel — build-2613 SIGTRAP (v10.79.488, 2026-10-02; triaged 2026-10-08 from the retained crash
// in `echoel_diag.log`: `dispatch_assert_queue` → `libswift_Concurrency` → two app frames →
// `_dispatch_root_queue_drain` → `_pthread_wqthread`, 200 ms after "transport play (timelineRegion)").
//
// WHAT WAS WRONG. `RetroCapture.startRecording` armed a `DispatchSource` timer on its private
// `writeQueue` with `setEventHandler { [weak self] in self?.drainToDisk() }`. `RetroCapture` is a
// `@MainActor` class, so under Swift 6 that non-`@Sendable` closure inherits MainActor isolation;
// `DispatchSourceHandler` is an imported block type, so the compiler puts a dynamic isolation check
// at the closure's ENTRY. The first tick fires 200 ms later on a libdispatch worker, the check asks
// "main queue?", `dispatch_assert_queue` fails → SIGTRAP two frames below app code — before the
// (correctly `nonisolated`) `drainToDisk()` runs at all. The device reached it through Arrange →
// Export → WAV, the whole-piece export that shipped in that very build; the log's last rung was
// "transport play (timelineRegion)" because this file wrote none.
//
// THE REPAIR. One token: `setEventHandler { @Sendable [weak self] in … }` — an explicit `@Sendable`
// closure is an isolation-inference boundary and gets no entry check. The callee stays
// `nonisolated`, the drain stays on `writeQueue` (file I/O never on main, #1413). Same repair as
// `MemoryPressureHandler.setupDispatchSource`; `PatternEngine` met the same trap in builds 1769/1777
// and moved its timers to `.main`. Plus one rung before `drain.resume()`.
//
// THE SECOND SITE (same day, found by reading the same export flow ONE PHASE further). After the
// recorder stops, `SingleExport.renderWithGain` pulls the take through
// `AVAssetWriterInput.requestMediaDataWhenReady(on: DispatchQueue(label: "com.echoelmusic.export"))`
// — a non-`@Sendable` closure formed in a `@MainActor` method, capturing two mutable counters,
// passed to an imported block type. Same inference, same entry check, same worker: it would trap
// before the first buffer is read, minutes into the export the 2613 fix had just let begin. The
// repair is the same token plus what `@Sendable` demands of the captures: the counters move into
// ONE `@unchecked Sendable` box (`ExportRenderCounters`), the three AVFoundation objects become
// `nonisolated(unsafe)` locals, and the inner `finishWriting { continuation.resume() }` closure is
// now formed in a non-isolated context, so it inherits nothing either.
//
// THE THIRD SITE (same day, found by the crash-class audit lens, confirmed against the compiler).
// `MIDIInput` is a `@MainActor` class built at app launch; `setupMIDI()` hands CoreMIDI two
// closure literals — the client's notify block and the input port's receive block — neither
// `@Sendable`. Swift's CSApply marks a closure argument for dynamic isolation checking whenever
// its callee comes from a module that is not concurrency-checked, and CoreMIDI is a C module.
// CoreMIDI calls the receive block on its own high-priority thread, so the first note, clock
// tick or CC from ANY connected source (a keyboard, a network session, another app's virtual
// port) would trap at the closure's entry, before the `nonisolated` parser runs. The repair is
// the same token on both blocks; they capture only `self`, weakly.
//
// THE FOURTH SITE (same hour, same lens). `EchoelBioEngine` (`@MainActor`) builds three
// `HKAnchoredObjectQuery`s with trailing results handlers, and `HealthKitWriter` (`@MainActor`)
// passes `store.save(samples) { _, _ in }`. The iOS 18 SDK header gives the query's results
// handler no `NS_SWIFT_SENDABLE` (measured on the header; `HKHealthStore`'s authorization
// completions do carry it, `saveObjects:withCompletion:` does not), HealthKit calls both on a
// background queue, and `HealthKitBioPublisher.startIfAlreadyAuthorized` starts the queries at
// LAUNCH once Health access was granted — so anyone who ever allowed Apple Health would trap
// on the first result of every launch. Same token; the three `process…Samples` callees are
// already `nonisolated`. The `updateHandler` ASSIGNMENTS carry it too (they run on the same
// queue). This file does not pin them. ⛔ Its first wording said they "get no entry check"; that is
// UNMEASURED. SE-0423 documents the check for a closure passed as a call ARGUMENT, and whether
// the setter of an imported block PROPERTY is treated the same way was never compiled here.
//
// THE FIFTH SITE (GMMW P0-1, 2026-10-08). `HapticEngine` (`@MainActor`) assigns two closure
// literals to `CHHapticEngine.resetHandler` and `.stoppedHandler`. CoreHaptics calls both on its
// own queue: the reset after the haptic server restarts, the stop after the idle shutdown the same
// method enables. Unlike the four sites above, these are ASSIGNMENTS, so whether they trapped is
// the open question one paragraph up. It is not answered here. They are pinned anyway, for two
// reasons that hold whatever the compiler does with an assignment. The handlers run off the main
// queue, and an explicit `@Sendable` closure is non-isolated by construction. The repair is the
// MIDIInput shape: `{ @Sendable [weak self] in Task { @MainActor [weak self] in … } }`.
//
// THE SIXTH SITE (GMMW P0-2, same day). `MetalBioRenderer.encodeBroadcastFrame` hands
// `MTLCommandBuffer.addCompletedHandler` a closure literal. Metal calls it on its own completion
// thread. The renderer is not spelled `@MainActor`. It conforms to `MTKViewDelegate`, and whether
// the SDK isolates that protocol (and so the renderer) is not readable here. So the file-scoped
// rule above cannot decide it, and claim 10 pins it OWNER-INDEPENDENTLY: every Metal command-buffer
// handler literal in `Sources/` is spelled `@Sendable`. It is LATENT today. The handler runs only
// while a broadcast stream is live, and HaishinKit is not linked. It is pinned before a frame tap
// can revive it.
//
// THE RULE THIS FILE PINS. In a file that declares a `@MainActor` class, every `setEventHandler`
// whose source was made on a queue other than `.main`, every `requestMediaDataWhenReady(on:)`
// block whose queue is not `.main`, and every closure literal trailing a CoreMIDI
// `MIDI…CreateWithBlock(`/`MIDI…CreateWithProtocol(` call (CoreMIDI picks the thread, never the
// caller), and — in a file that imports HealthKit — every closure literal trailing an
// `HK…Query(` initializer or a `.save(` call (HealthKit's background queue), and — in a file that
// imports CoreHaptics — every closure literal ASSIGNED to `.resetHandler`/`.stoppedHandler`
// (CoreHaptics' own queue) is spelled
// `@Sendable`. Handlers on `.main` may stay isolated
// (`MainActor.assumeIsolated` inside is the correct pattern there). Files without a `@MainActor`
// class are exempt: a closure formed in a non-isolated class inherits nothing.
//
// LIMITS (Tests/CISmoke/CLAUDE.md §1). SOURCE-TEXT SCAN over comment-stripped `Sources/`: it proves
// a spelling, never that the device does not trap. File-granular: it cannot see whether a handler
// is formed in a `nonisolated` method of a `@MainActor` class (there `@Sendable` is a no-op and still
// the honest spelling). A `setEventHandler` is paired with the NEAREST PRECEDING
// `DispatchSource.make…Source(` in the same file; a source created in another file, or a handler
// passed as a stored closure (`setEventHandler(handler: x)`), is not seen. A source made with no
// `queue:` runs on a global queue and counts as off-main. The media-ready block names its queue in
// its own `on:` argument, so it needs no pairing; a queue held in a variable (`on: exportQueue`)
// counts as off-main unless it is literally `.main`/`DispatchQueue.main`, and a block passed as a
// stored closure (`using: block`) is not seen. A CoreMIDI block is seen only as a TRAILING
// closure after the call's balanced argument list (one level of nested parentheses); a block
// passed by name, or as a labelled argument inside the parentheses, is not; the HealthKit needle
// reads the same trailing shape and only in a file that imports HealthKit (`.save(` is a common
// name). The CoreHaptics needle reads only the two handler ASSIGNMENTS
// (`.resetHandler = {`/`.stoppedHandler = {`) and only in a file that imports CoreHaptics. Five
// imported-block API families are pinned, not the class of all of them: a sixth with
// the same shape is a new needle, not a comment. The `@MainActor`
// needle accepts only attributes and modifiers between it and `class`, so `Task { @MainActor in`
// never counts as a class.
//
// HONEST GRADING (§3). Transcribed in Python against the parent `209d79f` and the worktree, with
// `SourceText.codeOnly` ported line for line:
//   · claim 1 — RED on the parent for its NAMED reason, a REGRESSION: exactly one violation,
//     `Audio/RetroCapture.swift` (queue `writeQueue`, handler not `@Sendable`); GREEN after the fix.
//   · claim 2 — COUNTERWEIGHT, green on both: the crash site is inside the rule's domain
//     (`@MainActor` class, off-main timer, `nonisolated` writer) — without it claim 1 could go
//     green by the needle ceasing to match the file.
//   · claim 3 — COUNTERWEIGHT, green on both: the rule on literal fixtures — it fires only for the
//     off-main + isolated + unmarked triple (#367) and never for a `.main` handler or a
//     non-isolated owner (#364).
//   · claim 4 — COUNTERWEIGHT, green on both: the real `.main` owners (`PatternEngine`,
//     `MIDIOutput`) and the real non-isolated off-main owners (`CameraCapture`,
//     `StemCaptureSession`) each have ≥1 handler and yield 0 violations — the exemptions are
//     exercised, not vacuous.
//   · claim 5 — FORWARD guard: red on the parent by ANCHOR ABSENCE only (one absence — the rung
//     did not exist); the arming rung stands before `drain.resume()`.
// Stripper measured PROPHYLAKTISCH: raw vs stripped verdicts identical on every file that carries
// a handler or a source (0 flips) — kept because `PatternEngine`'s doc block names the construct in
// prose and a future comment could otherwise count.
// SECOND MEASUREMENT (the media-ready needle), transcribed against the parent `3738258` and the
// worktree, 464 files, 9 carrier files, 0 stripper flips on both:
//   · claim 1 — RED on the parent for its NAMED reason, a REGRESSION: exactly one violation,
//     `Audio/SingleExport.swift:398` (`requestMediaDataWhenReady` on
//     `DispatchQueue(label: "com.echoelmusic.export")`, not `@Sendable`); GREEN after the fix.
//     Claims 2, 4 and 5 unchanged, green on both.
//   · claim 3's four media fixtures — pure needle, green on both: the queue is read from the
//     `on:` argument verbatim; the isolated shape is one violation, `@Sendable` and `.main` are
//     none, a `DispatchQueue.global(qos:)` call is seen and is one.
//   · claim 6 — COUNTERWEIGHT after the fix, RED on the parent for TWO reasons that are not the
//     same kind: the site is found and not `@Sendable` (regression-shaped) and the counters box is
//     absent (ANCHOR ABSENCE). The `@MainActor` class, the one media block, its own label queue and
//     `nonisolated static func applyGain(` are green on both.
// THIRD MEASUREMENT (the CoreMIDI needle), transcribed against the parent `f059867` and the
// worktree with `SourceText.codeOnly` ported:
//   · claim 1 — RED on the parent for its NAMED reason, a REGRESSION: exactly two violations,
//     `Audio/MIDIInput.swift` (`MIDIClientCreateWithBlock` and `MIDIInputPortCreateWithProtocol`,
//     neither `@Sendable`); GREEN after the fix. No other file carries a CoreMIDI trailing closure.
//   · claim 4 — unchanged, green on both: `MIDIOutput`'s four CoreMIDI create calls take no
//     closure (`nil` or none), so the needle yields no handler there.
//   · claim 3's three CoreMIDI fixtures — pure needle, green on both.
//   · claim 7 — COUNTERWEIGHT after the fix, RED on the parent for its named reason (the two
//     blocks are found and not `@Sendable`); the `@MainActor` class, the two blocks and the
//     `nonisolated` parser are green on both.
// FOURTH MEASUREMENT (the HealthKit needle), transcribed against the parent `bba1030` and the
// worktree: claim 1 RED on the parent for its NAMED reason — exactly four violations, the three
// `HKAnchoredObjectQuery(` handlers in `Bio/EchoelBioEngine.swift` and the `.save(` completion in
// `Bio/HealthKitWriter.swift`; GREEN after the fix. Claim 3's three HealthKit fixtures green on
// both; claim 8 (the two files inside the domain) red on the parent for its named reason, green
// after. Claims 2, 4, 6 and 7 unchanged.
// FIFTH MEASUREMENT (the CoreHaptics needle), transcribed against the parent `74a4433` and the
// worktree with `SourceText.codeOnly` ported. Claim 1 is RED on the parent for its NAMED reason,
// a REGRESSION: exactly two violations, `Studio/HapticEngine.swift` `.resetHandler` and
// `.stoppedHandler`, both unmarked. It is GREEN after the fix. Claim 3's three CoreHaptics
// fixtures are a pure needle and green on both trees. Claim 9 is red on the parent for its named
// reason (both assignments found, neither `@Sendable`) and green after. Claims 2 and 4–8 are
// unchanged. No other file imports CoreHaptics. The rule's verdict on an assignment is a SPELLING
// verdict: whether the parent's closures trapped on a device is not known (the ⛔ note above).
// SIXTH MEASUREMENT (the Metal needle, claim 10), transcribed against the parent `6c499e0` and the
// worktree. Claim 10 is RED on the parent for its NAMED reason, a REGRESSION: exactly one unmarked
// handler, `Views/MetalBioView.swift` `addCompletedHandler`. It is GREEN after the fix. Its two
// fixture rows are green on both trees. Claims 1–9 are unchanged: the file declares no
// `@MainActor` class, so claim 1 never saw this site.
// What the transcription cannot show: whether the iOS SDK annotates `MIDIReceiveBlock` as
// `@Sendable` (then the old spelling was already safe and `@Sendable` is a no-op). Either way the
// explicit spelling is correct; only a device with a MIDI source proves the trap is gone.
// NEEDS-FOUNDER-VERIFY: Arrange → Export → WAV auf dem Gerät bis zum Teilen-Blatt durchlaufen lassen,
// und im nächsten `echoel_diag.log` die Zeile „retro: recording armed“ VOR dem Play sehen — nur das
// Telefon beweist die Aufnahme, nur das 2613-dSYM beweist, dass Frame 7/8 diese Closure waren.
// Dieselbe Geräteprobe entscheidet auch die zweite Stelle: läuft der Export nach dem Stop bis zum
// Teilen-Blatt durch, hat der Pull-Block nicht getrappt — vorher konnte diese Phase auf keinem
// Swift-6-Build je enden. Die dritte Stelle: ein MIDI-Keyboard (USB, Bluetooth oder die
// Netzwerk-Session) anschließen und eine Taste drücken — die App läuft weiter, die Performer-
// Stimme klingt, und im `echoel_diag.log` steht danach kein `crash queue:`.

import Foundation
import XCTest

final class TheOffMainDispatchHandlerIsSendableTests: XCTestCase {

    private static let retro = "Sources/Echoelmusic/Audio/RetroCapture.swift"
    private static let export = "Sources/Echoelmusic/Audio/SingleExport.swift"
    private static let midiIn = "Sources/Echoelmusic/Audio/MIDIInput.swift"
    private static let bioEngine = "Sources/Echoelmusic/Bio/EchoelBioEngine.swift"
    private static let healthWriter = "Sources/Echoelmusic/Bio/HealthKitWriter.swift"
    private static let hapticEngine = "Sources/Echoelmusic/Studio/HapticEngine.swift"
    private static let metalView = "Sources/Echoelmusic/Views/MetalBioView.swift"

    /// A closure literal handed to `MTLCommandBuffer.addCompletedHandler`/`addScheduledHandler`:
    /// group 1 the API, group 2 the `@Sendable` attribute when the closure opens with it.
    private static let metalHandler = #"\.(addCompletedHandler|addScheduledHandler)\s*\{\s*(@Sendable)?"#
    private static let mainQueueOwners = [
        "Sources/Echoelmusic/Sequencer/PatternEngine.swift",
        "Sources/Echoelmusic/Audio/MIDIOutput.swift",
    ]
    private static let nonIsolatedOffMainOwners = [
        "Sources/Echoelmusic/Video/CameraCapture.swift",
        "Sources/Echoelmusic/Audio/StemCaptureSession.swift",
    ]

    // MARK: the rule

    /// `@MainActor` reaching a `class` keyword over nothing but other attributes and modifiers:
    /// `@MainActor @Observable\nfinal class X`, `@MainActor\npublic final class Y`. `Task {
    /// @MainActor in` cannot match — `in` is neither.
    private static let mainActorClass =
        #"@MainActor(?:\s+@\w+)*\s+(?:(?:public|open|internal|fileprivate|private|final)\s+)*class\b"#

    /// Every `DispatchSource.make…Source(` call with its argument text up to the first `)`.
    private static let sourceCall = #"DispatchSource\.make\w+Source\(([^)]*)"#

    /// The `queue:` argument inside that text.
    private static let queueArg = #"queue:\s*([^,)\s]+)"#

    /// A `setEventHandler` given a closure literal, with or without `(qos:flags:)` in front;
    /// group 1 is the `@Sendable` attribute when the closure opens with it.
    private static let handler = #"setEventHandler\s*(?:\([^)]*\)\s*)?\{\s*(@Sendable)?"#

    /// A `requestMediaDataWhenReady(on: <queue>) {` closure literal — AVFoundation calls it on
    /// that queue. Group 1 is the queue expression: a call with its own parentheses
    /// (`DispatchQueue(label: "…")`, `DispatchQueue.global(qos: .utility)`) or a bare name
    /// (`.main`, `exportQueue`); group 2 the `@Sendable` attribute when the closure opens with it.
    private static let mediaReady =
        #"requestMediaDataWhenReady\(\s*on:\s*(\w+(?:\.\w+)*\([^)]*\)|[^)]+)\)\s*\{\s*(@Sendable)?"#

    /// A closure literal TRAILING a CoreMIDI `MIDI…CreateWithBlock(`/`MIDI…CreateWithProtocol(`
    /// call: group 1 the API name, the argument list balanced to one nested level, group 2 the
    /// `@Sendable` attribute when the closure opens with it. A call whose last argument is `nil`
    /// and that is followed by a statement has no `{` after its `)` and is not a handler.
    private static let coreMIDIBlock =
        #"(MIDI\w+CreateWith(?:Block|Protocol))\((?:[^(){}]|\([^()]*\))*\)\s*\{\s*(@Sendable)?"#

    /// CoreMIDI chooses the thread a block runs on (the receive block: its own high-priority
    /// thread), so no CoreMIDI block counts as `.main`.
    private static let coreMIDIThread = "<CoreMIDI's own thread>"

    /// A closure literal TRAILING an `HK…Query(` initializer or a `.save(` call, read only in a
    /// file that imports HealthKit; same balanced-argument shape as the CoreMIDI needle.
    private static let healthKitBlock =
        #"(HK\w+Query|\.save)\((?:[^(){}]|\([^()]*\))*\)\s*\{\s*(@Sendable)?"#

    /// HealthKit calls query results handlers and save completions on a background queue.
    private static let healthKitQueue = "<HealthKit's background queue>"

    /// A closure literal ASSIGNED to a `CHHapticEngine` handler property, read only in a file that
    /// imports CoreHaptics: group 1 the property name, group 2 the `@Sendable` attribute when the
    /// closure opens with it.
    private static let coreHapticsHandler = #"\.(resetHandler|stoppedHandler)\s*=\s*\{\s*(@Sendable)?"#

    /// CoreHaptics calls its reset and stopped handlers on its own queue, never `.main`.
    private static let coreHapticsQueue = "<CoreHaptics' own queue>"

    private static let defaultQueue = "<no queue: — a global queue>"
    private static let unknownQueue = "<no DispatchSource.make…Source( above it>"

    private struct Handler { let line: Int; let queue: String; let sendable: Bool; let api: String }

    private struct Verdict {
        let isMainActorClass: Bool
        let queues: [String]
        let handlers: [Handler]
        let violations: [Handler]
    }

    private static func isMain(_ queue: String) -> Bool {
        queue == ".main" || queue == "DispatchQueue.main"
    }

    private func scan(_ code: String) throws -> Verdict {
        let ns = code as NSString
        let all = NSRange(location: 0, length: ns.length)
        let isMainActorClass = try NSRegularExpression(pattern: Self.mainActorClass)
            .firstMatch(in: code, range: all) != nil

        var sources: [(offset: Int, queue: String)] = []
        let queueRegex = try NSRegularExpression(pattern: Self.queueArg)
        for m in try NSRegularExpression(pattern: Self.sourceCall).matches(in: code, range: all) {
            let args = ns.substring(with: m.range(at: 1)) as NSString
            let argRange = NSRange(location: 0, length: args.length)
            let queue = queueRegex.firstMatch(in: args as String, range: argRange)
                .map { args.substring(with: $0.range(at: 1)) } ?? Self.defaultQueue
            sources.append((m.range.location, queue))
        }

        var handlers: [Handler] = []
        for m in try NSRegularExpression(pattern: Self.handler).matches(in: code, range: all) {
            let queue = sources.last { $0.offset < m.range.location }?.queue ?? Self.unknownQueue
            let sendable = m.range(at: 1).location != NSNotFound
            let line = ns.substring(to: m.range.location).components(separatedBy: "\n").count
            handlers.append(Handler(line: line, queue: queue, sendable: sendable, api: "setEventHandler"))
        }
        // The media-ready block names its queue in its own argument list — no pairing needed.
        for m in try NSRegularExpression(pattern: Self.mediaReady).matches(in: code, range: all) {
            let queue = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            let sendable = m.range(at: 2).location != NSNotFound
            let line = ns.substring(to: m.range.location).components(separatedBy: "\n").count
            handlers.append(Handler(line: line, queue: queue, sendable: sendable, api: "requestMediaDataWhenReady"))
        }
        // HealthKit blocks: only where HealthKit is imported — `.save(` is a common name.
        if code.contains("import HealthKit") {
            for m in try NSRegularExpression(pattern: Self.healthKitBlock).matches(in: code, range: all) {
                let sendable = m.range(at: 2).location != NSNotFound
                let line = ns.substring(to: m.range.location).components(separatedBy: "\n").count
                handlers.append(Handler(line: line, queue: Self.healthKitQueue, sendable: sendable,
                                        api: ns.substring(with: m.range(at: 1))))
            }
        }
        // CoreHaptics handlers: assignments, read only where CoreHaptics is imported.
        if code.contains("import CoreHaptics") {
            for m in try NSRegularExpression(pattern: Self.coreHapticsHandler).matches(in: code, range: all) {
                let sendable = m.range(at: 2).location != NSNotFound
                let line = ns.substring(to: m.range.location).components(separatedBy: "\n").count
                handlers.append(Handler(line: line, queue: Self.coreHapticsQueue, sendable: sendable,
                                        api: ns.substring(with: m.range(at: 1))))
            }
        }
        // CoreMIDI blocks: the thread is CoreMIDI's, never the caller's.
        for m in try NSRegularExpression(pattern: Self.coreMIDIBlock).matches(in: code, range: all) {
            let sendable = m.range(at: 2).location != NSNotFound
            let line = ns.substring(to: m.range.location).components(separatedBy: "\n").count
            handlers.append(Handler(line: line, queue: Self.coreMIDIThread, sendable: sendable,
                                    api: ns.substring(with: m.range(at: 1))))
        }

        let violations = isMainActorClass
            ? handlers.filter { !Self.isMain($0.queue) && !$0.sendable }
            : []
        return Verdict(isMainActorClass: isMainActorClass,
                       queues: sources.map { $0.queue },
                       handlers: handlers,
                       violations: violations)
    }

    // MARK: claims

    /// 1 — the regression catch: no off-main handler inside a `@MainActor` class without `@Sendable`.
    func testAnOffMainHandlerInsideAMainActorClassIsSpelledSendable() throws {
        var violations: [String] = []
        for (path, code) in try swiftSources() {
            for h in try scan(code).violations {
                violations.append("\(path):\(h.line) \(h.api) on queue `\(h.queue)`")
            }
        }
        XCTAssertEqual(violations, [], """
            A `DispatchSource` handler, a `requestMediaDataWhenReady(on:)` block, a CoreMIDI \
            block, a HealthKit handler or a CoreHaptics handler inside a `@MainActor` class, on a \
            queue other than \
            `.main`, is not spelled `@Sendable`: \(violations). Formed in a `@MainActor` \
            context, a non-`@Sendable` closure inherits MainActor isolation and the imported block type gets a dynamic isolation check at its \
            ENTRY — on the worker that check traps (`dispatch_assert_queue` → SIGTRAP) before the \
            body runs (build 2613, RetroCapture:604; the export's pull loop, SingleExport; builds \
            1769/1777, PatternEngine; the MIDI receive block, MIDIInput; the HealthKit query \
            handlers, EchoelBioEngine; the haptic reset/stopped handlers, HapticEngine). Spell the closure `{ @Sendable … }`, box what it \
            mutates (`ExportRenderCounters`), keep the callee `nonisolated` — or put the work on \
            `.main`.
            """)
    }

    /// 2 — the crash site is inside the rule's domain (else claim 1 could go green vacuously).
    func testTheCrashSiteIsInsideTheRulesDomain() throws {
        let code = try read(Self.retro)
        let v = try scan(code)
        XCTAssertTrue(v.isMainActorClass, """
            RetroCapture is no longer matched as a `@MainActor` class — the rule no longer reaches \
            it; re-derive whether the drain handler still needs `@Sendable` before trusting claim 1.
            """)
        XCTAssertTrue(v.queues.contains("writeQueue"), """
            the drain timer is no longer made on `writeQueue` (queues: \(v.queues)). If it moved to \
            `.main`, file I/O moved to the main thread — #1413 put it on `writeQueue` on purpose.
            """)
        XCTAssertGreaterThanOrEqual(v.handlers.count, 1, "no `setEventHandler` closure in RetroCapture")
        XCTAssertTrue(code.contains("nonisolated private func drainToDisk()"), """
            `drainToDisk` is no longer `nonisolated` — then `@Sendable` on the handler is not enough \
            (the compiler will say so): the drain belongs on `.main`, or the callee back off the actor.
            """)
    }

    /// 3 — the rule can fail for its named reason (#367) and for nothing else (#364).
    func testTheRuleFiresOnlyForTheOffMainIsolatedUnmarkedTriple() throws {
        let offMainIsolated = """
            @MainActor @Observable
            final class Owner {
                func arm() {
                    let t = DispatchSource.makeTimerSource(queue: workQueue)
                    t.setEventHandler { [weak self] in self?.tick() }
                }
            }
            """
        XCTAssertEqual(try scan(offMainIsolated).violations.count, 1,
                       "the 2613 shape must be a violation (#367)")

        let offMainSendable = offMainIsolated
            .replacingOccurrences(of: "{ [weak self] in", with: "{ @Sendable [weak self] in")
        XCTAssertEqual(try scan(offMainSendable).violations.count, 0,
                       "`@Sendable` is the repair; it must satisfy the rule")

        let mainIsolated = offMainIsolated
            .replacingOccurrences(of: "queue: workQueue", with: "queue: .main")
        XCTAssertEqual(try scan(mainIsolated).violations.count, 0, """
            a `.main` handler may stay isolated — `MainActor.assumeIsolated` inside it is the \
            correct pattern (#364)
            """)

        let defaultQueue = offMainIsolated
            .replacingOccurrences(of: "(queue: workQueue)", with: "()")
        XCTAssertEqual(try scan(defaultQueue).violations.count, 1,
                       "no `queue:` means a global queue — off-main")

        let nonIsolatedOwner = """
            final class Owner: NSObject, @unchecked Sendable {
                func arm() {
                    let t = DispatchSource.makeTimerSource(queue: workQueue)
                    t.setEventHandler { [weak self] in
                        Task { @MainActor in
                            self?.publish()
                        }
                    }
                }
            }
            """
        let v = try scan(nonIsolatedOwner)
        XCTAssertFalse(v.isMainActorClass, "`Task { @MainActor in` must not read as a `@MainActor` class")
        XCTAssertEqual(v.violations.count, 0, """
            a closure formed in a non-isolated class inherits no isolation; the rule must not reach \
            it (#364) — CameraCapture is this shape
            """)

        // The second API, same triple.
        let mediaIsolated = """
            @MainActor @Observable
            final class Exporter {
                func render() {
                    input.requestMediaDataWhenReady(on: DispatchQueue(label: "x.export")) {
                        while input.isReadyForMoreMediaData { pull() }
                    }
                }
            }
            """
        let media = try scan(mediaIsolated)
        XCTAssertEqual(media.handlers.map(\.queue), ["DispatchQueue(label: \"x.export\")"],
                       "the queue is read from the `on:` argument itself (handlers: \(media.handlers))")
        XCTAssertEqual(media.violations.count, 1, "the SingleExport shape must be a violation (#367)")

        let mediaSendable = mediaIsolated
            .replacingOccurrences(of: "\"x.export\")) {", with: "\"x.export\")) { @Sendable in")
        XCTAssertEqual(try scan(mediaSendable).violations.count, 0,
                       "`@Sendable` is the repair for this API too; it must satisfy the rule")

        let mediaMain = mediaIsolated
            .replacingOccurrences(of: "on: DispatchQueue(label: \"x.export\")", with: "on: .main")
        XCTAssertEqual(try scan(mediaMain).violations.count, 0,
                       "a `.main` media-ready block may stay isolated (#364)")

        let mediaGlobal = mediaIsolated
            .replacingOccurrences(of: "on: DispatchQueue(label: \"x.export\")", with: "on: DispatchQueue.global(qos: .utility)")
        XCTAssertEqual(try scan(mediaGlobal).violations.count, 1,
                       "a global queue is off-main; a call with its own parentheses must still be seen")

        // The third API family, same triple — CoreMIDI picks the thread.
        let midiIsolated = """
            @MainActor @Observable
            final class Input {
                func setup() {
                    let s = MIDIInputPortCreateWithProtocol(
                        client,
                        "In" as CFString,
                        ._2_0,
                        &port
                    ) { [weak self] list, _ in
                        self?.parse(list)
                    }
                }
            }
            """
        let midi = try scan(midiIsolated)
        XCTAssertEqual(midi.handlers.map(\.api), ["MIDIInputPortCreateWithProtocol"],
                       "a trailing receive block after a multi-line argument list must be seen (handlers: \(midi.handlers))")
        XCTAssertEqual(midi.violations.count, 1, "the MIDIInput shape must be a violation (#367)")

        let midiSendable = midiIsolated
            .replacingOccurrences(of: ") { [weak self] list, _ in", with: ") { @Sendable [weak self] list, _ in")
        XCTAssertEqual(try scan(midiSendable).violations.count, 0,
                       "`@Sendable` is the repair for a CoreMIDI block too; it must satisfy the rule")

        let midiNoBlock = """
            @MainActor @Observable
            final class Output {
                func setup() {
                    let s = MIDIClientCreateWithBlock("Out" as CFString, &client, nil)
                    guard s == noErr else { return }
                }
            }
            """
        XCTAssertEqual(try scan(midiNoBlock).handlers.count, 0, """
            a CoreMIDI create call with no trailing closure is not a handler — the next statement's \
            `{` must not be read as one (MIDIOutput is this shape, #364)
            """)

        // The fourth API family — HealthKit, read only where HealthKit is imported.
        let healthIsolated = """
            import HealthKit
            @MainActor @Observable
            final class Engine {
                func start(store: HKHealthStore) {
                    let q = HKAnchoredObjectQuery(
                        type: hrType,
                        predicate: predicate,
                        anchor: nil,
                        limit: HKObjectQueryNoLimit
                    ) { [weak self] _, samples, _, _, _ in
                        self?.process(samples)
                    }
                    store.save(samples) { _, _ in }
                }
            }
            """
        let health = try scan(healthIsolated)
        XCTAssertEqual(health.handlers.map(\.api), ["HKAnchoredObjectQuery", ".save"],
                       "both HealthKit trailing closures must be seen (handlers: \(health.handlers))")
        XCTAssertEqual(health.violations.count, 2, "the EchoelBioEngine + HealthKitWriter shapes must be violations (#367)")

        let healthSendable = healthIsolated
            .replacingOccurrences(of: ") { [weak self] _, samples, _, _, _ in", with: ") { @Sendable [weak self] _, samples, _, _, _ in")
            .replacingOccurrences(of: "store.save(samples) { _, _ in }", with: "store.save(samples) { @Sendable _, _ in }")
        XCTAssertEqual(try scan(healthSendable).violations.count, 0,
                       "`@Sendable` is the repair for a HealthKit handler too; it must satisfy the rule")

        let notHealthKit = healthIsolated.replacingOccurrences(of: "import HealthKit\n", with: "")
        XCTAssertEqual(try scan(notHealthKit).handlers.count, 0, """
            without `import HealthKit` a `.save(…) {` is somebody else's API — the needle must not \
            read it (#364)
            """)

        // The fifth API family — CoreHaptics handler ASSIGNMENTS, read only where it is imported.
        let hapticIsolated = """
            import CoreHaptics
            @MainActor
            public final class Haptics {
                func start() {
                    let e = try CHHapticEngine()
                    e.resetHandler = { [weak self] in
                        Task { @MainActor in self?.restart() }
                    }
                    e.stoppedHandler = { [weak self] _ in
                        Task { @MainActor in self?.markStopped() }
                    }
                }
            }
            """
        let haptic = try scan(hapticIsolated)
        XCTAssertEqual(haptic.handlers.map(\.api), ["resetHandler", "stoppedHandler"],
                       "both handler assignments must be seen (handlers: \(haptic.handlers))")
        XCTAssertEqual(haptic.violations.count, 2, "the HapticEngine shape must be two violations (#367)")

        let hapticSendable = hapticIsolated
            .replacingOccurrences(of: "e.resetHandler = { [weak self] in", with: "e.resetHandler = { @Sendable [weak self] in")
            .replacingOccurrences(of: "e.stoppedHandler = { [weak self] _ in", with: "e.stoppedHandler = { @Sendable [weak self] _ in")
        XCTAssertEqual(try scan(hapticSendable).violations.count, 0,
                       "`@Sendable` is the repair for a CoreHaptics handler too; it must satisfy the rule")

        let notCoreHaptics = hapticIsolated.replacingOccurrences(of: "import CoreHaptics\n", with: "")
        XCTAssertEqual(try scan(notCoreHaptics).handlers.count, 0, """
            without `import CoreHaptics` a `.resetHandler = {` is somebody else's property — the \
            needle must not read it (#364)
            """)
    }

    /// 4 — the two exemptions are exercised by real owners, not vacuous.
    func testTheExemptionsAreExercisedByRealOwners() throws {
        for path in Self.mainQueueOwners {
            let v = try scan(try read(path))
            XCTAssertTrue(v.isMainActorClass,
                          "\(path) is no longer a `@MainActor` class; pick another `.main` owner for this anchor")
            XCTAssertTrue(v.handlers.contains { Self.isMain($0.queue) },
                          "\(path) has no `.main` handler any more (handlers: \(v.handlers.map(\.queue)))")
            XCTAssertEqual(v.violations.count, 0, "\(path): \(v.violations.map(\.line))")
        }
        for path in Self.nonIsolatedOffMainOwners {
            let v = try scan(try read(path))
            XCTAssertFalse(v.isMainActorClass, """
                \(path) became a `@MainActor` class — then its off-main handlers need `@Sendable`, \
                and claim 1 says so; pick another non-isolated owner for this anchor
                """)
            XCTAssertTrue(v.handlers.contains { !Self.isMain($0.queue) },
                          "\(path) has no off-main handler any more (handlers: \(v.handlers.map(\.queue)))")
            XCTAssertEqual(v.violations.count, 0, "\(path): \(v.violations.map(\.line))")
        }
    }

    /// 5 — the arming rung stands BEFORE `drain.resume()` (CLAUDE.md, Lebenszyklus-Leiter).
    func testTheArmingRungStandsBeforeTheResume() throws {
        let code = try read(Self.retro)
        let rung = "EchoelCrashLog.breadcrumb(\"retro: recording armed"
        guard let rungRange = code.range(of: rung) else {
            return XCTFail("""
                ANCHOR MISSING: the arming rung `\(rung)` is gone from RetroCapture (#454). The \
                2613 log went silent for 200 ms before the trap because this file wrote nothing.
                """)
        }
        let resumes = code.components(separatedBy: "drain.resume()").count - 1
        XCTAssertEqual(resumes, 1, "`drain.resume()` must occur once for this ordering to mean anything (#408)")
        guard let resumeRange = code.range(of: "drain.resume()") else {
            return XCTFail("ANCHOR MISSING: `drain.resume()` is gone from RetroCapture (#454)")
        }
        XCTAssertLessThan(rungRange.lowerBound, resumeRange.lowerBound, """
            the rung stands BEFORE its call: a witness behind the step sees nothing when the step dies
            """)
    }

    /// 6 — the second site (the export's pull loop) is inside the rule's domain, and the state the
    /// block mutates is boxed (else claim 1 could go green by the needle ceasing to match the file).
    func testTheMediaReadyBlockSiteIsInsideTheRulesDomain() throws {
        let code = try read(Self.export)
        let v = try scan(code)
        XCTAssertTrue(v.isMainActorClass, """
            SingleExport is no longer matched as a `@MainActor` class — the rule no longer reaches \
            it; re-derive whether the pull block still needs `@Sendable` before trusting claim 1.
            """)
        let media = v.handlers.filter { $0.api == "requestMediaDataWhenReady" }
        XCTAssertEqual(media.count, 1, """
            SingleExport has \(media.count) media-ready blocks; this claim pins exactly one, the \
            render pull loop (handlers: \(v.handlers.map { ($0.api, $0.queue) }))
            """)
        XCTAssertTrue(media.allSatisfy { $0.queue.hasPrefix("DispatchQueue(label:") }, """
            the pull loop left its own serial queue (queues: \(media.map(\.queue))). On `.main` the \
            export would encode minutes of audio on the main thread.
            """)
        XCTAssertTrue(media.allSatisfy(\.sendable), """
            the export's pull block is no longer `@Sendable` — the 2613 trap class at the ENTRY of \
            the render phase, minutes into an export the user waited for.
            """)
        XCTAssertTrue(code.contains("final class ExportRenderCounters: @unchecked Sendable"), """
            the counters box is gone. A `@Sendable` block cannot mutate captured `var`s; the two \
            counters live in ONE `@unchecked Sendable` box because the block runs on one serial queue.
            """)
        XCTAssertTrue(code.contains("nonisolated static func applyGain("), """
            `applyGain` is no longer `nonisolated` — the `@Sendable` block calls it off the actor \
            (the compiler says so too; this names the reason).
            """)
    }

    /// 7 — the third site (the MIDI blocks) is inside the rule's domain and repaired (else claim 1
    /// could go green by the needle ceasing to match the file).
    func testTheCoreMIDIBlocksAreInsideTheRulesDomain() throws {
        let code = try read(Self.midiIn)
        let v = try scan(code)
        XCTAssertTrue(v.isMainActorClass, """
            MIDIInput is no longer matched as a `@MainActor` class — the rule no longer reaches it; \
            re-derive whether its CoreMIDI blocks still need `@Sendable` before trusting claim 1.
            """)
        let midi = v.handlers.filter { $0.queue == Self.coreMIDIThread }
        XCTAssertEqual(Set(midi.map(\.api)), ["MIDIClientCreateWithBlock", "MIDIInputPortCreateWithProtocol"], """
            MIDIInput's two CoreMIDI blocks are not both seen (handlers: \(v.handlers.map { ($0.api, $0.line) })). \
            If one moved behind a stored closure, the needle no longer reaches it — re-anchor first.
            """)
        XCTAssertTrue(midi.allSatisfy(\.sendable), """
            a MIDI block is no longer `@Sendable` — the first note, clock tick or CC from any \
            connected source traps at the closure's entry on CoreMIDI's thread.
            """)
        XCTAssertTrue(code.contains("private nonisolated func handleMIDIEvents("), """
            `handleMIDIEvents` is no longer `nonisolated` — the `@Sendable` receive block calls it \
            off the actor (the compiler says so too; this names the reason).
            """)
    }

    /// 8 — the fourth site (the HealthKit handlers) is inside the rule's domain and repaired (else
    /// claim 1 could go green by the needle ceasing to match the files).
    func testTheHealthKitHandlersAreInsideTheRulesDomain() throws {
        let engine = try read(Self.bioEngine)
        let e = try scan(engine)
        XCTAssertTrue(e.isMainActorClass, """
            EchoelBioEngine is no longer matched as a `@MainActor` class — re-derive whether its \
            query handlers still need `@Sendable` before trusting claim 1.
            """)
        let queries = e.handlers.filter { $0.api == "HKAnchoredObjectQuery" }
        XCTAssertEqual(queries.count, 3, """
            EchoelBioEngine has \(queries.count) `HKAnchoredObjectQuery(` trailing handlers; this \
            claim pins the three (heart rate, HRV, breath) — re-anchor if one moved behind a name.
            """)
        XCTAssertTrue(queries.allSatisfy(\.sendable), """
            a HealthKit query handler is no longer `@Sendable` — anyone who allowed Apple Health \
            traps on the first result of every launch (`startIfAlreadyAuthorized`).
            """)
        XCTAssertTrue(engine.contains("private nonisolated func processHeartRateSamples("), """
            `processHeartRateSamples` is no longer `nonisolated` — the `@Sendable` handler calls it \
            off the actor (the compiler says so too; this names the reason).
            """)
        let writer = try scan(try read(Self.healthWriter))
        XCTAssertTrue(writer.isMainActorClass, "HealthKitWriter is no longer matched as a `@MainActor` class")
        let saves = writer.handlers.filter { $0.api == ".save" }
        XCTAssertEqual(saves.count, 1, "HealthKitWriter's one save completion is not seen (handlers: \(writer.handlers.map(\.api)))")
        XCTAssertTrue(saves.allSatisfy(\.sendable), """
            the Health write's completion is no longer `@Sendable` — every opted-in write would trap \
            when HealthKit answers on its background queue.
            """)
    }

    /// 9 — the fifth site (the CoreHaptics handlers) is inside the rule's domain and repaired
    /// (else claim 1 could go green by the needle ceasing to match the file).
    func testTheHapticHandlersAreInsideTheRulesDomain() throws {
        let code = try read(Self.hapticEngine)
        let v = try scan(code)
        XCTAssertTrue(v.isMainActorClass, """
            HapticEngine is no longer matched as a `@MainActor` class — re-derive whether its \
            reset/stopped handlers still need `@Sendable` before trusting claim 1.
            """)
        let haptic = v.handlers.filter { $0.queue == Self.coreHapticsQueue }
        XCTAssertEqual(haptic.map(\.api), ["resetHandler", "stoppedHandler"], """
            HapticEngine's two CoreHaptics handler assignments are not both seen \
            (handlers: \(v.handlers.map { ($0.api, $0.line) })). If one moved behind a stored \
            closure, the needle no longer reaches it — re-anchor first.
            """)
        XCTAssertTrue(haptic.allSatisfy(\.sendable), """
            a haptic handler is no longer `@Sendable` — CoreHaptics calls it on its own queue after \
            the idle shutdown (`isAutoShutdownEnabled`) or a server reset, and an unmarked closure \
            formed in this `@MainActor` class inherits MainActor isolation.
            """)
        XCTAssertTrue(code.contains("isAutoShutdownEnabled = true"), """
            the idle shutdown is off — then the stopped handler fires only on a real stop. The \
            pin still holds, but this claim's message names the wrong trigger; re-derive it.
            """)
    }

    /// 10 — every Metal command-buffer handler literal in `Sources/` is `@Sendable`, whatever its
    /// owner's isolation: Metal calls it on its own thread, and the owner's isolation can come from
    /// an SDK protocol (`MTKViewDelegate`) this scan cannot read.
    func testEveryMetalCommandBufferHandlerIsSpelledSendable() throws {
        let needle = try NSRegularExpression(pattern: Self.metalHandler)
        func unmarked(_ code: String) -> [Int] {
            let ns = code as NSString
            return needle.matches(in: code, range: NSRange(location: 0, length: ns.length))
                .filter { $0.range(at: 2).location == NSNotFound }
                .map { ns.substring(to: $0.range.location).components(separatedBy: "\n").count }
        }
        let fixture = "buffer.addCompletedHandler { done in\n    tap.deliver(frame)\n}"
        XCTAssertEqual(unmarked(fixture).count, 1, "an unmarked completion handler must be seen (#367)")
        XCTAssertEqual(unmarked(fixture.replacingOccurrences(of: "{ done in", with: "{ @Sendable done in")).count, 0,
                       "`@Sendable` is the repair; it must satisfy the needle")
        var sites = 0
        var violations: [String] = []
        for (path, code) in try swiftSources() {
            let ns = code as NSString
            sites += needle.numberOfMatches(in: code, range: NSRange(location: 0, length: ns.length))
            violations += unmarked(code).map { "\(path):\($0)" }
        }
        XCTAssertGreaterThanOrEqual(sites, 1, """
            no Metal command-buffer handler literal in Sources/ — the broadcast frame tap in \
            `\(Self.metalView)` moved behind a name; re-anchor before trusting this claim
            """)
        XCTAssertEqual(violations, [], """
            a Metal command-buffer handler is not spelled `@Sendable`: \(violations). Metal calls it \
            on its own completion thread; if its owner is MainActor-isolated (spelled, or inferred \
            from an SDK protocol), an unmarked closure inherits that isolation and its entry check \
            traps there — the 2613 shape.
            """)
    }

    // MARK: helpers

    private struct AnchorMissing: Error { let name: String }

    private func root() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        return url
    }

    private func read(_ relativePath: String) throws -> String {
        guard let text = try? String(contentsOf: root().appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing(name: relativePath)
        }
        return SourceText.codeOnly(text)
    }

    /// Every `.swift` file under `Sources/`, comment-stripped. A walk that finds nothing FAILS:
    /// an empty walk would pass claim 1 vacuously.
    private func swiftSources() throws -> [(String, String)] {
        let sources = root().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil) else {
            XCTFail("ANCHOR MISSING: cannot walk Sources/ (#454)")
            throw AnchorMissing(name: "Sources/")
        }
        var out: [(String, String)] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            guard let cut = url.path.range(of: "/Sources/", options: .backwards) else { continue }
            out.append(("Sources/" + String(url.path[cut.upperBound...]), SourceText.codeOnly(text)))
        }
        guard out.count > 100 else {
            XCTFail("the Sources/ walk found only \(out.count) Swift files — claim 1 cannot be trusted")
            throw AnchorMissing(name: "Sources/ walk")
        }
        return out
    }
}
