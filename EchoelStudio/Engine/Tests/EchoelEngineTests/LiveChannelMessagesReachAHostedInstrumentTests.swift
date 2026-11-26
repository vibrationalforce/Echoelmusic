import EchoelCore
@testable import EchoelKernels
import XCTest
@testable import EchoelEngine

/// An instrument in pure Swift that notes every channel message the engine hands it, with the
/// absolute frame it plays on. No Audio Unit, so this runs where AudioToolbox does not.
private final class ListeningInstrument: HostedInstrument, @unchecked Sendable {
    let sampleRate: Double
    let parameterRanges: [UInt64: ClosedRange<Float>] = [:]
    private var clock: Int64 = 0
    private var pending: [(offset: Int, status: UInt8, data1: UInt8, data2: UInt8)] = []
    private(set) var heard: [(frame: Int64, status: UInt8, data1: UInt8, data2: UInt8)] = []

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    func schedule(address: UInt64, value: Float, offset: Int, ramp: Int) {}
    func noteOn(pitch: UInt8, velocity: UInt8, offset: Int) { pending.append((offset, 0x90, pitch, velocity)) }
    func noteOff(pitch: UInt8, offset: Int) { pending.append((offset, 0x80, pitch, 0)) }
    func control(status: UInt8, _ data1: UInt8, _ data2: UInt8, offset: Int) {
        pending.append((offset, status, data1, data2))
    }
    func allNotesOff(offset: Int) { pending.append((offset, 0xB0, 123, 0)) }

    func render(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>,
                gainLeft: Float, gainRight: Float) {
        for event in pending {
            heard.append((clock + Int64(event.offset), event.status, event.data1, event.data2))
        }
        pending.removeAll()
        clock += Int64(frames)
    }
}

/// A hosted instrument hears what a host passes on from a played controller: besides notes, the
/// wheels and the controllers, also channel pressure, poly pressure and a program change (AUH-5d,
/// the engine half). Before this, the live path handed a plugin track only controllers and the
/// pitch wheel, and the other three were dropped on the render thread.
final class LiveChannelMessagesReachAHostedInstrumentTests: XCTestCase {
    private let rate = 48_000.0

    func testPressureProgramChangeAndPolyPressurePlayedLiveReachTheInstrumentAtTheNextBlock() throws {
        let (project, track) = try pluginSong()
        let unit = ListeningInstrument(sampleRate: rate)
        let core = engine(project, track: track, unit: unit)
        render(core, frames: 512)
        core.playLive(slot: 0, status: 0xD0, 90, 0)
        core.playLive(slot: 0, status: 0xC0, 7, 0)
        core.playLive(slot: 0, status: 0xA0, 60, 44)
        render(core, frames: 512)

        let kinds: Set<UInt8> = [0xA0, 0xC0, 0xD0]
        let heard = unit.heard.filter { (event: (frame: Int64, status: UInt8, data1: UInt8, data2: UInt8)) -> Bool in
            kinds.contains(event.status & 0xF0)
        }
        let statuses: [UInt8] = heard.map { $0.status & 0xF0 }
        let firstBytes: [UInt8] = heard.map { $0.data1 }
        let secondBytes: [UInt8] = heard.map { $0.data2 }
        let frames: [Int64] = heard.map { $0.frame }
        XCTAssertEqual(statuses, [0xD0, 0xC0, 0xA0], "pressure, program change and poly pressure, in the order played")
        XCTAssertEqual(firstBytes, [90, 7, 60], "the pressure, the program and the key")
        XCTAssertEqual(secondBytes, [0, 0, 44], "one data byte for pressure and program change, the key's pressure for poly")
        XCTAssertEqual(frames, [512, 512, 512], "at the start of the block after they were played")
    }

    /// A plugin track with one note, one beat in for half a beat; it does not play here.
    private func pluginSong() throws -> (Project, TrackID) {
        var project = Project(tempo: 120)
        let track = TrackID(), clip = ClipID()
        let plugin = PluginComponent(type: PluginComponent.code("aumu"), subtype: PluginComponent.code("Lstn"),
                                     manufacturer: PluginComponent.code("Test"), name: "Listen", manufacturerName: "Test")
        try Command.addTrack(id: track, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try Command.setInstrumentPlugin(track, plugin).apply(to: &project)
        try Command.createClip(track: track, id: clip, name: "C", length: MusicalTime.ticksPerBar(.common)).apply(to: &project)
        try Command.addNotes(clip, [Note(pitch: 60, velocity: 100, start: 960, length: 480)]).apply(to: &project)
        try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 0).apply(to: &project)
        return (project, track)
    }

    private func engine(_ project: Project, track: TrackID, unit: any HostedInstrument) -> EngineCore {
        let engine = EngineCore(sampleRate: rate)
        engine.setClickEnabled(false)
        var slots = SlotAssigner(capacity: engine.slotCapacity)
        slots.update(for: project)
        engine.publish(EngineSnapshot(plan: PlaybackPlan(compiling: project), project: project, slots: slots.slots,
                                      sampleRate: rate, generation: 1, units: [track: unit], effects: [track: []]))
        return engine
    }

    private func render(_ engine: EngineCore, frames: Int) {
        var left = [Float](repeating: 0, count: frames)
        var right = [Float](repeating: 0, count: frames)
        left.withUnsafeMutableBufferPointer { (l: inout UnsafeMutableBufferPointer<Float>) in
            right.withUnsafeMutableBufferPointer { (r: inout UnsafeMutableBufferPointer<Float>) in
                guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                engine.render(frameCount: frames, left: lp, right: rp)
            }
        }
    }
}
