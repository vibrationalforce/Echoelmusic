// AnAudioTrackOffersTheGrainOnItsDevicePageTests.swift
// Echoel — GMMW GA-10d2: Echoel Grain has a door. An AUDIO track's Device page shows a Grain
// switch and, while it is on, the six knobs of the cloud plus the mix, each an `EchoelValueField`.
//
// THE CLAIMS, AND WHICH KIND EACH IS (Tests/CISmoke/CLAUDE.md §1):
// 1. END-TO-END over a REAL `TimelineStore` — `TrackGrain` offers the rows exactly on the
//    player's audio lanes (not a MIDI track, not the body track); On places the default grain
//    with the track's own seed, On again writes nothing; one knob moves one value and keeps the
//    seed, an out-of-range value is clamped; a knob on a track without a grain writes nothing;
//    Off removes the grain and leaves an unknown insert in place.
// 2. END-TO-END — every field's range is the model's own (`GrainSettings.Limits`, #416).
// 3. SOURCE-TEXT SCAN — the Device page mounts the leaf behind `TrackGrain.offered`; the leaf
//    draws seven `EchoelValueField` rows through one helper, no `Slider`/`Stepper`, no modal, and
//    reads nothing but the document; its seven labels are English-only catalog keys.
//
// GRADING (§0/§3): the file names `TrackGrain`, which this commit creates, so it does NOT
// COMPILE against the parent — no assertion has a verdict there (one absence, #486); every claim
// is a FORWARD guard. Counterweights: claim 1's refused tracks, "On again writes nothing", the
// knob on a grainless track, and the kept unknown insert. Claims 1–2 re-derived by hand from
// `TrackGrain` and `setLaneGrain`; claim 3 by `grep` and a Python read of the catalog.
// How the rows READ and FEEL on a phone, and whether VoiceOver speaks them well, is a DEVICE
// PROBE and open (NEEDS-FOUNDER-VERIFY G10 in the leaf's header).

import XCTest
import Foundation
@testable import Echoelmusic

@MainActor
final class AnAudioTrackOffersTheGrainOnItsDevicePageTests: XCTestCase {

    private static let leafPath = "Sources/Echoelmusic/Studio/TrackGrainRows.swift"
    private static let inspectorPath = "Sources/Echoelmusic/Studio/TrackInspectorView.swift"
    private static let catalogPath = "Sources/Echoelmusic/Resources/Localizable.xcstrings"
    private static let labels = ["Position", "Grain length", "Density", "Spray", "Pitch", "Spread", "Mix"]
    private static let unknownInsert = DeviceInsert(typeID: "com.example.future.fx", typeVersion: 2,
                                                    isEnabled: true, stateBlob: Data([4, 5, 6]))

    // MARK: 1 — the rows' actions, on a real store

    func testTheRowsActOnlyOnAnAudioTrackAndKeepItsPattern() {
        let timeline = TimelineStore()
        let original = timeline.document
        defer { timeline.replaceDocument(original) }

        let audio = TimelineLane(name: "Audio 1", kind: .audio,
                                 deviceChain: DeviceChain(inserts: [Self.unknownInsert]))
        let midi = TimelineLane(name: "Keys", kind: .midi)
        let bio = TimelineLane(name: "Body", kind: .audio, isBio: true)
        timeline.replaceDocument(TimelineDocument(lanes: [audio, midi, bio], regions: []))
        let doc = timeline.document
        XCTAssertTrue(TrackGrain.offered(audio.id, in: doc), "an audio track shows the Grain rows")
        XCTAssertFalse(TrackGrain.offered(midi.id, in: doc), "COUNTERWEIGHT: a MIDI track plays no grain")
        XCTAssertFalse(TrackGrain.offered(bio.id, in: doc), "COUNTERWEIGHT: nor the body track")

        TrackGrain.update(audio.id, timeline: timeline) { $0.position = 0.9 }
        XCTAssertNil(TrackGrain.current(audio.id, in: timeline.document),
                     "a knob on a track without a grain writes nothing")

        TrackGrain.setOn(true, laneID: audio.id, timeline: timeline)
        var expected = GrainSettings()
        expected.seed = GrainSettings.trackSeed(audio.id)
        XCTAssertEqual(TrackGrain.current(audio.id, in: timeline.document), expected,
                       "On places the default grain with the track's own pattern")
        let placed = timeline.document
        TrackGrain.setOn(true, laneID: audio.id, timeline: timeline)
        XCTAssertEqual(timeline.document, placed, "On again writes nothing")

        TrackGrain.update(audio.id, timeline: timeline) { $0.pitchSemitones = 7 }
        TrackGrain.update(audio.id, timeline: timeline) { $0.density = 9 }
        let edited = TrackGrain.current(audio.id, in: timeline.document)
        XCTAssertEqual(edited?.pitchSemitones, 7)
        XCTAssertEqual(edited?.density, 1, "an out-of-range value is clamped to the model's range")
        XCTAssertEqual(edited?.position, expected.position, "one knob moves one value")
        XCTAssertEqual(edited?.seed, expected.seed, "and the track keeps its pattern")

        TrackGrain.setOn(false, laneID: audio.id, timeline: timeline)
        XCTAssertNil(TrackGrain.current(audio.id, in: timeline.document), "Off removes the grain")
        XCTAssertEqual(timeline.document.lanes.first(where: { $0.id == audio.id })?.deviceChain?.inserts,
                       [Self.unknownInsert], "COUNTERWEIGHT: and nothing else on the track")

        TrackGrain.setOn(true, laneID: midi.id, timeline: timeline)
        XCTAssertNil(timeline.document.lanes.first(where: { $0.id == midi.id })?.deviceChain,
                     "the writer refuses a track the rows are not offered on")
    }

    // MARK: 2 — the ranges are the model's

    func testEveryFieldRangeIsTheModelsOwn() {
        XCTAssertEqual(TrackGrain.range(GrainSettings.Limits.grainMilliseconds), 10...500)
        XCTAssertEqual(TrackGrain.range(GrainSettings.Limits.pitchSemitones), -24...24)
        XCTAssertEqual(TrackGrain.range(GrainSettings.Limits.spraySeconds), 0...0.5)
        XCTAssertEqual(TrackGrain.range(GrainSettings.Limits.mix), 0...1)
    }

    // MARK: 3 — the door, the leaf's shape, the catalog

    func testTheDevicePageMountsTheLeafAndItsLabelsAreCatalogued() throws {
        let inspector = try source(Self.inspectorPath)
        XCTAssertTrue(inspector.contains("if TrackGrain.offered(laneID, in: document) {\n                        TrackGrainRows(laneID: laneID)"),
                      "the Device page mounts the Grain rows behind the player's own audio-lane predicate")
        XCTAssertEqual(inspector.components(separatedBy: "TrackGrainRows(").count - 1, 1, "one door")

        let leaf = try source(Self.leafPath)
        XCTAssertEqual(leaf.components(separatedBy: "EchoelValueField(").count - 1, 1,
                       "every knob goes through the one field helper")
        for label in Self.labels {
            XCTAssertTrue(leaf.contains("field(\"\(label)\""), "the `\(label)` row is missing")
        }
        XCTAssertEqual(leaf.components(separatedBy: "field(\"").count - 1, Self.labels.count,
                       "seven rows: six knobs of the cloud and the mix")
        for banned in ["Slider(", "Stepper(", ".sheet(", ".fullScreenCover(", ".alert(", ".popover("] {
            XCTAssertFalse(leaf.contains(banned), "`\(banned)` in the Grain rows — numbers use EchoelValueField, and no modal")
        }
        XCTAssertTrue(leaf.contains("timeline.setLaneGrain(laneID, settings:"), "writes go through the one writer")
        XCTAssertFalse(leaf.contains("@Environment(PatternEngine") || leaf.contains("masterLevel")
                       || leaf.contains("latestBio"), "the leaf reads no hot state")

        let url = repoRoot().appendingPathComponent(Self.catalogPath)
        let catalog = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])
        for label in Self.labels + ["Grain"] {
            let entry = strings[label] as? [String: Any]
            let locs = entry?["localizations"] as? [String: Any]
            let unit = (locs?["en"] as? [String: Any])?["stringUnit"] as? [String: Any]
            XCTAssertEqual(locs.map { Set($0.keys) }, Set(["en"]), "`\(label)` is not an English-only catalog key")
            XCTAssertEqual(unit?["value"] as? String, label)
            XCTAssertEqual(unit?["state"] as? String, "translated")
        }
    }

    // MARK: helpers

    private func repoRoot() -> URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return root
    }

    private func source(_ relativePath: String) throws -> String {
        let text = try String(contentsOf: repoRoot().appendingPathComponent(relativePath), encoding: .utf8)
        return SourceText.codeOnly(text)
    }
}
