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

    /// The device's presets of the app, in the app's order, by address. A row a preset does not
    /// name takes its song default, because loading a preset in the app replaces every synth value
    /// (`Command.loadInstrumentPreset`): a host and a song hear the same sound under one name.
    /// The drums and the sampler have no presets in the app, so they offer none. Builds arrays.
    public static func factory(for device: InstrumentDevice) -> [InstrumentKernelPreset] {
        guard device == .synth else { return [] }
        let rows = device.parameters
        return InstrumentPreset.all.map { preset in
            let settings = InstrumentSettings(values: preset.values)
            return InstrumentKernelPreset(name: preset.name, values: rows.map { Float(settings.value($0)) })
        }
    }
}
