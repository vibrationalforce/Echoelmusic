// TheTwoBioModulationsAreDifferentFilesTests.swift
// Echoel — #1165. Blocking bundle. SOURCE-TEXT SCAN (`Tests/CISmoke/CLAUDE.md` §1): it proves
// where names occur, never that anything runs.
//
// ⭐ WHY THIS FILE EXISTS. Two files in this repo have names where one is a PREFIX of the other,
// and they sit on opposite sides of the wired/unwired line:
//
//   Sources/Echoelmusic/Studio/BioModulation.swift     — pure value types, ZERO callers. It is
//                                                        named in CLAUDE.md's app-unwired list.
//   Sources/Echoelmusic/Core/BioModulationMap.swift    — LIVE. Its `isMeasured` gates the
//                                                        "measured" flag in BOTH synth voices
//                                                        and the bio panel's amount bar.
//
// The register named the first one BARE ("BioModulation, CloudSync"), while its neighbours in the
// same sentence carried paths (`Core/BioSpaceMap`, `Core/VisualModulation`). So the obvious way to
// CHECK that register entry — `git grep -c BioModulation -- Sources` — returned ten files for a
// name the sentence calls unwired. With a word boundary, and excluding the superstring neighbour,
// it is ZERO.
//
// ⛔ THAT TEN IS A DATE, NOT A FACT, and #1165's own CLAUDE.md clause carried it as a literal for
// one cycle before #1166 removed it: the count rises with every new `Sources/` file that calls the
// live gate, and nothing goes red. It is kept HERE, past tense, as the provenance of the find —
// which is what a guard header is for. The durable half is the INFLATION (a bare needle counts the
// neighbour) and the ZERO (a state the claims below pin), never the ten.
//
// This is law #1157 (a bare needle matches a SUPERSTRING) landing on the register line
// itself, and it runs in the expensive direction: a session "cleaning up the unwired
// BioModulation" follows that grep straight into the LIVE gate.
//
// ⚠️ #364 — NOTHING HERE IS FORBIDDEN. Wiring `Studio/BioModulation` is a normal slice; so is
// renaming either file to end the collision (that would be a genuine improvement). Claim 3 then
// goes red BY DESIGN and its message names the register sentence that must move in the same
// commit. What the guard forbids is only the silent state where the register and the tree disagree.
//
// GRADING — the LOAD-BEARING claim is the one that was RED before this slice, not the one that
// states the finding. That is claim 4: on HEAD, `grep -c 'Studio/BioModulation`' CLAUDE.md` was 0.
// Claims 1–3 are counterweights measured green beforehand; they exist so that claim 4 cannot be
// satisfied by prose that has drifted away from the tree.
//
// ⚠️ Comments are stripped before every scan. This repo writes ⛔ blocks that NAME the types they
// discuss, so a raw scan reads the register's own prose as a call site (#453/#762). String literals
// SURVIVE `codeOnly` — a needle inside a string would count as a reference. None exists today.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheTwoBioModulationsAreDifferentFilesTests: XCTestCase {

    private static let unwiredFile = "Sources/Echoelmusic/Studio/BioModulation.swift"
    private static let liveFile = "Sources/Echoelmusic/Core/BioModulationMap.swift"
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

    private func file(_ relative: String) throws -> String {
        let root = try repoRoot()
        guard let text = try? String(
            contentsOf: root.appendingPathComponent(relative), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: \(relative) — a missing anchor is a finding, not a pass.")
            return ""
        }
        return text
    }

    /// Comment-stripped text of every `.swift` file under `Sources/` except the ones named in
    /// `skipping`. Excluding a type's declaring file is what makes "who ELSE names it" the
    /// question; counting its own body would answer a different one (#1163).
    private func code(skipping: [String]) throws -> String {
        let root = try repoRoot()
        let dir = root.appendingPathComponent("Sources")
        let skip = Set(skipping.map {
            root.appendingPathComponent($0).standardizedFileURL.path
        })
        guard let walker = FileManager.default.enumerator(atPath: dir.path) else {
            XCTFail("Sources/ is present but not enumerable — re-anchor rather than skip (#454).")
            return ""
        }
        var out = ""
        for case let rel as String in walker where rel.hasSuffix(".swift") {
            let url = dir.appendingPathComponent(rel).standardizedFileURL
            if skip.contains(url.path) { continue }
            out += SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8)) + "\n"
        }
        guard !out.isEmpty else {
            XCTFail("walked Sources/ and read nothing — the scan found nothing, not nothing wrong.")
            return ""
        }
        return out
    }

    /// Occurrences of `name` that are NOT the start of a longer identifier. A bare `contains`
    /// would count `BioModulationMap` as a hit for `BioModulation` — the exact defect this file
    /// documents, so the guard must not repeat it (#1157).
    private func wholeWordCount(of name: String, in text: String) -> Int {
        var count = 0
        var searchStart = text.startIndex
        while let range = text.range(of: name, range: searchStart..<text.endIndex) {
            let beforeOK: Bool = {
                guard range.lowerBound > text.startIndex else { return true }
                let ch = text[text.index(before: range.lowerBound)]
                return !(ch.isLetter || ch.isNumber || ch == "_")
            }()
            let afterOK: Bool = {
                guard range.upperBound < text.endIndex else { return true }
                let ch = text[range.upperBound]
                return !(ch.isLetter || ch.isNumber || ch == "_")
            }()
            if beforeOK && afterOK { count += 1 }
            searchStart = range.upperBound
        }
        return count
    }

    /// Claim 1 — the collision is REAL, not a story. Both files exist, at different paths, and
    /// one name is a strict prefix of the other. If someone renames either file the collision is
    /// gone and this claim goes red, which is the correct moment to retire the whole guard.
    func testBothFilesExistAndOneNameIsAPrefixOfTheOther() throws {
        let root = try repoRoot()
        for path in [Self.unwiredFile, Self.liveFile] {
            XCTAssertTrue(
                FileManager.default.fileExists(
                    atPath: root.appendingPathComponent(path).path), """
                \(path) is gone. If it was renamed or deleted deliberately, retire this guard and \
                the ⚠️ #1165 clause in CLAUDE.md's app-unwired-cores sentence in the SAME commit \
                — a warning about a collision that no longer exists sends the next reader hunting \
                for a file that is not there.
                """)
        }
        XCTAssertTrue("BioModulationMap".hasPrefix("BioModulation"), """
            The prefix relationship this guard is built on no longer holds. That means a rename \
            already happened — remove the ⚠️ #1165 clause from CLAUDE.md and delete this file.
            """)
    }

    /// Claim 2 — the LIVE half is live. This is the counterweight that makes the warning worth
    /// carrying: if `BioModulationMap` ever loses every caller it stops being the dangerous
    /// neighbour and becomes a register entry of its own.
    func testTheMapHalfHasRealCallers() throws {
        let text = try code(skipping: [Self.liveFile])
        let hits = wholeWordCount(of: "BioModulationMap", in: text)
        XCTAssertGreaterThan(hits, 0, """
            `BioModulationMap` now has ZERO code references outside its own file. Either it was \
            just orphaned — in which case it belongs in CLAUDE.md's app-unwired list and the \
            ⚠️ #1165 clause must be rewritten, because the trap it warns about (a live neighbour) \
            is gone — or a caller was deleted by accident. Do not "fix" this by deleting the file: \
            its `isMeasured` is what makes the bio panel say a channel is MEASURED rather than \
            assumed, and both synth voices read it.
            """)
    }

    /// Claim 3 — the UNWIRED half is still unwired, measured the way the register claims it:
    /// whole-word, comments stripped, its own file excluded. `Studio/BioModulation.swift` declares
    /// no type of its own name, so the honest measurement is on the two types it DOES declare.
    func testTheUnwiredHalfStillHasNoCallers() throws {
        let text = try code(skipping: [Self.unwiredFile])
        for name in ["ClockSource", "BoundParameter"] {
            let hits = wholeWordCount(of: name, in: text)
            XCTAssertEqual(hits, 0, """
                `\(name)` (declared in \(Self.unwiredFile)) now has \(hits) code reference(s) \
                outside its own file. That file is named in CLAUDE.md's app-unwired pure cores \
                sentence. If it has genuinely been wired, MOVE it out of that list in the same \
                commit — a register that still calls a wired core unwired is the exact defect \
                #1163 was opened for, one direction over.
                """)
        }
    }

    /// Claim 4 — LOAD-BEARING (red on HEAD before #1165). The register must name both cores with
    /// their PATHS, because the bare name is what sends a reader to the wrong file.
    func testTheRegisterNamesTheCoresWithTheirPaths() throws {
        let law = try file(Self.lawFile)
        for needle in ["Studio/BioModulation", "Core/CloudSync"] {
            XCTAssertTrue(law.contains(needle), """
                CLAUDE.md's app-unwired pure cores sentence no longer names `\(needle)` with its \
                path. The bare name is the defect: `git grep -c BioModulation -- Sources` returns \
                ten files, because `Core/BioModulationMap` is a different and LIVE file, so a bare \
                register entry reads as stale when it is correct — and points a cleanup at the \
                live gate. Restore the path rather than the bare name.
                """)
        }
    }
}
