import EchoelCore

/// A starting sound an instrument plugin offers a host as a factory preset (the preset menu of
/// AUM and GarageBand): its name and a value for every address of the kernel, so choosing it
/// sounds as the same preset does in the app.
public struct InstrumentKernelPreset: Sendable, Equatable {
    public let name: String
    /// By address: `values[i]` is the value of the kernel's `parameters[i]`.
    public let values: [Float]
    /// Addresses a host's choice of this preset leaves as they are: the sampler's root key, which
    /// belongs to the sample it plays, not to a sound. Empty for the synth's and the drums'.
    public let leaves: Set<Int>

    public init(name: String, values: [Float], leaves: Set<Int> = []) {
        self.name = name
        self.values = values
        self.leaves = leaves
    }

    /// The device's starting sounds, in their order, by address. The synth's are the app's
    /// presets, and a row a preset does not name takes its song default, because loading a preset
    /// in the app replaces every synth value (`Command.loadInstrumentPreset`): a host and a song
    /// hear the same sound under one name. The drums offer their kits (`InstrumentPreset.drumKits`),
    /// the sampler its envelope shapes (`InstrumentPreset.samplerShapes`), each leaving the root key
    /// of the sample it plays. Builds arrays.
    public static func factory(for device: InstrumentDevice) -> [InstrumentKernelPreset] {
        let presets: [InstrumentPreset]
        switch device {
        case .synth: presets = InstrumentPreset.all
        case .drums: presets = InstrumentPreset.drumKits
        case .sampler: presets = InstrumentPreset.samplerShapes
        case .plugin, .unrecognized: return []
        }
        let rows = device.parameters
        let root = rows.firstIndex { $0.key == SynthParameter.samplerRoot.key }
        let leaves: Set<Int> = root.map { [$0] } ?? []
        return presets.map { preset in
            let settings = InstrumentSettings(values: preset.values)
            return InstrumentKernelPreset(name: preset.name, values: rows.map { Float(settings.value($0)) },
                                          leaves: leaves)
        }
    }
}
