import AudioToolbox
import EchoelCore
import EchoelEngine

/// The Echoel Effects extension's principal class. One extension carries the four standard
/// effects; the host's component description says which one to make.
final class AudioUnitViewController: PluginViewController {
    nonisolated override class func makeUnit(_ componentDescription: AudioComponentDescription) throws -> any EchoelPluginUnit {
        try StandardEffectUnit(componentDescription: componentDescription, options: [])
    }
}

extension StandardEffectUnit: EchoelPluginUnit {
    var plugin: OwnPlugin { .effects }
    var title: String { effect.extensionComponent.name }
}
