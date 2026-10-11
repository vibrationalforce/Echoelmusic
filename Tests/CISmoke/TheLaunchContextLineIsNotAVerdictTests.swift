// TheLaunchContextLineIsNotAVerdictTests.swift
// Echoel — GMMW SH-2b (2026-10-11). The launch context line reads as context, never as a verdict.
//
// WHAT THIS GUARDS. Build 2621 (2026-10-10) wrote `launch v…`, `crash net…`, `image…` and the
// `LaunchGuard:` verdict, then nothing — no crash marker, no `init a: audio core`. The log could
// not say whether iOS had prewarmed the process, whether the phone had just rebooted, how long
// the process had lived or how much memory it had. SH-2b adds ONE line after the verdict that
// answers those questions (`EchoelCrashLog.launchContextLine`). Its PLACE is pinned by claim 4 of
// `TheCrashNetIsUpBeforeTheStoresTests`; THIS file pins what the line looks like and, above all,
// what it is not: every reader of a pasted log (`looksLikeUnseenCrash`, `unconfirmedRunToAttach`,
// `neutralized`) searches for markers, and a context line that happened to contain one would turn
// a quiet run into a reported crash.
//
// THE CLAIMS — END-TO-END on the pure formatter (a `static func` on an `enum`, Foundation only),
// plus one on the live reader:
//   1. All-nil → every field prints `-`, in a fixed order with fixed names. `-` is "not readable
//      here", never a value; the order is what a triager's eye learns.
//   2. A full reading prints each value with its unit, lower-case throughout.
//   3. Neither line carries a marker: not `crashMarker`, not `startTappedMarker`, not either
//      confirm/clear marker, not the scene arrow; `looksLikeUnseenCrash` says false for a log of
//      just that line, and `neutralized` returns the line unchanged (there is nothing to lower).
//   4. The live reader (`launchContextLine()` without arguments) returns a line with the prefix,
//      the seven fields, a readable `prewarm` flag and a named thermal state — on the test host.
//      The two sysctl-backed fields and memory are allowed to read `-`: a refusal is a reading
//      this guard cannot force either way, and the format already says what `-` means.
//
// ⚠️ HONEST GRADING (#433). FORWARD: this file calls `EchoelCrashLog.launchContextLine`, which
// does not exist on the parent `a4df15c` (Sources/ and Tests/ equal to `5bc17bc`), so it DOES
// NOT COMPILE there — no assertion has a verdict on the parent (§3), and it needs
// `@testable import Echoelmusic` (#1337). Transcribed in
// Python against the worktree: the formatter is re-implemented and the two literals of claims 1–2
// are produced by it; the marker set of claim 3 is read from `EchoelCrashLog.swift`. Claim 4's
// field values are not predicted — only their shape is.
//
// ⚠️ THE LIMIT. Whether the fields are READABLE on the phone — `ActivePrewarm` present, the two
// sysctls answering, `os_proc_available_memory` meaningful — is a DEVICE PROBE (FOUNDER_INBOX §2,
// G10). This file proves the line cannot lie about being a verdict, not that it tells the truth
// about the device.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheLaunchContextLineIsNotAVerdictTests: XCTestCase {

    private let empty = EchoelCrashLog.launchContextLine(
        prewarm: nil, bootEpoch: nil, uptimeSeconds: nil, processAgeMs: nil,
        availableMB: nil, thermal: nil, lowPower: nil)

    private let full = EchoelCrashLog.launchContextLine(
        prewarm: true, bootEpoch: 1_791_600_000, uptimeSeconds: 29_933, processAgeMs: 120,
        availableMB: 1_800, thermal: "nominal", lowPower: false)

    // MARK: 1 — nil prints as `-`, in a fixed order

    func testAnUnreadableFieldPrintsAsADashInAFixedOrder() {
        XCTAssertEqual(empty, "launch context: prewarm=- boot=- up=- age=- avail=- thermal=- lowpower=-", """
            The all-nil launch context line changed. `-` is "not readable here" and the field order \
            is what a triager learns to read; a changed spelling here changes the context line of \
            every pasted log (SH-2b).
            """)
        XCTAssertTrue(empty.hasPrefix(EchoelCrashLog.launchContextPrefix),
                      "the line must start with `launchContextPrefix` — one spelling for writer and reader (#416)")
    }

    // MARK: 2 — a full reading prints values with units, lower-case

    func testAFullReadingPrintsValuesWithUnits() {
        XCTAssertEqual(full, "launch context: prewarm=1 boot=1791600000 up=29933s age=120ms avail=1800mb thermal=nominal lowpower=0",
                       "a full launch context line changed its spelling — the units and flags are how a triager reads a prewarm (1), a fresh boot (small `up=`) or a long-lived process (large `age=`)")
        XCTAssertEqual(full, full.lowercased(), "the launch context line is lower-case throughout — a marker is never lower-case")
        XCTAssertEqual(full.components(separatedBy: "=").count - 1, 7, "seven fields, seven `=`")
    }

    // MARK: 3 — not a verdict: no marker any reader searches for

    func testTheLineCarriesNoMarker() {
        let markers = [EchoelCrashLog.crashMarker, EchoelCrashLog.startTappedMarker,
                       EchoelCrashLog.confirmedHealthyMarker, EchoelCrashLog.recoveryScreenClearedMarker,
                       EchoelCrashLog.sceneArrow]
        for line in [empty, full] {
            for marker in markers {
                XCTAssertFalse(line.contains(marker), """
                    The launch context line contains the marker `\(marker)`. The next launch reads a \
                    pasted log for exactly these spellings; a context line carrying one would turn a \
                    quiet run into a reported crash or a tapped Start (SH-2b).
                    """)
            }
            XCTAssertFalse(EchoelCrashLog.looksLikeUnseenCrash(line + "\n"),
                           "a log holding only the launch context line must not look like an unseen crash")
            XCTAssertEqual(EchoelCrashLog.neutralized(line), line,
                           "`neutralized` must have nothing to lower in the launch context line")
        }
    }

    // MARK: 4 — the live reader keeps the shape

    func testTheLiveReaderKeepsTheShape() throws {
        let live = EchoelCrashLog.launchContextLine()
        XCTAssertTrue(live.hasPrefix(EchoelCrashLog.launchContextPrefix), "the live line must carry the prefix: \(live)")
        XCTAssertFalse(live.contains(EchoelCrashLog.crashMarker), "the live line must not carry the crash marker: \(live)")
        XCTAssertEqual(live, live.lowercased(), "the live line is lower-case throughout: \(live)")

        let fields = live.dropFirst(EchoelCrashLog.launchContextPrefix.count)
            .split(separator: " ")
            .map { $0.split(separator: "=", maxSplits: 1).map(String.init) }
        XCTAssertEqual(fields.map { $0.first ?? "" },
                       ["prewarm", "boot", "up", "age", "avail", "thermal", "lowpower"],
                       "the live line names its seven fields in the fixed order: \(live)")
        let values = Dictionary(uniqueKeysWithValues: fields.compactMap { pair in
            pair.count == 2 ? (pair[0], pair[1]) : nil
        })
        // Always readable on any host: the environment and `ProcessInfo`.
        XCTAssertTrue(["0", "1"].contains(values["prewarm"] ?? ""), "`prewarm` is a flag, read from the environment: \(live)")
        XCTAssertTrue(["0", "1"].contains(values["lowpower"] ?? ""), "`lowpower` is a flag, read from `ProcessInfo`: \(live)")
        XCTAssertNotEqual(values["thermal"], "-", "`thermal` comes from `ProcessInfo` and is always named: \(live)")
        // Readable on this host only if the kernel answers: a dash is a stated refusal, a value is a number.
        for (name, unit) in [("boot", ""), ("up", "s"), ("age", "ms"), ("avail", "mb")] {
            let value = try XCTUnwrap(values[name], "field `\(name)` missing: \(live)")
            if value == "-" { continue }
            XCTAssertTrue(value.hasSuffix(unit), "`\(name)` carries its unit `\(unit)`: \(live)")
            XCTAssertNotNil(Int(value.dropLast(unit.count)), "`\(name)` is a whole number: \(live)")
        }
    }
}
