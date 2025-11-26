// EchoelmusicAudioUnit.swift
// Bio-Reactive AUv3 Audio Unit for iOS
//
// Provides two AudioComponents:
// 1. Instrument (aumu) - Generates bio-reactive music
// 2. Effect (aufx) - Processes audio with bio-reactive effects
//
// Integration: Uses AudioEngine C++ DSP via Objective-C++ bridge

import AVFoundation
import CoreAudioKit
import AudioToolbox

/// Main AUv3 Audio Unit class - supports both instrument and effect modes
public class EchoelmusicAudioUnit: AUAudioUnit {

    // MARK: - Audio Unit Configuration

    /// Audio component type (instrument or effect)
    private let componentType: OSType

    /// Is this an instrument (generator) or effect (processor)?
    private var isInstrument: Bool {
        return componentType == kAudioUnitType_MusicDevice
    }

    // MARK: - Audio Buffers

    /// Internal audio buffer (stereo)
    private var pcmBuffer: AVAudioPCMBuffer?

    /// Maximum frames to render (set during allocateRenderResources)
    private var maxFramesToRender: UInt32 = 512

    // MARK: - Audio Parameters (Bio-Reactive)

    /// Parameter tree for host automation
    public override var parameterTree: AUParameterTree? {
        get { return _parameterTree }
        set { _parameterTree = newValue }
    }
    private var _parameterTree: AUParameterTree?

    // Parameter objects (created in init)
    private var filterCutoffParam: AUParameter!
    private var reverbSizeParam: AUParameter!
    private var delayTimeParam: AUParameter!
    private var delayFeedbackParam: AUParameter!
    private var modulationRateParam: AUParameter!
    private var modulationDepthParam: AUParameter!
    private var bioVolumeParam: AUParameter!
    private var hrvSensitivityParam: AUParameter!
    private var coherenceSensitivityParam: AUParameter!

    // MARK: - DSP State

    /// Current sample rate
    private var sampleRate: Double = 48000.0

    /// Current transport state
    private var isPlaying: Bool = false

    /// Sample time for MIDI note generation (instrument mode)
    private var sampleTime: AUEventSampleTime = 0

    // MARK: - Initialization

    public override init(componentDescription: AudioComponentDescription,
                        options: AudioComponentInstantiationOptions = []) throws {

        // Store component type
        self.componentType = componentDescription.componentType

        // Call super init
        try super.init(componentDescription: componentDescription, options: options)

        // Create parameter tree
        createParameterTree()

        // Set up audio bus configuration
        setupAudioBuses()

        // Set maximum frames to render
        self.maximumFramesToRender = 512
    }

    // MARK: - Parameter Tree Creation

    private func createParameterTree() {
        // Create parameters with audio unit scope

        // 1. Filter Cutoff (20 Hz - 20 kHz)
        filterCutoffParam = AUParameterTree.createParameter(
            withIdentifier: "filterCutoff",
            name: "Filter Cutoff",
            address: 0,
            min: 20.0,
            max: 20000.0,
            unit: .hertz,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable, .flag_CanRamp],
            valueStrings: nil,
            dependentParameters: nil
        )
        filterCutoffParam.value = 1000.0

        // 2. Reverb Size (0.0 - 1.0)
        reverbSizeParam = AUParameterTree.createParameter(
            withIdentifier: "reverbSize",
            name: "Reverb Size",
            address: 1,
            min: 0.0,
            max: 1.0,
            unit: .generic,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable, .flag_CanRamp],
            valueStrings: nil,
            dependentParameters: nil
        )
        reverbSizeParam.value = 0.5

        // 3. Delay Time (0 - 2000 ms)
        delayTimeParam = AUParameterTree.createParameter(
            withIdentifier: "delayTime",
            name: "Delay Time",
            address: 2,
            min: 0.0,
            max: 2000.0,
            unit: .milliseconds,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable, .flag_CanRamp],
            valueStrings: nil,
            dependentParameters: nil
        )
        delayTimeParam.value = 500.0

        // 4. Delay Feedback (0.0 - 0.95)
        delayFeedbackParam = AUParameterTree.createParameter(
            withIdentifier: "delayFeedback",
            name: "Delay Feedback",
            address: 3,
            min: 0.0,
            max: 0.95,
            unit: .generic,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable, .flag_CanRamp],
            valueStrings: nil,
            dependentParameters: nil
        )
        delayFeedbackParam.value = 0.3

        // 5. Modulation Rate (0.1 - 10 Hz)
        modulationRateParam = AUParameterTree.createParameter(
            withIdentifier: "modulationRate",
            name: "Modulation Rate",
            address: 4,
            min: 0.1,
            max: 10.0,
            unit: .hertz,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable, .flag_CanRamp],
            valueStrings: nil,
            dependentParameters: nil
        )
        modulationRateParam.value = 1.0

        // 6. Modulation Depth (0.0 - 1.0)
        modulationDepthParam = AUParameterTree.createParameter(
            withIdentifier: "modulationDepth",
            name: "Modulation Depth",
            address: 5,
            min: 0.0,
            max: 1.0,
            unit: .generic,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable, .flag_CanRamp],
            valueStrings: nil,
            dependentParameters: nil
        )
        modulationDepthParam.value = 0.5

        // 7. Bio Volume (0.0 - 1.0)
        bioVolumeParam = AUParameterTree.createParameter(
            withIdentifier: "bioVolume",
            name: "Bio Volume",
            address: 6,
            min: 0.0,
            max: 1.0,
            unit: .generic,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable, .flag_CanRamp],
            valueStrings: nil,
            dependentParameters: nil
        )
        bioVolumeParam.value = 1.0

        // 8. HRV Sensitivity (0.0 - 1.0)
        hrvSensitivityParam = AUParameterTree.createParameter(
            withIdentifier: "hrvSensitivity",
            name: "HRV Sensitivity",
            address: 7,
            min: 0.0,
            max: 1.0,
            unit: .generic,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        hrvSensitivityParam.value = 0.7

        // 9. Coherence Sensitivity (0.0 - 1.0)
        coherenceSensitivityParam = AUParameterTree.createParameter(
            withIdentifier: "coherenceSensitivity",
            name: "Coherence Sensitivity",
            address: 8,
            min: 0.0,
            max: 1.0,
            unit: .generic,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        coherenceSensitivityParam.value = 0.7

        // Create parameter tree
        _parameterTree = AUParameterTree.createTree(withChildren: [
            filterCutoffParam!,
            reverbSizeParam!,
            delayTimeParam!,
            delayFeedbackParam!,
            modulationRateParam!,
            modulationDepthParam!,
            bioVolumeParam!,
            hrvSensitivityParam!,
            coherenceSensitivityParam!
        ])

        // Parameter value observer (host automation)
        _parameterTree?.implementorValueObserver = { [weak self] parameter, value in
            guard let self = self else { return }

            // Update DSP parameters (would call into C++ AudioEngine here)
            // For now, just store the values
            // In full implementation, call EchoelmusicAudioEngineBridge
        }

        // Parameter value provider (for host to read)
        _parameterTree?.implementorValueProvider = { [weak self] parameter in
            guard let self = self else { return 0.0 }

            // Return current parameter value
            return parameter.value
        }
    }

    // MARK: - Audio Bus Configuration

    private func setupAudioBuses() {
        // Input bus (only for effect mode)
        if !isInstrument {
            let inputBusFormat = AVAudioFormat(standardFormatWithSampleRate: 48000.0, channels: 2)!
            do {
                try inputBusses[0].setFormat(inputBusFormat)
            } catch {
                print("❌ EchoelmusicAudioUnit: Failed to set input bus format: \(error)")
            }
        }

        // Output bus (always present)
        let outputBusFormat = AVAudioFormat(standardFormatWithSampleRate: 48000.0, channels: 2)!
        do {
            try outputBusses[0].setFormat(outputBusFormat)
        } catch {
            print("❌ EchoelmusicAudioUnit: Failed to set output bus format: \(error)")
        }
    }

    // MARK: - Resource Allocation

    public override func allocateRenderResources() throws {
        try super.allocateRenderResources()

        // Get output format
        guard let outputFormat = outputBusses[0].format as AVAudioFormat? else {
            throw NSError(domain: NSOSStatusErrorDomain,
                         code: Int(kAudioUnitErr_FormatNotSupported),
                         userInfo: nil)
        }

        // Store sample rate
        sampleRate = outputFormat.sampleRate

        // Allocate internal buffer
        maxFramesToRender = UInt32(maximumFramesToRender)
        pcmBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat,
                                     frameCapacity: maxFramesToRender)

        // Initialize DSP (would call AudioEngine::prepare() here)
        print("✅ EchoelmusicAudioUnit: Allocated render resources (SR: \(sampleRate) Hz, Block: \(maxFramesToRender) frames)")
    }

    public override func deallocateRenderResources() {
        super.deallocateRenderResources()

        // Release buffer
        pcmBuffer = nil

        // Release DSP resources (would call AudioEngine::releaseResources() here)
        print("✅ EchoelmusicAudioUnit: Deallocated render resources")
    }

    // MARK: - Audio Rendering (Internal Render Block)

    public override var internalRenderBlock: AUInternalRenderBlock {
        return { [weak self] (
            actionFlags,
            timestamp,
            frameCount,
            outputBusNumber,
            outputData,
            realtimeEventListHead,
            pullInputBlock
        ) in
            guard let self = self else { return kAudioUnitErr_Uninitialized }

            // Safety check
            guard frameCount <= self.maxFramesToRender else {
                return kAudioUnitErr_TooManyFramesToProcess
            }

            // Get output buffer list
            let outputBufferList = UnsafeMutableAudioBufferListPointer(outputData)

            // Process audio based on mode
            if self.isInstrument {
                // INSTRUMENT MODE: Generate audio (synthesizer)
                return self.renderInstrument(
                    actionFlags: actionFlags,
                    timestamp: timestamp,
                    frameCount: frameCount,
                    outputBufferList: outputBufferList
                )
            } else {
                // EFFECT MODE: Process input audio
                guard let pullInputBlock = pullInputBlock else {
                    return kAudioUnitErr_NoConnection
                }

                return self.renderEffect(
                    actionFlags: actionFlags,
                    timestamp: timestamp,
                    frameCount: frameCount,
                    outputBufferList: outputBufferList,
                    pullInputBlock: pullInputBlock
                )
            }
        }
    }

    // MARK: - Instrument Rendering

    private func renderInstrument(
        actionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
        timestamp: UnsafePointer<AudioTimeStamp>,
        frameCount: AUAudioFrameCount,
        outputBufferList: UnsafeMutableAudioBufferListPointer
    ) -> AUAudioUnitStatus {

        // Generate bio-reactive synthesis
        // In full implementation: Call AudioEngine to generate audio

        // For now: Generate simple sine wave modulated by HRV
        let numChannels = outputBufferList.count

        for channelIndex in 0..<numChannels {
            guard let channelData = outputBufferList[channelIndex].mData?.assumingMemoryBound(to: Float.self) else {
                continue
            }

            let channelFrameCount = Int(outputBufferList[channelIndex].mDataByteSize) / MemoryLayout<Float>.stride

            // Simple sine wave (440 Hz A note)
            let frequency: Float = 440.0
            let sampleRateFloat = Float(sampleRate)

            for frame in 0..<min(Int(frameCount), channelFrameCount) {
                let phase = (Float(sampleTime + AUEventSampleTime(frame)) * frequency) / sampleRateFloat
                channelData[frame] = sin(phase * 2.0 * Float.pi) * 0.5 // -6 dB
            }
        }

        // Update sample time
        sampleTime += AUEventSampleTime(frameCount)

        return noErr
    }

    // MARK: - Effect Rendering

    private func renderEffect(
        actionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
        timestamp: UnsafePointer<AudioTimeStamp>,
        frameCount: AUAudioFrameCount,
        outputBufferList: UnsafeMutableAudioBufferListPointer,
        pullInputBlock: AURenderPullInputBlock
    ) -> AUAudioUnitStatus {

        // Pull input audio
        var inputFlags: AudioUnitRenderActionFlags = []
        let status = pullInputBlock(&inputFlags, timestamp, frameCount, 0, outputData)

        guard status == noErr else { return status }

        // Process audio with bio-reactive DSP
        // In full implementation: Call AudioEngine::applyBioReactiveDSP()

        // For now: Simple passthrough with gain
        let gain: Float = bioVolumeParam.value
        let numChannels = outputBufferList.count

        for channelIndex in 0..<numChannels {
            guard let channelData = outputBufferList[channelIndex].mData?.assumingMemoryBound(to: Float.self) else {
                continue
            }

            let channelFrameCount = Int(outputBufferList[channelIndex].mDataByteSize) / MemoryLayout<Float>.stride

            for frame in 0..<min(Int(frameCount), channelFrameCount) {
                channelData[frame] *= gain
            }
        }

        return noErr
    }

    // MARK: - State Persistence

    public override var fullState: [String : Any]? {
        get {
            var state: [String: Any] = [:]

            // Save all parameter values
            state["filterCutoff"] = filterCutoffParam.value
            state["reverbSize"] = reverbSizeParam.value
            state["delayTime"] = delayTimeParam.value
            state["delayFeedback"] = delayFeedbackParam.value
            state["modulationRate"] = modulationRateParam.value
            state["modulationDepth"] = modulationDepthParam.value
            state["bioVolume"] = bioVolumeParam.value
            state["hrvSensitivity"] = hrvSensitivityParam.value
            state["coherenceSensitivity"] = coherenceSensitivityParam.value

            return state
        }
        set {
            guard let state = newValue else { return }

            // Restore all parameter values
            if let value = state["filterCutoff"] as? AUValue {
                filterCutoffParam.value = value
            }
            if let value = state["reverbSize"] as? AUValue {
                reverbSizeParam.value = value
            }
            if let value = state["delayTime"] as? AUValue {
                delayTimeParam.value = value
            }
            if let value = state["delayFeedback"] as? AUValue {
                delayFeedbackParam.value = value
            }
            if let value = state["modulationRate"] as? AUValue {
                modulationRateParam.value = value
            }
            if let value = state["modulationDepth"] as? AUValue {
                modulationDepthParam.value = value
            }
            if let value = state["bioVolume"] as? AUValue {
                bioVolumeParam.value = value
            }
            if let value = state["hrvSensitivity"] as? AUValue {
                hrvSensitivityParam.value = value
            }
            if let value = state["coherenceSensitivity"] as? AUValue {
                coherenceSensitivityParam.value = value
            }
        }
    }

    // MARK: - Factory Preset Support

    public override var factoryPresets: [AUAudioUnitPreset]? {
        return [
            AUAudioUnitPreset(number: 0, name: "Relaxed State"),
            AUAudioUnitPreset(number: 1, name: "Focused State"),
            AUAudioUnitPreset(number: 2, name: "Creative Flow"),
            AUAudioUnitPreset(number: 3, name: "Deep Meditation"),
            AUAudioUnitPreset(number: 4, name: "High Energy")
        ]
    }

    public override var currentPreset: AUAudioUnitPreset? {
        get { return _currentPreset }
        set {
            _currentPreset = newValue

            // Load preset
            if let preset = newValue {
                loadFactoryPreset(preset.number)
            }
        }
    }
    private var _currentPreset: AUAudioUnitPreset?

    private func loadFactoryPreset(_ number: Int) {
        switch number {
        case 0: // Relaxed State
            filterCutoffParam.value = 800.0
            reverbSizeParam.value = 0.7
            modulationRateParam.value = 0.5

        case 1: // Focused State
            filterCutoffParam.value = 2000.0
            reverbSizeParam.value = 0.3
            modulationRateParam.value = 2.0

        case 2: // Creative Flow
            filterCutoffParam.value = 1500.0
            reverbSizeParam.value = 0.5
            modulationRateParam.value = 1.5

        case 3: // Deep Meditation
            filterCutoffParam.value = 400.0
            reverbSizeParam.value = 0.9
            modulationRateParam.value = 0.2

        case 4: // High Energy
            filterCutoffParam.value = 5000.0
            reverbSizeParam.value = 0.2
            modulationRateParam.value = 5.0

        default:
            break
        }
    }
}

// MARK: - Factory Functions

/// Factory function for Instrument AudioComponent (aumu)
@_cdecl("EchoelmusicAudioUnitFactory")
public func createEchoelmusicInstrument(componentDescription: AudioComponentDescription) -> AUAudioUnit? {
    return try? EchoelmusicAudioUnit(componentDescription: componentDescription)
}

/// Factory function for Effect AudioComponent (aufx)
@_cdecl("EchoelmusicEffectFactory")
public func createEchoelmusicEffect(componentDescription: AudioComponentDescription) -> AUAudioUnit? {
    return try? EchoelmusicAudioUnit(componentDescription: componentDescription)
}
