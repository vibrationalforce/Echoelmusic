import XCTest
@testable import Echoelmusic

/// #1276 (G1 of `scratchpads/PLAN_GENRE_WELT_2026-09-11.md`) — the persisted genre tokens are
/// pinned against a LITERAL, because the round-trip guard next door cannot see the failure that
/// actually costs a user their sound.
///
/// WHAT IS ALREADY GUARDED, so this file does not duplicate it (#416):
/// `TheGenreVocabularyStaysNeutralTests` claim 3 asserts that every case round-trips through its
/// own raw value and that no two cases share one. Both stay true after a RENAME —
/// `dubTechno`'s token becoming "dub_techno" round-trips perfectly and is unique. What breaks is
/// the data already on disk: `@AppStorage(studio.genre)`, `Project.styleRaw` and
/// `TimelineLane.genreOverride` all store the raw string, and `init?(rawValue:)` returning nil
/// is NOT reported by `@AppStorage` — it hands back the default. A renamed token is therefore a
/// silent reset of the user's chosen sound and a `.dubTechno` fallback on every saved project
/// that used it. #570 knew this and pinned ONE token by hand; this pins all of them.
///
/// ⚠️ THE PIN IS A FLOOR, NOT AN EQUALITY, and claim 3 says so in a way that cannot be read
/// past: the next eleven batches of this epic ADD genres, and a guard that reddens on every
/// addition would be deleted by the third batch rather than obeyed. Adding a token is free;
/// removing or renaming one is the thing that has to be deliberate.
///
/// ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`0934dbc`) and this tree: claims
/// 1–4 GREEN on BOTH, by construction — nothing about the tokens changed in #1275, and this
/// file exists precisely so that a FUTURE change cannot be silent. That makes every claim here
/// PROPHYLAKTISCH, with zero verdicts flipping, and it is stated rather than dressed up. The
/// grading that means anything is mutant-driven, and the verdicts below are MEASURED, not
/// predicted — an earlier draft of this block predicted three of them and got one wrong:
///   · M1 rename `dubTechno` → "dub_techno" ....... claims 1, 2, 3 red · 4 green
///   · M2 remove `klezmer` ........................ claims 1, 2, 3 red · 4 green
///   · M3 duplicate entry in the pinned list ...... claims 3, 4 red · 1, 2 green
///   · M4 unsort the pinned list .................. claim 4 red · rest green
///   · M5 ADD a genre ............................. all four GREEN — the epic must stay cheap
/// M3 is why claim 3's second message names BOTH repairs: the draft sent the reader to claim 1,
/// which is green on that mutant. A message that points at a green claim is a wrong repair
/// instruction, and only a mutant run shows it.
final class TheGenreTokensNeverChangeTests: XCTestCase {

    /// Every raw value that exists on 2026-09-12, sorted. NOT derived from `allCases` — a pin
    /// that reads the thing it pins is a mirror, and this one has to be able to disagree.
    private static let pinned: [String] = [
        "acidTechno", "ambientPulse", "classical", "contemplation", "darkMinimal", "deepDrone",
        "deepHouse", "deepTech", "detroitTechno", "disco", "doom", "drift", "dubTechno",
        "earlySynth", "eighties", "esotericMeditation", "futuristic", "heavyMetal", "jazz",
        "klezmer", "minimalTechno", "oriental", "psyProgHouse", "psytrance", "punk", "rock",
        "rocknroll", "rocksteady", "sciFi", "selfObservation", "ska", "synthwave", "techHouse",
        "trap", "upliftingTrance", "vaporwave"
    ]

    /// Claim 1 — no token disappears. A rename shows up here as one missing and one added; a
    /// removal as one missing.
    func testEveryPinnedTokenStillExists() {
        let live = Set(MusicStyle.allCases.map(\.rawValue))
        let lost = Self.pinned.filter { !live.contains($0) }
        XCTAssertTrue(lost.isEmpty, """
            \(lost.count) persisted genre token(s) no longer exist: \(lost.joined(separator: ", "))
            Every one of these is stored on disk — `@AppStorage(studio.genre)`, `Project
            .styleRaw`, `TimelineLane.genreOverride`. `init?(rawValue:)` returning nil is not \
            reported by `@AppStorage`; it returns the default. So this is not a compile detail: \
            it is every affected user opening the app on a genre they did not choose, and every \
            saved project that used it falling back to `.dubTechno`. If a case really must go, \
            keep its token alive on the replacement (the #570 pattern: rename the CASE, pin the \
            raw value) and move the entry here in the same commit (#1276).
            """)
    }

    /// Claim 2 — and they still RESOLVE. Claim 1 compares strings; this walks the path a stored
    /// value actually takes, which is the one the user feels.
    func testEveryPinnedTokenResolvesToACase() {
        for token in Self.pinned {
            XCTAssertNotNil(MusicStyle(rawValue: token), """
                the stored token "\(token)" no longer resolves to a genre. This is the exact \
                call `@AppStorage` makes, and the exact failure it does not report (#1276).
                """)
        }
    }

    /// Claim 3 — COUNTERWEIGHT, and it is the reason this guard survives the epic: ADDING a
    /// genre must stay free. Green on both trees and on every future batch.
    func testAddingAGenreIsAllowed() {
        let live = Set(MusicStyle.allCases.map(\.rawValue))
        XCTAssertTrue(Set(Self.pinned).isSubset(of: live), """
            the pin is a FLOOR: `pinned ⊆ live`. If this fails, claim 1 has already named which \
            token went missing — read that message, not this one.
            """)
        XCTAssertGreaterThanOrEqual(live.count, Self.pinned.count, """
            fewer live tokens than pinned ones. TWO different faults land here and they are \
            repaired in opposite places — read the OTHER red in this file before acting: if \
            claim 1 is also red a genre was removed or renamed (fix `MusicStyle`); if claim 4 \
            is red instead, the pinned list below grew a DUPLICATE and the live roster is \
            untouched (fix the list). Measured against both mutants (#1276).
            """)
    }

    /// Claim 4 — the pin itself is well-formed. A list with a duplicate silently shrinks the set
    /// it protects, and a list that drifted to empty would make claims 1–3 vacuous (#806).
    func testThePinnedListIsWellFormed() {
        XCTAssertEqual(Set(Self.pinned).count, Self.pinned.count,
                       "the pinned list contains a duplicate — it protects fewer tokens than it appears to (#1276)")
        XCTAssertFalse(Self.pinned.isEmpty, "the pinned list is empty — every claim above is vacuous (#806)")
        XCTAssertEqual(Self.pinned, Self.pinned.sorted(),
                       "the pinned list is no longer sorted — sorted order is what makes a future diff readable (#1276)")
    }
}
