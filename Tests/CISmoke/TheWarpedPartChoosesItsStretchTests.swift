// TheWarpedPartChoosesItsStretchTests.swift
// Echoel — a WARPED audio part chooses how it keeps the song's tempo: Clean, Tape or Beats (audio
// editor W3, founder 2026-10-08: "Die klassische DAW Audio Editing View fehlt mir noch.").
//
// WHY: the timeline plays three stretch algorithms (`StretchMode.timelineCapabilities`) and every
// part persists one, but nothing could set it — `TimelineRegion.stretchMode` had no writer, so
// every warped part played Clean. Drums lost their attack under a stretch they could not leave.
//
// THE CLAIMS, AND WHICH KIND EACH IS (Tests/CISmoke/CLAUDE.md §1):
// 1. END-TO-END — `PartStretch.choices` is exactly the set the PLAYER renders as itself
//    (`StretchPlan.resolve` with the timeline's capabilities), in the enum's order: the bar can
//    never offer a mode the player would replace with Clean. Derived per case, never listed.
// 2. END-TO-END — `PartStretch.mode`: a warped audio part offers its mode; an unwarped part (rate
//    1, where all modes sound alike), a MIDI part, a bio part and a missing part offer none.
// 3. END-TO-END on the real store — one pick is ONE undo step; the same mode writes nothing; a mode
//    the timeline does not render is refused; the part's length and warp stay as they were, and
//    the engine's rate does not depend on the mode (the premise of "length untouched").
// 4. SOURCE-TEXT SCAN — the bar mounts the picker behind `PartStretch.mode`, once; the leaf is a
//    segmented `Picker` over `PartStretch.choices` whose one write is `setRegionStretchMode`; the
//    part bar is that writer's one caller.
// 5. COUNTERWEIGHTS (#343) — the player resolves each part's plan from ITS mode, and Join still
//    refuses two halves of different mode.
//
// GRADING (§0/§3, no Swift toolchain in a web session): the file names `PartStretch` and
// `setRegionStretchMode`, which this commit creates, so it does NOT COMPILE against the parent —
// no assertion has a verdict there. Claims 1–3 re-derived by hand from `StretchPlan.resolve`
// (capability ∧ implemented, else `.clean`; rate from warp + tempi only) and the setter; claim 4
// is a FORWARD guard (one absence on the parent, #486); claim 5 is green on both trees. How each
// mode SOUNDS on a real loop, and that Beats arrives on the part's next start, is a DEVICE PROBE
// and open.

import XCTest
import Foundation
@testable import Echoelmusic

@MainActor
final class TheWarpedPartChoosesItsStretchTests: XCTestCase {

    private static let bar = "Sources/Echoelmusic/Studio/SelectedPartBar.swift"

    private var restore: [() -> Void] = []

    override func tearDown() async throws {
        for undo in restore.reversed() { undo() }
        restore.removeAll()
        try await super.tearDown()
    }

    private static func rendered(_ mode: StretchMode) -> StretchMode {
        StretchPlan.resolve(mode: mode, warpEnabled: true, nativeBPM: 100, projectBPM: 120,
                            capabilities: StretchMode.timelineCapabilities).mode
    }

    // MARK: 1 — the bar offers what the player plays

    func testTheChoicesAreExactlyWhatThePlayerRendersAsItself() {
        let choices = PartStretch.choices
        XCTAssertFalse(choices.isEmpty, "no choice at all — an empty picker is a finding, never a pass (#454)")
        for mode in StretchMode.allCases {
            XCTAssertEqual(choices.contains(mode), Self.rendered(mode) == mode, """
                `\(mode)`: offered = \(choices.contains(mode)), but the player renders it as \
                `\(Self.rendered(mode))`. The bar must offer exactly the modes the timeline plays \
                as themselves — a mode it would quietly replace with Clean is a choice that lies.
                """)
        }
        XCTAssertEqual(choices, StretchMode.allCases.filter { choices.contains($0) }, "in the enum's order")
        XCTAssertTrue(choices.contains(.clean), "counterweight: the default is always a choice")
    }

    // MARK: 2 — which parts offer the choice

    func testOnlyAWarpedAudioPartOffersTheChoice() {
        let audio = TimelineLane(name: "Loop", kind: .audio)
        let keys = TimelineLane(name: "Keys", kind: .midi)
        let body = TimelineLane(name: "Body", kind: .audio, isBio: true)
        let warped = TimelineRegion(laneID: audio.id, clipID: UUID(), startTick: 0, lengthTicks: 7_680,
                                    warpEnabled: true, stretchMode: .tape)
        let unwarped = TimelineRegion(laneID: audio.id, clipID: UUID(), startTick: 7_680, lengthTicks: 7_680)
        let notes = TimelineRegion(laneID: keys.id, clipID: UUID(), startTick: 0, lengthTicks: 7_680,
                                   warpEnabled: true)
        let curve = TimelineRegion(laneID: body.id, clipID: UUID(), startTick: 0, lengthTicks: 7_680,
                                   warpEnabled: true)
        let document = TimelineDocument(lanes: [audio, keys, body], regions: [warped, unwarped, notes, curve])
        XCTAssertEqual(PartStretch.mode(of: warped.id, in: document), .tape, "a warped audio part shows its mode")
        XCTAssertNil(PartStretch.mode(of: unwarped.id, in: document),
                     "an unwarped part plays at rate 1, where every mode sounds the same — no choice (#164)")
        XCTAssertNil(PartStretch.mode(of: notes.id, in: document), "a MIDI part is not stretched")
        XCTAssertNil(PartStretch.mode(of: curve.id, in: document), "a bio curve is not stretched")
        XCTAssertNil(PartStretch.mode(of: UUID(), in: document), "a part that is gone offers nothing")
    }

    // MARK: 3 — the store: one step per pick, refuses what it cannot play, keeps the length

    func testOnePickIsOneUndoStepAndTheLengthStays() {
        let timeline = TimelineStore()
        let original = timeline.document
        restore.append { timeline.replaceDocument(original) }
        let audio = TimelineLane(name: "Loop", kind: .audio)
        let part = TimelineRegion(laneID: audio.id, clipID: UUID(), startTick: 0, lengthTicks: 7_680,
                                  warpEnabled: true)
        timeline.replaceDocument(TimelineDocument(lanes: [audio], regions: [part]))
        func stored() -> TimelineRegion? { timeline.document.regions.first { $0.id == part.id } }

        let other = PartStretch.choices.first { $0 != part.stretchMode }
        guard let pick = other else {
            return XCTFail("the timeline renders only one mode — there is nothing to choose (#454)")
        }
        XCTAssertFalse(timeline.canUndo, "a replaced song starts with no history")
        timeline.setRegionStretchMode(id: part.id, pick)
        XCTAssertEqual(stored()?.stretchMode, pick)
        XCTAssertEqual(stored()?.lengthTicks, part.lengthTicks, "the mode never resizes a part")
        XCTAssertEqual(stored()?.warpEnabled, true, "the mode never touches warp")
        XCTAssertTrue(timeline.canUndo)
        timeline.undo()
        XCTAssertEqual(stored()?.stretchMode, part.stretchMode, "ONE undo step puts the mode back")
        XCTAssertFalse(timeline.canUndo, "and it was exactly one")

        timeline.setRegionStretchMode(id: part.id, part.stretchMode)
        XCTAssertFalse(timeline.canUndo, "the same mode records nothing")
        timeline.setRegionStretchMode(id: UUID(), pick)
        XCTAssertFalse(timeline.canUndo, "a part that is gone records nothing")
        for refused in StretchMode.allCases where !PartStretch.choices.contains(refused) {
            timeline.setRegionStretchMode(id: part.id, refused)
            XCTAssertEqual(stored()?.stretchMode, part.stretchMode,
                           "`\(refused)` is not played by the timeline — the store must not keep it")
            XCTAssertFalse(timeline.canUndo, "`\(refused)`: a refused mode records nothing")
        }

        // The premise of "length untouched": the engine's rate does not depend on the mode.
        let rates = Set(StretchMode.allCases.map {
            StretchPlan.resolve(mode: $0, warpEnabled: true, nativeBPM: 100, projectBPM: 120,
                                capabilities: StretchMode.timelineCapabilities).rate
        })
        XCTAssertEqual(rates.count, 1, "the stretch RATE now depends on the mode — a pick would have to resize the part")
    }

    // MARK: 4 — the bar mounts the leaf; the leaf is a segmented picker with one write

    func testThePickerIsMountedOnceAndWritesThroughTheStore() throws {
        let code = try source(Self.bar)
        guard let bodyStart = code.range(of: "var body: some View {"),
              let trims = code.range(of: "private struct Trims {", range: bodyStart.upperBound..<code.endIndex),
              let leaf = code.range(of: "private struct PartStretchPicker: View {") else {
            return XCTFail("ANCHOR MISSING: the part bar's body or `PartStretchPicker` (#454)")
        }
        let body = String(code[bodyStart.upperBound..<trims.lowerBound])
        guard let gate = body.range(of: "if let stretch = PartStretch.mode(of: regionID, in: document) {"),
              let mount = body.range(of: "PartStretchPicker(regionID: regionID, mode: stretch)") else {
            return XCTFail("the bar no longer mounts the picker behind `PartStretch.mode`")
        }
        XCTAssertLessThan(gate.lowerBound, mount.lowerBound, "the choice appears only for a warped audio part")
        XCTAssertEqual(code.components(separatedBy: "PartStretchPicker(").count - 1, 1, "mounted once")

        let picker = String(code[leaf.upperBound...])
        for needle in ["selection: Binding(get: { mode },",
                       "set: { timeline.setRegionStretchMode(id: regionID, $0) })) {",
                       "ForEach(PartStretch.choices, id: \\.self) { choice in",
                       ".pickerStyle(.segmented)"] {
            XCTAssertTrue(picker.contains(needle), "the picker lost `\(needle)`")
        }
        XCTAssertEqual(picker.components(separatedBy: "setRegionStretchMode(").count - 1, 1, "one write, per pick")
        for banned in ["Slider(", "Stepper(", "EchoelValueField(", ".pickerStyle(.menu)", "player.", "clipStore"] {
            XCTAssertFalse(picker.contains(banned), """
                `PartStretchPicker` contains `\(banned)`. A named choice is a segmented `Picker` (the \
                UI law's word is NUMERIC), and the leaf reads nothing hot — the mode arrives cold.
                """)
        }

        let callers = try sourceFiles { $0.contains(".setRegionStretchMode(") }
        XCTAssertEqual(callers, [Self.bar], """
            `setRegionStretchMode` is called from \(callers). The part bar is its one door; a second \
            surface choosing a part's algorithm is a second editor of one value.
            """)
    }

    // MARK: 5 — counterweights: the player plays each part's own mode; Join refuses mixed modes

    func testThePlayerAndJoinStillReadThePartsMode() throws {
        let lanes = try source("Sources/Echoelmusic/Sequencer/AudioLanePlayer.swift")
        XCTAssertTrue(lanes.contains("StretchPlan.resolve(mode: region.stretchMode,"),
                      "the player no longer resolves a part's plan from ITS mode — the picker would move nothing")
        let timeline = try source("Sources/Echoelmusic/Sequencer/Timeline.swift")
        XCTAssertTrue(timeline.contains("stretchMode == other.stretchMode"),
                      "Join no longer refuses two halves of different mode — it would silently pick one")
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
