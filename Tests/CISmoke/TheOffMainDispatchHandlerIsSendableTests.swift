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
// THE RULE THIS FILE PINS. In a file that declares a `@MainActor` class, every `setEventHandler`
// whose source was made on a queue other than `.main` is spelled `@Sendable`. Handlers on `.main`
// may stay isolated (`MainActor.assumeIsolated` inside is the correct pattern there). Files without
// a `@MainActor` class are exempt: a closure formed in a non-isolated class inherits nothing.
//
// LIMITS (Tests/CISmoke/CLAUDE.md §1). SOURCE-TEXT SCAN over comment-stripped `Sources/`: it proves
// a spelling, never that the device does not trap. File-granular: it cannot see whether a handler
// is formed in a `nonisolated` method of a `@MainActor` class (there `@Sendable` is a no-op and still
// the honest spelling). A handler is paired with the NEAREST PRECEDING `DispatchSource.make…Source(`
// in the same file; a source created in another file, or a handler passed as a stored closure
// (`setEventHandler(handler: x)`), is not seen. A source made with no `queue:` runs on a global
// queue and counts as off-main. The `@MainActor` needle accepts only attributes and modifiers
// between it and `class`, so `Task { @MainActor in` never counts as a class.
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
// NEEDS-FOUNDER-VERIFY: Arrange → Export → WAV auf dem Gerät bis zum Teilen-Blatt durchlaufen lassen,
// und im nächsten `echoel_diag.log` die Zeile „retro: recording armed“ VOR dem Play sehen — nur das
// Telefon beweist die Aufnahme, nur das 2613-dSYM beweist, dass Frame 7/8 diese Closure waren.

import Foundation
import XCTest

final class TheOffMainDispatchHandlerIsSendableTests: XCTestCase {

    private static let retro = "Sources/Echoelmusic/Audio/RetroCapture.swift"
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

    private static let defaultQueue = "<no queue: — a global queue>"
    private static let unknownQueue = "<no DispatchSource.make…Source( above it>"

    private struct Handler { let line: Int; let queue: String; let sendable: Bool }

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
            handlers.append(Handler(line: line, queue: queue, sendable: sendable))
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
                violations.append("\(path):\(h.line) on queue `\(h.queue)`")
            }
        }
        XCTAssertEqual(violations, [], """
            A `DispatchSource` handler inside a `@MainActor` class on a queue other than `.main` is \
            not spelled `@Sendable`: \(violations). Formed in a `@MainActor` context, a non-`@Sendable` \
            closure inherits MainActor isolation and the imported block type gets a dynamic isolation \
            check at its ENTRY — on the worker that check traps (`dispatch_assert_queue` → SIGTRAP) \
            before the body runs (build 2613, RetroCapture:604; builds 1769/1777, PatternEngine). \
            Spell it `setEventHandler { @Sendable … }` and keep the callee `nonisolated` — or put \
            the timer on `.main`.
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
