// TheRoutingCardDoesNotPromiseGestureTests.swift
// Echoel — #1333. The routing card's OSC copy and the published integration table both listed
// `gesture` among the addresses the default stream carries. #1301 deleted every producer of
// it — the face and body channels, on the founder's "Face und Audio Input komplett entfernen"
// (2026-09-12) — and `git grep -n "/gesture" -- Sources` finds nothing.
//
// ⭐ WHY THIS ONE IS WORSE THAN A STALE SENTENCE. One of the two in-app lines is the
// VOICEOVER HINT. A sighted operator reads the caption below it and can at least compare it
// against their own patch; a non-sighted operator gets ONLY the hint, so the false claim was
// the whole of what they were told about what leaves this device. An integrator who wired a
// `/echoelmusic/gesture/*` handler in TouchDesigner or Max got a listener that can never fire,
// and the card said it would.
//
// ⭐ WHAT REPLACED IT IS NOT A DELETION. Both lines now name `/echoelmusic/bio/synthetic`,
// which genuinely accompanies every value-carrying tick (#639) and is the one address an
// integrator most needs to latch. The gesture slot was the only place the copy said "and
// there is one more" — leaving a shorter list would have been honest and less useful.
//
// ⚠️ IT ALSO CARRIES #1329's UNIT. Both clinical lines now state pNN50's PERCENTAGE scale, so
// the card and `docs/integrations.html` agree with the wire. That is one slice's fact arriving
// in its second home (#456), not scope creep: the same two sentences were being rewritten.
//
// ⚠️ HONEST GRADING (§0/§3). No local Swift toolchain — **8 assertions across three claims**
// (claim 1 = 3, claim 2 = 3, claim 3 = 2), transcribed in Python and driven against BOTH trees.
// On the parent (`9935af3`) **5 are red and they are TWO findings** (#486), and the split does
// NOT follow the claim boundaries — worth stating, because reading it off the claim numbers
// gets it wrong: (a) `gesture` named in three copies is THREE assertions, two in claim 1 plus
// claim 2's address enumeration, whose old text ENDED in `/gesture/*`; (b) the missing pNN50
// unit is claim 2's other two. The COUNTERWEIGHTS (#343), green on both trees, are claim 1's
// anchor check and claim 3's two: the sender really does carry what the card names, so the
// copy is not merely internally consistent, and claim 1 cannot be satisfied by copy that
// promises nothing at all.
// SOURCE-TEXT / FILE-CONTENT SCAN (§1) throughout; that VoiceOver actually speaks the repaired
// hint is a device probe and stays open.

import Foundation
import XCTest

final class TheRoutingCardDoesNotPromiseGestureTests: XCTestCase {

    private static let patchbay = "Sources/Echoelmusic/Studio/PatchbayView.swift"
    private static let table = "docs/integrations.html"

    /// Claim 1 — no user-visible copy offers a gesture address, and no producer exists.
    func testNothingPromisesGesture() throws {
        let code = SourceText.codeOnly(try Self.text(Self.patchbay))
        XCTAssertFalse(code.isEmpty, "ANCHOR MISSING: could not read \(Self.patchbay) (#454).")
        XCTAssertFalse(
            code.localizedCaseInsensitiveContains("gesture"),
            "the routing card's copy still names `gesture`. #1301 deleted every producer, so a "
            + "`/echoelmusic/gesture/*` handler in TouchDesigner or Max can never fire — and "
            + "one of these two lines is the VoiceOver hint, i.e. the only version a non-sighted "
            + "operator hears. If the channels are rebuilt, this guard reports it (#364); it "
            + "does not forbid them.")
        XCTAssertFalse(
            try Self.text(Self.table).contains("coherence, breath, gesture"),
            "the published integration table still lists gesture in the default stream.")
    }

    /// Claim 2 — the clinical lines state pNN50's unit, and the card still names the addresses
    /// that DO ship. Without the third assertion, claim 1 would be satisfied by empty copy.
    func testTheClinicalLinesCarryTheUnitAndTheRealAddresses() throws {
        let code = SourceText.codeOnly(try Self.text(Self.patchbay))
        XCTAssertTrue(code.contains("/pnn50 (0–100 %) are sent as well"),
                      "the routing card no longer states pNN50's percentage scale. The wire "
                      + "carries a percentage (#1329); an integrator normalising by 1 saturates.")
        XCTAssertTrue(code.contains("pNN50 as a percentage ride the OSC stream"),
                      "the VoiceOver hint no longer states the unit — the sighted caption does, "
                      + "so leaving it out here is exactly the asymmetry this slice removed.")
        XCTAssertTrue(code.contains("/heart/bpm, /heart/hrv (0–1), /coherence, /breath/*, /synthetic"),
                      "the card no longer enumerates the default stream. Claim 1 must not be "
                      + "satisfiable by copy that promises nothing — `/echoelmusic/bio/synthetic` "
                      + "is the address an integrator most needs to latch (#639).")
    }

    /// Claim 3 — counterweight: the sender really does carry those addresses, so the copy is
    /// not merely internally consistent.
    func testTheSenderCarriesWhatTheCardNames() throws {
        let sender = SourceText.codeOnly(
            try Self.text("Sources/Echoelmusic/Sync/OSCSender.swift"))
        XCTAssertTrue(sender.contains("\"/echoelmusic/bio/synthetic\""),
                      "`OSCSender` no longer sends `/echoelmusic/bio/synthetic`, which the "
                      + "routing card now names to the operator (#639).")
        XCTAssertFalse(sender.contains("/echoelmusic/gesture"),
                       "`OSCSender` names a gesture address again. If the channels came back, "
                       + "the card's copy and the integration table move in the same commit.")
    }

    private static func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
