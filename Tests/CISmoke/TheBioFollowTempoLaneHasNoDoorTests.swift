// TheBioFollowTempoLaneHasNoDoorTests.swift
// Echoel — #1163. Blocking bundle. SOURCE-TEXT SCAN (`Tests/CISmoke/CLAUDE.md` §1): it proves
// where construction sites sit, never that anything runs.
//
// ⭐ WHY THIS FILE EXISTS, AND IT IS NOT "BioTempoDirector IS UNREACHABLE". Unreachable is not a
// defect here — `ImmersiveStageView` is parked on purpose, and this file's own header says
// "deliberately NOT wired to playback yet". The defect is **unreachable AND missing from the
// register**: `CLAUDE.md`'s list of app-unwired pure cores named BioModulation, CloudSync,
// BioSpaceMap, VisualModulation and four `Sync/` cores, and did NOT name this one.
//
// ⭐ AND IT IS THE MOST DANGEROUS SHAPE IN THAT LIST, which is why the register line says so.
// This is not an orphan utility: it is a NEAR-TWIN of shipped behaviour. It computes a bio-follow
// tempo the same way the live path does — heartbeat pulled toward a resonance BPM by coherence,
// then a one-pole glide — while the LIVE servo is `BioComposer.tempo(for:)` (called from
// `compose`) feeding the inline convergence block in `EchoelStudioView`. So a session told to
// "fix the tempo glide" can plausibly edit this file and ship nothing, and a session PLANNING a
// BPM-follow lane can build from scratch what is already written, tested and NaN-safe.
//
// ⚠️ #364 — THIS GUARD DOES NOT FORBID WIRING IT. The day a bio-follow lane is doored is a
// product decision (founder "BPM both"), not a test's. Every claim's message names the prose that
// must move in the same commit.
//
// ⚠️ HONEST GRADING. Four claims, and the first draft of this header got it backwards — it
// called claim 1 load-bearing because it is the one that STATES the finding. The grade is not
// about which claim sounds central, it is about which one is RED before the slice.
// **Claim 4 is the LOAD-BEARING one**: the register line is what this slice adds, and
// `grep -c "Core/BioTempoDirector" CLAUDE.md` was 0 on `HEAD`. Claims 1, 2 and 3 are
// COUNTERWEIGHTS — green on both trees; they do not prove a repair, they make the register line
// rot loudly instead of silently.
//
// ⚠️ DRIVEN, NOT READ (`Tests/CISmoke/CLAUDE.md` §0 — no Swift toolchain in a web session).
// Transcribed into Python against the real tree: all four GREEN after the register edit; claim 1
// goes RED on each of the three wiring shapes injected separately (`BioTempoDirector(`,
// `BioTempoDirector.minTempo`, `: BioTempoDirector`) and STAYS GREEN when the injection is a
// COMMENT — the #762 false-positive direction, which is the whole reason `codeOnly` is used.
//
// ⚠️ LIMIT, stated because it is real: `codeOnly` strips comments but KEEPS string literals, so
// a needle inside a string would count as a call. No such string exists today; if one ever does,
// claim 1 reports a hit that is not a caller — read the reported count, do not trust it blind.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheBioFollowTempoLaneHasNoDoorTests: XCTestCase {

    private static let laneFile = "Sources/Echoelmusic/Core/BioTempoDirector.swift"
    private static let lawFile = "CLAUDE.md"

    private func repoRoot() throws -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }

    /// Comment-stripped text of every `.swift` file under `Sources/` EXCEPT the lane's own file,
    /// as one string. Excluding the declaring file is what makes "who calls it" the question:
    /// its own `nextTempo` calls `targetTempo`, and counting that would answer a different one.
    /// Comments are stripped because this repo writes ⛔ blocks that NAME the types they discuss,
    /// so a raw scan would read the register's own prose as a call site (#453/#762).
    private func callerCode() throws -> String {
        let root = try repoRoot()
        let dir = root.appendingPathComponent("Sources")
        let skip = root.appendingPathComponent(Self.laneFile).standardizedFileURL.path
        guard let walker = FileManager.default.enumerator(atPath: dir.path) else {
            XCTFail("Sources/ is present but not enumerable — re-anchor rather than skip (#454).")
            return ""
        }
        var out = ""
        for case let rel as String in walker where rel.hasSuffix(".swift") {
            let url = dir.appendingPathComponent(rel).standardizedFileURL
            if url.path == skip { continue }
            let text = try String(contentsOf: url, encoding: .utf8)
            out += SourceText.codeOnly(text) + "\n"
        }
        guard !out.isEmpty else {
            XCTFail("walked Sources/ and read nothing — the scan found nothing, not nothing wrong.")
            return ""
        }
        return out
    }

    private func file(_ relative: String) throws -> String {
        let root = try repoRoot()
        guard let text = try? String(
            contentsOf: root.appendingPathComponent(relative), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: \(relative) — a missing anchor is a finding, not a pass.")
            return ""
        }
        return text
    }

    /// claim 1 — LOAD-BEARING: nothing outside its own file constructs or calls the lane.
    /// Three needles, not one: a type can be reached by construction, by a static member, or by
    /// a stored property's type annotation, and a single needle would answer only one of them.
    func testNothingOutsideTheFileReachesTheLane() throws {
        let code = try callerCode()
        let needles = ["BioTempoDirector(", "BioTempoDirector.", ": BioTempoDirector"]
        var hits: [String: Int] = [:]
        for needle in needles {
            let n = code.components(separatedBy: needle).count - 1
            if n > 0 { hits[needle] = n }
        }
        XCTAssertTrue(hits.isEmpty, """
            `BioTempoDirector` is now reached from production code: \(hits). That is allowed and \
            may well be right (#364) — the founder's "BPM both" ask is exactly this lane. But the \
            register entry in `CLAUDE.md` (the app-unwired-pure-cores sentence in the ARCHITECTURE \
            block) says zero constructions and zero calls, and it must be corrected in the SAME \
            commit. Check also whether the TEMPO INVARIANT block's T1 enumeration of tempo sources \
            needs a fifth entry: a doored bio-follow lane is a new writer of the clock.
            """)
    }

    /// claim 2 — COUNTERWEIGHT: the file still declares the lane, so claim 1 measures something.
    /// A scan that matches nothing is a finding, never a pass (`.claude/rules/context.md` §2) —
    /// if the type were deleted or renamed, claim 1 would go green for the wrong reason.
    func testTheLaneStillExists() throws {
        let lane = SourceText.codeOnly(try file(Self.laneFile))
        XCTAssertTrue(lane.contains("struct BioTempoDirector"), """
            `Sources/Echoelmusic/Core/BioTempoDirector.swift` no longer declares \
            `struct BioTempoDirector`. If it was deleted, remove its clause from the \
            app-unwired-pure-cores sentence in `CLAUDE.md` in the same commit; if it was renamed, \
            re-anchor all four claims here. Either way claim 1 above is currently proving nothing.
            """)
    }

    /// claim 3 — COUNTERWEIGHT, and the reason the register entry was written: the LIVE servo is
    /// somewhere else. If `BioComposer.tempo(for:)` ever stops being called from `compose`, the
    /// "near-twin" argument in the register line has lost its other half and must be re-checked.
    func testTheLiveServoIsTheOtherOne() throws {
        let composer = SourceText.codeOnly(
            try file("Sources/Echoelmusic/Sequencer/BioComposer.swift"))
        XCTAssertTrue(composer.contains("tempo(for: input)"), """
            `BioComposer.compose` no longer calls `tempo(for: input)`. The register entry for \
            `BioTempoDirector` in `CLAUDE.md` calls it a TWIN of the live servo and names this \
            call as where the live one runs — re-measure which function feeds the clock before \
            trusting that sentence, and correct it in the same commit.
            """)
    }

    /// claim 4 — COUNTERWEIGHT: the register line exists and names the file. A guard that pins a
    /// code fact while its prose home silently disappears leaves the next session with a measured
    /// zero and no idea why it was measured (#1147).
    func testTheRegisterNamesTheLane() throws {
        let law = try file(Self.lawFile)
        XCTAssertTrue(law.contains("Core/BioTempoDirector"), """
            `CLAUDE.md` no longer names `Core/BioTempoDirector` in its app-unwired-pure-cores \
            sentence. If the lane was wired or deleted, that is fine — but then claims 1 and 2 \
            here describe a world that no longer exists and must move in the same commit.
            """)
    }
}
