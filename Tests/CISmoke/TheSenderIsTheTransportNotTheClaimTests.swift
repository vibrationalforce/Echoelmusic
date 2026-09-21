// TheSenderIsTheTransportNotTheClaimTests.swift
// Echoel — #517. Who a Live Colabo payload is FROM is a transport fact, not a payload field.
//
// THE DEFECT. `MCSessionDelegate.session(_:didReceive:fromPeer:)` hands over an AUTHENTICATED
// `MCPeerID` alongside the bytes. `handleData` took only the bytes, and then keyed
// `peerReadings`, filled `incoming`, and worded `status` from `payload.senderName` — a field the
// SENDER writes into the JSON. Meanwhile `handleStateChange` cleans up by `peerID.displayName`.
// Two different names for one peer, and the receiving side believed the wrong one.
//
// ⭐ THE SECOND CONSEQUENCE IS THE ONE THAT MADE THIS WORTH A SLICE, and it is not "someone can
// lie about their name". A reading filed under a key the disconnect path never clears is a row
// that survives every disconnect for the rest of the process — a peer who has LEFT keeps a line
// on the screen. That is exactly the property #508 was built to give ("a quiet peer stops
// looking alive"), defeated through the KEY rather than through the timestamp, which is why
// #508's freshness guard cannot see it: the reading in that row is genuinely fresh, it is the
// ROW that should not exist.
//
// ⭐ ONE WRITE, NOT FOUR (#416). The claim is replaced with the fact ONCE, at the boundary, via
// `ColabPayload.attributed(to:)`. The alternative was to fix each reader — the reading key, the
// status line, the import card — i.e. three places that must all keep remembering not to trust a
// field sitting right there. **So the downstream reads are DELIBERATELY UNCHANGED**, and there
// is no negative needle forbidding `payload.senderName`: after attribution that field IS the
// transport name, and forbidding a correct read is the #364 trap that gets guards deleted.
//
// ⚠️ SCOPE, said first: this file fixes AUTHORITY, not IDENTITY — and IDENTITY was fixed
// separately by #1435, which is why this paragraph is corrected rather than left standing. It
// read: *"Three phones in a room are still three peers called \"iPhone\" and still collide into
// one row (#513)."* True until 2026-09-21; the advertised string is now a
// `PeerIdentity.transportName` and `peerReadings` is keyed by `stableID`.
//
// ⭐ CLAIM 4 STILL HOLDS AND IS STILL THE POINT, because it is a claim about `attributed(to:)`
// and not about the transport: attribution maps whatever string it is handed onto the payload,
// so two peers handed the SAME string still land in one row. That is exactly why the ORDER
// mattered — a unique key handed out before attribution existed would have let a sender claim
// somebody else's key, which is a worse defect than a shared one.
//
// ⚠️ AND THE LIMIT OF THE GUARD: claims 5–7 are SOURCE SCANS. `MultipeerSession` sits behind
// `#if canImport(MultipeerConnectivity)` and needs a real MC stack, so this bundle cannot drive
// the receive path. **That two phones actually stop being able to write into each other's rows
// is a TWO-DEVICE trial and is OPEN.** Claims 1–4 are real behaviour, end to end, because
// `ColabPayload` is `public` and Foundation-only.
//
// ⚠️ HONEST GRADING (#433), and it is the #464 situation said plainly rather than dressed up:
// this file **cannot be graded against the parent tree at all** — four behaviour cases name
// `ColabPayload.attributed(to:)`, which does not exist there, so the bundle does not compile and
// NO claim has a verdict. Transcribed by hand instead (a Python rebuild of `SourceText.codeOnly`
// plus the brace matcher, each needle driven separately against `git show HEAD:` and the
// worktree):
//   · claim 5 — RED on the parent, TWICE, for two DIFFERENT facts: the signature takes no peer,
//     AND the decode carries no `.attributed(to:`. Both are kept because a version that took the
//     peer and then still keyed by the decoded field would satisfy a signature check alone.
//   · claim 6 — RED, but on ONE absence reported twice: the parent's delegate body is the single
//     line `self?.handleData(data)`, so neither needle can be there. Said this way rather than
//     counted as two findings (#486).
//   · claims 1–4, and claim 8's second assertion — could never have been red: they drive a
//     method the same commit adds. Booking them as regressions would be the #433 defect in the
//     flattering direction.
//   · claims 4, 7, 8a — GREEN on BOTH trees, and they are the content. The obvious later
//     cleanups were "attribution makes names unique, so drop #513" and "the disconnect cleanup is
//     redundant now". The first is false; the second re-opens the phantom row from the other end.
//     ⭐ #1435 RE-ANCHORED claim 7 (formerly 7a–7c): it spelled both `peerReadings` keys, both
//     naming a LOCAL, and that slice changed both at once. It now pins the PAIRING — the arrival
//     site and the disconnect site must use ONE key expression — which is what the file actually
//     cares about and is rename-proof. Claim 5 gained the `peerName → peer → displayName` chain
//     for the same reason.
//
// ⚠️ `SourceText.codeOnly` is PROPHYLACTIC here, and that is MEASURED rather than assumed
// (#484/#485 each had to withdraw the stronger claim once, #486 twice): raw versus stripped
// differ on **0 of 11** needle verdicts, on BOTH trees — because every needle is a positive
// `contains` and this slice writes no retraction that spells one out. It stays because #453 made
// ONE definition of "code, not prose" for the whole blocking bundle, and it stops being
// prophylactic the moment someone writes a retraction here quoting `handleData(_ data: Data)`.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheSenderIsTheTransportNotTheClaimTests: XCTestCase {

    private static let session = "Sources/Echoelmusic/Sync/MultipeerSession.swift"
    private static let payload = "Sources/Echoelmusic/Sync/ColabPayload.swift"

    private func peek() -> BioPeek {
        BioPeek(bpm: 64, coherence: 0.5, hrvNormalized: 0.4, breathRate: 6)
    }

    // MARK: - 1. The claim is replaced by the fact

    func testTheTransportNameWinsOverTheField() {
        let claimed = ColabPayload(kind: "bio", senderName: "Trusted Phone", bio: peek())
        XCTAssertEqual(claimed.attributed(to: "iPhone").senderName, "iPhone", """
            A payload must come out of `attributed(to:)` bearing the name the TRANSPORT \
            authenticated, not the one the sender typed. Everything downstream — the reading \
            key, the status line, the import card — reads this one field.
            """)
    }

    // MARK: - 2. It changes exactly that one field

    func testNothingElseTravelsDifferently() {
        let original = ColabPayload(kind: "session", senderName: "Trusted Phone", bio: peek())
        var expected = original
        expected.senderName = "iPhone"

        // Whole-value, so a future field added to the payload is covered without editing this
        // file. Said plainly: this mirrors the implementation, so its value is FORWARD — it goes
        // red if a later version starts dropping `project` or `bio` while re-attributing.
        XCTAssertEqual(original.attributed(to: "iPhone"), expected, """
            Attribution is a rename, not a filter. A boundary rewrite that also dropped a field \
            would silently discard the project a peer is offering — a data loss wearing the \
            clothes of a security fix.
            """)
        XCTAssertEqual(original.attributed(to: "iPhone").kind, "session")
        XCTAssertEqual(original.attributed(to: "iPhone").bio, peek())
    }

    // MARK: - 3. End to end over real bytes, in the receive path's own shape

    func testAForgedNameDoesNotSurviveDecodeAndAttribution() throws {
        let forged = ColabPayload(kind: "bio", senderName: "Michael's iPhone", bio: peek())
        let data = try XCTUnwrap(forged.encoded(), "the fixture payload must encode")

        let received = try XCTUnwrap(ColabPayload.decode(data)?.attributed(to: "iPad"))
        XCTAssertEqual(received.senderName, "iPad", """
            This is the exact expression the receive path runs. If decode-then-attribute ever \
            stopped producing the transport name, a peer could file a bio reading into any row \
            it liked — including a row for a name that is not in the session at all, which the \
            disconnect path could then never clear (#508's property, defeated through the key).
            """)
        XCTAssertEqual(received.bio, peek(), "the reading itself must survive the rewrite")
    }

    // MARK: - 4. COUNTERWEIGHT — this does not make names unique

    func testAttributionDoesNotInventIdentity() {
        let a = ColabPayload(kind: "bio", senderName: "A", bio: peek()).attributed(to: "iPhone")
        let b = ColabPayload(kind: "bio", senderName: "B", bio: peek()).attributed(to: "iPhone")
        XCTAssertEqual(a.senderName, b.senderName, """
            Attribution maps whatever string it is handed onto the payload — so two peers \
            handed the SAME string still collide into one row. That they are no longer handed \
            the same string is #1435 (`PeerIdentity`), a SEPARATE mechanism one layer out. This \
            assertion exists so this file cannot be read as having solved identity: fixing \
            AUTHORITY first is what made a unique key safe rather than merely different.
            """)

        // Idempotent: attributing twice is attributing once. The receive path applies it exactly
        // once today, but a future forward/relay step must not be able to compound it.
        XCTAssertEqual(a.attributed(to: "iPhone"), a)
    }

    // MARK: - 5. The boundary takes the transport peer and uses it

    func testHandleDataIsGivenThePeerAndAppliesIt() throws {
        let src = try code(at: Self.session)

        // #367: anchor FIRST. A bare "the new form is present" scan says nothing on a tree that
        // lost the method entirely, and a bare "the old form is absent" scan would pass on an
        // empty file.
        guard src.contains("private func handleData(") else {
            throw AnchorMissing(reason: """
                MultipeerSession no longer declares `handleData` — the anchor for this scan is \
                gone. Re-anchor it; do not let the absence read as a pass.
                """)
        }
        XCTAssertTrue(src.contains("private func handleData(_ data: Data, from peerName: String)"),
                      """
                      `handleData` must RECEIVE the authenticated peer. Taking only the bytes is \
                      what made the receiving side believe a field the sender writes.
                      """)
        // ⛔ THIS ASSERTION USED TO READ `attributed(to: peerName)` AND #1435 SPLIT THAT ONE
        // STRING IN TWO. The transport name is now a `PeerIdentity.transportName` — label,
        // separator, stable key — so passing it through unparsed would put a UUID on the import
        // card. The LAW is unchanged and is what is pinned: the argument must descend from the
        // transport parameter, never from the decoded payload.
        let arrival = try declarationBody(
            of: "private func handleData(_ data: Data, from peerName: String) {", in: Self.session)
        XCTAssertTrue(arrival.contains("PeerIdentity.resolve(transportName: peerName)"), """
            The boundary must resolve the AUTHENTICATED transport name into an identity. \
            Resolving anything else — or resolving nothing — is how the receiving side started \
            believing a field the sender writes.
            """)
        XCTAssertTrue(arrival.contains("ColabPayload.decode(data)?.attributed(to: peer.displayName)"),
                      """
                      Receiving the peer is not enough — the payload must be re-attributed at the \
                      boundary, with the label that came OUT of the transport name. A version that \
                      took `peerName` and then still keyed by the decoded field would pass a \
                      signature check and change nothing.
                      """)
        XCTAssertFalse(arrival.contains("attributed(to: payload."), """
            Attributing FROM the payload is the defect itself, written the other way round: it \
            would replace the sender's claim with the sender's claim.
            """)
    }

    // MARK: - 6. The delegate hands over the authenticated name

    func testTheDelegatePassesTheAuthenticatedPeer() throws {
        // `declarationBody` throws `AnchorMissing` by itself when the method is gone or
        // reshaped — deliberately NOT wrapped in `try?`, which would also swallow the
        // directory-gated `XCTSkip` and turn "no source tree" into a bogus failure.
        let body = try declarationBody(
            of: "public nonisolated func session(_ session: MCSession, didReceive data: Data, "
              + "fromPeer peerID: MCPeerID) {", in: Self.session)
        XCTAssertTrue(body.contains("peerID.displayName"), """
            The delegate must read the peer the transport authenticated. This is the single \
            point where the fact exists at all — everything after it is downstream of this line.
            """)
        XCTAssertTrue(body.contains("handleData(data, from: name)"), """
            …and must pass it on. Reading `peerID.displayName` into a local and then dropping it \
            is the defect this slice removes, one line later.
            """)
    }

    // MARK: - 7. COUNTERWEIGHT — the two sides must key on the SAME thing

    /// ⛔ THIS CLAIM USED TO SPELL BOTH KEYS — `peerReadings[payload.senderName] = PeerReading(`
    /// and `peerReadings[name] = nil` — and #1435 changed both at once (to
    /// `PeerIdentity.stableID`, because two phones advertising the same device name wrote into
    /// ONE entry and mixed two bodies into a single reading). Two spellings of one decision,
    /// each naming a LOCAL VARIABLE: the fragile kind (`Tests/CISmoke/CLAUDE.md` §3).
    ///
    /// ⭐ WHAT THE FILE ACTUALLY CARES ABOUT IS THE PAIRING, so that is what is pinned now: the
    /// arrival path and the disconnect path must subscript `peerReadings` with the SAME
    /// expression. A phantom row — the #517 defect — is precisely the state where those two
    /// expressions differ, whatever either one happens to be called. This is rename-proof and
    /// still fails for its named reason: make the two disagree and it goes red.
    func testTheTwoSidesOfTheReadingUseOneKey() throws {
        let src = try code(at: Self.session)
        let keys = Self.peerReadingKeys(in: src)

        guard keys.count >= 2 else {
            throw AnchorMissing(reason: """
                MultipeerSession subscripts `peerReadings` \(keys.count) time(s); this scan needs \
                the arrival site and the disconnect site. Re-anchor it rather than letting one \
                site read as agreement with itself.
                """)
        }
        XCTAssertEqual(Set(keys).count, 1, """
            Every `peerReadings[…]` must use ONE key expression. Found \(Set(keys).sorted()). A \
            reading filed under one key and cleared under another is the phantom row #517 exists \
            to end — it survives every disconnect for the rest of the process, and #508's \
            freshness window cannot reach it because the defect is in the KEY, not the clock.
            """)
        XCTAssertTrue(src.contains("peerReadings.removeAll()"), """
            Leaving the session must clear every reading. Otherwise the rows outlive the session \
            they belong to, which is the same phantom-row defect with a different cause.
            """)
    }

    /// Every subscript key written on `peerReadings`, in source order. Deliberately simple: the
    /// key is the text between the first `[` and the matching `]` on that occurrence, and a key
    /// containing a further `[` is not written anywhere in this file today.
    private static func peerReadingKeys(in src: String) -> [String] {
        var keys: [String] = []
        var cursor = src.startIndex
        while let open = src.range(of: "peerReadings[", range: cursor..<src.endIndex) {
            if let close = src.range(of: "]", range: open.upperBound..<src.endIndex) {
                keys.append(String(src[open.upperBound..<close.lowerBound]))
                cursor = close.upperBound
            } else {
                cursor = open.upperBound
            }
        }
        return keys
    }

    // MARK: - 8. COUNTERWEIGHT — the wire is unchanged

    func testTheFieldIsStillOnTheWire() throws {
        let src = try code(at: Self.payload)
        XCTAssertTrue(src.contains("public var senderName: String"), """
            `senderName` must stay on the payload. Deleting it would be a PROTOCOL change that \
            breaks a peer running an older build — #517 changes only what WE believe on receipt, \
            not what anyone sends.
            """)
        XCTAssertTrue(src.contains("public func attributed(to peerName: String) -> ColabPayload"),
                      "The boundary rewrite must live on the payload, where every receiver can "
                      + "reach it, rather than being re-implemented per call site (#416).")
    }

    // MARK: - Source access (house template)

    private struct AnchorMissing: Error { let reason: String }

    /// Directory-gated, never per-file (#475): a `fileExists` bracket around each read turns the
    /// very catastrophe this file guards against into a green SKIP.
    private func code(at relativePath: String) throws -> String {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path)
        else { throw XCTSkip("source tree not present under \(root.path)") }
        let path = root.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AnchorMissing(reason: """
                \(relativePath) is missing while the tree is present — it was renamed or moved. \
                Re-anchor this scan; do not let it skip (#454).
                """)
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }

    /// The brace-matched body following `key`, which must end in its opening brace.
    private func declarationBody(of key: String, in relativePath: String) throws -> String {
        let text = try code(at: relativePath)
        guard let start = text.range(of: key) else {
            throw AnchorMissing(reason: """
                \(relativePath) no longer declares `\(key)`. This scan is anchored on it; \
                re-anchor rather than deleting the assertion.
                """)
        }
        var depth = 0
        var index = text.index(before: start.upperBound)   // the opening brace itself
        while index < text.endIndex {
            if text[index] == "{" { depth += 1 }
            if text[index] == "}" {
                depth -= 1
                if depth == 0 { return String(text[start.upperBound..<index]) }
            }
            index = text.index(after: index)
        }
        throw AnchorMissing(reason: "Unbalanced braces after `\(key)` in \(relativePath).")
    }
}
