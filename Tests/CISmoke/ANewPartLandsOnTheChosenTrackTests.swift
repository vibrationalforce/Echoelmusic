// ANewPartLandsOnTheChosenTrackTests.swift
// Echoel — DMMW Phase 4 · slice 1 (founder 2026-09-29: "Neues Stück → Instrument/Spur → Part →
// Noten"). "New MIDI Part" always landed on the ROLL lane (the first MIDI track), so "Add MIDI
// Track" → "New MIDI Part" wrote the part onto a DIFFERENT track than the one just made and
// selected. It now lands on the selected track whenever the engine certainly plays a part there.
//
// WHAT IT PINS.
// 1. END-TO-END BEHAVIOUR over the pure `MIDIImport.emptyPartLane`: the selected track wins when
//    it is the roll lane or a rack-voiced MIDI lane (`MultiRollFanout.slot`, the player's rule);
//    a bio, audio, visual, unknown or voiceless selection falls back to the roll lane. And the
//    rule agrees with the track inspector's own `TrackMix.role` on every lane (#416 — two
//    places that say which track a voice plays must not disagree).
// 2. END-TO-END over a real `TimelineStore` + `ClipStore`: Add MIDI Track, select it, New MIDI
//    Part with a rack → the region sits on the NEW lane, at bar 1 of that lane, as ONE undo step.
// 3. The words: when the selected track cannot take the part, the note names both tracks.
// 4. SOURCE: the Workstation hands over `selection.trackID` and `player.laneVoiceCapacity`, and
//    names the missed track only when the landing differs from the selection.
//
// GRADING (§3). Against the parent (`0fa6eefb1`) this file does NOT COMPILE — `emptyPartLane`
// and the new required arguments are new — so no assertion has a verdict there: ONE absence
// (#486), every claim a FORWARD guard. Counterweights (#343): the fallback cases are the old
// behaviour and are green in intent on both trees. Transcribed in Python against THIS tree (no
// toolchain here): the lane rule over the fixture, and each scan needle.
//
// 5. REVIEW OF 324c8e9b3 (HIGH + MED), added in the repair commit: the compose guide's "Part"
//    step counts parts only on its own track (the import's track, the roll lane), so it points
//    the ONE part action at that track first — otherwise a part landed on a selected rack
//    track, "Part" stayed next and every tap spent a clip slot. And the "Generate won't place
//    its take over this part" sentence is said only for a part on the roll lane, the only lane
//    Generate yields on. END-TO-END over real stores for the loop, SOURCE for the two call sites;
//    the premise that the guide counts only its own track is a counterweight (green on both).
//
// ⛔ HONEST LIMITS. A part on a rack lane is played by that lane's rack voice (its own patch),
// not by the Echoel instrument — whether it SOUNDS right is a device probe. The MIDI FILE
// import still lands on the roll lane (unchanged here).
// NEEDS-FOUNDER-VERIFY: Workstation → Add MIDI Track → New MIDI Part → the part appears on the
// new track, write two notes, Play → they sound on that track's voice.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class ANewPartLandsOnTheChosenTrackTests: XCTestCase {

    private static let workstationPath = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let composeGuidePath = "Sources/Echoelmusic/Studio/ComposeGuide.swift"

    private static let keys = TimelineLane(name: "Keys", kind: .midi)
    private static let lead = TimelineLane(name: "Lead", kind: .midi)
    private static let body = TimelineLane(name: "Body", kind: .midi, isBio: true)
    private static let loop = TimelineLane(name: "Loop", kind: .audio)
    private static let look = TimelineLane(name: "Look", kind: .visual)

    private var restore: [() -> Void] = []

    override func tearDown() async throws {
        for undo in restore.reversed() { undo() }
        restore.removeAll()
    }

    // MARK: 1 — the lane rule

    func testTheSelectedTrackWinsOnlyWhereAVoicePlaysIt() {
        let document = TimelineDocument(lanes: [Self.keys, Self.lead, Self.body, Self.loop, Self.look],
                                         regions: [])
        XCTAssertEqual(document.rollLaneID, Self.keys.id, "ANCHOR: the first non-bio MIDI lane is the roll lane")
        func lane(_ selected: UUID?, _ capacity: Int) -> UUID? {
            MIDIImport.emptyPartLane(in: document, selectedTrack: selected, voiceCapacity: capacity)?.id
        }
        XCTAssertEqual(lane(Self.lead.id, 4), Self.lead.id, "a rack-voiced MIDI track takes the part")
        XCTAssertEqual(lane(Self.keys.id, 4), Self.keys.id, "the roll lane takes it too")
        XCTAssertEqual(lane(Self.keys.id, 0), Self.keys.id, "…with or without a rack")
        // Counterweights (#343): every fallback is the old behaviour.
        XCTAssertEqual(lane(Self.lead.id, 0), Self.keys.id, """
            with no rack voice the second MIDI track would hold a part nothing plays, and `canPlay` \
            does not check rack capacity — it must fall back
            """)
        XCTAssertEqual(lane(Self.body.id, 4), Self.keys.id, "never onto the bio curve")
        XCTAssertEqual(lane(Self.loop.id, 4), Self.keys.id, "never onto an audio track")
        XCTAssertEqual(lane(Self.look.id, 4), Self.keys.id, "never onto a visual track")
        XCTAssertEqual(lane(nil, 4), Self.keys.id, "nothing selected → the roll lane")
        XCTAssertEqual(lane(UUID(), 4), Self.keys.id, "a stale selection → the roll lane")
    }

    func testTheRuleAgreesWithTheTrackInspector() {
        let document = TimelineDocument(lanes: [Self.keys, Self.lead, Self.body, Self.loop, Self.look],
                                         regions: [])
        for capacity in [0, 1, 4] {
            for lane in document.lanes {
                let lands = MIDIImport.emptyPartLane(in: document, selectedTrack: lane.id,
                                                     voiceCapacity: capacity)?.id == lane.id
                let voiced: Bool
                switch TrackMix.role(of: lane.id, in: document, voiceCapacity: capacity) {
                case .some(.echoelInstrument), .some(.laneSynth): voiced = true
                default: voiced = false
                }
                XCTAssertEqual(lands, voiced, """
                    \(lane.name) at capacity \(capacity): the part lands where the inspector says a \
                    MIDI voice plays, and nowhere else (#416)
                    """)
            }
        }
    }

    // MARK: 2 — on the real stores

    func testAddTrackThenNewPartWritesOntoTheNewTrack() {
        let timeline = TimelineStore()
        let clips = ClipStore()
        let originalDocument = timeline.document
        let originalSlots = clips.slots
        restore.append { clips.replaceSlots(originalSlots); timeline.replaceDocument(originalDocument) }
        clips.replaceSlots([Clip?](repeating: nil, count: ClipStore.slotCount))
        let roll = TimelineLane(name: "Keys", kind: .midi)
        let bar = TimelineTime.ticksPerBar
        let rollPart = TimelineRegion(laneID: roll.id, clipID: UUID(), startTick: 0, lengthTicks: 2 * bar)
        timeline.replaceDocument(TimelineDocument(lanes: [roll], regions: [rollPart]))

        MIDIImport.addMIDITrack(timeline: timeline)
        guard let made = timeline.document.lanes.last, made.id != roll.id else {
            return XCTFail("ANCHOR: Add MIDI Track appends a lane")
        }
        let regionsBefore = timeline.document.regions.count
        guard case .success(let landing) = MIDIImport.addEmptyPart(clipStore: clips, timeline: timeline,
                                                                   selectedTrack: made.id,
                                                                   voiceCapacity: 4) else {
            return XCTFail("the empty part must land")
        }
        XCTAssertEqual(landing.laneID, made.id, "the part is on the track the player just made")
        XCTAssertEqual(landing.region.laneID, made.id)
        XCTAssertEqual(landing.region.startTick, 0,
                       "at bar 1 of THAT track — the roll lane's two bars do not push it back")
        XCTAssertEqual(timeline.document.regions.count, regionsBefore + 1)
        XCTAssertTrue(timeline.document.regions.contains { $0.id == landing.region.id && $0.laneID == made.id })
        XCTAssertEqual(clips.slots.compactMap { $0 }.first { $0.id == landing.clip.id }?.composerOwned, false,
                       "a user part — evolve never rewrites it")

        timeline.undo()
        XCTAssertFalse(timeline.document.regions.contains { $0.id == landing.region.id },
                       "ONE undo step takes the part back")
    }

    // MARK: 3 — the words

    func testAMissedSelectionIsSaid() {
        let moved = MIDIImport.emptyPartNote(laneName: "Keys", atSongStart: false, notOnSelected: "Loop")
        XCTAssertTrue(moved.contains("Loop cannot play a MIDI part"), moved)
        XCTAssertTrue(moved.contains("so it went on Keys"), moved)
        let landed = MIDIImport.emptyPartNote(laneName: "Lead", atSongStart: false, notOnSelected: nil)
        XCTAssertFalse(landed.contains("cannot play"), "a part that landed where asked says nothing extra")
        XCTAssertTrue(landed.hasPrefix("Added an empty"), "counterweight: the old sentence is kept")
    }

    // MARK: 4 — the Workstation hands the choice over

    func testTheWorkstationHandsOverTheSelectionAndTheCapacity() throws {
        let view = try source(Self.workstationPath)
        let action = try member("private func newMIDIPart() {", in: view)
        XCTAssertTrue(action.contains("let selected = selection.trackID"))
        XCTAssertTrue(action.contains("selectedTrack: selected,"))
        XCTAssertTrue(action.contains("voiceCapacity: player.laneVoiceCapacity)"))
        XCTAssertTrue(action.contains("id == landing.laneID ? nil : lanes.first { $0.id == id }?.name"),
                      "the missed track is named only when the landing differs from the selection")
        XCTAssertTrue(action.contains("notOnSelected: missed)"))
        // The row's spoken hint is the rule's own sentence, not a second wording of it (#416).
        let row = try member("private var newMIDIPartRow: some View {", in: view)
        XCTAssertTrue(row.contains(".accessibilityHint(MIDIImport.newPartHint)"))
        XCTAssertTrue(MIDIImport.newPartHint.contains("selected MIDI track when it has a voice"))
        XCTAssertTrue(MIDIImport.newPartHint.contains("otherwise to the first MIDI track"))
    }

    // MARK: 5 — review of 324c8e9b3: the guide's Part lands where the guide counts

    func testTheGuidesPartLandsOnTheTrackTheGuideCounts() throws {
        let timeline = TimelineStore()
        let clips = ClipStore()
        let originalDocument = timeline.document
        let originalSlots = clips.slots
        restore.append { clips.replaceSlots(originalSlots); timeline.replaceDocument(originalDocument) }
        clips.replaceSlots([Clip?](repeating: nil, count: ClipStore.slotCount))
        timeline.replaceDocument(TimelineDocument(lanes: [Self.keys, Self.lead], regions: []))
        func facts() -> ComposeGuide.Facts {
            ComposeGuide.facts(document: timeline.document, clips: clips.filledClips, canPlay: false, isPlaying: false)
        }

        // The loop's premise: a part on the selected rack track is not one the guide counts.
        guard case .success(let onRack) = MIDIImport.addEmptyPart(clipStore: clips, timeline: timeline,
                                                                  selectedTrack: Self.lead.id,
                                                                  voiceCapacity: 4) else {
            return XCTFail("ANCHOR: a rack-voiced track takes a part")
        }
        XCTAssertEqual(onRack.laneID, Self.lead.id)
        XCTAssertFalse(facts().hasPart, "premise: the guide counts only its own track's parts")
        XCTAssertEqual(ComposeGuide.nextStep(facts()), .part, "…so without the repair \"Part\" stays next")

        // The repair: the guide's track, handed to the same action, takes the part.
        let guideTrack = try XCTUnwrap(MIDIImport.firstImportableMIDILane(in: timeline.document))
        XCTAssertEqual(guideTrack.id, Self.keys.id, "the guide's track is the roll lane")
        guard case .success(let onGuide) = MIDIImport.addEmptyPart(clipStore: clips, timeline: timeline,
                                                                   selectedTrack: guideTrack.id,
                                                                   voiceCapacity: 4) else {
            return XCTFail("the roll lane always takes an empty part")
        }
        XCTAssertEqual(onGuide.laneID, Self.keys.id)
        XCTAssertTrue(facts().hasPart)
        XCTAssertEqual(ComposeGuide.nextStep(facts()), .notes, "the guide moves on — no loop")
    }

    func testTheGuidePointsTheActionAtItsTrackAndTheSentenceAtTheRollLane() throws {
        let view = try source(Self.workstationPath)
        let guide = try member("private var composeGuide: some View {", in: view)
        guard let part = guide.range(of: "case .part:"),
              let point = guide.range(of: "selection.selectTrack(guideTrack.id)",
                                      range: part.upperBound..<guide.endIndex),
              let act = guide.range(of: "newMIDIPart()", range: part.upperBound..<guide.endIndex) else {
            return XCTFail("ANCHOR MISSING: the guide's Part step (#454): \(guide)")
        }
        XCTAssertLessThan(point.lowerBound, act.lowerBound, "point at the guide's track, THEN add the part")
        XCTAssertTrue(guide.contains("if let guideTrack = MIDIImport.firstImportableMIDILane(in: timeline.document) {"),
                      "the guide's track is the import's track — the one `ComposeGuide` counts")
        let action = try member("private func newMIDIPart() {", in: view)
        XCTAssertTrue(action.contains("atSongStart: landing.region.startTick == 0"))
        XCTAssertTrue(action.contains("&& landing.laneID == timeline.document.rollLaneID,"), """
            Generate yields only to user parts on the roll lane — a part elsewhere must not be told \
            "Generate won't place its music over this part"
            """)
        // Counterweight (#343): the premise the repair rests on.
        let guideModel = try source(Self.composeGuidePath)
        XCTAssertTrue(guideModel.contains("guard let lane = MIDIImport.firstImportableMIDILane(in: document) else { return [] }"),
                      "the guide counts parts on the import's track only")
    }

    // MARK: - helpers

    private struct AnchorMissing: Error {}

    /// Brace-matched body after `anchor` (§2, #408).
    private func member(_ anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor),
              let open = code.range(of: "{", range: start.lowerBound..<code.endIndex) else {
            XCTFail("ANCHOR MISSING: \(anchor) (#454)")
            throw AnchorMissing()
        }
        var depth = 0
        var index = open.lowerBound
        while index < code.endIndex {
            let ch = code[index]
            if ch == "{" { depth += 1 }
            if ch == "}" {
                depth -= 1
                if depth == 0 { return String(code[open.lowerBound...index]) }
            }
            index = code.index(after: index)
        }
        XCTFail("UNBALANCED: \(anchor)")
        throw AnchorMissing()
    }

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath),
                                     encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing()
        }
        return SourceText.codeOnly(text)
    }
}
