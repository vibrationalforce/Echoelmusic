import EchoelCore
import EchoelDSP
import Foundation

/// One parameter of an instrument kernel, as a plugin publishes it: the address is its index.
public struct InstrumentKernelParameter: Sendable, Equatable {
    /// Stable: hosts store automation and presets under it.
    public let identifier: String
    public let title: String
    public let unit: ParameterUnit
    public let range: ClosedRange<Double>
    public let defaultValue: Double
    public let choices: [String]

    public init(identifier: String, title: String, unit: ParameterUnit, range: ClosedRange<Double>,
                defaultValue: Double, choices: [String] = []) {
        self.identifier = identifier
        self.title = title
        self.unit = unit
        self.range = range
        self.defaultValue = defaultValue
        self.choices = choices
    }

    /// A row of a built-in device's Core table as its plugin publishes it. The ONE identifier rule:
    /// the key with "." written "_" (`synth.cutoff` → `synth_cutoff`); hosts store it, so it never
    /// changes for an existing row.
    public init(_ row: InstrumentParameter) {
        self.init(identifier: row.key.rawValue.replacingOccurrences(of: ".", with: "_"),
                  title: row.title, unit: row.unit, range: row.range,
                  defaultValue: row.defaultValue, choices: row.choices)
    }
}

/// What an Echoel instrument plugin plays: MIDI bytes in, stereo out, parameters by index.
/// One Audio Unit class serves every kernel, so the demo lock, the busses and the event loop
/// exist once.
///
/// Threading: `setParameter` and `parameter` may be called from any thread; `receive` and
/// `render` only from the render thread, and neither may allocate.
public protocol InstrumentKernel: AnyObject, Sendable {
    static var parameters: [InstrumentKernelParameter] { get }
    init(sampleRate: Double, maximumFrames: Int)
    var sampleRate: Double { get }
    func setParameter(_ address: Int, _ value: Float)
    func parameter(_ address: Int) -> Float
    func receive(status: UInt8, _ data1: UInt8, _ data2: UInt8)
    /// Overwrites `frames` of `left` and `right`; `gain` scales the output (the demo lock).
    func render(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, gain: Float)
}

/// What the app's engine needs from a built-in kernel beyond what a plugin host gives it (S-26 D2).
/// Engine only, render thread only, and nothing here allocates. The Audio Unit keeps using
/// `InstrumentKernel` alone, so a host sees no difference.
public protocol EngineInstrumentKernel: InstrumentKernel {
    /// Whether any voice is sounding. The engine renders a silent kernel not at all, as it never
    /// rendered a silent instrument: a synth that renders while silent glides its pitch wheel and
    /// vibrato on, and the next note would start somewhere else.
    var isSounding: Bool { get }
    /// Applies parameter values set since the last render now, so the next event already hears
    /// them. `render` does the same at its top.
    func commitParameters()
    /// Starts the kernel over for a new owner; the engine calls it when a slot changes hands or
    /// instrument. Every voice falls silent at once (CC 120, all sound off) and every controller
    /// comes to rest without a glide (pedal up, wheels centred), so the next note sounds as on a
    /// fresh kernel and nothing the last owner did with its wheels carries over.
    func reset()
}

/// A built-in kernel the engine hands a sample on the render thread (the sampler). The Audio Unit
/// loads through `SampleLoadingKernel` instead; never mix the two on one kernel.
public protocol SampleAssigningKernel: EngineInstrumentKernel {
    /// Render thread: plays `buffer` from now on (nil: no sample). The caller keeps the buffer
    /// alive until it knows rendering moved on.
    func assign(_ buffer: SampleBuffer?)
}

extension SynthKernel: InstrumentKernel {
    public static var parameters: [InstrumentKernelParameter] {
        InstrumentDevice.synth.parameters.map(InstrumentKernelParameter.init)
    }
}

extension SynthKernel: EngineInstrumentKernel {}
extension DrumKernel: EngineInstrumentKernel {}
extension SamplerKernel: SampleAssigningKernel {}
