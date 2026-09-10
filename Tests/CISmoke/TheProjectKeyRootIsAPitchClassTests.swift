// TheProjectKeyRootIsAPitchClassTests.swift
// Echoel — #56 (BD). A take file cannot crash the app through its key root.
//
// THE CRASH. `Project.keyRoot` was decoded as a bare `Int` with `?? 0` and no fold. Every reader
// ADDS to it or INDEXES with it: `EchoelStudioView` computes `60 + rootIndex` for the key label
// and the root frequency, `TuningSystem.pitchClassCents(root:)` indexes with it. A hand-edited or
// corrupted take carrying `"keyRoot": 9223372036854775807` reached those lines unchanged, and
// `60 + Int.max` TRAPS — a crash behind the same live "Open project" `.fileImporter` door as
// #1207, one step worse than #1207's silent NaN. The 2026-09-10 handover (§4) named it the
// heaviest open item; the reviewer confirmed it by reading, this guard confirms it by decoding.
//
// THE FIX. The decoder folds the raw integer with `MusicalKey.init(root:)`'s own
// `((r % 12) + 12) % 12`, so the file and the key it names can never disagree (#416: one law,
// not a clamp that would turn a hand-typed 13 into 11 while `MusicalKey` reads it as 1).
//
// WHAT THIS PINS. (1) BEHAVIOUR — the three integers that would trap (`Int.max`, `Int.min`, and
// an out-of-range 13) decode into 0…11, and `60 + keyRoot` is computable. (2) SEMANTICS — the
// fold is the SAME expression `MusicalKey` uses, pinned by text at both sites, so a later
// "tidy" cannot make the decoder clamp while the key wraps. (3) COUNTERWEIGHT — the twelve
// in-range values survive the fold unchanged, so the fix cannot silently transpose a real take.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`aaa2e35`) and this tree: claim 1 is
// RED on the parent (the decoded value is `Int.max`; `60 + Int.max` overflows Int64 — the trap
// the parent ships), GREEN here; claim 2 is RED on the parent (no fold in the decoder), GREEN
// here; claim 3 is green on both trees, as a counterweight must be.
//
// ⚠️ THE LIMIT. XCTest cannot catch a Swift arithmetic trap, so claim 1 does not perform the
// parent's `60 + Int.max` — it asserts the RANGE that makes the addition safe, and the reader
// sites are pinned by the range, not by executing them.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheProjectKeyRootIsAPitchClassTests: XCTestCase {

    private func decode(keyRoot literal: String) throws -> Project {
        let json = #"{"name":"guard","keyRoot":"# + literal + "}"
        return try JSONDecoder().decode(Project.self, from: Data(json.utf8))
    }

    /// Claim 1 — the integers that trapped on the parent decode into a pitch class.
    func testTheTrappingIntegersDecodeIntoAPitchClass() throws {
        for literal in ["9223372036854775807", "-9223372036854775808", "13", "-1"] {
            let p = try decode(keyRoot: literal)
            XCTAssertTrue((0...11).contains(p.keyRoot),
                          "keyRoot \(literal) decoded to \(p.keyRoot) — outside 0…11, and " +
                          "`60 + rootIndex` in EchoelStudioView traps on the large ones (#56)")
            // Computable without overflow once the range holds — the reader sites' arithmetic.
            let midi = 60 + p.keyRoot
            XCTAssertEqual(TuningReference.noteName(forMIDINote: midi).isEmpty, false)
        }
    }

    /// Claim 2 — the fold is `MusicalKey`'s own, at both sites, by text.
    func testTheDecoderFoldsWithTheKeysOwnLaw() throws {
        let project = SourceText.codeOnly(try text("Sources/Echoelmusic/Core/Project.swift"))
        let key = SourceText.codeOnly(try text("Sources/Echoelmusic/Sequencer/MusicalKey.swift"))
        XCTAssertTrue(project.contains("((rawKeyRoot % 12) + 12) % 12"),
                      "Project's decoder no longer folds keyRoot with the pitch-class law — " +
                      "a raw Int reaches `60 + rootIndex` again (#56)")
        XCTAssertTrue(key.contains("((root % 12) + 12) % 12"),
                      "MusicalKey.init(root:) changed its fold — update the decoder in the SAME " +
                      "commit so a file and its key cannot disagree (#416)")
        // Semantic pin: 13 folds to 1 in BOTH places.
        XCTAssertEqual(try decode(keyRoot: "13").keyRoot, MusicalKey(root: 13).root)
    }

    /// Claim 3 — counterweight: every in-range root survives unchanged.
    func testInRangeRootsAreNotTransposed() throws {
        for r in 0...11 {
            XCTAssertEqual(try decode(keyRoot: "\(r)").keyRoot, r)
        }
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
