// AnAudioPartHasItsOwnLevelTests.swift
// Echoel — the selected AUDIO part has its own level on the part bar (audio editor W2, founder
// 2026-10-08: "Die klassische DAW Audio Editing View fehlt mir noch.").
//
// WHY: `TimelineRegion.gain` is played (`AudioLanePlayer`: the part's gain rides on its track's)
// and exported with the piece (the export plays through the same engine), but nothing could set
// it — `TimelineStore.setRegionGain` had NO caller. A part that came in too loud stayed too loud,
// or the whole track had to come down with it.
//
// THE CLAIMS, AND WHICH KIND EACH IS (Tests/CISmoke/CLAUDE.md §1):
// 1. END-TO-END — `PartGain.gain`: an audio part's gain; nil for a MIDI part (its player never
//    reads a region's gain — a control there would move nothing, #164), a bio track's part, and a
//    part that is gone.
// 2. END-TO-END on the real store — the field's range IS the store's clamp (3 → the top, −1 → the
//    bottom, NaN → 1.00), one write is ONE undo step, and an unchanged write records nothing.
// 3. SOURCE-TEXT SCAN — the bar mounts the field only behind `PartGain.gain`, once; the leaf drags
//    a DRAFT and writes once on release through `setRegionGain`, clears the draft when the stored
//    level moves, reads in decibels by the track header's own rule, and uses no raw slider.
//    The leaf writes the level in exactly TWO places: the release, and since W9 Normalize
//    (`TheNormalizedPartReachesFullScaleTests` pins that one behind its off-main read).
// 4. SOURCE-TEXT SCAN (census) — the part bar is the one caller of `setRegionGain` in `Sources/`.
//
// GRADING (§0/§3, no Swift toolchain in a web session): the file names `PartGain`, which this
// commit creates, so it does NOT COMPILE against the parent — no assertion has a verdict there.
// Claim 1 re-derived by hand from the four document shapes; claim 2's store behaviour read off
// `setRegionGain` (`min(2, max(0, gain.isFinite ? gain : 1))`, a no-op guard before the snapshot)
// — the range half is a COUNTERWEIGHT on the store, green on both trees, and the point of the
// claim: a field range that drifts from the store's clamp would show a level the part never gets.
// Claims 3–4 are FORWARD guards (one absence on the parent, #486), transcribed in Python against
// the work tree. What the field feels like on glass, and that the change is heard within a step
// while the piece plays, is a DEVICE PROBE and open.

import XCTest
@testable import Echoelmusic

@MainActor
final class AnAudioPartHasItsOwnLevelTests: XCTestCase {

    private static let bar = "Sources/Echoelmusic/Studio/SelectedPartBar.swift"

    private var restore: [() -> Void] = []

    override func tearDown() async throws {
        for undo in restore.reversed() { undo() }
        restore.removeAll()
        try await super.tearDown()
    }

    // MARK: 1 — which parts have a level of their own

    func testOnlyAnAudioPartOffersItsOwnLevel() {
        let audio = TimelineLane(name: "Loop", kind: .audio)
        let keys = TimelineLane(name: "Keys", kind: .midi)
        let body = TimelineLane(name: "Body", kind: .audio, isBio: true)
        let loud = TimelineRegion(laneID: audio.id, clipID: UUID(), startTick: 0, lengthTicks: 1_920, gain: 0.5)
        let notes = TimelineRegion(laneID: keys.id, clipID: UUID(), startTick: 0, lengthTicks: 1_920, gain: 0.5)
        let curve = TimelineRegion(laneID: body.id, clipID: UUID(), startTick: 0, lengthTicks: 1_920)
        let document = TimelineDocument(lanes: [audio, keys, body], regions: [loud, notes, curve])
        XCTAssertEqual(PartGain.gain(of: loud.id, in: document), 0.5, "an audio part shows the gain it plays at")
        XCTAssertNil(PartGain.gain(of: notes.id, in: document),
                     "a MIDI part's player never reads a region's gain — a level there would move nothing")
        XCTAssertNil(PartGain.gain(of: curve.id, in: document), "a bio curve is not a part to mix")
        XCTAssertNil(PartGain.gain(of: UUID(), in: document), "a part that is gone has no level")
    }

    // MARK: 2 — the field's range is the store's clamp; one write, one undo step

    func testTheStoreClampsToTheFieldsRangeAndWritesOneStep() {
        let timeline = TimelineStore()
        let original = timeline.document
        restore.append { timeline.replaceDocument(original) }
        let audio = TimelineLane(name: "Loop", kind: .audio)
        let part = TimelineRegion(laneID: audio.id, clipID: UUID(), startTick: 0, lengthTicks: 1_920)
        timeline.replaceDocument(TimelineDocument(lanes: [audio], regions: [part]))
        func gain() -> Float? { timeline.document.regions.first { $0.id == part.id }?.gain }

        XCTAssertFalse(timeline.canUndo, "a replaced song starts with no history")
        timeline.setRegionGain(id: part.id, 0.5)
        XCTAssertEqual(gain(), 0.5)
        XCTAssertTrue(timeline.canUndo)
        timeline.undo()
        XCTAssertEqual(gain(), 1, "ONE undo step puts the part's level back")
        XCTAssertFalse(timeline.canUndo, "and it was exactly one")

        timeline.setRegionGain(id: part.id, 1)
        XCTAssertFalse(timeline.canUndo, "an unchanged level records nothing")

        timeline.setRegionGain(id: part.id, 3)
        XCTAssertEqual(gain().map { Double($0) }, PartGain.range.upperBound,
                       "the store's top is the field's top — the field never offers a level the part does not get")
        timeline.setRegionGain(id: part.id, -1)
        XCTAssertEqual(gain().map { Double($0) }, PartGain.range.lowerBound, "and its bottom")
        timeline.setRegionGain(id: part.id, .nan)
        XCTAssertEqual(gain(), 1, "a non-finite level falls back to the file as it is")
    }

    // MARK: 3 — the bar mounts the leaf; the leaf drags a draft and writes once

    func testTheFieldWritesOnceOnReleaseThroughTheStore() throws {
        let code = try source(Self.bar)
        guard let bodyStart = code.range(of: "var body: some View {"),
              let trims = code.range(of: "private struct Trims {", range: bodyStart.upperBound..<code.endIndex),
              let leaf = code.range(of: "private struct PartGainField: View {") else {
            return XCTFail("ANCHOR MISSING: the part bar's body or `PartGainField` (#454)")
        }
        let body = String(code[bodyStart.upperBound..<trims.lowerBound])
        guard let gate = body.range(of: "if let gain = PartGain.gain(of: regionID, in: document) {"),
              let mount = body.range(of: "PartGainField(regionID: regionID, gain: gain)") else {
            return XCTFail("the bar no longer mounts the field behind `PartGain.gain`")
        }
        XCTAssertLessThan(gate.lowerBound, mount.lowerBound, "the field appears only for a part that has a level")
        XCTAssertEqual(code.components(separatedBy: "PartGainField(").count - 1, 1, "mounted once")

        let field = String(code[leaf.upperBound...])
        guard let call = field.range(of: "EchoelValueField(label: \"Part level\","),
              let commit = field.range(of: "private func commitGain() {") else {
            return XCTFail("the leaf no longer offers \"Part level\" or no longer commits through `commitGain`")
        }
        let fieldCall = String(field[call.upperBound..<commit.lowerBound])
        for needle in ["value: Binding(get: { shownGain }, set: { draft = $0 }),",
                       "range: PartGain.range,",
                       "decimals: 2,",
                       "standard: 1,",
                       "onCommit: { commitGain() })",
                       ".onChange(of: gain) { _, _ in draft = nil }",
                       "Text(TrackMix.decibelText(shownGain))"] {
            XCTAssertTrue(fieldCall.contains(needle), "the field lost `\(needle)`")
        }
        XCTAssertFalse(fieldCall.contains("setRegionGain("),
                       "the drag writes a DRAFT — a write per step would stack an undo step per value crossed")
        XCTAssertFalse(fieldCall.contains("onChange:"),
                       "`onChange` fires per drag event — routed to the store, every value crossed is a write")
        let commitBody = String(field[commit.upperBound...])
        XCTAssertTrue(commitBody.contains("timeline.setRegionGain(id: regionID, Float(value))"),
                      "the release writes through the store's one region-gain writer")
        XCTAssertEqual(field.components(separatedBy: "setRegionGain(").count - 1, 2, """
            the leaf writes the part's level in exactly two places — the release of the drag, and \
            Normalize (W9). A third write in the leaf is a third gesture, and it needs its own claim.
            """)
        for banned in ["Slider(", "Stepper("] {
            XCTAssertFalse(field.contains(banned), "the leaf contains `\(banned)` — one control (`EchoelValueField`)")
        }
    }

    // MARK: 4 — one door to the writer

    func testThePartBarIsTheOneCallerOfTheRegionGainWriter() throws {
        let callers = try sourceFiles { $0.contains(".setRegionGain(") }
        XCTAssertEqual(callers, [Self.bar], """
            `setRegionGain` is called from \(callers). The part bar is its one door; a second \
            surface writing a part's level is a second editor of one value, and the one whose \
            undo the person did not expect.
            """)
    }

    // MARK: helpers

    private static var root: URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return root
    }

    private func source(_ relativePath: String) throws -> String {
        let text = try String(contentsOf: Self.root.appendingPathComponent(relativePath), encoding: .utf8)
        return SourceText.codeOnly(text)
    }

    /// The `Sources/` files whose code (comments stripped) satisfies `matches`, repo-relative, sorted.
    private func sourceFiles(_ matches: (String) -> Bool) throws -> [String] {
        let base = Self.root.appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(atPath: base.path) else {
            XCTFail("cannot enumerate Sources/ — a scan that saw nothing is not a pass")
            return []
        }
        var hits: [String] = []
        var seen = 0
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            seen += 1
            guard let text = try? String(contentsOf: base.appendingPathComponent(relative), encoding: .utf8) else {
                continue
            }
            if matches(SourceText.codeOnly(text)) { hits.append("Sources/" + relative) }
        }
        XCTAssertGreaterThan(seen, 200, "the walk saw \(seen) files — the wrong directory")
        return hits.sorted()
    }
}
