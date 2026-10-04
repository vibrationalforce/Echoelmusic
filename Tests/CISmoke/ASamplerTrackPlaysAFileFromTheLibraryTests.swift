//
//  ASamplerTrackPlaysAFileFromTheLibraryTests.swift
//  Restructure E13-1 (founder 2026-10-04: „Beats aus Samples und Video als musikalisches Material
//  gehören bereits zum DMMW-Ziel. Plane dafür jeweils den kleinsten vollständigen Nutzerweg.")
//
//  The engine half was built and doorless: `TimelineLane.samplePath` persists, the region player
//  hands it to the rack (`slotSampleSink` → `LaneVoiceRack.setSample`), and the rack's sampler unit
//  plays it pitched by the note — but `TimelineStore.setLaneSample` had NO caller, so the inspector
//  did not offer the Sampler at all ("it needs a sample before it sounds — this row assigns none").
//  The inspector now offers it together with `TrackSampleRow`, which picks a library file.
//
//  WHAT THIS PINS, by kind (Tests/CISmoke/CLAUDE.md §1):
//  · END-TO-END BEHAVIOUR (claims 1–2) — `TimelineStore`, `TimelineLane`, `TrackMix` and
//    `TrackInstrument` are shipped. Claim 1: a pick is ONE Undo step, a pick of what the track
//    already plays is none, and Undo gives the earlier sample back. Claim 2: the Sampler is offered
//    and plays on the sampler voice.
//  · SOURCE-TEXT SCAN (claims 3–4) — `TrackSampleRow` and `TrackInspectorView` are `View`s: the row
//    is mounted ONLY while the track plays the Sampler (the law the old assertion carried, kept),
//    writes through the one writer inside `editLaneSample`, and lists the library off the main
//    actor. Claim 4's counterweight pins the root note its "Middle C plays it as recorded" says.
//  · DEVICE PROBE, OPEN — that a picked file SOUNDS on a MIDI part and again after reopening: G7
//    in `docs/dev/FOUNDER_INBOX.md`.
//
//  GRADING against the parent tree (#433/#464): the file does NOT compile there — it calls
//  `editLaneSample(id:_:)`, created by this commit — so no assertion has a verdict on the parent
//  (ONE absence, #486). Claims 1–2 are FORWARD guards transcribed by reading `editLaneSample`,
//  `apply(.laneSample)` and `instrumentChoices`; claims 3–4's needles were grepped against the
//  worktree. COUNTERWEIGHTS (#343): claim 1's no-op pick, claim 2's voice kind, claim 4's root note.
//
//  `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class ASamplerTrackPlaysAFileFromTheLibraryTests: XCTestCase {

    private static let row = "Sources/Echoelmusic/Studio/TrackSampleRow.swift"
    private static let inspector = "Sources/Echoelmusic/Studio/TrackInspectorView.swift"
    private static let rack = "Sources/Echoelmusic/Sequencer/LaneVoiceRack.swift"

    // MARK: 1 — a pick is one Undo step, and Undo gives the earlier sample back

    func testAPickIsOneUndoStep() {
        let timeline = TimelineStore()
        let original = timeline.document
        defer { timeline.replaceDocument(original) }

        let lane = TimelineLane(name: "Hits", kind: .midi, builtinInstrument: .sampler)
        timeline.replaceDocument(TimelineDocument(lanes: [lane], regions: []))
        XCTAssertFalse(timeline.canUndo, "premise: replacing the piece clears the history")

        // COUNTERWEIGHT: a pick of what the track already plays is not an edit.
        timeline.editLaneSample(id: lane.id) { timeline.setLaneSample(lane.id, path: nil) }
        XCTAssertFalse(timeline.canUndo, "a pick of the same sample records no step")

        let kick = "/Media/Audio/Kick.wav"
        timeline.editLaneSample(id: lane.id) { timeline.setLaneSample(lane.id, path: kick) }
        XCTAssertEqual(timeline.document.lanes.first?.samplePath, kick, "the pick lands on the lane")
        XCTAssertTrue(timeline.canUndo, "the pick is an Undo step")

        timeline.undo()
        XCTAssertNil(timeline.document.lanes.first?.samplePath, """
            Undo did not give the earlier sample back. A sample pick must be one `.laneSample` step \
            written back through `setLaneSample`, so the region player re-loads it as a pick does.
            """)
    }

    // MARK: 2 — the Sampler is offered on a rack track and plays on the sampler voice

    func testTheSamplerIsOfferedAndPlaysOnItsVoice() {
        XCTAssertTrue(TrackMix.instrumentChoices(.laneSynth(.poly)).contains(.sampler),
                      "a rack track offers the Sampler, together with its Sample row")
        XCTAssertEqual(TrackInstrument.sampler.voiceKind, .sampler,
                       "COUNTERWEIGHT: the choice binds the rack's sampler unit, the voice that loads the sample")
        XCTAssertEqual(TrackMix.instrumentChoices(.echoelInstrument), [],
                       "COUNTERWEIGHT: never on the Echoel track")
    }

    // MARK: 3 — the row exists only for the Sampler, and writes through the one writer

    func testTheRowIsMountedOnlyForTheSamplerAndWritesOnce() throws {
        let inspector = SourceText.codeOnly(try text(Self.inspector))
        XCTAssertTrue(inspector.contains("""
            if TrackMix.currentInstrument(of: laneID, in: document) == .sampler {
                                    TrackSampleRow(laneID: laneID)
            """), """
            The inspector no longer mounts the Sample row for a Sampler track, or mounts it for every \
            track. The Sampler is offered BECAUSE this row gives it a sound — without it, a track on \
            EchoelSampler is silent with no way to fix it.
            """)
        XCTAssertEqual(inspector.components(separatedBy: "TrackSampleRow(").count - 1, 1,
                       "one Sample row, in one place")

        let row = SourceText.codeOnly(try text(Self.row))
        for needle in ["timeline.editLaneSample(id: laneID) {",
                       "timeline.setLaneSample(laneID, path: path)",
                       "Text(\"No sample\").tag(String?.none)",
                       "Task.detached(priority: .utility) { MediaLibrary.listAudio() }",
                       ".frame(minHeight: 44)"] {
            XCTAssertTrue(row.contains(needle), "`TrackSampleRow` lost `\(needle)`")
        }
        XCTAssertEqual(row.components(separatedBy: "setLaneSample(").count - 1, 1, """
            `TrackSampleRow` writes the sample more than once. ONE write, inside `editLaneSample`, is \
            ONE Undo step; a second write would record nothing.
            """)
        XCTAssertEqual(row.components(separatedBy: "MediaLibrary.listAudio()").count - 1, 1,
                       "the library listing is disk I/O and runs only in the detached task")
    }

    // MARK: 4 — COUNTERWEIGHT: the root note the row's words promise

    func testMiddleCPlaysTheSampleAsRecorded() throws {
        let rack = SourceText.codeOnly(try text(Self.rack))
        XCTAssertTrue(rack.contains("pitchSemitones: Float(pitch - 60 + (transposeBySlot[slot] ?? 0))"), """
            The sampler's root note is no longer MIDI 60. `TrackSampleRow.note` says "Middle C plays \
            it as recorded" — change the words with the root.
            """)
        XCTAssertTrue(TrackSampleRow.note(hasSample: true, libraryEmpty: false).contains("Middle C"))
        XCTAssertTrue(TrackSampleRow.note(hasSample: false, libraryEmpty: true).contains("Import Audio"),
                      "an empty library names the door that fills it")
    }

    // MARK: - helpers

    private func text(_ relative: String) throws -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        let file = url.appendingPathComponent(relative)
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw XCTSkip("\(relative) not on disk — this run has no source tree")
        }
        return try String(contentsOf: file, encoding: .utf8)
    }
}
