// APrewarmedLaunchIsNotCountedUntilItsSceneTests.swift
// G10 (founder log 2026-10-16, v10.79.509 build 2634): `LaunchGuard: normal launch —
// unconfirmed streak 1` · `launch context: prewarm=1 … age=339ms` — and nothing after it. iOS
// had PREWARMED the process: it runs an app's launch sequence speculatively, before anyone
// taps the icon, and may discard the process unused. `beginLaunch()` counted that run, so the
// counter stayed raised without a crash and the next REAL launch opened Safe Mode — the
// "silent start" of build 2621, which also ended at this line and was followed by Safe Mode.
// Now a prewarmed launch decides its verdict but writes nothing; it is counted when its first
// scene builds (`EchoelmusicApp.countPrewarmedLaunchAtFirstScene`).
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claims 1–3 are END-TO-END on `LaunchGuard` itself (pure `UserDefaults` arithmetic).
//     A "new process" is modelled by the next `beginLaunch` — the counter persists, the
//     per-process flags are rewritten by it, exactly as a fresh process would start them.
//   · Claim 4 is a SOURCE-TEXT SCAN of `EchoelmusicApp.swift`: the scene counts first.
//   · NOT CLAIMED (DEVICE PROBE): that iOS never evaluates the scene during a prewarm. Apple
//     documents prewarming as stopping before `UIApplicationMain`; if a scene were built
//     anyway, the count would simply happen there — the old behaviour, no worse.
//     NEEDS-FOUNDER-VERIFY (G10): after this build, does a launch whose diag log reads
//     `prewarm=1` and ends early still open Safe Mode on the next tap?
//
// HONEST GRADING against the parent (§3): the file does not compile there —
// `beginLaunch(prewarmed:)`, `countPrewarmedLaunch()` and `launchCountDeferred` are new, so no
// assertion has a verdict on the parent. Hand-transcribed: on the parent a prewarm counted, so
// claim 1 is the REGRESSION (the next launch would be streak 2 → Safe Mode). Claims 2 and 3
// are COUNTERWEIGHTS — the guard still catches a crash after the scene and after a real
// launch, so "fix the false positive" cannot be implemented by gutting the guard. Claim 4 is a
// FORWARD guard. Mutants: count in `beginLaunch` regardless (1) · never count the prewarm (2) ·
// count twice per scene (2) · verdict computed after the deferral (3).

import Foundation
import XCTest
// `@testable` IS LOAD-BEARING: `resetForTesting()` and the new members are internal.
@testable import Echoelmusic

@MainActor
final class APrewarmedLaunchIsNotCountedUntilItsSceneTests: XCTestCase {

    // `resetForTesting()`, not `reset()` — the bundle runs inside the host app, and a stale
    // `cachedSafeMode` would flip the live app into Safe Mode (see LaunchGuardSmokeTests).
    override func setUp() async throws { LaunchGuard.resetForTesting() }
    override func tearDown() async throws { LaunchGuard.resetForTesting() }

    // MARK: 1 — a prewarm that iOS discards is not a failed launch

    func testADiscardedPrewarmDoesNotPushTheNextLaunchIntoSafeMode() {
        LaunchGuard.beginLaunch(prewarmed: true)          // iOS warms the process …
        XCTAssertTrue(LaunchGuard.launchCountDeferred)
        XCTAssertEqual(LaunchGuard.unconfirmedCount, 0, "a prewarm writes nothing")
        // … and discards it. The user taps the icon: a fresh, normal launch.
        LaunchGuard.beginLaunch(prewarmed: false)
        XCTAssertFalse(LaunchGuard.isSafeMode, """
            A prewarmed process that never reached a scene left the counter raised, and the \
            next real launch opened Safe Mode for a user who had seen nothing fail (G10).
            """)
        XCTAssertEqual(LaunchGuard.unconfirmedCount, 1)
        XCTAssertFalse(LaunchGuard.launchCountDeferred, "a normal launch defers nothing")
    }

    // MARK: 2 — counterweight: a prewarm that becomes a real launch IS counted, once

    func testAPrewarmThatReachesItsSceneIsCountedExactlyOnce() {
        LaunchGuard.beginLaunch(prewarmed: true)
        XCTAssertTrue(LaunchGuard.countPrewarmedLaunch(), "the first scene counts the launch")
        XCTAssertFalse(LaunchGuard.countPrewarmedLaunch(), "a second scene build counts nothing")
        XCTAssertEqual(LaunchGuard.unconfirmedCount, 1)
        // It then crashes before confirming healthy; the next launch must be protected.
        LaunchGuard.beginLaunch(prewarmed: false)
        XCTAssertTrue(LaunchGuard.isSafeMode, """
            A prewarmed launch that a person opened and that crashed must still escalate — \
            otherwise the fix trades a false positive for a missed real one.
            """)
        XCTAssertFalse(LaunchGuard.countPrewarmedLaunch(), "a normal launch has nothing deferred")
    }

    // MARK: 3 — counterweight: the verdict of a prewarmed launch still reads the last crash

    func testAPrewarmAfterACrashStillOpensSafeMode() {
        LaunchGuard.beginLaunch(prewarmed: false)         // a real launch that crashed
        LaunchGuard.beginLaunch(prewarmed: true)          // the next process happens to be prewarmed
        XCTAssertTrue(LaunchGuard.isSafeMode, """
            The verdict of a prewarmed launch must be decided as for any launch — the previous \
            run did not confirm healthy.
            """)
        XCTAssertEqual(LaunchGuard.unconfirmedCount, 1, "and the prewarm itself still wrote nothing")
    }

    // MARK: 4 — the app reads the prewarm flag and counts at the top of its first scene

    func testTheAppCountsAPrewarmedLaunchWhenItsSceneBuilds() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path)
        else { throw XCTSkip("source tree not present under \(root.path)") }
        let app = SourceText.codeOnly(try String(contentsOf: root.appendingPathComponent(
            "Sources/Echoelmusic/EchoelmusicApp.swift"), encoding: .utf8))
        let guardFile = SourceText.codeOnly(try String(contentsOf: root.appendingPathComponent(
            "Sources/Echoelmusic/Core/LaunchGuard.swift"), encoding: .utf8))
        XCTAssertTrue(guardFile.contains("environment[\"ActivePrewarm\"] == \"1\""),
                      "`beginLaunch()` reads the flag iOS sets on a prewarmed launch")
        guard let scene = app.range(of: "var body: some Scene {"),
              let count = app.range(of: "let _ = Self.countPrewarmedLaunchAtFirstScene()",
                                    range: scene.upperBound..<app.endIndex),
              let verdict = app.range(of: "if LaunchGuard.isSafeMode",
                                      range: scene.upperBound..<app.endIndex) else {
            return XCTFail("ANCHOR MISSING: the scene body, its prewarm count or its Safe-Mode branch (#408)")
        }
        XCTAssertLessThan(count.lowerBound, verdict.lowerBound, """
            The prewarm must be counted before the scene builds anything — a crash at first \
            render is the black-screen class this guard exists for.
            """)
    }
}
