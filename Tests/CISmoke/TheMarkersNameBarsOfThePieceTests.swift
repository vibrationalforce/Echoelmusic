// TheMarkersNameBarsOfThePieceTests.swift
// A5 (founder 2026-10-16, "einen einfachen Arrangement-Modus … auf Ableton-Level"): a piece
// carries markers — named bars, Live's locators. The transport row's Marker button adds one on
// the bar Play starts from, or removes the one there; the ruler draws them. Before, a piece had
// no way to name a place in it.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claims 1–3 are END-TO-END on shipped value types and the real store: the toggle rule, the
//     document's Codable round trip (an older song, a malformed marker, an empty list writing no
//     key), and `TimelineStore.toggleMarker` as ONE undo step.
//   · Claim 4 is a SOURCE-TEXT SCAN: the button sits in the transport row between Cycle and
//     Record, it is the one writer, and the ruler draws the document's markers.
//   · NOT CLAIMED (DEVICE PROBE): how the marks read on the ruler. NEEDS-FOUNDER-VERIFY (A5) —
//     the probe is written at `WorkstationMarkerToggle.swift`'s head.
//
// HONEST GRADING against the parent (§3): the file does not compile there (`TimelineMarker`,
// `markers`, `toggleMarker` and `WorkstationMarkerToggle` are new), so no assertion has a verdict
// on the parent. Hand-transcribed: claims 1 and 3 are the CAPABILITY; claim 2 is the
// COUNTERWEIGHT (an older song still decodes and still saves without a `markers` key, so A5 does
// not change a byte of any song that has none); claim 4 is a FORWARD guard. Mutants: no floor to
// the bar (1) · two markers on one bar (1) · `markers` always encoded (2) · a malformed marker
// throws the song (2) · two undo steps (3) · a second writer (4).

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheMarkersNameBarsOfThePieceTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar

    // MARK: 1 — one marker per bar, on the bar line

    func testATapAddsAMarkerOnTheBarAndASecondTapRemovesIt() {
        let bar = Self.bar
        XCTAssertEqual(TimelineMarker.barTick(4 * bar + 300), 4 * bar)
        XCTAssertEqual(TimelineMarker.barTick(-50), 0)
        let one = TimelineMarker.toggled([], atTick: 4 * bar + 300, name: "Marker 1")
        XCTAssertEqual(one.map(\.tick), [4 * bar], "a marker sits on the bar line, not mid-bar")
        XCTAssertEqual(one.first?.name, "Marker 1")
        let two = TimelineMarker.toggled(one, atTick: bar, name: "Marker 2")
        XCTAssertEqual(two.map(\.tick), [bar, 4 * bar], "sorted by bar")
        let back = TimelineMarker.toggled(two, atTick: 4 * bar + 1_000, name: "unused")
        XCTAssertEqual(back.map(\.tick), [bar], "a tap anywhere in a marked bar removes its marker — never a second one")
        XCTAssertEqual(MarkerChoice.marker(atTick: bar + 5, in: back)?.name, "Marker 2")
        XCTAssertNil(MarkerChoice.marker(atTick: 4 * bar, in: back))
        XCTAssertNotEqual(MarkerChoice.hint(hasMarkerHere: true), MarkerChoice.hint(hasMarkerHere: false))
        // C7: the next number is one past the highest in use — never a count, which repeats a name.
        let kept = [TimelineMarker(tick: 0, name: "Marker 1"), TimelineMarker(tick: bar, name: "Marker 3")]
        XCTAssertEqual(TimelineMarker.nextNumber(after: kept, prefix: "Marker "), 4,
                       "two markers, the highest Marker 3: the next is 4, not a second Marker 3")
        XCTAssertEqual(TimelineMarker.nextNumber(after: [], prefix: "Marker "), 1)
        let odd = [TimelineMarker(tick: 0, name: "Drop"), TimelineMarker(tick: bar, name: "Marker 99999999999")]
        XCTAssertEqual(TimelineMarker.nextNumber(after: odd, prefix: "Marker "), 1,
                       "a hand-named marker and an absurd number are ignored, the sum never overflows")
    }

    // MARK: 2 — the document carries them, and a song without any is unchanged

    func testTheDocumentCarriesMarkersAndAnOlderSongIsUnchanged() throws {
        let keys = TimelineLane(name: "Keys", kind: .midi)
        var doc = TimelineDocument(lanes: [keys], regions: [])
        XCTAssertEqual(doc.markers, [], "a new piece has no markers")
        let plain = String(decoding: try JSONEncoder().encode(doc), as: UTF8.self)
        XCTAssertFalse(plain.contains("\"markers\""), "an empty list writes no key — a song without markers saves as before")

        doc.markers = [TimelineMarker(tick: 8 * Self.bar, name: "Drop"), TimelineMarker(tick: 0, name: "Intro")]
        let decoded = try JSONDecoder().decode(TimelineDocument.self, from: JSONEncoder().encode(doc))
        XCTAssertEqual(decoded.markers.map(\.name), ["Intro", "Drop"], "markers survive a save, sorted by bar")

        let older = #"{"schemaVersion":1,"lanes":[],"regions":[],"automation":[]}"#
        XCTAssertEqual(try JSONDecoder().decode(TimelineDocument.self, from: Data(older.utf8)).markers, [],
                       "a song written before A5 decodes with none")
        let broken = #"{"schemaVersion":1,"lanes":[],"regions":[],"automation":[],"markers":[{"tick":"x"},{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","tick":1920,"name":"Verse"}]}"#
        let survived = try JSONDecoder().decode(TimelineDocument.self, from: Data(broken.utf8))
        XCTAssertEqual(survived.markers.map(\.name), ["Verse"], "a malformed marker is dropped, never the song")
    }

    // MARK: 3 — the store writes them as one undo step

    func testToggleMarkerIsOneUndoStep() {
        let timeline = TimelineStore()
        let original = timeline.document
        defer { timeline.replaceDocument(original) }
        timeline.replaceDocument(TimelineDocument(lanes: [TimelineLane(name: "Keys", kind: .midi)], regions: []))
        XCTAssertFalse(timeline.canUndo, "fixture premise: a fresh history")
        XCTAssertTrue(timeline.toggleMarker(atTick: 2 * Self.bar + 7))
        XCTAssertEqual(timeline.document.markers.map(\.tick), [2 * Self.bar])
        XCTAssertEqual(timeline.document.markers.first?.name, "Marker 1")
        XCTAssertTrue(timeline.canUndo)
        timeline.undo()
        XCTAssertEqual(timeline.document.markers, [], "ONE Undo takes the marker back")
        XCTAssertFalse(timeline.canUndo)
        timeline.redo()
        XCTAssertEqual(timeline.document.markers.map(\.tick), [2 * Self.bar], "and Redo restores it")
        XCTAssertFalse(timeline.toggleMarker(atTick: 2 * Self.bar), "a second tap on the bar removes it")
        XCTAssertEqual(timeline.document.markers, [])
        // C7 through the store: three markers, the middle one removed, the next is "Marker 4".
        for b in [0, 1, 2] { timeline.toggleMarker(atTick: b * Self.bar) }
        timeline.toggleMarker(atTick: Self.bar)
        XCTAssertEqual(timeline.document.markers.map(\.name), ["Marker 1", "Marker 3"])
        timeline.toggleMarker(atTick: 5 * Self.bar)
        XCTAssertEqual(timeline.document.markers.last?.name, "Marker 4", "a removal never hands its name on")
    }

    // MARK: 4 — the door, the one writer, the ruler

    func testTheButtonIsTheOneWriterAndTheRulerDrawsTheMarkers() throws {
        let view = try source("Sources/Echoelmusic/Studio/WorkstationView.swift")
        XCTAssertEqual(view.components(separatedBy: "WorkstationMarkerToggle()").count - 1, 1)
        guard let cycle = view.range(of: "WorkstationCycleToggle()"),
              let marker = view.range(of: "WorkstationMarkerToggle()", range: cycle.upperBound..<view.endIndex),
              view.range(of: "RecordTakeButton(", range: marker.upperBound..<view.endIndex) != nil else {
            return XCTFail("the Marker button is not mounted after Cycle and before Record (#408)")
        }
        let toggle = try source("Sources/Echoelmusic/Studio/WorkstationMarkerToggle.swift")
        XCTAssertTrue(toggle.contains("timeline.toggleMarker(atTick: start)"))
        XCTAssertTrue(toggle.contains("TimelineRegionPlayer.playStartTick(forCue: player.cueTick, in: document)"),
                      "the bar the ruler's line marks — never the playhead")
        XCTAssertFalse(toggle.contains("currentTick"), "cold: the playhead is a leaf of its own")
        XCTAssertFalse(toggle.contains("EchoelTheme.accent"), "never green — green is the body's signal")
        let writers = try filesUnderSources { $0.contains(".toggleMarker(") || $0.contains("document.markers =") }
        XCTAssertEqual(writers.sorted(), ["Core/TimelineStore.swift", "Studio/WorkstationMarkerToggle.swift"],
                       "the markers have one writer and one door")
        let ruler = try source("Sources/Echoelmusic/Studio/ArrangeRulerLocator.swift")
        XCTAssertTrue(ruler.contains("ForEach(document.markers) { marker in"), "the ruler draws the document's markers")
        XCTAssertEqual(ruler.components(separatedBy: ".onTapGesture(coordinateSpace: .local)").count - 1, 1,
                       "COUNTERWEIGHT: the ruler keeps its one tap; the marks take none")
    }

    // MARK: helpers

    private struct Unreadable: Error {}

    private func root() throws -> URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path)
        else { throw XCTSkip("source tree not present under \(root.path)") }
        return root
    }

    private func source(_ relativePath: String) throws -> String {
        guard let text = try? String(contentsOf: try root().appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw Unreadable()
        }
        return SourceText.codeOnly(text)
    }

    /// `Sources/Echoelmusic`-relative paths of every Swift file whose CODE satisfies `match`.
    private func filesUnderSources(_ match: (String) -> Bool) throws -> [String] {
        let base = try root().appendingPathComponent("Sources/Echoelmusic")
        guard let walker = FileManager.default.enumerator(atPath: base.path) else {
            throw XCTSkip("cannot walk Sources/Echoelmusic (#454)")
        }
        var hits: [String] = []
        for case let rel as String in walker where rel.hasSuffix(".swift") {
            if let text = try? String(contentsOf: base.appendingPathComponent(rel), encoding: .utf8),
               match(SourceText.codeOnly(text)) { hits.append(rel) }
        }
        return hits
    }
}
