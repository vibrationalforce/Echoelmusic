// TheMediaLookUndoComparesOnTheDisplayGridTests.swift
// Review repair 2d of 9d479f922 (2026-09-27): a media look's Undo decided "did the person move
// this since?" with `Double ==`. The applied values are `Float`s widened to `Double`
// (1.2949999570846558 shows as "1.29"), and `EchoelValueField` commits on the row's grid — so a
// person who re-typed the very number the row showed had "moved" the value and lost its way back
// without a word, while the repo already says in `EchoelStudioView` (`sameOnDisplayGrid`) why `==`
// is the wrong question there. The comparison is now made on the row's display grid, once
// (`VisualLookSnapshot.settingsDifferingOnDisplay`), for the card's Undo and the agent's report.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claims 1–2 are END-TO-END on shipped, Foundation-only types (`MediaSeedApplication`,
//     `VisualLookSnapshot`, `ScrubPrecision`) against a private `UserDefaults` suite.
//   · Claim 3 is END-TO-END on the shipped executor with a fresh `MediaLookUndo` (never `.shared`).
//   · Claim 4 is a SOURCE-TEXT SCAN: the six rows' literal `decimals:` equal `DisplayGrid` by
//     label (two spellings, pinned to each other), both undos ask the one comparison, and no
//     per-value `==` is left in `MediaSeedApplication.undo`.
//   · DEVICE PROBE, open: on the phone, apply a photo, re-type the Intensity the row shows, tap
//     Undo — the intensity must go back. NEEDS-FOUNDER-VERIFY.
//
// HONEST GRADING against the parent (9c9d0a071, §3): the file does not COMPILE there — it names
// `settingsDifferingOnDisplay` and `DisplayGrid`, which this commit creates — ONE absence (#486);
// claims 1–3 are FORWARD guards, claim 4's row/literal half is a COUNTERWEIGHT (green on both
// trees — the rows did not change). Hand-transcribed in Python over the grid arithmetic; mutants
// driven, each red for its named reason: `==` per value (claim 1: the re-typed value is kept;
// claim 3: the agent reports it kept), a blanket tolerance (claim 2: `abs(a-b) <= 0.01` calls
// 1.294 and 1.296 the same although the row shows 1.29 and 1.30 — ⚠️ measured: that mutant is NOT
// caught by 1.30-vs-1.29, whose difference is 0.010000000000000009 in binary; the straddling pair
// is what catches it, and `<= 0.02` is caught by both), a grid of 4 places in
// `DisplayGrid.intensity` (claim 4, the rows say 2).
// ⚠️ The premise "the applied intensity is OFF the grid" is asserted, not assumed (claim 1): a
// future preset whose `Float` happens to land on a hundredth would make the re-typing case
// indistinguishable from "unchanged", and the claim would then prove nothing — it says so.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheMediaLookUndoComparesOnTheDisplayGridTests: XCTestCase {

    private func freshDefaults() throws -> UserDefaults {
        let name = "echoel.tests.mediaLookGrid.\(UUID().uuidString)"
        let suite = try XCTUnwrap(UserDefaults(suiteName: name))
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: name) }
        return suite
    }

    /// A bright, coloured photo: intensity 0.35 + 1.05 · 0.9 = 1.295 as a `Float` → off the grid.
    private func photo() -> MediaSeed {
        MediaSeed(version: MediaSeed.formatVersion, hue: 0.6, dominantRed: 0.2, dominantGreen: 0.3,
                  dominantBlue: 0.8, brightness: 0.9, saturation: 0.7, contrast: 0.5,
                  hasDominantColour: true, sampledPixels: 64)
    }

    private func shown(_ value: Double, decimals: Int) -> Double {
        ScrubPrecision.gridded(value, decimals: decimals)
    }

    // MARK: 1 — the number the row shows, typed back in, is not a move: Undo puts it back

    func testAReTypedShownValueIsNotAMoveAndGoesBack() throws {
        let defaults = try freshDefaults()
        let original = VisualLookSnapshot.read(from: defaults)
        let applied = MediaSeedApplication.apply(photo(), to: defaults)
        let grid = VisualLookSnapshot.DisplayGrid.intensity
        let displayed = shown(applied.after.intensity, decimals: grid)
        XCTAssertNotEqual(displayed, applied.after.intensity,
                          "premise: the applied intensity is OFF the display grid (a Float widened); if this ever "
                          + "fails, this claim can no longer tell re-typing from unchanged — pick another value")
        XCTAssertEqual(displayed, 1.29, accuracy: 1e-12, "the row shows 1.29 for 1.2949999…")

        // The person opens the Intensity row and types the number it shows.
        defaults.set(displayed, forKey: StudioDefaultKeys.visualIntensity.key)
        XCTAssertEqual(VisualLookSnapshot.read(from: defaults).settingsDifferingOnDisplay(from: applied.after), [],
                       "as displayed, nothing differs")
        applied.undo(on: defaults)
        let back = VisualLookSnapshot.read(from: defaults)
        XCTAssertEqual(back.intensity, original.intensity, "the re-typed value was not a move — it goes back")
        XCTAssertEqual(back, original, "and so does everything else")
    }

    // MARK: 2 — one grid step IS a move, on every row's own grid; NaN is never "the same"

    func testOneGridStepIsAMoveAndIsKept() throws {
        let defaults = try freshDefaults()
        let original = VisualLookSnapshot.read(from: defaults)
        let applied = MediaSeedApplication.apply(photo(), to: defaults)
        let oneStep = shown(applied.after.intensity, decimals: VisualLookSnapshot.DisplayGrid.intensity) + 0.01
        defaults.set(oneStep, forKey: StudioDefaultKeys.visualIntensity.key)
        XCTAssertEqual(VisualLookSnapshot.read(from: defaults).settingsDifferingOnDisplay(from: applied.after),
                       ["intensity"])
        applied.undo(on: defaults)
        let back = VisualLookSnapshot.read(from: defaults)
        XCTAssertEqual(back.intensity, oneStep, accuracy: 1e-12, "a real move of one shown step is the person's")
        XCTAssertEqual(back.detail, original.detail)
        XCTAssertEqual(back.hue, original.hue)
        XCTAssertEqual(back.presetID, original.presetID)

        // Detail is a `decimals: 0` row: 48.4 shows as 48 (not a move), 49 is a move.
        let second = MediaSeedApplication.apply(photo(), to: defaults)
        XCTAssertEqual(second.after.detail, 48, "10 + 76 · 0.5")
        defaults.set(48.4, forKey: StudioDefaultKeys.visualDetail.key)
        XCTAssertEqual(VisualLookSnapshot.read(from: defaults).settingsDifferingOnDisplay(from: second.after), [])
        defaults.set(49.0, forKey: StudioDefaultKeys.visualDetail.key)
        XCTAssertEqual(VisualLookSnapshot.read(from: defaults).settingsDifferingOnDisplay(from: second.after),
                       ["detail"])
        second.undo(on: defaults)
        XCTAssertEqual(VisualLookSnapshot.read(from: defaults).detail, 49)

        // The grid is a comparison, not a tolerance: 1.294 and 1.296 are 0.002 apart and SHOW as
        // 1.29 and 1.30, so they differ; 1.30 and 1.29 differ by one step.
        XCTAssertFalse(VisualLookSnapshot.sameOnDisplayGrid(1.294, 1.296, decimals: 2),
                       "a tolerance would call these equal; the rows show two different numbers")
        XCTAssertFalse(VisualLookSnapshot.sameOnDisplayGrid(1.30, 1.29, decimals: 2))
        XCTAssertTrue(VisualLookSnapshot.sameOnDisplayGrid(1.2949999570846558, 1.29, decimals: 2))
        XCTAssertFalse(VisualLookSnapshot.sameOnDisplayGrid(.nan, .nan, decimals: 2), "NaN is never the same")
        XCTAssertFalse(VisualLookSnapshot.sameOnDisplayGrid(1, .infinity, decimals: 2))
        XCTAssertEqual(VisualLookSnapshot.DisplayGrid.byLabel.count, 6, "six rows, one grid each")
    }

    // MARK: 3 — the agent's report asks the same comparison

    @MainActor
    func testTheAgentsReportUsesTheSameComparison() async throws {
        let defaults = try freshDefaults()
        let original = VisualLookSnapshot.read(from: defaults)
        let owner = MediaLookUndo()
        let executor = EchoelCommandExecutor(timeline: TimelineStore(), selection: WorkstationSelection(),
                                             voiceCapacity: { 4 }, mediaLooks: owner, visualDefaults: defaults)
        func plan(_ steps: [EchoelCommand]) -> EchoelActionPlan {
            EchoelActionPlan(requestID: UUID(), steps: steps, basis: executor.snapshot(), consents: [])
        }
        owner.showPhoto(photo())
        _ = await executor.execute(plan([.applyMediaLook(medium: .photo)]))
        let applied = try XCTUnwrap(owner.pending)
        defaults.set(shown(applied.after.intensity, decimals: VisualLookSnapshot.DisplayGrid.intensity),
                     forKey: StudioDefaultKeys.visualIntensity.key)
        let undo = await executor.execute(plan([.undoAgentChange]))
        XCTAssertEqual(undo.steps.first?.outcome, .done("Took back my last change."),
                       "the re-typed shown number is not reported as kept")
        XCTAssertEqual(VisualLookSnapshot.read(from: defaults), original)

        _ = await executor.execute(plan([.applyMediaLook(medium: .photo)]))
        let again = try XCTUnwrap(owner.pending)
        defaults.set(shown(again.after.intensity, decimals: VisualLookSnapshot.DisplayGrid.intensity) + 0.01,
                     forKey: StudioDefaultKeys.visualIntensity.key)
        let kept = await executor.execute(plan([.undoAgentChange]))
        XCTAssertEqual(kept.steps.first?.outcome,
                       .failed(.partlyUndone(restored: 1, alreadyUndone: 0, kept: "The visual intensity")),
                       "one shown step IS a move, and it is named")
    }

    // MARK: 4 — the two spellings of the grid agree, and there is one comparison

    func testTheRowsAndTheGridAgreeAndThereIsOneComparison() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        func code(_ path: String) throws -> String {
            SourceText.codeOnly(try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8))
        }
        let studio = try code("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        for (label, grid) in VisualLookSnapshot.DisplayGrid.byLabel {
            guard let call = studio.range(of: "EchoelValueField(label: \"\(label)\",") else {
                return XCTFail("the \"\(label)\" row moved or was renamed — re-anchor, and move `DisplayGrid` with it")
            }
            let window = studio[call.upperBound...].prefix(200)
            guard let decimals = window.range(of: "decimals: ") else {
                return XCTFail("the \"\(label)\" row states no `decimals:` within its call")
            }
            let digits = window[decimals.upperBound...].prefix { $0.isNumber }
            XCTAssertEqual(Int(digits), grid, """
                The "\(label)" row displays \(digits) decimals but `VisualLookSnapshot.DisplayGrid` says \(grid). \
                The rows must keep a LITERAL (`VisualPresetValuesAreReachableTests`), so the grid is spelled \
                twice and must move in one commit — or the media look's Undo compares on a grid the row \
                does not show.
                """)
        }
        let look = try code("Sources/Echoelmusic/Studio/MediaSeedLook.swift")
        let executor = try code("Sources/Echoelmusic/EchoelAI/EchoelCommandExecutor.swift")
        XCTAssertTrue(look.contains("ScrubPrecision.gridded(a, decimals: decimals) == ScrubPrecision.gridded(b, decimals: decimals)"),
                      "the grid is the rows' own `ScrubPrecision.gridded`, not a second rounding")
        XCTAssertEqual(look.components(separatedBy: "settingsDifferingOnDisplay(from: after)").count - 1, 1,
                       "`MediaSeedApplication.undo` asks the one comparison")
        XCTAssertEqual(executor.components(separatedBy: "settingsDifferingOnDisplay(from: before)").count - 1, 1,
                       "the agent's `keptSettings` asks the one comparison")
        for exact in ["live.intensity == after.intensity", "live.intensity != before.intensity",
                      "live.hue == after.hue", "live.hue != before.hue"] {
            XCTAssertFalse(look.contains(exact) || executor.contains(exact),
                           "a per-value `==`/`!=` survives (`\(exact)`) — the display-grid comparison is bypassed")
        }
    }
}
