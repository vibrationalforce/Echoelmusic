// TheEchoelIsAnInstanceOnItsTrackTests.swift
// Echoel — Phase 3 / EF1: "Echoel as flagship Device", first slice (plan
// `scratchpads/PLAN_ECHOEL_DEVICE_2026-09-26.md`). The song carries its Echoel: the track the
// Echoel plays (`rollLaneID`) holds an instrument insert of type `com.echoelmusic.device.echoel`
// (WA3 §A.2), and that instance — not the app-global `@AppStorage` key — owns the Echoel's FX
// character. The key stays as the instrument's working copy and is ADOPTED from the song.
//
// WHAT IT PINS.
// 1. PURE (`DeviceInsert`): the instance round-trips its FX character; a LATER `typeVersion`, another
//    type and a state that is not the v1 shape are not read AND not rewritten (the song keeps a
//    later build's instance byte for byte); a rewrite keeps every field it does not own; a name
//    this build does not know reads as nil but stays rewritable.
// 2. PURE (`DeviceChain`): choosing or removing a track EFFECT never touches the instrument; a
//    chain holding only an instrument is not empty.
// 3. DECODE: a chain without an instrument writes no `instrument` key (the DC1 bytes); one that is
//    not an insert costs the instance, never the chain's inserts.
// 4. END-TO-END over a REAL `TimelineStore`: the writer writes the roll lane only, moves a stale
//    instance off another lane in the same write, re-states nothing, refuses a later build's
//    instance, and writes nothing in a song without a MIDI track.
// 5. PLAYBACK VALUES: the instance change is mixer-only (no relocate) and never reaches a rack
//    slot's effect; the document reads the instance on the roll lane only.
// 6. WHO SEES THE ROW (`TrackMix.controls`): the Echoel track, only once the song holds a readable
//    instance; its choices start with `.auto` (the Echoel owns a genre).
// 7. SOURCE-TEXT SCAN: the four sync points in `EchoelStudioView` — the Effects Picker and
//    `open(_:)` write the owner; `adoptEchoelFXFromSong()` runs at launch, after `restoreSong` in
//    `openFromLibrary`, and on the `"fxCharacter"` edit — and the inspector writes the store
//    BEFORE it posts that edit.
//
// HONEST GRADING (§3), against the parent tree (`eaebb40cf`): the file does NOT compile there —
// `DeviceInsert.echoelTypeID`, `DeviceChain.instrument`, `TimelineStore.setEchoelFXCharacter`,
// `TimelineDocument.echoelFXCharacter` and `TrackMix.echoelEffectChoices` are all new — so no
// assertion has a verdict on the parent. Every claim is a FORWARD guard; one absence (#486).
// Counterweights (#343): claim 2 asserts the DC1 effect still sounds beside the instrument; claim 5
// asserts the rack slot's effect is unchanged by an instance write; claim 6 asserts a rack track's
// row is untouched. Graded by Python transcription of the store writer, `settingEchoelFX`, and
// every scan anchor against the worktree.
//
// NOT HERE — DEVICE PROBE, open. That the chosen character is HEARD, that relaunch keeps it, and
// that Save → Open another song → Open back restores each song's own Echoel effect.
// NEEDS-FOUNDER-VERIFY: Workstation → tap the Echoel track → Effect: Underwater → the instrument
// sounds submerged and the Studio's Effects panel shows Underwater. Relaunch: still Underwater.
// Save the song, set Effect: Hall, Save as another song, Open the first: Underwater again.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheEchoelIsAnInstanceOnItsTrackTests: XCTestCase {

    private static let studioPath = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let inspectorPath = "Sources/Echoelmusic/Studio/TrackInspectorView.swift"

    /// A later build's Echoel instance: same type, a format this build does not read.
    private static let laterEchoel = DeviceInsert(
        typeID: DeviceInsert.echoelTypeID, typeVersion: 2, isEnabled: true,
        stateBlob: Data("{\"fx\":{\"name\":\"hall\"}}".utf8))

    // MARK: 1 — the instance's own answers

    func testTheInstanceCarriesItsCharacterAndNothingItCannotRead() throws {
        let fresh = DeviceInsert.echoel(fxCharacter: .underwater)
        XCTAssertEqual(fresh.typeID, "com.echoelmusic.device.echoel", "WA3 §A.2 names this type")
        XCTAssertEqual(fresh.typeVersion, DeviceInsert.echoelTypeVersion)
        XCTAssertEqual(fresh.echoelFXCharacter, .underwater)
        XCTAssertEqual(DeviceInsert.echoel(fxCharacter: .auto).echoelFXCharacter, .auto,
                       "`.auto` IS the Echoel's choice — it owns a genre")

        XCTAssertNil(Self.laterEchoel.echoelFXCharacter, "a later format is not read with v1 meaning")
        XCTAssertNil(Self.laterEchoel.settingEchoelFX(.room), "…and never rewritten with it")
        XCTAssertNil(DeviceInsert.character(.room).echoelFXCharacter, "an effect insert is not the Echoel")
        XCTAssertNil(DeviceInsert.character(.room).settingEchoelFX(.room))
        let notV1 = DeviceInsert(typeID: DeviceInsert.echoelTypeID, typeVersion: 1, isEnabled: true,
                                 stateBlob: Data([0x00, 0xFF]))
        XCTAssertNil(notV1.echoelFXCharacter)
        XCTAssertNil(notV1.settingEchoelFX(.room), "a state that is not the v1 shape is kept, not replaced")

        // A later build's EXTRA field inside a v1 state survives a rewrite.
        let extended = DeviceInsert(typeID: DeviceInsert.echoelTypeID, typeVersion: 1, isEnabled: true,
                                    stateBlob: Data("{\"fxCharacter\":\"vinyl\",\"patch\":\"Glass\"}".utf8))
        let rewritten = try XCTUnwrap(extended.settingEchoelFX(.dream))
        XCTAssertEqual(rewritten.echoelFXCharacter, .dream)
        XCTAssertEqual(rewritten.id, extended.id, "the instance keeps its identity")
        let fields = try JSONDecoder().decode([String: String].self, from: rewritten.stateBlob)
        XCTAssertEqual(fields["patch"], "Glass", "a field this build does not own is kept")

        // A character name this build does not know (a removed case) reads as nil and is rewritable.
        let retired = DeviceInsert(typeID: DeviceInsert.echoelTypeID, typeVersion: 1, isEnabled: true,
                                   stateBlob: Data("{\"fxCharacter\":\"harmonizer\"}".utf8))
        XCTAssertNil(retired.echoelFXCharacter)
        XCTAssertEqual(retired.settingEchoelFX(.clean)?.echoelFXCharacter, .clean)

        // One state, one byte form: re-stating the value is an equality, not a write.
        XCTAssertEqual(fresh.settingEchoelFX(.underwater), fresh)
    }

    // MARK: 2 — the effect writer never touches the instrument

    func testTheTrackEffectAndTheInstrumentAreIndependent() throws {
        var chain = DeviceChain(inserts: [])
        XCTAssertTrue(chain.isEmpty)
        chain.instrument = .echoel(fxCharacter: .cassette)
        XCTAssertFalse(chain.isEmpty, "a chain holding only an instrument is stored")

        let withEffect = try XCTUnwrap(chain.settingCharacter(.hall))
        XCTAssertEqual(withEffect.instrument, chain.instrument)
        XCTAssertEqual(withEffect.soundingCharacter, .hall, "the DC1 effect still sounds beside it")
        let withoutEffect = try XCTUnwrap(withEffect.settingCharacter(nil),
                                          "removing the effect must not remove the instance")
        XCTAssertEqual(withoutEffect.instrument, chain.instrument)
        XCTAssertTrue(withoutEffect.inserts.isEmpty)
        XCTAssertNil(DeviceChain(inserts: []).settingCharacter(nil), "nothing left → no chain, as in DC1")
    }

    // MARK: 3 — decode

    func testAChainWithoutAnInstrumentWritesTheDC1Bytes() throws {
        let plain = TimelineLane(name: "Keys", kind: .midi,
                                 deviceChain: DeviceChain(inserts: [.character(.hall)]))
        let object = try laneJSON(plain)
        let chain = try XCTUnwrap(object["deviceChain"] as? [String: Any])
        XCTAssertNil(chain["instrument"], "no instance → no key; a DC1 song keeps its bytes")

        var echoel = TimelineLane(name: "MIDI 1", kind: .midi)
        var owned = DeviceChain(inserts: [])
        owned.instrument = .echoel(fxCharacter: .megaphone)
        echoel.deviceChain = owned
        let back = try JSONDecoder().decode(TimelineLane.self, from: JSONEncoder().encode(echoel))
        XCTAssertEqual(back.deviceChain, owned)
        XCTAssertEqual(back.deviceChain?.instrument?.echoelFXCharacter, .megaphone)

        var broken = try laneJSON(TimelineLane(name: "Keys", kind: .midi,
                                               deviceChain: DeviceChain(inserts: [.character(.room)])))
        var brokenChain = try XCTUnwrap(broken["deviceChain"] as? [String: Any])
        brokenChain["instrument"] = "not an insert"
        broken["deviceChain"] = brokenChain
        let decoded = try JSONDecoder().decode(TimelineLane.self,
                                               from: JSONSerialization.data(withJSONObject: broken))
        XCTAssertNil(decoded.deviceChain?.instrument)
        XCTAssertEqual(decoded.deviceChain?.soundingCharacter, .room,
                       "an unreadable instance costs the instance, never the inserts")
    }

    // MARK: 4 — the one writer, on a real store

    func testTheStoreWritesTheInstanceOnTheTrackTheEchoelPlays() throws {
        let timeline = TimelineStore()
        let original = timeline.document
        defer { timeline.replaceDocument(original) }

        let bio = TimelineLane(name: "Body", kind: .midi, isBio: true)
        let echoel = TimelineLane(name: "MIDI 1", kind: .midi)
        var stale = DeviceChain(inserts: [.character(.vinyl)])
        stale.instrument = .echoel(fxCharacter: .telephone)
        let keys = TimelineLane(name: "Keys", kind: .midi, deviceChain: stale)
        timeline.replaceDocument(TimelineDocument(lanes: [bio, echoel, keys], regions: []))
        func lane(_ id: UUID) -> TimelineLane? { timeline.document.lanes.first { $0.id == id } }

        timeline.setEchoelFXCharacter(.underwater)
        XCTAssertEqual(timeline.document.echoelFXCharacter, .underwater)
        XCTAssertEqual(lane(echoel.id)?.deviceChain?.instrument?.echoelFXCharacter, .underwater)
        XCTAssertNil(lane(bio.id)?.deviceChain, "a bio lane never holds the Echoel")
        XCTAssertNil(lane(keys.id)?.deviceChain?.instrument, "one instance per song — the stale one moved")
        XCTAssertEqual(lane(keys.id)?.deviceChain?.soundingCharacter, .vinyl,
                       "moving the instance leaves that track's own effect alone")

        let written = timeline.document
        timeline.setEchoelFXCharacter(.underwater)
        XCTAssertEqual(timeline.document, written, "re-stating the same character writes nothing")

        // A later build's instance on the roll lane is kept, not overwritten.
        var later = DeviceChain(inserts: [])
        later.instrument = Self.laterEchoel
        timeline.replaceDocument(TimelineDocument(
            lanes: [TimelineLane(id: echoel.id, name: "MIDI 1", kind: .midi, deviceChain: later)],
            regions: []))
        timeline.setEchoelFXCharacter(.room)
        XCTAssertEqual(lane(echoel.id)?.deviceChain?.instrument, Self.laterEchoel)
        XCTAssertNil(timeline.document.echoelFXCharacter)

        // A song with no MIDI track has nowhere to hold the instance.
        let audioOnly = TimelineDocument(lanes: [TimelineLane(name: "Audio 1", kind: .audio)], regions: [])
        timeline.replaceDocument(audioOnly)
        timeline.setEchoelFXCharacter(.hall)
        XCTAssertEqual(timeline.document, audioOnly)
    }

    // MARK: 5 — what playback reads

    func testTheInstanceIsMixerOnlyAndNeverAnotherTracksEffect() {
        let echoel = TimelineLane(name: "MIDI 1", kind: .midi)
        let keys = TimelineLane(name: "Keys", kind: .midi)
        let playing = TimelineDocument(lanes: [echoel, keys], regions: [])
        var edited = playing
        var owned = DeviceChain(inserts: [])
        owned.instrument = .echoel(fxCharacter: .dream)
        edited.lanes[0].deviceChain = owned

        XCTAssertTrue(TimelineDocument.structurallyEqual(playing, edited),
                      "an Echoel effect change must not relocate voices mid-play")
        XCTAssertEqual(edited.echoelFXCharacter, .dream)
        XCTAssertNil(playing.echoelFXCharacter)
        XCTAssertNil(MultiRollFanout.effect(forSlot: 0, in: edited, rollLane: edited.rollLaneID),
                     "the rack slot plays its own effect, never the Echoel's")

        // Only the roll lane is read: an instance on another lane is not the Echoel's.
        var misplaced = playing
        misplaced.lanes[1].deviceChain = owned
        XCTAssertNil(misplaced.echoelFXCharacter)
    }

    // MARK: 6 — who sees the row

    func testTheEchoelTrackOffersItsEffectOnlyOnceTheSongHoldsIt() throws {
        let echoel = TimelineLane(name: "MIDI 1", kind: .midi)
        let keys = TimelineLane(name: "Keys", kind: .midi)
        let bare = TimelineDocument(lanes: [echoel, keys], regions: [])
        var held = bare
        var owned = DeviceChain(inserts: [])
        owned.instrument = .echoel(fxCharacter: .auto)
        held.lanes[0].deviceChain = owned

        let without = try XCTUnwrap(TrackMix.controls(of: echoel.id, in: bare, voiceCapacity: 4))
        XCTAssertEqual(without.role, .echoelInstrument)
        XCTAssertFalse(without.effect, "no instance yet → no row that would guess its value")
        let with = try XCTUnwrap(TrackMix.controls(of: echoel.id, in: held, voiceCapacity: 4))
        XCTAssertTrue(with.effect)
        XCTAssertFalse(with.pan, "the Echoel track still has no pan consumer")
        XCTAssertTrue(try XCTUnwrap(TrackMix.controls(of: keys.id, in: held, voiceCapacity: 4)).effect,
                      "the rack track's own row is untouched")

        XCTAssertEqual(TrackMix.echoelEffectChoices.first, .auto)
        XCTAssertEqual(Set(TrackMix.echoelEffectChoices), Set(FXCharacter.allCases))
    }

    // MARK: 7 — the sync points

    func testEveryWriterOfTheWorkingCopyWritesTheSongAndEveryReaderAdopts() throws {
        let studio = try source(Self.studioPath)
        XCTAssertEqual(studio.components(separatedBy: "adoptEchoelFXFromSong()").count - 1, 4,
                       "declared once + launch + after a library Open + the \"fxCharacter\" edit")
        let adopt = try body(of: "private func adoptEchoelFXFromSong()", in: studio)
        XCTAssertTrue(adopt.contains("timelineStore.document.echoelFXCharacter"),
                      "the song is read in a FUNCTION, never in `body` (the freeze law)")
        XCTAssertTrue(adopt.contains("timelineStore.setEchoelFXCharacter(fxCharacter)"),
                      "a song from before EF1 imports the working copy once")
        XCTAssertTrue(adopt.contains("applyFX()"), "an adopted change is SOUNDED, not only shown")

        let fromLibrary = try body(of: "private func openFromLibrary(_ p: Project)", in: studio)
        guard let restore = fromLibrary.range(of: "SessionSaveOpen.restoreSong("),
              let adoption = fromLibrary.range(of: "adoptEchoelFXFromSong()") else {
            return XCTFail("ANCHOR MISSING: openFromLibrary's restore or adoption (#454)")
        }
        XCTAssertLessThan(restore.lowerBound, adoption.lowerBound,
                          "adopt AFTER the song is replaced, or the old song's Echoel wins")

        let open = try body(of: "private func open(_ p: Project)", in: studio)
        guard let copy = open.range(of: "fxCharacter = p.fxCharacter"),
              let owner = open.range(of: "timelineStore.setEchoelFXCharacter(p.fxCharacter)") else {
            return XCTFail("ANCHOR MISSING: open(_:)'s FX write (#454)")
        }
        XCTAssertLessThan(copy.lowerBound, owner.lowerBound)
        if let rescue = open.range(of: "autosaveTake()") {
            XCTAssertLessThan(rescue.lowerBound, owner.lowerBound,
                              "the rescue records the song BEFORE its Echoel is rewritten")
        } else {
            XCTFail("ANCHOR MISSING: open(_:)'s rescue (#454)")
        }

        let picker = try body(of: ".onChange(of: fxCharacter)", in: studio)
        XCTAssertTrue(picker.contains("timelineStore.setEchoelFXCharacter(picked)"),
                      "the Effects panel's pick lands on the song first")

        let edit = try body(of: "private func handleCompositionEdit(_ field: String?)", in: studio)
        XCTAssertTrue(edit.contains("case \"fxCharacter\":"))

        let inspector = try source(Self.inspectorPath)
        let setter = try body(of: "static func setEchoelEffect(_ character: FXCharacter, timeline: TimelineStore)",
                              in: inspector)
        guard let write = setter.range(of: "timeline.setEchoelFXCharacter(character)"),
              let post = setter.range(of: "NotificationCenter.default.post(name: .echoelCompositionEdited, object: \"fxCharacter\")") else {
            return XCTFail("ANCHOR MISSING: the inspector's Echoel effect writer (#454)")
        }
        XCTAssertLessThan(write.lowerBound, post.lowerBound,
                          "the Studio adopts from the song, so the song must be written first")
        let row = try body(of: "private var echoelEffectRow: some View", in: inspector)
        XCTAssertTrue(row.contains(".pickerStyle(.menu)"), "a named choice is a Picker, not a number field")
        XCTAssertTrue(row.contains("TrackMix.setEchoelEffect("))
    }

    // MARK: helpers

    private struct AnchorMissing: Error { let name: String }

    private func laneJSON(_ lane: TimelineLane) throws -> [String: Any] {
        let data = try JSONEncoder().encode(lane)
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

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
