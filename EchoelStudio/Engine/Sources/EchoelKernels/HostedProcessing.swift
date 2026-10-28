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

/// Where the song is at the first sample of a render call, as a hosted Audio Unit asks its host
/// for it: a tempo-synced delay, an LFO, an arpeggiator or a step sequencer follows it. Beats are
/// quarter notes from the song's start, as Audio Units count them.
public struct HostTransport: Equatable, Sendable {
    public var isPlaying: Bool
    /// The transport started, stopped or jumped since the render call before.
    public var changed: Bool
    public var tempo: Double
    public var numerator: Int
    public var denominator: Int
    public var beat: Double
    /// The beat on which the bar holding `beat` starts.
    public var downbeat: Double
    /// Frames from this call's first sample to the next quarter note — a beat as Audio Units count
    /// it, not the signature's beat (in 6/8 that would be an eighth); 0 while stopped.
    public var samplesToNextBeat: Int
    /// The song position in samples.
    public var sample: Double

    public init(isPlaying: Bool, changed: Bool, tempo: Double, numerator: Int, denominator: Int, beat: Double,
                downbeat: Double, samplesToNextBeat: Int, sample: Double) {
        self.isPlaying = isPlaying
        self.changed = changed
        self.tempo = tempo
        self.numerator = numerator
        self.denominator = denominator
        self.beat = beat
        self.downbeat = downbeat
        self.samplesToNextBeat = samplesToNextBeat
        self.sample = sample
    }
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
    /// All notes off with the pedal lifted and the wheel centred, `offset` frames into the next
    /// `render` call: 0 for a stop or a seek at a block's start, the boundary's frame for a clip
    /// launched or stopped inside a block, so a note played just before it in the same block ends
    /// too (audit 2026-10-23).
    func allNotesOff(offset: Int)
    /// Where the song is for the next `render` call. Render thread, must not allocate.
    func follow(_ transport: HostTransport)
    /// Renders `frames` and adds them into `left` and `right` at the lane's gains.
    func render(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>,
                gainLeft: Float, gainRight: Float)
    /// The blocks the unit refused to render since it was made: each one left silence where its
    /// sound belonged. Any thread; an export reads it after its render to fail instead of saving
    /// a file with holes (Codex handover S6).
    var renderFailures: Int { get }
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
    /// Where the song is for the next `process` call. Render thread, must not allocate.
    func follow(_ transport: HostTransport)
    /// Replaces `frames` of the bus with the effect's output.
    func process(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>)
    /// The blocks the effect refused to process since it was made (see `HostedInstrument`).
    var renderFailures: Int { get }
}

/// Units that keep no time of their own — the built-in kernels, a test's stand-in — ignore it,
/// and units that cannot refuse a block report no failures.
extension HostedInstrument {
    public func follow(_ transport: HostTransport) {}
    public var renderFailures: Int { 0 }
}

extension HostedProcessor {
    public func follow(_ transport: HostTransport) {}
    public var renderFailures: Int { 0 }
}
