import AudioToolbox
import EchoelCore
import EchoelEngine

/// The Echoel Drums extension's principal class.
final class AudioUnitViewController: PluginViewController {
    nonisolated override class func makeUnit(_ componentDescription: AudioComponentDescription) throws -> any EchoelPluginUnit {
        try InstrumentAudioUnit(
            kernel: DrumKernel.self, plugin: .drums,
            help: "General MIDI drum map: kick 36 · snare 38 · clap 39 · toms 41–50 · closed hat 42 · open hat 46 · crash 49.",
            componentDescription: componentDescription)
    }
}
