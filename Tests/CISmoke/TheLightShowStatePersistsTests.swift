// TheLightShowStatePersistsTests.swift
// Echoel — the light TARGET survived a relaunch; the light SHOW did not. #1442.
//
// WHAT WAS WRONG, and it was an asymmetry INSIDE one panel rather than a missing feature.
// `PatchbayView`'s Light section writes six values into both light senders. Three of them —
// `host`, `port`, `universe` — persist through `net.artnet.*` / `net.sacn.*` and come back on
// the next launch. Three others — `resolution`, `fixtureCount`, `fixtureSpacing` — lived only
// in the sender object. An installation artist aimed the app at a rig, told it the rig has
// twelve lamps eight slots apart, relaunched, and was pointed at the same rig addressing ONE
// lamp at 16-bit. Nothing said so; the numbers simply read 1 and 0 again.
//
// ⚠️ THE OLD BEHAVIOUR WAS DELIBERATE AND ITS OWN DOC NAMED THE PRICE OF CHANGING IT.
// `PatchbayView` said: *"a stored count of 32 would fan a stranger's rig on first open. A
// fixed installation would rather have it persist like `universe` does; that is a separate
// slice with its own key and decode default."* This IS that slice, and the safety argument is
// answered by measurement rather than waved away:
//   · the stream only starts when a PERSISTED patchbay route is enabled
//     (`EchoelmusicApp`: `if g.hasEnabledRoute(toSink: "artnet.out")`), and
//   · it is aimed at the PERSISTED `host`/`port`/`universe`.
// So a first open that emits anything at all is already aimed at the stored rig. The count is
// not the marginal risk; it was the only part of that aim that did not survive.
//
// ⭐ WHAT IS DELIBERATELY *NOT* PERSISTED, and claim 5 is the counterweight that keeps it so:
// `grandMaster` and `blackout`. A stored master of 0.05 reads as "the lights are broken" and a
// stored blackout loads the app into a dark room — both senders' own docs say "live state, not
// persisted ... a fresh launch always starts at full (predictable for the operator)", and that
// decision stands untouched. This slice moves exactly the three SHOW-SHAPE fields.
//
// ⭐ NO `+1` OFFSET, unlike `universe`, and the reason is worth stating because copying the
// neighbour would have been the obvious move. `universe` needs it because 0 is a LEGAL Art-Net
// universe and `UserDefaults.integer(forKey:)` also returns 0 for "never written". Here:
//   · `fixtureCount` is legal only from 1 up, so a stored 0 unambiguously means unset → 1.
//   · `fixtureSpacing`'s default IS 0, so unset and a stored 0 decode to the same value.
// An offset would have been ceremony that adds a way to be wrong. Claim 2 drives both.
//
// ⭐ ONE DECODER, NOT TWO (#416). The two senders keep separate KEYS (different namespaces,
// as they already do for host/port/universe) but share ONE set of pure decode functions on
// `ArtNetSender`, the same way `SACNSender` already shares `DMXResolution` and `reencode`.
// Two spellings of one clamp is the defect whether or not they agree today. Claim 6 pins it.
//
// GRADE (Tests/CISmoke/CLAUDE.md §1): claims 1–5 are END-TO-END BEHAVIOUR — they construct the
// shipped senders and drive the real `init` decode through the real `UserDefaults` keys, the
// shape `TheArtNetDefaultIsUnicastTests` already uses here. Claim 6 is a SOURCE-TEXT SCAN and
// says so. DEVICE PROBE — that a physical rig lights up the same way after a relaunch — is
// impossible here and stays open.
//
// ⚠️ EVERY BEHAVIOUR CLAIM SAVES AND RESTORES THE SIX KEYS IT TOUCHES. These are the real
// `UserDefaults.standard` keys the app ships with; a guard that left them written would change
// what the next launch of the app on that simulator does, and would make a sibling guard's
// "fresh default" claim depend on test ORDER.
//
// HONEST GRADING (#433/#464/#486), hand-transcribed against `HEAD` and this tree (§0 — no
// Swift toolchain in a web session):
//   · **2 REGRESSIONS** on the parent, for the reason their names give. Claim 2: a written
//     mode/count/spacing does not come back, because no key exists. Claim 4: a stored 9999 has
//     no effect at all there, so the property reads 1 where the claim expects the clamped 32.
//   · **1 REGRESSION reported once although it names twelve things** (#486): claim 6. The
//     three decoders and the six keys are absent together — one absence, not nine findings.
//   · **3 COUNTERWEIGHTS**, green on both trees, and they are the point of the file. Claim 1:
//     a FIRST open is unchanged — this is what makes persistence safe to add at all. Claim 3:
//     the two arms do not share a stored show. Claim 5: the master fader and the blackout did
//     NOT join the persisted set. ⚠️ Claim 3 is green on the parent VACUOUSLY (nothing
//     persists there, so nothing can cross-talk); it earns its keep only on this tree, and
//     that is worth knowing before reading its parent verdict as evidence of anything.
//   · ⭐ THE FILE COMPILES AGAINST THE PARENT and every claim has a real verdict there. It
//     never CALLS the new decoders — claim 6 scans for their NAMES as text — so it references
//     no symbol this commit creates. Say it plainly rather than reaching for the #488
//     "not gradable against the parent" wording, which reads as an excuse.
//   · STRIPPER: **PROPHYLAKTISCH (0 of 18 verdicts flip raw vs stripped)**, measured rather
//     than claimed (§2 keeps retracting the opposite). `SourceText.codeOnly` stays because the
//     next comment that names `decodedFixtureCount(` in prose would make it load-bearing
//     without anyone noticing — but today it changes nothing, and saying otherwise would be
//     the third slice in a row to claim load-bearing without measuring.

import Foundation
import XCTest
@testable import Echoelmusic

#if canImport(Network)

final class TheLightShowStatePersistsTests: XCTestCase {

    private static let keys = [
        "net.artnet.resolution", "net.artnet.fixtureCount", "net.artnet.fixtureSpacing",
        "net.sacn.resolution", "net.sacn.fixtureCount", "net.sacn.fixtureSpacing",
    ]

    /// Run `body` with the six show keys cleared, restoring whatever was there afterwards.
    /// ⚠️ NOT a convenience: these are the shipped keys, and a guard that leaves one written
    /// decides what the next test — and the next launch of the app on this simulator — sees.
    /// ⚠️ `@MainActor` is not decoration: `body` constructs the senders, which are
    /// `@MainActor` classes. A nonisolated helper would run the closure in a nonisolated
    /// context and Swift 6 would refuse the construction inside it.
    @MainActor
    private func withCleanShowKeys(_ body: () -> Void) {
        let d = UserDefaults.standard
        let saved = Self.keys.map { ($0, d.object(forKey: $0)) }
        Self.keys.forEach { d.removeObject(forKey: $0) }
        defer {
            for (k, v) in saved {
                if let v { d.set(v, forKey: k) } else { d.removeObject(forKey: k) }
            }
        }
        body()
    }

    // MARK: - 1 · COUNTERWEIGHT: a first open is unchanged

    @MainActor
    func testAFreshInstallStillAddressesOneFixtureAtSixteenBit() {
        withCleanShowKeys {
            let art = ArtNetSender(), sacn = SACNSender()
            XCTAssertEqual(art.resolution, .sixteenBit, """
                A fresh install no longer starts at 16-bit. The decode DEFAULT is what makes \
                persistence safe to add (#1442): with nothing stored the senders must behave \
                exactly as they did before any key existed.
                """)
            XCTAssertEqual(art.fixtureCount, 1, "a fresh install fans the dimmer across more than one lamp (#1442)")
            XCTAssertEqual(art.fixtureSpacing, 0, "a fresh install no longer addresses back-to-back (#1442)")
            XCTAssertEqual(sacn.resolution, .sixteenBit, "sACN's fresh default drifted from Art-Net's (#1442)")
            XCTAssertEqual(sacn.fixtureCount, 1, "sACN's fresh default drifted from Art-Net's (#1442)")
            XCTAssertEqual(sacn.fixtureSpacing, 0, "sACN's fresh default drifted from Art-Net's (#1442)")
        }
    }

    // MARK: - 2 · the show comes back, on BOTH arms

    @MainActor
    func testTheRigSizeAndResolutionSurviveAReconstruction() {
        withCleanShowKeys {
            let art = ArtNetSender()
            art.resolution = .eightBit
            art.fixtureCount = 12
            art.fixtureSpacing = 8
            let reopened = ArtNetSender()
            XCTAssertEqual(reopened.resolution, .eightBit, """
                The DMX resolution did not survive a reconstruction. This is the whole slice \
                (#1442): the Light section's target persists and its SHAPE must too, or a fixed \
                installation silently re-addresses its rig on every launch.
                """)
            XCTAssertEqual(reopened.fixtureCount, 12, "fixtureCount did not survive a reconstruction (#1442)")
            XCTAssertEqual(reopened.fixtureSpacing, 8, "fixtureSpacing did not survive a reconstruction (#1442)")

            let s = SACNSender()
            s.resolution = .eightBit
            s.fixtureCount = 4
            s.fixtureSpacing = 16
            let sReopened = SACNSender()
            XCTAssertEqual(sReopened.resolution, .eightBit, "sACN's show state did not survive (#1442)")
            XCTAssertEqual(sReopened.fixtureCount, 4, "sACN's show state did not survive (#1442)")
            XCTAssertEqual(sReopened.fixtureSpacing, 16, "sACN's show state did not survive (#1442)")
        }
    }

    // MARK: - 3 · the two arms keep SEPARATE keys

    @MainActor
    func testTheTwoArmsDoNotShareOneStoredShow() {
        withCleanShowKeys {
            let art = ArtNetSender()
            art.fixtureCount = 7
            let sacn = SACNSender()
            XCTAssertEqual(sacn.fixtureCount, 1, """
                Writing Art-Net's fixture count changed what sACN reads back. The two senders \
                address DIFFERENT rigs in general — they already keep separate host/port/\
                universe keys — so one shared key would make a two-protocol install unusable \
                (#1442). The Picker writing both arms is a UI decision, not a storage one.
                """)
        }
    }

    // MARK: - 4 · a corrupt or future value cannot reach the wire

    @MainActor
    func testAnImpossibleStoredValueIsClampedAndAnUnknownModeFallsBack() {
        withCleanShowKeys {
            let d = UserDefaults.standard
            d.set(9_999, forKey: "net.artnet.fixtureCount")
            d.set(-5, forKey: "net.artnet.fixtureSpacing")
            d.set("32-bit", forKey: "net.artnet.resolution")
            let art = ArtNetSender()
            XCTAssertEqual(art.fixtureCount, DMXFixtureFan.maxFixtures, """
                A stored fixture count above the fan's own ceiling was not clamped on decode \
                (#1442). `DMXFixtureFan.fanned` clamps too, so this is defence in depth — but \
                the PROPERTY is what the patchbay shows the operator, and showing 9999 while \
                sending 32 is a lie about the rig.
                """)
            XCTAssertEqual(art.fixtureSpacing, 0, "a negative stored spacing was not clamped (#1442)")
            XCTAssertEqual(art.resolution, .sixteenBit, """
                An unrecognised stored resolution did not fall back to the shipped default \
                (#1442). A build that adds a third mode and is then rolled back leaves exactly \
                this string behind.
                """)
        }
    }

    // MARK: - 5 · COUNTERWEIGHT: the master fader and the blackout stay live-only

    @MainActor
    func testTheMasterAndTheBlackoutStillDoNotPersist() {
        withCleanShowKeys {
            let art = ArtNetSender()
            art.grandMaster = 0.05
            art.blackout = true
            let reopened = ArtNetSender()
            XCTAssertEqual(reopened.grandMaster, 1, accuracy: 0.0001, """
                The Grand Master became persistent. It must NOT (#1442): a stored 0.05 loads \
                the next session at 5 % and reads to the operator as broken hardware. Both \
                senders' docs state this as the rule; #1442 moved the three SHAPE fields and \
                deliberately left these two.
                """)
            XCTAssertFalse(reopened.blackout, """
                Blackout became persistent. It must NOT (#1442) — the app would open into a \
                dark room with no indication why.
                """)
            let sacn = SACNSender()
            sacn.grandMaster = 0.05
            sacn.blackout = true
            let sReopened = SACNSender()
            XCTAssertEqual(sReopened.grandMaster, 1, accuracy: 0.0001, "sACN's master became persistent (#1442)")
            XCTAssertFalse(sReopened.blackout, "sACN's blackout became persistent (#1442)")
        }
    }

    // MARK: - 6 · SOURCE-TEXT SCAN — one decoder, two key namespaces

    func testTheDecodeRuleIsWrittenOnceAndBothArmsAskIt() throws {
        let art = SourceText.codeOnly(try text("Sources/Echoelmusic/Sync/ArtNetSender.swift"))
        let sacn = SourceText.codeOnly(try text("Sources/Echoelmusic/Sync/SACNSender.swift"))
        for name in ["decodedResolution", "decodedFixtureCount", "decodedFixtureSpacing"] {
            XCTAssertTrue(art.contains("static func \(name)("), """
                `ArtNetSender.\(name)` is gone. The two senders share ONE decode rule on \
                purpose (#416/#1442) — a clamp written twice is the defect whether or not the \
                two copies agree today.
                """)
            XCTAssertFalse(sacn.contains("static func \(name)("), """
                `SACNSender` declares its own `\(name)`. That is the second spelling this \
                claim exists to prevent (#416/#1442); it must CALL `ArtNetSender.\(name)`, the \
                way it already shares `DMXResolution` and `reencode`.
                """)
            XCTAssertTrue(sacn.contains("ArtNetSender.\(name)("), """
                `SACNSender` no longer calls `ArtNetSender.\(name)`. Either it grew its own \
                copy or it stopped decoding at all — both are #1442 regressions.
                """)
        }
        for key in ["net.artnet.resolution", "net.artnet.fixtureCount", "net.artnet.fixtureSpacing"] {
            XCTAssertTrue(art.contains("\"\(key)\""), "`\(key)` is gone from ArtNetSender (#1442)")
            XCTAssertFalse(sacn.contains("\"\(key)\""), """
                `SACNSender` names an Art-Net key. The two arms keep separate namespaces \
                (#1442, claim 3 drives the behaviour).
                """)
        }
        for key in ["net.sacn.resolution", "net.sacn.fixtureCount", "net.sacn.fixtureSpacing"] {
            XCTAssertTrue(sacn.contains("\"\(key)\""), "`\(key)` is gone from SACNSender (#1442)")
        }
    }

    // MARK: - helper

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

#endif
