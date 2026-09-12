// ThePadGrammarLeavesTheNilPathAloneTests.swift
// Echoel — G2's new pad branch changes no existing take, in the BLOCKING bundle.
//
// KIND: MIXED, labelled per claim. Claims 1–3 are a SOURCE-TEXT SCAN of `BioComposer.swift` —
// they prove where the branch sits and what it does not touch, which is exactly the kind of fact
// a behavioural test cannot reach here. Claim 4 is END-TO-END BEHAVIOUR on the pure composer.
//
// ⛔ WHAT THIS FILE DELIBERATELY DOES NOT ASSERT, because `PadRhythmOverrideTests` already does
// and two spellings of one law is the defect (#416): that the default take is the GENRE's own
// articulation and equals no character's output. That file also records, at length, why a true
// golden fixture is impossible here — there is no local toolchain to capture one from the
// pre-feature revision — and that account is not repeated. Read it before adding a fifth claim.
//
// SO WHAT IS LEFT FOR THIS FILE IS THE PART THAT IS NEW, and it is one idea: the grammar branch
// is an `else if` inserted into a five-way chain, so ITS POSITION IS ITS PRECEDENCE. There is no
// flag to read and nothing at runtime to interrogate — move it one rung up and an arpeggiated
// genre loses its pitch figure; move it one rung down and a sustained genre with a figure never
// plays it. That ordering is the whole design decision of the slice, and only text can hold it.
//
// ⚠️ HONEST GRADING (§0/§3), transcribed in Python against the parent (`6db1a62`) and the
// worktree, since there is no toolchain here:
//   · claims 1–3 are REGRESSIONS on the parent for their named reason — the branch does not
//     exist there, so every needle is absent. That is ONE absence, reported three times (#486),
//     not three findings.
//   · claim 4 is a COUNTERWEIGHT and is GREEN ON BOTH TREES by construction, which is the point
//     (#343): every genre's `padGrammar` is `nil`, so the pad these genres produce must be the
//     one they always produced. A file that only asserted the new branch would stay green on a
//     tree that kept the branch and lost a genre's pad.

import Foundation
import XCTest
@testable import Echoelmusic

final class ThePadGrammarLeavesTheNilPathAloneTests: XCTestCase {

    private static let composerFile = "Sources/Echoelmusic/Sequencer/BioComposer.swift"

    // MARK: - claim 1 (SOURCE SCAN) — the branch sits between the arp and the derived grids

    /// The ordering IS the precedence, so it is asserted as an ordering: the arp path must come
    /// BEFORE the grammar (an arp genre's pitch figure is its identity and a chord-shaped figure
    /// would silence it), and both `chordOnsets` branches must come AFTER (the derived four-case
    /// grid is what an authored figure exists to replace).
    func testTheGrammarBranchSitsAfterTheArpAndBeforeTheDerivedGrids() throws {
        let code = try source(Self.composerFile)
        let arp = try index(of: "} else if profile.arpeggiated {", in: code)
        let grammar = try index(of: "} else if let figure = padGrammar?.onsets(", in: code)
        let sustained = try index(of: "} else if profile.sustained {", in: code)
        let rhythmic = try index(of: "} else if articulation != .sustained {", in: code)
        XCTAssertLessThan(arp, grammar, """
            The pad-grammar branch has moved ABOVE the arpeggiated path. An arp genre's identity \
            is its pitch figure walking the voicing; a chord-shaped grammar tested first would \
            replace it with block chords and the genre would stop being itself.
            """)
        XCTAssertLessThan(grammar, sustained, """
            The pad-grammar branch has moved BELOW `profile.sustained`. A genre that was GIVEN a \
            figure would then never play it — the derived heartbeat Fläche would win, silently, \
            for exactly the genres a batch spent its cycle authoring.
            """)
        XCTAssertLessThan(sustained, rhythmic,
                          "the two derived-grid branches have swapped — unrelated to this slice, but read why")
    }

    // MARK: - claim 2 (SOURCE SCAN) — the condition is the optional, and it draws no RNG

    /// Byte-identity on the nil path rests on ONE property: getting to the next branch must cost
    /// nothing. `PadGrammar.onsets` is pure and RNG-free, and the condition is an optional chain
    /// on a value that is `nil` for every genre — so a take composed today draws exactly the
    /// random numbers it drew before, and every later note keeps its identity. A `rng.next()`
    /// moved into or above this condition would shift the whole stream, which is invisible in a
    /// diff and audible in every genre at once.
    func testTheGrammarConditionDrawsNoRandomness() throws {
        let code = try source(Self.composerFile)
        guard let branch = code.range(of: "} else if let figure = padGrammar?.onsets(") else {
            throw AnchorMissing(reason: "the grammar branch is gone — re-anchor (#454)")
        }
        guard let bodyStart = code.range(of: "for pitch in voiced {", range: branch.upperBound..<code.endIndex) else {
            throw AnchorMissing(reason: "the grammar branch has no note-writing body — re-anchor (#454)")
        }
        // Exactly the text between the `else if` and the first note written by it: the CONDITION
        // and nothing else. Taking a fixed number of lines would be unsound by construction here
        // (#408) — this repo writes 20-line comment blocks and `codeOnly` preserves their lines.
        let condition = String(code[branch.lowerBound..<bodyStart.lowerBound])
        XCTAssertFalse(condition.contains("rng.next()"), """
            The pad-grammar branch draws a random number before its body runs. Every genre \
            resolves to `nil` today, so this line executes on EVERY take and would shift the \
            seeded stream for all of them — the notes after it change, no test names the cause, \
            and the diff shows one added line.
            """)
        XCTAssertFalse(condition.contains("nextUUID("),
                       "the same defect written as a UUID draw — `nextUUID` advances the same generator")
    }

    // MARK: - claim 3 (SOURCE SCAN, COUNTERWEIGHT) — nothing was replaced

    /// The failure this catches is the tempting one: a future cleanup deciding the grammar branch
    /// "supersedes" a derived grid and deleting it. Every genre is `nil`, so deleting either
    /// `chordOnsets` branch would silence or flatten thirty-six genres while this file's other
    /// claims stayed green.
    func testBothDerivedGridsSurvive() throws {
        let code = try source(Self.composerFile)
        XCTAssertGreaterThanOrEqual(code.components(separatedBy: "Self.chordOnsets(secStart: secStart").count - 1, 3, """
            A `chordOnsets` call site is gone from the pad path. The grammar branch does not \
            replace them — every genre resolves to `nil`, so those grids are what the pad \
            actually plays today.
            """)
        XCTAssertTrue(code.contains("padGrammar: input.style.padGrammar"), """
            The composer is no longer given the genre's pad figure. With the parameter \
            un-defaulted this cannot compile — so if this is red, the argument has been given a \
            default, which is the #431/#440/#443 defect: a forgetting that appears in no diff.
            """)
    }

    // MARK: - claim 4 (BEHAVIOUR, COUNTERWEIGHT) — every offered genre still has a pad

    /// Green on both trees on purpose (#343). The `else if` was spliced into a chain that decides
    /// what the pad plays for every genre; the cheapest way for that splice to be wrong is for a
    /// genre to fall through to a branch it did not take before and go quiet.
    func testEveryOfferedGenreStillProducesAPad() {
        for style in MusicStyle.offered {
            let input = BioComposer.Input(heartRateBPM: 58, hrvNormalized: 0.8, coherence: 0.9,
                                          breathPhase: 0.5, breathDepth: 0.1,
                                          key: MusicalKey(root: 0, scale: style.scale),
                                          style: style, mode: .studioLocked,
                                          lockedTempo: Double(style.defaultTempo),
                                          seed: 0xD00D)
            let pad = BioComposer.compose(input).notes.filter { $0.role == .harmony }
            XCTAssertFalse(pad.isEmpty, """
                \(style) produces no pad at a resting body. The G2 branch was spliced into the \
                chain that chooses the pad's grid; a genre losing its pad here means it now falls \
                into a branch it did not take before.
                """)
            XCTAssertTrue(pad.allSatisfy { $0.lengthSteps >= 1 },
                          "\(style) has a zero-length pad note (#205/#176)")
        }
    }

    // MARK: - source access (§0/§2 — one stripper, skip on no tree, FAIL on a moved anchor)

    private struct AnchorMissing: Error { let reason: String }

    private func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path)
        else { throw XCTSkip("source tree not present under \(root.path)") }
        let path = root.appendingPathComponent(relativePath)
        guard let text = try? String(contentsOf: path, encoding: .utf8) else {
            throw AnchorMissing(reason: "\(relativePath) is missing — re-anchor, do not skip (#454)")
        }
        return SourceText.codeOnly(text)
    }

    /// The offset of `needle`, FAILING when it is absent rather than returning a sentinel: an
    /// ordering claim over two sentinels compares 0 with 0 and passes vacuously (#367/#454).
    private func index(of needle: String, in code: String) throws -> Int {
        guard let range = code.range(of: needle) else {
            throw AnchorMissing(reason: """
                the anchor \"\(needle)\" is gone from the composer. Re-anchor this scan on the \
                line that carries the same decision; do not let it pass.
                """)
        }
        return code.distance(from: code.startIndex, to: range.lowerBound)
    }
}
