// APartCarriesTheNameThePersonGaveItTests.swift
// A8 (founder 2026-10-16, "Arrangement auf Ableton-Level"): a part can be named. The Part page of a
// track's inspector opens on a Name field for the selected part; the canvas block wears the name
// (`ArrangeCanvas.partName`, A1b). Before, the canvas showed a name nobody could write.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claims 1–2 are END-TO-END on shipped types: which clip a part names, how many parts share
//     it, what a typed name stores, and the store writer through the real `ClipStore`.
//   · Claim 3 is a SOURCE-TEXT SCAN: the field is mounted once, on the Part page, writes through
//     the one writer, and commits on Return / focus loss / leaving — never per keystroke.
//   · NOT CLAIMED (DEVICE PROBE): typing and reading. NEEDS-FOUNDER-VERIFY (A8) — the probe is at
//     `PartNameField.swift`'s head.
//
// HONEST GRADING against the parent (§3): the file does not compile there (`PartName`,
// `renameClip`, `PartNameField` are new), so no assertion has a verdict on the parent.
// Hand-transcribed: claims 1–2 are the CAPABILITY plus COUNTERWEIGHTS (a part on another track
// names nothing; an empty name is refused; an unchanged name writes nothing; an unknown clip writes
// nothing; a copy shares the name); claim 3 is a FORWARD guard. Mutants: the lane check dropped (1)
// · an empty name stored (1) · no cap (1) · `renameClip` writes an unchanged name (2) · the field
// writing per keystroke (3) · a second mount (3).

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class APartCarriesTheNameThePersonGaveItTests: XCTestCase {

    // MARK: 1 — which clip a part names, and what a typed name stores

    func testAPartNamesItsClipAndATypedNameIsTrimmedAndCapped() {
        let bar = TimelineTime.ticksPerBar
        let lead = TimelineLane(name: "Lead", kind: .midi)
        let bass = TimelineLane(name: "Bass", kind: .midi)
        let clipID = UUID()
        let part = TimelineRegion(laneID: lead.id, clipID: clipID, startTick: 0, lengthTicks: bar)
        let copy = part.duplicated(atStartTick: bar)
        let other = TimelineRegion(laneID: bass.id, clipID: UUID(), startTick: 0, lengthTicks: bar)
        let document = TimelineDocument(lanes: [lead, bass], regions: [part, copy, other])
        XCTAssertEqual(PartName.clipID(of: part.id, onLane: lead.id, in: document), clipID)
        XCTAssertNil(PartName.clipID(of: other.id, onLane: lead.id, in: document),
                     "a part selected on another track names nothing here")
        XCTAssertNil(PartName.clipID(of: nil, onLane: lead.id, in: document))
        XCTAssertEqual(PartName.sharingCount(clipID, in: document), 2, "a copy plays the same clip")
        XCTAssertEqual(PartName.sharingCount(other.clipID, in: document), 1)
        XCTAssertEqual(PartName.stored("  Verse \n"), "Verse")
        XCTAssertNil(PartName.stored("   "), "an empty name is refused, like a track's")
        XCTAssertEqual(PartName.stored(String(repeating: "a", count: 200))?.count, PartName.maxLength)
    }

    // MARK: 2 — the one writer

    func testRenameClipWritesOnlyAChangedNameOfAKnownClip() {
        let clips = ClipStore()
        let originalSlots = clips.slots
        defer { clips.replaceSlots(originalSlots) }
        let clip = Clip(name: "Part 1", kind: .midi)
        var grid = [Clip?](repeating: nil, count: ClipStore.slotCount)
        grid[3] = clip
        XCTAssertTrue(clips.replaceSlots(grid), "fixture premise: the grid takes the clip")
        XCTAssertTrue(clips.renameClip(id: clip.id, to: "Verse"))
        XCTAssertEqual(clips.clip(id: clip.id)?.name, "Verse")
        XCTAssertEqual(clips.slots.firstIndex { $0?.id == clip.id }, 3, "the clip keeps its slot")
        XCTAssertFalse(clips.renameClip(id: clip.id, to: "Verse"), "an unchanged name writes nothing")
        XCTAssertFalse(clips.renameClip(id: UUID(), to: "Drop"), "an unknown clip writes nothing")
        XCTAssertEqual(ArrangeCanvas.partName(clips.clip(id: clip.id)), "Verse", "the canvas wears it")
    }

    // MARK: 3 — the field on the Part page

    func testTheNameFieldSitsOnThePartPageAndCommitsOnce() throws {
        let inspector = try source("Sources/Echoelmusic/Studio/TrackInspectorView.swift")
        XCTAssertEqual(inspector.components(separatedBy: "PartNameField(laneID: laneID)").count - 1, 1, "one mount")
        let partPage = try XCTUnwrap(inspector.range(of: "if page == .part {"))
        let notesPage = try XCTUnwrap(inspector.range(of: "if page == .notes {"))
        let mount = try XCTUnwrap(inspector.range(of: "PartNameField(laneID: laneID)"))
        XCTAssertTrue(partPage.upperBound <= mount.lowerBound && mount.upperBound <= notesPage.lowerBound,
                      "the field is on the Part page")
        let field = try source("Sources/Echoelmusic/Studio/PartNameField.swift")
        XCTAssertEqual(field.components(separatedBy: "clipStore.renameClip(").count - 1, 1, "one write site")
        XCTAssertTrue(field.contains(".onSubmit { commit() }"))
        XCTAssertTrue(field.contains("if !isFocused { commit() }"))
        XCTAssertTrue(field.contains(".onDisappear { commit() }"))
        XCTAssertFalse(field.contains(".onChange(of: draft"), "never a write per keystroke")
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
