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
