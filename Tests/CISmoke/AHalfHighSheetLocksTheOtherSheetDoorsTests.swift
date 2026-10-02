// AHalfHighSheetLocksTheOtherSheetDoorsTests.swift
// Echoel — the tool sheets open at HALF height, and while one is up no other sheet or alert door can
// drive a second modal true (slice D, founder order 2026-10-01: „Viele Bereiche sind zu groß und
// füllen den Bildschirm aus.").
//
// WHY THESE TWO FACTS ARE ONE GUARD. `echoelSheetPanel()` (FX "All parameters", Routing, Live
// Colabo) opened at `.large` until this slice, so the instrument behind was covered and its doors
// were unreachable until the user dragged the sheet down. At `.medium` the background is live from
// the first frame (`.presentationBackgroundInteraction(.enabled(upThrough: .medium))`), and every
// OTHER sheet/alert door of `EchoelStudioView` is reachable while one of these is up. Driving a
// second modal true over a presented sheet is the two-modals hang (an invisible tap-blocking layer,
// CLAUDE.md Presentation). So the default and the lock ship together, or the default is a hazard.
//
// THE THREE CLAIMS:
// 1. `EchoelSheetPanelModifier` starts at `.medium`, still offers `.large`, and keeps the background
//    live only up through `.medium` (a `.large` sheet still owns the screen).
// 2. `panelSheetUp` is exactly the three half-high sheet flags — `showAllFX`, `showLiveColabo`,
//    `showRouting` — and those three are the sheets that wear `.echoelSheetPanel()`.
// 3. EVERY setter of a sheet/alert flag in `EchoelStudioView` (`showOpen`, `showSaveDialog`,
//    `showLearn`, `showLiveColabo`, `showRouting`, `showAllFX`, `showSaveMoodAs`, `showSavePatchAs`
//    `= true`) is locked: either a `guard !panelSheetUp` sits in the three code lines above it, or the
//    line itself carries the older `if !showAllFX, !showLiveColabo` refusal, or the next of
//    `.disabled(panelSheetUp)` / `Button {` / another setter that follows it is the `.disabled`.
//    A visible disabled state, never a silent no-op (#164/#227).
//
// GRADING (§0/§3 — no Swift toolchain in a web session; transcribed in Python against the parent
// tree ae397d05a and the slice-D tree): all claims are SOURCE-TEXT scans. Parent: claim 1's
// `.medium` default is a REGRESSION (red: `.large`); claim 2 is red by ANCHOR ABSENCE (no
// `panelSheetUp`) — one absence (#486); claim 3 is a REGRESSION for eleven of its twelve setters
// (only the receiver's "routing" arm carried a refusal already).
// Slice-D tree: all green. Counterweights green on both: `.large` stays offered, the background
// interaction cap, and the three `.echoelSheetPanel()` sites.
// DEVICE PROBE, open: FX opens at half height with the instrument playable above it; with it up the
// Open/Learn/Save/Live Colabo tiles read disabled and a tap on the head's light tile (Routing's one
// door since slice G) does nothing; dragging FX to full height and back works; nothing freezes —
// readings, not scans.
//
// ⭐ SLICE G (founder order 2026-10-01, one door per area) MOVED CLAIM 3's FLOOR FROM 12 TO 10, and
// the two are not lost doors: they are the bio panel's „Open Routing" and the master panel's
// „Routing" button, both deleted, both `showRouting = true` setters. Routing's one door is the
// receiver's `case "routing":` arm (the head's light tile), which carries the older refusal and is
// still scanned here. The absence of the other two is pinned where it belongs —
// `TheRoutingHasOneDoorTests` — not by a floor that cannot tell a deleted door from a moved anchor.
// The single total floor is REPLACED by a floor PER SETTER, each at its measured count — strictly
// stronger than the old "≥ 12 in total": a lost `showOpen` door used to hide behind a gained
// setter elsewhere, and now cannot. Measured (code-only lines, first-matching setter per line):
//   parent 3deb54e77 — showOpen 2 · showSaveDialog 2 · showLearn 1 · showLiveColabo 1 ·
//                      showRouting 3 · showAllFX 1 · showSaveMoodAs 1 · showSavePatchAs 1 = 12
//   slice-G tree     — identical except showRouting 1 = 10; none unlocked on either tree.
// `showRouting`'s floor is 1, not 3, and that is the ONE number this slice lowers on purpose; its
// CEILING (exactly one) is `TheRoutingHasOneDoorTests` claim 1. Graded by transcription: on the
// parent every per-setter floor is met and the 12-total holds; on the slice-G tree every floor is
// met with the minimum exactly — a COUNTERWEIGHT on both, a REGRESSION guard for any later loss.

import XCTest

final class AHalfHighSheetLocksTheOtherSheetDoorsTests: XCTestCase {

    private static let panel = "Sources/Echoelmusic/Studio/EchoelSheetPanel.swift"
    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let setters = ["showOpen = true", "showSaveDialog = true", "showLearn = true",
                                  "showLiveColabo = true", "showRouting = true", "showAllFX = true",
                                  "showSaveMoodAs = true", "showSavePatchAs = true"]
    /// The measured number of code lines setting each flag (slice G, 2026-10-02 — see the header).
    /// A floor per setter, not one total: a lost door cannot hide behind a gained one.
    private static let measuredSetterLines: [String: Int] = [
        "showOpen = true": 2, "showSaveDialog = true": 2, "showLearn = true": 1,
        "showLiveColabo = true": 1, "showRouting = true": 1, "showAllFX = true": 1,
        "showSaveMoodAs = true": 1, "showSavePatchAs = true": 1,
    ]

    // MARK: 1 — half height by default

    func testThePanelSheetOpensAtHalfHeight() throws {
        let code = SourceText.codeOnly(try text(Self.panel))
        XCTAssertTrue(code.contains("@State private var detent: PresentationDetent = .medium"), """
            `EchoelSheetPanelModifier` no longer starts at `.medium`. The founder order is that a \
            tool sheet leaves the work area visible; a `.large` default covers it again.
            """)
        XCTAssertTrue(code.contains(".presentationDetents([.medium, .large], selection: $detent)"),
                      "the full height is still one drag away — an editor that wants room gets it")
        XCTAssertTrue(code.contains(".presentationBackgroundInteraction(.enabled(upThrough: .medium))"),
                      "the background is live only up through `.medium` — a full-height sheet still owns the screen")
    }

    // MARK: 2 — the lock names exactly the half-high sheets

    func testTheLockNamesExactlyTheHalfHighSheets() throws {
        let code = SourceText.codeOnly(try text(Self.studio))
        XCTAssertTrue(code.contains("private var panelSheetUp: Bool { showAllFX || showLiveColabo || showRouting }"), """
            ANCHOR / REGRESSION: `panelSheetUp` is missing or no longer the three half-high sheet \
            flags. A sheet that wears `.echoelSheetPanel()` and is not in it leaves every other door \
            live over it — the two-modals hang.
            """)
        XCTAssertEqual(code.components(separatedBy: ".echoelSheetPanel()").count - 1, 3, """
            `.echoelSheetPanel()` is applied \(code.components(separatedBy: ".echoelSheetPanel()").count - 1) \
            times in EchoelStudioView; the lock names three (FX, Routing, Live Colabo). A new half-high \
            sheet joins `panelSheetUp` in the same commit.
            """)
        XCTAssertTrue(code.contains(".sheet(isPresented: $showRouting) { AnyView(PatchbayView().echoelSheetPanel()) }"),
                      "ANCHOR: Routing is one of the three half-high sheets (#454)")
    }

    // MARK: 3 — every other door is locked while one is up

    func testEverySheetDoorIsLockedWhileAHalfHighSheetIsUp() throws {
        let lines = SourceText.codeOnly(try text(Self.studio)).components(separatedBy: "\n")
        var seen = 0
        var perSetter: [String: Int] = [:]
        for (index, line) in lines.enumerated() {
            guard let setter = Self.setters.first(where: { line.contains($0) }) else { continue }
            seen += 1
            perSetter[setter, default: 0] += 1
            if line.contains("if !showAllFX, !showLiveColabo") { continue }
            let above = lines[max(0, index - 3)..<index]
            if above.contains(where: { $0.contains("guard !panelSheetUp") }) { continue }
            var verdict: String?
            for next in lines[(index + 1)...] {
                if next.contains(".disabled(panelSheetUp)") { verdict = "locked"; break }
                if next.contains("Button {") || Self.setters.contains(where: { next.contains($0) }) {
                    verdict = "open"; break
                }
            }
            XCTAssertEqual(verdict, "locked", """
                `\(setter)` at EchoelStudioView line \(index + 1) is not locked while a half-high \
                sheet is up. Give its button `.disabled(panelSheetUp)` (or a `guard !panelSheetUp` \
                for a notification arm) — a second modal over a presented sheet is the two-modals hang.
                """)
        }
        XCTAssertGreaterThanOrEqual(seen, 10, """
            the scan saw \(seen) sheet/alert setters — fewer than the ten measured after slice G \
            (twelve before it; slice G deleted two of Routing's three doors, see the header) means \
            the anchors moved, not that the doors went (a scan that saw nothing is not a pass)
            """)
        XCTAssertEqual(Set(Self.measuredSetterLines.keys), Set(Self.setters),
                       "every scanned setter carries a measured floor, and every floor names a scanned setter")
        for setter in Self.setters {
            let floor = Self.measuredSetterLines[setter, default: 1]
            XCTAssertGreaterThanOrEqual(perSetter[setter, default: 0], floor, """
                the scan saw `\(setter)` on \(perSetter[setter, default: 0]) code line(s); \(floor) were \
                measured after slice G. Fewer means a door went without its sheet or an anchor moved — \
                both need this table edited in the same commit, never a floor quietly lowered. \
                (Routing's one setter is the receiver's `case "routing":` arm.)
                """)
        }
    }

    // MARK: helpers

    private func repoRoot() -> URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return root
    }

    private func text(_ relativePath: String) throws -> String {
        try String(contentsOf: repoRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }
}
