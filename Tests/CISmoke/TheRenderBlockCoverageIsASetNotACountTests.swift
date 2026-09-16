// TheRenderBlockCoverageIsASetNotACountTests.swift
// Echoel — #1328. `DSP/AudioOutputGuard`'s COVERAGE block claimed "All seven of the app's
// `AVAudioSourceNode` render blocks are wired" while its own bullet list named SIX, and the
// bullet four lines below named the missing seventh: `DrumSynthVoice`, deleted with #167 on
// 2026-07-27. The claim and its own refutation sat in one doc comment for seven weeks (#425).
//
// ⭐ WHY THE REPAIR IS NOT "write six". This is a SAFETY invariant — the non-finite sweep at
// every source node's output, the thing standing between one NaN and a permanently silent
// master bus. A count says nothing about whether a NEW voice is covered; it goes stale in the
// reassuring direction (a seventh voice arrives, the prose still reads "seven", nothing is
// red, and the new voice's samples reach CoreAudio unswept). So this guard asks the SET
// question in both directions and prints the DIFFERENCE per file, which is the form
// `.claude/rules/context.md` §2 demands: a pair of equal totals cannot answer "is A inside B",
// and it fails reassuringly when it is wrong.
//
// ⚠️ IT FORBIDS NO VOICE (#364). Adding a render block is legal; claims 1 and 2 then name the
// new file and say exactly what it still owes — a guard call and a bullet.
//
// ⚠️ WHAT IT DOES NOT PROVE (§1). SOURCE-TEXT SCAN: it proves a guard call EXISTS in each
// file, never that it sits on the last write, never that it covers every branch. That reading
// is what the doc block's three FORMS (buffer / scalar / in-place) are for, and it is a human's
// judgement per voice. Claim 3 is END-TO-END on the shipped sweep itself, which is the one
// behaviour a test bundle can actually drive here.
//
// ⚠️ HONEST GRADING (§0/§3). No local Swift toolchain — **9 assertions across three claims**
// (claim 1 = 3, claim 2 = 2, claim 3 = 4), transcribed in Python and driven against BOTH trees.
// On the parent (`6847962`) **2 are red and they are ONE finding** (#486): both of claim 2's
// needles, because the prose repair did not exist there. Claims 1 and 3 are COUNTERWEIGHTS
// (#343): green on both trees — six render-block files, none unswept, none unnamed — because
// the CODE was correct all along and only the prose lied. That is the honest shape of this
// slice, stated rather than dressed up: nothing here caught a live safety hole; what it buys
// is the NEXT voice, which a count could not have covered.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheRenderBlockCoverageIsASetNotACountTests: XCTestCase {

    private static let guardFile = "Sources/Echoelmusic/DSP/AudioOutputGuard.swift"

    /// Claim 1 — every file constructing an `AVAudioSourceNode` also calls the guard, and is
    /// NAMED in the COVERAGE block. Two set inclusions, differences printed per file.
    func testEveryRenderBlockIsWiredAndNamed() throws {
        let root = Self.repoRoot()
        let sources = root.appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(atPath: sources.path) else {
            XCTFail("ANCHOR MISSING: could not walk Sources/ (#454)")
            return
        }
        var renderBlockFiles: [String] = []
        var unswept: [String] = []
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            guard let raw = try? String(contentsOf: sources.appendingPathComponent(relative),
                                        encoding: .utf8) else { continue }
            let code = SourceText.codeOnly(raw)
            guard code.contains("AVAudioSourceNode(") else { continue }
            renderBlockFiles.append(relative)
            if !code.contains("AudioOutputGuard.") { unswept.append(relative) }
        }
        XCTAssertFalse(
            renderBlockFiles.isEmpty,
            "ANCHOR MISSING: found no `AVAudioSourceNode(` under Sources/ at all — a scan that "
            + "matches nothing is a finding, never a pass (#454, `.claude/rules/context.md` §2).")
        XCTAssertEqual(
            unswept, [],
            "these render-block files never mention `AudioOutputGuard.`: \(unswept). Every "
            + "SOUNDING path of every render block must pass the samples it writes through the "
            + "non-finite sweep — one NaN reaching the master bus poisons every recursive node "
            + "downstream and the limiter cannot undo it. This forbids no new voice (#364); it "
            + "says what the new one still owes.")
        let coverage = try Self.coverageBlock(in: Self.text(Self.guardFile))
        let unnamed = renderBlockFiles
            .map { String(($0 as NSString).lastPathComponent.dropLast(6)) }
            .filter { !coverage.contains($0) }
        XCTAssertEqual(
            unnamed, [],
            "these render-block types are wired but NOT named in AudioOutputGuard's COVERAGE "
            + "block: \(unnamed). The block claims to be the whole set; an unnamed voice makes "
            + "it a claim about a subset, which is exactly how \"All seven\" survived next to a "
            + "list of six (#1328). Add a bullet saying which of the three entry-point FORMS it "
            + "needs — buffer, scalar or in-place.")
    }

    /// Claim 2 — the retraction is recorded, and the block routes to a command instead of a
    /// figure. Positive needles: a negative scan would hit the retraction's own quotation.
    func testTheCoverageBlockRoutesInsteadOfCounting() throws {
        let doc = try Self.text(Self.guardFile)
        XCTAssertTrue(doc.contains("this line said\n/// \"All seven\" while its own list named six"),
                      "the #1328 retraction is gone. It is the record that a count and its own "
                      + "refutation stood four lines apart in one doc comment for seven weeks.")
        XCTAssertTrue(doc.contains("grep -rln \"AVAudioSourceNode(\" --include=*.swift Sources/"),
                      "the COVERAGE block no longer carries the command that re-derives the set. "
                      + "Replacing an unmaintainable number with its command is the repair this "
                      + "repo has made before (#803/#810/#818) — do not put a figure back.")
    }

    /// Claim 3 — END-TO-END on the shipped sweep, the one behaviour drivable here: the scalar
    /// entry point really silences every non-finite shape and passes finite values through.
    func testTheScalarSweepSilencesEveryNonFiniteShape() throws {
        XCTAssertEqual(AudioOutputGuard.silencingNonFinite(Float.nan), 0,
                       "a NaN survives the sweep — it fails every comparison downstream and "
                       + "poisons each recursive node it reaches.")
        XCTAssertEqual(AudioOutputGuard.silencingNonFinite(Float.infinity), 0,
                       "an infinity survives the sweep — the limiter scales what it is given "
                       + "and cannot clamp it.")
        XCTAssertEqual(AudioOutputGuard.silencingNonFinite(-Float.infinity), 0,
                       "a negative infinity survives the sweep.")
        XCTAssertEqual(AudioOutputGuard.silencingNonFinite(-0.25), -0.25,
                       "the sweep altered a FINITE sample. It must be transparent to real "
                       + "audio, including negative values — a guard that changes the signal "
                       + "is a defect, not a safety net.")
    }

    // MARK: - helpers

    /// The COVERAGE section of the guard's doc comment, from its own heading to the next one.
    /// Anchor uniqueness checked here rather than in review (#408).
    private static func coverageBlock(in doc: String) throws -> String {
        let head = "── COVERAGE"
        let hits = doc.components(separatedBy: head).count - 1
        guard hits == 1, let start = doc.range(of: head) else {
            throw XCTSkip("anchor `\(head)` occurs \(hits)× — re-anchor before trusting a zero (#408)")
        }
        let rest = doc[start.upperBound...]
        guard let end = rest.range(of: "THE INVARIANT IS EXACTLY THIS") else {
            throw XCTSkip("the COVERAGE block's closing anchor moved — re-anchor (#454)")
        }
        return String(rest[..<end.lowerBound])
    }

    private static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func text(_ relativePath: String) throws -> String {
        try String(contentsOf: repoRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }
}
