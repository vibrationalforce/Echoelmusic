import AudioToolbox
import EchoelCore
import XCTest
@testable import EchoelEngine

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

    func testAUnitPreparedForAnotherRateIsNotPlayed() throws {
        let (project, track) = try pluginSong()
        let out = render(playing(project, track: track, unit: FakeInstrument(level: 0.5).makeUnit(sampleRate: 44_100)),
                         frames: 4_800, block: 256)
        XCTAssertTrue(out.allSatisfy { $0 == 0 })
    }

    func testStoppingSendsAllNotesOff() throws {
        let (project, track) = try pluginSong()
        let fake = FakeInstrument(level: 0)
        let engine = playing(project, track: track, unit: fake.makeUnit(sampleRate: rate))
        _ = render(engine, frames: 26_000, block: 512)
        engine.stop()
        _ = render(engine, frames: 1_024, block: 512)
        XCTAssertTrue(fake.heard.contains { $0.status == 0xB0 && $0.pitch == 123 }, "controller 123 after stop")
    }
}
