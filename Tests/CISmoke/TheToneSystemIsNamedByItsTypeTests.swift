// TheToneSystemIsNamedByItsTypeTests.swift
// Echoel — Phase C1 (2026-09-22). Blocking bundle. SOURCE-TEXT SCAN
// (`Tests/CISmoke/CLAUDE.md` §1) throughout: it proves where text sits, never that a
// note sounds at the retuned pitch. That half is a DEVICE PROBE and stays open.
//
// ⭐ WHY THIS FILE EXISTS. The musical-context census (Phase C) asked one question —
// which owner holds which musical fact — and found two citation defects rather than a
// missing type. Both are in files a session reads BEFORE it decides whether something
// is safe to delete or safe to build, which is what makes them worth a guard:
//
//   1. `CLAUDE.md` cited the tone system by its FILE, `Sequencer/MicrotonalTuning`, and
//      no type of that name exists — the #1376 trap. The TYPE is `TuningSystem`. A
//      session grepping for `MicrotonalTuning` as a type finds nothing and can conclude
//      the tone system is dead. It is not: it retunes EVERY pitched voice.
//   2. `Core/TuningDetector.swift`'s own header named `MicrophoneManager.pitch /
//      .frequency` as its source. `MicrophoneManager` was deleted with #1302, and the
//      deletion is structural: `AudioConfiguration.RecordRouteOwner` is an UNINHABITED
//      enum, so `claimRecordRoute(_:)` cannot be called at all. The header therefore
//      read as "parked until the mic returns", when the honest reading is "no producer,
//      and its natural producer today is an imported audio FILE".
//
// ⭐ THE EXPENSIVE HALF OF (2) IS NOT THE STALE NAME. `DetectedTuning` already carries
// `keyRoot`, `isMinor`, `confidence`, `a4Hz` and `centsOffset`, and `analyze` already
// returns nil when the evidence is thin — i.e. it already satisfies "never force
// uncertain material into a confident musical label". Anyone building detected
// key/scale analysis without knowing that builds a SECOND one. Claim 5 is what keeps
// that shape pinned, and it is a counterweight, not a catch.
//
// ⭐ THAT DAY ARRIVED IMMEDIATELY, AND THE PARAGRAPH BELOW IS WHAT IT LOOKED LIKE. This
// note used to read *"It does NOT forbid giving `TuningDetector` a producer — that is the
// point of writing it down. On the day one lands, claim 3 goes red BY DESIGN and its
// message says to move the register entry in the same commit."* Phase E landed that
// producer one commit later: `Sequencer/AudioKeyAnalysis` reads an IMPORTED FILE, and
// claim 3 is now inverted to name it. The prediction is kept rather than deleted because
// it is the evidence that the absence claim was written to be retired, not defended — and
// because the next absence claim in this bundle should be written the same way.
//
// ⚠️ WHAT MUST NOT BE READ INTO THIS (#364). It does NOT pin the NUMBER of pitched voices:
// a new retuned voice must not turn this
// file red, so claim 2 asserts the SEVEN NAMED receivers rather than a total (#903 — a
// count pin rots when the code changes correctly and the number does not follow).
//
// ⛔ AND IT MUST NOT BE READ AS "THE MIC MIGHT COME BACK CHEAPLY". Restoring an audio
// input is a founder decision (#1302, founder 2026-09-12 verbatim: "Face und Audio Input
// komplett entfernen"), and it carries a plist obligation — adding a case to
// `RecordRouteOwner` requires `NSMicrophoneUsageDescription` back in the SAME commit or
// iOS terminates the app. That is stated at `AudioConfiguration`, not re-decided here.
//
// ⚠️ HONEST GRADING (§3), and my first draft of THIS paragraph was wrong in both
// directions — it said "eleven assertions" and named two catches. Measured, not
// remembered: **11 `XCTAssert` CALL SITES across 7 claims, expanding to 21 assertions at
// runtime** — two of the eleven sit in loops (claim 1 runs five keyword variants, claim 2
// seven receivers), so 11 − 2 + 5 + 7 = 21. The Python transcription drove **17 distinct
// propositions**, folding claim 1's five variants into one (they are one fact) and keeping
// claim 2's seven apart (they are seven facts).
//
// ⚠️ COUNT FROM `final class` DOWN — `grep -c XCTAssert` over the WHOLE file over-counts,
// because this header names the token (#708: a note that cites a count can become its own
// hit). The command that measures the claims rather than the prose about them is
// `awk '/^final class/,0' <file> | grep -c XCTAssert`.
//
// Against the tree this file was WRITTEN on (`ba1eed686`): **4 REGRESSION CATCHES, 13
// COUNTERWEIGHTS, 0 red.** The catches were claim 4 (the header named a deleted producer
// with no retraction) and all THREE assertions of claim 7 (the law file cited the tone
// system by file WITHOUT `.swift`, never named the type `TuningSystem`, and carried no
// register entry for `Core/TuningDetector`). I had booked only two, i.e. UNDER-counted —
// the same defect as over-counting, recorded here rather than quietly fixed (§3).
//
// ⚠️ THAT GRADING IS A DATE, NOT A STANDING FACT, and it is left as history on purpose.
// Phase E changed claim 3 from an absence to a named producer in the very next commit, so
// the catch/counterweight split above describes the file as it was first written. Re-grade
// against the current parent before quoting it.
//
// The 13 counterweights are green on both trees (#343) and are the content: this slice
// corrected two CITATIONS and added a register entry, it changed no behaviour. What they
// buy is the day a producer lands, a voice stops being retuned, or a second key owner
// appears.
//
// Needles re-derived by `grep` before this file was written (#808), comment-stripped
// where the claim demands code: `public struct TuningSystem` = 1 · a type declaration
// named `MicrotonalTuning` anywhere in `Sources/` = 0 · each of the seven
// `…setTuningCents(` receivers = 1 · `-> DetectedTuning?` = 1 ·
// `public var confidence: Double` = 1 · the `SessionContext` keyRoot `didSet` = 1.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheToneSystemIsNamedByItsTypeTests: XCTestCase {

    private static let toneSystemFile = "Sources/Echoelmusic/Sequencer/MicrotonalTuning.swift"
    private static let detectorFile = "Sources/Echoelmusic/Core/TuningDetector.swift"
    private static let fanOutFile = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let keyOwnerFile = "Sources/Echoelmusic/Core/SessionContext.swift"
    private static let lawFile = "CLAUDE.md"

    /// The seven receivers the law file now names. Each is asserted individually rather
    /// than counted, so an EIGHTH retuned voice is a legal addition (#364).
    private static let retunedVoices = [
        "synth.setTuningCents(",
        "touchSynth?.setTuningCents(",
        "leadSynth?.setTuningCents(",
        "bassSynth?.setTuningCents(",
        "subBass.setTuningCents(",
        "bioVoice.setTuningCents(",
        "laneVoiceRack.setTuningCents("
    ]

    private func repoRoot() throws -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }

    /// Raw text — for claims ABOUT prose (headers, the law file).
    private func text(_ relative: String) throws -> String {
        let url = try repoRoot().appendingPathComponent(relative)
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: \(relative) could not be read — a missing anchor is a "
                    + "finding, not a pass (#454/#1240).")
            return ""
        }
        return contents
    }

    /// Comment-stripped text — for claims about CODE. `SourceText.codeOnly` is the one
    /// definition of "code, not prose" (#453); this repo writes ⛔ blocks that NAME the
    /// very symbols they retract, and this slice just added three more of them.
    private func code(_ relative: String) throws -> String {
        SourceText.codeOnly(try text(relative))
    }

    /// Comment-stripped code of every `.swift` file under `Sources/`, one string.
    private func sourcesCode() throws -> String {
        let dir = try repoRoot().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(atPath: dir.path) else {
            XCTFail("Sources/ is present but not enumerable — re-anchor rather than skip (#454).")
            return ""
        }
        var out = ""
        for case let rel as String in walker where rel.hasSuffix(".swift") {
            let contents = try String(contentsOf: dir.appendingPathComponent(rel), encoding: .utf8)
            out += SourceText.codeOnly(contents) + "\n"
        }
        guard !out.isEmpty else {
            XCTFail("walked Sources/ and read nothing — the scan found nothing, not nothing wrong.")
            return ""
        }
        return out
    }

    // MARK: - claim 1 — the file is not the type

    /// The #1376 trap, pinned from both sides: the file declares `TuningSystem`, and NO
    /// type named `MicrotonalTuning` exists anywhere under `Sources/`. Without the second
    /// half this claim would pass on a tree that added such a type and left the law file's
    /// warning describing a problem that no longer exists.
    func testTheFileDeclaresTuningSystemAndNoTypeIsNamedAfterTheFile() throws {
        XCTAssertTrue(try code(Self.toneSystemFile).contains("public struct TuningSystem"), """
            \(Self.toneSystemFile) no longer declares `public struct TuningSystem`. The law \
            file cites BOTH the file and the type precisely so a rename cannot leave a \
            session grepping for a name that resolves to nothing — move the citation in \
            this commit.
            """)

        let all = try sourcesCode()
        for keyword in ["struct MicrotonalTuning", "enum MicrotonalTuning",
                        "class MicrotonalTuning", "protocol MicrotonalTuning",
                        "typealias MicrotonalTuning"] {
            XCTAssertFalse(all.contains(keyword), """
                A type named `MicrotonalTuning` now exists (`\(keyword)`). The law file warns \
                that the file name resolves to NO type — that warning is now false and must be \
                rewritten in this commit, or the next reader distrusts the rest of the line.
                """)
        }
    }

    // MARK: - claim 2 — it really does reach every pitched voice

    /// The law file says "das Tonsystem JEDER gestimmten Stimme". That is a claim about
    /// neighbours (#867: whoever asserts over a neighbour must measure the neighbour), so
    /// each named receiver is asserted on its own. A count is deliberately NOT pinned.
    func testEveryNamedPitchedVoiceReceivesTheToneSystem() throws {
        let fanOut = try code(Self.fanOutFile)
        for receiver in Self.retunedVoices {
            XCTAssertTrue(fanOut.contains(receiver), """
                `\(receiver)` is gone from \(Self.fanOutFile). The law file names this receiver \
                in its list of every pitched voice the tone system reaches; either the voice \
                stopped being retuned (a real regression — a non-12-TET system would then play \
                12-TET against retuned neighbours, the #114 concert-pitch gap again) or it was \
                renamed and the law file's list must follow in this commit.
                """)
        }
    }

    // MARK: - claim 3 — the detector has EXACTLY ONE production caller, and it is the file one

    /// ⭐ THIS CLAIM WAS INVERTED IN THE COMMIT THAT MADE IT FALSE, which is the only honest
    /// way to retire an absence claim (#1437 did the same thing to "`TimelineRegionPlayer.play`
    /// has zero callers"). It used to read `testTheTuningDetectorStillHasNoProductionCaller`
    /// and assert `callers.isEmpty`. Phase E gave the detector a producer —
    /// `Sequencer/AudioKeyAnalysis`, reading an IMPORTED FILE — so the old form would have
    /// gone red on correct work, and its failure message said in as many words what to do:
    /// *"That is progress, not a defect … Move both in this commit, and say which producer
    /// supplies the fundamentals (the import path, not a microphone: #1302)."* This is that
    /// move. The claim is NOT weakened to an inequality: it names the one caller, so a SECOND
    /// producer is still a finding that has to be written down.
    func testTheTuningDetectorHasExactlyOneProducerAndItIsTheFileAnalysis() throws {
        let dir = try repoRoot().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(atPath: dir.path) else {
            XCTFail("Sources/ is present but not enumerable — re-anchor rather than skip (#454).")
            return
        }
        var callers: [String] = []
        for case let rel as String in walker where rel.hasSuffix(".swift") {
            guard !rel.hasSuffix("TuningDetector.swift") else { continue }
            let contents = try String(contentsOf: dir.appendingPathComponent(rel), encoding: .utf8)
            if SourceText.codeOnly(contents).contains("TuningDetector") { callers.append(rel) }
        }
        XCTAssertEqual(callers, ["Sequencer/AudioKeyAnalysis.swift"], """
            `TuningDetector`'s production callers are \
            \(callers.isEmpty ? "NONE" : callers.joined(separator: ", ")) — expected exactly \
            `Sequencer/AudioKeyAnalysis.swift`. If the list is EMPTY the producer was lost and \
            the detector is an orphan again: CLAUDE.md's register entry and this file's header \
            must go back to saying so. If there is a SECOND caller, say what it is and why it \
            is not a duplicate estimator — #C1 recorded that the value and the estimator \
            already existed, and minting a parallel one is the mistake both were written to \
            prevent (#416). The producer must stay the FILE path: audio input is a founder \
            hold (#1302), so a microphone-shaped caller here is a regression, not a feature.
            """)
    }

    // MARK: - claim 4 — the header cannot silently name a deleted producer again

    /// ⚠️ This is NOT "the file must not contain the word `MicrophoneManager`" — it DOES
    /// contain it, inside the retraction, and a bare absence scan would therefore be red on
    /// the correct tree (#367, the mirror case). What is pinned is the RETRACTION: the
    /// deletion's number must stand beside the name.
    func testTheDetectorHeaderRetractsItsDeletedProducer() throws {
        let header = try text(Self.detectorFile)
        guard header.contains("MicrophoneManager") else { return }
        XCTAssertTrue(header.contains("#1302"), """
            \(Self.detectorFile) names `MicrophoneManager` without naming #1302. That type was \
            deleted on 2026-09-12 and the deletion is structural — `RecordRouteOwner` is an \
            uninhabited enum, so no code path can claim a record route. A header that names a \
            deleted producer without saying it is deleted reads as "parked until the mic \
            returns", which is the exact misreading this slice repaired.
            """)
    }

    // MARK: - claims 5 to 7 — counterweights

    /// COUNTERWEIGHT. The shape a future key/scale analysis must REUSE rather than mint
    /// again: a confidence field, and an Optional return so thin evidence stays unlabelled.
    func testTheDetectedTuningStillCarriesConfidenceAndCanRefuseToAnswer() throws {
        let detector = try code(Self.detectorFile)
        XCTAssertTrue(detector.contains("public var confidence: Double"), """
            `DetectedTuning.confidence` is gone. It is the field that keeps an uncertain \
            estimate from being shown as a confident musical fact; anything replacing it must \
            carry the same distinction.
            """)
        XCTAssertTrue(detector.contains("-> DetectedTuning?"), """
            `analyze` no longer returns an Optional. The nil return IS the "not enough \
            evidence" answer — making it total would force every input into a confident key.
            """)
    }

    /// COUNTERWEIGHT. One persisted owner for the session key. If a second appears, the
    /// census conclusion ("the value types exist, the owner exists, only the producer is
    /// missing") stops being true and Phase E has to be re-measured.
    func testTheSessionContextIsStillTheOnePersistedKeyOwner() throws {
        XCTAssertTrue(try code(Self.keyOwnerFile)
            .contains("didSet { defaults.set(keyRoot, forKey: Key.keyRoot) }"), """
            `SessionContext` no longer persists `keyRoot` through that `didSet`. It is the one \
            live owner of the session key; a second persisted owner is a second musical truth \
            and must be raised before it ships.
            """)
    }

    /// COUNTERWEIGHT. The law file must keep BOTH names. Citing only the file is what this
    /// slice repaired; citing only the type would lose the pointer to where it lives.
    func testTheLawFileCitesBothTheFileAndTheType() throws {
        let law = try text(Self.lawFile)
        XCTAssertTrue(law.contains("MicrotonalTuning.swift"), """
            CLAUDE.md no longer names the FILE `MicrotonalTuning.swift`. Both names are load- \
            bearing: the type is what a grep resolves, the file is where it lives.
            """)
        XCTAssertTrue(law.contains("`TuningSystem`"), """
            CLAUDE.md no longer names the TYPE `TuningSystem`. Citing the file alone is the \
            #1376 trap this slice repaired — a session greps the file name, finds no type, and \
            can read a live tone system as dead.
            """)
        XCTAssertTrue(law.contains("`Core/TuningDetector`"), """
            The orphan-register entry for `Core/TuningDetector` is gone from CLAUDE.md. It is \
            the entry that stops a future key-detection slice minting a second `DetectedTuning`.
            """)
    }
}
