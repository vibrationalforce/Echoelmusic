// ThePeerKeyIsNotTheLabelTests.swift
// Echoel — #1435. The guard over `PeerIdentity`: a nearby peer's KEY and the string a human
// READS are two different values, and nothing may collapse them again.
//
// ⛔ THE DEFECT, MEASURED RATHER THAN ASSUMED. `MultipeerSession` built its `MCPeerID` from
// `UIDevice.current.name` and then used that ONE string as the key for `peerIDs`, for the
// `discovered` dedupe, for `peerReadings`, and as the `senderName` on every payload.
// `DiscoveredPeer.name` was literally `{ id }`. This repository declares no
// `com.apple.developer.device-information.user-assigned-device-name` entitlement, so on iOS 16+
// every stock iPhone reports the MODEL name — three phones in a room were ONE peer, and one
// `peerReadings["iPhone"]` entry mixed three bodies into a single reading.
//
// ⚠️ WHICH HALF IS PROVEN HERE, said before any claim (§1). The ENTITLEMENT half is measured in
// this repository (claim 9). The iOS BEHAVIOUR half — that `UIDevice.current.name` returns the
// model without it — is Apple's contract and this bundle cannot prove it. **That two real phones
// now appear as two rows is a TWO-DEVICE TRIAL and is OPEN** (NEEDS-FOUNDER-VERIFY, registered
// at `PeerIdentity`'s own header). Nothing below should be read as having run on hardware.
//
// ⭐ THE STRONG CLAIMS ARE REAL BEHAVIOUR, and that is a deliberate design choice in the type
// rather than luck: `PeerIdentity` is `public`, `Sendable`, Foundation-only, and
// `local(defaults:fallbackName:)` TAKES the `UserDefaults` it reads and the fallback label it
// might use — so claims 1–6 drive shipped code end to end instead of describing it. The
// alternative (reading `.standard` and `UIDevice` internally) would have made every one of them
// a source-text scan.
//
// ⚠️ CLAIMS 7–10 ARE SOURCE-TEXT SCANS and say so. `MultipeerSession` sits behind
// `#if canImport(MultipeerConnectivity)` and needs a real MC stack; `LiveColaboView` is SwiftUI
// this bundle cannot construct. They are the #343 counterweights: without them a tree could keep
// `PeerIdentity` perfectly and go on advertising the device name.
//
// ⚠️ HONEST GRADING (#433/#464). This file **cannot be graded against the parent tree at all**:
// every behaviour claim names `PeerIdentity`, which does not exist at `07ecc3b66`, so the bundle
// does not compile there and NO claim has a verdict — the #488 ambiguity, stated rather than
// left to read as "green against its own tree". Transcribed by hand instead (a Python rebuild of
// the transport encoding and of `SourceText.codeOnly`, each needle driven separately against
// `git show HEAD:` and the worktree):
//   · claims 1–6 — FORWARD guards. They drive a type this same commit adds and could never have
//     been red. Booking them as regressions would be the flattering-direction defect.
//   · claim 7 — RED on the parent for its named reason: `MCPeerID(displayName:)` is built from
//     the device name there, and `peerIDs` is keyed by `peerID.displayName`.
//   · claim 8 — RED on the parent: `senderName` is `myPeerID.displayName` at both send sites.
//   · claim 9 — GREEN on both trees, and it is the content: the entitlement is absent on both,
//     which is WHY the defect was the default case rather than an edge case.
//   · claim 10 — RED on the parent: `colab.invite(peer.name)`, and `DiscoveredPeer.name` is a
//     computed `{ id }` there, so the invite went out by label.
//
// ⚠️ `SourceText.codeOnly` is LOAD-BEARING here, MEASURED rather than assumed: claim 7's
// `peerIDs[peer.stableID]` needle and claim 8's negative both appear inside this slice's own
// retraction comments in `MultipeerSession.swift`. Raw versus stripped flips **2 of 9** scan
// verdicts on the worktree.

import Foundation
import XCTest
@testable import Echoelmusic

final class ThePeerKeyIsNotTheLabelTests: XCTestCase {

    private static let identity = "Sources/Echoelmusic/Sync/PeerIdentity.swift"
    private static let session = "Sources/Echoelmusic/Sync/MultipeerSession.swift"
    private static let colabView = "Sources/Echoelmusic/Studio/LiveColaboView.swift"

    // MARK: - 1. BEHAVIOUR — two phones with the same label are two peers

    func testTwoPeersWithTheIdenticalLabelStayApart() {
        let a = PeerIdentity(stableID: "A-1", displayName: "iPhone")
        let b = PeerIdentity(stableID: "B-2", displayName: "iPhone")

        XCTAssertNotEqual(a.stableID, b.stableID, """
            The whole defect in one line: two stock iPhones both report the model name, and while \
            that string WAS the key they were one peer — one row in `discovered`, one entry in \
            `peerIDs`, one `peerReadings` slot holding two bodies.
            """)
        XCTAssertEqual(a.displayName, b.displayName,
                       "…while the LABEL is free to collide. That is not a defect; it is what a "
                       + "label is. Only the key has to be unique.")
        XCTAssertNotEqual(a.transportName, b.transportName, """
            And the difference must survive onto the wire, or the transport hands both phones the \
            same `MCPeerID` and nothing downstream can tell them apart.
            """)
    }

    // MARK: - 2. BEHAVIOUR — the transport spelling round-trips

    func testTheTransportNameCarriesBothHalvesBack() throws {
        let me = PeerIdentity(stableID: UUID().uuidString, displayName: "Mira")
        let back = try XCTUnwrap(PeerIdentity(transportName: me.transportName), """
            A transport name written by this type must parse back into an identity. If it does \
            not, every peer on a current build is treated as a legacy peer and the fix is inert.
            """)
        XCTAssertEqual(back, me, "Both halves must survive the round trip, not just the key.")
    }

    func testALabelContainingTheSeparatorStillSplitsAtTheKey() throws {
        // The split is on the LAST separator on purpose. A label that happens to contain one —
        // pasted text, an odd keyboard — must not be able to steal the key's boundary.
        let odd = PeerIdentity(stableID: UUID().uuidString, displayName: "Mira\u{001F}Live")
        let back = try XCTUnwrap(PeerIdentity(transportName: odd.transportName))
        XCTAssertEqual(back.stableID, odd.stableID, """
            Splitting at the FIRST separator would hand back "Live<sep><uuid>" as the key — a key \
            that changes with the label, which is the collapse this type exists to prevent.
            """)
        XCTAssertEqual(back.displayName, odd.displayName, "…and the label keeps its own character.")
    }

    // MARK: - 3. BEHAVIOUR — the 63-byte transport budget, spent on the label first

    func testALongMultiByteLabelIsTruncatedAndTheKeySurvives() throws {
        let key = UUID().uuidString
        let long = PeerIdentity(stableID: key,
                                displayName: "Ünïcødé Ärtist Näme Viel Zu Lang 🎛🎚🎹 und noch mehr")
        let wire = long.transportName

        XCTAssertLessThanOrEqual(wire.utf8.count, 63, """
            `MCPeerID.displayName` is capped at 63 BYTES. A name in German, Japanese or emoji is \
            not one byte per character, so a character-count budget overflows on exactly the \
            names most likely to be real.
            """)
        let back = try XCTUnwrap(PeerIdentity(transportName: wire))
        XCTAssertEqual(back.stableID, key, """
            The KEY is budgeted first and must survive intact. Truncating from the right would \
            cut the UUID and re-introduce collisions — the defect returning while wearing a fix.
            """)
        XCTAssertTrue(long.displayName.hasPrefix(back.displayName), """
            The label may be shortened, never rewritten: what arrives must be a prefix of what \
            was meant, or the peer is shown a name nobody chose.
            """)
        XCTAssertFalse(back.displayName.isEmpty,
                       "…and something must remain, or the row is a blank line.")
    }

    // MARK: - 4. BEHAVIOUR — a peer that does not speak this vocabulary

    func testABarePeerNameDegradesInsteadOfFailing() {
        XCTAssertNil(PeerIdentity(transportName: "iPhone"), """
            A bare device name carries no key, so parsing must REFUSE rather than invent one. \
            Inventing would give an older peer a key that changes when they rename.
            """)
        let legacy = PeerIdentity.resolve(transportName: "iPhone")
        XCTAssertEqual(legacy.stableID, "iPhone")
        XCTAssertEqual(legacy.displayName, "iPhone", """
            `resolve` must fall back to the pre-#1435 behaviour FOR THAT PEER — old phones still \
            collide with each other, new ones never do. Refusing to connect would be a worse \
            answer than a degraded one, and a session that silently drops an older friend is the \
            kind of "fix" that gets reverted.
            """)
    }

    // MARK: - 5. BEHAVIOUR — the local identity: minted once, kept across a rename

    func testTheLocalIdentityIsMintedOnceAndSurvivesARename() throws {
        let suite = "echoel.tests.peerKey.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set("Mira", forKey: SessionContext.artistStorageKey)
        let first = PeerIdentity.local(defaults: defaults, fallbackName: "iPhone")
        let again = PeerIdentity.local(defaults: defaults, fallbackName: "iPhone")
        XCTAssertEqual(first.stableID, again.stableID, """
            The key is minted ONCE and persisted. A key re-rolled per read would make the peer a \
            stranger on every launch — and on every relaunch mid-session.
            """)
        XCTAssertNotNil(UUID(uuidString: first.stableID), """
            The key must be a UUID string. That is not decoration: the 63-byte transport budget \
            can only promise the label a share because the key's 36 bytes are known.
            """)

        defaults.set("Mira Live", forKey: SessionContext.artistStorageKey)
        let renamed = PeerIdentity.local(defaults: defaults, fallbackName: "iPhone")
        XCTAssertEqual(renamed.stableID, first.stableID, """
            Renaming must move the LABEL and nothing else. A rename that moved the key would \
            re-collide the very peer this type keeps apart, and would strand their bio row.
            """)
        XCTAssertEqual(renamed.displayName, "Mira Live")
    }

    // MARK: - 6. BEHAVIOUR — an unnamed install still advertises the device name

    func testAnUnnamedInstallFallsBackToTheDeviceName() throws {
        let suite = "echoel.tests.peerKey.unnamed.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        // This is the DEFAULT INSTALL, not a hypothetical: `SessionContext.init` migrates
        // `.none`, `""` and the legacy `"Echoel"` onto the brand mark, so the stored value on an
        // untouched device is literally `E~`.
        defaults.set(SessionContext.unnamedArtist, forKey: SessionContext.artistStorageKey)
        let branded = PeerIdentity.local(defaults: defaults, fallbackName: "iPhone")
        XCTAssertEqual(branded.displayName, "iPhone", """
            The brand mark means "you have not named yourself" — it is not a name to advertise. \
            Broadcasting `E~` to every nearby device would be a NEW surface introduced by an \
            identity repair, not a repair.
            """)

        defaults.removeObject(forKey: SessionContext.artistStorageKey)
        let absent = PeerIdentity.local(defaults: defaults, fallbackName: "iPhone")
        XCTAssertEqual(absent.displayName, "iPhone",
                       "An absent key must read the same way as the brand mark: unnamed.")

        defaults.set("   ", forKey: SessionContext.artistStorageKey)
        let blank = PeerIdentity.local(defaults: defaults, fallbackName: "iPhone")
        XCTAssertEqual(blank.displayName, "iPhone", """
            Whitespace is not a name. A label of spaces would advertise an invisible row that \
            cannot be told from any other invisible row.
            """)
    }

    // MARK: - 7. SCAN COUNTERWEIGHT — the transport is fed the identity, and keyed by it

    func testTheSessionAdvertisesTheIdentityAndKeysOnIt() throws {
        let src = try code(at: Self.session)

        guard src.contains("MCPeerID(displayName:") else {
            throw AnchorMissing(reason: """
                MultipeerSession no longer constructs an `MCPeerID(displayName:)`; this scan is \
                anchored on it. Re-anchor rather than letting the absence read as a pass.
                """)
        }
        XCTAssertTrue(src.contains("MCPeerID(displayName: me.transportName)"), """
            The advertised string must be the IDENTITY's spelling. Building it from the device \
            name is the defect verbatim — and on iOS 16+ without the user-assigned-device-name \
            entitlement that name is the model, identical on every stock phone.
            """)
        XCTAssertTrue(src.contains("peerIDs[peer.stableID] = peerID"), """
            The peer registry must be keyed by the STABLE ID. Keying by the advertised string \
            would work by accident today and break the moment a peer renames.
            """)
        XCTAssertFalse(src.contains("peerIDs[peerID.displayName]"), """
            …and it must not be keyed by the transport spelling. That is the old key wearing the \
            new string: two peers, one entry, the second overwriting the first.
            """)
    }

    // MARK: - 8. SCAN COUNTERWEIGHT — the wire carries the LABEL, never the transport spelling

    func testThePayloadsCarryTheLabelAndNotTheWireName() throws {
        let src = try code(at: Self.session)
        let built = occurrences(of: "ColabPayload(kind:", in: src)
        let stamped = occurrences(of: "senderName: identity.displayName", in: src)

        // ⚠️ A RATIO, NOT A LITERAL (#818/#364). Pinning "2" would go red the day a third
        // payload is added — legitimate work — and a guard that reds on legitimate work gets
        // deleted. What must hold is that EVERY payload this file builds stamps the label.
        XCTAssertGreaterThanOrEqual(built, 2, """
            MultipeerSession builds \(built) `ColabPayload`; this scan needs the session sender \
            and the bio sender. Re-anchor rather than comparing a number with itself.
            """)
        XCTAssertEqual(stamped, built, """
            Every payload must stamp the human LABEL — \(stamped) of \(built) do. \
            `myPeerID.displayName` is now the TRANSPORT spelling, so a missed site would put a \
            separator and a UUID onto the peer's import card, and a half-migration would do it \
            on whichever surface was forgotten.
            """)
        XCTAssertFalse(src.contains("senderName: myPeerID.displayName"), """
            The old spelling must be gone from BOTH sites, not one. A half-migration would show \
            the raw wire name on whichever surface was missed.
            """)
    }

    // MARK: - 9. SCAN COUNTERWEIGHT — the entitlement really is absent

    func testTheDeviceNameEntitlementIsStillNotDeclared() throws {
        // This is the premise the whole slice rests on, and it is the one half of the iOS story
        // this repository CAN measure. If the entitlement is ever added, the device name becomes
        // user-chosen — which does not make it a key, but it does change what the fallback label
        // means, and this file should be re-read.
        let root = try treeRoot()
        var declarations = 0
        var scanned = 0
        let enumerator = FileManager.default.enumerator(atPath: root.path)
        while let rel = enumerator?.nextObject() as? String {
            // Walking `.git`, `.build` and DerivedData buys nothing and costs the whole tree.
            if rel.hasPrefix(".git") || rel.hasPrefix(".build") || rel.contains("DerivedData") {
                enumerator?.skipDescendants()
                continue
            }
            guard rel.hasSuffix(".entitlements") || rel.hasSuffix(".plist") else { continue }
            let text = (try? String(contentsOf: root.appendingPathComponent(rel),
                                    encoding: .utf8)) ?? ""
            scanned += 1
            if text.contains("user-assigned-device-name") { declarations += 1 }
        }
        XCTAssertGreaterThan(scanned, 0, """
            No entitlements or plist file was read at all. A zero-denominator scan is a finding, \
            never a pass — it would report "absent" on an empty tree.
            """)
        XCTAssertEqual(declarations, 0, """
            `com.apple.developer.device-information.user-assigned-device-name` is now declared. \
            The FALLBACK label in `PeerIdentity.local` then stops being the model name and \
            becomes something the user chose — still not a key, but the reasoning in this file's \
            header and in `PeerIdentity`'s needs re-reading before it is quoted again.
            """)
    }

    // MARK: - 10. SCAN COUNTERWEIGHT — the door invites by key and shows the label

    func testTheColaboDoorInvitesByKeyAndRendersTheLabel() throws {
        let src = try code(at: Self.colabView)

        guard src.contains("colab.invite(") else {
            throw AnchorMissing(reason: """
                LiveColaboView no longer calls `colab.invite(`; this scan is anchored on it. \
                Re-anchor rather than deleting the assertion.
                """)
        }
        XCTAssertTrue(src.contains("colab.invite(peer.id)"), """
            The invite must go out by IDENTITY. Inviting by label picked an arbitrary one of two \
            identically-named phones — and gave no sign which.
            """)
        XCTAssertFalse(src.contains("colab.invite(peer.name)"),
                       "…and never by the label, which is what it used to do.")
        XCTAssertFalse(src.contains("ForEach(colab.connectedPeerNames, id: \\.self)"), """
            A `ForEach` over the NAMES with `id: \\.self` is a SwiftUI identity bug the moment two \
            peers share a label: duplicate ids, rows that swap and animate wrongly. The list must \
            be driven by `connectedPeers`, keyed on `stableID`.
            """)
    }

    // MARK: - 11. SCAN COUNTERWEIGHT — the bio fingerprint stays off the wire

    func testTheIdentityDoesNotBorrowTheBioSignature() throws {
        let src = try code(at: Self.identity)
        XCTAssertFalse(src.contains("PerformerSignature"), """
            `PerformerSignature` is per-installation and already persisted, so it reads like a \
            free stable ID — and its own header forbids exactly that: never transmitted, \
            deliberately kept OUT of the shared App Group, and shaped by HealthKit-derived \
            frames. Using it here would turn a privacy boundary into an advertising beacon.
            """)
        XCTAssertFalse(src.contains("import UIKit"), """
            This type must stay Foundation-only — that is what lets the blocking bundle DRIVE it \
            (claims 1–6) instead of scanning it, and what keeps the fallback label a parameter \
            rather than a hidden `UIDevice` read.
            """)
        XCTAssertTrue(src.contains("public let stableID: String")
                      && src.contains("public let displayName: String"), """
            Both halves must be STORED. The pre-#1435 `DiscoveredPeer` made `name` a computed \
            `{ id }` — one value wearing two hats — and that is the collapse in miniature.
            """)
    }

    // MARK: - Source access (house template)

    private struct AnchorMissing: Error { let reason: String }

    private func occurrences(of needle: String, in haystack: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        var count = 0
        var search = haystack.startIndex..<haystack.endIndex
        while let found = haystack.range(of: needle, range: search) {
            count += 1
            search = found.upperBound..<haystack.endIndex
        }
        return count
    }

    /// Comment-stripped source (#453 — the ONE definition of "code, not prose"). LOAD-BEARING
    /// here, measured: claim 7's `peerIDs[peer.stableID]` needle and claim 8's negative both
    /// occur inside this slice's own retraction comments in `MultipeerSession.swift`.
    private func code(at relativePath: String) throws -> String {
        let path = try treeRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AnchorMissing(reason: """
                \(relativePath) is missing while the tree is present — it was renamed or moved. \
                Re-anchor this scan; do not let it skip.
                """)
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }

    /// Directory-gated, never per-file (#475): a `fileExists` bracket around each read turns the
    /// very catastrophe this file guards against into a green SKIP.
    private func treeRoot() throws -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Sources").path) {
                return dir
            }
            dir = dir.deletingLastPathComponent()
        }
        throw XCTSkip("No source tree next to the test bundle — nothing to scan.")
    }
}
