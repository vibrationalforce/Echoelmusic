//
//  BassGrammar.swift
//  Echoelmusic — Sequencer
//
//  ONE AUTHORED BASS FIGURE PER GENRE (founder 2026-09-04: "Ich will richtig gute Bass und Pad
//  etc Loops für Deep tech, dark minimal, deep house, psy prog House etc haben").
//
//  ⛔ WHY THIS EXISTS — measured before it was written (`PLAN_GENRE_BASS_PAD_LOOPS_2026-09-04.md`):
//  the pad side of a genre is built five ways (profile · articulation · patch · FX · mix) and the
//  BASS side had no genre axis at all. `BioComposer.appendBass` is one genre-blind walk — root on
//  the section downbeat, root/fifth on 8ths or quarters when the body has drive, ONE held root
//  when it does not. A house bass that lands on the "&", a psy bass that rolls three 16ths under
//  a free downbeat, a dark-minimal sub that holds — none of those could be composed, whatever the
//  genre said. This type is the missing axis: a fixed 16-step figure the genre OWNS, the way
//  `MusicStyle.chordArticulation` already owns the pad's grid.
//
//  THE FIGURE IS THE GENRE, NOT THE BODY. Like `.skank` for the pad ("the offbeat IS the genre, at
//  rest or aroused"), a grammar applies at a resting body too — the body keeps its say through
//  the section VELOCITY (`bassVelocity` in `composeHarmonic`, which carries breath depth and the
//  low-end tilt) and through `hVel`'s humanising. What the body no longer decides for these
//  genres is WHERE the bass lands; that was the defect.
//
//  PRECEDENCE, decided here so `appendBass` does not have to discover it: a user's Bass-rhythm
//  Picker choice (`Input.bassRhythm`, non-nil) WINS over the grammar and takes the walking path
//  exactly as before — the person asked for a character by name, the genre only offered one. With
//  the Picker on "Genre" (`nil`), the grammar plays. A genre WITHOUT a grammar (`nil` from
//  `MusicStyle.bassGrammar`) is byte-identical to the pre-grammar walk: the `#253 A3` Golden law
//  (`BassRhythmOverrideTests`) is untouched because the new branch is entered only where a genre
//  sets a value.
//
//  Pure Foundation value type, no RNG of its own (the caller humanises), so a figure is assertable
//  in CI — `Tests/CISmoke/GenreBassGrammarTests.swift`. Whether it GROOVES is a device question
//  and is filed as one (NEEDS-FOUNDER-VERIFY in the plan).
//

import Foundation

/// A fixed one-bar bass figure, in the composer's 16-step bar.
public enum BassGrammar: String, CaseIterable, Sendable, Codable {
    /// House: the bass on every "&" (phases 2 · 6 · 10 · 14), an 8th long, the downbeat FREE.
    /// Where a kick would sit the low end leaves a hole on purpose — that hole is the house pump.
    case offbeatEighths
    /// Psy: downbeat free, then three 16ths under every beat (phases 1-2-3 · 5-6-7 · …), each one
    /// step long. Twelve hits a bar, the rolling bass. The third of each three is the accent so the
    /// figure leans INTO the next beat rather than away from it.
    case rollingSixteenths
    /// Tech: every 8th, on-beats held to the "&", off-beats a 16th; the fifth on the last "&" of
    /// the bar (phase 14) so the loop turns around instead of treadmilling.
    case drivingEighths
    /// Dark minimal: ONE root held half the bar, then the fifth short on "3&" (phase 10) and
    /// nothing else. Weight, not a line.
    case sparseSub
    /// The BORDUN: the root held three quarters, then the fifth for the last one — and no
    /// silence anywhere. It is the only figure here whose hits cover all sixteen steps, and
    /// that is its identity rather than a detail: a bowed drone does not stop between notes.
    ///
    /// ⚠️ AUTHORED AHEAD (#1294) for `nordicFiddle`, exactly as `rollingSixteenths` waited for
    /// `psyProgHouse` through S1…S5. `GenreBassGrammarTests.testEveryGrammarIsOwnedOrAuthoredAhead`
    /// lists it, so the day a genre claims it that list goes red on the right line.
    ///
    /// ⛔ NOT NAMED `pedalDrone`, though the design catalogue writes that in the bass column for
    /// this genre. `pedalDrone` is the name the same catalogue gives a planned `PadGrammar` case,
    /// in the PAD column of a dozen drone genres — one spelling for two enums is the #416 shape
    /// waiting to happen, and whoever wrote the second one would have inherited the confusion.
    /// The bass figure is a bordun; the pad figure is a pedal. Two facts, two names.
    ///
    /// ⚠️ AND IT IS NOT A DOUBLE STOP, which is what the catalogue line describes ("droning
    /// double-stop fifths"). The bass role plays ONE pitch at a time — `Hit.fifth` chooses the
    /// fifth INSTEAD of the root, never beside it — so root-then-fifth without a gap is the
    /// honest approximation of a bowed drone pair, and the doc says so rather than claiming the
    /// interval. A real double stop needs two simultaneous bass notes, which is a different
    /// change to a different type.
    case heldRoot

    /// One hit of a figure. `phase` is the 16-step bar position; `length` in steps (≥ 1, the
    /// #205/#176 no-zero-length law); `level` scales the section velocity (1 = the section's own);
    /// `fifth` plays the chord's fifth instead of its root — always in key via `MusicalKey.degree`.
    public struct Hit: Equatable, Sendable {
        public let phase: Int
        public let length: Int
        public let level: Float
        public let fifth: Bool

        public init(phase: Int, length: Int, level: Float, fifth: Bool = false) {
            self.phase = phase
            self.length = length
            self.level = level
            self.fifth = fifth
        }
    }

    /// The figure, in ascending phase order, never overlapping (pinned by the guard).
    public var hits: [Hit] {
        switch self {
        case .offbeatEighths:
            return [Hit(phase: 2, length: 2, level: 1.0),
                    Hit(phase: 6, length: 2, level: 0.9),
                    Hit(phase: 10, length: 2, level: 1.0),
                    Hit(phase: 14, length: 2, level: 0.9)]
        case .rollingSixteenths:
            var out: [Hit] = []
            out.reserveCapacity(12)
            for beat in 0..<4 {
                let base = beat * 4
                out.append(Hit(phase: base + 1, length: 1, level: 0.85))
                out.append(Hit(phase: base + 2, length: 1, level: 0.80))
                out.append(Hit(phase: base + 3, length: 1, level: 1.0))
            }
            return out
        case .drivingEighths:
            var out: [Hit] = []
            out.reserveCapacity(8)
            for beat in 0..<4 {
                let base = beat * 4
                out.append(Hit(phase: base, length: 2, level: 1.0))
                out.append(Hit(phase: base + 2, length: 1, level: 0.85, fifth: beat == 3))
            }
            return out
        case .sparseSub:
            return [Hit(phase: 0, length: 8, level: 1.0),
                    Hit(phase: 10, length: 2, level: 0.8, fifth: true)]
        case .heldRoot:
            // The fifth on the LAST quarter, the same turnaround idea `drivingEighths` uses on
            // the last "&": the bar leads back instead of treadmilling on one note. Softer than
            // the root so the drone stays the ground and the fifth reads as its answer.
            return [Hit(phase: 0, length: 12, level: 1.0),
                    Hit(phase: 12, length: 4, level: 0.8, fifth: true)]
        }
    }
}

public extension MusicStyle {
    /// The bass figure this genre owns, or `nil` = the pre-grammar walking bass, byte-identical.
    ///
    /// Opt-in by design, so `default: nil` is the honest arm here and NOT the exhaustiveness
    /// dodge the rest of `MusicStyle` avoids: a genre that has not been given a figure keeps the
    /// walk it always had. S3–S5 of the plan add `deepTech` / `darkMinimal` / `psyProgHouse` with
    /// their own arms (`drivingEighths` / `sparseSub` / `rollingSixteenths`). ⚠️ `rollingSixteenths`
    /// was authored ahead of S5 and has been owned since; #1286 G5b gave it a SECOND owner
    /// (`darkPsyTrance`), which is the licence a shared figure was always meant to have — the
    /// two genres differ in their `bassPatch`, their tempo and their mode, never in the figure.
    var bassGrammar: BassGrammar? {
        switch self {
        case .deepHouse:     return .offbeatEighths
        case .techHouse:     return .drivingEighths
        case .deepTech:      return .drivingEighths   // #983 S3: shares the figure, not the patch
        case .darkMinimal:   return .sparseSub         // #983 S4: same — minimal's figure, its own sub
        case .psyProgHouse:  return .rollingSixteenths // #983 S5: the figure authored ahead in S1, owned
        // #1286 G5b — the same "share the figure, never the voice" licence the two lines above
        // already take: `industrialTechno` rolls minimal's sparse sub at a faster tempo on its
        // own patch, and `darkPsyTrance` is the SECOND owner of `rollingSixteenths`. Psy-prog
        // remains its FIRST owner, which is what its doc claims — and every owner has its own
        // `bassPatch`, which is the part that actually keeps two genres apart.
        // #1288 G6a — three more co-owners. `drivingEighths` goes to three and four owners;
        // `offbeatEighths` to three. Each brings its OWN bass patch, which is the licence's whole
        // shape (#1286): share the figure, never the voice.
        // #1289 G6b — three more co-owners; each brings its own bass patch.
        case .boomBapHipHop:    return .sparseSub
        case .electroFunk:      return .drivingEighths
        case .rootsReggae:      return .offbeatEighths
        // #1290 G11a — the SIXTH `drivingEighths` owner. `celticAir` gets NO figure: it is
        // `.none`-archetype with no bass patch, so it keeps the pre-grammar walk exactly as it
        // was. ⛔ The design sheet gave `nordicFiddle` a `pedalDrone` figure; that case does not
        // exist in this enum, and authoring a figure is its own slice (one case, one `hits` arm,
        // one map arm, one guard) — so that genre is NOT in this batch.
        //   ⭐ #1294 G11c DID that slice, and the prediction held exactly: the case was authored
        //   ahead as `heldRoot` (NOT `pedalDrone` — that spelling is reserved for a planned
        //   `PadGrammar` case, and one spelling for two enums is the #416 shape), and this arm
        //   is the map half that finally claims it. `GenreBassGrammarTests` moves it from
        //   `authoredAhead` to `owned` in the same commit, which is what makes an authored-ahead
        //   figure safe to leave sitting: the day someone takes it, the list goes red on the
        //   right line rather than the figure quietly acquiring an owner.
        case .nordicFiddle:     return .heldRoot
        // #1295b G11d — the SEVENTH owner of `drivingEighths`, and shared on purpose: a
        // figure is shareable, a VOICE never is. `balkanModal` gets its own patch
        // ("Brass Sub"), and that patch is built to stop inside its eighth — the exact
        // opposite of the `heldRoot` voice one line above.
        // ⛔ This read "SIXTH" until #1349 COUNTED the arms instead of copying the neighbour
        // four lines up: `andalusianCadence` WAS the sixth, and `balkanModal` landed after it.
        // One ordinal, inherited rather than measured — the cheapest possible instance of the
        // defect this file's own docs keep naming. Command: the `drivingEighths` owner list
        // printed by `python3 scripts/genre-prebatch.py <candidates.json>` under `7 BASS
        // GRAMMAR`, which prints the names and not a number, so it cannot go stale the same way.
        case .balkanModal:      return .drivingEighths
        // #1349 G10a — the EIGHTH owner of `drivingEighths`, and the sharing is the point one
        // more time: the design sheet gave this genre `offbeatEighths`, which is `soulBallad`'s
        // figure, and those two already share scale, stack, register and groove archetype. A
        // figure is shareable; two genres that close must not share THIS one. The voice is its
        // own ("Church Sub"), which is the half that never shares.
        case .gospelChoir:      return .drivingEighths
        // #1350 G15a — the FIFTH owner of `sparseSub`, and the sheet's own choice for once:
        // a sub that lands sparsely under a dragged backbeat is the figure. Shared with
        // `minimalTechno`, `darkMinimal`, `industrialTechno` and `boomBapHipHop` — the last of
        // those is a near neighbour, and the VOICE is where they part ("Wobble Sub" against
        // "Dust Sub"), exactly as every arm in this file argues.
        case .loFiHipHop:       return .sparseSub
        // #1354 G15b-2: SIXTH `sparseSub` owner. A half-time bass plays perhaps two notes
        // a bar, which is the sparsest reading this figure has — the voice (`Drag Sub`)
        // is its own, as always here: figure shared, voice never.
        case .slowedGothPop:    return .sparseSub
        // #1352 G15b-1 — the FIFTH owner of `offbeatEighths`, and the sheet's own choice:
        // the skank IS the figure, and dub inherits it from reggae unchanged. Shared with
        // `deepHouse`, `soulBallad`, `rootsReggae` and `afroHouse`. ⚠️ `rootsReggae` is the one
        // that matters — same figure, same mode, same register, overlapping tempo — and the
        // VOICE is where they part ("Dub Sub" against "Roll Sub"), which the patch arm measures
        // rather than asserts.
        case .dubEcho:          return .offbeatEighths
        // #1357 G14 — the SIXTH owner of `offbeatEighths`, joining `deepHouse`, `soulBallad`,
        // `rootsReggae`, `dubEcho` and `afroHouse`. The chuck lands between the beats in this
        // music exactly as it does in the other five; what differs is the voice, and that is
        // the licence this file grants — figure shared, voice never ("Lilt Sub" is its own
        // patch). ⚠️ TWO of those five sit at four of seven with this genre and it is a TIE,
        // not a nearest: `deepHouse` shares this figure, archetype, register and lead name;
        // `afroHouse` shares this figure, archetype, register and chord tones. Against
        // `deepHouse` the parting is scale (`.harmonicMinor` against `.minor`, so the V is
        // major here and minor there), progression, and a tempo window 16 BPM clear of it;
        // against `afroHouse` it is scale, lead voice and a window 14 BPM clear. The case doc
        // measures all of it rather than asserting it.
        case .cumbia:           return .offbeatEighths
        // #1358 G14b — the NINTH owner of `drivingEighths`, counted over the file rather than
        // inherited from a neighbouring comment (#1295b shipped an ordinal that was off by one
        // exactly that way). The figure's on-beat hits held to the "&" ARE the marcato stomp,
        // which is why the sheet's choice survived measurement unchanged. Voice is its own
        // ("Marcato Sub"), as always here.
        case .tangoMarcato:     return .drivingEighths
        case .andalusianCadence: return .drivingEighths
        case .blackMetal:       return .drivingEighths
        case .modalJazz:        return .drivingEighths
        case .soulBallad:       return .offbeatEighths
        case .industrialTechno: return .sparseSub
        case .afroHouse:        return .offbeatEighths
        case .darkPsyTrance:    return .rollingSixteenths
        case .minimalTechno: return .sparseSub
        default:             return nil
        }
    }
}
