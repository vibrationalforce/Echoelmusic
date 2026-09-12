// TheIdiomVariationLeavesTheNilPathAloneTests.swift
// Echoel — G3a's variation axis changes no existing take, in the BLOCKING bundle.
//
// KIND: MIXED, labelled per claim. Claims 1–2 and 5 are END-TO-END BEHAVIOUR on the pure
// composer; claims 3–4 are a SOURCE-TEXT SCAN of `BioComposer.swift`, for facts no behavioural
// test can reach while every genre resolves to `nil`.
//
// ⭐ THIS FILE CARRIES A STRONGER CLAIM THAN THE G2 ONE, and the difference is worth stating
// because it is what makes the slice safe. `ThePadGrammarLeavesTheNilPathAloneTests` proves that
// a branch nobody reaches costs nothing. Here the flag can be turned ON — and must STILL cost
// nothing, because no genre owns an envelope yet. So there are two nil paths, not one:
//   · the flag is off  ⇒ `idiomControl` returns `nil` at its first `guard`
//   · the flag is on and the genre owns nothing ⇒ it returns `nil` at its second
// A future session that wires the "Vary" door (G3b) will turn the flag on for every take in the
// app. If only the first path were pinned, that commit would silently become the one that
// changed how thirty-six genres sound, with nothing in its diff saying so.
//
// ⚠️ HONEST GRADING (§0/§3), transcribed in Python against the parent and the worktree, since
// there is no toolchain here:
//   · claims 3–4 are REGRESSIONS on the parent for their named reason — neither the hook nor the
//     argument exists there, so every needle is absent. ONE absence reported twice (#486).
//   · claims 1, 2 and 5 are COUNTERWEIGHTS and are GREEN ON BOTH TREES by construction, which is
//     the point (#343): on the parent the flag does not exist, so they are compiled out of the
//     comparison; on the worktree they are the measurement that the axis is inert.
//
// ⛔ WHAT THIS FILE DELIBERATELY DOES NOT ASSERT: that the idiom seed consumes no RNG. That is
// `TheIdiomVariationDrawsNoRNGTests`, which measures it the only way it can be measured — by
// comparing UUID SEQUENCES rather than note counts. Two spellings of one law is the defect
// (#416); the two files split along the line between "the take is identical" and "the stream is
// un-shifted", which are different facts with different failure modes.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheIdiomVariationLeavesTheNilPathAloneTests: XCTestCase {

    private static let composerFile = "Sources/Echoelmusic/Sequencer/BioComposer.swift"

    /// Three body states that reach different branches: settled, middling, unsettled. `amount`
    /// is `max(varyFloor, 1 - coherence)`, so these are also the three points at which a wired
    /// envelope would move the least, some, and the most.
    private static let bodies: [(hr: Float, hrv: Float, coh: Float, breath: Float)] = [
        (52, 0.85, 0.95, 0.10),
        (74, 0.50, 0.50, 0.50),
        (108, 0.20, 0.05, 0.90)
    ]
    private static let seeds: [UInt64] = [0x5EED, 0xD00D, 0xBEEF]

    private func input(_ style: MusicStyle, _ body: (hr: Float, hrv: Float, coh: Float, breath: Float),
                       seed: UInt64, vary: Bool, nonce: UInt64 = 0) -> BioComposer.Input {
        BioComposer.Input(heartRateBPM: body.hr, hrvNormalized: body.hrv, coherence: body.coh,
                          breathPhase: 0.25, breathDepth: body.breath,
                          key: MusicalKey(root: 0, scale: style.scale),
                          style: style, mode: .studioLocked,
                          lockedTempo: Double(style.defaultTempo),
                          seed: seed, structureSeed: seed &+ 1,
                          suggestJourney: true,
                          idiomVariation: vary, variationNonce: nonce)
    }

    private func fingerprint(_ notes: [Note]) -> [String] {
        notes.map { "\($0.id)|\($0.pitch)|\($0.startStep)|\($0.lengthSteps)|\($0.velocity)" }
    }

    // MARK: - claim 1 (BEHAVIOUR, COUNTERWEIGHT) — the flag changes nothing, note for note

    /// `suggestJourney: true` is passed on purpose: that is the branch the Studio takes, and it
    /// is the branch the one wired hook lives in. Comparing on the legacy branch would leave the
    /// hook untested and read as a pass.
    func testTurningTheFlagOnChangesNoNote() {
        for style in MusicStyle.offered {
            for body in Self.bodies {
                for seed in Self.seeds {
                    let off = BioComposer.compose(input(style, body, seed: seed, vary: false))
                    let on = BioComposer.compose(input(style, body, seed: seed, vary: true))
                    XCTAssertEqual(fingerprint(off.notes), fingerprint(on.notes), """
                        \(style) at coherence \(body.coh), seed \(seed): turning \
                        `idiomVariation` on changed the take. No genre owns an \
                        `idiomProfile` today, so this must be impossible — either a hook \
                        stopped guarding on the optional, or a genre was given an envelope \
                        in a commit that did not also update this file's ledger.
                        """)
                }
            }
        }
    }

    // MARK: - claim 2 (BEHAVIOUR, COUNTERWEIGHT) — the nonce changes nothing either

    /// The nonce is what a re-generate button raises (G3b). With no envelope to move inside, a
    /// re-roll must be a no-op — otherwise the door would appear to work, on nothing.
    func testRaisingTheNonceChangesNoNote() {
        for style in MusicStyle.offered {
            let body = Self.bodies[1]
            let base = BioComposer.compose(input(style, body, seed: 0x5EED, vary: true, nonce: 0))
            for nonce in [UInt64(1), 7, 4_294_967_296] {
                let rolled = BioComposer.compose(input(style, body, seed: 0x5EED, vary: true, nonce: nonce))
                XCTAssertEqual(fingerprint(base.notes), fingerprint(rolled.notes), """
                    \(style): nonce \(nonce) changed the take while the genre owns no \
                    envelope. The nonce may only reach `IdiomControl.seed`; if it has found \
                    its way into `seed` or `structureSeed`, every note identity in the app \
                    now depends on a counter the composer's callers do not control.
                    """)
            }
        }
    }

    // MARK: - claim 3 (SOURCE SCAN) — the one wired hook reads the optional and nothing else

    func testTheAnchorHookIsGuardedByTheOptional() throws {
        let code = try source(Self.composerFile)
        XCTAssertTrue(code.contains("let rotSeed = progressionPhase + (idiom?.rootOffset ?? 0)"), """
            The G3 anchor hook is gone or rewritten. This is the ONE hook every genre \
            executes — the rotation that decides where a take enters its genre's own \
            progression. If the `?? 0` has been dropped, a nil idiom no longer resolves to \
            today's expression and every genre's entry point moved.
            """)
        XCTAssertTrue(code.contains("let rotBase = ((rotSeed % baseProg.count) + baseProg.count) % baseProg.count"), """
            The double modulo under the anchor hook is gone. `progressionPhase` can be \
            negative, so `%` alone yields a negative index and `baseProg[…]` traps. The \
            offset being non-negative is reasoning about the wrong summand.
            """)
        // The hook must not have grown a draw: the expression sits on the hot path of every
        // take, nil idiom or not.
        guard let hook = code.range(of: "let rotSeed = progressionPhase") else {
            throw AnchorMissing(reason: "the anchor hook is gone — re-anchor (#454)")
        }
        guard let after = code.range(of: "sectionAlterations?[i] = [0, 0, 0]",
                                     range: hook.upperBound..<code.endIndex) else {
            throw AnchorMissing(reason: "the anchor block lost its alteration reset — re-anchor (#454)")
        }
        let block = String(code[hook.lowerBound..<after.upperBound])
        XCTAssertFalse(block.contains("rng.next()"),
                       "the anchor block draws a random number — every later note identity shifts")
        XCTAssertFalse(block.contains("nextUUID("),
                       "the same defect written as a UUID draw — `nextUUID` advances the same generator")
    }

    // MARK: - claim 4 (SOURCE SCAN, COUNTERWEIGHT) — both call sites still hand it over

    func testBothCallSitesPassTheIdiom() throws {
        let code = try source(Self.composerFile)
        XCTAssertEqual(code.components(separatedBy: "idiom: idiom,").count - 1, 2, """
            `composeHarmonic` is no longer given the take's idiom at both call sites. With \
            the parameter un-defaulted this cannot compile — so if this is red, the \
            argument has been given a default, which is the #431/#440/#443 defect: a \
            forgetting that appears in no diff and silently flattens every envelope the \
            batches are about to author.
            """)
        XCTAssertTrue(code.contains("idiom: IdiomControl?,"), """
            The `idiom` parameter is gone from `composeHarmonic`, or has been given a \
            default. Read the comment above it before changing this.
            """)
        XCTAssertFalse(code.contains("idiom: IdiomControl? = nil"),
                       "the idiom parameter has been defaulted — see #431/#440/#443")
    }

    // MARK: - claim 5 (BEHAVIOUR, COUNTERWEIGHT) — nothing lost its pad with the flag on

    /// Green on both trees on purpose (#343). A file that only asserted equality would stay green
    /// on a tree where BOTH sides went silent.
    func testEveryOfferedGenreStillProducesAPadWithTheFlagOn() {
        for style in MusicStyle.offered {
            let notes = BioComposer.compose(input(style, Self.bodies[0], seed: 0xD00D, vary: true)).notes
            let pad = notes.filter { $0.role == .harmony }
            XCTAssertFalse(pad.isEmpty, "\(style) produces no pad with `idiomVariation` on")
            XCTAssertTrue(pad.allSatisfy { $0.lengthSteps >= 1 },
                          "\(style) has a zero-length pad note (#205/#176)")
        }
    }

    // MARK: - source access (§0/§2 — one stripper, skip on no tree, FAIL on a moved anchor)

    private struct AnchorMissing: Error { let reason: String }

    private func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path)
        else { throw XCTSkip("source tree not present under \(root.path)") }
        let path = root.appendingPathComponent(relativePath)
        guard let text = try? String(contentsOf: path, encoding: .utf8) else {
            throw AnchorMissing(reason: "\(relativePath) is missing — re-anchor, do not skip (#454)")
        }
        return SourceText.codeOnly(text)
    }
}
