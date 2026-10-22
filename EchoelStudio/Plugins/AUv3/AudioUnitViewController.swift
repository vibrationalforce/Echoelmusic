import AudioToolbox
import EchoelCore
import EchoelEngine
import EchoelKernels

/// The principal class of the one Echoel extension (`com.echoelmusic.app.auv3`). It carries every
/// Echoel Audio Unit; the host's component description says which one to make.
final class AudioUnitViewController: PluginViewController {
    nonisolated override class func makeUnit(_ componentDescription: AudioComponentDescription) throws -> any EchoelPluginUnit {
        switch componentDescription.componentSubType {
        case OwnPlugin.synth.component.subtype, OwnPlugin.legacyBodyVibe.component.subtype:
            return try InstrumentAudioUnit(kernel: SynthKernel.self, title: OwnPlugin.synth.component.name,
                                           componentDescription: componentDescription)
        case OwnPlugin.drums.component.subtype:
            return try InstrumentAudioUnit(
                kernel: DrumKernel.self, title: OwnPlugin.drums.component.name,
                help: "General MIDI drum map: kick 36 · snare 38 · clap 39 · toms 41–50 · closed hat 42 · open hat 46 · crash 49.",
                componentDescription: componentDescription)
        case OwnPlugin.sampler.component.subtype:
            return try InstrumentAudioUnit(
                kernel: SamplerKernel.self, title: OwnPlugin.sampler.component.name,
                help: "Set Root key to the note the sample was recorded at; every other key transposes it.",
                componentDescription: componentDescription)
        default:
            // The four effects; anything else is refused by the unit itself.
            return try StandardEffectUnit(componentDescription: componentDescription, options: [])
        }
    }
}

extension StandardEffectUnit: EchoelPluginUnit {
    var title: String { effect.extensionComponent.name }
    /// The effects are free in other hosts as in Echoel.
    var needsPurchase: Bool { false }
}
