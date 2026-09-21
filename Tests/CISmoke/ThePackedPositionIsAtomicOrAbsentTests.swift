// ThePackedPositionIsAtomicOrAbsentTests.swift
// Echoel — #1421. The immersive object now leaves as ONE position message, or as none.
//
// THE DEFECT, cited from the standard rather than asserted. ADM-OSC v1.0 §"Minimum Viable
// Implementation" (`docs/adm-osc.bs`, the vendored spec #1210 already pinned the leaf NAMES
// against) requires of a SENDER: "Implement at least one of `/adm/obj/{n}/xyz` (Cartesian,
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
