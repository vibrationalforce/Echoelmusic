import AudioToolbox
import Foundation

/// Tells its owner when a loaded unit replaced its parameter tree, or said that every parameter's
/// value changed at once (`allParameterValues`, a preset the unit chose itself). Some units build
/// a new tree when a mode changes or a preset loads; the host's ranges and its observer then
/// belong to a tree that is gone, and automation would move what is no longer there.
///
/// Key-value observation, which a unit may post from any thread: `onChange` is called on that
/// thread and must hop to where it works. Never the render thread's business.
public final class ParameterTreeWatch: @unchecked Sendable {
    private var observations: [NSKeyValueObservation] = []

    public init(_ unit: AUAudioUnit, onChange: @escaping @Sendable () -> Void) {
        observations = [
            unit.observe(\.parameterTree, options: [.new]) { _, _ in onChange() },
            unit.observe(\.allParameterValues, options: [.new]) { _, _ in onChange() },
        ]
    }

    deinit {
        observations.forEach { $0.invalidate() }
    }
}

extension HostedParameters {
    /// The parameters automation may move, by address: writable, with a real range. Read when a
    /// unit is loaded — after its saved settings, since some units build their tree from them —
    /// and again whenever its tree changes (`ParameterTreeWatch`).
    public static func automatableRanges(_ tree: AUParameterTree?) -> [UInt64: ClosedRange<Float>] {
        var ranges: [UInt64: ClosedRange<Float>] = [:]
        for parameter in tree?.allParameters ?? [] where parameter.flags.contains(.flag_IsWritable) {
            let low = parameter.minValue, high = parameter.maxValue
            guard low.isFinite, high.isFinite, high > low else { continue }
            ranges[parameter.address] = low...high
        }
        return ranges
    }
}
