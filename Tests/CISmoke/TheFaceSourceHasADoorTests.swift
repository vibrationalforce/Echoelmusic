// TheFaceSourceHasADoorTests.swift
// Echoel — #1257 (was `TheFaceSourceHasNoDoorTests`, #1002). Blocking bundle. SOURCE-TEXT
// SCAN plus two BEHAVIOUR claims (`Tests/CISmoke/CLAUDE.md` §1): it proves where the door's
// construction sites sit and what the enums answer, never that ARKit tracks a face.
//
// ⭐ WHAT CHANGED. #1002 registered `FaceExpressionBioPublisher` as a finished input modality
// with ZERO construction sites, and its guard said in every message what must travel with the
// wiring commit: the register line, the purpose string, the EU AI Act framing, the picker's
// case list, `hasProducer`. #1257 is that commit (founder prompt "Kamera als Instrument-
// Eingang", 2026-09-11): ONE construction site in `EchoelmusicApp`, `BioSourceOption.face`
// offered only where `FaceExpressionBioPublisher.isSupported`, the three face `ModSource`s
// producing, the camera string naming both lenses, and the header keeping its framing.
//
// ⚠️ #364 — THIS GUARD DOES NOT FORBID CLOSING THE DOOR AGAIN. Every message says what else
// moves in that commit. Whether a face actually moves a parameter is a DEVICE probe
// (NEEDS-FOUNDER-VERIFY in the publisher's header), not a claim here.
//
// ⚠️ HONEST GRADING (#433/#464), transcribed in Python against the parent (1438077) and
// this tree. Claims 1, 2, 3, 5, 6 are RED on the parent for exactly their named reason (no
// construction site, no `face` case, `hasProducer` false, rear-lens-only string, register
// naming the OLD guard). Claim 4 is MIXED: the EU AI Act needle is the COUNTERWEIGHT (green
// on both trees), the device-ask and `didFailWithError` needles are RED on the parent — the
// header had no ask and the delegate no failure path before #1257. Claims 2 and 3 are
// BEHAVIOUR on the shipped enums and cannot compile against the parent (no `face` case) —
// per §3 that is ONE finding, not a stripper artefact. ⛔ The first draft of claim 5 needled
// "not stored or transmitted" against a string that says "No images are stored or
// transmitted" — the transcription caught it RED on this very tree before the commit.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheFaceSourceHasADoorTests: XCTestCase {

    private static let publisherFile = "Sources/Echoelmusic/Bio/FaceExpressionBioPublisher.swift"
    private static let appFile = "Sources/Echoelmusic/EchoelmusicApp.swift"
    private static let plistFile = "Resources/iOS/Info.plist"

    private func repoRoot() throws -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }

    /// Comment-stripped text of every `.swift` file under `Sources/`, one string (#453/#762:
    /// this repo's ⛔ blocks name the types they discuss, so a raw scan would count prose).
    private func sourcesCode() throws -> String {
        let root = try repoRoot()
        let dir = root.appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(atPath: dir.path) else {
            XCTFail("Sources/ is present but not enumerable — re-anchor rather than skip (#454).")
            return ""
        }
        var out = ""
        for case let rel as String in walker where rel.hasSuffix(".swift") {
            let text = try String(contentsOf: dir.appendingPathComponent(rel), encoding: .utf8)
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

    /// claim 1 — exactly ONE construction site, and it is the app (the publishers' one home).
    func testExactlyTheAppConstructsTheFaceSource() throws {
        let calls = try sourcesCode().components(separatedBy: "FaceExpressionBioPublisher(").count - 1
        XCTAssertEqual(calls, 1, """
            `FaceExpressionBioPublisher` has \(calls) construction site(s); #1257 wired exactly \
            one, in `EchoelmusicApp` beside the other three publishers. Zero means the door is \
            closed again — then the register line in `CLAUDE.md` (#1002/#1257) and the picker's \
            `face` case must move in the same commit; two means a second lifecycle owner, the \
            BLE-3 class of bug (two owners killed straps mid-performance).
            """)
        let app = SourceText.codeOnly(try file(Self.appFile))
        XCTAssertTrue(app.contains("FaceExpressionBioPublisher()"), """
            The one construction site is no longer `EchoelmusicApp`. Publishers are constructed \
            at app level and handed down by `.environment` so the studio's source picker is \
            their ONLY starter — a publisher built inside a view has as many lifecycles as the \
            view has appearances.
            """)
        XCTAssertTrue(app.contains(".environment(faceExpression)"), """
            `EchoelmusicApp` no longer injects `faceExpression` — the studio's \
            `@Environment(FaceExpressionBioPublisher.self)` would then crash at first read.
            """)
    }

    /// claim 2 (BEHAVIOUR) — the picker has the case, labelled honestly.
    func testTheSourcePickerOffersFaceHonestly() {
        XCTAssertEqual(BioSourceOption.face.rawValue, "face", """
            `BioSourceOption.face`'s raw value is the on-the-wire id `selectBioSource` parses \
            through its private `BioSourceKind(rawValue:)` — a mismatch is a menu entry that \
            does nothing (#135).
            """)
        XCTAssertTrue(BioSourceOption.face.menuLabel.hasPrefix("Play with"),
                      "the face entry starts the music when idle — the prefix is the honesty (#234)")
        XCTAssertTrue(BioSourceOption.face.menuLabel.contains("no pulse"), """
            The face label no longer says "no pulse". A `.faceCam` frame carries \
            `heartRateBPM: 0` by design; the player choosing it must know the pulse is not \
            being read (the composer holds the last body or its neutral).
            """)
    }

    /// claim 3 (BEHAVIOUR) — the three face channels are producing, so the carrier pickers
    /// may offer them (`FXModCarrier.allChoices` filters on this).
    func testTheFaceChannelsHaveAProducer() {
        for source in [ModSource.faceSmile, .faceBrow, .faceJaw] {
            XCTAssertTrue(source.hasProducer, """
                `ModSource.\(source)`.hasProducer is false while `FaceExpressionBioPublisher` \
                is constructed and startable (#1257). A producing channel hidden from the \
                pickers is the opposite lie to #215's — flip it back only together with the \
                door.
                """)
        }
        XCTAssertFalse(ModSource.motion.hasProducer,
                       "motion still has no producer (#215) — nothing in #1257 measured movement")
    }

    /// claim 4 — COUNTERWEIGHT: the file keeps the two facts that must travel.
    func testTheFileStillCarriesItsFraming() throws {
        let text = try file(Self.publisherFile)
        XCTAssertTrue(text.contains("EU AI Act"), """
            The EU AI Act framing is gone from \(Self.publisherFile). It is not decoration: it \
            is the reason this type publishes movement rather than an inferred affective state. \
            Do not remove it without a founder decision.
            """)
        XCTAssertTrue(text.contains("NEEDS-FOUNDER-VERIFY"), """
            The publisher's header lost its device ask. No gate here can see a face; the ask is \
            what puts the probe on the founder's list (`scripts/founder-verify.py`).
            """)
        XCTAssertTrue(text.contains("didFailWithError"), """
            The delegate no longer handles `didFailWithError`. A denied or revoked camera \
            permission then leaves `isPublishing` true with a session that never runs — the \
            silent "face never arrives" the prompt forbids.
            """)
    }

    /// claim 5 — the ONE app-wide camera string names BOTH lenses and both uses.
    func testTheCameraStringNamesBothLenses() throws {
        let plist = try file(Self.plistFile)
        guard let keyRange = plist.range(of: "<key>NSCameraUsageDescription</key>") else {
            XCTFail("NSCameraUsageDescription missing from Info.plist — the rPPG prompt would show an empty reason.")
            return
        }
        let tail = String(plist[keyRange.upperBound...])
        guard let open = tail.range(of: "<string>"), let close = tail.range(of: "</string>") else {
            XCTFail("camera usage string malformed — re-anchor (#454).")
            return
        }
        let value = String(tail[open.upperBound..<close.lowerBound])
        for needle in ["rear", "front", "control signal", "No images are stored or transmitted"] {
            XCTAssertTrue(value.contains(needle), """
                `NSCameraUsageDescription` no longer says "\(needle)". iOS shows ONE string for \
                both the rear-lens pulse and the front-camera face input; a string that names \
                only one use lies at the other prompt (App Store 5.1.1). Founder-authorised \
                wording (#1257 prompt: "in einem Satz und ehrlich").
                """)
        }
        XCTAssertFalse(value.lowercased().contains("emotion") && !value.contains("never an inferred emotion"),
                       "the string may name emotion only to deny inferring it")
    }

    /// claim 6 — the register carries the door and names THIS guard.
    func testTheRegisterNamesTheDoor() throws {
        let law = try file("CLAUDE.md")
        XCTAssertTrue(law.contains("TheFaceSourceHasADoorTests"), """
            `CLAUDE.md`'s register entry for `FaceExpressionBioPublisher` no longer names this \
            guard — it still points at the #1002 "no door" guard, or the entry is gone. The \
            register is what a session reads to decide what already exists; an input modality \
            that is doored but registered as doorless sends the next session to rebuild it.
            """)
        XCTAssertTrue(law.contains("BioSourceOption.face"), """
            The register does not say WHERE the door is (`BioSourceOption.face`, the source \
            dropdown). Naming the file is not naming the door.
            """)
    }
}
