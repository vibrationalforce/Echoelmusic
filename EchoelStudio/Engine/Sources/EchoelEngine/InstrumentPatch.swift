import EchoelCore
import EchoelDSP

extension SynthPatch {
    /// The DSP patch for a track's instrument settings — the one place the document's synth
    /// values become sound.
    public init(_ settings: InstrumentSettings) {
        func value(_ p: SynthParameter) -> Float { Float(settings.value(p)) }
        let waveforms: [Oscillator.Waveform] = [.sine, .saw, .square, .triangle]
        let index = Int(settings.value(.waveform).rounded())
        self.init(
            waveform: waveforms.indices.contains(index) ? waveforms[index] : .saw,
            filterMode: .lowpass,
            cutoff: value(.cutoff),
            resonance: value(.resonance),
            filterEnvelopeAmount: value(.filterAmount),
            filterEnvelope: .init(attack: 0.002, decay: value(.filterDecay), sustain: 0, release: value(.release)),
            ampEnvelope: .init(attack: value(.attack), decay: value(.decay), sustain: value(.sustain), release: value(.release)),
            level: value(.level)
        )
    }
}

/// One synth parameter the render thread can set on a patch without looking up a name: the
/// compiled form of an instrument automation lane.
public enum PatchField: Sendable, CaseIterable {
    case waveform, cutoff, resonance, filterAmount, filterDecay, attack, decay, sustain, release, level

    public init?(_ key: ParameterKey) {
        switch key {
        case SynthParameter.waveform.key: self = .waveform
        case SynthParameter.cutoff.key: self = .cutoff
        case SynthParameter.resonance.key: self = .resonance
        case SynthParameter.filterAmount.key: self = .filterAmount
        case SynthParameter.filterDecay.key: self = .filterDecay
        case SynthParameter.attack.key: self = .attack
        case SynthParameter.decay.key: self = .decay
        case SynthParameter.sustain.key: self = .sustain
        case SynthParameter.release.key: self = .release
        case SynthParameter.level.key: self = .level
        default: return nil
        }
    }

    /// Writes a document value into the patch the way `SynthPatch(_:)` would. Render-safe.
    public func apply(_ value: Double, to patch: inout SynthPatch) {
        let v = Float(value)
        switch self {
        case .waveform:
            switch Int(value.rounded()) {
            case 0: patch.waveform = .sine
            case 2: patch.waveform = .square
            case 3: patch.waveform = .triangle
            default: patch.waveform = .saw
            }
        case .cutoff: patch.cutoff = v
        case .resonance: patch.resonance = v
        case .filterAmount: patch.filterEnvelopeAmount = v
        case .filterDecay: patch.filterEnvelope.decay = v
        case .attack: patch.ampEnvelope.attack = v
        case .decay: patch.ampEnvelope.decay = v
        case .sustain: patch.ampEnvelope.sustain = v
        case .release:
            patch.ampEnvelope.release = v
            patch.filterEnvelope.release = v
        case .level: patch.level = v
        }
    }
}
