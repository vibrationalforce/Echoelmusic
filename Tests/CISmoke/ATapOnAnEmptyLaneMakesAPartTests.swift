// ATapOnAnEmptyLaneMakesAPartTests.swift
// A1 (founder 2026-10-16, "einen einfachen Arrangement-Modus der alles kann auf Ableton-Level"):
// every non-bio track is a lane on the canvas, the canvas runs past the song's end, and a tap on
// empty lane space makes an empty part on the bar under the finger — on THAT track, never moved
// to another. Before this, a track without parts had no lane at all, and a part could only be
// made with the "New MIDI Part" row, which lands after the lane's last part.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claims 1–3 are END-TO-END on shipped value types (`ArrangeCanvas.canvasTicks` /
//     `barTick`, `MIDIImport.planEmptyPart(onLane:atTick:)`) and on the two real stores
//     (`placeEmptyPart` — clip first, region second, ONE undo step).
//   · Claim 4 is a SOURCE-TEXT SCAN: the lane's tap calls `createPart`, and the Workstation
//     hands it to `placeEmptyPart` and opens the notes.
//   · NOT CLAIMED (DEVICE PROBE): that the tap on empty space does not also fire under a part
//     block (SwiftUI gives the topmost view the tap; the blocks sit above the background).
//     NEEDS-FOUNDER-VERIFY (A1): on an empty track, tap bar 3 — a 4-bar part appears there and
//     the note editor opens; tap an existing part — it is selected, no second part appears.
//
// HONEST GRADING against the parent (§3): the file does not compile there — `canvasTicks`,
// `barTick`, `takesEmptyPart`, `planEmptyPart(…onLane:atTick:…)` and `placeEmptyPart` are new,
// so no assertion has a verdict on the parent. Hand-transcribed: claims 1–2 are the CAPABILITY,
// claim 3's refusal half is the COUNTERWEIGHT (a tap on a voiceless or bio lane must not
// quietly put the part on the roll lane, as "New MIDI Part" does), claim 4 is a FORWARD guard.
// Mutants: no headroom (1) · tap not floored to the bar (1) · tap past the end not clamped (1) ·
// part moved to the roll lane (2) · region before clip (3) · two undo steps (3) · view calls
// `addEmptyPart` instead (4).

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class ATapOnAnEmptyLaneMakesAPartTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar

    // MARK: 1 — the canvas has room past the song, and a tap names a bar

    func testTheCanvasRunsPastTheSongAndATapNamesTheBarUnderTheFinger() {
        let bar = Self.bar
        XCTAssertEqual(ArrangeCanvas.canvasTicks(songTicks: 0), ArrangeCanvas.minimumBars * bar,
                       "an empty song is a timeline, not a sliver")
        XCTAssertEqual(ArrangeCanvas.canvasTicks(songTicks: 16 * bar), (16 + ArrangeCanvas.headroomBars) * bar,
                       "there is always open space after the last part")
        XCTAssertEqual(ArrangeCanvas.canvasTicks(songTicks: -5), ArrangeCanvas.minimumBars * bar)

        let song = 8 * bar
        XCTAssertEqual(ArrangeCanvas.barTick(atX: 0, laneWidth: 800, songTicks: song), 0)
        XCTAssertEqual(ArrangeCanvas.barTick(atX: 250, laneWidth: 800, songTicks: song), 2 * bar,
                       "a tap in bar 3 floors to bar 3's downbeat")
        XCTAssertEqual(ArrangeCanvas.barTick(atX: 2_000, laneWidth: 800, songTicks: song), 7 * bar,
                       "past the right edge is the last bar, never beyond the canvas")
        XCTAssertEqual(ArrangeCanvas.barTick(atX: -40, laneWidth: 800, songTicks: song), 0)
        XCTAssertNil(ArrangeCanvas.barTick(atX: 10, laneWidth: 0, songTicks: song))
        XCTAssertNil(ArrangeCanvas.barTick(atX: .nan, laneWidth: 800, songTicks: song))
        XCTAssertNil(ArrangeCanvas.barTick(atX: 10, laneWidth: 800, songTicks: 0))
    }

    // MARK: 2 — the part lands on THAT lane, on THAT bar

    func testATapPlacesAFourBarPartOnTheTappedLaneAtTheTappedBar() {
        let bio = TimelineLane(name: "Body", kind: .midi, isBio: true)
        let keys = TimelineLane(name: "Keys", kind: .midi)
        let doc = TimelineDocument(lanes: [bio, keys], regions: [])
        XCTAssertEqual(doc.rollLaneID, keys.id, "fixture premise: Keys is the roll lane")
        let slots = [Clip?](repeating: nil, count: ClipStore.slotCount)

        XCTAssertTrue(MIDIImport.takesEmptyPart(onLane: keys.id, in: doc, voiceCapacity: 0))
        guard case .success(let landing) = MIDIImport.planEmptyPart(document: doc, slots: slots,
                                                                    onLane: keys.id,
                                                                    atTick: 3 * Self.bar + 17,
                                                                    voiceCapacity: 0) else {
            return XCTFail("a tap on the roll lane must make a part")
        }
        XCTAssertEqual(landing.laneID, keys.id)
        XCTAssertEqual(landing.region.laneID, keys.id)
        XCTAssertEqual(landing.region.startTick, 3 * Self.bar, "floored to the tapped bar's downbeat")
        XCTAssertEqual(landing.region.lengthTicks, MIDIImport.emptyPartBars * Self.bar)
        XCTAssertEqual(landing.clip.kind, .midi)
        XCTAssertEqual(landing.region.clipID, landing.clip.id)
    }

    // MARK: 3 — refused where it would not play; the stores take it as one step

    func testARefusedLaneIsNeverSwappedAndThePlacementIsOneUndoStep() throws {
        let bio = TimelineLane(name: "Body", kind: .midi, isBio: true)
        let keys = TimelineLane(name: "Keys", kind: .midi)
        let lead = TimelineLane(name: "Lead", kind: .midi)
        let audio = TimelineLane(name: "Audio", kind: .audio)
        let doc = TimelineDocument(lanes: [bio, keys, lead, audio], regions: [])
        let slots = [Clip?](repeating: nil, count: ClipStore.slotCount)
        for refused in [bio.id, lead.id, audio.id] {
            XCTAssertFalse(MIDIImport.takesEmptyPart(onLane: refused, in: doc, voiceCapacity: 0))
            switch MIDIImport.planEmptyPart(document: doc, slots: slots, onLane: refused,
                                            atTick: 0, voiceCapacity: 0) {
            case .success(let landing):
                XCTFail("""
                    A tap on a lane the engine would not play landed on \(landing.laneID) — the \
                    part must never appear on a track the finger did not point at.
                    """)
            case .failure(let failure):
                XCTAssertEqual(failure, .noMIDILane)
            }
        }

        let timeline = TimelineStore()
        let clips = ClipStore()
        let originalDocument = timeline.document
        let originalSlots = clips.slots
        defer {
            clips.replaceSlots(originalSlots)
            timeline.replaceDocument(originalDocument)
        }
        XCTAssertTrue(clips.replaceSlots([Clip?](repeating: nil, count: ClipStore.slotCount)),
                      "fixture premise: an empty grid")
        timeline.replaceDocument(TimelineDocument(lanes: [keys], regions: []))
        XCTAssertFalse(timeline.canUndo, "fixture premise: a fresh history")
        guard case .success(let landing) = MIDIImport.placeEmptyPart(clipStore: clips, timeline: timeline,
                                                                    onLane: keys.id, atTick: 2 * Self.bar,
                                                                    voiceCapacity: 0) else {
            return XCTFail("the placement must land")
        }
        XCTAssertEqual(timeline.document.regions.map(\.id), [landing.region.id])
        XCTAssertEqual(clips.clip(id: landing.clip.id)?.kind, .midi, "the clip is in the grid")
        timeline.undo()
        XCTAssertTrue(timeline.document.regions.isEmpty, "ONE Undo takes the part back")
        XCTAssertFalse(timeline.canUndo)
    }

    // MARK: 4 — the lane's tap reaches the transaction and opens the notes

    func testTheLaneTapReachesThePlacementAndOpensTheNotes() throws {
        let canvas = try source("Sources/Echoelmusic/Studio/ArrangeCanvasView.swift")
        let view = try source("Sources/Echoelmusic/Studio/WorkstationView.swift")
        XCTAssertTrue(canvas.contains(".onTapGesture(coordinateSpace: .local) { location in"),
                      "the empty lane space takes a tap")
        XCTAssertTrue(canvas.contains("createPart(row.id, tick)"), "the tap names its own lane and bar")
        XCTAssertTrue(view.contains("createPart: { createPart(onLane: $0, atTick: $1) },"),
                      "the Workstation hands the canvas its placement")
        guard let start = view.range(of: "private func createPart(onLane laneID: UUID, atTick tick: Int) {"),
              let end = view.range(of: "private func newMIDIPart() {", range: start.upperBound..<view.endIndex) else {
            return XCTFail("ANCHOR MISSING: createPart(onLane:atTick:) (#408)")
        }
        let action = String(view[start.upperBound..<end.lowerBound])
        XCTAssertTrue(action.contains("MIDIImport.placeEmptyPart("), "the tap's own transaction")
        XCTAssertFalse(action.contains("MIDIImport.addEmptyPart("),
                       "\"New MIDI Part\" lands after the last part — the tap names a bar")
        XCTAssertTrue(action.contains("selection.setNotesOpen(true)"), "the new part opens for notes")
        XCTAssertTrue(action.contains("importNote = failure.userMessage"), "a refusal is said, not silent")
    }

    // MARK: helpers

    private struct Unreadable: Error {}

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path)
        else { throw XCTSkip("source tree not present under \(root.path)") }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw Unreadable()
        }
        return SourceText.codeOnly(text)
    }
}
