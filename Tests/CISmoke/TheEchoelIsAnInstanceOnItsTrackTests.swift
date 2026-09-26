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
//    `open(_:)` write the owner; `adoptEchoelFXFromSong()` runs at launch (right after the genre
//    clamp), after `restoreSong` in `openFromLibrary`, and on the `"fxCharacter"` edit — the
//    inspector writes the store BEFORE it posts that edit, and asks for a missing instance when
//    the Echoel track opens (a first MIDI track added after launch).
//
// 8./9. EF2 (the genre as the instance's second fact): pure + real store (one instance, two
//    facts; the Genre row only once the song holds the genre), and a SCAN of every genre writer —
//    the genre case writes the song first (header Picker + OSC remote), the Workstation posts
//    "echoelGenre" (never "genre", which would write the OLD copy back), launch adopts the genre
//    before the FX character and silently, `openFromLibrary` silently after the restore, `open(_:)`
//    and the Sound reset write the song.
//    EF2 GRADING, against `fce169210`: the file does NOT compile there (`echoelGenre`,
//    `settingEchoelGenre`, `TimelineStore.setEchoelGenre`, `Controls.genre`,
//    `TrackMix.pickEchoelGenre` are new) — every EF2 claim is a FORWARD guard, one absence (#486).
//    Claim 7's request needle was RE-ANCHORED in the same commit: the body now accepts an empty
//    slot OR an instance this build reads (a fact was added, none removed). Graded by Python
//    transcription of every claim-7/9 scan against the worktree: all green.
//
// REVIEW OF 6d68bea64 (no HIGH): M3 (a roll lane that appears after launch had no instance and
// no row) is repaired by `TrackMix.requestEchoelInstanceIfMissing`; L3/L4 sharpened claims 5/7.
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
// NEEDS-FOUNDER-VERIFY: EF2 — Workstation → Echoel track → Genre: pick another genre → the header
// shows it, the instrument recomposes in it; relaunch keeps it; Open a song saved in another
// genre → that song's genre returns, its saved notes are NOT recomposed.

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
        // Only the roll lane is read: an instance on another lane is not the Echoel's — and a
        // rack slot whose lane carries an instrument insert plays no effect from it (review of
        // 6d68bea64, L3: the first form asserted this on a lane with no chain at all, where it
        // could not fail).
        var misplaced = playing
        misplaced.lanes[1].deviceChain = owned
        XCTAssertNil(misplaced.echoelFXCharacter)
        XCTAssertNil(MultiRollFanout.effect(forSlot: 0, in: misplaced, rollLane: misplaced.rollLaneID),
                     "a rack slot reads its INSERTS, never an instrument instance")
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
        // The launch adoption sits AFTER the genre clamp (an adoption re-stamps the FX room from
        // `style`) — review of 6d68bea64, L4: the count alone survives moving it anywhere.
        guard let clamp = studio.range(of: "style = StudioDefaultKeys.genre.value"),
              let launch = studio.range(of: "adoptEchoelFXFromSong()", range: clamp.upperBound..<studio.endIndex),
              let decl = studio.range(of: "private func adoptEchoelFXFromSong()") else {
            return XCTFail("ANCHOR MISSING: the launch genre clamp or the launch adoption (#454)")
        }
        XCTAssertLessThan(launch.lowerBound, decl.lowerBound, "the first adoption after the clamp is the launch call")
        let gap = studio[clamp.upperBound..<launch.lowerBound].components(separatedBy: "\n").count
        XCTAssertLessThan(gap, 12, "the launch adoption follows the genre clamp directly")

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
        // Review of 6d68bea64, M3: a first MIDI track added after launch has no instance, so the
        // inspector asks the instrument to state it — only for an EMPTY slot, never over a later
        // build's instance.
        let request = try body(of: "static func requestEchoelInstanceIfMissing(", in: inspector)
        XCTAssertTrue(request.contains("== .echoelInstrument"))
        XCTAssertTrue(request.contains("instrument == nil || instrument?.echoelFields != nil"))
        XCTAssertTrue(request.contains("object: \"fxCharacter\")"))
        let appear = try body(of: ".onAppear", in: inspector)
        XCTAssertTrue(appear.contains("TrackMix.requestEchoelInstanceIfMissing("))

        let row = try body(of: "private var echoelEffectRow: some View", in: inspector)
        XCTAssertTrue(row.contains(".pickerStyle(.menu)"), "a named choice is a Picker, not a number field")
        XCTAssertTrue(row.contains("TrackMix.setEchoelEffect("))
    }

    // MARK: 8 — EF2: the genre is the instance's second fact

    func testTheGenreIsASecondFactOfTheSameInstance() throws {
        let fxOnly = DeviceInsert.echoel(fxCharacter: .vinyl)
        XCTAssertNil(fxOnly.echoelGenre, "an EF1 instance carries no genre yet")
        let both = try XCTUnwrap(fxOnly.settingEchoelGenre(.selfObservation))
        XCTAssertEqual(both.echoelGenre, .selfObservation)
        XCTAssertEqual(both.echoelFXCharacter, .vinyl, "setting the genre keeps the FX character")
        XCTAssertEqual(both.id, fxOnly.id)
        XCTAssertEqual(try XCTUnwrap(both.settingEchoelFX(.hall)).echoelGenre, .selfObservation,
                       "and setting the FX character keeps the genre")
        XCTAssertNil(Self.laterEchoel.settingEchoelGenre(.selfObservation), "never over a later format")
        let unknown = DeviceInsert(typeID: DeviceInsert.echoelTypeID, typeVersion: 1, isEnabled: true,
                                   stateBlob: Data("{\"genre\":\"notAGenreThisBuildKnows\"}".utf8))
        XCTAssertNil(unknown.echoelGenre)
        XCTAssertEqual(unknown.settingEchoelGenre(.selfObservation)?.echoelGenre, .selfObservation)
    }

    func testTheStoreWritesTheGenreBesideTheEffect() throws {
        let timeline = TimelineStore()
        let original = timeline.document
        defer { timeline.replaceDocument(original) }

        let echoel = TimelineLane(name: "MIDI 1", kind: .midi)
        timeline.replaceDocument(TimelineDocument(lanes: [echoel], regions: []))
        timeline.setEchoelFXCharacter(.cassette)
        XCTAssertNil(timeline.document.echoelGenre)
        let fxOnly = try XCTUnwrap(TrackMix.controls(of: echoel.id, in: timeline.document, voiceCapacity: 4))
        XCTAssertTrue(fxOnly.effect)
        XCTAssertFalse(fxOnly.genre, "no genre in the song yet → no Genre row that would guess it")

        timeline.setEchoelGenre(.selfObservation)
        XCTAssertEqual(timeline.document.echoelGenre, .selfObservation)
        XCTAssertEqual(timeline.document.echoelFXCharacter, .cassette, "one instance, two facts")
        XCTAssertEqual(timeline.document.lanes.first?.deviceChain?.instrument?.typeID,
                       DeviceInsert.echoelTypeID)
        XCTAssertTrue(try XCTUnwrap(TrackMix.controls(of: echoel.id, in: timeline.document,
                                                      voiceCapacity: 4)).genre)

        let written = timeline.document
        timeline.setEchoelGenre(.selfObservation)
        XCTAssertEqual(timeline.document, written, "re-stating the genre writes nothing")
    }

    // MARK: 9 — EF2: every writer of the genre's working copy writes the song

    func testEveryGenreWriterWritesTheSongAndTheWorkstationEditIsAUserEdit() throws {
        let studio = try source(Self.studioPath)
        let edit = try body(of: "private func handleCompositionEdit(_ field: String?)", in: studio)
        guard let genreCase = edit.range(of: "case \"genre\":"),
              let write = edit.range(of: "timelineStore.setEchoelGenre(style)", range: genreCase.upperBound..<edit.endIndex),
              let scale = edit.range(of: "scale = style.scale", range: genreCase.upperBound..<edit.endIndex) else {
            return XCTFail("ANCHOR MISSING: the genre case's owner write (#454)")
        }
        XCTAssertLessThan(write.lowerBound, scale.lowerBound,
                          "the header Picker and the OSC remote reach the song through this case, first")
        XCTAssertTrue(edit.contains("case \"echoelGenre\":"))
        XCTAssertTrue(edit.contains("adoptEchoelGenreFromSong(announce: true)"),
                      "the Workstation's genre is a user edit: full genre semantics, recompose included")

        let adopt = try body(of: "private func adoptEchoelGenreFromSong(announce: Bool)", in: studio)
        XCTAssertTrue(adopt.contains("MusicStyle.offered.contains(songGenre)"),
                      "an un-offered song genre is replaced, never adopted into an unreachable row")
        XCTAssertTrue(adopt.contains("if announce { handleCompositionEdit(\"genre\") }"))
        XCTAssertTrue(adopt.contains("timelineStore.setEchoelGenre(style)"))

        // Launch: the genre is adopted BEFORE the FX character (whose stamp reads `style`), silently.
        guard let clamp = studio.range(of: "style = StudioDefaultKeys.genre.value"),
              let genreAdopt = studio.range(of: "adoptEchoelGenreFromSong(announce: false)", range: clamp.upperBound..<studio.endIndex),
              let fxAdopt = studio.range(of: "adoptEchoelFXFromSong()", range: clamp.upperBound..<studio.endIndex) else {
            return XCTFail("ANCHOR MISSING: the launch adoptions (#454)")
        }
        XCTAssertLessThan(genreAdopt.lowerBound, fxAdopt.lowerBound)

        let fromLibrary = try body(of: "private func openFromLibrary(_ p: Project)", in: studio)
        guard let restore = fromLibrary.range(of: "SessionSaveOpen.restoreSong("),
              let silent = fromLibrary.range(of: "adoptEchoelGenreFromSong(announce: false)") else {
            return XCTFail("ANCHOR MISSING: openFromLibrary's genre adoption (#454)")
        }
        XCTAssertLessThan(restore.lowerBound, silent.lowerBound,
                          "silent, after the song is replaced — a loaded take is never recomposed away")

        let open = try body(of: "private func open(_ p: Project)", in: studio)
        XCTAssertTrue(open.contains("timelineStore.setEchoelGenre(openStyle)"))
        let reset = try body(of: "private func resetSoundToDefaults()", in: studio)
        XCTAssertTrue(reset.contains("timelineStore.setEchoelGenre(StudioDefaultKeys.genre.value)"),
                      "a reset the song does not follow is undone by the next launch's adoption")

        let inspector = try source(Self.inspectorPath)
        let setter = try body(of: "static func pickEchoelGenre(_ genre: MusicStyle, timeline: TimelineStore)", in: inspector)
        guard let store = setter.range(of: "timeline.setEchoelGenre(genre)"),
              let post = setter.range(of: "object: \"echoelGenre\")") else {
            return XCTFail("ANCHOR MISSING: the inspector's genre writer (#454)")
        }
        XCTAssertLessThan(store.lowerBound, post.lowerBound)
        XCTAssertFalse(setter.contains("object: \"genre\")"),
                       "posting \"genre\" would re-derive from the OLD working copy and write it back over the edit")
        let request = try body(of: "static func requestEchoelInstanceIfMissing(", in: inspector)
        XCTAssertTrue(request.contains("object: \"echoelGenre\")"), "an EF1 song gains its genre on first open")
        let row = try body(of: "private var echoelGenreRow: some View", in: inspector)
        XCTAssertTrue(row.contains("MusicStyle.Subcategory.allCases"), "the header's own curated root")
        XCTAssertTrue(row.contains("shelf.offeredGenres"))
        XCTAssertTrue(row.contains(".pickerStyle(.menu)"))
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
