import AudioToolbox
import EchoelCore
import EchoelKernels

/// An instrument kernel's parameters as the tree its Audio Unit publishes: the address is the
/// index, a named choice reaches a host as its names. Kept here rather than in the plugin's shell
/// so what a host is told can be tested on the host's side.
public enum InstrumentParameterTree {
    /// The tree for `kernel`, each node at its default. `.flag_CanRamp` only where the kernel
    /// glides a host's ramp itself (`InstrumentKernel.canRamp`): a host ramps the others by
    /// sending values, which a kernel that takes a ramp's end value at once would otherwise skip.
    public static func make(for kernel: any InstrumentKernel.Type) -> AUParameterTree {
        let nodes = kernel.parameters.enumerated().map { index, parameter in
            let unit: AudioUnitParameterUnit = switch parameter.unit {
            case .hertz: .hertz
            case .seconds: .seconds
            case .octaves: .octaves
            case .decibel: .decibels
            case .bpm: .BPM
            case .choice: .indexed
            // Pan and plain amounts read as numbers; the units a host knows are named above.
            default: .generic
            }
            var flags: AudioUnitParameterOptions = [.flag_IsReadable, .flag_IsWritable]
            if kernel.canRamp(index) { flags.insert(.flag_CanRamp) }
            let node = AUParameterTree.createParameter(
                withIdentifier: parameter.identifier, name: parameter.title, address: AUParameterAddress(index),
                min: AUValue(parameter.range.lowerBound), max: AUValue(parameter.range.upperBound), unit: unit,
                unitName: nil, flags: flags,
                valueStrings: parameter.choices.isEmpty ? nil : parameter.choices, dependentParameters: nil)
            node.value = AUValue(parameter.defaultValue)
            return node
        }
        return AUParameterTree.createTree(withChildren: nodes)
    }
}
