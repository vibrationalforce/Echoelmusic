// TheGenrePresetIsACentreNotAPointTests.swift
// Echoel — #1402. Founder 2026-09-20, verbatim: *"Es wäre aufjedenfall gut grundsätzlich einen
// Status zu erreichen, wo kein Moment wie der andere klingt. Auch die Genre presets sollen einen
// vibe haben aber nicht gleich klingen. Immer random und variations reich. Wie stark die
// Variation ist kann man dann einstellen."*
//
// ⭐ WHAT THIS SLICE IS. The curated mood preset stops being a POINT the whole loop sits on and
// becomes a CENTRE the bars scatter around. Five PERFORMANCE axes drift per bar, three IDENTITY
// axes hold, and `MusicStyle` — the genre's chords, scale, register and rhythm — is not touched
// at all. That split is the entire reason this can ship without re-auditioning 41 curated
// genres, and it is why claim 2 pins the three that must NOT move by name.
//
// ⛔ THE FAILURE THIS FILE IS REALLY GUARDING IS A TIDY-UP, NOT A BUG. `variationSpread` reads
// like a list somebody could "simplify" into a `switch` over axis NAMES — the first draft of
// this slice was exactly that, and it is silently wrong: a new axis added without its case
// scatters nothing and nothing goes red (#367). Claim 5 pins the key-path form, so the compiler
// keeps carrying the mapping instead of a string.
//
// ⚠️ IT CANNOT PROVE THE SOUND. Whether 0.25 is the right opening default, and whether a genre
// still reads as itself at 1.00, is the founder's ear on the device. What is settled here is
// that 0 changes nothing, that the identity axes never move, that the values stay in domain,
// that bar 1 is the preset, and that the dial is not a lying one at a one-bar loop.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheGenrePresetIsACentreNotAPointTests: XCTestCase {

    private static let composer = "Sources/Echoelmusic/Sequencer/BioComposer.swift"
    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"

    private func code(_ relPath: String) throws -> String {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let path = root.appendingPathComponent(relPath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw XCTSkip("source tree not present at \(path.path)")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }

    /// A mood with every axis off the boundary, so a move in either direction is visible and
    /// nothing is clamped by accident.
    private var centre: MoodProfile {
        MoodProfile(liveliness: 0.5, darkness: 0.5, tension: 0.4, romance: 0.4,
                    weird: 0.4, virtuosity: 0.4, syncopation: 0.4, humanize: 0.4)
    }

    // MARK: - 1. The Golden law

    /// ⭐ AT ZERO IT IS A NO-OP, BIT-IDENTICALLY. Every stored project and every fresh install
    /// composed before #1402 must sound exactly as it did; the whole slice is opt-in by amount.
    /// The non-finite and negative branches are here for the same reason the DSP boundary
    /// sanitizers are: `amount` arrives from `@AppStorage` via `Float(Double)`, and a corrupted
    /// defaults plist is the one input nobody writes by hand.
    func testAmountZeroReturnsTheProfileUnchanged() {
        let base = centre
        for amount in [Float(0), -0.5, -Float.infinity, .nan] {
            XCTAssertEqual(base.varied(amount: amount, seed: 0x1234_5678), base, """
            `varied(amount: \(amount))` changed the profile.

            Zero (and anything that is not a positive, finite amount) MUST return `self`. That \
            is what makes #1402 opt-in: a project saved before this slice, and a fresh install \
            with the dial pulled down, have to compose the identical notes they did before.
            """)
        }
    }

    // MARK: - 2. The split that protects genre identity

    /// ⛔ THE THREE THAT MUST NEVER MOVE, pinned by name and by behaviour. `darkness` drops the
    /// voicing an octave above 0.60 and `romance` adds the 7th above 0.50 — both are CLIFFS
    /// (`MoodKnobsSayWhatTheyDoTests` measures them), so scattering them would flip a genre's
    /// register or its chord quality mid-loop rather than vary its performance. `tension` picks
    /// the dissonance the scale is read with. Those three ARE the vibe the founder asked to keep.
    func testTheIdentityAxesNeverScatter() {
        let base = centre
        for seed in UInt64(0)..<64 {
            let out = base.varied(amount: 1.0, seed: seed &* 0x9E37_79B9_7F4A_7C15)
            XCTAssertEqual(out.darkness, base.darkness, """
            `darkness` moved at seed \(seed). It is an IDENTITY axis: above 0.60 it drops the \
            whole voicing an octave, so scattering it re-registers the genre instead of varying \
            the performance.
            """)
            XCTAssertEqual(out.tension, base.tension,
                           "`tension` moved at seed \(seed) — it decides the dissonance the "
                           + "scale is read with, which is what a genre IS.")
            XCTAssertEqual(out.romance, base.romance, """
            `romance` moved at seed \(seed). Above 0.50 it adds the 7th to genres whose chord \
            does not already carry one — a chord-quality switch, not a shade.
            """)
        }
    }

    /// The other half: it really does scatter, and `liveliness` is the axis that proves it
    /// without a clamp in the way (centre 0.5, cap 0.25, so no draw can reach a boundary).
    /// Asserted as a SPREAD over seeds rather than "seed X moved", so no single draw's sign can
    /// make this flap.
    func testThePerformanceAxesScatterAtFullAmount() {
        let base = centre
        let values = Set((UInt64(0)..<64).map {
            base.varied(amount: 1.0, seed: $0 &* 0x9E37_79B9_7F4A_7C15).liveliness
        })
        XCTAssertGreaterThan(values.count, 8, """
            64 seeds produced only \(values.count) distinct `liveliness` values at amount 1.0.

            This is the founder's request itself — "kein Moment wie der andere". If the spread \
            collapsed, either `variationSpread` lost its performance axes or the draw stopped \
            depending on the seed.
            """)
    }

    // MARK: - 3. The domain holds

    /// ⚠️ CLAMPING IS NOT COSMETIC. `weird > 1` is where the composer's chromatic branch stops
    /// being musical, and every consumer of these eight documents them as 0…1. Both boundary
    /// profiles are tested because a one-sided clamp is the easy half to get right.
    func testTheScatterStaysInsideTheDocumentedDomain() {
        for base in [MoodProfile(liveliness: 1, darkness: 1, tension: 1, romance: 1,
                                 weird: 1, virtuosity: 1, syncopation: 1, humanize: 1),
                     MoodProfile(liveliness: 0, darkness: 0, tension: 0, romance: 0,
                                 weird: 0, virtuosity: 0, syncopation: 0, humanize: 0)] {
            for seed in UInt64(0)..<64 {
                let out = base.varied(amount: 1.0, seed: seed &* 0xD1B5_4A32_D192_ED03)
                for (axis, _) in MoodProfile.variationSpread {
                    let v = out[keyPath: axis]
                    XCTAssertTrue(v >= 0 && v <= 1, """
                    a scattered axis left 0…1 (value \(v), seed \(seed)).

                    Clamp at the boundary, not at the consumer — the eight dials are documented \
                    0…1 everywhere they are read, and the composer's chromatic branch stops \
                    being musical above 1.
                    """)
                }
            }
        }
    }

    // MARK: - 4. Deterministic, not random

    /// ⭐ "Random" in the founder's sentence means *unpredictable to the ear*, never
    /// *irreproducible*. A take has to compose the same notes on every device and every
    /// relaunch or nothing downstream — export, the maze, a saved project — means anything.
    func testTheSameSeedScattersTheSameWay() {
        let base = centre
        for seed in UInt64(0)..<16 {
            XCTAssertEqual(base.varied(amount: 0.7, seed: seed),
                           base.varied(amount: 0.7, seed: seed), """
            `varied` returned two different profiles for seed \(seed).

            It must be a pure function of (profile, amount, seed) — `SeededRNG` only, no \
            `Date`, no `SystemRandomNumberGenerator`, no `Hasher` (process-random and banned).
            """)
        }
    }

    // MARK: - 5. The table is a mapping, not a spelling

    /// ⛔ KEY PATHS, NOT NAMES. See this file's header: a `switch` over axis names is the
    /// plausible "tidy-up" that makes a newly added axis a silent no-op (#367). The key-path
    /// form makes the table itself the mapping, so the compiler carries it (#416).
    func testTheSpreadIsAKeyPathTableAndCoversFiveAxes() throws {
        let source = try code(Self.composer)
        XCTAssertTrue(source.contains("WritableKeyPath<MoodProfile, Float>"), """
        `variationSpread` no longer stores `WritableKeyPath<MoodProfile, Float>`.

        If it became a table of axis NAMES with a `switch` beside it, adding a sixth axis \
        without its case scatters nothing and nothing goes red. The key path IS the mapping.
        """)
        XCTAssertEqual(MoodProfile.variationSpread.count, 5, """
        `variationSpread` holds \(MoodProfile.variationSpread.count) axes, expected 5.

        This is not a count for its own sake: `MoodProfile` has EIGHT axes and exactly three of \
        them (darkness · tension · romance) are identity, pinned by claim 2. Five plus three is \
        the whole struct — a sixth entry here means one of the three moved, and claim 2 will \
        say which.
        """)
        for (_, cap) in MoodProfile.variationSpread {
            XCTAssertTrue(cap > 0 && cap <= 0.5, """
            a `variationSpread` cap is \(cap). A cap of 0 is a row that does nothing (#164/#227 \
            one layer down — the dial moves and that axis never follows); above 0.5 a single \
            draw can cross a centred axis from one end of its range to the other, which is a \
            different reading of the mood rather than a variation of it.
            """)
        }
    }

    // MARK: - 6. Bar 1 is the preset

    /// ⛔ `rawBars[0]` IS `composition.notes`, composed at the preset itself, and it is what the
    /// loop opens with — the genre states itself, then varies. The `varied(` call therefore
    /// belongs INSIDE `for b in 1..<barCount` and nowhere else. Scattering bar 0 too would mean
    /// no bar anywhere plays the curated preset, which is a different product decision than the
    /// one that was asked for.
    func testOnlyTheBarsAfterTheFirstAreScattered() throws {
        let lines = try code(Self.studio)
            .split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let calls = lines.indices.filter { lines[$0].contains(".varied(") }
        XCTAssertEqual(calls.count, 1, """
        `EchoelStudioView` makes \(calls.count) `varied(` calls, expected exactly 1.

        A second one is almost certainly bar 0 or a per-role fan-out, and both break the \
        promise the caption makes on screen ("Bar 1 plays the genre preset").
        """)
        let loop = try XCTUnwrap(lines.firstIndex { $0.contains("for b in 1..<barCount") }, """
        the per-bar loop `for b in 1..<barCount` is gone from `generate()`. If the loop-conform \
        arrangement changed shape, move this guard with it — do not leave a check pointing at a \
        line that no longer exists.
        """)
        let call = try XCTUnwrap(calls.first)
        XCTAssertGreaterThan(call, loop, """
        the `varied(` call is no longer inside `for b in 1..<barCount`.

        Bar 0 is `composition.notes`, already composed at the preset. If the scatter moved \
        above the loop it now applies to the bar the loop OPENS with, and the genre never \
        states itself plainly.
        """)
    }

    /// ⚠️ THE SCATTER SEED IS NOT THE NOTE SEED, and that is a real invariant rather than taste.
    /// `compose` consumes `barInput.seed` for the notes, so deriving the scatter from the same
    /// number ties "which mood this bar reads" to "which notes it draws" — two things that must
    /// move independently, and a future change to either would silently re-voice the other.
    func testTheScatterSeedIsFoldedSeparatelyFromTheNoteSeed() throws {
        let source = try code(Self.studio)
        let tail = try XCTUnwrap(source.components(separatedBy: ".varied(").last)
        let args = String(tail.prefix(240))
        XCTAssertFalse(args.contains("barInput.seed"), """
        the `varied(` call derives its seed from `barInput.seed` — the same stream `compose` \
        reads for the notes. Fold a separate number (the call site shows `evolvingSeed ^ …`) so \
        mood-scatter and note-choice stay orthogonal.
        """)
        XCTAssertTrue(args.contains("evolvingSeed"), """
        the `varied(` call no longer derives its seed from `evolvingSeed`.

        That is what makes the scatter EVOLVE with the take instead of being frozen per genre: \
        `evolution` increments on every real take, so the same bar index reads the mood \
        differently the next time round.
        """)
    }

    // MARK: - 7. The dial is not a lying one

    /// ⭐ #164/#227 AT A ONE-BAR LOOP. Bar 1 is always the preset, so with one bar there is
    /// nothing left to scatter and the dial would sweep its whole range in silence — exactly the
    /// report that produced #1401. Since #1401 a disabled `EchoelValueField` also LOOKS
    /// disabled, so this reads as "off here" rather than "broken".
    func testTheRowIsDisabledWhereItCannotScatter() throws {
        let source = try code(Self.studio)
        let row = try XCTUnwrap(source.components(separatedBy: "private var moodVariationRow").last, """
        `moodVariationRow` is gone from `EchoelStudioView`. If the control moved, move this \
        guard with it.
        """)
        let body = String(row.prefix(900))
        XCTAssertTrue(body.contains("loopBars.rawValue > 1"), """
        `moodVariationRow` no longer decides its enabled state from the loop length.
        """)
        // ⚠️ THE NEEDLE IS `.disabled(!`, NOT `.disabled(!scattersSomething)` — pinning the local
        // variable's NAME would red the bundle on a legal rename, which is work this guard has no
        // business forbidding (#364). Together with the `loopBars.rawValue > 1` check above, the
        // negated form still catches both real regressions: the modifier disappearing, and it
        // being pinned to a constant.
        XCTAssertTrue(body.contains(".disabled(!"), """
        `moodVariationRow` no longer disables itself on a negated condition.

        At a one-bar loop bar 1 IS the whole loop, and bar 1 is always the preset. A live dial \
        there moves a number and changes no sound — the lying-dial law (#164/#227), and the \
        shape of the founder's own 2026-09-20 report.
        """)
    }

    /// ⛔ THE CAPTION COUNTS THE TABLE, it does not spell it. Widening or narrowing
    /// `variationSpread` rewrites the sentence for free; a hand-written "five" is the mistake
    /// `RoleRhythm.accentIsSubtle` exists to record — a UI list that drifted from the engine and
    /// was WRONG about which member was missing.
    func testTheCaptionIsProjectedFromTheTable() throws {
        let source = try code(Self.studio)
        let caption = try XCTUnwrap(source.components(separatedBy: "func moodVariationCaption").last)
        let body = String(caption.prefix(900))
        XCTAssertTrue(body.contains("MoodProfile.variationSpread.count"), """
        `moodVariationCaption` no longer reads its number from `MoodProfile.variationSpread`.

        A typed number in user-facing copy about a table the engine owns is a date, not a fact.
        """)
        for typed in ["five performance", "5 performance dials"] {
            XCTAssertFalse(body.contains(typed), """
            `moodVariationCaption` types the axis count ("\(typed)") instead of projecting it.
            """)
        }
    }

    /// ⛔ TWO ROWS SPELLED "Variation" IN ONE PANEL IS HOW #1401 HAPPENS AGAIN. `padShapeSection`
    /// already ships `label: "Variation"` (that is `padEvolve`, one role's rhythm, inert on four
    /// of six characters). This row scales how far EVERY bar drifts from the preset. Different
    /// things, different labels — and the pad row keeps its word because it is the one the
    /// founder has already looked at, under its own "Pad rhythm" heading.
    func testTheTwoVariationRowsInTheMoodPanelAreNotSpelledAlike() throws {
        let source = try code(Self.studio)
        func labels(after decl: String) throws -> Set<String> {
            let tail = try XCTUnwrap(source.components(separatedBy: decl).last,
                                     "`\(decl)` is gone from `EchoelStudioView`.")
            let body = String(tail.prefix(1600))
            var found = Set<String>()
            for piece in body.components(separatedBy: "EchoelValueField(label: \"").dropFirst() {
                if let end = piece.firstIndex(of: "\"") { found.insert(String(piece[..<end])) }
            }
            return found
        }
        let mine = try labels(after: "private var moodVariationRow")
        let pad = try labels(after: "private var padShapeSection")
        XCTAssertTrue(mine.contains("Bar variation"), """
        the global variation row is no longer labelled "Bar variation" (found \(mine.sorted())).
        """)
        XCTAssertTrue(pad.contains("Variation"), """
        `padShapeSection` no longer ships a "Variation" row (found \(pad.sorted())). If \
        `padEvolve` was renamed, this guard's reason is gone — retire it rather than loosening it.
        """)
        XCTAssertTrue(mine.isDisjoint(with: pad), """
        `moodVariationRow` and `padShapeSection` now share a label: \
        \(mine.intersection(pad).sorted()).

        Both render in `moodPanel`. Two rows reading the same word, one of which is inert on \
        four of six pad characters, is precisely the confusion the founder reported on \
        2026-09-20 ("Variation geht nicht", #1401).
        """)
    }

    // MARK: - 8. The persisted value can be reset and is reported

    /// ⛔ THE FIFTH-TIME LAW, from `SoundReset`'s own ⛔ block: a persisted setting that decides
    /// what a take SOUNDS like and is NOT in that list can only be cured by a reinstall. The
    /// label↔breadcrumb join is asserted generically by
    /// `ResetSoundClearsWhatTheLaunchLineReportsTests`; what is NOT covered there, and is here,
    /// is that this key reached the list at all.
    func testTheVariationDepthIsClearedByTheSoundReset() {
        let cleared = Set(SoundReset.entries.flatMap(\.keys))
        XCTAssertTrue(cleared.contains(StudioDefaultKeys.moodVariation.key), """
        `\(StudioDefaultKeys.moodVariation.key)` is not cleared by any `SoundReset` entry.

        It is persisted and it decides what a take sounds like, so without a line there its \
        only remedy is delete-and-reinstall — the amputation #400 exists to replace.
        """)
    }

    /// ⭐ THE LAW, NOT THE NUMBER (#818). The founder asked for "immer … variationsreich", so a
    /// fresh install must already breathe — the default cannot be 0. The curated genre batches
    /// were auditioned at the preset itself, so it cannot be 1 either. Between those two the
    /// value is an ear decision and this guard deliberately does not pin it, so retuning it
    /// stays a one-line change (#364).
    func testTheOpeningDefaultBreathesWithoutBeingTheWholeSpread() {
        let v = StudioDefaultKeys.moodVariation.value
        XCTAssertTrue(v > 0, """
        the opening `moodVariation` is \(v). At 0 a fresh install composes every bar at the \
        preset, which is the state the founder asked to leave behind ("immer … variationsreich").
        """)
        XCTAssertTrue(v < 1, """
        the opening `moodVariation` is \(v). At 1 every curated genre opens at the far edge of \
        its allowed spread, and the batches were auditioned at the preset itself.
        """)
    }
}
