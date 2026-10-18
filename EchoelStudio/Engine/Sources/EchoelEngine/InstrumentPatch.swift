import EchoelCore
import EchoelDSP

extension SynthPatch {
    /// What no synth parameter sets: a lowpass filter whose envelope opens in 2 ms and falls to
    /// nothing. Every other field comes from a `PatchField`.
    static let parameterBase = SynthPatch(filterMode: .lowpass,
                                          filterEnvelope: .init(attack: 0.002, decay: 0.3, sustain: 0, release: 0.25))

    /// The DSP patch for a track's instrument settings. Built through `PatchField`, the one
    /// mapping from synth parameters to sound, which the plugin kernel and automation use too.
    public init(_ settings: InstrumentSettings) {
        var patch = Self.parameterBase
        for field in PatchField.allCases {
            field.apply(settings.value(field.parameter), to: &patch)
        }
        self = patch
    }
}

/// One synth parameter as the field of the DSP patch it sets — the ONE mapping from the
/// document's synth values to sound. The song's tracks (`SynthPatch(_:)`), the plugin kernel and
/// compiled automation all go through it, so the three cannot drift apart. The cases are in the
/// order of `SynthParameter.all`.
public enum PatchField: Sendable, CaseIterable {
    case waveform, cutoff, resonance, filterAmount, filterDecay, attack, decay, sustain, release, level

    /// The document parameter this field takes its value from.
    public var parameter: SynthParameter {
        switch self {
        case .waveform: .waveform
        case .cutoff: .cutoff
        case .resonance: .resonance
        case .filterAmount: .filterAmount
        case .filterDecay: .filterDecay
        case .attack: .attack
        case .decay: .decay
        case .sustain: .sustain
        case .release: .release
        case .level: .level
        }
    }

    public init?(_ key: ParameterKey) {
        guard let field = Self.allCases.first(where: { $0.parameter.key == key }) else { return nil }
        self = field
    }

    /// Writes a document value into the patch. Arithmetic only: render-safe.
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
