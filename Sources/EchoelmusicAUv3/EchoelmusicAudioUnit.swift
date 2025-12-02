//
//  EchoelmusicAudioUnit.swift
//  EchoelmusicAUv3
//
//  Created: December 2025
//  AUDIO UNIT v3 BASE CLASS
//  Universal AUv3 wrapper for Echoelmusic audio processing
//
//  Supports:
//  - Instrument (aumu) - TR-808, BioReactive Composer
//  - Effect (aufx) - Stem Separation, Effects Chain
//  - MIDI Processor (aumi) - MIDI 2.0 Processing
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

    var componentSubType: OSType {
        switch self {
        case .instrument: return fourCharCode("E808")
        case .effect: return fourCharCode("Estm")
        case .midiProcessor: return fourCharCode("Emid")
        }
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

/// Create AudioComponentDescription for Echoelmusic AU
public func echoelmusicAudioComponentDescription(type: EchoelmusicAUType) -> AudioComponentDescription {
    AudioComponentDescription(
        componentType: type.componentType,
        componentSubType: type.componentSubType,
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

    // Stem Separation
    case vocalLevel = 200
    case drumLevel = 201
    case bassLevel = 202
    case otherLevel = 203
    case separationQuality = 204

    // Bio-Reactive
    case bioReactivity = 300
    case coherenceTarget = 301
    case creativityLevel = 302
}

// MARK: - Base Audio Unit

/// Base class for all Echoelmusic Audio Units
open class EchoelmusicAudioUnit: AUAudioUnit {

    // MARK: - Properties

    /// Audio Unit type (instrument, effect, midi)
    public let auType: EchoelmusicAUType

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
    public static let defaultFormat = AVAudioFormat(
        standardFormatWithSampleRate: 48000,
        channels: 2
    )!

    // MARK: - Initialization

    public init(componentDescription: AudioComponentDescription, auType: EchoelmusicAUType) throws {
        self.auType = auType

        try super.init(componentDescription: componentDescription, options: [])

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

        try super.init(componentDescription: componentDescription, options: options)

        setupParameterTree()
        setupBuses()
        setupFactoryPresets()
        self.maximumFramesToRender = 4096
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

        // Type-specific parameters
        switch auType {
        case .instrument:
            parameters.append(contentsOf: create808Parameters())
            parameters.append(contentsOf: createBioReactiveParameters())

        case .effect:
            parameters.append(contentsOf: createStemSeparationParameters())

        case .midiProcessor:
            break
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

    private func createStemSeparationParameters() -> [AUParameter] {
        return [
            AUParameterTree.createParameter(
                withIdentifier: "vocalLevel",
                name: "Vocals Level",
                address: EchoelmusicParameterAddress.vocalLevel.rawValue,
                min: 0, max: 2,
                unit: .linearGain,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: nil,
                dependentParameters: nil
            ),
            AUParameterTree.createParameter(
                withIdentifier: "drumLevel",
                name: "Drums Level",
                address: EchoelmusicParameterAddress.drumLevel.rawValue,
                min: 0, max: 2,
                unit: .linearGain,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: nil,
                dependentParameters: nil
            ),
            AUParameterTree.createParameter(
                withIdentifier: "bassLevel",
                name: "Bass Level",
                address: EchoelmusicParameterAddress.bassLevel.rawValue,
                min: 0, max: 2,
                unit: .linearGain,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: nil,
                dependentParameters: nil
            ),
            AUParameterTree.createParameter(
                withIdentifier: "otherLevel",
                name: "Other Level",
                address: EchoelmusicParameterAddress.otherLevel.rawValue,
                min: 0, max: 2,
                unit: .linearGain,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: nil,
                dependentParameters: nil
            ),
            AUParameterTree.createParameter(
                withIdentifier: "separationQuality",
                name: "Separation Quality",
                address: EchoelmusicParameterAddress.separationQuality.rawValue,
                min: 0, max: 1,
                unit: .generic,
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: ["Fast", "Balanced", "High Quality"],
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
        switch auType {
        case .instrument:
            _factoryPresets = [
                AUAudioUnitPreset(number: 0, name: "Classic 808"),
                AUAudioUnitPreset(number: 1, name: "Hard Trap"),
                AUAudioUnitPreset(number: 2, name: "Deep Sub"),
                AUAudioUnitPreset(number: 3, name: "Distorted"),
                AUAudioUnitPreset(number: 4, name: "Long Slide"),
                AUAudioUnitPreset(number: 5, name: "Bio Flow"),
                AUAudioUnitPreset(number: 6, name: "Quantum Pulse")
            ]
        case .effect:
            _factoryPresets = [
                AUAudioUnitPreset(number: 0, name: "Vocal Isolation"),
                AUAudioUnitPreset(number: 1, name: "Drums Only"),
                AUAudioUnitPreset(number: 2, name: "Bass Boost"),
                AUAudioUnitPreset(number: 3, name: "Karaoke Mode"),
                AUAudioUnitPreset(number: 4, name: "Instrumental")
            ]
        case .midiProcessor:
            _factoryPresets = [
                AUAudioUnitPreset(number: 0, name: "Default"),
                AUAudioUnitPreset(number: 1, name: "MPE Mode")
            ]
        }
    }

    // MARK: - AUAudioUnit Overrides

    open override var parameterTree: AUParameterTree? {
        return _parameterTree
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

        guard let outputFormat = outputBusses[0].format else {
            throw NSError(domain: "EchoelmusicAU", code: -1)
        }

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
        return { [weak self] actionFlags, timestamp, frameCount, outputBusNumber, outputData, realtimeEventListHead, pullInputBlock in

            guard let self = self, let kernel = self.kernel else {
                return noErr
            }

            // Pull input for effects
            if self.auType == .effect, let pullInput = pullInputBlock {
                var inputFlags = AudioUnitRenderActionFlags()
                let status = pullInput(&inputFlags, timestamp, frameCount, 0, outputData)
                if status != noErr {
                    return status
                }
            }

            // Process MIDI events
            var event = realtimeEventListHead?.pointee
            while event != nil {
                switch event!.head.eventType {
                case .MIDI:
                    let midiEvent = event!.MIDI
                    kernel.handleMIDI(
                        status: midiEvent.data.0,
                        data1: midiEvent.data.1,
                        data2: midiEvent.data.2,
                        sampleOffset: AUEventSampleTime(event!.head.eventSampleTime)
                    )
                case .midiSysEx:
                    break
                case .parameter:
                    let paramEvent = event!.parameter
                    kernel.setParameter(
                        address: paramEvent.parameterAddress,
                        value: paramEvent.value
                    )
                default:
                    break
                }
                event = event!.head.next?.pointee
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

// MARK: - Audio Unit View Controller

/// Base view controller for Audio Unit UI
open class EchoelmusicAudioUnitViewController: AUViewController {

    public var audioUnit: EchoelmusicAudioUnit? {
        didSet {
            DispatchQueue.main.async { [weak self] in
                self?.connectViewToAU()
            }
        }
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        if audioUnit != nil {
            connectViewToAU()
        }
    }

    /// Override to connect UI to audio unit parameters
    open func connectViewToAU() {
        // Subclasses implement
    }
}

// MARK: - Audio Unit Factory

/// Factory for creating Echoelmusic audio units
@objc(EchoelmusicAudioUnitFactory)
public class EchoelmusicAudioUnitFactory: NSObject, AUAudioUnitFactory {

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
}
