// ADisabledParameterRowLooksDisabledTests.swift
// Echoel — #1401: a `.disabled()` `EchoelValueField` rendered PIXEL-IDENTICAL to a live one.
//
// WHY THIS EXISTS — it is a founder report from the device, not a polish item. On
// Mood → Pad rhythm **Hypnotic**, the Variation row would not move: "Variation geht nicht".
// Measured, the row was behaving exactly as designed. `padShapeSection` writes
// `.disabled(off || !(character?.usesEvolve ?? false))`, and `RoleRhythm.Character.usesEvolve`
// is `false` for `hypnotic` — turning evolve 0→1 there produces a bit-identical bar, which
// `RoleRhythmTests` asserts against real `hit(...)` output rather than trusting the flag.
//
// ⛔ THE DEFECT WAS THAT NOTHING SAID SO. `EchoelValueField` contained **no** reference to
// enabled-ness at all — measured on the parent with
// `git grep -c "isEnabled" Sources/Echoelmusic/Studio/EchoelValueField.swift` → 0. So the
// disabled row drew the same `EchoelTheme.text` label, the same `text` value and the same
// `borderStrong` control boundary as the two LIVE rows directly above it, and the boundary is
// the token #367 introduced to mean "this is operable". Three rows, one of them inert, no
// visible difference. The only explanation on screen was an 11 pt dim caption below all three
// — and `padShapeSection`'s own doc already conceded the point: "a disabled row that does not
// say WHY is only marginally better than an enabled one that does nothing". The design was
// right; the RENDERING never carried it, and the eye reaches the control before the caption.
//
// ⭐ AND THE SAME LIE WAS SPOKEN. The accessibility hint appended "Swipe up or down to adjust,
// or double-tap to type" unconditionally. VoiceOver says "dimmed" for a disabled element and
// then read an instruction the row cannot answer — the #164/#227 lying-control defect one
// sense over, on the surface this repo has already had to repair twice for sighted users.
//
// ⚠️ WHAT THIS SLICE DELIBERATELY DID **NOT** DO (#364). It did not give `hypnotic` an evolve
// behaviour. Whether Variation *should* move on that character is a sound decision and belongs
// to the founder's ear; `usesEvolve` is measured against real output, so flipping it here would
// be a view changing the engine to make its own dial look busy. Claim 7 pins the premise
// instead, so the day that decision IS taken, this file says what else must move.
//
// ⚠️ CONTRAST IS NOT WEAKENED. WCAG 1.4.3 and 1.4.11 both exempt inactive controls; claim 5 is
// the counterweight that keeps the ACTIVE (`accent`) and ENABLED-IDLE (`borderStrong`)
// boundaries exactly where #367 put them, so "dim the disabled one" cannot drift into "dim the
// control boundary".
//
// KIND (§1): **SOURCE-TEXT SCAN.** `EchoelValueField` is a `View` no test bundle can render,
// so this proves which colour token each branch NAMES — never what a screen shows. That a dim
// row reads as off to a human eye, and that VoiceOver speaks the shortened hint, are DEVICE
// PROBES and stay open.
//
// GRADING (§3), transcribed in Python against both trees, parent `a8e0c534d`:
// · Claims 1, 2, 3, 4 — **RED on the parent**, green here. They are genuine REGRESSIONS: the
//   parent has no enabled-ness in this file at all, which is precisely the reported defect.
//   ⚠️ They are ONE absence reported four times in the #486 sense — four assertions, one
//   missing property — and are counted that way rather than as four findings.
// · Claim 8 — a **FORWARD guard**, not a regression. Its positive half names
//   `filter(\.usesEvolve)`, which this commit writes; its negative half (no hard-coded
//   character list) was already true on the parent, because the parent had no list either.
//   Booking it as a regression would be the flattering direction (#433).
// · Claims 5, 6, 7 — **COUNTERWEIGHTS** (#343), green on both trees, and they are the point:
//   the #367 tokens survive (5), the row is still actually disabled (6), and the character the
//   founder was standing on still ignores evolve (7). Without 6 and 7 the first four guard a
//   state nothing in the app enters.
//
// ⚠️ THE STRIPPER IS LOAD-BEARING HERE, MEASURED, NOT ASSUMED (§2). Claim 8's negative half
// searches for the literal `Dynamic and Flowing` — and THIS SLICE writes that exact phrase into
// a warning comment in `padShapeCaption` telling the next session not to hard-code it. Raw:
// 1 hit. Comment-stripped: 0. So 1 of 1 verdicts flips — without `SourceText.codeOnly` this
// claim would be red on its own correct tree, which is the #1397 claim-5 self-collision in a
// new file.

import XCTest

final class ADisabledParameterRowLooksDisabledTests: XCTestCase {

    private static let field = "Sources/Echoelmusic/Studio/EchoelValueField.swift"
    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let rhythm = "Sources/Echoelmusic/Sequencer/RoleRhythm.swift"

    private func text(_ relative: String) -> String {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(
                atPath: dir.appendingPathComponent("Package.swift").path) { break }
            dir = dir.deletingLastPathComponent()
        }
        guard let s = try? String(contentsOf: dir.appendingPathComponent(relative),
                                  encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: \(relative) could not be read. This guard fails rather "
                    + "than skips (§4) — a missing anchor is a finding, not a pass.")
            return ""
        }
        return s
    }

    private func code(_ relative: String) -> String { SourceText.codeOnly(text(relative)) }

    // MARK: - Claim 1 — the field knows whether it is switched on

    func testTheParameterFieldReadsWhetherItIsEnabled() {
        let source = code(Self.field)
        XCTAssertTrue(source.contains("@Environment(\\.isEnabled) private var isEnabled"), """
            `EchoelValueField` no longer reads `isEnabled`. That read is the whole of #1401: \
            without it a `.disabled(…)` row draws the same label, the same value and the same \
            `borderStrong` control boundary as a live one, and the only report you get back is \
            the one that came back from the device — "Variation geht nicht" — about a row that \
            was working exactly as designed. It must come from the ENVIRONMENT and not from a \
            `disabled:` argument: `.disabled(…)` may sit on the row or on any ancestor, and an \
            argument only sees the call sites that remembered to pass it (#431/#440).
            """)
    }

    // MARK: - Claim 2 — label and idle value follow it, through ONE definition

    func testTheLabelAndTheValueBothFollowTheEnabledState() {
        let source = code(Self.field)
        XCTAssertTrue(
            source.contains("private var labelTint: Color { isEnabled ? EchoelTheme.text : EchoelTheme.dim }"),
            """
            `labelTint` is gone or no longer branches on `isEnabled`. It is ONE definition for \
            three call sites on purpose (#416): the stacked label, the inline label and the \
            idle value. Three separate ternaries is how two of them stay `EchoelTheme.text` \
            through the next edit and the row goes back to looking live.
            """)
        // ⚠️ `>=`, NOT `==` (#364/#818). There are exactly two label branches today — inline
        // and stacked-above (the accessibility text-size layout) — but a third is a legitimate
        // future layout, and a pinned 2 would red it while the thing this claim is NAMED for
        // (a branch reverted to the unconditional tint) is caught by the pair below anyway.
        XCTAssertGreaterThanOrEqual(
            source.components(separatedBy: ".foregroundStyle(labelTint)").count - 1, 2,
            """
            Fewer than two `Text(label)` branches tint through `labelTint`. A row that dims in \
            only one layout is worse than one that dims in neither: it reads as a rendering \
            bug at large Dynamic Type sizes instead of as a switched-off control.
            """)
        XCTAssertFalse(source.contains(".foregroundStyle(EchoelTheme.text)"), """
            A tint in `EchoelValueField` went back to the unconditional `EchoelTheme.text` — \
            the exact spelling this slice replaced, measured at 0 occurrences after it. That \
            is how one branch quietly stops dimming while `labelTint` still exists and claim 1 \
            still passes.
            """)
        XCTAssertTrue(source.contains(".foregroundStyle(active ? EchoelTheme.accent : labelTint)"),
            """
            The VALUE no longer dims with the row. The number is the largest thing in the \
            field (17 pt monospaced against a 14 pt label), so it is what the eye lands on — \
            a dim label over a full-brightness value still reads as an operable control.
            """)
    }

    // MARK: - Claim 3 — the control boundary stops promising operability

    func testTheBoundaryDropsTheControlTokenWhenTheRowIsOff() {
        let source = code(Self.field)
        XCTAssertTrue(source.contains("isEnabled ? EchoelTheme.borderStrong : EchoelTheme.border"),
            """
            The value box's boundary no longer branches on `isEnabled`. `borderStrong` is the \
            token #367 added to mean "this is operable" (0.45 opacity, a control boundary at \
            WCAG 1.4.11's 3:1); drawing it around a row that answers nothing is a promise. \
            `border` — the decorative token, which this file's own comment measures at 1.07:1 \
            against the box fill — is wrong for a live control and exactly right for a dead one.
            """)
    }

    // MARK: - Claim 4 — and the spoken version stops promising it too

    func testTheSpokenHintDropsTheGesturePromiseWhenTheRowIsOff() {
        let source = code(Self.field)
        XCTAssertTrue(source.contains("if !isEnabled { return hint }"), """
            The accessibility hint no longer shortens when the row is disabled. VoiceOver \
            already says "dimmed"; appending "Swipe up or down to adjust, or double-tap to \
            type" to that instructs a non-sighted performer to do something the row cannot \
            answer. That is the same lying-control defect (#164/#227) the visual half of this \
            slice repairs — and it is the half nobody can see in a screenshot.
            """)
        XCTAssertEqual(
            source.components(separatedBy: "Swipe up or down to adjust, or double-tap to type").count - 1,
            1,
            """
            The gesture instruction is no longer written exactly once. It lives in \
            `accessibleHint` so the disabled branch cannot be bypassed; a second copy \
            somewhere in `body` is how the promise comes back without the branch changing.
            """)
    }

    // MARK: - Claim 5 — COUNTERWEIGHT: #367's two live boundaries are untouched

    func testTheActiveAndIdleBoundariesStillUseTheControlTokens() {
        let source = code(Self.field)
        XCTAssertTrue(source.contains("EchoelTheme.accent"), """
            The value box lost its `accent` branch. That is the SCRUBBING/keypad-open state and \
            it must stay the loudest of the three; #1401 dims the OFF state only.
            """)
        XCTAssertTrue(source.contains("EchoelTheme.borderStrong"), """
            The value box lost `borderStrong` entirely. This slice adds a third, dimmer branch \
            — it does not replace the control boundary. If this is red, a find-and-replace \
            swept the file and repainted every parameter row as decorative, which is the \
            regression #367 was written for, not a fix (#364).
            """)
    }

    // MARK: - Claim 6 — COUNTERWEIGHT/premise: the row really is disabled

    func testTheVariationRowIsStillDisabledWhereTheCharacterIgnoresIt() {
        let source = code(Self.studio)
        XCTAssertTrue(source.contains(".disabled(off || !(character?.usesEvolve ?? false))"), """
            `padShapeSection` no longer disables the Variation row on characters that ignore \
            `evolve`. Claims 1–4 then guard a state the app never enters, and the row is back \
            to being a full-range dial that changes nothing — the #164/#227 defect this whole \
            file is about. If the row was HIDDEN instead (which is what the sibling Field \
            auto-play row does, `if fieldArpCharacter.usesEvolve`), that is a legitimate \
            choice — but then say so here and re-read this file's header, because its story \
            is about a VISIBLE dead control.
            """)
    }

    // MARK: - Claim 7 — COUNTERWEIGHT/premise: the reported character still ignores Variation

    func testTheReportedCharacterStillIgnoresVariation() {
        let source = code(Self.rhythm)
        XCTAssertTrue(source.contains("case .driving, .hypnotic, .sparse, .syncopated:  return false"),
            """
            `Character.usesEvolve`'s false list changed. THAT IS ALLOWED and may even be the \
            right answer to the founder's report — but it is a SOUND decision measured against \
            real `hit(...)` output, not a view concern, and it rewrites this file's premise: \
            the row the founder touched (Hypnotic) would then be live, and `padShapeCaption`'s \
            "Variation is off for this rhythm" sentence becomes a lie in the same commit. \
            Pull the caption and this header along with it (#456).
            """)
    }

    // MARK: - Claim 8 — FORWARD: the caption's signpost is projected, never typed

    func testTheCaptionNamesTheWorkingRhythmsByProjectionNotByList() {
        let source = code(Self.studio)
        XCTAssertTrue(source.contains("filter(\\.usesEvolve)"), """
            `padShapeCaption` no longer derives which rhythms carry Variation. Telling the \
            player where the dial DOES work is what turns "Variation geht nicht" from a wall \
            into a direction — but it has to be read off the engine.
            """)
        XCTAssertFalse(source.contains("Dynamic and Flowing"), """
            `padShapeCaption` hard-codes the character list. That is the exact mistake \
            `accentIsSubtle` exists to record: the first A7 UI hard-coded `hypnotic || \
            flowing` twenty lines under a comment congratulating itself for reading the flag \
            off the engine, and the list was WRONG — `sparse` spreads more than `hypnotic` and \
            was the one left out. A seventh character, or a re-tuned `usesEvolve`, must rewrite \
            this sentence for free.
            ⚠️ This claim reads COMMENT-STRIPPED source on purpose: this slice writes that exact \
            phrase into a warning comment saying not to hard-code it, so a raw scan would be \
            red on its own correct tree (measured: 1 raw hit, 0 stripped).
            """)
    }
}
