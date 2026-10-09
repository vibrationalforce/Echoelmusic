// TheAppSaysWhatItCameUpWithTests.swift
// Echoel — GMMW SH-10. "Did the engine start, at what rate, which body source ran, which outputs
// stream, how much memory is left, how hot is the phone?" — a founder log answered that only by
// reading scattered lines, and three of the facts were in no line at all. Now the studio writes ONE
// `self-check:` line, once, `SelfCheckLine.launchDelaySeconds` after its deferred starts, and once
// after each engine self-heal that recovered. The line is a pure function of `SelfCheckFacts`.
//
// WHAT IT PINS (Tests/CISmoke/CLAUDE.md §1) — claims 1–4 are END-TO-END on `SelfCheckLine`
// (internal, Foundation-only, through `@testable`) and on `EchoelCrashLog`'s two log readers;
// claims 5–7 are SOURCE-TEXT SCANS (the app gathers its facts from objects a bundle cannot build,
// and the self-heal fires only when a real route or configuration change breaks the engine).
// DEVICE PROBE, open: that the launch line shows up in an exported `echoel_diag.log` with true
// values, and that unplugging headphones mid-playback yields a `self-heal (route lost)` line.
// 1. A fixture of facts gives one exact line, field by field, in a fixed order.
// 2. Each field's other states: degraded over running, stopped, an unreadable rate, an unknown
//    headroom, empty lists, armed and on.
// 3. No fact can make the line read as a crash marker or a scene transition to the next launch.
// 4. The thermal names are the four the system defines.
// 5. The app writes it at launch from its OWN task, after the deferred starts and before the
//    steady sleep, after `launchDelaySeconds`; and on a recovered self-heal through the engine's
//    hook. Two triggers, each a plain call — no timer, no loop, no precondition in the writer.
// 6. The engine fires the hook once, after its `self-heal recovered` rung, only on the branch
//    where the engine runs again.
// 7. The headroom is the same reading as the SH-6 `memory:` line, read now — not the poll's copy.
//
// HONEST GRADING (§3). The file names new types — it does not compile on its parent (`daf2475`),
// so every claim is FORWARD: no assertion here has a verdict there, and the scans of claims 5–7
// are red there by ANCHOR ABSENCE (no writer, no hook, no fresh headroom read). Transcribed in
// Python against the worktree: the formatter is re-implemented and driven through claims 1–4; the
// scans of 5–7 run over the same `codeOnly` text. MUTANTS, each red for its named reason: the
// running test before the degraded one → 2; no neutralising → 3; a field out of order → 1; the
// launch line written inside the steady-confirm task's own sleep → 5; a repeating timer in the
// writer → 5; a `precondition` in the writer → 5; the hook called before the rung → 6; the hook
// on the give-up path → 6; `.used` in place of `.available` → 7.

import Foundation
import XCTest
@testable import Echoelmusic

private struct SelfCheckAnchorMissing: Error, CustomStringConvertible {
    let reason: String
    var description: String { reason }
}

final class TheAppSaysWhatItCameUpWithTests: XCTestCase {

    private static let app = "Sources/Echoelmusic/EchoelmusicApp.swift"
    private static let engine = "Sources/Echoelmusic/Audio/AudioEngine.swift"
    private static let memory = "Sources/Echoelmusic/Core/MemoryPressureHandler.swift"

    private func fixture() -> SelfCheckFacts {
        SelfCheckFacts(trigger: "launch",
                       engineRunning: true,
                       engineDegraded: false,
                       sampleRate: 48_000,
                       bodyVoiceArmed: false,
                       bioSources: ["camera"],
                       safeMode: false,
                       streak: 1,
                       headroomBytes: 1532 * 1_048_576 + 1000,
                       thermal: "nominal",
                       lowPower: false,
                       outputs: ["osc", "artnet"])
    }

    // MARK: 1 — one exact line

    func testAFixtureGivesOneExactLine() {
        XCTAssertEqual(SelfCheckLine.format(fixture()),
                       "self-check: launch · engine running 48000 Hz · body voice off · bio camera · "
                       + "safe mode off · streak 1 · headroom 1532 MB · thermal nominal · low power off · "
                       + "outputs osc+artnet")
    }

    // MARK: 2 — every field's other states

    func testEachFieldSaysItsOtherStates() {
        var facts = fixture()
        facts.engineDegraded = true
        XCTAssertEqual(fields(of: facts)[1], "engine degraded",
                       "degraded wins over running — a degraded engine may still report running")
        facts.engineDegraded = false
        facts.engineRunning = false
        XCTAssertEqual(fields(of: facts)[1], "engine stopped")
        facts.engineRunning = true
        for unreadable in [0, -1, Double.nan, Double.infinity] {
            facts.sampleRate = unreadable
            XCTAssertEqual(fields(of: facts)[1], "engine running ? Hz", "rate \(unreadable)")
        }
        facts.sampleRate = 44_100.4
        XCTAssertEqual(fields(of: facts)[1], "engine running 44100 Hz")
        facts.headroomBytes = nil
        facts.outputs = []
        facts.bodyVoiceArmed = true
        facts.safeMode = true
        facts.lowPower = true
        facts.streak = 3
        facts.bioSources = ["strap", "demo"]
        XCTAssertEqual(Array(fields(of: facts).dropFirst(2)),
                       ["body voice armed", "bio strap+demo", "safe mode on", "streak 3", "headroom ?",
                        "thermal nominal", "low power on", "outputs none"])
        facts.bioSources = []
        XCTAssertEqual(fields(of: facts)[3], "bio none")
    }

    // MARK: 3 — nothing reads as something else

    func testNoFactMakesTheLineReadAsACrashOrASceneTransition() {
        var facts = fixture()
        facts.trigger = "self-heal (\(EchoelCrashLog.crashMarker) \(EchoelCrashLog.startTappedMarker) "
            + "\(EchoelCrashLog.sceneTransition(from: "active", to: "inactive")))"
        facts.bioSources = [EchoelCrashLog.confirmedHealthyMarker]
        let line = SelfCheckLine.format(facts)
        XCTAssertTrue(line.hasPrefix(SelfCheckLine.prefix))
        XCTAssertFalse(EchoelCrashLog.looksLikeUnseenCrash(line), "`\(line)` reads as a crash to the next launch")
        XCTAssertNil(EchoelCrashLog.lastScenePhase(in: line), "`\(line)` reads as a scene transition")
        XCTAssertFalse(line.contains(EchoelCrashLog.confirmedHealthyMarker), "`\(line)` reads as a launch confirm")
        XCTAssertFalse(EchoelCrashLog.looksLikeUnseenCrash(SelfCheckLine.format(fixture())))
    }

    // MARK: 4 — thermal names

    func testTheThermalNamesAreTheFourTheSystemDefines() {
        XCTAssertEqual(SelfCheckLine.thermalName(.nominal), "nominal")
        XCTAssertEqual(SelfCheckLine.thermalName(.fair), "fair")
        XCTAssertEqual(SelfCheckLine.thermalName(.serious), "serious")
        XCTAssertEqual(SelfCheckLine.thermalName(.critical), "critical")
    }

    // MARK: 5 — the app writes it twice, never periodically

    func testTheAppWritesItAtLaunchAndAfterARecoveredSelfHeal() throws {
        let app = try source(Self.app)
        XCTAssertEqual(occurrences(of: "writeSelfCheck(trigger: \"", in: app), 2, "two triggers: launch and self-heal")
        XCTAssertEqual(occurrences(of: "audioEngine.onSelfHealRecovered = {", in: app), 1, "one hook, one owner")

        let issued = try anchor("deferredStartsIssuedAt = ContinuousClock.now", in: app)
        let steady = try anchor("try? await Task.sleep(for: .seconds(LaunchGuard.steadyConfirmSeconds))", in: app)
        let hook = try anchor("audioEngine.onSelfHealRecovered = {", in: app)
        let task = try anchor("Task { @MainActor in", in: app, after: issued.upperBound)
        let delay = try anchor("try? await Task.sleep(for: .seconds(SelfCheckLine.launchDelaySeconds))", in: app)
        let launch = try anchor("writeSelfCheck(trigger: \"launch\")", in: app)
        let healed = try anchor("writeSelfCheck(trigger: \"self-heal (\\(reason))\")", in: app)
        XCTAssertTrue(issued.upperBound <= hook.lowerBound && hook.lowerBound < healed.lowerBound
                      && healed.lowerBound < task.lowerBound && task.lowerBound < delay.lowerBound
                      && delay.lowerBound < launch.lowerBound && launch.lowerBound < steady.lowerBound, """
            The order is: deferred starts issued → the self-heal hook → its OWN task that sleeps \
            `launchDelaySeconds` and writes the launch line → the steady-confirm sleep. Inside the \
            startup task's own sleep it would move the SH-1 confirm; after it, the line would come \
            ten seconds late.
            """)

        let writer = try block(after: "private func writeSelfCheck(trigger: String) {", in: app)
        XCTAssertEqual(occurrences(of: "EchoelCrashLog.breadcrumb(SelfCheckLine.format(facts))", in: writer), 1,
                       "the writer writes exactly one line")
        for forbidden in ["Timer", "repeating", "while ", "Task.sleep", "precondition", "assert", "fatalError", "!."] {
            XCTAssertFalse(writer.contains(forbidden), """
                `\(forbidden)` in the writer. It is written once per trigger, never periodically, and \
                asserts nothing at run time — a fact it cannot read is printed as `?`.
                """)
        }
        for fact in ["audioEngine.isRunning", "audioEngine.degraded", "audioEngine.sampleRate", "bioVoice.isArmed",
                     "LaunchGuard.isSafeMode", "LaunchGuard.unconfirmedCount", "info.thermalState",
                     "info.isLowPowerModeEnabled", "MemoryPressureHandler.shared.currentHeadroomBytes()"] {
            XCTAssertTrue(writer.contains(fact), "the writer no longer reads `\(fact)`")
        }
    }

    // MARK: 6 — the engine fires the hook after it recovered

    func testTheEngineFiresTheHookOnceAfterItsRecoveredRung() throws {
        let engine = try source(Self.engine)
        XCTAssertTrue(engine.contains("@ObservationIgnored var onSelfHealRecovered: ((String) -> Void)?"),
                      "the hook is not observed — nothing in SwiftUI may churn on it")
        XCTAssertEqual(occurrences(of: "onSelfHealRecovered?(", in: engine), 1, "one call site")
        let recover = try block(after: "private func recoverEngine(reason: String) {", in: engine)
        let branch = try block(after: "if self.masterEngine.isRunning {", in: recover)
        let rung = try anchor("self.logEngineLifecycle(\"self-heal recovered (\\(reason))\")", in: branch)
        let call = try anchor("self.onSelfHealRecovered?(reason)", in: branch)
        XCTAssertLessThan(rung.lowerBound, call.lowerBound, "the rung stands before the hook (#859)")
        let gaveUp = try anchor("self-heal gave up", in: recover)
        XCTAssertFalse(recover[recover.startIndex..<gaveUp.lowerBound].contains("onSelfHealRecovered"),
                       "a self-heal that gave up recovered nothing — no self-check there")
    }

    // MARK: 7 — the headroom, read now

    func testTheHeadroomIsTheMemoryLinesReadingReadNow() throws {
        let memory = try source(Self.memory)
        XCTAssertTrue(memory.contains("public func currentHeadroomBytes() -> Int { getMemoryStats().available }"), """
            The self-check headroom must be the SH-6 `memory:` line's reading (`.available`, this \
            process's headroom), read when asked — the poll's `availableMemoryBytes` is 0 for the \
            first five seconds, and `.used` is the #1201 category error.
            """)
    }

    // MARK: - Helpers

    /// The line's fields after the prefix, split on the one separator (index 0 = the trigger).
    /// Always ten long, so an index never traps: a missing field reads as a visible mismatch.
    private func fields(of facts: SelfCheckFacts) -> [String] {
        let line = SelfCheckLine.format(facts)
        var parts = line.dropFirst(SelfCheckLine.prefix.count).components(separatedBy: SelfCheckLine.separator)
        while parts.count < 10 { parts.append("<missing in `\(line)`>") }
        return parts
    }

    private func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    private func anchor(_ needle: String, in text: String) throws -> Range<String.Index> {
        guard let hit = text.range(of: needle) else {
            throw SelfCheckAnchorMissing(reason: "`\(needle)` is not in the scanned text — re-anchor (#454)")
        }
        return hit
    }

    private func anchor(_ needle: String, in text: String, after start: String.Index) throws -> Range<String.Index> {
        guard let hit = text.range(of: needle, range: start..<text.endIndex) else {
            throw SelfCheckAnchorMissing(reason: "`\(needle)` is not after its anchor — re-anchor (#454)")
        }
        return hit
    }

    /// The brace-matched block that opens at the first `{` at or after `key` (#408).
    private func block(after key: String, in text: String) throws -> String {
        let start = try anchor(key, in: text)
        var depth = 0
        var body = ""
        for ch in text[start.lowerBound...] {
            if ch == "{" { depth += 1 }
            if depth > 0 { body.append(ch) }
            if ch == "}" {
                depth -= 1
                if depth == 0 { break }
            }
        }
        return body
    }

    private func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        let path = root.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw SelfCheckAnchorMissing(reason: "\(relativePath) is missing while the tree is present — re-anchor (#454)")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }
}
