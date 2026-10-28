import AVFoundation
import AudioToolbox
import EchoelCore
import XCTest
@testable import EchoelEngine
@testable import EchoelHost

/// A stand-in for an Audio Unit instrument: it fills every block with a constant and notes the
/// absolute frame of each MIDI message it was sent.
private final class FakeInstrument: @unchecked Sendable {
    let level: Float
    private var pending: [(offset: Int64, status: UInt8, pitch: UInt8)] = []
    private(set) var heard: [(frame: Int64, status: UInt8, pitch: UInt8)] = []

    init(level: Float) { self.level = level }

    func makeUnit(sampleRate: Double) -> HostedUnit {
        HostedUnit(render: { [self] _, stamp, frames, _, list, _ in
            let start = Int64(stamp.pointee.mSampleTime)
            for event in pending { heard.append((start + event.offset, event.status, event.pitch)) }
            pending.removeAll()
            for buffer in UnsafeMutableAudioBufferListPointer(list) {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                for i in 0..<Int(frames) { data[i] = level }
            }
            return noErr
        }, scheduleMIDI: { [self] time, _, _, bytes in
            pending.append((time - AUEventSampleTimeImmediate, bytes[0], bytes[1]))
        }, sampleRate: sampleRate, maximumFrames: 4_096, owner: nil)
    }
}

/// A stand-in that fills every block with 0.5, except the one call it refuses.
private final class RefusingInstrument: @unchecked Sendable {
    let refused: Int
    private var calls = 0

    init(refusing call: Int) { refused = call }

    func makeUnit(sampleRate: Double) -> HostedUnit {
        HostedUnit(render: { [self] _, _, frames, _, list, _ in
            calls += 1
            if calls == refused { return kAudioUnitErr_CannotDoInCurrentContext }
            for buffer in UnsafeMutableAudioBufferListPointer(list) {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                for i in 0..<Int(frames) { data[i] = 0.5 }
            }
            return noErr
        }, scheduleMIDI: nil, sampleRate: sampleRate, maximumFrames: 256, owner: nil)
    }
}

/// What a unit under test read through its host blocks, one entry per render call.
private final class ClockReadings: @unchecked Sendable {
    var readings: [(tempo: Double, numerator: Double, denominator: Int, beat: Double, moving: Bool, changed: Bool)] = []
}

final class HostedUnitTests: XCTestCase {
    private let rate = 48_000.0

    private func pluginSong() throws -> (Project, TrackID) {
        var project = Project(tempo: 120)
        let track = TrackID(), clip = ClipID()
        let plugin = PluginComponent(type: PluginComponent.code("aumu"), subtype: PluginComponent.code("Fake"),
                                     manufacturer: PluginComponent.code("Test"), name: "Fake", manufacturerName: "Test")
        try Command.addTrack(id: track, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try Command.setInstrumentPlugin(track, plugin).apply(to: &project)
        try Command.createClip(track: track, id: clip, name: "C", length: 4 * MusicalTime.ticksPerBar(.common)).apply(to: &project)
        // One beat in, for half a beat: frames 24,000 to 36,000 at 120 BPM.
        try Command.addNotes(clip, [Note(pitch: 60, velocity: 100, start: 960, length: 480)]).apply(to: &project)
        try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 0).apply(to: &project)
        return (project, track)
    }

    private func render(_ engine: EngineCore, frames: Int, block: Int) -> [Float] {
        var left = [Float](repeating: 0, count: frames)
        var right = [Float](repeating: 0, count: frames)
        var start = 0
        while start < frames {
            let n = Swift.min(block, frames - start)
            left.withUnsafeMutableBufferPointer { l in
                right.withUnsafeMutableBufferPointer { r in
                    guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                    engine.render(frameCount: n, left: lp + start, right: rp + start)
                }
            }
            start += n
        }
        return left
    }

    private func playing(_ project: Project, track: TrackID, unit: HostedUnit?) -> EngineCore {
        let engine = EngineCore(sampleRate: rate)
        engine.setClickEnabled(false)
        var slots = SlotAssigner(capacity: engine.slotCapacity)
        slots.update(for: project)
        engine.publish(EngineSnapshot(plan: PlaybackPlan(compiling: project), project: project, slots: slots.slots,
                                      sampleRate: rate, generation: 1, units: unit.map { [track: $0] } ?? [:]))
        engine.play()
        return engine
    }

    func testTheUnitHearsEachNoteOnItsExactFrameWhateverTheBlockSize() throws {
        let (project, track) = try pluginSong()
        for block in [64, 700, 4_096] {
            let fake = FakeInstrument(level: 0.5)
            let engine = playing(project, track: track, unit: fake.makeUnit(sampleRate: rate))
            _ = render(engine, frames: 48_000, block: block)
            let notes = fake.heard.filter { $0.status & 0xF0 == 0x90 || $0.status & 0xF0 == 0x80 }
            XCTAssertEqual(notes.map(\.frame), [24_000, 36_000], "block \(block)")
            XCTAssertEqual(notes.map(\.status), [0x90, 0x80], "block \(block)")
            XCTAssertEqual(notes.map(\.pitch), [60, 60], "block \(block)")
        }
    }

    func testTheUnitIsMixedAtTheTracksGainAndAMissingUnitIsSilent() throws {
        var (project, track) = try pluginSong()
        let fake = FakeInstrument(level: 0.5)
        let out = render(playing(project, track: track, unit: fake.makeUnit(sampleRate: rate)), frames: 4_800, block: 256)
        XCTAssertEqual(out[100], 0.5 * Float(0.5).squareRoot(), accuracy: 1e-5)

        XCTAssertTrue(render(playing(project, track: track, unit: nil), frames: 4_800, block: 256).allSatisfy { $0 == 0 })

        try Command.setMute(track, true).apply(to: &project)
        let muted = render(playing(project, track: track, unit: FakeInstrument(level: 0.5).makeUnit(sampleRate: rate)),
                           frames: 4_800, block: 256)
        XCTAssertTrue(muted.allSatisfy { $0 == 0 })
    }

    /// What a unit reads through its host blocks from inside its own render: the song's tempo and
    /// beat, and whether it moves — "changed" once, at the start (audit 2026-10-23).
    func testAUnitReadsTheTempoBeatAndTransportFromInsideItsRender() throws {
        var (project, track) = try pluginSong()
        try Command.setTempo(bpm: 95).apply(to: &project)
        let clock = HostClock()
        let seen = ClockReadings()
        let unit = HostedUnit(render: { _, _, _, _, _, _ in
            var tempo = 0.0, numerator = 0.0, beat = 0.0, downbeat = 0.0
            var denominator = 0, toNextBeat = 0
            _ = clock.musicalContextBlock(&tempo, &numerator, &denominator, &beat, &toNextBeat, &downbeat)
            var flags = AUHostTransportStateFlags()
            var sample = 0.0
            _ = clock.transportStateBlock(&flags, &sample, nil, nil)
            seen.readings.append((tempo: tempo, numerator: numerator, denominator: denominator, beat: beat,
                                  moving: flags.contains(.moving), changed: flags.contains(.changed)))
            return noErr
        }, scheduleMIDI: nil, sampleRate: rate, maximumFrames: 4_096, owner: nil, clock: clock)
        let engine = playing(project, track: track, unit: unit)
        // 201 blocks of 240 frames: the last one starts at sample 48,000, one second in.
        _ = render(engine, frames: 48_240, block: 240)

        let first = try XCTUnwrap(seen.readings.first), last = try XCTUnwrap(seen.readings.last)
        XCTAssertEqual(first.tempo, 95)
        XCTAssertEqual(first.numerator, 4)
        XCTAssertEqual(first.denominator, 4)
        XCTAssertTrue(first.moving)
        XCTAssertTrue(first.changed, "the start is reported once")
        XCTAssertFalse(seen.readings.dropFirst().contains { $0.changed }, "and not again while it only runs on")
        XCTAssertEqual(last.beat, 95.0 / 60, accuracy: 1e-6, "a second in at 95 BPM")
    }

    func testAUnitPreparedForAnotherRateIsNotPlayed() throws {
        let (project, track) = try pluginSong()
        let out = render(playing(project, track: track, unit: FakeInstrument(level: 0.5).makeUnit(sampleRate: 44_100)),
                         frames: 4_800, block: 256)
        XCTAssertTrue(out.allSatisfy { $0 == 0 })
    }

    func testAnExportPlaysTheUnitItIsGiven() throws {
        let (project, track) = try pluginSong()
        let fake = FakeInstrument(level: 0.5)
        let result = OfflineRender.render(project, sampleRate: rate, tailSeconds: 0, ringOutSeconds: 0,
                                          units: [track: fake.makeUnit(sampleRate: rate)])
        XCTAssertEqual(result.left[30_000], 0.5 * Float(0.5).squareRoot(), accuracy: 1e-5)
        XCTAssertEqual(fake.heard.filter { $0.status == 0x90 }.map(\.frame), [24_000])
        XCTAssertTrue(OfflineRender.render(project, sampleRate: rate, tailSeconds: 0).left.allSatisfy { $0 == 0 })
    }

    func testStoppingSendsAllNotesOff() throws {
        let (project, track) = try pluginSong()
        let fake = FakeInstrument(level: 0)
        let engine = playing(project, track: track, unit: fake.makeUnit(sampleRate: rate))
        _ = render(engine, frames: 26_000, block: 512)
        engine.stop()
        _ = render(engine, frames: 1_024, block: 512)
        XCTAssertTrue(fake.heard.contains { $0.status == 0xB0 && $0.pitch == 123 }, "controller 123 after stop")
        XCTAssertTrue(fake.heard.contains { $0.status == 0xB0 && $0.pitch == 64 }, "the pedal lifted after stop")
        XCTAssertTrue(fake.heard.contains { $0.status == 0xE0 }, "the wheel centred after stop")
    }

    func testAClipsBendAndPedalReachTheUnitAtTheirFrame() throws {
        let song = try pluginSong()
        var project = song.0
        let track = song.1
        guard let clip = project.track(track)?.clips.first?.id else { return XCTFail("no clip") }
        // The pedal at the note (beat 1, frame 24,000), a bend at beat 2 (frame 48,000).
        try Command.setControls(clip, [ControlChange(kind: .controller(number: 64), start: 960, value: 127),
                                       ControlChange(kind: .pitchBend, start: 1_920, value: 12_000)]).apply(to: &project)
        let fake = FakeInstrument(level: 0)
        _ = render(playing(project, track: track, unit: fake.makeUnit(sampleRate: rate)), frames: 50_000, block: 700)
        // Frame 0 may carry the rest a fresh plan sends; the clip's own moves are at their frames.
        let pedal = fake.heard.filter { $0.status == 0xB0 && $0.pitch == 64 && $0.frame > 0 }.map(\.frame)
        XCTAssertEqual(pedal, [24_000])
        XCTAssertEqual(fake.heard.filter { $0.status == 0xE0 && $0.frame > 0 }.map(\.frame), [48_000])
        let atBeat = fake.heard.filter { $0.frame == 24_000 }.map(\.status)
        XCTAssertEqual(atBeat, [0xB0, 0x90], "the pedal is down before the note it holds")
    }

    /// A unit that refuses a block is counted, block by block, so an export can say its file has
    /// a hole instead of reporting success (Codex handover S6). A unit that never fails counts 0.
    func testARefusedBlockIsCountedAndAGoodUnitCountsNone() throws {
        let failing = RefusingInstrument(refusing: 2).makeUnit(sampleRate: rate)
        var left = [Float](repeating: 0, count: 256), right = left
        for _ in 0..<3 {
            left.withUnsafeMutableBufferPointer { l in
                right.withUnsafeMutableBufferPointer { r in
                    guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                    failing.render(frames: 256, left: lp, right: rp, gainLeft: 1, gainRight: 1)
                }
            }
        }
        XCTAssertEqual(failing.renderFailures, 1, "the second of three blocks was refused")
        XCTAssertEqual(left[0], 1.0, accuracy: 1e-6, "the two good blocks still added their sound")
        XCTAssertEqual(FakeInstrument(level: 0.5).makeUnit(sampleRate: rate).renderFailures, 0)

        let (project, track) = try pluginSong()
        let export = HostedUnit(render: { _, _, _, _, _, _ in kAudioUnitErr_CannotDoInCurrentContext },
                                scheduleMIDI: nil, sampleRate: rate, maximumFrames: 16_384, owner: nil)
        _ = OfflineRender.render(project, sampleRate: rate, tailSeconds: 0, ringOutSeconds: 0, units: [track: export])
        XCTAssertGreaterThan(export.renderFailures, 0, "an export through a failing unit leaves a count to read")
    }
}
