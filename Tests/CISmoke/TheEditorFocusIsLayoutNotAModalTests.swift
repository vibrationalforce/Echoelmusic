// TheEditorFocusIsLayoutNotAModalTests.swift
// Echoel — GMMW AE-3a (founder 2026-10-08: "Die klassische DAW Audio Editing View fehlt mir noch.
// Orientiere dich an den Bigplayern … vermeide Unübersichtlichkeit"). A phone in portrait has no
// room for a real editor under the canvas, the guide and the other tracks. FOCUS gives the
// selected part's editors the stage: the Arrange plate draws only the part bar, the open track's
// head and its detail (Part · Notes · Automation · Device), over the pinned transport.
//
// WHAT THIS PINS.
// 1. END-TO-END on the real owner (`WorkstationSelection`): focus is off by default, survives a
//    page change and another part on the same track, and ends with the track — `clear`,
//    `toggleTrack`, `selectTrack` and a `selectRegion` on another track turn it off — and, since
//    the AE-3 review (MED-2), a `selectRegion` after the focused part is gone.
// 2. END-TO-END (pure): `WorkstationSelection.focusShown` is true only with the flag on, on the
//    Arrange plate, for a part that still resolves on its track, on a track the part bar can
//    arrange. A plate change, an Undo that removes the part, a bio curve: no focus. Resolved on
//    read — nothing is pruned in a body.
// 3. SOURCE: it is LAYOUT, not a modal. The Workstation keeps its one presentation modifier (the
//    importer) and gains none; in focus the canvas, the guide, the song line, the other tracks,
//    the side-by-side column and the scene launcher step aside, while the part bar, the open
//    track's head and detail and the pinned transport stay — and, since the AE-3 review (MED-1),
//    the ruler, alone (`ArrangeFocusRuler`): the one control that moves a stopped playhead. The
//    plate asks the flag before it reads the part id (LOW-7). The flag is never persisted.
// 4. SOURCE (AE-3b): the part bar's Focus button is the ONE production writer — it toggles the
//    flag as it is at the tap, wears the bar's own tool button, and sits in the heading row,
//    which focus keeps on screen (the way out is never hidden by the thing it undoes). Since the
//    AE-3 review: the heading falls back under the title at a large type size (MED-3), Voice
//    Control answers to the button's word (LOW-9), and the change is announced (LOW-10).
//
// Grading (§0/§3, no Swift toolchain). `editorFocused`, `setEditorFocused` and `focusShown` do
// not exist on `c96d884`, so this file does not compile there — one absence (#486), every claim a
// FORWARD guard. Claim 4 was "no writer yet" in AE-3a (`3781017`) and is flipped by AE-3b; on
// `3781017` its new form is red for exactly that reason (no `focusButton`) — a FORWARD guard. Claims 1–2 transcribed into Python (the selection's state machine
// and the pure predicate); claim 3's scans driven against both trees — its counterweights (one
// importer, one canvas, one inspector, the pinned transport, no `UserDefaults`/`Codable` in the
// owner) are green on both. The AE-3 review commit adds, per claim: 1's removed-part case
// (REGRESSION on `5a45436` — the flag stayed on), 3's focus ruler and flag-first scans (red there by
// ANCHOR ABSENCE, one absence), 4's fallback, input label and announcement (FORWARD).
// NOT covered: that the focused plate reads well on glass, that VoiceOver finds its way out, and
// that rotating with focus on keeps the chosen detail page — device probes.
// NEEDS-FOUNDER-VERIFY: select a part, tap Focus → the canvas, the guide and
// the other tracks go; the ruler, the part bar, the track's head and its detail fill the screen, the
// transport stays at the bottom; the button now reads "Show all". Tap the ruler → Play's line moves.
// Tap Show all, or switch to Mixer → the full plate. At the largest text size the two buttons sit
// under the title, nothing clipped.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheEditorFocusIsLayoutNotAModalTests: XCTestCase {

    private static let selectionPath = "Sources/Echoelmusic/Studio/WorkstationSelection.swift"
    private static let viewPath = "Sources/Echoelmusic/Studio/WorkstationView.swift"

    private static let laneA = TimelineLane(name: "Keys", kind: .midi)
    private static let laneB = TimelineLane(name: "Bass", kind: .midi)
    private static let bioLane = TimelineLane(name: "Pulse", kind: .midi, isBio: true)
    private static let partA1 = TimelineRegion(laneID: laneA.id, clipID: UUID(), startTick: 0,
                                               lengthTicks: TimelineTime.ticksPerBar)
    private static let partA2 = TimelineRegion(laneID: laneA.id, clipID: UUID(),
                                               startTick: TimelineTime.ticksPerBar,
                                               lengthTicks: TimelineTime.ticksPerBar)
    private static let partB = TimelineRegion(laneID: laneB.id, clipID: UUID(), startTick: 0,
                                              lengthTicks: TimelineTime.ticksPerBar)
    private static let bioPart = TimelineRegion(laneID: bioLane.id, clipID: UUID(), startTick: 0,
                                                lengthTicks: TimelineTime.ticksPerBar)
    private static let document = TimelineDocument(lanes: [laneA, laneB, bioLane],
                                                   regions: [partA1, partA2, partB, bioPart])

    // MARK: 1 — focus ends with the track (real owner)

    func testFocusEndsWithTheTrack() {
        let selection = WorkstationSelection()
        XCTAssertFalse(selection.editorFocused, "off by default — the full plate first")

        selection.selectRegion(Self.partA1.id, in: Self.document)
        selection.setEditorFocused(true)
        selection.selectRegion(Self.partA2.id, in: Self.document)
        XCTAssertTrue(selection.editorFocused, "another part on the same track keeps the stage")
        selection.showInspectorPage(.notes)
        XCTAssertTrue(selection.editorFocused, "a page change inside the detail keeps it")
        selection.selectTrack(Self.laneA.id)
        XCTAssertTrue(selection.editorFocused, "re-selecting the open track changes nothing")

        selection.selectRegion(Self.partB.id, in: Self.document)
        XCTAssertFalse(selection.editorFocused, "a part on ANOTHER track ends the focus")

        selection.setEditorFocused(true)
        selection.selectTrack(Self.laneA.id)
        XCTAssertFalse(selection.editorFocused, "selecting another track ends it")

        selection.selectRegion(Self.partA1.id, in: Self.document)
        selection.setEditorFocused(true)
        selection.toggleTrack(Self.laneB.id)
        XCTAssertFalse(selection.editorFocused, "toggling another track open ends it")

        selection.selectRegion(Self.partA1.id, in: Self.document)
        selection.setEditorFocused(true)
        selection.toggleTrack(Self.laneA.id)
        XCTAssertFalse(selection.editorFocused, "closing the open track ends it")
        XCTAssertNil(selection.trackID)

        selection.selectRegion(Self.partA1.id, in: Self.document)
        selection.setEditorFocused(true)
        selection.clear()
        XCTAssertFalse(selection.editorFocused, "a clear ends it")

        selection.selectRegion(Self.partA1.id, in: Self.document)
        selection.setEditorFocused(true)
        selection.setEditorFocused(false)
        XCTAssertFalse(selection.editorFocused, "and the switch turns it off")
        XCTAssertEqual(selection.regionID, Self.partA1.id, "…leaving the part selected")

        // AE-3 review (MED-2): the focused part was removed (or undone); a tap on another part of
        // the same track must not turn the stage back on unasked.
        selection.selectRegion(Self.partA1.id, in: Self.document)
        selection.setEditorFocused(true)
        let removed = TimelineDocument(lanes: [Self.laneA, Self.laneB, Self.bioLane],
                                       regions: [Self.partA2, Self.partB, Self.bioPart])
        selection.selectRegion(Self.partA2.id, in: removed)
        XCTAssertFalse(selection.editorFocused, "the part focus was on is gone — the next tap starts unfocused")
        XCTAssertEqual(selection.regionID, Self.partA2.id, "…and still selects the tapped part")
    }

    // MARK: 2 — whether focus shows is resolved on read (pure)

    func testFocusShowsOnlyForALivePartOnTheArrangePlate() {
        func shown(_ flag: Bool = true, arrange: Bool = true, region: UUID? = Self.partA1.id,
                   track: UUID? = Self.laneA.id, in document: TimelineDocument = Self.document) -> Bool {
            WorkstationSelection.focusShown(flag, onArrange: arrange, region: region, track: track, in: document)
        }
        XCTAssertTrue(shown(), "flag on, Arrange, a live part on its arrangeable track")
        XCTAssertFalse(shown(false), "the flag is off")
        XCTAssertFalse(shown(arrange: false), "another plate — Mixer, Browse, Piece — shows the full plate")
        XCTAssertFalse(shown(region: nil), "no part selected")
        XCTAssertFalse(shown(track: nil), "no track selected")
        XCTAssertFalse(shown(region: Self.partB.id), "a part that does not sit on the selected track")
        let undone = TimelineDocument(lanes: [Self.laneA, Self.laneB], regions: [Self.partA2, Self.partB])
        XCTAssertFalse(shown(in: undone), "an Undo removed the part — focus stops showing, nothing pruned")
        XCTAssertFalse(shown(region: Self.bioPart.id, track: Self.bioLane.id),
                       "a bio curve has no part bar, so it has no focus")
    }

    // MARK: 3 — layout, not a modal; who steps aside and who stays (source)

    func testFocusIsLayoutAndKeepsTheWayOut() throws {
        let owner = try source(Self.selectionPath)
        XCTAssertTrue(owner.contains("public private(set) var editorFocused = false"),
                      "one flag, written only through the owner")
        for banned in ["UserDefaults", "@AppStorage", "Codable"] {
            XCTAssertFalse(owner.contains(banned), "`\(banned)` in the selection owner — focus is view state, never remembered")
        }

        let view = try source(Self.viewPath)
        for modal in [".sheet(", ".fullScreenCover(", ".popover(", ".alert(", ".confirmationDialog(", ".fileExporter("] {
            XCTAssertFalse(view.contains(modal), "`\(modal)` on the Workstation — focus is layout, never a presentation")
        }
        XCTAssertEqual(view.components(separatedBy: ".fileImporter(").count - 1, 1,
                       "COUNTERWEIGHT: the one importer is still the only presentation modifier")
        let shownGate = try member("private var editorFocusShown: Bool {", in: view)
        guard let flag = shownGate.range(of: "selection.editorFocused"),
              let predicate = shownGate.range(of: "&& WorkstationSelection.focusShown(true, onArrange: pieceView == .arrange,"),
              let part = shownGate.range(of: "region: selection.regionID") else {
            return XCTFail("ANCHOR MISSING: the plate's flag-first focus gate (#454)")
        }
        XCTAssertTrue(flag.upperBound <= predicate.lowerBound && predicate.upperBound <= part.lowerBound, """
            the plate asks the ONE predicate, resolved on read — and asks the flag first, so with             focus off a part tap never makes the whole plate read the part id (review LOW-7)
            """)

        let body = try member("var body: some View {", in: view)
        XCTAssertTrue(body.contains("let focused = editorFocusShown"))
        XCTAssertTrue(body.contains("if !focused { songLine(summary) }"), "the song line steps aside")
        XCTAssertTrue(body.contains("let sideBySide = verticalSizeClass == .compact && !arrangeRows.isEmpty && !focused"),
                      "in focus the detail takes the full width, landscape too")
        let canvasGate = try block(after: "if !focused {\n", in: body)
        XCTAssertTrue(canvasGate.contains("ArrangeCanvasView("), "the canvas steps aside")
        XCTAssertFalse(canvasGate.contains("SelectedPartBar("), "the part bar STAYS — it holds the way out")
        guard let gateStart = body.range(of: "if !focused {\n"),
              let otherwise = body.range(of: "} else {", range: gateStart.upperBound..<body.endIndex) else {
            return XCTFail("ANCHOR MISSING: the canvas gate's else (#454)")
        }
        let rulerGate = try block(after: "} else {", in: String(body[otherwise.lowerBound...]))
        XCTAssertTrue(rulerGate.contains("ArrangeFocusRuler("), "in focus the ruler stays — the canvas's else (review MED-1)")
        XCTAssertFalse(rulerGate.contains("SelectedPartBar("), "…alone: the part bar is outside the gate")
        XCTAssertEqual(view.components(separatedBy: "ArrangeFocusRuler(").count - 1, 1, "one focus ruler")
        let ruler = try source("Sources/Echoelmusic/Studio/ArrangeRulerLocator.swift")
        let focusRuler = try member("struct ArrangeFocusRuler: View {", in: ruler)
        XCTAssertTrue(focusRuler.contains("ArrangeRulerLocator(document: document, songTicks: songTicks,"),
                      "it IS the canvas's ruler row — the same tap, line and VoiceOver control, not a second ruler")
        let laneGate = try block(after: "if !focused || open == row.id {", in: body)
        XCTAssertTrue(laneGate.contains("TrackInspectorView(laneID: row.id)") && laneGate.contains("laneRow(row)"),
                      "the open track keeps its head and its detail; the others step aside")
        let launcher = try block(after: "if pieceView == .arrange && !focused {", in: body)
        XCTAssertTrue(launcher.contains("SessionLaunchView(playFrom:"), "the scene launcher steps aside")
        let guide = try member("private var composeGuide: some View {", in: view)
        guard let off = guide.range(of: "if !editorFocusShown {"),
              let gate = guide.range(of: "if pieceView == .arrange || !facts.hasPart {") else {
            return XCTFail("ANCHOR MISSING: the guide's focus gate or its plate gate (#454)")
        }
        XCTAssertLessThan(off.lowerBound, gate.lowerBound, "the guide steps aside in focus, its plate rule unchanged inside")

        // Counterweights (#343): one canvas, one inspector, one part bar, the transport pinned.
        XCTAssertEqual(view.components(separatedBy: "ArrangeCanvasView(").count - 1, 1)
        XCTAssertEqual(view.components(separatedBy: "TrackInspectorView(laneID: row.id)").count - 1, 1)
        XCTAssertEqual(view.components(separatedBy: "SelectedPartBar(playFrom:").count - 1, 1)
        XCTAssertTrue(body.contains(".safeAreaInset(edge: .bottom, spacing: 0) { transportBar }"),
                      "the transport stays pinned in focus")
    }

    // MARK: 4 — the part bar's Focus button is the ONE writer (AE-3b)

    func testThePartBarsFocusButtonIsTheOnlyWriter() throws {
        let root = repoRoot().appendingPathComponent("Sources/Echoelmusic")
        guard let walker = FileManager.default.enumerator(atPath: root.path) else {
            return XCTFail("cannot enumerate Sources/Echoelmusic — a scan that saw nothing is not a pass")
        }
        var writers: [String] = []
        var seen = 0
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            seen += 1
            guard let text = try? String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
            else { continue }
            if SourceText.codeOnly(text).contains(".setEditorFocused(") { writers.append(relative) }
        }
        XCTAssertGreaterThan(seen, 200, "the walk saw \(seen) files — the wrong directory")
        XCTAssertEqual(writers, ["Studio/SelectedPartBar.swift"], "one door turns focus on and off: the part bar's")

        let bar = try source("Sources/Echoelmusic/Studio/SelectedPartBar.swift")
        XCTAssertEqual(bar.components(separatedBy: ".setEditorFocused(").count - 1, 1, "…and it writes once")
        let button = try member("private var focusButton: some View {", in: bar)
        XCTAssertTrue(button.contains("selection.setEditorFocused(!selection.editorFocused)"),
                      "the button toggles the flag as it is at the tap")
        XCTAssertTrue(button.contains("return button(focused ? \"Show all\" : \"Focus\","),
                      "it wears the bar's own tool button and says what a tap will do")
        XCTAssertTrue(button.contains(".accessibilityInputLabels([focused ? String(localized: \"Show all\") : String(localized: \"Focus\")])"),
                      "Voice Control answers to the word on the button (WCAG 2.5.3, review LOW-9)")
        XCTAssertTrue(button.contains("AccessibilityNotification.Announcement(selection.editorFocused"),
                      "the plate's change is announced (review LOW-10)")
        XCTAssertTrue(bar.contains("headingButtons(part, stacked: true)"),
                      "the heading has a fallback under the title at a large type size (review MED-3)")
        guard let header = bar.range(of: "Text(String(localized: \"Selected part · \") + title)"),
              let mount = bar.range(of: "focusButton\n"),
              let play = bar.range(of: "PartPlayButton(startTick: part.startTick, playFrom: playFrom,") else {
            return XCTFail("ANCHOR MISSING: the part bar's heading, its Focus mount or its Play (#454)")
        }
        XCTAssertTrue(header.upperBound < mount.lowerBound && mount.upperBound <= play.lowerBound,
                      "Focus sits in the heading row, before Play — the row focus keeps on screen")
        XCTAssertEqual(bar.components(separatedBy: "focusButton\n").count - 1, 1, "mounted once")
    }

    // MARK: helpers

    private struct AnchorMissing: Error { let reason: String }

    private func repoRoot() -> URL {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { dir.deleteLastPathComponent() }
        return dir
    }

    private func source(_ relativePath: String) throws -> String {
        guard let text = try? String(contentsOf: repoRoot().appendingPathComponent(relativePath), encoding: .utf8) else {
            throw XCTSkip("source tree not present")
        }
        return SourceText.codeOnly(text)
    }

    /// The text of the braces that open at the first `{` from `anchor` on.
    private func block(after anchor: String, in text: String) throws -> String {
        guard let start = text.range(of: anchor),
              let open = text[start.lowerBound...].firstIndex(of: "{") else {
            throw AnchorMissing(reason: "`\(anchor)` (#454)")
        }
        var depth = 1
        var index = text.index(after: open)
        while index < text.endIndex {
            switch text[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return String(text[text.index(after: open)..<index]) }
            default: break
            }
            index = text.index(after: index)
        }
        throw AnchorMissing(reason: "unbalanced braces after `\(anchor)` (#454)")
    }

    /// The body of the member declared by `head` (which ends in `{`).
    private func member(_ head: String, in text: String) throws -> String {
        try block(after: head, in: text)
    }
}
