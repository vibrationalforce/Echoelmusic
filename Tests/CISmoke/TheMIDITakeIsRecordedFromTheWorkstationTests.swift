// TheMIDITakeIsRecordedFromTheWorkstationTests.swift
// Echoel — Phase 3 / Recording R1. The MIDI recorder was built and wired —
// `MIDIBusPublisher` tees every external note into `RecordController`, which commits each armed
// track's take as a new part — and nothing could start it: `RecordController.arm()` and
// `TimelineStore.toggleArm` had no production caller. `RecordTakeControls.swift` is that caller.
//
// WHAT IT PINS.
// 1. END-TO-END BEHAVIOUR (a real `RecordController` on a real `Transport`, `TimelineStore` and
//    `ClipStore`): an armed MIDI track records the notes played into ONE new part at bar 1, and the
//    take ENDS at the song end — the arrangement wraps there while the transport's step count runs
//    on, so without the end every later note would land past the song. Notes after the end and a
//    later Stop add nothing.
// 2. END-TO-END BEHAVIOUR: a take the full 8-slot clip grid cannot hold is COUNTED
//    (`droppedTakes`), not skipped silently, and the next arm clears the count.
// 3. END-TO-END BEHAVIOUR (pure): the door's state order (recording > stop first > arm first >
//    song cannot play > ready) and who may be armed (a rack MIDI track only).
// 4. SOURCE-TEXT SCAN: the Workstation mounts the button with its ONE start from the top and its
//    own Stop, mounts the arm switch per open track, and still names no recorder; the door file is
//    the only production caller of `.toggleArm(` and of the recorder's `arm()`; the app hands the
//    recorder the player's song end.
//
// HONEST GRADING (§3), against the parent tree (the Automation-close doc commit): the file does
// NOT compile there — `followSongEnd`, `droppedTakes`, `songEndTick` and `RecordTake` are new — so
// no assertion has a verdict on the parent; every claim is FORWARD (one absence, #486). By
// transcription claim 4's mounts are absent at the parent. Counterweights (#343): claim 1 with NO
// song end keeps recording past bar 1 (the provider is the one thing that ends it); claim 3's
// Echoel, audio and capacity-0 tracks cannot be armed. Behaviour graded by hand-tracing
// `RecordController.onStep` / `TakeRecorder` / `MIDINoteRecorder`.
// NOT HERE — DEVICE PROBE, open.
// NEEDS-FOUNDER-VERIFY: Workstation with a part that plays → select a second MIDI track → "Arm for
// recording" → the row shows ARM → Record → play a MIDI keyboard for a few bars → Stop: a new part
// sits on that track from bar 1 and Play sounds your notes on the track's own instrument; Undo
// removes it. Let the song reach its end while recording: the take stops there by itself.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheMIDITakeIsRecordedFromTheWorkstationTests: XCTestCase {

    private static let steps = Transport.stepsPerBar
    private static let bar = TimelineTime.ticksPerBar
    private static let step = TimelineTime.ticksPerTransportStep

    private var rigClips: ClipStore?

    /// A real rig. `ClipStore` persists to the shared App Group file and reloads it, so the grid
    /// is cleared first and last (the `RecordControllerAudioHookTests` idiom).
    private func rig() -> (Transport, TimelineStore, ClipStore, RecordController, UUID) {
        let clips = ClipStore()
        for i in clips.slots.indices { clips.clear(at: i) }
        rigClips = clips
        let timeline = TimelineStore()
        timeline.addLane(kind: .midi, name: "Keys \(UUID().uuidString)")
        let lane = timeline.document.lanes.last?.id ?? UUID()
        // The store reloads the persisted song, so another test's armed track would record too.
        for other in timeline.document.lanes where other.isArmed && other.id != lane {
            timeline.toggleArm(id: other.id)
        }
        timeline.toggleArm(id: lane)
        let transport = Transport()
        let controller = RecordController()
        controller.wire(transport: transport, timeline: timeline, clips: clips, bus: EngineBus())
        return (transport, timeline, clips, controller, lane)
    }

    override func tearDown() {
        if let clips = rigClips { for i in clips.slots.indices { clips.clear(at: i) } }
        super.tearDown()
    }

    /// Steps `from..<to` of the transport, counted from Play (bar = step / 16).
    private func run(_ transport: Transport, steps range: Range<Int>) {
        for s in range { transport.tick(step: s % Self.steps) }
    }

    // MARK: 1 — the take lands where it was heard, and ends where the song does

    func testATakeIsOnePartFromBarOneThatEndsAtTheSongEnd() throws {
        let (transport, timeline, clips, controller, lane) = rig()
        controller.followSongEnd { Self.bar }            // a one-bar song
        let regionsBefore = timeline.document.regions.count

        controller.arm()
        transport.play()
        run(transport, steps: 0..<3)                     // steps 0,1,2 — the take anchors at 0
        controller.recordNoteOn(pitch: 60, velocity: 0.8)   // at step 2
        run(transport, steps: 3..<6)
        controller.recordNoteOff(pitch: 60)               // at step 5
        run(transport, steps: 6..<17)                    // step 16 = the song end: the take ends
        XCTAssertFalse(controller.isRecording, "the take ends where the song wraps")

        controller.recordNoteOn(pitch: 72, velocity: 0.8)   // after the end: heard, not recorded
        run(transport, steps: 17..<20)
        controller.recordNoteOff(pitch: 72)
        transport.stop()

        let added = Array(timeline.document.regions.dropFirst(regionsBefore)).filter { $0.laneID == lane }
        XCTAssertEqual(added.count, 1, "one take, one part — Stop after the end adds nothing")
        let region = try XCTUnwrap(added.first)
        XCTAssertEqual(region.laneID, lane)
        XCTAssertEqual(region.startTick, 0, "the take starts at bar 1, where Record starts the song")
        XCTAssertEqual(region.lengthTicks, Self.bar, "it ends at the song end, not past it")
        let clip = try XCTUnwrap(clips.slots.compactMap { $0 }.first { $0.id == region.clipID })
        let notes = clip.melody?.notes ?? []
        XCTAssertEqual(notes.map(\.pitch), [60], "only the note played inside the song")
        XCTAssertEqual(notes.first?.startTick, 2 * Self.step, "at the sixteenth it was played")
        XCTAssertEqual(controller.droppedTakes, 0)
    }

    func testWithoutASongEndTheTakeRunsOnPastIt() throws {
        let (transport, timeline, _, controller, _) = rig()   // no followSongEnd: the counterweight
        let regionsBefore = timeline.document.regions.count
        controller.arm()
        transport.play()
        run(transport, steps: 0..<3)
        controller.recordNoteOn(pitch: 60, velocity: 0.8)
        run(transport, steps: 3..<20)
        XCTAssertTrue(controller.isRecording, "nothing but the song end stops a running take")
        controller.recordNoteOff(pitch: 60)
        transport.stop()
        let region = try XCTUnwrap(timeline.document.regions.dropFirst(regionsBefore).first)
        XCTAssertEqual(region.lengthTicks, 2 * Self.bar, "the take counted on into bar 2")
    }

    // MARK: 2 — a take the grid cannot hold is said, not lost silently

    func testATakeTheFullGridCannotHoldIsCounted() throws {
        let (transport, timeline, clips, controller, _) = rig()
        for i in clips.slots.indices { clips.setClip(at: i, Clip(name: "Full \(i)")) }
        let regionsBefore = timeline.document.regions.count
        controller.arm()
        transport.play()
        run(transport, steps: 0..<2)
        controller.recordNoteOn(pitch: 64, velocity: 0.7)
        run(transport, steps: 2..<4)
        controller.recordNoteOff(pitch: 64)
        transport.stop()
        XCTAssertEqual(controller.droppedTakes, 1)
        XCTAssertEqual(timeline.document.regions.count, regionsBefore, "no part without a clip")
        XCTAssertEqual(RecordTake.droppedSentence(1),
                       "1 take was not added: the part grid is full (8 parts).")
        controller.arm()
        XCTAssertEqual(controller.droppedTakes, 0, "the next take starts with a clean count")
        controller.cancel()
    }

    // MARK: 3 — the door's decisions, pure

    func testTheDoorSaysWhatStandsBetweenTheUserAndATake() {
        XCTAssertEqual(RecordTake.state(recording: true, playing: true, armed: true, startable: true), .recording)
        XCTAssertEqual(RecordTake.state(recording: false, playing: true, armed: true, startable: true), .stopFirst)
        XCTAssertEqual(RecordTake.state(recording: false, playing: false, armed: false, startable: true), .armFirst)
        XCTAssertEqual(RecordTake.state(recording: false, playing: false, armed: true, startable: false), .songCannotPlay)
        XCTAssertEqual(RecordTake.state(recording: false, playing: false, armed: true, startable: true), .ready)
        XCTAssertTrue(RecordTake.caption(.ready).contains("sixteenth grid"),
                      "the take is quantised to the step — the caption says so")
    }

    func testOnlyARackMIDITrackCanBeArmed() {
        let echoel = TimelineLane(name: "MIDI 1", kind: .midi)
        let keys = TimelineLane(name: "Keys", kind: .midi)
        let audio = TimelineLane(name: "Audio 1", kind: .audio)
        let doc = TimelineDocument(lanes: [echoel, keys, audio], regions: [])
        XCTAssertTrue(RecordTake.canArm(keys.id, in: doc, voiceCapacity: 4))
        XCTAssertFalse(RecordTake.canArm(echoel.id, in: doc, voiceCapacity: 4),
                       "the Echoel track is the instrument's own part")
        XCTAssertFalse(RecordTake.canArm(audio.id, in: doc, voiceCapacity: 4), "no audio input (#1302)")
        XCTAssertFalse(RecordTake.canArm(keys.id, in: doc, voiceCapacity: 0),
                       "a track without a rack voice could not play the take back")
    }

    // MARK: 4 — the one door, the one start

    func testTheWorkstationMountsTheDoorOnItsOneStart() throws {
        let workstation = try code("Sources/Echoelmusic/Studio/WorkstationView.swift")
        XCTAssertEqual(workstation.components(separatedBy: "RecordTakeButton(playing: playing, startable: startable,").count - 1, 1)
        XCTAssertTrue(workstation.contains("startSong: { startTimeline(fromTick: 0, launching: []) },"),
                      "Record starts the song through the Workstation's ONE start, from the top")
        XCTAssertTrue(workstation.contains("stopSong: { player.stop() })"))
        XCTAssertEqual(workstation.components(separatedBy: "TrackArmToggle(laneID: row.id)").count - 1, 1)
        XCTAssertFalse(workstation.contains("RecordController"), "the Workstation names no recorder")

        let door = "Studio/RecordTakeControls.swift"
        XCTAssertEqual(try filesUnderSources(containing: ".toggleArm("), [door],
                       "one writer of a track's arm flag")
        XCTAssertEqual(try filesUnderSources(containing: "recorder.arm()"), [door],
                       "one production caller of the recorder's arm")
        let app = try code("Sources/Echoelmusic/EchoelmusicApp.swift")
        XCTAssertTrue(app.contains("recordController.followSongEnd { [weak timelinePlayer] in timelinePlayer?.songEndTick }"),
                      "the recorder must know where the song wraps")
    }

    // MARK: helpers

    private struct AnchorMissing: Error { let name: String }

    private func code(_ relativePath: String) throws -> String {
        let url = repoRoot().appendingPathComponent(relativePath)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing(name: relativePath)
        }
        return SourceText.codeOnly(text)
    }

    /// Paths under `Sources/Echoelmusic/` whose CODE (comments stripped) contains `needle`.
    private func filesUnderSources(containing needle: String) throws -> [String] {
        let base = repoRoot().appendingPathComponent("Sources/Echoelmusic")
        guard let walker = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else {
            XCTFail("ANCHOR MISSING: cannot walk Sources/Echoelmusic (#454)")
            throw AnchorMissing(name: "Sources/Echoelmusic")
        }
        var hits: [String] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            if SourceText.codeOnly(text).contains(needle) {
                // By marker, not by prefix length: an enumerator URL can carry a resolved prefix
                // (`/private/var/…`) that the base path does not.
                if let tail = url.path.components(separatedBy: "Sources/Echoelmusic/").last {
                    hits.append(tail)
                }
            }
        }
        if hits.isEmpty && needle.isEmpty { XCTFail("empty needle") }
        return hits.sorted()
    }

    private func repoRoot() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.pathComponents.count > 1 {
            url.deleteLastPathComponent()
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
                return url
            }
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }
}
