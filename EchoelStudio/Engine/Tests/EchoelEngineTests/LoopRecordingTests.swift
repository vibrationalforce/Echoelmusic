import EchoelCore
import EchoelDSP
import Foundation
import XCTest
@testable import EchoelEngine

/// Loop record: a take that runs through the loop's wraps becomes one take per pass in the track's
/// take folder, the newest sounding. One bar at 120 BPM is two seconds, 96 000 frames at 48 kHz; the
/// loop the musician records over is four bars, 384 000 frames.
final class LoopRecordingTests: XCTestCase {
    private let rate = 48_000.0
    private let bar: Tick = 3_840
    private let barFrames = 96_000
    private let loopFrames = 384_000
    private var loop: Range<Tick> { 0..<(4 * bar) }
    private var time: TimeConversion { TimeConversion(bpm: 120, sampleRate: rate) }
    private var meter: MeterMap { Project(tempo: 120).meterMap }

    private func audioSong(frameCount: Int) throws -> (project: Project, track: TrackID, media: MediaFile) {
        var project = Project(tempo: 120)
        let track = TrackID()
        try Command.addTrack(id: track, name: "Vocal", kind: .audio, index: nil).apply(to: &project)
        let media = MediaFile(name: "Take 1", path: "Media/take.caf", frameCount: frameCount, sampleRate: rate)
        try Command.addMedia(media).apply(to: &project)
        return (project, track, media)
    }

    private func apply(_ commands: [Command], to project: inout Project) throws {
        for command in commands { try command.apply(to: &project) }
    }

    // MARK: - The render thread reports its wraps

    func testTheCoreReportsEachWrapOnTheClockThatNeverJumps() {
        let core = EngineCore(sampleRate: rate)
        core.setClickEnabled(false)
        let project = Project(tempo: 120)
        var slots = SlotAssigner(capacity: core.slotCapacity)
        slots.update(for: project)
        core.publish(EngineSnapshot(plan: PlaybackPlan(compiling: project), project: project, slots: slots.slots,
                                    sampleRate: rate, generation: 1, samples: [:]))
        core.setLoop(loop)
        core.setReportsLoopWraps(true)
        core.play()
        var left = [Float](repeating: 0, count: 256), right = [Float](repeating: 0, count: 256)
        let blocks = (loopFrames * 7 / 2) / 256
        for _ in 0..<blocks {
            left.withUnsafeMutableBufferPointer { l in
                right.withUnsafeMutableBufferPointer { r in
                    guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                    core.render(frameCount: 256, left: lp, right: rp)
                }
            }
        }
        XCTAssertEqual(core.playedFrames, Int64(blocks * 256), "the played frames run on through every wrap")
        XCTAssertLessThan(core.positionSample, Int64(loopFrames), "the playhead stays inside the loop")
        XCTAssertEqual(core.takeLoopWraps(), [384_000, 768_000, 1_152_000], "each wrap on its exact frame")
        core.setReportsLoopWraps(false)
    }

    // MARK: - Audio

    func testThreePassesAreThreeTakesOfOneFileInOneFolderTheNewestSounding() throws {
        let frames = 3 * loopFrames
        let passes = LoopRecording.audioPasses(frameCount: frames, startSample: 0, startPlayed: 0, latency: 0,
                                               wraps: [384_000, 768_000], loop: loop, time: time, meter: meter)
        XCTAssertEqual(passes.map(\.offset), [0, 384_000, 768_000], "one file, three offsets")
        XCTAssertEqual(passes.map(\.length), [384_000, 384_000, 384_000])
        XCTAssertEqual(passes.map(\.start), [0, 0, 0], "each pass on the loop's start")

        var (project, track, media) = try audioSong(frameCount: frames)
        try apply(LoopRecording.audioCommands(passes, media: media, track: track), to: &project)
        let held = try XCTUnwrap(project.track(track))
        XCTAssertEqual(held.regions.count, 3)
        XCTAssertEqual(Set(held.regions.map(\.media)), [media.id], "no new file")
        XCTAssertEqual(held.takeGroups.count, 1, "one folder")
        let group = try XCTUnwrap(held.takeGroups.first)
        XCTAssertEqual(group.takes.count, 3)
        let newest = try XCTUnwrap(held.regions.first { $0.offset == 768_000 })
        XCTAssertEqual(group.takes.last, newest.id.rawValue, "the newest pass is the bottom lane")
        XCTAssertEqual(group.comp, [CompSegment(start: 0, end: 4 * bar, take: newest.id.rawValue)], "the newest sounds")
    }

    func testANewSongRecordsOneRegionAsBefore() throws {
        // A new song loops one bar (`Arranging.songLoop`); even had it wrapped, the take is one region.
        let fresh = Project(tempo: 120)
        let oneBar = Arranging.songLoop(songEnd: 0, meter: fresh.meterMap)
        XCTAssertEqual(oneBar, 0..<bar)
        XCTAssertFalse(LoopRecording.recordsPasses(over: oneBar, meter: fresh.meterMap))
        let frames = 3 * barFrames
        let passes = LoopRecording.audioPasses(frameCount: frames, startSample: 0, startPlayed: 0, latency: 0,
                                               wraps: [96_000, 192_000], loop: oneBar, time: time, meter: meter)
        XCTAssertEqual(passes, [LoopRecording.AudioPass(start: 0, offset: 0, length: frames)])
        var (project, track, media) = try audioSong(frameCount: frames)
        try apply(LoopRecording.audioCommands(passes, media: media, track: track), to: &project)
        XCTAssertEqual(project.track(track)?.regions.count, 1, "one region")
        XCTAssertEqual(project.track(track)?.takeGroups.count, 0, "no folder")
    }

    func testANewSongsMIDITakeOverdubsIntoOneClipAsBefore() {
        let events = [note(60, at: 24_000, sample: 24_000, on: true), note(60, at: 30_000, sample: 30_000, on: false),
                      note(62, at: 96_000 + 48_000, sample: 48_000, on: true), note(62, at: 96_000 + 60_000, sample: 60_000, on: false)]
        let passes = LoopRecording.midiPasses(events, from: .init(sample: 0, played: 0),
                                              to: .init(sample: 90_000, played: 186_000), wraps: [96_000],
                                              loop: 0..<bar, latency: 0, time: time, meter: meter)
        XCTAssertEqual(passes.count, 1, "both passes in one clip, on the same bar")
        XCTAssertEqual(passes.first?.notes.map(\.pitch), [60, 62])
    }

    func testAFourBarLoopRecordsPassesAndTwoBarsIsTheThreshold() {
        XCTAssertTrue(LoopRecording.recordsPasses(over: loop, meter: meter))
        XCTAssertTrue(LoopRecording.recordsPasses(over: 0..<(2 * bar), meter: meter))
        XCTAssertFalse(LoopRecording.recordsPasses(over: 0..<(2 * bar - 1), meter: meter))
        XCTAssertFalse(LoopRecording.recordsPasses(over: nil, meter: meter))
    }

    func testTheLatencyMovesEveryCutByTheSameFrames() {
        let passes = LoopRecording.audioPasses(frameCount: 3 * loopFrames + 480, startSample: 0, startPlayed: 0,
                                               latency: 480, wraps: [384_000, 768_000], loop: loop, time: time,
                                               meter: meter)
        XCTAssertEqual(passes.map(\.offset), [480, 384_480, 768_480], "file frame wrap + latency was heard on bar 1")
        XCTAssertEqual(passes.map(\.length), [384_000, 384_000, 384_000])
    }

    func testAPassBegunMidLoopStartsWhereRecordWasPressed() {
        // Record pressed on beat 3 (48 000 frames in), the played clock already at 500 000.
        let passes = LoopRecording.audioPasses(frameCount: 336_000 + loopFrames, startSample: 48_000,
                                               startPlayed: 500_000, latency: 0, wraps: [100_000, 836_000], loop: loop,
                                               time: time, meter: meter)
        XCTAssertEqual(passes.map(\.start), [1_920, 0], "a wrap before the take is not one of its passes")
        XCTAssertEqual(passes.map(\.offset), [0, 336_000])
        XCTAssertEqual(passes.map(\.length), [336_000, 384_000])
    }

    func testAShortLastPassIsDropped() {
        // Stop 1 000 frames after the loop came round: far less than a quarter bar (24 000).
        let passes = LoopRecording.audioPasses(frameCount: 2 * loopFrames + 1_000, startSample: 0, startPlayed: 0,
                                               latency: 0, wraps: [384_000, 768_000], loop: loop, time: time,
                                               meter: meter)
        XCTAssertEqual(passes.map(\.offset), [0, 384_000], "the 1 000-frame pass is no take")
        let kept = LoopRecording.audioPasses(frameCount: 2 * loopFrames + 30_000, startSample: 0, startPlayed: 0,
                                             latency: 0, wraps: [384_000, 768_000], loop: loop, time: time,
                                             meter: meter)
        XCTAssertEqual(kept.map(\.length), [384_000, 384_000, 30_000], "past a quarter bar it stays")
    }

    func testATakeThatNeverWrappedIsOneRegionAsBefore() {
        let passes = LoopRecording.audioPasses(frameCount: 1_000, startSample: 24_000, startPlayed: 24_000, latency: 480,
                                               wraps: [], loop: loop, time: time, meter: meter)
        let placed = RecordingPlacement.place(startSample: 24_000, latency: 480, time: time)
        XCTAssertEqual(passes, [LoopRecording.AudioPass(start: placed.start, offset: placed.offset, length: 1_000 - placed.offset)],
                       "however short, a plain take is kept")
    }

    func testTheWholeLoopRecordIsOneUndoStep() async throws {
        let frames = 3 * loopFrames
        let (project, track, media) = try audioSong(frameCount: 0 + frames)
        var empty = project
        empty.media.removeAll()
        let start = empty
        let passes = LoopRecording.audioPasses(frameCount: frames, startSample: 0, startPlayed: 0, latency: 0,
                                               wraps: [384_000, 768_000], loop: loop, time: time, meter: meter)
        let commands = [Command.addMedia(media)] + LoopRecording.audioCommands(passes, media: media, track: track)
        try await MainActor.run {
            let store = ProjectStore(project: start)
            try store.perform(commands, title: "Loop Record")
            XCTAssertEqual(store.project.track(track)?.regions.count, 3)
            store.undo()
            XCTAssertEqual(store.project, start, "one undo takes every pass and the file")
            XCTAssertFalse(store.canUndo)
        }
    }

    func testLiveIsTheExportAndTheNewestPassIsHeard() throws {
        let frames = 3 * loopFrames
        let values = (0..<frames).map { (i: Int) -> Float in Float(i / 384_000 + 1) * 0.1 }
        let buffer = try XCTUnwrap(SampleBuffer(samples: values, sampleRate: rate))
        let passes = LoopRecording.audioPasses(frameCount: frames, startSample: 0, startPlayed: 0, latency: 0,
                                               wraps: [384_000, 768_000], loop: loop, time: time, meter: meter)
        var (project, track, media) = try audioSong(frameCount: frames)
        try apply(LoopRecording.audioCommands(passes, media: media, track: track), to: &project)
        let samples = [media.id: buffer]
        let export = OfflineRender.render(project, sampleRate: rate, tailSeconds: 0, ringOutSeconds: 0, samples: samples,
                                          frameCount: loopFrames)
        XCTAssertEqual(export.left[48_000], 0.3 * Float(0.5).squareRoot(), accuracy: 1e-5, "the third pass sounds")
        for block in [64, 256, 4_096] {
            XCTAssertEqual(live(project, samples, frames: loopFrames, block: block), export.left,
                           "block \(block): live is the export, sample for sample")
        }
    }

    private func live(_ project: Project, _ samples: [MediaID: SampleBuffer], frames: Int, block: Int) -> [Float] {
        let core = EngineCore(sampleRate: rate)
        core.setClickEnabled(false)
        var slots = SlotAssigner(capacity: core.slotCapacity)
        slots.update(for: project)
        core.publish(EngineSnapshot(plan: PlaybackPlan(compiling: project), project: project, slots: slots.slots,
                                    sampleRate: rate, generation: 1, samples: samples))
        core.play()
        var left = [Float](repeating: 0, count: frames), right = [Float](repeating: 0, count: frames)
        var start = 0
        while start < frames {
            let n = Swift.min(block, frames - start)
            left.withUnsafeMutableBufferPointer { l in
                right.withUnsafeMutableBufferPointer { r in
                    guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                    core.render(frameCount: n, left: lp + start, right: rp + start)
                }
            }
            start += n
        }
        return left
    }

    // MARK: - MIDI

    private func note(_ pitch: UInt8, at played: Int64, sample: Int64, on: Bool) -> LoopRecording.Event {
        LoopRecording.Event(moment: .init(sample: sample, played: played), status: on ? 0x90 : 0x80,
                            data1: pitch, data2: on ? 100 : 0)
    }

    func testMIDINotesLandInThePassTheyWerePlayedIn() throws {
        // Three passes from bar 1; in each, one note on beat 2 (24 000 frames in), a pitch per pass.
        var events: [LoopRecording.Event] = []
        for pass in 0..<3 {
            let base = Int64(pass * loopFrames)
            events.append(note(UInt8(60 + pass), at: base + 24_000, sample: 24_000, on: true))
            events.append(note(UInt8(60 + pass), at: base + 36_000, sample: 36_000, on: false))
        }
        let passes = LoopRecording.midiPasses(events, from: .init(sample: 0, played: 0),
                                              to: .init(sample: 383_000, played: 1_151_000), wraps: [384_000, 768_000],
                                              loop: loop, latency: 0, time: time, meter: meter)
        XCTAssertEqual(passes.map { $0.notes.map(\.pitch) }, [[60], [61], [62]], "each note in its own pass")
        XCTAssertEqual(passes.map(\.start), [0, 0, 0])
        XCTAssertEqual(passes.first?.notes.first?.start, 960, "on beat 2 of the loop")

        var project = Project(tempo: 120)
        let track = TrackID()
        try Command.addTrack(id: track, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try apply(LoopRecording.midiCommands(passes, track: track, firstNumber: 1), to: &project)
        let held = try XCTUnwrap(project.track(track))
        XCTAssertEqual(held.clips.map(\.name), ["Take 1", "Take 2", "Take 3"])
        let group = try XCTUnwrap(held.takeGroups.first)
        XCTAssertEqual(group.takes.count, 3, "one folder of three")
        let plan = PlaybackPlan(compiling: project)
        let pitches = Set(plan.tracks.flatMap { $0.events }.map(\.pitch))
        XCTAssertEqual(pitches, [62], "only the newest pass plays")
    }

    func testAMIDINotePlayedJustAfterTheWrapButHeardBeforeItStaysInTheEarlierPass() throws {
        // Played 100 frames after the wrap, heard 480 frames earlier: the end of pass one.
        let events = [note(64, at: 384_100, sample: 100, on: true), note(64, at: 384_200, sample: 200, on: false),
                      note(65, at: 388_000, sample: 4_000, on: true), note(65, at: 398_000, sample: 14_000, on: false)]
        let passes = LoopRecording.midiPasses(events, from: .init(sample: 0, played: 0),
                                              to: .init(sample: 60_000, played: 444_000), wraps: [384_000],
                                              loop: loop, latency: 480, time: time, meter: meter)
        XCTAssertEqual(passes.map { $0.notes.map(\.pitch) }, [[64], [65]])
        let first = try XCTUnwrap(passes.first?.notes.first)
        XCTAssertEqual((passes.first?.start ?? 0) + first.start, time.tick(atSample: 384_000 - 380),
                       "where it was heard, before the wrap (clip start plus note start)")
    }

    func testAShortLastMIDIPassIsDropped() {
        let events = [note(60, at: 24_000, sample: 24_000, on: true), note(60, at: 30_000, sample: 30_000, on: false),
                      note(61, at: 384_100, sample: 100, on: true)]
        let passes = LoopRecording.midiPasses(events, from: .init(sample: 0, played: 0),
                                              to: .init(sample: 1_000, played: 385_000), wraps: [384_000],
                                              loop: loop, latency: 0, time: time, meter: meter)
        XCTAssertEqual(passes.map { $0.notes.map(\.pitch) }, [[60]], "Stop just after the wrap keeps no pass")
    }

    func testAMIDITakeWithoutAWrapIsOneClipAsBefore() {
        let events = [note(60, at: 124_000, sample: 124_000, on: true), note(60, at: 130_000, sample: 130_000, on: false)]
        let passes = LoopRecording.midiPasses(events, from: .init(sample: 120_000, played: 0),
                                              to: .init(sample: 131_000, played: 11_000), wraps: [],
                                              loop: loop, latency: 0, time: time, meter: meter)
        XCTAssertEqual(passes.count, 1)
        XCTAssertEqual(passes.first?.start, bar, "placed on the bar the note began in")
    }
}
