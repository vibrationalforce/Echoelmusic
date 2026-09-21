// ThePackedPositionIsAtomicOrAbsentTests.swift
// Echoel — #1421. The immersive object now leaves as ONE position message, or as none.
//
// THE DEFECT, cited from the standard rather than asserted. ADM-OSC v1.0 §"Minimum Viable
// Implementation" requires of a SENDER: "Implement at least one of `/adm/obj/{n}/xyz` (Cartesian,
// packed) or `/adm/obj/{n}/aed` (polar, packed) for position". Echoel sent NEITHER — three
// separate `/azim`, `/elev`, `/dist` datagrams — so it was not a conforming sender.
//
// ⭐ AND THE SHARPER HALF, which inverts the risk this change appears to carry. The same
// section requires of a RECEIVER only: "Handle at least one of `/adm/obj/{n}/xyz` or
// `/adm/obj/{n}/aed`". A fully conforming renderer is therefore **not required to handle
// `/azim`, `/elev` or `/dist` at all** — the unpacked-only feed could be dropped on the floor
// by a receiver that is entirely within spec. Packing makes the object MORE likely to be
// understood, not less. A wire-format change to a third-party integration normally deserves
// the opposite presumption, and that presumption is exactly what would have kept this
// unfixed; the spec text is what overturns it.
//
// The second reason is the spec's own: "Use packed messages (`xyz` or `aed`) for position
// updates to ensure atomic delivery." Three datagrams can straddle two render ticks, so a
// moving object gets rendered at a position it never occupied — one axis from this frame,
// two from the last.
//
// ⛔ THE ALL-THREE CONDITION IS #1140, NOT AN OPTIMISATION, and claim 2 is the one that
// matters most in this file. A packed message must carry three numbers. A partially measured
// frame has no third number, and the only ways to send one anyway are to invent it or repeat
// a stale one — precisely what the per-axis gates exist to prevent (an unmeasured breath
// rides out as azimuth −180, hard left; an unmeasured coherence as distance 1, the far wall;
// both occurred on shipping hardware, see `ADMOSCAbsenceTests`). So: all three measured ⇒ one
// atomic `/aed`; anything less ⇒ the individual leaves, each still riding its own channel.
//
// ⚠️ WHAT THIS DOES NOT PROVE. That a real renderer MOVES on `/aed` needs a renderer. The
// address, its argument count and its argument ORDER are cited from the spec table
// (`/adm/obj/n/aed  f f f  packed polar: azimuth, elevation, distance`); reception is not
// proved here, and the `NEEDS-FOUNDER-VERIFY` for that lives in `ADMOSCSender.swift`'s header.
//
// ⛔ AND THE SCOPE OF THIS FILE IS TWO EMITTERS, NOT THREE — written here because the claim
// "Echoel is a conforming ADM-OSC sender" is exactly the kind that gets over-read. #1421
// enumerated the BIO arm and the MUSIC arm. Applying this repo's own #766/#768 law to that
// enumeration ("all checked" only ever means "all the ones I thought of"; the tell is that
// every surface checked so far is the same KIND) found a THIRD: `SpatialSceneOSC.swift`
// emits `/azim`, `/elev`, `/dist` per object for the scene stream, and
// `ADMOSCSender.send(scene:dialect:)` has its OWN send loop that does not pass through this
// fold. Its Cartesian dialect is unpacked too, where the spec has `/xyz`.
//
// That path is DOUBLY doorless — `streamsScene` defaults false with its only writer in the
// parked `ImmersiveStageView`, and `sceneDialect` has no writer at all — so nothing a user
// can reach is affected.
//
// ⭐ THE POLAR HALF OF THAT FINDING IS CLOSED BY #1430 (claims 9–13), AND THE DESIGN QUOTED
// ABOVE WAS WRONG, which is the part worth keeping. It said: *"the fold has to move to a
// Foundation-only home (this file's subject lives inside `#if canImport(Network)`), which
// takes the `/aed` literal out of `ADMOSCSender.swift` and reddens
// `TheADMOSCLeavesAreTheSpecsTests` claim 1 — a four-file slice, so it belongs with the commit
// that re-doors the stage."* Measured instead of recalled: that is true of the FORMATTER and
// irrelevant to the SEND loop. `ADMOSCSender.send(scene:dialect:)` is a method on the same
// type inside the same guard, so it reaches `Self.packedPositionMessages` directly. Nothing
// moved, claim 1 of the neighbouring guard kept its literal, and the slice was TWO files.
// **A note that makes work BIGGER than it is parks a real repair for weeks** — the exact
// mirror of the law CLAUDE.md records for the slogan that made the iPad switch-back sound
// like one line, and the reason it is corrected here rather than only in the task list (#456).
//
// ⭐ THE CARTESIAN HALF IS CLOSED BY #1432, and my #1430 reason for leaving it open was WRONG
// in the cautious direction: it said *"the spec's packed Cartesian address is not verified in
// this repository"*. It was — `TheADMOSCLeavesAreTheSpecsTests`'s header has named `/xyz` among
// the object leaves since #1210 and quotes the sender minimum *"implement at least one of
// /xyz or /aed"*. I read the guard I was editing and not its neighbour, which is #456 a third
// time in one day. Re-derived from the standard anyway, and it agrees: the quick reference
// lists `/adm/obj/{n}/xyz` as `f f f`, "Packed: x, y, z (recommended for atomicity)", with
// object numbers starting at 1. **Over-caution is not free either** — it parked a two-file
// repair behind a fact the repository already held.
//
// ⚠️ ALSO NOT DONE, deliberately: an OSC BUNDLE. The spec notes packed values "can also be
// grouped with other messages in an OSC bundle for atomic/synchronous delivery with a shared
// timestamp". That needs `#bundle` framing in `OSCSender.encode` and is beyond the MVI bar.
//
// Grading (§0, no Swift toolchain in a web session): claims 1–7 are end-to-end behaviour over
// the real mappers and were transcribed into Python and driven against a model of the fold;
// claim 8 is a source scan driven directly. RED on `2596d2849` — `packedPositionMessages`
// does not exist there, so the file does not build. NOT compile-verified: a transcription does
// not run Swift's type checker.

#if canImport(Network)
import Foundation
import XCTest
@testable import Echoelmusic

final class ThePackedPositionIsAtomicOrAbsentTests: XCTestCase {

    private static let sender = "Sources/Echoelmusic/Sync/ADMOSCSender.swift"

    // MARK: Fixtures

    /// Three polar leaves plus one non-positional address, for object 1.
    private func leaves(azim: Float? = 10, elev: Float? = 20, dist: Float? = 0.3,
                        gain: Float? = 0.7) -> [(String, Float)] {
        var msgs: [(String, Float)] = []
        if let azim { msgs.append(("/adm/obj/1/azim", azim)) }
        if let elev { msgs.append(("/adm/obj/1/elev", elev)) }
        if let dist { msgs.append(("/adm/obj/1/dist", dist)) }
        if let gain { msgs.append(("/adm/obj/1/gain", gain)) }
        return msgs
    }

    private func bioFrame(bpm: Float, hrv: Float, breathRate: Float, phase: Float,
                          coherence: Float, source: BioSource) -> BioSampleFrame {
        BioSampleFrame(timestamp: 0, heartRateBPM: bpm, hrvNormalized: hrv,
                       breathRate: breathRate, breathPhase: phase, coherence: coherence,
                       motionEnergy: 0, source: source)
    }

    private func addresses(_ out: [(String, [Float])]) -> [String] { out.map { $0.0 } }

    // MARK: 1 — all three present ⇒ ONE atomic `/aed`, in spec order

    func testThreeMeasuredAxesLeaveAsOnePackedMessage() throws {
        let out = ADMOSCSender.packedPositionMessages(leaves(), object: 1)

        XCTAssertEqual(addresses(out), ["/adm/obj/1/aed", "/adm/obj/1/gain"], """
            The fold did not happen, or did not consume the axes it folded. ADM-OSC v1.0's
            sender minimum is "implement at least one of /xyz or /aed"; sending the three
            unpacked leaves alongside would also defeat the atomicity the packing is for.
            """)
        let packed = try XCTUnwrap(out.first?.1)
        XCTAssertEqual(packed, [10, 20, 0.3], """
            `/aed` is `f f f` = azimuth, elevation, distance IN THAT ORDER (spec object table).
            A permuted payload is not a wrong number, it is a wrong PLACE — the renderer will
            happily put the object at (20°, 10°, …) and nothing will log an error.
            """)
    }

    // MARK: 2 — any axis missing ⇒ NO `/aed`, and no invented third number

    func testAMissingAxisLeavesTheOthersUnpackedAndInventsNothing() {
        let cases: [(String, [(String, Float)])] = [
            ("azimuth unmeasured",   leaves(azim: nil)),
            ("elevation unmeasured", leaves(elev: nil)),
            ("distance unmeasured",  leaves(dist: nil))
        ]
        for (label, input) in cases {
            let out = ADMOSCSender.packedPositionMessages(input, object: 1)
            XCTAssertFalse(addresses(out).contains("/adm/obj/1/aed"), """
                \(label): a packed `/aed` was produced from an incomplete position. A packed
                message must carry three numbers, and the only ways to supply the missing one
                are to invent it or to repeat a stale one — which is exactly the #1140 defect
                the per-axis gates exist to prevent (unmeasured breath ⇒ azimuth −180, hard
                left; unmeasured coherence ⇒ distance 1, the far wall — both shipped once).
                """)
            XCTAssertEqual(addresses(out), input.map { $0.0 }, """
                \(label): the unpacked fallback must pass every surviving leaf through
                unchanged and in order. Silence on an address means "not measured" and the
                renderer holds its last value; changing which addresses appear changes what the
                object asserts.
                """)
        }
    }

    // MARK: 3 — non-positional addresses survive, with their value

    func testTheNonPositionalAddressesPassThroughUntouched() throws {
        let out = ADMOSCSender.packedPositionMessages(leaves(), object: 1)
        let gain = try XCTUnwrap(out.first(where: { $0.0 == "/adm/obj/1/gain" })?.1)
        XCTAssertEqual(gain, [0.7], """
            `/gain` is not a position axis and must ride out exactly as the mapper produced it.
            It is also the address whose own gate (`ModSource.motion.hasProducer`, #215) is
            false today and will one day be true — the fold must not acquire an opinion on it.
            """)
    }

    // MARK: 4 — the BIO arm, end to end, on both sides of its own gates

    func testTheBioArmPacksOnlyWhenEveryChannelIsMeasured() {
        // Camera take, everything measured: breath waveform (only .cameraPPG/.fallback
        // provide one), a pulse, non-zero HRV and non-zero coherence.
        let full = bioFrame(bpm: 62, hrv: 0.4, breathRate: 12, phase: 0.25,
                            coherence: 0.6, source: .cameraPPG)
        let packed = ADMOSCSender.packedPositionMessages(
            ADMOSCSender.admMessages(for: full, object: 1), object: 1)
        XCTAssertEqual(addresses(packed), ["/adm/obj/1/aed"], """
            A fully measured camera frame must produce exactly one packed position and nothing
            else (no `/gain`: nothing measures motion, #215). If this reports the three
            unpacked leaves, the fold is not reached from the mapper's output.
            """)

        // Chest strap: `.ble` derives no respiration, so `hasMeasuredBreathWaveform` is false
        // and there is no azimuth to pack. This is the case that shipped pinned at −180.
        let strap = bioFrame(bpm: 62, hrv: 0.4, breathRate: 0, phase: 0,
                             coherence: 0.6, source: .ble)
        let unpacked = ADMOSCSender.packedPositionMessages(
            ADMOSCSender.admMessages(for: strap, object: 1), object: 1)
        XCTAssertEqual(addresses(unpacked), ["/adm/obj/1/elev", "/adm/obj/1/dist"], """
            A strap frame has no breath waveform, so it has no azimuth — and must therefore
            send NO `/aed` and keep the two axes it did measure on their own addresses. A
            packed message here would have to invent an azimuth, and the value it would invent
            is −180: the object slammed hard left for the whole session.
            """)
    }

    // MARK: 5 — the MUSIC arm, which is measured by construction

    func testTheMusicArmAlwaysPacks() {
        let frame = MusicalFrame(notes: [MusicalNote(frequencyHz: 440, amplitude: 1)],
                                 masterLevel: 0.8)
        let out = ADMOSCSender.packedPositionMessages(
            MusicMediaMap.admMessages(forMusic: frame, object: 1), object: 1)
        XCTAssertEqual(addresses(out), ["/adm/obj/1/aed", "/adm/obj/1/gain"], """
            The music arm sends all four addresses unconditionally — it only runs while
            `isSounding`, so notes and a master level are measured by construction. It must
            therefore ALWAYS pack, and `/gain` must still follow. Two datagrams per tick
            instead of four, and the position is atomic.
            """)
    }

    // MARK: 6 — the fold and the mappers must agree on the object index

    func testTheFoldFindsItsOwnLeavesAtEveryObjectIndex() {
        for index in [1, 7, 0, -3] {
            let msgs = ADMOSCSender.admMessages(
                for: bioFrame(bpm: 62, hrv: 0.4, breathRate: 12, phase: 0.25,
                              coherence: 0.6, source: .cameraPPG),
                object: index)
            let out = ADMOSCSender.packedPositionMessages(msgs, object: index)
            let expected = "/adm/obj/\(Swift.max(1, index))/aed"
            XCTAssertEqual(addresses(out), [expected], """
                At object index \(index) the fold produced \(addresses(out)) instead of
                [\(expected)]. The mapper clamps the index to 1-based (ADM object numbers are
                "positive integers, starting at 1") and the fold must clamp IDENTICALLY — if
                the two ever disagree, the fold silently matches nothing and the packing stops
                happening with no error anywhere.
                """)
        }
    }

    // MARK: 7 — TOTALITY: nothing invented, nothing lost

    func testTheFoldInventsNoAddressAndLosesNoValue() {
        let inputs: [[(String, Float)]] = [leaves(), leaves(azim: nil), leaves(gain: nil), []]
        let folded: Set<String> = ["/adm/obj/1/azim", "/adm/obj/1/elev", "/adm/obj/1/dist"]
        for input in inputs {
            let out = ADMOSCSender.packedPositionMessages(input, object: 1)
            let incoming = Set(input.map { $0.0 })
            let didPack = out.contains(where: { $0.0 == "/adm/obj/1/aed" })
            for (address, floats) in out {
                if address == "/adm/obj/1/aed" {
                    XCTAssertEqual(floats.count, 3, "`/aed` must carry exactly three floats")
                    XCTAssertTrue(folded.isSubset(of: incoming), """
                        `/aed` appeared although the mappers did not produce all three axes.
                        This function REGROUPS the mappers' output (#416); it must never be a
                        second home for a mapping or for a measurement gate.
                        """)
                } else {
                    XCTAssertTrue(incoming.contains(address), """
                        `\(address)` is not an address the mappers produced. The fold may only
                        regroup; an invented address is an invented assertion about a body.
                        """)
                    XCTAssertEqual(floats.count, 1,
                                   "a non-packed ADM leaf carries exactly one float")
                }
            }
            let survivors = Set(addresses(out)).subtracting(["/adm/obj/1/aed"])
            let consumed: Set<String> = didPack ? folded : []
            XCTAssertEqual(survivors, incoming.subtracting(consumed), """
                An address the mappers produced went missing. The only addresses that may
                disappear are the three that were folded INTO an `/aed`, and only when one was
                actually produced.
                """)
        }
    }


    // MARK: 9 — the scene arm packs, per object, in positional order

    func testEveryObjectInASceneLeavesAsOnePackedMessage() {
        let scene = SpatialScene(objects: [
            SpatialObject(id: "a", position: SpatialPosition(azimuth: -30, elevation: 5,
                                                             distance: 0.4), gain: 0.5),
            SpatialObject(id: "b", position: SpatialPosition(azimuth: 40, elevation: -10,
                                                             distance: 0.8), gain: 0.9),
        ])
        let flat = SpatialSceneOSCFormatter.messages(for: scene, dialect: .admOSC)
            .map { ($0.address, $0.value) }
        let out = ADMOSCSender.packedSceneMessages(flat, dialect: .admOSC)

        XCTAssertEqual(addresses(out), ["/adm/obj/1/aed", "/adm/obj/1/gain",
                                        "/adm/obj/2/aed", "/adm/obj/2/gain"], """
            The scene arm did not fold per object, or it reordered the wire. It was the THIRD
            position emitter (#1424) and the last one still walking the unpacked list; the
            order must stay POSITIONAL — each object's packed block takes the place of its
            FIRST leaf — because an "objects first, everything else appended" shape is a no-op
            today and silently reorders the wire the day this formatter emits anything else.
            """)
    }

    // MARK: 10 — COUNTERWEIGHT: IEM is a different standard and is never folded

    func testTheIEMDialectIsNeverFolded() {
        let scene = SpatialScene(objects: [
            SpatialObject(id: "a", position: SpatialPosition(azimuth: -30, elevation: 5,
                                                             distance: 0.4), gain: 0.5),
        ])
        let flat = SpatialSceneOSCFormatter.messages(for: scene, dialect: .iem)
            .map { ($0.address, $0.value) }
        let out = ADMOSCSender.packedSceneMessages(flat, dialect: .iem)

        XCTAssertEqual(addresses(out), flat.map { $0.0 }, """
            The IEM MultiEncoder vocabulary was folded. It is a DIFFERENT standard, not an
            unpacked version of ADM-OSC: 0-based sources, degrees, dB, no distance parameter,
            and `/aed` means nothing to its receiver. Folding here emits an address the plugin
            cannot read — a conformance repair that breaks conformance one dialect over.
            """)
        XCTAssertTrue(out.allSatisfy { $0.1.count == 1 },
                      "every IEM leaf carries exactly one float, as before the fold existed")
    }

    // MARK: 11 — the Cartesian scene packs too, into `/xyz`, and invents nothing

    func testTheCartesianSceneLeavesAsOnePackedMessage() {
        let scene = SpatialScene(objects: [
            SpatialObject(id: "a", position: SpatialPosition(azimuth: -30, elevation: 5,
                                                             distance: 0.4), gain: 0.5),
        ])
        let flat = SpatialSceneOSCFormatter.messages(for: scene, dialect: .admOSCCartesian)
            .map { ($0.address, $0.value) }
        let out = ADMOSCSender.packedSceneMessages(flat, dialect: .admOSCCartesian)

        XCTAssertEqual(addresses(out), ["/adm/obj/1/xyz", "/adm/obj/1/gain"], """
            The Cartesian scene did not fold. ADM-OSC v1.0 lists `/adm/obj/{n}/xyz` as `f f f`,
            "Packed: x, y, z (recommended for atomicity)", exactly as it lists `/aed` — the two
            are two SPELLINGS of one decision, and a fold that packs only one of them makes a
            Cartesian-only renderer the single receiver that still gets a torn position.
            """)
        XCTAssertEqual(out.first(where: { $0.0 == "/adm/obj/1/xyz" })?.1.count, 3, """
            `/xyz` must carry exactly three floats, in x, y, z order. The argument ORDER is not
            checkable from the address alone, so it is pinned here at the value level by
            claim 11b below rather than assumed from the name.
            """)
        let packedXYZ = out.first(where: { $0.0 == "/adm/obj/1/xyz" })?.1 ?? []
        let leaves = flat.filter { ["/adm/obj/1/x", "/adm/obj/1/y", "/adm/obj/1/z"]
            .contains($0.0) }
        XCTAssertEqual(packedXYZ, [leaves.first(where: { $0.0.hasSuffix("/x") })?.1,
                                   leaves.first(where: { $0.0.hasSuffix("/y") })?.1,
                                   leaves.first(where: { $0.0.hasSuffix("/z") })?.1]
                                  .compactMap { $0 }, """
            11b — the packed floats are not the formatter's x, y, z in that order. This is the
            assertion that catches a transposed axis, which no address check can see and which
            moves an object to the wrong place in the room while every guard stays green.
            """)
        XCTAssertFalse(addresses(out).contains(where: { $0.hasSuffix("/xy") }), """
            The spec also defines a TWO-axis packed form, `/adm/obj/{n}/xy`. Nothing here emits
            a 2D position, so nothing may emit that address — a partial position sent as if it
            were complete is the #1140 defect wearing the spec's own vocabulary.
            """)
    }

    // MARK: 12 — the object index is PARSED, so 11 is not 1 and a missing axis stays local

    func testTheSceneFoldGroupsByParsedIndexNotByStride() {
        let polar = { (n: Int) -> [(String, Float)] in
            [("/adm/obj/\(n)/azim", Float(n)), ("/adm/obj/\(n)/elev", Float(n) + 0.1),
             ("/adm/obj/\(n)/dist", Float(n) + 0.2), ("/adm/obj/\(n)/gain", 0.5)]
        }
        let out = ADMOSCSender.packedSceneMessages(polar(1) + polar(11), dialect: .admOSC)
        XCTAssertEqual(addresses(out), ["/adm/obj/1/aed", "/adm/obj/1/gain",
                                        "/adm/obj/11/aed", "/adm/obj/11/gain"], """
            Object 11 was folded into object 1, or the grouping used the emission STRIDE. The
            index is parsed from the address on purpose: `/adm/obj/11/azim` does not carry the
            prefix `/adm/obj/1/` because the character after the index is a slash, while a
            four-at-a-time stride is silently wrong the day a channel is added and nothing
            goes red.
            """)

        let missingElev = polar(1).filter { !$0.0.hasSuffix("/elev") } + polar(2)
        XCTAssertEqual(addresses(ADMOSCSender.packedSceneMessages(missingElev,
                                                                  dialect: .admOSC)),
                       ["/adm/obj/1/azim", "/adm/obj/1/dist", "/adm/obj/1/gain",
                        "/adm/obj/2/aed", "/adm/obj/2/gain"], """
            One object missing an axis changed another object's fate. The all-three condition
            is #1140 and it is PER OBJECT: object 1 cannot pack, object 2 must still pack, and
            a fold that decided globally would either invent a position for 1 or withhold a
            correct one from 2.
            """)

        XCTAssertNil(ADMOSCSender.admObjectIndex("/adm/obj/0/azim"), """
            Object 0 was recognised. `packedPositionMessages` raises its argument with
            `max(1, n)`, so handing it a 0 makes it hunt for leaves under `/adm/obj/1` and
            quietly mis-group a whole object.
            """)
        XCTAssertNil(ADMOSCSender.admObjectIndex("/adm/obj/1"),
                     "an address with no leaf after the index is not an object leaf")
        XCTAssertNil(ADMOSCSender.admObjectIndex("/echoelmusic/bio/heart/bpm"),
                     "a foreign namespace is not an ADM object")
    }

    // MARK: 13 — the scene SEND loop goes through the fold

    func testTheSceneSendLoopGoesThroughTheFold() throws {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { dir.deleteLastPathComponent() }
        let url = dir.appendingPathComponent(Self.sender)
        guard let code = try? String(contentsOf: url, encoding: .utf8) else {
            return XCTFail("ANCHOR MISSING: cannot read \(Self.sender) — re-anchor rather than "
                           + "letting this stay green (#454).")
        }
        XCTAssertTrue(code.contains("Self.packedSceneMessages(flat, dialect: dialect)"), """
            `send(scene:dialect:)` no longer sends through the fold. This is the #1210 lesson
            for the third arm: the pure function passing claims 9–12 proves nothing about the
            wire if the send loop walks the unpacked list, and this arm is doorless, so no
            device session would ever reveal it.
            """)
        XCTAssertFalse(code.contains("send(address: message.address, floats: [message.value])"), """
            The old unpacked scene loop is back. It sent every leaf as its own datagram, which
            is exactly the shape #1424 recorded as the third unfolded emitter.
            """)
    }

    // MARK: 8 — the sender actually sends through the fold

    func testTheSendLoopGoesThroughTheFold() throws {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { dir.deleteLastPathComponent() }
        let url = dir.appendingPathComponent(Self.sender)
        guard let code = try? String(contentsOf: url, encoding: .utf8) else {
            return XCTFail("ANCHOR MISSING: cannot read \(Self.sender) — re-anchor rather than "
                           + "letting this stay green (#454).")
        }
        XCTAssertTrue(code.contains("Self.packedPositionMessages(messages, object: objectIndex)"), """
            `sendIfFresh` no longer sends through the fold. The pure function passing its own
            tests proves nothing about the wire if the send loop walks the unpacked list — that
            is the #1210 lesson one layer over: a golden test proves a formatter is STABLE,
            never that its output reaches the socket.
            """)
    }
}
#endif
