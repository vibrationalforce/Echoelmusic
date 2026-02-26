//
//  EchoelmusicAudioUnit.swift
//  EchoelmusicAUv3
//
//  Created: December 2025
//  AUDIO UNIT v3 BASE CLASS
//  Universal AUv3 wrapper for Echoelmusic — all 10 Echoel* tools as plugins
//
//  10 AUv3 Plugins — each with dedicated DSP kernel:
//  ┌──────────────────────────────────────────────────────────────────────┐
//  │ Instruments (aumu)                                                  │
//  │   EchoelSynth (Esyn) — TR808 bass synthesizer                     │
//  │   EchoelBio   (Ebio) — Binaural beat generator (brainwave states) │
//  │                                                                     │
//  │ Effects (aufx)                                                      │
//  │   EchoelFX    (Eefx) — Freeverb algorithmic reverb                │
//  │   EchoelMix   (Emix) — Analog-style compressor (soft-knee)        │
//  │   EchoelField (Efld) — Multi-mode biquad filter (LP/HP/BP/Notch)  │
//  │   EchoelMind  (Emnd) — 8 analog console emulations                │
//  │                                                                     │
//  │ MIDI Processors (aumi)                                              │
//  │   EchoelSeq   (Eseq) — Step sequencer with drum synthesis         │
//  │   EchoelMIDI  (Emid) — MIDI processor with synthesis              │
//  │   EchoelBeam  (Ebem) — Audio-to-lighting DMX bridge               │
//  │   EchoelNet   (Enet) — Network protocol bridge (OSC/MSC/Dante)    │
//  └──────────────────────────────────────────────────────────────────────┘
//
//  C++ DSP (via bridge headers): DynamicEQ, SpectralSculptor
//  macOS additionally: VST3, CLAP (via PluginWrapper — in development)
//

import Foundation
import AudioToolbox
import AVFoundation
import CoreAudioKit

// MARK: - Audio Unit Type

/// Supported Audio Unit types
public enum EchoelmusicAUType: String, CaseIterable {
    case instrument = "aumu"    // Music Device (Generator)
    case effect = "aufx"        // Effect
    case midiProcessor = "aumi" // MIDI Processor

    var componentType: OSType {
        switch self {
        case .instrument: return kAudioUnitType_MusicDevice
        case .effect: return kAudioUnitType_Effect
        case .midiProcessor: return kAudioUnitType_MIDIProcessor
        }
    }
}

/// All 10 Echoel* plugin identities — each backed by a dedicated DSP kernel
public enum EchoelPluginID: String, CaseIterable {
    // Instruments (aumu)
    case echoelSynth = "Esyn"   // TR808 bass synthesizer (TR808DSPKernel)
    case echoelBio   = "Ebio"   // Binaural beat generator (BinauralDSPKernel)

    // Effects (aufx)
    case echoelFX    = "Eefx"   // Freeverb reverb (ReverbDSPKernel)
    case echoelMix   = "Emix"   // Analog compressor (CompressorDSPKernel)
    case echoelField = "Efld"   // Multi-mode filter (FilterDSPKernel)
    case echoelMind  = "Emnd"   // 8 analog console emulations (EchoelCoreDSPKernel)

    // MIDI Processors (aumi)
    case echoelSeq   = "Eseq"   // Step sequencer + drum synthesis
    case echoelMIDI  = "Emid"   // MIDI processor + synthesis
    case echoelBeam  = "Ebem"   // Audio-to-lighting DMX bridge
    case echoelNet   = "Enet"   // Network protocol bridge (OSC/MSC)

    var auType: EchoelmusicAUType {
        switch self {
        case .echoelSynth, .echoelBio:
            return .instrument
        case .echoelFX, .echoelMix, .echoelField, .echoelMind:
            return .effect
        case .echoelSeq, .echoelMIDI, .echoelBeam, .echoelNet:
            return .midiProcessor
        }
    }

    var componentSubType: OSType {
        return fourCharCode(rawValue)
    }

    var displayName: String {
        switch self {
        case .echoelSynth: return "EchoelSynth"
        case .echoelFX:    return "EchoelFX"
        case .echoelMix:   return "EchoelMix"
        case .echoelSeq:   return "EchoelSeq"
        case .echoelMIDI:  return "EchoelMIDI"
        case .echoelBio:   return "EchoelBio"
        case .echoelField: return "EchoelField"
        case .echoelBeam:  return "EchoelBeam"
        case .echoelNet:   return "EchoelNet"
        case .echoelMind:  return "EchoelMind"
        }
    }

    /// Identify plugin from AudioComponentDescription subtype
    static func from(componentDescription: AudioComponentDescription) -> EchoelPluginID? {
        let subtypeBytes = withUnsafeBytes(of: componentDescription.componentSubType.bigEndian) {
            String(bytes: $0, encoding: .ascii)
        }
        guard let subtype = subtypeBytes else { return nil }
        return EchoelPluginID(rawValue: subtype)
    }
}

/// Convert 4-character string to OSType
private func fourCharCode(_ string: String) -> OSType {
    var result: OSType = 0
    for char in string.utf8.prefix(4) {
        result = (result << 8) | OSType(char)
    }
    return result
}

// MARK: - Audio Unit Description

/// Echoelmusic manufacturer code: "Echo"
let kEchoelmusicManufacturer: OSType = fourCharCode("Echo")

/// Create AudioComponentDescription for a specific Echoelmusic plugin
public func echoelmusicAudioComponentDescription(plugin: EchoelPluginID) -> AudioComponentDescription {
    AudioComponentDescription(
        componentType: plugin.auType.componentType,
        componentSubType: plugin.componentSubType,
        componentManufacturer: kEchoelmusicManufacturer,
        componentFlags: 0,
        componentFlagsMask: 0
    )
}

/// Create AudioComponentDescription for an Echoelmusic AU type (generic, no subtype)
public func echoelmusicAudioComponentDescription(type: EchoelmusicAUType) -> AudioComponentDescription {
    AudioComponentDescription(
        componentType: type.componentType,
        componentSubType: 0,
        componentManufacturer: kEchoelmusicManufacturer,
        componentFlags: 0,
        componentFlagsMask: 0
    )
}

// MARK: - Parameter Addresses

/// Parameter addresses for automation
public enum EchoelmusicParameterAddress: AUParameterAddress {
    // Global
    case bypass = 0
    case gain = 1
    case mix = 2

    // 808 Bass Synth
    case pitchGlideTime = 100
    case pitchGlideRange = 101
    case pitchGlideCurve = 102
    case clickAmount = 103
    case decay = 104
    case drive = 105
    case filterCutoff = 106

    // Reserved (200-204) — formerly stem separation, addresses kept for state compatibility

    // Bio-Reactive
    case bioReactivity = 300
    case coherenceTarget = 301
    case creativityLevel = 302

    // Reverb (ReverbDSPKernel)
    case reverbWetDry = 400
    case reverbRoomSize = 401
    case reverbDamping = 402
    case reverbWidth = 403
    case reverbPreDelay = 404

    // Compressor (CompressorDSPKernel)
    case compThreshold = 500
    case compRatio = 501
    case compAttack = 502
    case compRelease = 503
    case compMakeupGain = 504
    case compKnee = 505

    // Filter (FilterDSPKernel)
    case filterFrequency = 600
    case filterResonance = 601
    case filterMode = 602

    // Console / EchoelCore (EchoelCoreDSPKernel)
    case consoleLegend = 700
    case consoleVibe = 701
    case consoleBlend = 702

    // Binaural (BinauralDSPKernel)
    case binauralCarrier = 800
    case binauralBeat = 801
    case binauralAmplitude = 802

    // Tuning (Global)
    case concertPitch = 900

    // EchoelSynth extended
    case synthOscillatorType = 910   // 0=Sine, 1=Triangle, 2=Saw, 3=Square, 4=808
    case synthSubOscLevel = 911     // Sub-oscillator (-1 octave) level
    case synthNoiseLevel = 912      // Noise component level

}

// MARK: - Base Audio Unit

/// Base class for all Echoelmusic Audio Units
open class EchoelmusicAudioUnit: AUAudioUnit {

    // MARK: - Properties

    /// Audio Unit type (instrument, effect, midi)
    public let auType: EchoelmusicAUType

    /// Specific Echoel* plugin identity
    public let pluginID: EchoelPluginID?

    /// Parameter tree for host automation
    private var _parameterTree: AUParameterTree?

    /// Audio processing format
    private var _outputBusArray: AUAudioUnitBusArray?
    private var _inputBusArray: AUAudioUnitBusArray?

    /// Internal render block
    private var _internalRenderBlock: AUInternalRenderBlock?

    /// DSP Kernel (for subclass override)
    open var kernel: EchoelmusicDSPKernel?

    /// Current preset
    private var _currentPreset: AUAudioUnitPreset?

    /// Factory presets
    private var _factoryPresets: [AUAudioUnitPreset] = []

    // MARK: - Audio Format

    /// Default audio format (48kHz, stereo, float32)
    public static let defaultFormat: AVAudioFormat? = {
        AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)
            ?? AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: 2, interleaved: false)
    }()

    // MARK: - Initialization

    public init(componentDescription: AudioComponentDescription, auType: EchoelmusicAUType) throws {
        self.auType = auType
        self.pluginID = EchoelPluginID.from(componentDescription: componentDescription)

        try super.init(componentDescription: componentDescription, options: [])

        // Instantiate the correct DSP kernel based on plugin identity
        self.kernel = Self.createKernel(for: self.pluginID, auType: auType)

        // Setup parameter tree
        setupParameterTree()

        // Setup buses
        setupBuses()

        // Setup factory presets
        setupFactoryPresets()

        // Maximum frames to render
        self.maximumFramesToRender = 4096
    }

    public override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
        // Determine AU type from component description
        switch componentDescription.componentType {
        case kAudioUnitType_MusicDevice:
            self.auType = .instrument
        case kAudioUnitType_Effect:
            self.auType = .effect
        case kAudioUnitType_MIDIProcessor:
            self.auType = .midiProcessor
        default:
            self.auType = .effect
        }

        self.pluginID = EchoelPluginID.from(componentDescription: componentDescription)

        try super.init(componentDescription: componentDescription, options: options)

        // Instantiate the correct DSP kernel based on plugin identity
        self.kernel = Self.createKernel(for: self.pluginID, auType: self.auType)

        setupParameterTree()
        setupBuses()
        setupFactoryPresets()
        self.maximumFramesToRender = 4096
    }

    // MARK: - Kernel Factory

    /// Creates the appropriate DSP kernel for each plugin identity.
    /// Each plugin gets a dedicated kernel with its own DSP algorithm.
    private static func createKernel(for pluginID: EchoelPluginID?, auType: EchoelmusicAUType) -> EchoelmusicDSPKernel {
        guard let pluginID = pluginID else {
            switch auType {
            case .instrument: return TR808DSPKernel()
            case .effect: return ReverbDSPKernel()
            case .midiProcessor: return TR808DSPKernel()
            }
        }

        switch pluginID {
        // Instruments
        case .echoelSynth:
            return TR808DSPKernel()           // Bass synthesizer
        case .echoelBio:
            return BinauralDSPKernel()        // Binaural beat generator

        // Effects — each gets its own dedicated DSP
        case .echoelFX:
            return ReverbDSPKernel()          // Freeverb algorithmic reverb
        case .echoelMix:
            return CompressorDSPKernel()      // Analog-style compressor
        case .echoelField:
            return FilterDSPKernel()          // Multi-mode biquad filter
        case .echoelMind:
            return EchoelCoreDSPKernel()      // 8 analog console emulations

        // MIDI Processors
        case .echoelSeq:
            return TR808DSPKernel()           // Sequencer with drum synthesis
        case .echoelMIDI:
            return TR808DSPKernel()           // MIDI pass-through + synthesis
        case .echoelBeam:
            return TR808DSPKernel()           // DMX bridge (audio-triggered)
        case .echoelNet:
            return TR808DSPKernel()           // Network bridge (audio-triggered)
        }
    }

    // MARK: - Parameter Tree

    private func setupParameterTree() {
        // Create parameter groups based on AU type
        var parameters: [AUParameter] = []

        // Global parameters
        let bypassParam = AUParameterTree.createParameter(
            withIdentifier: "bypass",
            name: "Bypass",
            address: EchoelmusicParameterAddress.bypass.rawValue,
            min: 0, max: 1,
            unit: .boolean,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )

        let gainParam = AUParameterTree.createParameter(
            withIdentifier: "gain",
            name: "Output Gain",
            address: EchoelmusicParameterAddress.gain.rawValue,
            min: 0, max: 2,
            unit: .linearGain,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable, .flag_DisplayLogarithmic],
            valueStrings: nil,
            dependentParameters: nil
        )

        let mixParam = AUParameterTree.createParameter(
            withIdentifier: "mix",
            name: "Dry/Wet Mix",
            address: EchoelmusicParameterAddress.mix.rawValue,
            min: 0, max: 1,
            unit: .generic,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )

        parameters.append(contentsOf: [bypassParam, gainParam, mixParam])

        // Plugin-specific parameters — each plugin registers only its own parameters
        if let id = pluginID {
            switch id {
            case .echoelSynth:
                parameters.append(contentsOf: create808Parameters())
                parameters.append(contentsOf: createSynthExtendedParameters())
            case .echoelBio:
                parameters.append(contentsOf: createBinauralParameters())
                parameters.append(contentsOf: createBioReactiveParameters())
            case .echoelFX:
                parameters.append(contentsOf: createReverbParameters())
                parameters.append(contentsOf: createReverbExtendedParameters())
            case .echoelMix:
                parameters.append(contentsOf: createCompressorParameters())
            case .echoelField:
                parameters.append(contentsOf: createFilterParameters())
            case .echoelMind:
                parameters.append(contentsOf: createConsoleParameters())
            case .echoelSeq, .echoelMIDI, .echoelBeam, .echoelNet:
                parameters.append(contentsOf: create808Parameters())
            }
        } else {
            // Fallback when pluginID is nil — register by AU type
            switch auType {
            case .instrument:
                parameters.append(contentsOf: create808Parameters())
            case .effect:
                parameters.append(contentsOf: createReverbParameters())
            case .midiProcessor:
                break
            }
        }

        // Create tree
        _parameterTree = AUParameterTree.createTree(withChildren: parameters)

        // Set default values
        bypassParam.value = 0
        gainParam.value = 1
        mixParam.value = 1

        // Setup parameter observer
        _parameterTree?.implementorValueObserver = { [weak self] param, value in
            self?.kernel?.setParameter(address: param.address, value: value)
        }

        _parameterTree?.implementorValueProvider = { [weak self] param in
            return self?.kernel?.getParameter(address: param.address) ?? param.value
        }
    }

    private func create808Parameters() -> [AUParameter] {
        return [
            AUParameterTree.createParameter(
                withIdentifier: "pitchGlideTime",
                name: "Pitch Glide Time",
                address: EchoelmusicParameterAddress.pitchGlideTime.rawValue,
                min: 0.01, max: 0.5,
                unit: .seconds,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: nil,
                dependentParameters: nil
            ),
            AUParameterTree.createParameter(
                withIdentifier: "pitchGlideRange",
                name: "Pitch Glide Range",
                address: EchoelmusicParameterAddress.pitchGlideRange.rawValue,
                min: -24, max: 0,
                unit: .relativeSemiTones,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: nil,
                dependentParameters: nil
            ),
            AUParameterTree.createParameter(
                withIdentifier: "clickAmount",
                name: "Click Amount",
                address: EchoelmusicParameterAddress.clickAmount.rawValue,
                min: 0, max: 1,
                unit: .generic,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: nil,
                dependentParameters: nil
            ),
            AUParameterTree.createParameter(
                withIdentifier: "decay",
                name: "Decay",
                address: EchoelmusicParameterAddress.decay.rawValue,
                min: 0.1, max: 10,
                unit: .seconds,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: nil,
                dependentParameters: nil
            ),
            AUParameterTree.createParameter(
                withIdentifier: "drive",
                name: "Drive",
                address: EchoelmusicParameterAddress.drive.rawValue,
                min: 0, max: 1,
                unit: .generic,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: nil,
                dependentParameters: nil
            ),
            AUParameterTree.createParameter(
                withIdentifier: "filterCutoff",
                name: "Filter Cutoff",
                address: EchoelmusicParameterAddress.filterCutoff.rawValue,
                min: 20, max: 2000,
                unit: .hertz,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable, .flag_DisplayLogarithmic],
                valueStrings: nil,
                dependentParameters: nil
            )
        ]
    }

    private func createReverbParameters() -> [AUParameter] {
        return [
            AUParameterTree.createParameter(
                withIdentifier: "reverbWetDry",
                name: "Wet/Dry",
                address: EchoelmusicParameterAddress.reverbWetDry.rawValue,
                min: 0, max: 100,
                unit: .percent,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: nil,
                dependentParameters: nil
            ),
            AUParameterTree.createParameter(
                withIdentifier: "reverbRoomSize",
                name: "Room Size",
                address: EchoelmusicParameterAddress.reverbRoomSize.rawValue,
                min: 0, max: 100,
                unit: .percent,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: nil,
                dependentParameters: nil
            ),
            AUParameterTree.createParameter(
                withIdentifier: "reverbDamping",
                name: "Damping",
                address: EchoelmusicParameterAddress.reverbDamping.rawValue,
                min: 0, max: 100,
                unit: .percent,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: nil,
                dependentParameters: nil
            )
        ]
    }

    private func createCompressorParameters() -> [AUParameter] {
        return [
            AUParameterTree.createParameter(
                withIdentifier: "compThreshold",
                name: "Threshold",
                address: EchoelmusicParameterAddress.compThreshold.rawValue,
                min: -60, max: 0,
                unit: .decibels,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: nil,
                dependentParameters: nil
            ),
            AUParameterTree.createParameter(
                withIdentifier: "compRatio",
                name: "Ratio",
                address: EchoelmusicParameterAddress.compRatio.rawValue,
                min: 1, max: 20,
                unit: .generic,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: nil,
                dependentParameters: nil
            ),
            AUParameterTree.createParameter(
                withIdentifier: "compAttack",
                name: "Attack",
                address: EchoelmusicParameterAddress.compAttack.rawValue,
                min: 0.1, max: 200,
                unit: .milliseconds,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: nil,
                dependentParameters: nil
            ),
            AUParameterTree.createParameter(
                withIdentifier: "compRelease",
                name: "Release",
                address: EchoelmusicParameterAddress.compRelease.rawValue,
                min: 10, max: 2000,
                unit: .milliseconds,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: nil,
                dependentParameters: nil
            ),
            AUParameterTree.createParameter(
                withIdentifier: "compMakeupGain",
                name: "Makeup Gain",
                address: EchoelmusicParameterAddress.compMakeupGain.rawValue,
                min: 0, max: 24,
                unit: .decibels,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: nil,
                dependentParameters: nil
            ),
            AUParameterTree.createParameter(
                withIdentifier: "compKnee",
                name: "Knee",
                address: EchoelmusicParameterAddress.compKnee.rawValue,
                min: 0, max: 20,
                unit: .decibels,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: nil,
                dependentParameters: nil
            )
        ]
    }

    private func createFilterParameters() -> [AUParameter] {
        return [
            AUParameterTree.createParameter(
                withIdentifier: "filterFrequency",
                name: "Frequency",
                address: EchoelmusicParameterAddress.filterFrequency.rawValue,
                min: 20, max: 20000,
                unit: .hertz,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable, .flag_DisplayLogarithmic],
                valueStrings: nil,
                dependentParameters: nil
            ),
            AUParameterTree.createParameter(
                withIdentifier: "filterResonance",
                name: "Resonance",
                address: EchoelmusicParameterAddress.filterResonance.rawValue,
                min: 0.1, max: 20,
                unit: .generic,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: nil,
                dependentParameters: nil
            ),
            AUParameterTree.createParameter(
                withIdentifier: "filterMode",
                name: "Mode",
                address: EchoelmusicParameterAddress.filterMode.rawValue,
                min: 0, max: 3,
                unit: .indexed,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: ["Low Pass", "High Pass", "Band Pass", "Notch"],
                dependentParameters: nil
            )
        ]
    }

    private func createConsoleParameters() -> [AUParameter] {
        return [
            AUParameterTree.createParameter(
                withIdentifier: "consoleLegend",
                name: "Console Model",
                address: EchoelmusicParameterAddress.consoleLegend.rawValue,
                min: 0, max: 7,
                unit: .indexed,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: ["SSL VCA", "API Thrust", "Neve Transformer", "Pultec Boost",
                               "Fairchild Mu", "LA-2A Optical", "1176 FET", "Manley Tube"],
                dependentParameters: nil
            ),
            AUParameterTree.createParameter(
                withIdentifier: "consoleVibe",
                name: "Vibe (Drive)",
                address: EchoelmusicParameterAddress.consoleVibe.rawValue,
                min: 0, max: 100,
                unit: .percent,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: nil,
                dependentParameters: nil
            ),
            AUParameterTree.createParameter(
                withIdentifier: "consoleBlend",
                name: "Blend",
                address: EchoelmusicParameterAddress.consoleBlend.rawValue,
                min: 0, max: 100,
                unit: .percent,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: nil,
                dependentParameters: nil
            )
        ]
    }

    private func createSynthExtendedParameters() -> [AUParameter] {
        return [
            AUParameterTree.createParameter(
                withIdentifier: "concertPitch",
                name: "Concert Pitch (A4)",
                address: EchoelmusicParameterAddress.concertPitch.rawValue,
                min: 392, max: 494,
                unit: .hertz,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: nil,
                dependentParameters: nil
            ),
            AUParameterTree.createParameter(
                withIdentifier: "oscillatorType",
                name: "Oscillator",
                address: EchoelmusicParameterAddress.synthOscillatorType.rawValue,
                min: 0, max: 4,
                unit: .indexed,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: ["Sine", "Triangle", "Saw", "Square", "808 Pulse"],
                dependentParameters: nil
            ),
            AUParameterTree.createParameter(
                withIdentifier: "subOscLevel",
                name: "Sub Oscillator",
                address: EchoelmusicParameterAddress.synthSubOscLevel.rawValue,
                min: 0, max: 1,
                unit: .generic,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: nil,
                dependentParameters: nil
            ),
            AUParameterTree.createParameter(
                withIdentifier: "noiseLevel",
                name: "Noise",
                address: EchoelmusicParameterAddress.synthNoiseLevel.rawValue,
                min: 0, max: 1,
                unit: .generic,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: nil,
                dependentParameters: nil
            )
        ]
    }

    private func createReverbExtendedParameters() -> [AUParameter] {
        return [
            AUParameterTree.createParameter(
                withIdentifier: "reverbWidth",
                name: "Width",
                address: EchoelmusicParameterAddress.reverbWidth.rawValue,
                min: 0, max: 100,
                unit: .percent,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: nil,
                dependentParameters: nil
            ),
            AUParameterTree.createParameter(
                withIdentifier: "reverbPreDelay",
                name: "Pre-Delay",
                address: EchoelmusicParameterAddress.reverbPreDelay.rawValue,
                min: 0, max: 200,
                unit: .milliseconds,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: nil,
                dependentParameters: nil
            )
        ]
    }

    private func createBinauralParameters() -> [AUParameter] {
        return [
            AUParameterTree.createParameter(
                withIdentifier: "binauralCarrier",
                name: "Carrier Frequency",
                address: EchoelmusicParameterAddress.binauralCarrier.rawValue,
                min: 100, max: 1000,
                unit: .hertz,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable, .flag_DisplayLogarithmic],
                valueStrings: nil,
                dependentParameters: nil
            ),
            AUParameterTree.createParameter(
                withIdentifier: "binauralBeat",
                name: "Beat Frequency",
                address: EchoelmusicParameterAddress.binauralBeat.rawValue,
                min: 0.5, max: 50,
                unit: .hertz,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: nil,
                dependentParameters: nil
            ),
            AUParameterTree.createParameter(
                withIdentifier: "binauralAmplitude",
                name: "Amplitude",
                address: EchoelmusicParameterAddress.binauralAmplitude.rawValue,
                min: 0, max: 1,
                unit: .linearGain,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: nil,
                dependentParameters: nil
            )
        ]
    }

    private func createBioReactiveParameters() -> [AUParameter] {
        return [
            AUParameterTree.createParameter(
                withIdentifier: "bioReactivity",
                name: "Bio Reactivity",
                address: EchoelmusicParameterAddress.bioReactivity.rawValue,
                min: 0, max: 1,
                unit: .generic,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: nil,
                dependentParameters: nil
            ),
            AUParameterTree.createParameter(
                withIdentifier: "coherenceTarget",
                name: "Coherence Target",
                address: EchoelmusicParameterAddress.coherenceTarget.rawValue,
                min: 0, max: 1,
                unit: .generic,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: nil,
                dependentParameters: nil
            ),
            AUParameterTree.createParameter(
                withIdentifier: "creativityLevel",
                name: "Creativity Level",
                address: EchoelmusicParameterAddress.creativityLevel.rawValue,
                min: 0, max: 1,
                unit: .generic,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: nil,
                dependentParameters: nil
            )
        ]
    }

    // MARK: - Bus Setup

    private func setupBuses() {
        guard let format = Self.defaultFormat else { return }

        // Output bus (all types have output)
        let outputBus = try? AUAudioUnitBus(format: format)
        if let bus = outputBus {
            _outputBusArray = AUAudioUnitBusArray(
                audioUnit: self,
                busType: .output,
                busses: [bus]
            )
        }

        // Input bus (effects have input)
        if auType == .effect {
            let inputBus = try? AUAudioUnitBus(format: format)
            if let bus = inputBus {
                _inputBusArray = AUAudioUnitBusArray(
                    audioUnit: self,
                    busType: .input,
                    busses: [bus]
                )
            }
        } else {
            _inputBusArray = AUAudioUnitBusArray(
                audioUnit: self,
                busType: .input,
                busses: []
            )
        }
    }

    // MARK: - Factory Presets

    private func setupFactoryPresets() {
        guard let id = pluginID else {
            _factoryPresets = [Self.makePreset(number: 0, name: "Default")]
            return
        }

        switch id {
        case .echoelSynth:
            _factoryPresets = [
                Self.makePreset(number: 0, name: "Classic 808"),
                Self.makePreset(number: 1, name: "Hard Trap"),
                Self.makePreset(number: 2, name: "Deep Sub"),
                Self.makePreset(number: 3, name: "Distorted"),
                Self.makePreset(number: 4, name: "Long Slide"),
                Self.makePreset(number: 5, name: "Saw Bass"),
                Self.makePreset(number: 6, name: "Square Lead"),
                Self.makePreset(number: 7, name: "Sub Sine"),
                Self.makePreset(number: 8, name: "Noise Perc")
            ]
        case .echoelFX:
            _factoryPresets = [
                Self.makePreset(number: 0, name: "Small Room"),
                Self.makePreset(number: 1, name: "Medium Hall"),
                Self.makePreset(number: 2, name: "Large Hall"),
                Self.makePreset(number: 3, name: "Cathedral"),
                Self.makePreset(number: 4, name: "Plate")
            ]
        case .echoelMix:
            _factoryPresets = [
                Self.makePreset(number: 0, name: "Gentle Glue"),
                Self.makePreset(number: 1, name: "Vocal Leveler"),
                Self.makePreset(number: 2, name: "Bus Compressor"),
                Self.makePreset(number: 3, name: "Drum Smash"),
                Self.makePreset(number: 4, name: "Limiter")
            ]
        case .echoelSeq:
            _factoryPresets = [
                Self.makePreset(number: 0, name: "4/4 Basic"),
                Self.makePreset(number: 1, name: "Bio-Pulse"),
                Self.makePreset(number: 2, name: "Euclidean"),
                Self.makePreset(number: 3, name: "Generative Lambda")
            ]
        case .echoelMIDI:
            _factoryPresets = [
                Self.makePreset(number: 0, name: "Default"),
                Self.makePreset(number: 1, name: "MPE Mode"),
                Self.makePreset(number: 2, name: "Arp + Chord"),
                Self.makePreset(number: 3, name: "Scale Quantize")
            ]
        case .echoelBio:
            _factoryPresets = [
                Self.makePreset(number: 0, name: "Heart Composer"),
                Self.makePreset(number: 1, name: "Breath Ambient"),
                Self.makePreset(number: 2, name: "Coherence Tonal"),
                Self.makePreset(number: 3, name: "Movement Rhythmic")
            ]
        case .echoelField:
            _factoryPresets = [
                Self.makePreset(number: 0, name: "Warm Low Pass"),
                Self.makePreset(number: 1, name: "Bright High Pass"),
                Self.makePreset(number: 2, name: "Vocal Band Pass"),
                Self.makePreset(number: 3, name: "Notch Hum Remove")
            ]
        case .echoelBeam:
            _factoryPresets = [
                Self.makePreset(number: 0, name: "DMX Default"),
                Self.makePreset(number: 1, name: "Beat-Synced"),
                Self.makePreset(number: 2, name: "Bio-Reactive Warm"),
                Self.makePreset(number: 3, name: "Strobe Chase")
            ]
        case .echoelNet:
            _factoryPresets = [
                Self.makePreset(number: 0, name: "OSC Bridge"),
                Self.makePreset(number: 1, name: "MSC Theater"),
                Self.makePreset(number: 2, name: "Mackie Control"),
                Self.makePreset(number: 3, name: "SharePlay Collab")
            ]
        case .echoelMind:
            _factoryPresets = [
                Self.makePreset(number: 0, name: "SSL VCA Bus"),
                Self.makePreset(number: 1, name: "API Thrust"),
                Self.makePreset(number: 2, name: "Neve Silk"),
                Self.makePreset(number: 3, name: "Pultec Warmth"),
                Self.makePreset(number: 4, name: "Fairchild Glue"),
                Self.makePreset(number: 5, name: "LA-2A Vocal"),
                Self.makePreset(number: 6, name: "1176 Drums"),
                Self.makePreset(number: 7, name: "Manley Tube")
            ]
        }
    }

    /// Helper to create AUAudioUnitPreset (API requires setting properties after init)
    private static func makePreset(number: Int, name: String) -> AUAudioUnitPreset {
        let preset = AUAudioUnitPreset()
        preset.number = number
        preset.name = name
        return preset
    }

    // MARK: - AUAudioUnit Overrides

    open override var parameterTree: AUParameterTree? {
        get { return _parameterTree }
        set { _parameterTree = newValue }
    }

    open override var outputBusses: AUAudioUnitBusArray {
        return _outputBusArray ?? AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [])
    }

    open override var inputBusses: AUAudioUnitBusArray {
        return _inputBusArray ?? AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [])
    }

    open override var factoryPresets: [AUAudioUnitPreset]? {
        return _factoryPresets
    }

    open override var currentPreset: AUAudioUnitPreset? {
        get { return _currentPreset }
        set {
            _currentPreset = newValue
            if let preset = newValue {
                loadPreset(number: preset.number)
            }
        }
    }

    open override var latency: TimeInterval {
        return kernel?.latency ?? 0
    }

    open override var tailTime: TimeInterval {
        return kernel?.tailTime ?? 0
    }

    open override var channelCapabilities: [NSNumber]? {
        // Stereo in, stereo out
        return [2, 2]
    }

    open override func allocateRenderResources() throws {
        try super.allocateRenderResources()

        let outputFormat = outputBusses[0].format
        kernel?.initialize(
            sampleRate: outputFormat.sampleRate,
            channelCount: Int(outputFormat.channelCount)
        )
    }

    open override func deallocateRenderResources() {
        kernel?.deallocate()
        super.deallocateRenderResources()
    }

    open override var internalRenderBlock: AUInternalRenderBlock {
        // Capture kernel and auType once — safe for real-time render thread (no weak self dereference)
        let kernel = self.kernel
        let isEffect = self.auType == .effect

        return { actionFlags, timestamp, frameCount, outputBusNumber, outputData, realtimeEventListHead, pullInputBlock in

            guard let kernel = kernel else {
                return noErr
            }

            // Pull input for effects
            if isEffect, let pullInput = pullInputBlock {
                var inputFlags = AudioUnitRenderActionFlags()
                let status = pullInput(&inputFlags, timestamp, frameCount, 0, outputData)
                if status != noErr {
                    return status
                }
            }

            // Process MIDI events safely
            var currentEvent = realtimeEventListHead?.pointee
            while let event = currentEvent {
                switch event.head.eventType {
                case .MIDI:
                    let midiEvent = event.MIDI
                    kernel.handleMIDI(
                        status: midiEvent.data.0,
                        data1: midiEvent.data.1,
                        data2: midiEvent.data.2,
                        sampleOffset: AUEventSampleTime(event.head.eventSampleTime)
                    )
                case .midiSysEx:
                    break
                case .parameter:
                    let paramEvent = event.parameter
                    kernel.setParameter(
                        address: paramEvent.parameterAddress,
                        value: paramEvent.value
                    )
                default:
                    break
                }
                currentEvent = event.head.next?.pointee
            }

            // Render audio
            kernel.render(
                frameCount: Int(frameCount),
                outputData: outputData
            )

            return noErr
        }
    }

    // MARK: - State Management

    open override var fullState: [String: Any]? {
        get {
            var state: [String: Any] = [:]

            // Save all parameters
            if let tree = _parameterTree {
                for param in tree.allParameters {
                    state[param.identifier] = param.value
                }
            }

            // Save custom state
            if let kernelState = kernel?.fullState {
                state["kernelState"] = kernelState
            }

            return state
        }
        set {
            guard let state = newValue else { return }

            // Restore parameters
            if let tree = _parameterTree {
                for param in tree.allParameters {
                    if let value = state[param.identifier] as? AUValue {
                        param.value = value
                    }
                }
            }

            // Restore kernel state
            if let kernelState = state["kernelState"] as? [String: Any] {
                kernel?.fullState = kernelState
            }
        }
    }

    // MARK: - Preset Loading

    open func loadPreset(number: Int) {
        // Override in subclass for preset-specific parameter values
        kernel?.loadPreset(number: number)
    }

    // MARK: - MIDI

    open override var midiOutputNames: [String] {
        return ["MIDI Out"]
    }

    open override var supportsMPE: Bool {
        return true
    }
}

// MARK: - DSP Kernel Protocol

/// Protocol for DSP processing kernels
public protocol EchoelmusicDSPKernel: AnyObject {

    /// Initialize with sample rate and channel count
    func initialize(sampleRate: Double, channelCount: Int)

    /// Deallocate resources
    func deallocate()

    /// Set parameter value
    func setParameter(address: AUParameterAddress, value: AUValue)

    /// Get parameter value
    func getParameter(address: AUParameterAddress) -> AUValue

    /// Handle MIDI event
    func handleMIDI(status: UInt8, data1: UInt8, data2: UInt8, sampleOffset: AUEventSampleTime)

    /// Render audio
    func render(frameCount: Int, outputData: UnsafeMutablePointer<AudioBufferList>)

    /// Load preset
    func loadPreset(number: Int)

    /// Latency in seconds
    var latency: TimeInterval { get }

    /// Tail time in seconds
    var tailTime: TimeInterval { get }

    /// Full state for save/restore
    var fullState: [String: Any]? { get set }
}

// MARK: - Audio Unit Factory

/// Factory for creating Echoelmusic audio units
@objc(EchoelmusicAudioUnitFactory)
public class EchoelmusicAudioUnitFactory: NSObject, AUAudioUnitFactory, NSExtensionRequestHandling {

    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        // Determine type from component description
        let auType: EchoelmusicAUType
        switch componentDescription.componentType {
        case kAudioUnitType_MusicDevice:
            auType = .instrument
        case kAudioUnitType_Effect:
            auType = .effect
        case kAudioUnitType_MIDIProcessor:
            auType = .midiProcessor
        default:
            auType = .effect
        }

        return try EchoelmusicAudioUnit(componentDescription: componentDescription, auType: auType)
    }

    /// Required by NSExtensionRequestHandling for App Extension support
    public func beginRequest(with context: NSExtensionContext) {
        // Audio Unit extensions don't use this method for normal operation
        // The system uses createAudioUnit(with:) instead
    }
}
