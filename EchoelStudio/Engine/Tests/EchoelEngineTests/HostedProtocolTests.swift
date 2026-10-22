import EchoelCore
@testable import EchoelKernels
import XCTest
@testable import EchoelEngine

/// An instrument in pure Swift: it adds a constant to every block and notes the absolute frame
/// of every message the engine sent it. No Audio Unit, so this runs where AudioToolbox does not.
private final class ConstantInstrument: HostedInstrument, @unchecked Sendable {
    let sampleRate: Double
    let parameterRanges: [UInt64: ClosedRange<Float>] = [:]
    private let level: Float
    private var clock: Int64 = 0
    private var pending: [(offset: Int, status: UInt8, data: UInt8)] = []
    private(set) var heard: [(frame: Int64, status: UInt8, data: UInt8)] = []

    init(level: Float, sampleRate: Double) {
        self.level = level
        self.sampleRate = sampleRate
    }

    func schedule(address: UInt64, value: Float, offset: Int, ramp: Int) {}
    func noteOn(pitch: UInt8, velocity: UInt8, offset: Int) { pending.append((offset, 0x90, pitch)) }
    func noteOff(pitch: UInt8, offset: Int) { pending.append((offset, 0x80, pitch)) }
    func control(status: UInt8, _ data1: UInt8, _ data2: UInt8, offset: Int) { pending.append((offset, status, data1)) }
    func allNotesOff() { pending.append((0, 0xB0, 123)) }

    func render(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>,
                gainLeft: Float, gainRight: Float) {
        for event in pending { heard.append((clock + Int64(event.offset), event.status, event.data)) }
        pending.removeAll()
        for i in 0..<frames {
            left[i] += level * gainLeft
            right[i] += level * gainRight
        }
        clock += Int64(frames)
    }
}

/// An insert in pure Swift: `x · factor + offset` on both channels.
private final class AffineEffect: HostedProcessor, @unchecked Sendable {
    let sampleRate: Double
    let isBypassed = false
    let insert: InsertID? = nil
    let parameterRanges: [UInt64: ClosedRange<Float>] = [:]
    private let factor: Float, offset: Float

    init(factor: Float, offset: Float, sampleRate: Double) {
        self.factor = factor
        self.offset = offset
        self.sampleRate = sampleRate
    }

    func schedule(address: UInt64, value: Float, offset: Int, ramp: Int) {}

    func process(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>) {
        for i in 0..<frames {
            left[i] = left[i] * factor + offset
            right[i] = right[i] * factor + offset
        }
    }
}

/// The engine plays a hosted instrument and its inserts through two protocols, never through the
/// Audio Unit wrapper classes — so anything that conforms plays the same way (S-26, D1).
final class HostedProtocolTests: XCTestCase {
    private let rate = 48_000.0

    /// A plugin track with one note, one beat in for half a beat: frames 24,000 to 36,000.
    private func pluginSong() throws -> (Project, TrackID) {
        var project = Project(tempo: 120)
        let track = TrackID(), clip = ClipID()
        let plugin = PluginComponent(type: PluginComponent.code("aumu"), subtype: PluginComponent.code("Pure"),
                                     manufacturer: PluginComponent.code("Test"), name: "Pure", manufacturerName: "Test")
        try Command.addTrack(id: track, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try Command.setInstrumentPlugin(track, plugin).apply(to: &project)
        try Command.createClip(track: track, id: clip, name: "C", length: 4 * MusicalTime.ticksPerBar(.common)).apply(to: &project)
        try Command.addNotes(clip, [Note(pitch: 60, velocity: 100, start: 960, length: 480)]).apply(to: &project)
        try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 0).apply(to: &project)
        return (project, track)
    }

    private func engine(_ project: Project, track: TrackID, unit: any HostedInstrument,
                        inserts: [any HostedProcessor] = []) -> EngineCore {
        let engine = EngineCore(sampleRate: rate)
        engine.setClickEnabled(false)
        var slots = SlotAssigner(capacity: engine.slotCapacity)
        slots.update(for: project)
        engine.publish(EngineSnapshot(plan: PlaybackPlan(compiling: project), project: project, slots: slots.slots,
                                      sampleRate: rate, generation: 1, units: [track: unit], effects: [track: inserts]))
        return engine
    }

    private func render(_ engine: EngineCore, frames: Int, block: Int = 256) -> [Float] {
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

    func testAConformingInstrumentHearsEachNoteOnItsFrameWhateverTheBlockSize() throws {
        let (project, track) = try pluginSong()
        for block in [64, 700, 4_096] {
            let unit = ConstantInstrument(level: 0, sampleRate: rate)
            let core = engine(project, track: track, unit: unit)
            core.play()
            _ = render(core, frames: 48_000, block: block)
            let notes = unit.heard.filter { $0.status == 0x90 || $0.status == 0x80 }
            XCTAssertEqual(notes.map(\.frame), [24_000, 36_000], "block \(block)")
            XCTAssertEqual(notes.map(\.status), [0x90, 0x80], "block \(block)")
        }
    }

    func testAConformingInstrumentHearsAllNotesOffOnStopAndALiveControllerAtTheBlockStart() throws {
        let (project, track) = try pluginSong()
        let unit = ConstantInstrument(level: 0, sampleRate: rate)
        let core = engine(project, track: track, unit: unit)
        core.play()
        _ = render(core, frames: 26_000, block: 512)
        core.stop()
        _ = render(core, frames: 1_024, block: 512)
        XCTAssertTrue(unit.heard.contains { $0.status == 0xB0 && $0.data == 123 }, "all notes off after stop")

        let before = unit.heard.count
        core.playLive(slot: 0, status: 0xB0, 1, 64)
        _ = render(core, frames: 512, block: 512)
        let live = unit.heard.dropFirst(before).filter { $0.status == 0xB0 && $0.data == 1 }
        XCTAssertEqual(live.map(\.frame), [26_000 + 1_024], "the wheel at the start of the next block")
    }

    func testInsertsProcessTheInstrumentsBusInTheirOrder() throws {
        let (project, track) = try pluginSong()
        let gain = Float(0.5).squareRoot()   // centre pan at 0 dB
        let doubleThenLift: [any HostedProcessor] = [AffineEffect(factor: 2, offset: 0, sampleRate: rate),
                                                    AffineEffect(factor: 1, offset: 0.1, sampleRate: rate)]
        let out = render(engine(project, track: track, unit: ConstantInstrument(level: 0.5, sampleRate: rate),
                                inserts: doubleThenLift), frames: 1_024)
        XCTAssertEqual(out[100], (0.5 * 2 + 0.1) * gain, accuracy: 1e-5)
        let lifted = render(engine(project, track: track, unit: ConstantInstrument(level: 0.5, sampleRate: rate),
                                   inserts: doubleThenLift.reversed()), frames: 1_024)
        XCTAssertEqual(lifted[100], (0.5 + 0.1) * 2 * gain, accuracy: 1e-5)
    }
}
