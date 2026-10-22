import EchoelCore
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

extension SynthKernel: InstrumentKernel {
    public static var parameters: [InstrumentKernelParameter] {
        SynthParameter.all.map {
            InstrumentKernelParameter(identifier: $0.key.rawValue.replacingOccurrences(of: ".", with: "_"),
                                      title: $0.title, unit: $0.unit, range: $0.range,
                                      defaultValue: $0.defaultValue, choices: $0.choices)
        }
    }
}
