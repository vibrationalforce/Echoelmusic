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
//  · GMMW GA-4 (claims 5–6) — the rack holds ONE SAMPLER UNIT PER SLOT. Claim 5 is END-TO-END over
//    the rack's Debug seams: two Sampler tracks bind two units and each unit loads its own file
//    (before GA-4 the second track fell back to EchoelSynth); a fifth Sampler request on four units
//    is the allocator's poly fallback, never silence (COUNTERWEIGHT). Claim 6 is a SOURCE-TEXT SCAN:
//    `attachAll` makes `capacity` units and attaches each before the rack reads as attached, the app
//    calls it before `audioEngine.start()`, and the row no longer states the one-unit limit.
//  · DEVICE PROBE, OPEN — that a picked file SOUNDS on a MIDI part and again after reopening, and
//    that two Sampler tracks sound two files with no dropout or heat: G7 in `docs/dev/FOUNDER_INBOX.md`.
//
//  GRADING against the parent tree (#433/#464): the file does NOT compile there — it calls
//  `editLaneSample(id:_:)`, created by this commit — so no assertion has a verdict on the parent
//  (ONE absence, #486). Claims 1–2 are FORWARD guards transcribed by reading `editLaneSample`,
//  `apply(.laneSample)` and `instrumentChoices`; claims 3–4's needles were grepped against the
//  worktree. COUNTERWEIGHTS (#343): claim 1's no-op pick, claim 2's voice kind, claim 4's root note.
//  GA-4 grading against its parent (`255ce87`): claim 5 drives only seams that exist there, so it
//  COMPILES there — and with four injected units it is green there too (the seams take any count);
//  its REGRESSION half is claim 6, red there for its named reason (`attachAll` made `[sampler]`, and
//  the row said "One track plays EchoelSampler at a time"). Claim 5's fifth-request check and claim
//  6's attach-before-start are COUNTERWEIGHTS. Transcribed and driven against both trees.
//
//  `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest
#if canImport(AVFoundation)
import AVFoundation
#endif
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

    // MARK: 5 — GMMW GA-4: two Sampler tracks play two files

    func testTwoSamplerTracksPlayTwoFiles() throws {
        #if DEBUG
        let rack = LaneVoiceRack(capacity: 4)
        rack.installVoicesForTests((0..<4).map { _ in PolySynthVoice(maxVoices: 1) })
        rack.installKindUnitsForTests(subs: [], samplers: (0..<4).map { _ in SamplerVoice() })
        let first = try writeMonoWAV(named: "ga4-first")
        let second = try writeMonoWAV(named: "ga4-second")
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }
        rack.setKind(slot: 0, kind: .sampler)
        rack.setKind(slot: 2, kind: .sampler)
        XCTAssertEqual(rack.bindingsForTests[0], .sampler(0))
        XCTAssertEqual(rack.bindingsForTests[2], .sampler(1),
                       "the second Sampler track gets a unit of its own, not EchoelSynth")
        rack.setSample(slot: 0, url: first)
        rack.setSample(slot: 2, url: second)
        XCTAssertEqual(rack.samplers[0].sourceURL, first)
        XCTAssertEqual(rack.samplers[1].sourceURL, second, "…and plays its own file")
        XCTAssertTrue(rack.samplers[0].isLoaded && rack.samplers[1].isLoaded, "both files loaded")

        let five: [(slot: Int, kind: LaneVoiceKind)] = (0..<5).map { (slot: $0, kind: LaneVoiceKind.sampler) }
        let bound = KindVoiceAllocator.allocate(ordered: five, subUnits: 0, samplerUnits: 4)
        XCTAssertEqual(bound[3], .sampler(3))
        XCTAssertEqual(bound[4], .poly(4),
                       "COUNTERWEIGHT: past the units a Sampler request is EchoelSynth — never silence")
        #else
        XCTFail("the rack's test seams are Debug-only; this claim needs the Debug build that Build for Testing makes")
        #endif
    }

    // MARK: 6 — GMMW GA-4: one unit per slot, attached before the engine starts

    func testEverySlotHasASamplerUnitAttachedBeforeStart() throws {
        let rack = SourceText.codeOnly(try text(Self.rack))
        guard let attach = rack.range(of: "public func attachAll(to audioEngine: AudioEngine) {"),
              let units = rack.range(of: "samplers = (0..<capacity).map { _ in SamplerVoice() }"),
              let each = rack.range(of: "for sampler in samplers { audioEngine.attachSourceNode(sampler.sourceNode) }"),
              let done = rack.range(of: "attached = true", range: attach.upperBound..<rack.endIndex) else {
            return XCTFail("""
                ANCHOR MISSING (#454): `attachAll` no longer makes one sampler unit per slot and                 attaches each. With one unit, a second Sampler track plays EchoelSynth.
                """)
        }
        XCTAssertTrue(attach.lowerBound < units.lowerBound && units.lowerBound < each.lowerBound
                      && each.lowerBound < done.lowerBound,
                      "the units are made and attached inside `attachAll`, before the rack reads as attached")
        XCTAssertFalse(rack.contains("samplers = [sampler]"), "one unit for the whole rack is the shape GA-4 retired")

        let app = SourceText.codeOnly(try text("Sources/Echoelmusic/EchoelmusicApp.swift"))
        guard let rackAttach = app.range(of: "laneVoiceRack.attachAll(to: audioEngine)"),
              let start = app.range(of: "EchoelCrashLog.breadcrumb(\"startup 3/4: starting audio engine\")") else {
            return XCTFail("ANCHOR MISSING (#454): the startup attach or the engine start breadcrumb")
        }
        XCTAssertLessThan(rackAttach.lowerBound, start.lowerBound,
                          "COUNTERWEIGHT: the rack (and its sampler units) attach before the engine starts")

        let row = SourceText.codeOnly(try text(Self.row))
        XCTAssertFalse(row.contains("One track plays EchoelSampler at a time"),
                       "the row states a one-unit limit the rack no longer has")
    }

    // MARK: - helpers

    #if canImport(AVFoundation)
    /// A short mono 48 kHz float WAV — the sampler's own rate, so the load takes its copy path.
    private func writeMonoWAV(named name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(UUID().uuidString).wav")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 48_000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings,
                                   commonFormat: .pcmFormatFloat32, interleaved: false)
        let frames = 4_800
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                            frameCapacity: AVAudioFrameCount(frames)),
              let data = buffer.floatChannelData else {
            throw XCTSkip("no PCM buffer for the fixture")
        }
        buffer.frameLength = AVAudioFrameCount(frames)
        for frame in 0..<frames { data[0][frame] = frame % 48 == 0 ? 0.5 : 0 }
        try file.write(from: buffer)
        return url
    }
    #endif

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
