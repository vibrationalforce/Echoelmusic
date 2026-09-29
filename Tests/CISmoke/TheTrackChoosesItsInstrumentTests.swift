// TheTrackChoosesItsInstrumentTests.swift
// Echoel — DMMW Phase 4 · slice 2 (founder 2026-09-29: "Instrument pro Spur"). A track's
// instrument (`TimelineLane.builtinInstrument`) was read by the player on every part load
// (`MultiRollFanout.voiceKind` → `LaneVoiceRack.setKind`), and its one writer
// (`TimelineStore.setBuiltinInstrument`) had NO production caller — the engine half was done
// and doorless. The track inspector now offers the choice on a rack track.
//
// WHAT IT PINS.
// 1. END-TO-END BEHAVIOUR over the pure `TrackMix` rule: the choices exist only on a rack track
//    (`.laneSynth`) — never on the Echoel track (its kind sink would swap the generative
//    instrument's own voice), a bio, audio, visual or voiceless track; a legacy choice stays
//    shown as the current value; the fallback is EchoelSynth, the player's own `?? .poly`.
// 2. END-TO-END over a real `TimelineStore`: the write lands on the lane, the player's kind
//    rule (`MultiRollFanout.voiceKind`) reads the new kind, and the inspector's role follows.
// 3. COUNTERWEIGHTS (#343): the hint's "one voice each" rests on the rack holding exactly one
//    sub-bass and one body unit, and the allocator falling back to poly — both scanned.
// 4. SOURCE: the row writes through `TrackMix.setInstrument` only, is a menu Picker (a named
//    choice, not a number), carries the hint, and is shown only when there are choices.
//
// GRADING (§3). Against the parent this file does NOT COMPILE — `instrumentChoices`,
// `currentInstrument`, `instrumentMenu`, `instrumentHint` and `setInstrument` are new — so no
// assertion has a verdict there: ONE absence (#486), every claim a FORWARD guard; the
// counterweights in claim 3 are green in intent on both trees. Transcribed in Python against
// THIS tree (no toolchain): the role rule over the fixture, and every scan needle.
//
// 5. REVIEW OF 895cf025a (4 MED + 1 LOW), added in the repair commit: the Pan field is offered
//    only where `LaneVoiceRack.setPan` moves the sound (not the sub-bass, not the sampler); the
//    Device row names the voice by the Instrument row's name (one name per voice); the hint says
//    a track on EchoelBodyVibe cannot be armed — measured end to end through `RecordTake.canArm`;
//    and a pick of what already plays writes nothing. FORWARD guards; the `setPan` no-op and the
//    body voice's record source are counterweights (green on both trees).
//
// ⛔ HONEST LIMITS. Not undoable (the store's lane dials never were). The Echoel track keeps
// its instrument. The sampler is not offered (it needs a sample first). With
// `FeatureFlags.voiceKindRouting` off the rack has no sub or body unit and every choice plays
// the synth. Whether EchoelBass and EchoelBodyVibe SOUND right on a track is a device probe.
// NEEDS-FOUNDER-VERIFY: Workstation → Add MIDI Track → select it → Instrument: EchoelBass →
// New MIDI Part, write low notes, Play → a sub-bass, not the synth.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheTrackChoosesItsInstrumentTests: XCTestCase {

    private static let inspectorPath = "Sources/Echoelmusic/Studio/TrackInspectorView.swift"
    private static let rackPath = "Sources/Echoelmusic/Sequencer/LaneVoiceRack.swift"
    private static let allocatorPath = "Sources/Echoelmusic/Sequencer/KindVoiceAllocator.swift"

    private static let keys = TimelineLane(name: "Keys", kind: .midi)
    private static let lead = TimelineLane(name: "Lead", kind: .midi)
    private static let old = TimelineLane(name: "Old", kind: .midi, builtinInstrument: .drums)
    private static let body = TimelineLane(name: "Body", kind: .midi, isBio: true)
    private static let loop = TimelineLane(name: "Loop", kind: .audio)
    private static let look = TimelineLane(name: "Look", kind: .visual)

    private var restore: [() -> Void] = []

    override func tearDown() async throws {
        for undo in restore.reversed() { undo() }
        restore.removeAll()
    }

    // MARK: 1 — the rule

    func testOnlyARackTrackOffersTheChoice() {
        let document = TimelineDocument(lanes: [Self.keys, Self.lead, Self.old, Self.body, Self.loop, Self.look],
                                         regions: [])
        XCTAssertEqual(document.rollLaneID, Self.keys.id, "ANCHOR: the first non-bio MIDI lane is the Echoel track")
        func choices(_ lane: TimelineLane, _ capacity: Int) -> [TrackInstrument] {
            guard let role = TrackMix.role(of: lane.id, in: document, voiceCapacity: capacity) else { return [] }
            return TrackMix.instrumentChoices(role)
        }
        XCTAssertEqual(choices(Self.lead, 4), [.polySynth, .subBass, .bioVoice],
                       "a rack track offers exactly the kinds the rack binds on a secondary slot")
        // Counterweights (#343): nowhere else.
        XCTAssertEqual(choices(Self.keys, 4), [], "never the Echoel track — it would swap the instrument's voice")
        XCTAssertEqual(choices(Self.lead, 0), [], "a track with no rack voice has nothing to choose")
        XCTAssertEqual(choices(Self.body, 4), [], "a bio curve makes no sound")
        XCTAssertEqual(choices(Self.loop, 4), [], "an audio track plays its file")
        XCTAssertEqual(choices(Self.look, 4), [], "a visual track plays nothing")
        XCTAssertFalse(TrackMix.instrumentChoices(.laneSynth(.poly)).contains(.sampler),
                       "the sampler needs a sample before it sounds — this row assigns none")
    }

    func testTheCurrentValueIsTheLanesOrTheSynth() {
        let document = TimelineDocument(lanes: [Self.keys, Self.lead, Self.old], regions: [])
        XCTAssertEqual(TrackMix.currentInstrument(of: Self.lead.id, in: document), .polySynth,
                       "a lane without an instrument plays EchoelSynth (`voiceKind ?? .poly`)")
        XCTAssertEqual(TrackMix.currentInstrument(of: Self.old.id, in: document), .drums)
        let legacy = TrackMix.instrumentMenu(.laneSynth(.poly), current: .drums)
        XCTAssertEqual(legacy, [.drums, .polySynth, .subBass, .bioVoice],
                       "a legacy choice is shown as the current value, never offered anew")
        XCTAssertEqual(TrackMix.instrumentMenu(.laneSynth(.subBass), current: .subBass),
                       [.polySynth, .subBass, .bioVoice])
        XCTAssertEqual(TrackMix.instrumentMenu(.echoelInstrument, current: .drums), [],
                       "no row where there is no choice, whatever the lane holds")
    }

    // MARK: 2 — on the real store, read by the player's own rule

    func testTheChoiceReachesThePlayersKindRule() {
        let timeline = TimelineStore()
        let originalDocument = timeline.document
        restore.append { timeline.replaceDocument(originalDocument) }
        timeline.replaceDocument(TimelineDocument(lanes: [Self.keys, Self.lead], regions: []))
        let rollLane = timeline.document.rollLaneID
        guard let slot = MultiRollFanout.slot(forLaneID: Self.lead.id, in: timeline.document,
                                              rollLane: rollLane, capacity: 4) else {
            return XCTFail("ANCHOR: the second MIDI track has a rack slot at capacity 4")
        }
        XCTAssertEqual(MultiRollFanout.voiceKind(forSlot: slot, in: timeline.document, rollLane: rollLane), .poly)

        TrackMix.setInstrument(.subBass, laneID: Self.lead.id, timeline: timeline)
        XCTAssertEqual(timeline.document.lanes.first { $0.id == Self.lead.id }?.builtinInstrument, .subBass)
        XCTAssertEqual(MultiRollFanout.voiceKind(forSlot: slot, in: timeline.document, rollLane: rollLane),
                       .subBass, "the slot the player loads binds the chosen kind")
        XCTAssertEqual(TrackMix.role(of: Self.lead.id, in: timeline.document, voiceCapacity: 4),
                       .laneSynth(.subBass), "and the inspector names the voice that plays it")

        TrackMix.setInstrument(.bioVoice, laneID: Self.lead.id, timeline: timeline)
        XCTAssertEqual(MultiRollFanout.voiceKind(forSlot: slot, in: timeline.document, rollLane: rollLane),
                       .bioVoice)
        XCTAssertNil(timeline.document.lanes.first { $0.id == Self.keys.id }?.builtinInstrument,
                     "counterweight: the Echoel track is untouched")
    }

    // MARK: 3 — the hint's premises

    func testTheRackHoldsOneSubAndOneBodyVoiceAndNeverSilences() throws {
        XCTAssertTrue(TrackMix.instrumentHint.contains("EchoelBass and EchoelBodyVibe each play one track at a time"))
        XCTAssertTrue(TrackMix.instrumentHint.contains("plays EchoelSynth"))
        let rack = try source(Self.rackPath)
        XCTAssertEqual(rack.components(separatedBy: "subs = [sub]").count - 1, 1, """
            the hint says ONE EchoelBass voice; a rack with more sub units makes it wrong — \
            reword `TrackMix.instrumentHint` in the same commit
            """)
        XCTAssertEqual(rack.components(separatedBy: "bios = [bio]").count - 1, 1,
                       "the same for the body voice")
        let allocator = try source(Self.allocatorPath)
        XCTAssertTrue(allocator.contains("out[entry.slot] = .poly(entry.slot)"),
                      "a kind whose unit is taken falls back to the synth, never to silence")
        XCTAssertEqual(TrackInstrument.subBass.voiceKind, .subBass)
        XCTAssertEqual(TrackInstrument.bioVoice.voiceKind, .bioVoice)
        XCTAssertEqual(TrackInstrument.polySynth.voiceKind, .poly)
    }

    // MARK: 4 — the row

    func testTheRowWritesThroughTheStoreAndIsANamedChoice() throws {
        let code = try source(Self.inspectorPath)
        XCTAssertEqual(code.components(separatedBy: "timeline.setBuiltinInstrument(").count - 1, 1,
                       "one write, inside `TrackMix.setInstrument`")
        let row = try member("private func instrumentRow(_ instruments: [TrackInstrument]) -> some View {", in: code)
        XCTAssertTrue(row.contains("set: { TrackMix.setInstrument($0, laneID: laneID, timeline: timeline) }"))
        XCTAssertTrue(row.contains(".pickerStyle(.menu)"), "a named choice is a menu Picker, not a number field")
        XCTAssertTrue(row.contains(".accessibilityHint(TrackMix.instrumentHint)"), "one wording (#416)")
        XCTAssertTrue(row.contains(".frame(minHeight: 44)"), "a 44-pt target")
        let body = try member("var body: some View {", in: code)
        XCTAssertTrue(body.contains("controls.role, current: TrackMix.currentInstrument(of: laneID, in: document))"))
        XCTAssertTrue(body.contains("if !instruments.isEmpty {"), "no row where there is no choice")
        XCTAssertEqual(code.components(separatedBy: "instrumentRow(").count - 1, 2,
                       "declared once, mounted once")
    }

    // MARK: 5 — review of 895cf025a

    func testEveryInstrumentGetsOnlyTheControlsThatMoveItsSound() throws {
        let lanes = [Self.keys, TimelineLane(name: "Sub", kind: .midi, builtinInstrument: .subBass),
                     TimelineLane(name: "Body voice", kind: .midi, builtinInstrument: .bioVoice),
                     TimelineLane(name: "Pad", kind: .midi, builtinInstrument: .polySynth)]
        let document = TimelineDocument(lanes: lanes, regions: [])
        func controls(_ i: Int) throws -> TrackMix.Controls {
            try XCTUnwrap(TrackMix.controls(of: lanes[i].id, in: document, voiceCapacity: 4))
        }
        XCTAssertFalse(try controls(1).pan, "`setPan` is a no-op for the sub-bass unit")
        XCTAssertTrue(try controls(2).pan, "the body unit pans at its mixer stage")
        XCTAssertTrue(try controls(3).pan, "the synth pans")
        // One name per voice: the Device row says what the Instrument row says.
        XCTAssertEqual(TrackMix.deviceName(.laneSynth(.subBass)), TrackInstrument.subBass.displayName)
        XCTAssertEqual(TrackMix.deviceName(.laneSynth(.bioVoice)), TrackInstrument.bioVoice.displayName)
        XCTAssertEqual(TrackMix.deviceName(.laneSynth(.poly)), TrackInstrument.polySynth.displayName)
        // The pan premise, at the rack.
        let rack = try source(Self.rackPath)
        let setPan = try member("public func setPan(slot: Int, _ pan: Float) {", in: rack)
        XCTAssertTrue(setPan.contains("case .subBass, .sampler:"), """
            the sub-bass and sampler units still take no pan — if one gains a pan stage, offer the \
            field in `TrackMix.controls` in the same commit
            """)
    }

    func testTheBodyVoiceTrackSaysItCannotBeArmed() {
        let body = TimelineLane(name: "Body voice", kind: .midi, builtinInstrument: .bioVoice)
        let synth = TimelineLane(name: "Pad", kind: .midi)
        let document = TimelineDocument(lanes: [Self.keys, body, synth], regions: [])
        XCTAssertEqual(TrackInstrument.bioVoice.recordSource, .bio, "premise: the body voice records the body")
        XCTAssertFalse(RecordTake.canArm(body.id, in: document, voiceCapacity: 4),
                       "a track on EchoelBodyVibe cannot be armed for MIDI")
        XCTAssertTrue(RecordTake.canArm(synth.id, in: document, voiceCapacity: 4), "counterweight: a synth track can")
        XCTAssertTrue(TrackMix.instrumentHint.contains("A track on EchoelBodyVibe cannot be armed to record MIDI"),
                      "the choice says what it costs before it is made")
        XCTAssertTrue(TrackMix.instrumentHint.contains("the higher one in the list"),
                      "the allocator's first-rank-wins rule, in the player's words")
    }

    func testAPickOfWhatAlreadyPlaysWritesNothing() {
        let timeline = TimelineStore()
        let originalDocument = timeline.document
        restore.append { timeline.replaceDocument(originalDocument) }
        timeline.replaceDocument(TimelineDocument(lanes: [Self.keys, Self.lead], regions: []))
        let before = timeline.document
        TrackMix.setInstrument(.polySynth, laneID: Self.lead.id, timeline: timeline)
        XCTAssertEqual(timeline.document, before, "EchoelSynth already plays a lane without an instrument")
        XCTAssertNil(timeline.document.lanes.first { $0.id == Self.lead.id }?.builtinInstrument)
        TrackMix.setInstrument(.subBass, laneID: Self.lead.id, timeline: timeline)
        XCTAssertEqual(timeline.document.lanes.first { $0.id == Self.lead.id }?.builtinInstrument, .subBass,
                       "counterweight: a real change still writes")
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
