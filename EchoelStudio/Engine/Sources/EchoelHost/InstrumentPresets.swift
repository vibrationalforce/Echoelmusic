import AudioToolbox
import EchoelKernels

/// An instrument kernel's factory presets as its Audio Unit offers them to a host
/// (`AUAudioUnit.factoryPresets`, `currentPreset`). Kept here rather than in the plugin's shell so
/// the choice a host makes can be tested on the host's side.
public enum InstrumentPresets {
    /// What a host lists: one preset per factory preset, numbered by its place (0, 1, …). A host
    /// stores the number in its session, so the order is the app's and only ever grows at the end.
    public static func menu(_ presets: [InstrumentKernelPreset]) -> [AUAudioUnitPreset] {
        presets.enumerated().map { index, preset in
            let item = AUAudioUnitPreset()
            item.number = index
            item.name = preset.name
            return item
        }
    }

    /// The factory preset a host chose by its number; nil for a user preset (a negative number)
    /// and for a number past the list (a session from a build that had more).
    public static func factory(_ number: Int, in presets: [InstrumentKernelPreset]) -> InstrumentKernelPreset? {
        guard number >= 0, number < presets.count else { return nil }
        return presets[number]
    }

    /// Sets every value of `preset` through the tree, so the kernel (the tree's implementor), the
    /// host's controls and its automation all see it. Off the render thread: a host chooses a
    /// preset from its own interface.
    public static func apply(_ preset: InstrumentKernelPreset, to tree: AUParameterTree) {
        for (address, value) in preset.values.enumerated() {
            tree.parameter(withAddress: AUParameterAddress(address))?.value = AUValue(value)
        }
    }
}
