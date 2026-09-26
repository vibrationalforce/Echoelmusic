// TheTrackEffectIsADeviceOnTheLaneTests.swift
// Echoel — Phase 3 / DC1: the native DeviceChain, first slice (plan
// `scratchpads/PLAN_DEVICE_CHAIN_2026-09-26.md`). An extra MIDI track can carry ONE effect insert,
// chosen in the Workstation's track inspector, stored on the lane as a `DeviceChain` (WA3 §D),
// and played through that track's own rack voice FX chain.
//
// WHAT IT PINS.
// 1. PURE (`DeviceChain`): what sounds is the FIRST ENABLED character insert that has its own
//    preset; `.auto` never sounds; the writer keeps ONE character insert, keeps every insert of
//    another type in place (an unknown type is kept verbatim, WA3 §C2 / #527), keeps the
//    character insert's identity, and stores NO chain when nothing is left.
// 2. DECODE (`TimelineLane`): a pre-DC1 song has no chain; a song carrying the REMOVED AUv3
//    `instrument`/`effects` keys still has no chain (the new key is its own); a chain that is not
//    a chain costs the effect, never the lane; one unreadable insert costs only itself; an
//    unknown insert round-trips byte for byte; a lane with no chain encodes no key.
// 3. END-TO-END over a REAL `TimelineStore`: `setLaneEffect` writes, re-selecting writes nothing,
//    and nil removes the chain while an unknown insert survives.
// 4. PLAYBACK VALUES (pure, the player's own functions): the chain flows through `mergeMixer`
//    (live during play) and is NOT structural (no relocate); `MultiRollFanout.effect` answers
//    per slot with the chain's own `soundingCharacter`.
// 5. END-TO-END on a REAL `EchoelFXChain`: a character's preset changes the chain, and the
//    snapshot the rack takes at attach puts it back EXACTLY — the pooled-slot law: a lane with no
//    effect must not inherit the previous lane's character. `.auto` touches nothing.
// 6. WHO SEES THE ROW (`TrackMix.controls`): only a POLY rack track.
// 7. SOURCE-TEXT SCAN: the effect is pushed at every site the octave is (three load sites +
//    `refreshMixer`), BEFORE the pump loads the notes, the app wires it to the rack exactly once, the rack restores the snapshot,
//    and the inspector writes through the store and gates the row on the flag.
//
// HONEST GRADING (§3), against the parent tree (`e23c0ed92`): the file does NOT compile there —
// `DeviceChain`, `DeviceInsert`, `TimelineLane.deviceChain`, `TimelineStore.setLaneEffect`,
// `MultiRollFanout.effect`, `FXCharacter.applyOwnPreset`, `TrackMix.Controls.effect` and
// `TrackMix.effectChoices` are all new — so no assertion has a verdict on the parent. Every claim
// is a FORWARD guard; one absence (#486). Counterweights (#343): claim 2 asserts the untouched
// lane fields beside the missing chain; claim 5 asserts the chain really CHANGED before it
// asserts the restore (a restore of an unchanged chain proves nothing); claim 6 asserts level/pan
// stay on the tracks that lose the row. Graded by Python transcription of `settingCharacter`,
// `soundingCharacter` and every scan anchor against the worktree.
//
// REVIEW OF e061ca2d3 (no HIGH) added: a character insert of a LATER `typeVersion` is not read
// with this build's meaning, and choosing an effect over it re-stamps its version with its state
// (claim 1); the push-before-load order (claim 7). ⚠️ Stated limit, in `DeviceChain`'s header:
// "kept" holds for an unknown TYPE in this envelope, not for an insert whose envelope differs.
//
// NOT HERE — DEVICE PROBE, open. Whether the effect is HEARD on the right track and only there,
// and that a second track in the same slot after it plays dry. Nothing here attaches an audio
// engine; the rack's `setEffect` is scanned, not driven.
// NEEDS-FOUNDER-VERIFY: Workstation → Add a MIDI track → New MIDI Part → tap the track → Effect:
// Underwater → Play: that track sounds submerged, the Echoel track does not. Effect: Default →
// the track sounds as before. Save, reopen: the effect is still there.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheTrackEffectIsADeviceOnTheLaneTests: XCTestCase {

    private static let playerPath = "Sources/Echoelmusic/Sequencer/TimelineRegionPlayer.swift"
    private static let appPath = "Sources/Echoelmusic/EchoelmusicApp.swift"
    private static let rackPath = "Sources/Echoelmusic/Sequencer/LaneVoiceRack.swift"
    private static let inspectorPath = "Sources/Echoelmusic/Studio/TrackInspectorView.swift"
    private static let timelinePath = "Sources/Echoelmusic/Sequencer/Timeline.swift"

    private static let unknownInsert = DeviceInsert(
        typeID: "com.example.later.granular", typeVersion: 3, isEnabled: true,
        stateBlob: Data([0x00, 0xFF, 0x7F, 0x10]))

    // MARK: 1 — the chain's own answers

    func testTheFirstEnabledCharacterWithAPresetIsWhatSounds() {
        XCTAssertNil(DeviceChain(inserts: []).soundingCharacter)

        let set = DeviceChain(inserts: []).settingCharacter(.underwater)
        XCTAssertEqual(set?.inserts.count, 1)
        XCTAssertEqual(set?.soundingCharacter, .underwater)
        XCTAssertEqual(set?.inserts.first?.typeID, DeviceInsert.characterTypeID)

        var disabled = DeviceInsert.character(.hall)
        disabled.isEnabled = false
        XCTAssertNil(DeviceChain(inserts: [disabled]).soundingCharacter,
                     "a disabled insert does not sound")
        XCTAssertEqual(DeviceChain(inserts: [disabled, .character(.room)]).soundingCharacter, .room,
                       "the first ENABLED one sounds")
        XCTAssertNil(DeviceChain(inserts: [.character(.auto)]).soundingCharacter,
                     "`.auto` means the genre's effect — a track does not own a genre")
        let unreadable = DeviceInsert(typeID: DeviceInsert.characterTypeID, typeVersion: 9,
                                      isEnabled: true, stateBlob: Data("laser".utf8))
        XCTAssertNil(unreadable.character, "a later build's character name is nothing here, not a crash")
        XCTAssertNil(DeviceChain(inserts: [Self.unknownInsert]).soundingCharacter)
    }

    func testTheWriterKeepsWhatItCannotReadAndStoresNothingWhenEmpty() throws {
        XCTAssertNil(DeviceChain(inserts: []).settingCharacter(nil))
        XCTAssertNil(DeviceChain(inserts: []).settingCharacter(.auto),
                     "`.auto` is not an effect a track can carry")
        XCTAssertNil(DeviceChain(inserts: [.character(.vinyl)]).settingCharacter(nil),
                     "a track with no effect stores no chain")

        let existing = DeviceInsert.character(.vinyl)
        let chain = DeviceChain(inserts: [Self.unknownInsert, existing])
        let changed = try XCTUnwrap(chain.settingCharacter(.hall))
        XCTAssertEqual(changed.inserts.count, 2)
        XCTAssertEqual(changed.inserts[0], Self.unknownInsert, "an unknown insert is kept, in place, verbatim")
        XCTAssertEqual(changed.inserts[1].id, existing.id, "the character insert keeps its identity")
        XCTAssertEqual(changed.soundingCharacter, .hall)

        let removed = try XCTUnwrap(chain.settingCharacter(nil),
                                    "removing the effect must not drop the insert this build cannot read")
        XCTAssertEqual(removed.inserts, [Self.unknownInsert])

        let doubled = DeviceChain(inserts: [.character(.dream), Self.unknownInsert, .character(.blurry)])
        let one = try XCTUnwrap(doubled.settingCharacter(.room))
        XCTAssertEqual(one.inserts.filter { $0.typeID == DeviceInsert.characterTypeID }.count, 1,
                       "one chain sounds one character — a second would be a claim")
        XCTAssertEqual(one.inserts.map(\.typeID),
                       [DeviceInsert.characterTypeID, Self.unknownInsert.typeID])
        XCTAssertEqual(one.soundingCharacter, .room)

        // Review of e061ca2d3: a LATER state format is not this build's to read or to half-rewrite.
        let later = DeviceInsert(typeID: DeviceInsert.characterTypeID, typeVersion: 2,
                                 isEnabled: true, stateBlob: Data("hall".utf8))
        XCTAssertNil(later.character, "a v2 state that happens to parse is not played with v1 meaning")
        XCTAssertNil(DeviceChain(inserts: [later]).soundingCharacter)
        let restamped = try XCTUnwrap(DeviceChain(inserts: [later]).settingCharacter(.room))
        XCTAssertEqual(restamped.inserts.first?.id, later.id)
        XCTAssertEqual(restamped.inserts.first?.typeVersion, DeviceInsert.characterTypeVersion,
                       "v1 bytes under a v2 label would be misread by the later build")
        XCTAssertEqual(restamped.soundingCharacter, .room)

        var off = DeviceInsert.character(.telephone)
        off.isEnabled = false
        XCTAssertEqual(DeviceChain(inserts: [off]).settingCharacter(.telephone)?.soundingCharacter,
                       .telephone, "choosing it again re-enables it")
    }

    // MARK: 2 — decode

    private func laneJSON(_ lane: TimelineLane) throws -> [String: Any] {
        let data = try JSONEncoder().encode(lane)
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func decodeLane(_ object: [String: Any]) throws -> TimelineLane {
        let data = try JSONSerialization.data(withJSONObject: object)
        return try JSONDecoder().decode(TimelineLane.self, from: data)
    }

    func testAnOldSongAndARemovedPlugInKeyHaveNoChain() throws {
        let lane = TimelineLane(name: "Keys", kind: .midi, pan: 0.25, transposeSemitones: 3)
        let plain = try laneJSON(lane)
        XCTAssertNil(plain["deviceChain"], "a lane with no chain writes no key — old bytes stay old bytes")
        XCTAssertNil(try decodeLane(plain).deviceChain)

        var legacy = plain
        legacy["instrument"] = ["name": "Some AU", "componentType": "aumu"]
        legacy["effects"] = [["name": "Some FX", "componentType": "aufx"]]
        let decoded = try decodeLane(legacy)
        XCTAssertNil(decoded.deviceChain, "the removed AUv3 keys are not the chain (its own key)")
        XCTAssertEqual(decoded.pan, 0.25)
        XCTAssertEqual(decoded.transposeSemitones, 3)
    }

    func testABrokenChainCostsTheEffectNeverTheLane() throws {
        let lane = TimelineLane(name: "Keys", kind: .midi, level: 0.5)
        var broken = try laneJSON(lane)
        broken["deviceChain"] = "not a chain"
        let decoded = try decodeLane(broken)
        XCTAssertNil(decoded.deviceChain)
        XCTAssertEqual(decoded.name, "Keys")
        XCTAssertEqual(decoded.level, 0.5)

        var partly = try laneJSON(TimelineLane(name: "Keys", kind: .midi,
                                               deviceChain: DeviceChain(inserts: [.character(.hall)])))
        var chain = try XCTUnwrap(partly["deviceChain"] as? [String: Any])
        var inserts = try XCTUnwrap(chain["inserts"] as? [Any])
        inserts.insert(["typeID": 42], at: 0)
        chain["inserts"] = inserts
        partly["deviceChain"] = chain
        XCTAssertEqual(try decodeLane(partly).deviceChain?.soundingCharacter, .hall,
                       "one unreadable insert is skipped, the rest of the chain survives")
    }

    func testAnUnknownInsertRoundTripsByteForByte() throws {
        let lane = TimelineLane(name: "Keys", kind: .midi,
                                deviceChain: DeviceChain(inserts: [Self.unknownInsert, .character(.cassette)]))
        let back = try JSONDecoder().decode(TimelineLane.self, from: JSONEncoder().encode(lane))
        XCTAssertEqual(back.deviceChain, lane.deviceChain)
        XCTAssertEqual(back.deviceChain?.inserts.first?.stateBlob, Self.unknownInsert.stateBlob)
        XCTAssertEqual(back.deviceChain?.inserts.first?.typeVersion, 3)
    }

    // MARK: 3 — the one writer, on a real store

    func testTheStoreWritesTheChainAndKeepsWhatItCannotRead() throws {
        let timeline = TimelineStore()
        let original = timeline.document
        defer { timeline.replaceDocument(original) }

        let echoel = TimelineLane(name: "MIDI 1", kind: .midi)
        let keys = TimelineLane(name: "Keys", kind: .midi,
                                deviceChain: DeviceChain(inserts: [Self.unknownInsert]))
        timeline.replaceDocument(TimelineDocument(lanes: [echoel, keys], regions: []))
        func chain() -> DeviceChain? {
            timeline.document.lanes.first(where: { $0.id == keys.id })?.deviceChain
        }

        timeline.setLaneEffect(keys.id, character: .underwater)
        XCTAssertEqual(chain()?.soundingCharacter, .underwater)
        XCTAssertEqual(chain()?.inserts.first, Self.unknownInsert)
        let written = chain()

        timeline.setLaneEffect(keys.id, character: .underwater)
        XCTAssertEqual(chain(), written, "re-selecting the same effect changes nothing")

        timeline.setLaneEffect(keys.id, character: nil)
        XCTAssertEqual(chain()?.inserts, [Self.unknownInsert], "Default removes the effect, not the unknown insert")
        XCTAssertNil(timeline.document.lanes.first(where: { $0.id == echoel.id })?.deviceChain,
                     "only the chosen track changed")

        timeline.setLaneEffect(UUID(), character: .hall)   // an unknown lane is a no-op, not a crash
        XCTAssertEqual(chain()?.inserts, [Self.unknownInsert])
    }

    // MARK: 4 — the values playback reads

    func testTheChainFlowsLiveAndIsNotStructural() throws {
        let echoel = TimelineLane(name: "MIDI 1", kind: .midi)
        let keys = TimelineLane(name: "Keys", kind: .midi)
        let playing = TimelineDocument(lanes: [echoel, keys], regions: [])
        var edited = playing
        edited.lanes[1].deviceChain = DeviceChain(inserts: [.character(.dream)])

        XCTAssertTrue(TimelineDocument.structurallyEqual(playing, edited),
                      "an effect change must not relocate voices mid-play")
        var snapshot = playing
        XCTAssertTrue(snapshot.mergeMixer(from: edited), "the live merge reports the change")
        XCTAssertEqual(snapshot.lanes[1].deviceChain?.soundingCharacter, .dream)
        XCTAssertFalse(snapshot.mergeMixer(from: edited), "and reports nothing the second time")

        // Slot 0 is the first MIDI lane AFTER the Echoel one — the rack's own rank rule.
        XCTAssertEqual(MultiRollFanout.effect(forSlot: 0, in: edited, rollLane: edited.rollLaneID), .dream)
        XCTAssertNil(MultiRollFanout.effect(forSlot: 0, in: playing, rollLane: playing.rollLaneID))
        XCTAssertNil(MultiRollFanout.effect(forSlot: 1, in: edited, rollLane: edited.rollLaneID),
                     "a slot with no lane plays the default")
    }

    // MARK: 5 — a real chain: the character changes it, the snapshot puts it back

    func testTheSnapshotPutsAPooledSlotBackExactly() {
        let id = UUID()
        for character in TrackMix.effectChoices {
            let chain = EchoelFXChain()
            let snapshot = FXPreset.capture(from: chain, fxEnabled: true, id: id, name: "Lane default")

            XCTAssertTrue(character.applyOwnPreset(to: chain, bpm: 120), "\(character) carries its own preset")
            let changed = FXPreset.capture(from: chain, fxEnabled: true, id: id, name: "Lane default")
            XCTAssertNotEqual(changed, snapshot,
                              "\(character) left the chain untouched — the restore below would prove nothing")

            snapshot.apply(to: chain)
            XCTAssertEqual(FXPreset.capture(from: chain, fxEnabled: true, id: id, name: "Lane default"),
                           snapshot, "the next lane in this slot would inherit \(character)")
        }

        let chain = EchoelFXChain()
        let before = FXPreset.capture(from: chain, fxEnabled: true, id: id, name: "x")
        XCTAssertFalse(FXCharacter.auto.applyOwnPreset(to: chain, bpm: 120))
        XCTAssertEqual(FXPreset.capture(from: chain, fxEnabled: true, id: id, name: "x"), before,
                       "`.auto` has no preset of its own and must touch nothing")
    }

    // MARK: 6 — who sees the row

    func testOnlyAPolyRackTrackOffersAnEffect() throws {
        let bio = TimelineLane(name: "Body", kind: .midi, isBio: true)
        let echoel = TimelineLane(name: "MIDI 1", kind: .midi)
        let poly = TimelineLane(name: "Keys", kind: .midi)
        let sampler = TimelineLane(name: "Hits", kind: .midi, builtinInstrument: .sampler)
        let audio = TimelineLane(name: "Audio 1", kind: .audio)
        let doc = TimelineDocument(lanes: [bio, echoel, poly, sampler, audio], regions: [])

        let polyControls = try XCTUnwrap(TrackMix.controls(of: poly.id, in: doc, voiceCapacity: 4))
        XCTAssertEqual(polyControls.role, .laneSynth(.poly))
        XCTAssertTrue(polyControls.effect)
        for lane in [bio, echoel, sampler, audio] {
            let controls = try XCTUnwrap(TrackMix.controls(of: lane.id, in: doc, voiceCapacity: 4))
            XCTAssertFalse(controls.effect, "\(lane.name) has no per-track chain the row could move")
        }
        // Counterweight: losing the Effect row did not cost these tracks their mixer.
        XCTAssertTrue(try XCTUnwrap(TrackMix.controls(of: sampler.id, in: doc, voiceCapacity: 4)).pan)
        XCTAssertTrue(try XCTUnwrap(TrackMix.controls(of: echoel.id, in: doc, voiceCapacity: 4)).level)
        XCTAssertFalse(try XCTUnwrap(TrackMix.controls(of: poly.id, in: doc, voiceCapacity: 0)).effect,
                       "a track past the rack has no voice and no effect")

        XCTAssertFalse(TrackMix.effectChoices.contains(.auto))
        XCTAssertTrue(TrackMix.effectChoices.contains(.clean), "Clean (dry) is a real choice")
        XCTAssertTrue(TrackMix.effectChoices.allSatisfy { $0.preset != nil })
    }

    // MARK: 7 — the wiring

    func testTheEffectIsPushedWhereverTheOctaveIs() throws {
        let player = try source(Self.playerPath)
        let effect = player.components(separatedBy: "slotEffectSink?(").count - 1
        let octave = player.components(separatedBy: "slotOctaveSink?(").count - 1
        XCTAssertGreaterThanOrEqual(octave, 4, "ANCHOR: the octave pushes moved (#454)")
        XCTAssertEqual(effect, octave, """
            the effect is pushed at \(effect) site(s), the octave at \(octave). Slots are POOLED: \
            a load site that pushes the octave and not the effect lets a track play through the \
            previous track's effect.
            """)
        let mixer = try body(of: "private func refreshMixer()", in: player)
        XCTAssertTrue(mixer.contains("slotEffectSink?("), "a menu change during play must land live")
        XCTAssertTrue(player.contains("MultiRollFanout.effect(forSlot:"))
        // A pooled slot must carry THIS lane's effect before its first note, not after.
        let window = try body(of: "private func loadSecondaryWindow(", in: player)
        guard let push = window.range(of: "slotEffectSink?("),
              let load = window.range(of: "pump.load(") else {
            XCTFail("ANCHOR MISSING: the secondary window's push or load moved (#454)")
            return
        }
        XCTAssertLessThan(push.lowerBound, load.lowerBound,
                          "the effect is pushed after the notes are loaded — the first bar plays the old effect")
    }

    func testTheAppWiresTheRackAndTheRackRestoresItsDefault() throws {
        let app = try source(Self.appPath)
        XCTAssertEqual(app.components(separatedBy: "timelinePlayer.slotEffectSink =").count - 1, 1)
        XCTAssertTrue(app.contains("laneVoiceRack?.setEffect(slot: slot, character: character,"))

        let rack = try source(Self.rackPath)
        let setEffect = try body(of: "public func setEffect(slot: Int, character: FXCharacter?, bpm: Double)", in: rack)
        XCTAssertTrue(setEffect.contains("applyOwnPreset(to: voice.fxChain"))
        XCTAssertTrue(setEffect.contains("defaultEffectBySlot[slot].apply(to: voice.fxChain)"),
                      "no effect = the slot's own default, or a pooled slot keeps the last lane's character")
        let attach = try body(of: "public func attachAll(to audioEngine: AudioEngine)", in: rack)
        XCTAssertTrue(attach.contains("FXPreset.capture(from: $0.fxChain"),
                      "the default is captured at attach, before any lane wrote the chain")
    }

    func testTheInspectorGatesTheRowAndWritesThroughTheStore() throws {
        let inspector = try source(Self.inspectorPath)
        XCTAssertEqual(inspector.components(separatedBy: "timeline.setLaneEffect(").count - 1, 1)
        let gate = try body(of: "if controls.effect", in: inspector)
        XCTAssertTrue(gate.contains("effectRow"))
        XCTAssertEqual(inspector.components(separatedBy: "effectRow").count - 1, 2,
                       "declared once, placed once — inside the gate")
        let row = try body(of: "private var effectRow: some View", in: inspector)
        XCTAssertTrue(row.contains(".pickerStyle(.menu)"), "a named choice is a Picker, not a number field")
        XCTAssertTrue(row.contains("TrackMix.effectChoices"))

        let timeline = try source(Self.timelinePath)
        XCTAssertTrue(timeline.contains("forKey: .deviceChain)"), "the chain decodes from its OWN key")
    }

    // MARK: helpers

    private struct AnchorMissing: Error { let name: String }

    /// The brace-matched body after the first occurrence of `anchor` (#408).
    private func body(of anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor),
              let open = code[start.upperBound...].firstIndex(of: "{") else {
            XCTFail("ANCHOR MISSING: \(anchor) (#454)")
            throw AnchorMissing(name: anchor)
        }
        var depth = 0
        var index = open
        while index < code.endIndex {
            switch code[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return String(code[code.index(after: open)..<index]) }
            default: break
            }
            index = code.index(after: index)
        }
        XCTFail("UNBALANCED: \(anchor)")
        throw AnchorMissing(name: anchor)
    }

    private func repoRoot() -> URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return root
    }

    private func source(_ relativePath: String) throws -> String {
        let url = repoRoot().appendingPathComponent(relativePath)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing(name: relativePath)
        }
        return SourceText.codeOnly(text)
    }
}
