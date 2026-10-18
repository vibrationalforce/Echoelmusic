import AudioToolbox
import EchoelCore
import EchoelEngine

/// The Echoel Sampler extension's principal class.
final class AudioUnitViewController: PluginViewController {
    nonisolated override class func makeUnit(_ componentDescription: AudioComponentDescription) throws -> any EchoelPluginUnit {
        try InstrumentAudioUnit(
            kernel: SamplerKernel.self, plugin: .sampler,
            help: "Set Root key to the note the sample was recorded at; every other key transposes it.",
            componentDescription: componentDescription)
    }
}
