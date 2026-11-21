import EchoelCore

/// A starting sound an instrument plugin offers a host as a factory preset (the preset menu of
/// AUM and GarageBand): its name and a value for every address of the kernel, so choosing it
/// sounds as the same preset does in the app.
public struct InstrumentKernelPreset: Sendable, Equatable {
    public let name: String
    /// By address: `values[i]` is the value of the kernel's `parameters[i]`.
    public let values: [Float]

    public init(name: String, values: [Float]) {
        self.name = name
        self.values = values
    }

    /// The device's starting sounds, in their order, by address. The synth's are the app's
    /// presets, and a row a preset does not name takes its song default, because loading a preset
    /// in the app replaces every synth value (`Command.loadInstrumentPreset`): a host and a song
    /// hear the same sound under one name. The drums offer their kits (`InstrumentPreset.drumKits`).
    /// The sampler offers none yet: a preset sets every address, and its root key belongs to the
    /// sample, not to a sound. Builds arrays.
    public static func factory(for device: InstrumentDevice) -> [InstrumentKernelPreset] {
        let presets: [InstrumentPreset]
        switch device {
        case .synth: presets = InstrumentPreset.all
        case .drums: presets = InstrumentPreset.drumKits
        case .sampler, .plugin, .unrecognized: return []
        }
        let rows = device.parameters
        return presets.map { preset in
            let settings = InstrumentSettings(values: preset.values)
            return InstrumentKernelPreset(name: preset.name, values: rows.map { Float(settings.value($0)) })
        }
    }
}
