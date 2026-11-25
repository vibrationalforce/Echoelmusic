import AVFoundation
import Foundation

/// What an Echoel unit tells a host about its busses, and the one sample layout its render block
/// reads and fills. Kept here rather than in the plugin's shell (`Plugins/Shared/InstrumentAudioUnit`),
/// like `InstrumentParameterTree`, so what a host is told can be tested on the host's side.
public enum UnitFormat {
    private enum BusError: Error { case missingInput, missingOutput }

    /// Negotiate the main stereo path after restoring a preset and before allocating resources.
    /// Set the input first for effects whose output format follows their input.
    public static func configureHostedBusses(_ unit: AUAudioUnit, isEffect: Bool, sampleRate: Double) throws {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2),
              unit.outputBusses.count > 0 else { throw BusError.missingOutput }

        func configure(_ bus: AUAudioUnitBus) throws {
            let current = bus.format
            if current.sampleRate != sampleRate || !accepts(current) {
                try bus.setFormat(format)
            }
        }
        if isEffect {
            guard unit.inputBusses.count > 0 else { throw BusError.missingInput }
            unit.inputBusses[0].isEnabled = true
            try configure(unit.inputBusses[0])
        }
        unit.outputBusses[0].isEnabled = true
        try configure(unit.outputBusses[0])
    }

    /// An instrument's channels (`AUAudioUnit.channelCapabilities`, input count then output count):
    /// no input, two outputs. A unit that states nothing leaves a host to guess; it may then offer
    /// the instrument in mono, set that format, and be refused only when it allocates.
    public static let instrumentCapabilities: [NSNumber] = [0, 2]

    /// The channel counts a bus takes (`AUAudioUnitBus.supportedChannelCounts`): stereo.
    public static let channelCounts: [NSNumber] = [2]

    /// Whether a render block can read or fill a bus of `format`: 32-bit float, one buffer per
    /// channel, exactly two channels, at a real sample rate. An interleaved stereo format reaches a
    /// render block as ONE buffer of both channels, and a mono one as one buffer too.
    public static func accepts(_ format: AVAudioFormat) -> Bool {
        format.commonFormat == .pcmFormatFloat32 && !format.isInterleaved && format.channelCount == 2
            && format.sampleRate.isFinite && format.sampleRate > 0
    }
}
