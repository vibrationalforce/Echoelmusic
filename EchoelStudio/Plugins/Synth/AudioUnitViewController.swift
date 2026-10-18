import AudioToolbox
import EchoelCore
import EchoelEngine

/// The Echoel Synth extension's principal class.
final class AudioUnitViewController: PluginViewController {
    nonisolated override class func makeUnit(_ componentDescription: AudioComponentDescription) throws -> any EchoelPluginUnit {
        try InstrumentAudioUnit(kernel: SynthKernel.self, plugin: .synth, componentDescription: componentDescription)
    }
}
