// TheDeviceStateSpeaksInTheDiagLogTests.swift
// Echoel — GMMW SH-6. A jetsam kill leaves no trace inside the process, and a thermal step or Low
// Power Mode changes what the visual draws without a word in the exported log — `os_log` is
// invisible there. So a log ending in silence could not tell a memory death from a crash, nor a
// cooler phone from a slower one. Now each memory-pressure EVENT writes one `memory:` line (level,
// this process's headroom, the event count) before anything is released, and the governor writes
// one `governor:` line per thermal step, per Low Power switch and per TIER change — only when
// something changed, never per frame, never per battery percent.
//
// WHAT IT PINS (Tests/CISmoke/CLAUDE.md §1) — claims 1–3 are SOURCE-TEXT SCANS (the handler and the
// governor read the device; no bundle can raise memory pressure or heat the phone); claim 4 is
// END-TO-END on `EchoelCrashLog.looksLikeUnseenCrash` over every literal's text. DEVICE PROBE,
// open: that a real pressure event and a real thermal step show up in an exported `echoel_diag.log`.
// 1. Memory: the line sits in `handlePressure` before the release loop and before the os_log, it
//    reads `.available` (headroom), never the #1201 `.used`, and the 5 s poll carries no line.
// 2. Governor, device: `refresh()` keeps the old thermal and power state, reads the device, and
//    writes each line inside an `if` that compares old with new — before `recompute()`.
// 3. Governor, tier: `apply` writes its line after `guard next != settings`, inside an `if` on the
//    tier, before `settings = next` (so it can name both) and before the os_log; `recordFrame` —
//    called once per drawn frame — carries no line at all.
// 4. No line can read as a crash marker to the next launch.
//
// HONEST GRADING (§3). The file names nothing new — it compiles on its parent (`b22b17d`). There,
// claims 1–3 are REGRESSIONS by ANCHOR ABSENCE (no `memory:` or `governor:` line exists — three
// absences, the one finding "the device state never reaches the exported log"); claim 4 is red too
// for want of a literal (its precondition). Counterweights inside the claims, green on both trees:
// the poll stays silent, `recordFrame` stays silent, the #1201 `used` reading is not the headroom.
// Transcribed in Python against both trees; MUTANTS, each red for its named reason: the memory line
// moved below the release loop → 1; `.used` in place of `.available` → 1; a line in the poll → 1;
// the thermal line outside its `if` → 2; the tier line before the guard → 3; a line in
// `recordFrame` → 3; "CRASH" in a line → 4.

import Foundation
import XCTest
@testable import Echoelmusic

private struct DeviceStateAnchorMissing: Error, CustomStringConvertible {
    let reason: String
    var description: String { reason }
}

final class TheDeviceStateSpeaksInTheDiagLogTests: XCTestCase {

    private static let memory = "Sources/Echoelmusic/Core/MemoryPressureHandler.swift"
    private static let governor = "Sources/Echoelmusic/Core/ResourceGovernor.swift"
    private static let sink = "EchoelCrashLog.breadcrumb("

    // MARK: 1 — one memory line per pressure event, before the release

    func testAMemoryPressureEventWritesOneLineBeforeTheRelease() throws {
        let code = try source(Self.memory)
        let handler = try block(after: "private func handlePressure(level: MemoryPressureLevel) {", in: code)
        let line = try anchor("\"memory: ", in: handler)
        let release = try anchor("for component in activeComponents", in: handler)
        let osLog = try anchor("log.warning(", in: handler)
        XCTAssertLessThan(line.lowerBound, release.lowerBound, "the line is written BEFORE anything is released")
        XCTAssertLessThan(line.lowerBound, osLog.lowerBound, "the exported line comes before the os_log the log cannot see")
        XCTAssertTrue(handler.contains("let headroomMB = getMemoryStats().available / 1_048_576"),
                      "the line reports this process's HEADROOM")
        XCTAssertTrue(handler[line.lowerBound...].hasPrefix("\"memory: \\(level.description.lowercased()) pressure, headroom \\(headroomMB) MB"), """
            the line reports the level and the HEADROOM — never the #1201 `used`, a subtraction \
            that names nothing
            """)
        let poll = try block(after: "private func updateMemoryStats() {", in: code)
        XCTAssertFalse(poll.contains(Self.sink), "the 5 s poll writes nothing — the log is for events, not a heartbeat")
        XCTAssertEqual(occurrences(of: Self.sink, in: code), 1, "one memory line, in the one handler every signal reaches")
    }

    // MARK: 2 — the governor names a thermal step and a power switch, only when they change

    func testTheGovernorNamesAThermalStepAndAPowerSwitch() throws {
        let code = try source(Self.governor)
        let refresh = try block(after: "public func refresh() {", in: code)
        let keptThermal = try anchor("let thermalBefore = thermal", in: refresh)
        let keptPower = try anchor("let lowPowerBefore = lowPower", in: refresh)
        let read = try anchor("readDeviceState()", in: refresh)
        let recompute = try anchor("recompute()", in: refresh)
        XCTAssertLessThan(keptThermal.lowerBound, read.lowerBound, "the old thermal level is kept before the device is read")
        XCTAssertLessThan(keptPower.lowerBound, read.lowerBound, "the old power state is kept before the device is read")
        let thermalStep = try block(after: "if thermal != thermalBefore {", in: refresh)
        XCTAssertTrue(thermalStep.contains(Self.sink + "\"governor: thermal "), "a thermal step writes its line inside its own `if`")
        let powerSwitch = try block(after: "if lowPower != lowPowerBefore {", in: refresh)
        XCTAssertTrue(powerSwitch.contains(Self.sink + "\"governor: low power "), "a power switch writes its line inside its own `if`")
        XCTAssertEqual(occurrences(of: Self.sink, in: refresh), 2, """
            two lines in `refresh`, each behind its comparison — battery notifications land here once \
            per percent and must say nothing
            """)
        let lastLine = try XCTUnwrap(refresh.range(of: Self.sink, options: .backwards))
        XCTAssertLessThan(lastLine.lowerBound, recompute.lowerBound, "the cause is logged before the tier change it causes")
    }

    // MARK: 3 — a tier change writes one line; a drawn frame writes none

    func testATierChangeWritesOneLineAndAFrameWritesNone() throws {
        let code = try source(Self.governor)
        let apply = try block(after: "private func apply(_ next: QualitySettings, cause: QualityPressure) {", in: code)
        let unchanged = try anchor("guard next != settings else { return }", in: apply)
        let tierChange = try anchor("if next.tier != settings.tier {", in: apply)
        let assign = try anchor("settings = next", in: apply)
        let osLog = try anchor("log.log(", in: apply)
        XCTAssertLessThan(unchanged.lowerBound, tierChange.lowerBound, "an unchanged setting writes nothing")
        XCTAssertLessThan(tierChange.lowerBound, assign.lowerBound, "the line can name the tier being LEFT")
        XCTAssertLessThan(assign.lowerBound, osLog.lowerBound, "premise: the os_log follows the assignment")
        let line = try block(after: "if next.tier != settings.tier {", in: apply)
        XCTAssertTrue(line.contains(Self.sink + "\"governor: tier "), "the tier line sits inside its comparison")
        XCTAssertEqual(occurrences(of: Self.sink, in: apply), 1, "one line per tier change")

        let frame = try block(after: "public func recordFrame(timestamp: CFTimeInterval) {", in: code)
        XCTAssertFalse(frame.contains(Self.sink), """
            `recordFrame` runs once per drawn frame — a line there would write sixty a second into a \
            file read after a crash
            """)
        XCTAssertEqual(occurrences(of: Self.sink, in: code), 3, "three governor lines: thermal, power, tier")
    }

    // MARK: 4 — no line reads as a crash

    func testNoDeviceStateLineReadsAsACrash() throws {
        var literals: [String] = []
        for file in [Self.memory, Self.governor] {
            let code = try source(file)
            var rest = code[...]
            while let open = rest.range(of: Self.sink) {
                let after = rest[open.upperBound...]
                guard let quote = after.firstIndex(of: "\""),
                      let close = after[after.index(after: quote)...].firstIndex(of: "\"") else { break }
                literals.append(String(after[after.index(after: quote)..<close]))
                rest = after[close...]
            }
        }
        XCTAssertEqual(literals.count, 4, "precondition: the memory line and the three governor lines were read")
        for literal in literals {
            XCTAssertFalse(EchoelCrashLog.looksLikeUnseenCrash(literal), """
                `\(literal)` reads as a crash marker — the next launch would report a crash that did \
                not happen
                """)
        }
    }

    // MARK: - Helpers

    private func anchor(_ needle: String, in text: String) throws -> Range<String.Index> {
        guard let hit = text.range(of: needle) else {
            throw DeviceStateAnchorMissing(reason: "`\(needle)` is not in the scanned block — re-anchor (#454)")
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

    private func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    private func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        let path = root.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw DeviceStateAnchorMissing(reason: "\(relativePath) is missing while the tree is present — re-anchor (#454)")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }
}
