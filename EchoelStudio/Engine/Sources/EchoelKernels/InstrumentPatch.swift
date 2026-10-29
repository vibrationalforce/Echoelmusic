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
/// compiled automation all go through it, so the three cannot drift apart. The cases ARE Core's
/// `SynthParameter.Name` (with its `parameter` and `init?(_:)`), so there is no second list here:
/// a new synth parameter fails to compile until `apply` below maps it to the DSP.
public typealias PatchField = SynthParameter.Name

extension SynthParameter.Name {
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
        case .engine:
            switch Int(value.rounded()) {
            case 1: patch.engine = .supersaw
            case 2: patch.engine = .fm
            case 3: patch.engine = .sub
            case 4: patch.engine = .morph
            case 5: patch.engine = .mallet
            case 6: patch.engine = .ddsp
            default: patch.engine = .classic
            }
        case .character: patch.character = v
        case .filter: patch.filterModel = Int(value.rounded()) == 1 ? .ladder : .stateVariable
        }
    }
}
