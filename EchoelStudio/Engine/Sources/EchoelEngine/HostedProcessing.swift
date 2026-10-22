import EchoelCore
import Foundation

/// A hosted unit whose parameters automation moves. The ranges are read once, on the main
/// thread; `schedule` is called on the render thread, for the unit's next render call.
public protocol ParameterScheduling: AnyObject, Sendable {
    /// The unit's writable parameters by address, each with its range.
    var parameterRanges: [UInt64: ClosedRange<Float>] { get }
    /// Moves `address` to `value`, `offset` frames into the next render call, gliding over
    /// `ramp` frames where the unit can.
    func schedule(address: UInt64, value: Float, offset: Int, ramp: Int)
}

/// An instrument the engine plays from inside its own render pass — a hosted Audio Unit. The
/// engine names only this protocol, never the class that wraps the unit, so it needs no
/// AudioToolbox.
///
/// Threading: `sampleRate` and `parameterRanges` are read on the main thread when a snapshot is
/// compiled. Everything else runs on the render thread only and must not allocate.
public protocol HostedInstrument: ParameterScheduling {
    var sampleRate: Double { get }
    /// A note-on `offset` frames into the next `render` call.
    func noteOn(pitch: UInt8, velocity: UInt8, offset: Int)
    func noteOff(pitch: UInt8, offset: Int)
    /// A pitch bend (`0xE0`) or a controller (`0xB0`), `offset` frames into the next `render` call.
    func control(status: UInt8, _ data1: UInt8, _ data2: UInt8, offset: Int)
    /// All notes off with the pedal lifted and the wheel centred, at the start of the next
    /// `render` call.
    func allNotesOff()
    /// Renders `frames` and adds them into `left` and `right` at the lane's gains.
    func render(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>,
                gainLeft: Float, gainRight: Float)
}

/// An effect on an insert chain, processed inside the engine's own render pass.
///
/// Threading: `sampleRate`, `isBypassed`, `insert` and `parameterRanges` are read on the main
/// thread when a snapshot is compiled; `process` runs on the render thread only and must not
/// allocate.
public protocol HostedProcessor: ParameterScheduling {
    var sampleRate: Double { get }
    /// A bypassed effect is skipped; the bus passes through unchanged.
    var isBypassed: Bool { get }
    /// The insert this effect plays, so the song's automation of it finds it.
    var insert: InsertID? { get }
    /// Replaces `frames` of the bus with the effect's output.
    func process(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>)
}
