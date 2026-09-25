// TheTrackInspectorShowsOnlyWiredControlsTests.swift
// Echoel — WA4.1: select a track in the Workstation, see what plays it, mix it.
//
// WHAT THIS PINS. `Studio/TrackInspectorView.swift` gives the per-track mixer API on
// `TimelineStore` its first production caller. The engine half was already live and doorless:
// `AudioLanePlayer.reconcileMix`, the rack slot sinks and `rollSlotGain` → `mixGain` all honour
// level/mute/solo/pan every step. The risk in dooring it is not a crash; it is a control that
// moves a number and not the sound (#164/#227). So the claims are about WHICH controls appear:
//
// 1. END-TO-END over the real `TimelineDocument`: the Echoel instrument's track (the first
//    non-bio MIDI lane) gets level + mute/solo and NO pan; any other MIDI lane and every audio
//    lane get all three; a bio lane and an unplayed kind get none; an unknown id gets nil.
// 2. The Echoel track is chosen by the SAME rule `rollSlotGain` uses (#416) — a second MIDI lane
//    is a rack lane even when it was added first by name.
// 3. COUNTERWEIGHT (#343): the premise of "no pan on the Echoel track" — `rollSlotPan` still has
//    no consumer. The day one lands, this goes red ON PURPOSE with the checklist in its message.
// 4. SOURCE: the writes go through the store's existing API and nothing else (no second truth,
//    no persistence of its own); the pan field sits inside `if controls.pan`; numeric
//    parameters use `EchoelValueField`, never `Slider`/`Stepper`.
// 5. SOURCE: the Workstation holds the selection as VIEW state and constructs the inspector
//    exactly once, and still sends `timeline` nothing but `document` (the seam
//    `TheWorkstationHasADoorTests` pins — re-asserted here only for the inspector's sake).
//
// Review of b2913f96b (PASS WITH CONDITIONS) tightened claims 3 and 4 and added the roll-rule /
// rename-commit claim; all three are FORWARD guards over this repair.
// Grading (§0, no Swift toolchain in a web session): claims 1–2 were transcribed into Python over
// a model of `TrackMix.role`/`controls` and `rollSlotGain`'s lane rule; claims 3–5 were driven
// against this tree. On the parent the subject file does not exist, so the bundle does not build
// there — ONE absence, not five findings (#486). Claim 3 is a COUNTERWEIGHT (green on both trees).
// NOT covered: whether the inspector renders, reads well, or that a moved fader is HEARD — that is
// a device probe, and the founder-verify marker below owns it.
// NEEDS-FOUNDER-VERIFY: Workstation → tap a track → move Level, Pan, Mute, Solo while the song
// plays; the Echoel track's Mute also silences the Studio instrument and Start un-mutes it.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheTrackInspectorShowsOnlyWiredControlsTests: XCTestCase {

    private static let inspectorPath = "Sources/Echoelmusic/Studio/TrackInspectorView.swift"
    private static let workstationPath = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let sourcesRoot = "Sources/Echoelmusic"

    // One fixture VALUE per lane — never a factory (#1419: defaulted UUIDs make a generator).
    private static let bioLane = TimelineLane(name: "Body", kind: .midi, isBio: true)
    private static let echoelLane = TimelineLane(name: "MIDI 1", kind: .midi)
    private static let rackLane = TimelineLane(name: "Keys", kind: .midi, builtinInstrument: .sampler)
    private static let audioLane = TimelineLane(name: "Audio 1", kind: .audio)
    private static let visualLane = TimelineLane(name: "Look", kind: .visual)

    /// The lane rack's default capacity (`LaneVoiceRack(capacity: 4)`), as the player reports it.
    private static let rack = 4

    private static let document = TimelineDocument(
        lanes: [bioLane, echoelLane, rackLane, audioLane, visualLane], regions: [])

    // MARK: 1 — which controls, per role

    func testOnlyWiredControlsAreOffered() throws {
        let doc = Self.document

        let echoel = try XCTUnwrap(TrackMix.controls(of: Self.echoelLane.id, in: doc, voiceCapacity: Self.rack))
        XCTAssertEqual(echoel.role, .echoelInstrument)
        XCTAssertTrue(echoel.level)
        XCTAssertTrue(echoel.muteSolo)
        XCTAssertFalse(echoel.pan, "rollSlotPan has no consumer — a pan field here moves nothing")

        let rack = try XCTUnwrap(TrackMix.controls(of: Self.rackLane.id, in: doc, voiceCapacity: Self.rack))
        XCTAssertEqual(rack.role, .laneSynth(TrackInstrument.sampler.voiceKind))
        XCTAssertTrue(rack.level && rack.pan && rack.muteSolo)

        let audio = try XCTUnwrap(TrackMix.controls(of: Self.audioLane.id, in: doc, voiceCapacity: Self.rack))
        XCTAssertEqual(audio.role, .audio)
        XCTAssertTrue(audio.level && audio.pan && audio.muteSolo)

        let bio = try XCTUnwrap(TrackMix.controls(of: Self.bioLane.id, in: doc, voiceCapacity: Self.rack))
        XCTAssertEqual(bio.role, .bio)
        XCTAssertFalse(bio.level || bio.pan || bio.muteSolo, "a bio curve makes no sound")

        let visual = try XCTUnwrap(TrackMix.controls(of: Self.visualLane.id, in: doc, voiceCapacity: Self.rack))
        XCTAssertEqual(visual.role, .unplayed)
        XCTAssertFalse(visual.level || visual.pan || visual.muteSolo)

        XCTAssertNil(TrackMix.controls(of: UUID(), in: doc, voiceCapacity: Self.rack), "an unknown track has no inspector")
    }

    // MARK: 2 — the Echoel track is the roll lane, by the roll lane's own rule

    func testTheEchoelTrackIsTheRollSlotLane() {
        // A rack MIDI lane listed FIRST makes IT the roll lane — the rule is position, not name.
        let doc = TimelineDocument(lanes: [Self.rackLane, Self.echoelLane], regions: [])
        XCTAssertEqual(TrackMix.role(of: Self.rackLane.id, in: doc, voiceCapacity: Self.rack), .echoelInstrument)
        XCTAssertEqual(TrackMix.role(of: Self.echoelLane.id, in: doc, voiceCapacity: Self.rack), .laneSynth(.poly))
        // And its level is the one `rollSlotGain` plays (#416: one rule, two readers).
        XCTAssertEqual(doc.rollSlotGain, doc.effectiveGain(for: Self.rackLane.id))
    }

    func testEveryRoleHasADeviceName() {
        let roles: [TrackMix.Role] = [.echoelInstrument, .laneSynth(.poly), .audio, .bio, .unplayed,
                                      .noVoice(capacity: 4), .noVoice(capacity: 0)]
        for role in roles {
            XCTAssertFalse(TrackMix.deviceName(role).isEmpty, "\(role) has no device name")
        }
    }

    // MARK: 2b — a MIDI lane past the rack's capacity has no voice, so no mixer

    func testAVoicelessTrackGetsNoMixer() throws {
        // Roll lane + five extra MIDI lanes: the rack voices the first four extras only.
        let extras = (1...5).map { TimelineLane(name: "Extra \($0)", kind: .midi) }
        let doc = TimelineDocument(lanes: [Self.echoelLane] + extras, regions: [])
        for lane in extras.prefix(4) {
            XCTAssertEqual(TrackMix.role(of: lane.id, in: doc, voiceCapacity: Self.rack),
                           .laneSynth(.poly), "\(lane.name) has a rack voice")
        }
        let fifth = try XCTUnwrap(extras.last)
        let controls = try XCTUnwrap(TrackMix.controls(of: fifth.id, in: doc, voiceCapacity: Self.rack))
        XCTAssertEqual(controls.role, .noVoice(capacity: Self.rack))
        XCTAssertFalse(controls.level || controls.pan || controls.muteSolo,
                       "a fader on a track no voice plays moves a number, not the sound")
        // The same answer the player's own slot rule gives (#416).
        XCTAssertNil(MultiRollFanout.slot(forLaneID: fifth.id, in: doc,
                                          rollLane: doc.rollLaneID, capacity: Self.rack))
        // Multi-roll off: every extra MIDI lane is voiceless; the Echoel track still plays.
        XCTAssertEqual(TrackMix.role(of: extras[0].id, in: doc, voiceCapacity: 0), .noVoice(capacity: 0))
        XCTAssertEqual(TrackMix.role(of: Self.echoelLane.id, in: doc, voiceCapacity: 0), .echoelInstrument)
    }

    func testTheInspectorAsksThePlayersCapacity() throws {
        let code = try source(Self.inspectorPath)
        XCTAssertTrue(code.contains("voiceCapacity: player.laneVoiceCapacity"),
                      "the capacity is the player's, never a literal restated here")
        let player = try source("Sources/Echoelmusic/Sequencer/TimelineRegionPlayer.swift")
        XCTAssertTrue(player.contains("public var laneVoiceCapacity: Int { multiRollCapacity }"),
                      "the getter reads the one capacity `enableMultiRoll` sets")
        XCTAssertTrue(player.contains("@ObservationIgnored private var multiRollCapacity"),
                      "unobserved storage — reading it subscribes the inspector to nothing")
    }

    // MARK: 3 — counterweight: the premise of "no pan on the Echoel track"

    func testTheRollSlotPanStillHasNoConsumer() throws {
        // Every file but the declaring one must be silent, and the declaring one may name it
        // exactly once — its declaration (review of b2913f96b: skipping the whole file let a
        // reader added there go unseen).
        let hits = try filesMatching { code, path in
            code.contains("rollSlotPan") && !(path.hasSuffix("Sequencer/Timeline.swift")
                && code.components(separatedBy: "rollSlotPan").count - 1 == 1
                && code.contains("public var rollSlotPan: Float {"))
        }
        XCTAssertEqual(hits, [], """
            `TimelineDocument.rollSlotPan` is now read by \(hits.joined(separator: ", ")). \
            If that reader PANS the Echoel instrument, this red is welcome: flip `pan` to true \
            for `.echoelInstrument` in `TrackMix.controls`, update claim 1 and this claim, and \
            drop the ⛔ note on `TimelineStore.setLanePan` — all in the same commit.
            """)
    }

    // MARK: 4 — the writes, the pan gate, the parameter law

    func testTheInspectorWritesOnlyThroughTheStoresAPI() throws {
        let code = try source(Self.inspectorPath)
        for call in ["timeline.setLaneLevel(", "timeline.setLanePan(", "timeline.toggleMute(",
                     "timeline.toggleSolo(", "timeline.renameLane("] {
            XCTAssertEqual(code.components(separatedBy: call).count - 1, 1,
                           "`\(call)` must be called exactly once, inside `TrackMix`")
        }
        for banned in ["UserDefaults", "@AppStorage", "AppGroupStore", "JSONEncoder",
                       "TimelineLane(", "TimelineDocument(", "TimelineStore(",
                       "Slider(", "Stepper("] {
            XCTAssertFalse(code.contains(banned),
                           "the inspector contains `\(banned)` — it writes through the store's "
                           + "API, owns no persistence, and numeric parameters use EchoelValueField")
        }
        XCTAssertGreaterThanOrEqual(code.components(separatedBy: "EchoelValueField(").count - 1, 2,
                                    "Level and Pan are EchoelValueField rows")
    }

    func testThePanFieldIsGatedOnTheWiredFlag() throws {
        let code = try source(Self.inspectorPath)
        // Brace-matched (#408), so a Pan field just AFTER the gate's closing brace fails too.
        guard let gate = code.range(of: "if controls.pan {"),
              let block = Self.braceBody(in: code, openingAt: gate.upperBound) else {
            XCTFail("ANCHOR MISSING: the pan gate moved (#454)")
            return
        }
        XCTAssertTrue(block.contains("label: \"Pan\""),
                      "the Pan field must sit inside `if controls.pan`, or it appears on the "
                      + "Echoel track where it moves nothing")
        XCTAssertEqual(code.components(separatedBy: "label: \"Pan\"").count - 1, 1)
    }

    /// The Echoel track is picked by the player's OWN rule, and a typed name cannot be left on
    /// screen unsaved (review of b2913f96b).
    func testTheRollRuleIsTheDocumentsAndTheNameIsNeverLeftUnsaved() throws {
        let code = try source(Self.inspectorPath)
        XCTAssertTrue(code.contains("document.rollLaneID == laneID"),
                      "the Echoel track is `TimelineDocument.rollLaneID` — one rule (#416)")
        XCTAssertFalse(code.contains("$0.kind == .midi && !$0.isBio"),
                       "a restated roll-lane rule is a second definition that can drift")
        XCTAssertTrue(code.contains(".onSubmit { commitName() }"))
        XCTAssertTrue(code.contains("if !focused { commitName() }"),
                      "leaving the field commits the name")
        XCTAssertTrue(code.contains(".onDisappear { commitName() }"),
                      "closing the inspector commits the name")
        XCTAssertFalse(code.contains(".fill(on ? EchoelTheme.accent"),
                       "a solid green area behind a label is the one EchoelTheme forbids")
    }

    // MARK: 5 — the Workstation seam

    func testTheWorkstationOwnsTheSelectionAndOpensOneInspector() throws {
        let code = try source(Self.workstationPath)
        XCTAssertTrue(code.contains("@State private var selectedTrack: UUID?"),
                      "selection is VIEW state of the Workstation, never song state")
        XCTAssertEqual(code.components(separatedBy: "TrackInspectorView(").count - 1, 1)
        XCTAssertFalse(code.contains("TrackMix."),
                       "the Workstation hands the track id over; the inspector owns the writes")
        let inspectorConstructions = try filesMatching { code, _ in
            code.contains("TrackInspectorView(")
        }
        XCTAssertEqual(inspectorConstructions, [Self.workstationPath],
                       "the inspector has exactly one door: the Workstation's selected row")
    }

    // MARK: Source helpers

    /// The text from `start` — just past an anchor's own `{` — to that brace's matching `}`.
    /// nil when the brace never closes.
    private static func braceBody(in code: String, openingAt start: String.Index) -> String? {
        var depth = 1
        var cursor = start
        while cursor < code.endIndex {
            let ch = code[cursor]
            if ch == "{" { depth += 1 }
            if ch == "}" {
                depth -= 1
                if depth == 0 { return String(code[start..<cursor]) }
            }
            cursor = code.index(after: cursor)
        }
        return nil
    }

    private func repoRoot() -> URL {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { dir.deleteLastPathComponent() }
        return dir
    }

    private func source(_ relativePath: String) throws -> String {
        let url = repoRoot().appendingPathComponent(relativePath)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            return ""
        }
        return SourceText.codeOnly(text)
    }

    /// Comment-stripped files under `Sources/Echoelmusic` for which `matches` holds, as
    /// repo-relative paths, sorted.
    private func filesMatching(_ matches: (String, String) -> Bool) throws -> [String] {
        let root = repoRoot().appendingPathComponent(Self.sourcesRoot)
        guard let walker = FileManager.default.enumerator(atPath: root.path) else {
            XCTFail("cannot enumerate \(Self.sourcesRoot) — a scan that saw nothing is not a pass")
            return []
        }
        var hits: [String] = []
        var seen = 0
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            seen += 1
            let path = Self.sourcesRoot + "/" + relative
            let url = root.appendingPathComponent(relative)
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            if matches(SourceText.codeOnly(text), path) { hits.append(path) }
        }
        XCTAssertGreaterThan(seen, 200, "the walk saw \(seen) files — the wrong directory")
        return hits.sorted()
    }
}
