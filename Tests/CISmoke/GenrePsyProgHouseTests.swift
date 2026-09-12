import XCTest
@testable import Echoelmusic

/// #983 S5 — `psyProgHouse`, the third genre of the founder's 2026-09-04 ask and the first owner
/// of `BassGrammar.rollingSixteenths` (authored ahead in S1). Its case doc separates it from the
/// un-offered `psytrance` axis by axis; each axis is measured here in the BLOCKING bundle.
///
/// NEEDS-FOUNDER-VERIFY: Genre "Psy Prog House", Loop-Modus — rollt der 16tel-Bass als LINIE
/// (nicht als Rasseln), und hängt der Pluck ins Ping-Pong-Echo, ohne dass die Triade verschwimmt?
/// (Instruction on the line on purpose — see the note in `GenreDeepTechTests`.)
final class GenrePsyProgHouseTests: XCTestCase {

    func testPsyProgHouseIsOfferedInTheElectronicSection() {
        XCTAssertTrue(MusicStyle.offered.contains(.psyProgHouse), "built but not offered — a doorless genre")
        XCTAssertEqual(MusicStyle.psyProgHouse.category, .electronic)
        XCTAssertTrue(MusicStyle.Category.electronic.offeredGenres.contains(.psyProgHouse))
        XCTAssertEqual(MusicStyle.psyProgHouse.displayName, "Psy Prog House")
        XCTAssertFalse(MusicStyle.offered.contains(.psytrance), "the doc's contrast assumes psytrance stays un-offered")
    }

    /// A plain minor triad over the descending vamp — the PAIR is new (deepHouse and rock share the descent).
    func testTheTriadOverTheDescentIsItsOwnShape() {
        let profile = MusicStyle.psyProgHouse.harmonicProfile
        XCTAssertEqual(profile.chordTones, [0, 2, 4])
        XCTAssertEqual(profile.progression, [0, 6, 5], "i → VII → VI")
        XCTAssertEqual(profile.padOctave, 3)
        XCTAssertFalse(profile.arpeggiated, "arpeggiated would bypass the `.stab` articulation")
        XCTAssertFalse(profile.sustained, "sustained would suppress the rolling bass figure")
        XCTAssertEqual(MusicStyle.psyProgHouse.scale, .minor)
        let copies = MusicStyle.allCases.filter {
            $0 != .psyProgHouse && $0.harmonicProfile.progression == [0, 6, 5] && $0.harmonicProfile.chordTones == [0, 2, 4]
        }
        XCTAssertTrue(copies.isEmpty, "the case doc says no other arm stabs a plain triad on this descent; found \(copies)")
        XCTAssertEqual(MusicStyle.deepHouse.harmonicProfile.progression, [0, 6, 5],
                       "the doc names deepHouse as sharing the descent — if that changed, the doc must too")
        XCTAssertFalse(profile.chordTones.contains(6), "no seventh — Romance's count grows by one here")
    }

    /// Everything psytrance does differently, it keeps — the two must never read as one genre at two tempos.
    func testPsyProgHouseIsNotPsytranceAtHouseTempo() {
        let psy = MusicStyle.psytrance.harmonicProfile
        let prog = MusicStyle.psyProgHouse.harmonicProfile
        XCTAssertTrue(psy.arpeggiated); XCTAssertFalse(prog.arpeggiated)
        XCTAssertNotEqual(psy.padOctave, prog.padOctave)
        XCTAssertNotEqual(MusicStyle.psytrance.scale, MusicStyle.psyProgHouse.scale)
        XCTAssertLessThan(MusicStyle.psyProgHouse.tempoRange.upperBound, MusicStyle.psytrance.tempoRange.lowerBound,
                          "the windows must not even touch: psy-prog is a house tempo")
        XCTAssertEqual(MusicStyle.psyProgHouse.tempoRange, 128...136)
        XCTAssertEqual(MusicStyle.psyProgHouse.defaultTempo, 132)
        XCTAssertEqual(MusicStyle.psyProgHouse.swing, 0)
        XCTAssertEqual(MusicStyle.psyProgHouse.beatArchetype, .fourOnFloor)
        XCTAssertEqual(MusicStyle.psyProgHouse.chordArticulation, .stab)
    }

    /// The figure authored ahead in S1 has its first owner, on its own patch.
    func testTheRollingSixteenthsAreOwnedOnTheirOwnBass() throws {
        XCTAssertEqual(MusicStyle.psyProgHouse.bassGrammar, .rollingSixteenths)
        let bass = try XCTUnwrap(MusicStyle.psyProgHouse.bassPatch)
        XCTAssertEqual(bass.name, "Psy Bass")
        XCTAssertEqual(MusicStyle.psyProgHouse.synthPatch.name, "Prog Pluck")
        // ⛔ THIS SWEEP USED TO FORBID A SECOND OWNER, and it over-asserted what the doc says.
        // `BassGrammar`'s table claims psy-prog is the FIRST owner of `rollingSixteenths` — a
        // second owner does not falsify that, and forbidding one turned a SHAREABLE figure into
        // an exclusive one by accident. `deepTech` and `darkMinimal` already share their figures
        // with `techHouse` and `minimalTechno`; the property that actually keeps two genres apart
        // is the one asserted now: every owner has its OWN bass patch. (#1286 G5b, which added
        // `darkPsyTrance` as the second owner and would otherwise have been red on a correct
        // tree — the #364 shape.)
        let rollers = MusicStyle.allCases.filter { $0.bassGrammar == .rollingSixteenths }
        XCTAssertTrue(rollers.contains(.psyProgHouse), "psy-prog no longer owns the figure at all")
        let ids = rollers.compactMap { $0.bassPatch?.id }
        XCTAssertEqual(ids.count, rollers.count, """
            A genre rolls sixteenths without a bass patch of its own: \
            \(rollers.filter { $0.bassPatch == nil }.map(\.rawValue)). The figure may be shared; \
            the voice may not, or the two genres become one bassline at two tempos.
            """)
        XCTAssertEqual(Set(ids).count, ids.count, """
            Two genres roll sixteenths on the SAME bass patch. Share the figure, never the \
            voice — that is the licence `deepTech` and `darkMinimal` take one line above it.
            """)
        XCTAssertLessThan(bass.release, 0.1, "three hits per beat at 132 must each be their own event")
    }

    /// The family echo is shared on purpose; the preset is not psytrance's preset.
    func testTheFXSharesPsytrancesEchoButIsNotItsPreset() {
        let prog = MusicStyle.psyProgHouse.fxPreset
        let psy = MusicStyle.psytrance.fxPreset
        XCTAssertEqual(prog.delayMode, .pingPong)
        XCTAssertEqual(prog.delayMode, psy.delayMode, "the ping-pong echo IS the family")
        XCTAssertLessThan(prog.delayMix, psy.delayMix, "the chord stays legible under the echo")
        XCTAssertLessThan(prog.delayFeedback, psy.delayFeedback)
        XCTAssertTrue(prog.chorusEnabled); XCTAssertFalse(psy.chorusEnabled)
        XCTAssertTrue(prog.reverbEnabled); XCTAssertFalse(psy.reverbEnabled)
        XCTAssertGreaterThan(prog.reverbRoom, MusicStyle.techHouse.fxPreset.reverbRoom)
        XCTAssertLessThan(prog.reverbRoom, MusicStyle.detroitTechno.fxPreset.reverbRoom)
        let otherPingPongFourOnFloor = MusicStyle.offered.filter {
            $0 != .psyProgHouse && $0.beatArchetype == .fourOnFloor && $0.fxPreset.delayMode == .pingPong
        }
        XCTAssertTrue(otherPingPongFourOnFloor.isEmpty,
                      "the FX doc says no other offered four-on-floor genre uses ping-pong; found \(otherPingPongFourOnFloor)")
    }

    /// The pluck's tail is the longest of the stabbing family; its brightness sits under the trance pluck.
    func testThePluckHangsIntoTheEchoAndStaysUnderTrance() {
        let pluck = MusicStyle.psyProgHouse.synthPatch
        XCTAssertGreaterThan(pluck.release, MusicStyle.upliftingTrance.synthPatch.release)
        XCTAssertLessThan(pluck.brightness, MusicStyle.upliftingTrance.synthPatch.brightness)
        XCTAssertGreaterThan(pluck.brightness, MusicStyle.techHouse.synthPatch.brightness)
    }
}
