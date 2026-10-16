// TheTrackColourIsThePersonsChoiceTests.swift
// A4b (founder 2026-10-16, gap list item 4 "Spuren umsortieren + Farbe", the colour half): a
// track can wear a colour the person chose. The Track page of the inspector has a "Colour" menu
// (Automatic or one of seven track hues); the canvas head, the parts, the mixer strip and the
// audio editor wear the choice. Before, the colour came from the instrument alone.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claims 1–3 are END-TO-END on shipped types: the hue rule, the lane's Codable round trip (an
//     older song, an unknown colour, no colour writing no key), the store writer, and
//     `structurallyEqual` ignoring the colour (a recolour re-attacks nothing).
//   · Claim 4 is a SOURCE-TEXT SCAN: every hue call site passes the lane's choice, the menu is
//     mounted on the Track page, and the store is its one writer.
//   · NOT CLAIMED (DEVICE PROBE): how the colours read. NEEDS-FOUNDER-VERIFY (A4b) — the probe is
//     at `TrackColorRow.swift`'s head.
//
// HONEST GRADING against the parent (§3): the file does not compile there (`TrackColor`,
// `TimelineLane.color`, `setLaneColor`, `TrackColorRow` are new), so no assertion has a verdict
// on the parent. Hand-transcribed: claims 1–3 are the CAPABILITY plus COUNTERWEIGHTS (the bio track
// keeps the body's green; an older song decodes and saves without a `color` key; an unknown colour
// keeps the track; a recolour is not structural); claim 4 is a FORWARD guard. Mutants: the choice
// ignored (1) · green offered (1) · the bio track recoloured (1, 3) · `color` always encoded (2) ·
// an unknown colour drops the lane (2) · colour counted as structural (3) · a call site that
// forgets the choice (4).

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheTrackColourIsThePersonsChoiceTests: XCTestCase {

    // MARK: 1 — the choice wins, except on the bio track

    func testTheChosenColourWinsExceptOnTheBioTrack() {
        typealias Hue = EchoelTheme.TrackHue
        XCTAssertEqual(Hue.of(kind: .midi, instrument: .polySynth, isBio: false, color: nil), .synth,
                       "no choice = the instrument's colour, as before")
        XCTAssertEqual(Hue.of(kind: .midi, instrument: .polySynth, isBio: false, color: .orchid), .visual)
        XCTAssertEqual(Hue.of(kind: .audio, instrument: nil, isBio: true, color: .orchid), .body,
                       "the bio track keeps the body's colour")
        let chosen = Set(TrackColor.allCases.map(Hue.chosen))
        XCTAssertEqual(chosen.count, TrackColor.allCases.count, "every colour is a different hue")
        XCTAssertFalse(chosen.contains(.body), "the body's green is never offered")
    }

    // MARK: 2 — the lane carries it, and an older song is unchanged

    func testTheLaneCarriesTheColourAndAnOlderSongIsUnchanged() throws {
        var lane = TimelineLane(name: "Lead", kind: .midi, builtinInstrument: .polySynth)
        XCTAssertNil(lane.color, "a new track has no chosen colour")
        let plain = String(decoding: try JSONEncoder().encode(lane), as: UTF8.self)
        XCTAssertFalse(plain.contains("\"color\""), "no choice writes no key — a song saves as before")
        lane.color = .terracotta
        let back = try JSONDecoder().decode(TimelineLane.self, from: JSONEncoder().encode(lane))
        XCTAssertEqual(back.color, .terracotta, "the choice survives a save")
        let unknown = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"Pad","kind":"midi","color":"neon"}"#
        let kept = try JSONDecoder().decode(TimelineLane.self, from: Data(unknown.utf8))
        XCTAssertEqual(kept.name, "Pad", "an unknown colour keeps the track")
        XCTAssertNil(kept.color, "and reads as the instrument's colour")
    }

    // MARK: 3 — one writer, no structural change

    func testSetLaneColorWritesTheChoiceAndChangesNothingThatSounds() {
        let timeline = TimelineStore()
        let original = timeline.document
        defer { timeline.replaceDocument(original) }
        let lead = TimelineLane(name: "Lead", kind: .midi, builtinInstrument: .polySynth)
        let body = TimelineLane(name: "Body", kind: .audio, isBio: true)
        timeline.replaceDocument(TimelineDocument(lanes: [lead, body], regions: []))
        let before = timeline.document
        timeline.setLaneColor(id: lead.id, .slate)
        XCTAssertEqual(timeline.document.lanes.first?.color, .slate)
        XCTAssertTrue(TimelineDocument.structurallyEqual(before, timeline.document),
                      "a recolour is not structural — the player re-attacks nothing")
        timeline.setLaneColor(id: body.id, .slate)
        XCTAssertNil(timeline.document.lanes.last?.color, "the bio track cannot be recoloured")
        timeline.setLaneColor(id: lead.id, nil)
        XCTAssertNil(timeline.document.lanes.first?.color, "Automatic clears the choice")
    }

    // MARK: 4 — every hue site passes the choice; the menu and its writer

    func testEveryHueSitePassesTheChoiceAndTheMenuIsOnTheTrackPage() throws {
        for (file, needle) in [
            ("ArrangeCanvasView", "isBio: row.isBio, color: row.color)"),
            ("WorkstationView", "isBio: row.isBio, color: row.color)"),
            ("PieceMixerView", "isBio: lane.isBio, color: lane.color)"),
            ("AudioPartEditorView", "isBio: lane.isBio, color: lane.color)"),
        ] {
            let code = try source("Sources/Echoelmusic/Studio/\(file).swift")
            XCTAssertTrue(code.contains(needle), "\(file) passes the track's chosen colour")
        }
        let summary = try source("Sources/Echoelmusic/Studio/WorkstationSummary.swift")
        XCTAssertTrue(summary.contains("color: lane.color,"), "the canvas rows carry the choice")
        let inspector = try source("Sources/Echoelmusic/Studio/TrackInspectorView.swift")
        XCTAssertEqual(inspector.components(separatedBy: "TrackColorRow(laneID: laneID)").count - 1, 1, "one mount")
        let row = try source("Sources/Echoelmusic/Studio/TrackColorRow.swift")
        XCTAssertTrue(row.contains("timeline.setLaneColor(id: laneID, $0)"))
        XCTAssertTrue(row.contains(".pickerStyle(.menu)"), "a named choice is a menu, not a number field")
        let store = try source("Sources/Echoelmusic/Core/TimelineStore.swift")
        XCTAssertEqual(store.components(separatedBy: "].color = ").count - 1, 1, "one writer of the colour")
        let doc = try source("Sources/Echoelmusic/Sequencer/Timeline.swift")
        XCTAssertTrue(doc.contains("n.color = lb.color"), "structurallyEqual leaves the colour out")
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
