// TheDetailShowsOnePageAtATimeTests.swift
// Echoel — Workstation redesign A8, extended by DAW shell S4a (founder 2026-10-02, the approved
// shell: "ein Detailbereich, der der Auswahl folgt"): the open track's detail shows ONE page at a
// time — Track (name · level · pan · remove), Part (the track's parts), Notes (the selected part's
// grid, `PartNoteEditor`), Automation (the track's curve, `SongAutomationEditor`) or Device (what
// plays it · instrument · instance · style · effect) — chosen by one segmented control at its top.
// Until S4a the note grid and the automation row were two more switches of their own under the
// canvas; this file was TheInspectorShowsOnePageOfThreeTests until then (#374: the name described
// three pages).
//
// WHAT THIS PINS, AND THE RISK IT ANSWERS. One inline area, up to five pages: the risk is not the
// control, it is a row that goes missing (a page gate that swallowed a row nobody re-homed), a
// second truth about the chosen page (an `@State` in a view rebuilt per track by `.id(row.id)`, a
// persisted copy beside the owner, or the old `notesOpen` flag standing beside the page), a page
// that is an empty box (Part on a bio track, Notes with no editable part, Automation where the
// curve would draw silence), an editor mounted twice (once on its page, once under the canvas),
// and a typed name lost when its page leaves the screen.
//
// 1. END-TO-END (pure + the real `@MainActor` owner): which pages a track offers — Part exactly
//    where `TrackParts.arrangeable` says, Notes exactly where `PartNoteEditor.editableRegion`
//    finds a part, Automation exactly where `SongAutomationEdit.sounds` says (#416: each page is
//    offered by the rule its own editor hides by); the page drawn falls back to Track; the choice
//    outlives a change of track, a close and a clear; a bio track never erases it; opening the
//    notes IS the Notes page, and closing them never moves another page.
// 2. SOURCE-TEXT SCAN: the body draws one `Picker`, segmented, whose setter commits the name
//    first; the Part/Notes/Automation segments exist only where their pages do; each page gate
//    appears once and holds its rows, each row once.
// 2c. SOURCE-TEXT SCAN (S4a review, MEDIUM): the note editor's four tool rows stand in a wrapping
//     layout built from ideal widths, so in the 260-pt landscape column they wrap instead of
//     truncating "Deselect" to "Des…". Whether it LOOKS right is a device check.
// 2b. SOURCE-TEXT SCAN (S4b): the record arm and an audio track's Pitch are Track-page rows, an
//    imported file's tempo is a Part-page row — built by the Workstation, placed by the detail,
//    never left loose under it.
// 3. SOURCE-TEXT SCAN: the choice is view state on the ONE owner — one writer, no persistence,
//    and `notesOpen` is read off the page, never stored beside it.
// 4. COUNTERWEIGHTS (#343): no modal and no hot read in the detail; the name still commits on
//    close; the instance request still runs on appear; the Workstation still mounts the detail,
//    the part bar, the arm switch, the pitch field and the part-tempo rows once each — and the
//    two editors NOWHERE but on their pages; `TrackPartsView` keeps its own gate; the segment
//    words and the hint are English-only catalog keys.
//
// Grading (Tests/CISmoke/CLAUDE.md §0/§3 — no Swift toolchain in a web session):
// · Parent (72d502edd): claims 1 and 3 are red there by ONE absence — `TrackMix.detailPages` and
//   the `.notes`/`.automation` cases do not exist (the file does not compile there), reported
//   once (#486). Claim 2 is red there on the `detailPages` line, the two new segments and the two
//   new page gates; claim 4 on the hint key and on the two editors still mounted in the
//   Workstation body. Every red names the S4a absence, none another reason.
// · S4b (parent 2bf2cba20): claim 2b and claim 2's `trackRows`/`partRows` rows are red there by
//   ONE absence — the inspector takes no rows from its caller; every other claim is unchanged.
// · S4a review (parent 0b05984fb): claim 2c is red there by ONE absence — no `NoteToolFlow`.
// · This tree: every claim transcribed into Python and driven green.
// · Stripper (`SourceText.codeOnly`): PROPHYLAKTISCH — 0 of the source verdicts flip between
//   raw and stripped text on either tree.
// NOT covered: whether the segments render, fit, or read well — a device probe.
// NEEDS-FOUNDER-VERIFY: Workstation → open a rack MIDI track and select one of its parts: the
// control reads "Track | Part | Notes | Automation | Device" and each page shows only its rows;
// "Write notes" in the compose guide opens the Notes page; type a new name, tap "Device" before
// Return — the name is kept; open another track — the same page stays; open the bio track — two
// segments, Track shown; in landscape the five words fit the 260-pt detail column at the largest
// text size; a tap near the top or bottom edge of a segment still switches. S4b: the record arm
// (rack MIDI track) and an audio track's Pitch sit on the Track page, an imported file's tempo on
// the Part page — nothing hangs loose under the detail any more.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheDetailShowsOnePageAtATimeTests: XCTestCase {

    private static let inspectorPath = "Sources/Echoelmusic/Studio/TrackInspectorView.swift"
    private static let ownerPath = "Sources/Echoelmusic/Studio/WorkstationSelection.swift"
    private static let workstationPath = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let partsViewPath = "Sources/Echoelmusic/Studio/TrackPartsView.swift"
    private static let notesPath = "Sources/Echoelmusic/Studio/PartNoteEditor.swift"
    private static let automationPath = "Sources/Echoelmusic/Studio/SongAutomationEditor.swift"
    private static let catalogPath = "Sources/Echoelmusic/Resources/Localizable.xcstrings"
    private static let sourcesRoot = "Sources/Echoelmusic"

    private struct AnchorMissing: Error {}

    // MARK: 1 — END-TO-END: the pages a track offers, and the choice that outlives the track

    func testATrackOffersItsPagesAndTheChoiceOutlivesTheTrack() {
        let keys = TimelineLane(name: "Keys", kind: .midi)
        let loop = TimelineLane(name: "Loop", kind: .audio)
        let body = TimelineLane(name: "Body", kind: .midi, isBio: true)
        let look = TimelineLane(name: "Look", kind: .visual)
        let doc = TimelineDocument(lanes: [keys, loop, body, look], regions: [])

        XCTAssertEqual(TrackMix.inspectorPages(of: keys.id, in: doc), [.track, .part, .device])
        XCTAssertEqual(TrackMix.inspectorPages(of: loop.id, in: doc), [.track, .part, .device])
        XCTAssertEqual(TrackMix.inspectorPages(of: body.id, in: doc), [.track, .device],
                       "a bio track has no parts to arrange — a Part page there is an empty box")
        XCTAssertEqual(TrackMix.inspectorPages(of: look.id, in: doc), [.track, .device])
        for lane in doc.lanes {
            XCTAssertEqual(TrackMix.inspectorPages(of: lane.id, in: doc).contains(.part),
                           TrackParts.arrangeable(lane.id, in: doc),
                           "Part is offered exactly where TrackPartsView draws rows (#416)")
        }

        XCTAssertEqual(TrackInspectorPage.shown(.device, offered: [.track, .part, .device]), .device)
        XCTAssertEqual(TrackInspectorPage.shown(.part, offered: [.track, .device]), .track,
                       "a track without the chosen page shows Track — every track has a name")
        XCTAssertEqual(TrackInspectorPage.shown(.track, offered: [.track, .device]), .track)

        let selection = WorkstationSelection()
        XCTAssertEqual(selection.inspectorPage, .track, "a fresh owner opens on Track")
        selection.showInspectorPage(.device)
        selection.selectTrack(keys.id)
        XCTAssertEqual(selection.inspectorPage, .device, "the page survives opening a track")
        selection.toggleTrack(keys.id)
        XCTAssertNil(selection.trackID, "toggling the open track closes it")
        XCTAssertEqual(selection.inspectorPage, .device, "the page survives a close")
        selection.clear()
        XCTAssertEqual(selection.inspectorPage, .device, "the page survives a clear")

        selection.showInspectorPage(.part)
        selection.selectTrack(body.id)
        XCTAssertEqual(TrackInspectorPage.shown(selection.inspectorPage,
                                                offered: TrackMix.inspectorPages(of: body.id, in: doc)),
                       .track, "the bio track draws Track")
        XCTAssertEqual(selection.inspectorPage, .part,
                       "and does not erase the choice — the next MIDI track opens on Part again")
    }

    // MARK: 1b — END-TO-END: Notes and Automation are pages where their editors have something

    func testNotesAndAutomationArePagesWhereTheyHaveSomethingToEdit() {
        // The first non-bio MIDI track is the Echoel track (no curve row — a founder call); the
        // second is a rack track (`.laneSynth(.poly)` with capacity), the one that takes a curve.
        let echoel = TimelineLane(name: "MIDI 1", kind: .midi)
        let rack = TimelineLane(name: "Keys", kind: .midi)
        let loop = TimelineLane(name: "Loop", kind: .audio)
        let body = TimelineLane(name: "Body", kind: .midi, isBio: true)
        let echoelPart = TimelineRegion(laneID: echoel.id, clipID: UUID(), startTick: 0, lengthTicks: 1920)
        let rackPart = TimelineRegion(laneID: rack.id, clipID: UUID(), startTick: 0, lengthTicks: 1920)
        let loopPart = TimelineRegion(laneID: loop.id, clipID: UUID(), startTick: 0, lengthTicks: 1920)
        let bodyPart = TimelineRegion(laneID: body.id, clipID: UUID(), startTick: 0, lengthTicks: 1920)
        let doc = TimelineDocument(lanes: [echoel, rack, loop, body],
                                   regions: [echoelPart, rackPart, loopPart, bodyPart])

        XCTAssertEqual(TrackMix.detailPages(of: echoel.id, selectedRegion: nil, in: doc, voiceCapacity: 4),
                       [.track, .part, .device], "no part selected: no Notes page")
        XCTAssertEqual(TrackMix.detailPages(of: echoel.id, selectedRegion: echoelPart.id, in: doc, voiceCapacity: 4),
                       [.track, .part, .notes, .device], "its MIDI part selected: Notes, before Device")
        XCTAssertEqual(TrackMix.detailPages(of: rack.id, selectedRegion: nil, in: doc, voiceCapacity: 4),
                       [.track, .part, .automation, .device], "a rack track takes a curve")
        XCTAssertEqual(TrackMix.detailPages(of: rack.id, selectedRegion: rackPart.id, in: doc, voiceCapacity: 4),
                       [.track, .part, .notes, .automation, .device], "all five, in the control's order")
        XCTAssertEqual(TrackMix.detailPages(of: rack.id, selectedRegion: echoelPart.id, in: doc, voiceCapacity: 4),
                       [.track, .part, .automation, .device], "a part on ANOTHER track opens no Notes here")
        XCTAssertEqual(TrackMix.detailPages(of: rack.id, selectedRegion: rackPart.id, in: doc, voiceCapacity: 0),
                       [.track, .part, .notes, .device], "without a rack voice a curve would draw silence")
        XCTAssertEqual(TrackMix.detailPages(of: loop.id, selectedRegion: loopPart.id, in: doc, voiceCapacity: 4),
                       [.track, .part, .device], "an audio part has no notes and no curve")
        XCTAssertEqual(TrackMix.detailPages(of: body.id, selectedRegion: bodyPart.id, in: doc, voiceCapacity: 4),
                       [.track, .device], "the bio curve has no parts, notes or curve row")

        // #416, biconditional over every track × every selection: each page is offered by the
        // rule its editor hides by, and the inspector's own three keep their rule and order.
        // `[UUID?]` spelled out: `[nil] + [UUID]` does not type-check (the two element types differ).
        let selections: [UUID?] = [nil] + doc.regions.map { Optional($0.id) }
        for lane in doc.lanes {
            for selected in selections {
                for capacity in [0, 4] {
                    let pages = TrackMix.detailPages(of: lane.id, selectedRegion: selected, in: doc,
                                                     voiceCapacity: capacity)
                    XCTAssertEqual(pages.contains(.notes),
                                   PartNoteEditor.editableRegion(selected, track: lane.id, in: doc) != nil,
                                   "Notes is offered exactly where the editor finds a part (#416)")
                    XCTAssertEqual(pages.contains(.automation),
                                   SongAutomationEdit.sounds(on: lane.id, in: doc, voiceCapacity: capacity),
                                   "Automation is offered exactly where the curve sounds (#416)")
                    XCTAssertEqual(pages.filter { $0 != .notes && $0 != .automation },
                                   TrackMix.inspectorPages(of: lane.id, in: doc),
                                   "Track, Part and Device keep their one rule")
                    XCTAssertEqual(pages.last, .device, "Device closes the control on every track")
                }
            }
        }

        XCTAssertEqual(TrackInspectorPage.shown(.notes, offered: [.track, .part, .device]), .track,
                       "Notes chosen, no editable part: Track, never an empty box")
        XCTAssertEqual(TrackInspectorPage.shown(.automation, offered: [.track, .device]), .track)

        let selection = WorkstationSelection()
        XCTAssertFalse(selection.notesOpen)
        selection.setNotesOpen(true)
        XCTAssertEqual(selection.inspectorPage, .notes, "opening the notes IS the Notes page")
        XCTAssertTrue(selection.notesOpen)
        selection.setNotesOpen(false)
        XCTAssertEqual(selection.inspectorPage, .track, "closing the notes falls back to Track")
        XCTAssertFalse(selection.notesOpen)
        selection.showInspectorPage(.automation)
        XCTAssertFalse(selection.notesOpen, "one fact: another page means the notes are not open")
        selection.setNotesOpen(false)
        XCTAssertEqual(selection.inspectorPage, .automation, "closing notes that are not open moves nothing")
        selection.showInspectorPage(.notes)
        XCTAssertTrue(selection.notesOpen, "the page control opens the notes too")
    }

    // MARK: 2 — SOURCE: one segmented control, one page at a time

    func testTheInspectorDrawsOnePageAtATime() throws {
        let code = SourceText.codeOnly(try text(Self.inspectorPath))
        let body = try member("var body: some View {", in: code)

        XCTAssertTrue(body.contains("let pages = TrackMix.detailPages(of: laneID, selectedRegion: selection.regionID, in: document,"),
                      "the detail's pages follow the selected part (S4a)")
        XCTAssertFalse(body.contains("TrackMix.inspectorPages("),
                       "the body asks for the detail's pages, never the inspector's three alone")
        XCTAssertTrue(body.contains("let page = TrackInspectorPage.shown(selection.inspectorPage, offered: pages)"))
        XCTAssertEqual(occurrences("selection.inspectorPage", in: body), 1,
                       "the body reads the choice once, through `shown`")
        XCTAssertTrue(code.contains("@Environment(WorkstationSelection.self) private var selection"),
                      "the inspector reads the ONE owner")

        XCTAssertTrue(body.contains("Picker(\"Inspector\", selection: Binding<TrackInspectorPage>("))
        XCTAssertTrue(body.contains(".pickerStyle(.segmented)"),
                      "segmented: no popover for a re-render to tear down")
        XCTAssertEqual(occurrences("Picker(", in: body), 1, "one page control; the menus live in members")
        XCTAssertTrue(body.contains("Text(\"Track\").tag(TrackInspectorPage.track)"))
        XCTAssertTrue(body.contains("Text(\"Device\").tag(TrackInspectorPage.device)"))
        let partGate = try member("if pages.contains(.part) {", in: body)
        XCTAssertTrue(partGate.contains("Text(\"Part\").tag(TrackInspectorPage.part)"),
                      "the Part segment exists only where the page does")
        let notesGate = try member("if pages.contains(.notes) {", in: body)
        XCTAssertTrue(notesGate.contains("Text(\"Notes\").tag(TrackInspectorPage.notes)"),
                      "the Notes segment exists only where the page does")
        let automationGate = try member("if pages.contains(.automation) {", in: body)
        XCTAssertTrue(automationGate.contains("Text(\"Automation\").tag(TrackInspectorPage.automation)"),
                      "the Automation segment exists only where the page does")
        for segment in ["TrackInspectorPage.track)", "TrackInspectorPage.part)", "TrackInspectorPage.notes)",
                        "TrackInspectorPage.automation)", "TrackInspectorPage.device)"] {
            XCTAssertEqual(occurrences(".tag(" + segment, in: body), 1, "one segment per page: \(segment)")
        }
        guard let part = body.range(of: ".tag(TrackInspectorPage.part)"),
              let notes = body.range(of: ".tag(TrackInspectorPage.notes)"),
              let automation = body.range(of: ".tag(TrackInspectorPage.automation)"),
              let device = body.range(of: ".tag(TrackInspectorPage.device)") else {
            XCTFail("ANCHOR MISSING: the five segments (#454)")
            throw AnchorMissing()
        }
        XCTAssertTrue(part.lowerBound < notes.lowerBound && notes.lowerBound < automation.lowerBound
                      && automation.lowerBound < device.lowerBound,
                      "the segments read in the pages' order: Part · Notes · Automation · Device")

        guard let setter = body.range(of: "set: { picked in"),
              let write = body.range(of: "selection.showInspectorPage(picked)", range: setter.upperBound..<body.endIndex) else {
            XCTFail("ANCHOR MISSING: the page control's setter (#454)")
            throw AnchorMissing()
        }
        XCTAssertTrue(body[setter.upperBound..<write.lowerBound].contains("commitName()"),
                      "a typed name is stored before its page leaves the screen")

        let pages: [(gate: String, rows: [String])] = [
            ("if page == .device {", ["TrackMix.deviceName(controls.role)", "openDeviceButton",
                                     "instrumentRow(instruments)", "EchoelInstanceLine()",
                                     "echoelGenreRow", "echoelEffectRow", "effectRow",
                                     // GMMW GA-1 — the rack track's Compose here rows.
                                     "TrackComposeRows(laneID: laneID)"]),
            ("if page == .track {", ["TextField(\"Track name\"", "label: \"Level\"", "label: \"Pan\"",
                                    "trackRows", "removeRow(removal)"]),
            ("if page == .part {", ["TrackPartsView(laneID: laneID)", "partRows"]),
            ("if page == .notes {", ["PartNoteEditor(voiceCapacity: player.laneVoiceCapacity)"]),
            ("if page == .automation {",
             ["SongAutomationEditor(songTicks: ArrangementStrip.songTicks(WorkstationSummary(document: document)))"]),
        ]
        for (gate, rows) in pages {
            XCTAssertEqual(occurrences(gate, in: body), 1, "one gate per page: \(gate)")
            let page = try member(gate, in: body)
            for row in rows {
                XCTAssertTrue(page.contains(row), "\(row) lost its page (\(gate))")
                XCTAssertEqual(occurrences(row, in: body), 1, "\(row) is drawn once — on its page")
            }
        }
    }

    // MARK: 2b — SOURCE: the open track's own rows sit on its pages (S4b)

    /// Until S4b the record arm, an audio track's Pitch and its files' tempo were three loose rows
    /// UNDER the detail, visible whatever page was chosen. They are now rows of the detail: the
    /// Workstation still builds them (they read its transport and measuring state) and hands them
    /// to the inspector, which places the arm and Pitch on the Track page and the tempo rows on
    /// the Part page. The risk is a row built but never placed, or placed on a page its track
    /// never offers: Track exists on every track, and the tempo rows exist only on a non-bio
    /// audio track, where `TrackParts.arrangeable` offers Part.
    func testTheOpenTracksRowsSitOnItsPages() throws {
        let inspector = SourceText.codeOnly(try text(Self.inspectorPath))
        XCTAssertTrue(inspector.contains("struct TrackInspectorView<TrackRows: View, PartRows: View>: View {"))
        XCTAssertTrue(inspector.contains("init(laneID: UUID, @ViewBuilder trackRows: () -> TrackRows, @ViewBuilder part partRows: () -> PartRows) {"))
        XCTAssertTrue(inspector.contains("self.trackRows = trackRows()"))
        XCTAssertTrue(inspector.contains("self.partRows = partRows()"))

        let workstation = SourceText.codeOnly(try text(Self.workstationPath))
        guard let open = workstation.range(of: "TrackInspectorView(laneID: row.id) {"),
              let split = workstation.range(of: "} part: {", range: open.upperBound..<workstation.endIndex),
              let close = workstation.range(of: ".id(row.id)", range: split.upperBound..<workstation.endIndex) else {
            XCTFail("ANCHOR MISSING: the inspector's two row closures in the Workstation (#454)")
            throw AnchorMissing()
        }
        let trackRows = String(workstation[open.upperBound..<split.lowerBound])
        let partRows = String(workstation[split.upperBound..<close.lowerBound])
        XCTAssertTrue(trackRows.contains("TrackArmToggle(laneID: row.id)"), "the record arm is a Track-page row")
        XCTAssertTrue(trackRows.contains("if row.kind == .audio { pitchField(row) }"), "an audio track's Pitch is a Track-page row")
        XCTAssertFalse(trackRows.contains("partTempoRows("), "a file's tempo is not a Track-page row")
        XCTAssertTrue(partRows.contains("if row.kind == .audio { partTempoRows(laneID: row.id) }"),
                      "each imported file's tempo is a Part-page row")
        XCTAssertFalse(partRows.contains("TrackArmToggle("), "the arm is not a Part-page row")
        XCTAssertFalse(partRows.contains("pitchField("), "Pitch is not a Part-page row")

        // The Part page exists on every non-bio audio track — the only place the tempo rows exist.
        let audio = TimelineLane(name: "Audio", kind: .audio)
        let doc = TimelineDocument(lanes: [audio], regions: [])
        XCTAssertTrue(TrackMix.inspectorPages(of: audio.id, in: doc).contains(.part),
                      "an audio track offers the Part page its tempo rows sit on")
    }

    // MARK: 2c — SOURCE: the note tools wrap in the narrow detail column (S4a review, MEDIUM)

    func testTheNoteToolsWrapInsteadOfTruncating() throws {
        let notes = SourceText.codeOnly(try text(Self.notesPath))
        XCTAssertTrue(notes.contains("private struct NoteToolFlow: Layout {"),
                      "the wrapping layout the note tools stand in")
        // The four tool rows (Transpose · key · Quantize/Duplicate · Lower/Higher/Delete/Deselect).
        let tools = try member("private func selectionControls(", in: notes)
        let controls = try member("private func controls(range:", in: notes)
        XCTAssertEqual(occurrences("NoteToolFlow(spacing: EchoelTheme.spaceS) {", in: tools), 3,
                       "Transpose, key and Quantize rows wrap")
        XCTAssertEqual(occurrences("NoteToolFlow(spacing: EchoelTheme.spaceS) {", in: controls), 1,
                       "the octave/Delete/Deselect row wraps")
        // Any `HStack(` — not one spacing spelling: F2 moved the rows onto `EchoelTheme.spaceS`,
        // and a needle naming the old literal would have passed for every one-line row since.
        XCTAssertFalse(tools.contains("HStack(") || controls.contains("HStack("),
                       "a tool row is a one-line HStack again — in the 260-pt landscape column it truncates")
        // The layout measures IDEAL sizes. A row that could shrink would always "fit" and never
        // wrap (the BioStripView lesson): no scale factor anywhere in the editor.
        let flow = try member("private struct NoteToolFlow: Layout {", in: notes)
        XCTAssertTrue(flow.contains("subviews[index].sizeThatFits(.unspecified)"), "rows are built from ideal widths")
        XCTAssertFalse(notes.contains("minimumScaleFactor"), "a shrinking label would defeat the wrap")
    }

    // MARK: 3 — SOURCE: the choice is view state on the one owner

    func testTheChoiceIsViewStateOnTheOneOwner() throws {
        let owner = SourceText.codeOnly(try text(Self.ownerPath))
        XCTAssertTrue(owner.contains("public private(set) var inspectorPage: TrackInspectorPage = .track"))
        XCTAssertTrue(owner.contains("public func showInspectorPage(_ page: TrackInspectorPage) {"))
        XCTAssertTrue(owner.contains("offered.contains(chosen) ? chosen : .track"),
                      "one fallback rule, on the type")
        XCTAssertFalse(owner.contains("Codable"), "the selection is never persisted")
        XCTAssertFalse(owner.contains("UserDefaults"), "the selection is never persisted")
        XCTAssertTrue(owner.contains("public var notesOpen: Bool { inspectorPage == .notes }"),
                      "whether the notes are open is READ off the page — one fact, not two (S4a)")
        XCTAssertFalse(owner.contains("var notesOpen = "), "no stored notes flag beside the page")
        XCTAssertFalse(owner.contains("notesOpen = "), "nothing writes a notes flag — the page is the fact")

        let inspector = SourceText.codeOnly(try text(Self.inspectorPath))
        for forbidden in ["@AppStorage", "@SceneStorage", "UserDefaults", "@State private var page"] {
            XCTAssertFalse(inspector.contains(forbidden),
                           "\(forbidden): a second home for the page — the inspector is rebuilt per track")
        }

        XCTAssertEqual(try filesUnderSources(containing: "showInspectorPage("),
                       ["Studio/TrackInspectorView.swift", "Studio/WorkstationSelection.swift"],
                       "one caller (the page control) and the declaration")
        XCTAssertEqual(try filesUnderSources(containing: "inspectorPage = "),
                       ["Studio/WorkstationSelection.swift"], "one writer")
    }

    // MARK: 4 — COUNTERWEIGHTS: the neighbours keep their doors

    func testTheNeighboursKeepTheirDoors() throws {
        let inspector = SourceText.codeOnly(try text(Self.inspectorPath))
        XCTAssertFalse(inspector.contains("Shows this track, its parts or the device that plays it"),
                       "the hint names every page it can show")
        for modal in [".sheet(", ".fullScreenCover(", ".popover(", ".alert(", ".confirmationDialog("] {
            XCTAssertFalse(inspector.contains(modal), "\(modal): the pages are inline, never a modal")
        }
        for hot in ["isPlaying", "currentTick", "latestBio", "masterLevel", "TimelineView(",
                    "CameraRPPGBioPublisher"] {
            XCTAssertFalse(inspector.contains(hot), "\(hot): a hot read rebuilds the menus above")
        }
        XCTAssertTrue(inspector.contains(".onDisappear { commitName() }"), "the name commits on close")
        let appear = try member(".onAppear {", in: inspector)
        XCTAssertTrue(appear.contains("TrackMix.requestEchoelInstanceIfMissing("),
                      "the instance request does not wait for the Device page")

        let workstation = SourceText.codeOnly(try text(Self.workstationPath))
        for editor in ["PartNoteEditor(", "SongAutomationEditor("] {
            XCTAssertFalse(workstation.contains(editor),
                           "\(editor): the editor lives on its page of the detail, never a second time under the canvas")
            XCTAssertEqual(try filesUnderSources(containing: editor),
                           ["Studio/TrackInspectorView.swift"], "\(editor) is mounted on its page only")
        }
        let notesEditor = try member("struct PartNoteEditor: View {",
                                     in: SourceText.codeOnly(try text(Self.notesPath)))
        let automationEditor = try member("struct SongAutomationEditor: View {",
                                          in: SourceText.codeOnly(try text(Self.automationPath)))
        for (editor, gone) in [(notesEditor, "setNotesOpen("), (notesEditor, "Button"),
                               (automationEditor, "@State private var isOpen"), (automationEditor, "Button")] {
            XCTAssertFalse(editor.contains(gone),
                           "\(gone): the page is the switch — the editor keeps no switch of its own")
        }
        for door in ["TrackInspectorView(laneID: row.id)", "SelectedPartBar(playFrom:",
                     "TrackArmToggle(laneID: row.id)", "pitchField(row)", "partTempoRows(laneID: row.id)"] {
            XCTAssertEqual(occurrences(door, in: workstation), 1, "\(door) is still mounted once")
        }
        let parts = SourceText.codeOnly(try text(Self.partsViewPath))
        XCTAssertTrue(parts.contains("if TrackParts.arrangeable(laneID, in: document) {"),
                      "TrackPartsView keeps its own gate — the Part page relies on the same rule")

        let strings = try catalogStrings()
        for key in ["Track", "Part", "Notes", "Automation", "Device", "Inspector",
                    "Shows this track, its parts, the selected part's notes, its automation or the device that plays it"] {
            XCTAssertEqual(englishValue(of: key, in: strings), key, "`\(key)` is an English-only catalog key")
        }
    }

    // MARK: helpers

    /// The brace-matched block that opens at `anchor` (#408), string-literal aware. A missed
    /// anchor fails AND throws (#926) — an empty slice would make every `contains` vacuous.
    private func member(_ anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor) else {
            XCTFail("ANCHOR MISSING: `\(anchor)` (#454)")
            throw AnchorMissing()
        }
        var depth = 0
        var inString = false
        var escaped = false
        var index = code.index(before: start.upperBound)
        while index < code.endIndex {
            let ch = code[index]
            if inString {
                if escaped { escaped = false } else if ch == "\\" { escaped = true } else if ch == "\"" { inString = false }
            } else if ch == "\"" {
                inString = true
            } else if ch == "{" {
                depth += 1
            } else if ch == "}" {
                depth -= 1
                if depth == 0 { return String(code[start.lowerBound...index]) }
            }
            index = code.index(after: index)
        }
        XCTFail("ANCHOR MISSING: no closing brace after `\(anchor)` (#454)")
        throw AnchorMissing()
    }

    private func occurrences(_ needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    private func repoRoot() -> URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return root
    }

    private func text(_ relativePath: String) throws -> String {
        try String(contentsOf: repoRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }

    /// Swift files under `Sources/Echoelmusic` whose CODE (comments blanked) contains `needle`,
    /// as "<dir>/<file>" paths, sorted.
    private func filesUnderSources(containing needle: String) throws -> [String] {
        let root = repoRoot().appendingPathComponent(Self.sourcesRoot)
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            XCTFail("ANCHOR MISSING: cannot walk \(Self.sourcesRoot) (#454)")
            throw AnchorMissing()
        }
        var seen = 0
        var hits: [String] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            seen += 1
            let code = SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
            if code.contains(needle) {
                hits.append(url.pathComponents.suffix(2).joined(separator: "/"))
            }
        }
        XCTAssertGreaterThan(seen, 200, "the walk saw too few files to mean anything — a parser that matches nothing is a finding")
        return hits.sorted()
    }

    private func catalogStrings() throws -> [String: Any] {
        let data = try Data(contentsOf: repoRoot().appendingPathComponent(Self.catalogPath))
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = object["strings"] as? [String: Any] else {
            XCTFail("ANCHOR MISSING: Localizable.xcstrings is not the JSON shape this guard reads (#454)")
            throw AnchorMissing()
        }
        return strings
    }

    /// The `en` value of `key` — nil when the key is missing or the entry still carries a second
    /// language. The app speaks one language since 2026-10-02 (founder: "Nur Englisch"); this helper
    /// read the `de` unit until then.
    private func englishValue(of key: String, in strings: [String: Any]) -> String? {
        let entry = strings[key] as? [String: Any]
        let localizations = entry?["localizations"] as? [String: Any] ?? [:]
        guard Set(localizations.keys) == ["en"] else { return nil }
        let en = localizations["en"] as? [String: Any]
        let unit = en?["stringUnit"] as? [String: Any]
        return unit?["value"] as? String
    }
}
