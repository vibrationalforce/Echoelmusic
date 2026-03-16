#if canImport(AVFoundation)
import Foundation
import AVFoundation
import os

/// AUv3 Audio Unit — EchoelVoice Bio-Reactive Vocal Processor
///
/// Vocal effect plugin with pitch correction, harmony generation,
/// and spectral analysis for CIE 1931 color visualization.
///
/// Component: aufx/evoc/Echo (effect processor)
public final class EchoelVoiceAudioUnit: AUAudioUnit {

    private static let auLog = OSLog(
        subsystem: "com.echoelmusic.voice.auv3",
        category: "AudioUnit"
    )

    // MARK: - DSP

    private let kernel = VocalDSPKernel()

    /// Exposed for UI spectral visualization reads
    var dspKernel: VocalDSPKernel { kernel }

    // MARK: - Buses

    private var _inputBusArray: AUAudioUnitBusArray!
    private var _outputBusArray: AUAudioUnitBusArray!
    private var inputBus: AUAudioUnitBus!
    private var outputBus: AUAudioUnitBus!

    // MARK: - Parameter Tree

    private var _parameterTree: AUParameterTree!

    // Parameter nodes
    private var correctionSpeedParam: AUParameter!
    private var correctionStrengthParam: AUParameter!
    private var rootNoteParam: AUParameter!
    private var scaleTypeParam: AUParameter!
    private var formantShiftParam: AUParameter!
    private var harmonyMixParam: AUParameter!
    private var harmonyInterval1Param: AUParameter!
    private var harmonyInterval2Param: AUParameter!
    private var inputGainParam: AUParameter!
    private var outputGainParam: AUParameter!
    private var dryWetParam: AUParameter!
    private var transposeParam: AUParameter!
    private var humanizeParam: AUParameter!

    // MARK: - Initialization

    public override init(
        componentDescription: AudioComponentDescription,
        options: AudioComponentInstantiationOptions = []
    ) throws {
        try super.init(componentDescription: componentDescription, options: options)

        let defaultFormat = AVAudioFormat(
            standardFormatWithSampleRate: 48000,
            channels: 2
        )!

        inputBus = try AUAudioUnitBus(format: defaultFormat)
        outputBus = try AUAudioUnitBus(format: defaultFormat)

        _inputBusArray = AUAudioUnitBusArray(
            audioUnit: self, busType: .input, busses: [inputBus]
        )
        _outputBusArray = AUAudioUnitBusArray(
            audioUnit: self, busType: .output, busses: [outputBus]
        )

        setupParameterTree()

        os_log(.info, log: Self.auLog, "EchoelVoice AUv3 initialized")
    }

    // MARK: - Parameter Tree Setup

    private func setupParameterTree() {
        // Pitch Correction group
        correctionSpeedParam = AUParameterTree.createParameter(
            withIdentifier: "correctionSpeed",
            name: "Correction Speed",
            address: VocalDSPKernel.ParameterAddress.correctionSpeed.rawValue,
            min: 0.0, max: 200.0,
            unit: .milliseconds,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        correctionSpeedParam.value = 50.0

        correctionStrengthParam = AUParameterTree.createParameter(
            withIdentifier: "correctionStrength",
            name: "Correction Strength",
            address: VocalDSPKernel.ParameterAddress.correctionStrength.rawValue,
            min: 0.0, max: 1.0,
            unit: .generic,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        correctionStrengthParam.value = 0.8

        rootNoteParam = AUParameterTree.createParameter(
            withIdentifier: "rootNote",
            name: "Key",
            address: VocalDSPKernel.ParameterAddress.rootNote.rawValue,
            min: 0.0, max: 11.0,
            unit: .indexed,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"],
            dependentParameters: nil
        )
        rootNoteParam.value = 0

        scaleTypeParam = AUParameterTree.createParameter(
            withIdentifier: "scaleType",
            name: "Scale",
            address: VocalDSPKernel.ParameterAddress.scaleType.rawValue,
            min: 0.0, max: 18.0,
            unit: .indexed,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: [
                "Chromatic", "Major", "Natural Minor", "Harmonic Minor", "Melodic Minor",
                "Pentatonic Maj", "Pentatonic Min", "Blues", "Dorian", "Phrygian",
                "Lydian", "Mixolydian", "Locrian", "Whole Tone", "Diminished",
                "Augmented", "Arabian", "Japanese", "Hungarian"
            ],
            dependentParameters: nil
        )
        scaleTypeParam.value = 0

        transposeParam = AUParameterTree.createParameter(
            withIdentifier: "transpose",
            name: "Transpose",
            address: VocalDSPKernel.ParameterAddress.transpose.rawValue,
            min: -24.0, max: 24.0,
            unit: .relativeSemiTones,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        transposeParam.value = 0

        humanizeParam = AUParameterTree.createParameter(
            withIdentifier: "humanize",
            name: "Humanize",
            address: VocalDSPKernel.ParameterAddress.humanize.rawValue,
            min: 0.0, max: 1.0,
            unit: .generic,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        humanizeParam.value = 0.2

        let pitchGroup = AUParameterTree.createGroup(
            withIdentifier: "pitch",
            name: "Pitch Correction",
            children: [correctionSpeedParam, correctionStrengthParam,
                       rootNoteParam, scaleTypeParam, transposeParam, humanizeParam]
        )

        // Formant group
        formantShiftParam = AUParameterTree.createParameter(
            withIdentifier: "formantShift",
            name: "Formant Shift",
            address: VocalDSPKernel.ParameterAddress.formantShift.rawValue,
            min: -12.0, max: 12.0,
            unit: .relativeSemiTones,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        formantShiftParam.value = 0.0

        let formantGroup = AUParameterTree.createGroup(
            withIdentifier: "formant",
            name: "Formant",
            children: [formantShiftParam]
        )

        // Harmony group
        harmonyMixParam = AUParameterTree.createParameter(
            withIdentifier: "harmonyMix",
            name: "Harmony Mix",
            address: VocalDSPKernel.ParameterAddress.harmonyMix.rawValue,
            min: 0.0, max: 1.0,
            unit: .generic,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        harmonyMixParam.value = 0.0

        harmonyInterval1Param = AUParameterTree.createParameter(
            withIdentifier: "harmonyInterval1",
            name: "Harmony 1",
            address: VocalDSPKernel.ParameterAddress.harmonyInterval1.rawValue,
            min: -12.0, max: 12.0,
            unit: .relativeSemiTones,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        harmonyInterval1Param.value = 4.0  // Major 3rd

        harmonyInterval2Param = AUParameterTree.createParameter(
            withIdentifier: "harmonyInterval2",
            name: "Harmony 2",
            address: VocalDSPKernel.ParameterAddress.harmonyInterval2.rawValue,
            min: -12.0, max: 12.0,
            unit: .relativeSemiTones,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        harmonyInterval2Param.value = 7.0  // Perfect 5th

        let harmonyGroup = AUParameterTree.createGroup(
            withIdentifier: "harmony",
            name: "Harmony",
            children: [harmonyMixParam, harmonyInterval1Param, harmonyInterval2Param]
        )

        // Gain group
        inputGainParam = AUParameterTree.createParameter(
            withIdentifier: "inputGain",
            name: "Input Gain",
            address: VocalDSPKernel.ParameterAddress.inputGain.rawValue,
            min: 0.0, max: 2.0,
            unit: .linearGain,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        inputGainParam.value = 1.0

        outputGainParam = AUParameterTree.createParameter(
            withIdentifier: "outputGain",
            name: "Output Gain",
            address: VocalDSPKernel.ParameterAddress.outputGain.rawValue,
            min: 0.0, max: 2.0,
            unit: .linearGain,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        outputGainParam.value = 1.0

        dryWetParam = AUParameterTree.createParameter(
            withIdentifier: "dryWet",
            name: "Dry/Wet",
            address: VocalDSPKernel.ParameterAddress.dryWet.rawValue,
            min: 0.0, max: 1.0,
            unit: .generic,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        dryWetParam.value = 1.0

        let gainGroup = AUParameterTree.createGroup(
            withIdentifier: "gain",
            name: "Gain",
            children: [inputGainParam, outputGainParam, dryWetParam]
        )

        // Build tree
        _parameterTree = AUParameterTree.createTree(
            withChildren: [pitchGroup, formantGroup, harmonyGroup, gainGroup]
        )

        // Parameter value provider
        _parameterTree.implementorValueProvider = { [weak self] param in
            guard let self,
                  let address = VocalDSPKernel.ParameterAddress(rawValue: param.address) else {
                return param.value
            }
            return self.kernel.getParameter(address: address)
        }

        // Parameter value observer
        _parameterTree.implementorValueObserver = { [weak self] param, value in
            guard let self,
                  let address = VocalDSPKernel.ParameterAddress(rawValue: param.address) else {
                return
            }
            self.kernel.setParameter(address: address, value: value)
        }

        // String value provider
        _parameterTree.implementorStringFromValueCallback = { param, valuePtr in
            let value = valuePtr?.pointee ?? param.value
            switch param.address {
            case VocalDSPKernel.ParameterAddress.correctionSpeed.rawValue:
                if value <= 0 { return "Hard" }
                return String(format: "%.0f ms", value)
            case VocalDSPKernel.ParameterAddress.rootNote.rawValue:
                let notes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
                let idx = Int(value) % 12
                return notes[idx]
            case VocalDSPKernel.ParameterAddress.transpose.rawValue,
                 VocalDSPKernel.ParameterAddress.harmonyInterval1.rawValue,
                 VocalDSPKernel.ParameterAddress.harmonyInterval2.rawValue,
                 VocalDSPKernel.ParameterAddress.formantShift.rawValue:
                let v = Int(value)
                if v > 0 { return "+\(v) st" }
                if v < 0 { return "\(v) st" }
                return "0 st"
            default:
                return String(format: "%.2f", value)
            }
        }
    }

    // MARK: - AUAudioUnit Overrides

    public override var parameterTree: AUParameterTree? { _parameterTree }
    public override var inputBusses: AUAudioUnitBusArray { _inputBusArray }
    public override var outputBusses: AUAudioUnitBusArray { _outputBusArray }
    public override var canProcessInPlace: Bool { true }
    public override var supportsUserPresets: Bool { true }
    public override var latency: TimeInterval { 0 }
    public override var tailTime: TimeInterval { 0.1 }

    // MARK: - Factory Presets

    public override var factoryPresets: [AUAudioUnitPreset]? {
        [
            AUAudioUnitPreset(number: 0, name: "Natural"),
            AUAudioUnitPreset(number: 1, name: "Pop"),
            AUAudioUnitPreset(number: 2, name: "Auto-Tune"),
            AUAudioUnitPreset(number: 3, name: "Hard Tune"),
            AUAudioUnitPreset(number: 4, name: "Harmony"),
            AUAudioUnitPreset(number: 5, name: "Octave Up"),
            AUAudioUnitPreset(number: 6, name: "Choir")
        ]
    }

    public override var currentPreset: AUAudioUnitPreset? {
        didSet {
            guard let preset = currentPreset, preset.number >= 0 else { return }
            applyFactoryPreset(preset.number)
        }
    }

    private func applyFactoryPreset(_ number: Int) {
        switch number {
        case 0: // Natural
            correctionSpeedParam.value = 150
            correctionStrengthParam.value = 0.5
            humanizeParam.value = 0.5
            harmonyMixParam.value = 0.0
            formantShiftParam.value = 0.0
            transposeParam.value = 0

        case 1: // Pop
            correctionSpeedParam.value = 50
            correctionStrengthParam.value = 0.8
            humanizeParam.value = 0.2
            harmonyMixParam.value = 0.0
            formantShiftParam.value = 0.0
            transposeParam.value = 0

        case 2: // Auto-Tune
            correctionSpeedParam.value = 10
            correctionStrengthParam.value = 0.95
            humanizeParam.value = 0.05
            harmonyMixParam.value = 0.0
            formantShiftParam.value = 0.0
            transposeParam.value = 0

        case 3: // Hard Tune
            correctionSpeedParam.value = 0
            correctionStrengthParam.value = 1.0
            humanizeParam.value = 0.0
            harmonyMixParam.value = 0.0
            formantShiftParam.value = 0.0
            transposeParam.value = 0

        case 4: // Harmony
            correctionSpeedParam.value = 50
            correctionStrengthParam.value = 0.8
            humanizeParam.value = 0.2
            harmonyMixParam.value = 0.6
            harmonyInterval1Param.value = 4  // Major 3rd
            harmonyInterval2Param.value = 7  // Perfect 5th

        case 5: // Octave Up
            correctionSpeedParam.value = 50
            correctionStrengthParam.value = 0.8
            humanizeParam.value = 0.1
            harmonyMixParam.value = 0.0
            transposeParam.value = 12

        case 6: // Choir
            correctionSpeedParam.value = 80
            correctionStrengthParam.value = 0.7
            humanizeParam.value = 0.3
            harmonyMixParam.value = 0.8
            harmonyInterval1Param.value = 3   // Minor 3rd
            harmonyInterval2Param.value = 7   // Perfect 5th

        default:
            break
        }
    }

    // MARK: - State Save/Restore

    public override var fullState: [String: Any]? {
        get {
            var state = super.fullState ?? [:]
            state["correctionSpeed"] = correctionSpeedParam.value
            state["correctionStrength"] = correctionStrengthParam.value
            state["rootNote"] = rootNoteParam.value
            state["scaleType"] = scaleTypeParam.value
            state["formantShift"] = formantShiftParam.value
            state["harmonyMix"] = harmonyMixParam.value
            state["harmonyInterval1"] = harmonyInterval1Param.value
            state["harmonyInterval2"] = harmonyInterval2Param.value
            state["inputGain"] = inputGainParam.value
            state["outputGain"] = outputGainParam.value
            state["dryWet"] = dryWetParam.value
            state["transpose"] = transposeParam.value
            state["humanize"] = humanizeParam.value
            return state
        }
        set {
            super.fullState = newValue
            guard let state = newValue else { return }
            if let v = state["correctionSpeed"] as? Float { correctionSpeedParam.value = v }
            if let v = state["correctionStrength"] as? Float { correctionStrengthParam.value = v }
            if let v = state["rootNote"] as? Float { rootNoteParam.value = v }
            if let v = state["scaleType"] as? Float { scaleTypeParam.value = v }
            if let v = state["formantShift"] as? Float { formantShiftParam.value = v }
            if let v = state["harmonyMix"] as? Float { harmonyMixParam.value = v }
            if let v = state["harmonyInterval1"] as? Float { harmonyInterval1Param.value = v }
            if let v = state["harmonyInterval2"] as? Float { harmonyInterval2Param.value = v }
            if let v = state["inputGain"] as? Float { inputGainParam.value = v }
            if let v = state["outputGain"] as? Float { outputGainParam.value = v }
            if let v = state["dryWet"] as? Float { dryWetParam.value = v }
            if let v = state["transpose"] as? Float { transposeParam.value = v }
            if let v = state["humanize"] as? Float { humanizeParam.value = v }
        }
    }

    // MARK: - Rendering

    public override func allocateRenderResources() throws {
        try super.allocateRenderResources()

        let format = outputBus.format
        kernel.prepare(
            sampleRate: format.sampleRate,
            maxFrames: maximumFramesToRender,
            channelCount: Int(format.channelCount)
        )

        os_log(.info, log: Self.auLog,
               "Render resources allocated: %.0f Hz, %d ch, %d max frames",
               format.sampleRate, format.channelCount, maximumFramesToRender)
    }

    public override func deallocateRenderResources() {
        super.deallocateRenderResources()
        kernel.reset()
        os_log(.info, log: Self.auLog, "Render resources deallocated")
    }

    public override var internalRenderBlock: AUInternalRenderBlock {
        let kernel = self.kernel

        return { (actionFlags, timestamp, frameCount, outputBusNumber,
                  outputData, renderEvent, pullInputBlock) in

            guard let pullInputBlock else {
                return kAudioUnitErr_NoConnection
            }

            var pullFlags: AudioUnitRenderActionFlags = []
            let status = pullInputBlock(&pullFlags, timestamp, frameCount, 0, outputData)
            guard status == noErr else { return status }

            kernel.process(
                inputBufferList: UnsafePointer(outputData),
                outputBufferList: outputData,
                frameCount: frameCount
            )

            return noErr
        }
    }
}
#endif
