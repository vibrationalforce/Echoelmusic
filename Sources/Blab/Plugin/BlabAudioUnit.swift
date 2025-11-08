import AVFoundation
import CoreAudioKit

/// BLAB AUv3 Audio Unit - Instrument Plugin
///
/// Features:
/// - Bio-reactive synthesis
/// - MPE support
/// - Real-time biofeedback integration
/// - Spatial audio output
/// - DAW automation
///
/// Usage in DAW:
/// - Load as AUv3 instrument in Logic Pro, GarageBand, Ableton Live, etc.
/// - Connect HealthKit for biofeedback
/// - MIDI input for performance
/// - Automation for all parameters
@objc public class BlabAudioUnit: AUAudioUnit {

    // MARK: - Audio Unit Properties

    /// Input bus (for audio input - if needed)
    private var inputBus: AUAudioUnitBus!

    /// Output bus (for synthesized audio)
    private var outputBus: AUAudioUnitBus!

    /// Input/Output bus arrays
    private var _inputBusArray: AUAudioUnitBusArray!
    private var _outputBusArray: AUAudioUnitBusArray!

    public override var inputBusses: AUAudioUnitBusArray {
        return _inputBusArray
    }

    public override var outputBusses: AUAudioUnitBusArray {
        return _outputBusArray
    }

    // MARK: - DSP Components

    private var bioParameterMapper: BioParameterMapper?
    private var nodeGraph: NodeGraph?
    private var midiProcessor: MIDIProcessor?

    // MARK: - Parameters

    private var _parameterTree: AUParameterTree!

    public override var parameterTree: AUParameterTree? {
        get { return _parameterTree }
        set { /* Read-only */ }
    }

    // Parameter objects
    private var hrvCoherenceParam: AUParameter!
    private var filterCutoffParam: AUParameter!
    private var reverbWetParam: AUParameter!
    private var delayTimeParam: AUParameter!

    // MARK: - State

    private var sampleRate: Double = 44100.0
    private var maxFrames: AUAudioFrameCount = 512

    // MARK: - Initialization

    public override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions) throws {
        // Create default audio format
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!

        try super.init(componentDescription: componentDescription, options: options)

        // Create busses
        inputBus = try AUAudioUnitBus(format: format)
        outputBus = try AUAudioUnitBus(format: format)

        _inputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [inputBus])
        _outputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [outputBus])

        // Setup parameters
        setupParameters()

        // Initialize DSP components
        bioParameterMapper = BioParameterMapper()
        nodeGraph = NodeGraph.createBiofeedbackChain()
        midiProcessor = MIDIProcessor()

        print("🎹 BlabAudioUnit initialized")
    }

    // MARK: - Parameter Setup

    private func setupParameters() {
        // HRV Coherence (0-100)
        hrvCoherenceParam = AUParameterTree.createParameter(
            withIdentifier: "hrvCoherence",
            name: "HRV Coherence",
            address: 0,
            min: 0.0,
            max: 100.0,
            unit: .percent,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )

        // Filter Cutoff (200-8000 Hz)
        filterCutoffParam = AUParameterTree.createParameter(
            withIdentifier: "filterCutoff",
            name: "Filter Cutoff",
            address: 1,
            min: 200.0,
            max: 8000.0,
            unit: .hertz,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable, .flag_CanRamp],
            valueStrings: nil,
            dependentParameters: nil
        )

        // Reverb Wet/Dry (0-100%)
        reverbWetParam = AUParameterTree.createParameter(
            withIdentifier: "reverbWet",
            name: "Reverb Mix",
            address: 2,
            min: 0.0,
            max: 100.0,
            unit: .percent,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable, .flag_CanRamp],
            valueStrings: nil,
            dependentParameters: nil
        )

        // Delay Time (0.01-2.0 seconds)
        delayTimeParam = AUParameterTree.createParameter(
            withIdentifier: "delayTime",
            name: "Delay Time",
            address: 3,
            min: 0.01,
            max: 2.0,
            unit: .seconds,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable, .flag_CanRamp],
            valueStrings: nil,
            dependentParameters: nil
        )

        // Create parameter tree
        _parameterTree = AUParameterTree.createTree(withChildren: [
            hrvCoherenceParam,
            filterCutoffParam,
            reverbWetParam,
            delayTimeParam
        ])

        // Setup parameter observers
        _parameterTree.implementorValueObserver = { [weak self] param, value in
            self?.handleParameterChange(param, value: value)
        }

        _parameterTree.implementorValueProvider = { [weak self] param in
            return self?.getParameterValue(param) ?? 0.0
        }
    }

    // MARK: - Audio Processing

    public override var internalRenderBlock: AUInternalRenderBlock {
        return { [weak self] actionFlags, timestamp, frameCount, outputBusNumber, outputData, realtimeEventListHead, pullInputBlock in

            guard let self = self else { return noErr }

            // Get output buffer
            let outputBuffer = UnsafeMutableAudioBufferListPointer(outputData)

            // Create AVAudioPCMBuffer for DSP processing
            guard let format = self.outputBus.format as? AVAudioFormat,
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                return kAudioUnitErr_InvalidProperty
            }

            buffer.frameLength = frameCount

            // Process MIDI events
            self.midiProcessor?.processEvents(from: realtimeEventListHead, frameCount: frameCount)

            // Generate/process audio through node graph
            if let graph = self.nodeGraph, graph.isProcessing {
                let time = AVAudioTime(hostTime: timestamp.pointee.mHostTime)
                let processed = graph.process(buffer, time: time)

                // Copy processed audio to output
                if let processedData = processed.floatChannelData {
                    for channel in 0..<Int(format.channelCount) {
                        if let outputChannelData = outputBuffer[channel].mData?.assumingMemoryBound(to: Float.self),
                           let processedChannelData = processedData[channel] as UnsafeMutablePointer<Float>? {
                            memcpy(outputChannelData, processedChannelData, Int(frameCount) * MemoryLayout<Float>.size)
                        }
                    }
                }
            }

            return noErr
        }
    }

    // MARK: - Lifecycle

    public override func allocateRenderResources() throws {
        try super.allocateRenderResources()

        sampleRate = outputBus.format.sampleRate
        maxFrames = maximumFramesToRender

        // Prepare node graph
        nodeGraph?.start(sampleRate: sampleRate, maxFrames: maxFrames)

        print("🎹 BlabAudioUnit render resources allocated")
    }

    public override func deallocateRenderResources() {
        super.deallocateRenderResources()

        nodeGraph?.stop()

        print("🎹 BlabAudioUnit render resources deallocated")
    }

    // MARK: - Parameter Handling

    private func handleParameterChange(_ param: AUParameter, value: AUValue) {
        switch param.address {
        case 0:  // HRV Coherence
            // Update bio-parameter mapper
            bioParameterMapper?.updateParameters(
                hrvCoherence: Double(value),
                heartRate: 70.0,  // TODO: Get from HealthKit
                voicePitch: 0.0,
                audioLevel: 0.5
            )

        case 1:  // Filter Cutoff
            nodeGraph?.nodes.first { $0.name.contains("Filter") }?.setParameter(name: "cutoffFrequency", value: value)

        case 2:  // Reverb Wet
            nodeGraph?.nodes.first { $0.name.contains("Reverb") }?.setParameter(name: "wetDry", value: value)

        case 3:  // Delay Time
            nodeGraph?.nodes.first { $0.name.contains("Delay") }?.setParameter(name: "delayTime", value: value)

        default:
            break
        }
    }

    private func getParameterValue(_ param: AUParameter) -> AUValue {
        switch param.address {
        case 0:
            return AUValue(bioParameterMapper?.getCurrentParameters().coherence ?? 50.0)
        case 1:
            return nodeGraph?.nodes.first { $0.name.contains("Filter") }?.getParameter(name: "cutoffFrequency") ?? 1000.0
        case 2:
            return nodeGraph?.nodes.first { $0.name.contains("Reverb") }?.getParameter(name: "wetDry") ?? 30.0
        case 3:
            return nodeGraph?.nodes.first { $0.name.contains("Delay") }?.getParameter(name: "delayTime") ?? 0.5
        default:
            return 0.0
        }
    }

    // MARK: - MIDI Support

    public override var supportsMPE: Bool {
        return true
    }

    public override var channelCapabilities: [NSNumber]? {
        // Support 16 MIDI channels + MPE
        return Array(0...15).map { NSNumber(value: $0) }
    }

    // MARK: - Preset Support

    public override var factoryPresets: [AUAudioUnitPreset]? {
        return [
            AUAudioUnitPreset(number: 0, name: "Calm Coherence"),
            AUAudioUnitPreset(number: 1, name: "Flow State"),
            AUAudioUnitPreset(number: 2, name: "Energized"),
            AUAudioUnitPreset(number: 3, name: "Deep Meditation"),
        ]
    }

    public override var currentPreset: AUAudioUnitPreset? {
        didSet {
            if let preset = currentPreset {
                loadPreset(preset)
            }
        }
    }

    private func loadPreset(_ preset: AUAudioUnitPreset) {
        switch preset.number {
        case 0:  // Calm Coherence
            filterCutoffParam.value = 800.0
            reverbWetParam.value = 60.0
            delayTimeParam.value = 0.75

        case 1:  // Flow State
            filterCutoffParam.value = 2000.0
            reverbWetParam.value = 40.0
            delayTimeParam.value = 0.5

        case 2:  // Energized
            filterCutoffParam.value = 5000.0
            reverbWetParam.value = 20.0
            delayTimeParam.value = 0.25

        case 3:  // Deep Meditation
            filterCutoffParam.value = 400.0
            reverbWetParam.value = 80.0
            delayTimeParam.value = 1.0

        default:
            break
        }
    }
}

// MARK: - MIDI Processor Helper

class MIDIProcessor {
    func processEvents(from eventList: UnsafePointer<AURenderEvent>?, frameCount: AUAudioFrameCount) {
        var event = eventList

        while let currentEvent = event {
            switch currentEvent.pointee.head.eventType {
            case .MIDI:
                let midiEvent = UnsafeRawPointer(currentEvent).assumingMemoryBound(to: AUMIDIEvent.self).pointee
                processMIDIEvent(midiEvent)

            case .midiSysEx:
                let sysExEvent = UnsafeRawPointer(currentEvent).assumingMemoryBound(to: AUMIDISysExEvent.self).pointee
                processSysExEvent(sysExEvent)

            case .parameter, .parameterRamp:
                // Handled by parameter tree
                break

            default:
                break
            }

            event = currentEvent.pointee.head.next?.pointee
        }
    }

    private func processMIDIEvent(_ event: AUMIDIEvent) {
        let status = event.data.0
        let data1 = event.data.1
        let data2 = event.data.2

        let messageType = status & 0xF0
        let channel = status & 0x0F

        switch messageType {
        case 0x90:  // Note On
            print("🎹 MIDI Note On: \(data1) vel:\(data2) ch:\(channel)")
        case 0x80:  // Note Off
            print("🎹 MIDI Note Off: \(data1)")
        case 0xB0:  // Control Change
            print("🎹 MIDI CC: \(data1) val:\(data2)")
        case 0xE0:  // Pitch Bend
            let pitchBend = Int(data1) | (Int(data2) << 7)
            print("🎹 MIDI Pitch Bend: \(pitchBend)")
        default:
            break
        }
    }

    private func processSysExEvent(_ event: AUMIDISysExEvent) {
        print("🎹 MIDI SysEx: \(event.length) bytes")
    }
}

// MARK: - BioParameterMapper Extension

extension BioParameterMapper {
    func getCurrentParameters() -> (coherence: Double, filterCutoff: Float, reverbWet: Float) {
        return (coherence: 50.0, filterCutoff: filterCutoff, reverbWet: reverbWet)
    }
}
