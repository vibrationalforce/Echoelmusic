// TheMusicEgressHasItsOwnGateTests.swift
// Echoel — #1383, founder Posten 5. The OUTPUT-STAGE spine (`MusicalFrame`) has been
// published since the day the piano-roll VIEW was deleted, and nothing carried it off the
// device: an external visual engine could subscribe to the body and not to the music.
// `/echoelmusic/music/*` is the fifth item of the founder's own ordering.
//
// THE FINDING THAT SHAPED THE DESIGN, and the reason this file exists at all:
// `BioEgressPolicy`'s fail-closed property belongs to ONE call site — the filter inside
// `OSCSender.send(frame:)`. `send(address:floats:)` is a raw pipe with no classification,
// and `sendModulation` reaches it directly (gated upstream in `ModulationEngine.apply`
// instead). So a NEW egress path does not inherit the guarantee by living in this class.
// It has to route through `fieldClass` itself, and claim 2 is what holds it there.
//
// ⚠️ THE MUSIC ADDRESSES ARE A SET, NOT A PREFIX (claim 6). `derivedPrefixes` grants the
// class to every future member of a namespace; `BioEgressPolicy.fieldClass`'s own doc says
// the point of returning `nil` is that a new address ships SILENT rather than unclassified.
// A `/echoelmusic/music/` prefix would hand that away for precisely the namespace that is
// about to grow. This claim pins the decision, not the spelling.
//
// ⚠️ THE GATE IS ON TEMPO ALONE, and that asymmetry is the load-bearing part. Four of the
// five carry no physiology: the key and the note count are the user's composition, the beat
// phase and the master level are the transport. Tempo under `.flowFree` follows the pulse,
// and `MusicalFrame` HAS NO provenance field — so it takes the strict reading and honours
// the same source gate that withholds the bio frame, the rule `ModulationEngine` already
// applies to its network tap. Claim 4 pins the SHARED CONSTANT rather than a re-spelled
// literal: a gate guarding a string nobody sends is #367.
//
// KIND (§1): END-TO-END BEHAVIOUR for claims 2, 5 and 7 (`MusicalFrame`, `BioEgressPolicy`
// and `OSCSender.musicMessages` are value types driven directly). SOURCE-TEXT SCAN for 1,
// 3, 4 and 6. What an OSC monitor SEES is a DEVICE PROBE and is not claimed here.
//
// ⚠️ HONEST GRADING (§3) — this file names symbols THIS COMMIT CREATES
// (`musicMessages`, `musicTempoAddress`, `musicAddresses`, `sendMusicIfFresh`), so it does
// NOT COMPILE against the parent and NO assertion has a verdict there. That is ONE absence
// (#486), not seven findings. Graded by TRANSCRIPTION (§0) against both trees plus mutants.
//
// ⚠️ Claims 3 and 7 are COUNTERWEIGHTS and are the reason this is not just a feature pin:
// 3 reddens the day someone "completes" the batch by adding the producerless fields, and
// 7 reddens the day someone deletes the tempo send entirely instead of gating it (#364 —
// this file must not forbid the feature it is guarding).

import XCTest
@testable import Echoelmusic

final class TheMusicEgressHasItsOwnGateTests: XCTestCase {

    private func senderSource() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/Echoelmusic/Sync/OSCSender.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func policySource() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/Echoelmusic/Core/BioEgressPolicy.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    // 1. The musical batch rides the EXISTING poll, beside its two siblings — not a second
    //    timer. A new timer on this path is how two senders come to disagree about rate,
    //    and the bio ceiling (`governedByBioCeiling`) would govern only one of them.
    func testTheMusicalBatchRidesTheSameTickAsTheBioBatch() throws {
        let src = SourceText.codeOnly(try senderSource())
        guard let start = src.range(of: "loop.start(interval:") else {
            return XCTFail("the poll that drives every OSC egress path is gone — re-anchor this guard")
        }
        let window = String(src[start.lowerBound...].prefix(400))
        for call in ["self.sendIfFresh(from: bus)",
                     "self.sendMusicIfFresh(from: bus)",
                     "self.drainAndSendEvents(from: bus)"] {
            XCTAssertTrue(window.contains(call), """
            \(call) is not in the poll closure. All three egress paths share ONE tick on \
            purpose; a musical batch on its own timer escapes the bio ceiling that governs \
            this one.
            """)
        }
        XCTAssertEqual(src.components(separatedBy: "loop.start(").count - 1, 1, """
        A SECOND loop.start( appeared in OSCSender. There is one poll by design.
        """)
    }

    // 2. THE FAIL-CLOSED ROUND TRIP. Every address the builder can emit must be answerable
    //    by the classifier — because the sender's filter drops what it cannot classify, so
    //    an unclassified address is a silent send, not a loud one.
    func testEveryAddressTheBuilderEmitsIsClassified() {
        let frame = MusicalFrame(notes: [MusicalNote(frequencyHz: 440, amplitude: 0.8)],
                                 rootPitchClass: 9, scaleName: "dorian",
                                 tempoBPM: 112, beatPhase: 0.25, masterLevel: 0.6)
        let msgs = OSCSender.musicMessages(for: frame)
        XCTAssertFalse(msgs.isEmpty, "the musical batch built nothing from a sounding frame")
        for m in msgs {
            XCTAssertEqual(BioEgressPolicy.fieldClass(ofOSCAddress: m.address), .derived, """
            \(m.address) is emitted by OSCSender.musicMessages but BioEgressPolicy cannot \
            classify it as .derived. The sender's filter drops what it cannot classify, so \
            this address would be built and never sent — a silent feature, not a loud \
            failure. Add it to BioEgressPolicy.musicAddresses in THIS commit.
            """)
            XCTAssertEqual(m.floats.count, 1, """
            \(m.address) carries \(m.floats.count) floats. The whole Echoel address set is \
            one float per address; a variable-arity message needs its own decision about \
            stable receiver slots (see musicMessages' own doc), not a quiet exception.
            """)
        }
        XCTAssertEqual(Set(msgs.map(\.address)), BioEgressPolicy.musicAddresses, """
        The set the builder emits and the set the policy knows have drifted apart. They are \
        two spellings of one contract; either both move or neither does.
        """)
    }

    // 3. COUNTERWEIGHT. The two PRODUCERLESS fields and the diagnostic-only one must stay
    //    off the wire. Measured 2026-09-19: the single construction site passes neither
    //    sectionIndex nor trackLevels, so both hold their defaults on every frame ever
    //    published — streaming a constant -1 is indistinguishable from a real reading (#496).
    func testTheProducerlessAndDiagnosticFieldsAreNotOnTheWire() throws {
        let src = SourceText.codeOnly(try senderSource())
        guard let start = src.range(of: "static func musicMessages(") else {
            return XCTFail("musicMessages is gone — re-anchor this guard")
        }
        let body = String(src[start.lowerBound...].prefix(1400))
        for field in ["sectionIndex", "trackLevels", "inaudibleNoteCount", "scaleName"] {
            XCTAssertFalse(body.contains("frame.\(field)"), """
            musicMessages reads frame.\(field). sectionIndex and trackLevels have NO \
            PRODUCER (always -1 and []); inaudibleNoteCount is documented DIAGNOSTIC ONLY, \
            "no renderer may react to it", and an OSC receiver is a renderer; scaleName is \
            a String the float encoder cannot write. If one of these gained a producer, \
            that is the commit that moves this line — with the reason rewritten, not deleted.
            """)
        }
    }

    // 4. The gate and the message use ONE spelling. A gate that compares against a
    //    re-typed literal is a gate that keeps passing after the address is renamed (#367).
    func testTheTempoGateKeysOnTheSharedConstantAndNotARetypedLiteral() throws {
        let src = SourceText.codeOnly(try senderSource())
        XCTAssertTrue(src.contains("m.address == Self.musicTempoAddress, !bodyMayEgress"), """
        The tempo gate no longer compares against Self.musicTempoAddress. If the address \
        is spelled twice, renaming one leaves a gate guarding a string nobody sends.
        """)
        XCTAssertEqual(src.components(separatedBy: "\"/echoelmusic/music/tempo\"").count - 1, 1, """
        "/echoelmusic/music/tempo" is written more than once in OSCSender. The constant \
        musicTempoAddress exists so it is written exactly once.
        """)
        XCTAssertTrue(src.contains("bus.latestBio.map { BioEgressPolicy.allowsEgress($0.source) } ?? true"), """
        The body gate no longer reads the LIVE bio source through BioEgressPolicy. The \
        ?? true half is deliberate: no bio frame means nothing to withhold, and composing \
        without biofeedback must not lose its tempo out.
        """)
    }

    // 5. The two batches keep SEPARATE dedupe cursors. Bio and musical frames are published
    //    by different producers at different cadences on the same clock; one shared cursor
    //    lets whichever arrives second suppress the other for a whole tick.
    func testTheTwoBatchesDoNotShareADedupeCursor() throws {
        let src = SourceText.codeOnly(try senderSource())
        XCTAssertTrue(src.contains("private var lastMusicalTimestamp"), """
        The musical batch lost its own dedupe cursor.
        """)
        XCTAssertTrue(src.contains("frame.timestamp != lastMusicalTimestamp"), """
        sendMusicIfFresh no longer dedupes on its own cursor. Sharing lastFrameTimestamp \
        makes the two batches suppress each other.
        """)
        guard let start = src.range(of: "func sendMusicIfFresh(") else {
            return XCTFail("sendMusicIfFresh is gone — re-anchor this guard")
        }
        let body = String(src[start.lowerBound...].prefix(700))
        XCTAssertFalse(body.contains("lastFrameTimestamp"), """
        sendMusicIfFresh reads lastFrameTimestamp — the BIO cursor. Two producers on one \
        clock sharing one cursor means whichever frame arrives second is dropped.
        """)
    }

    // 6. THE DESIGN CLAIM. A SET, not a prefix — so an unregistered future music address
    //    fails closed instead of inheriting the class.
    func testTheMusicAddressesAreASetSoAnUnregisteredOneFailsClosed() throws {
        XCTAssertNil(BioEgressPolicy.fieldClass(ofOSCAddress: "/echoelmusic/music/not/registered/yet"), """
        An unregistered /echoelmusic/music/ address classified anyway — so the namespace \
        has been given a PREFIX. That hands away the property this file's header calls the \
        whole design: a new address must ship silent rather than unclassified.
        """)
        let policy = SourceText.codeOnly(try policySource())
        XCTAssertFalse(policy.contains("\"/echoelmusic/music/\""), """
        "/echoelmusic/music/" appears as a namespace literal in BioEgressPolicy. The music \
        addresses are enumerated one by one on purpose.
        """)
    }

    // 7. COUNTERWEIGHT (#364). This file must not forbid the feature it guards: the tempo
    //    IS sent, and it IS withheld only on a blocked source — not deleted, not always-off.
    func testTheTempoIsSentAndIsOnlyWithheldForABlockedSource() {
        let frame = MusicalFrame(tempoBPM: 128, beatPhase: 0.5)
        let addresses = OSCSender.musicMessages(for: frame).map(\.address)
        XCTAssertTrue(addresses.contains(OSCSender.musicTempoAddress), """
        The tempo is no longer built at all. The gate was meant to WITHHOLD it on a blocked \
        source, not to remove it — an instrument that cannot tell Ableton its tempo has \
        lost the point of this address space.
        """)
        XCTAssertTrue(BioEgressPolicy.allowsEgress(.cameraPPG), "the camera source stopped permitting egress")
        XCTAssertTrue(BioEgressPolicy.allowsEgress(.ble), "the strap source stopped permitting egress")
        XCTAssertFalse(BioEgressPolicy.allowsEgress(.healthKit), """
        HealthKit began permitting egress. The tempo gate reduces to a no-op if this flips, \
        and so does every bio address — 5.1.3 is the reason both exist.
        """)
    }

    // 8. THE WEBSITE IS IN THE LOOP. #755's lesson was that all three copy guards read SWIFT
    //    and the WEBSITE was in none of them, so `docs/overview.html` went on selling two
    //    producerless mappings after the code stopped claiming them. `integrations.html` is
    //    the canonical full address list and the Resolume page teaches a VJ to bind these —
    //    so both directions matter: an address that ships and is undocumented is a feature
    //    nobody finds, and an address documented but not shipped is the 2.3-rejection class.
    func testTheCanonicalAddressListNamesExactlyWhatShips() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        for page in ["docs/integrations.html", "docs/resolume-osc.html"] {
            let html = try String(contentsOf: root.appendingPathComponent(page), encoding: .utf8)
            for address in BioEgressPolicy.musicAddresses {
                XCTAssertTrue(html.contains(address), """
                \(page) does not name \(address), which OSCSender ships. An address on the \
                wire that the address list omits is a feature nobody finds.
                """)
            }
            // The other direction: nothing under the musical namespace may be advertised
            // that the sender cannot produce.
            var scan = Substring(html)
            while let r = scan.range(of: "/echoelmusic/music/") {
                let rest = scan[r.lowerBound...]
                let addr = String(rest.prefix(while: { !"<\" ,)&".contains($0) }))
                XCTAssertTrue(BioEgressPolicy.musicAddresses.contains(addr), """
                \(page) advertises \(addr), which is not in BioEgressPolicy.musicAddresses \
                and therefore cannot be sent. Documenting an address the sender does not \
                produce is the claim class that gets a build rejected under 2.3.
                """)
                scan = scan[r.upperBound...]
            }
        }
    }
}
