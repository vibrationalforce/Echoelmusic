#if canImport(AVFoundation)
import Foundation
import AVFoundation
import os

/// AUv3 Audio Unit — Bio-Reactive Audio Processor
///
/// Exposes Echoelmusic's DSP chain (reverb + delay + filter) as a
/// standard Audio Unit v3 effect plugin. Compatible with GarageBand,
/// Logic Pro, AUM, and any AUv3 host.
///
/// Component: aufx/echl/Echo (effect processor)
public final class EchoelmusicAudioUnit: AUAudioUnit {

    private static let auLog = OSLog(
        subsystem: "com.echoelmusic.app.auv3",
        category: "AudioUnit"
    )

    // MARK: - DSP

    private let kernel = DSPKernel()

    // MARK: - Buses

    private var _inputBusArray: AUAudioUnitBusArray!
    private var _outputBusArray: AUAudioUnitBusArray!
    private var inputBus: AUAudioUnitBus!
    private var outputBus: AUAudioUnitBus!

    // MARK: - Parameter Tree

    private var _parameterTree: AUParameterTree!

    // Parameter nodes (retained for observation)
    private var wetDryParam: AUParameter!
    private var roomSizeParam: AUParameter!
    private var dampingParam: AUParameter!
    private var delayTimeParam: AUParameter!
    private var feedbackParam: AUParameter!
    private var filterCutoffParam: AUParameter!
    private var filterResonanceParam: AUParameter!
    private var inputGainParam: AUParameter!
    private var outputGainParam: AUParameter!

    // MARK: - Initialization

    public override init(
        componentDescription: AudioComponentDescription,
        options: AudioComponentInstantiationOptions = []
    ) throws {
        try super.init(componentDescription: componentDescription, options: options)

        guard let defaultFormat = AVAudioFormat(
            standardFormatWithSampleRate: 48000,
            channels: 2
        ) else {
            throw NSError(domain: "com.echoelmusic.app.auv3", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create default audio format"])
        }

        inputBus = try AUAudioUnitBus(format: defaultFormat)
        outputBus = try AUAudioUnitBus(format: defaultFormat)

        _inputBusArray = AUAudioUnitBusArray(
            audioUnit: self, busType: .input, busses: [inputBus]
        )
        _outputBusArray = AUAudioUnitBusArray(
            audioUnit: self, busType: .output, busses: [outputBus]
        )

        setupParameterTree()

        os_log(.info, log: Self.auLog, "AUv3 initialized")
    }

    // MARK: - Parameter Tree Setup

    private func setupParameterTree() {
        // Reverb group
        wetDryParam = AUParameterTree.createParameter(
            withIdentifier: "wetDry",
            name: "Wet/Dry Mix",
            address: DSPKernel.ParameterAddress.wetDry.rawValue,
            min: 0.0, max: 1.0,
            unit: .generic,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        wetDryParam.value = 0.3

        roomSizeParam = AUParameterTree.createParameter(
            withIdentifier: "roomSize",
            name: "Room Size",
            address: DSPKernel.ParameterAddress.roomSize.rawValue,
            min: 0.0, max: 1.0,
            unit: .generic,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        roomSizeParam.value = 0.5

        dampingParam = AUParameterTree.createParameter(
            withIdentifier: "damping",
            name: "Damping",
            address: DSPKernel.ParameterAddress.damping.rawValue,
            min: 0.0, max: 1.0,
            unit: .generic,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        dampingParam.value = 0.5

        let reverbGroup = AUParameterTree.createGroup(
            withIdentifier: "reverb",
            name: "Reverb",
            children: [wetDryParam, roomSizeParam, dampingParam]
        )

        // Delay group
        delayTimeParam = AUParameterTree.createParameter(
            withIdentifier: "delayTime",
            name: "Delay Time",
            address: DSPKernel.ParameterAddress.delayTime.rawValue,
            min: 0.01, max: 2.0,
            unit: .seconds,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        delayTimeParam.value = 0.25

        feedbackParam = AUParameterTree.createParameter(
            withIdentifier: "feedback",
            name: "Feedback",
            address: DSPKernel.ParameterAddress.feedback.rawValue,
            min: 0.0, max: 0.9,
            unit: .generic,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        feedbackParam.value = 0.4

        let delayGroup = AUParameterTree.createGroup(
            withIdentifier: "delay",
            name: "Delay",
            children: [delayTimeParam, feedbackParam]
        )

        // Filter group
        filterCutoffParam = AUParameterTree.createParameter(
            withIdentifier: "filterCutoff",
            name: "Filter Cutoff",
            address: DSPKernel.ParameterAddress.filterCutoff.rawValue,
            min: 20.0, max: 20000.0,
            unit: .hertz,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        filterCutoffParam.value = 8000.0

        filterResonanceParam = AUParameterTree.createParameter(
            withIdentifier: "filterResonance",
            name: "Resonance",
            address: DSPKernel.ParameterAddress.filterResonance.rawValue,
            min: 0.1, max: 20.0,
            unit: .generic,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        filterResonanceParam.value = 0.707

        let filterGroup = AUParameterTree.createGroup(
            withIdentifier: "filter",
            name: "Filter",
            children: [filterCutoffParam, filterResonanceParam]
        )

        // Gain group
        inputGainParam = AUParameterTree.createParameter(
            withIdentifier: "inputGain",
            name: "Input Gain",
            address: DSPKernel.ParameterAddress.inputGain.rawValue,
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
            address: DSPKernel.ParameterAddress.outputGain.rawValue,
            min: 0.0, max: 2.0,
            unit: .linearGain,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        outputGainParam.value = 1.0

        let gainGroup = AUParameterTree.createGroup(
            withIdentifier: "gain",
            name: "Gain",
            children: [inputGainParam, outputGainParam]
        )

        // Build tree
        _parameterTree = AUParameterTree.createTree(
            withChildren: [reverbGroup, delayGroup, filterGroup, gainGroup]
        )

        // Parameter value provider (read from kernel)
        _parameterTree.implementorValueProvider = { [weak self] param in
            guard let self,
                  let address = DSPKernel.ParameterAddress(rawValue: param.address) else {
                return param.value
            }
            return self.kernel.getParameter(address: address)
        }

        // Parameter value observer (write to kernel)
        _parameterTree.implementorValueObserver = { [weak self] param, value in
            guard let self,
                  let address = DSPKernel.ParameterAddress(rawValue: param.address) else {
                return
            }
            self.kernel.setParameter(address: address, value: value)
        }

        // String value provider
        _parameterTree.implementorStringFromValueCallback = { param, valuePtr in
            let value = valuePtr?.pointee ?? param.value
            switch param.address {
            case DSPKernel.ParameterAddress.filterCutoff.rawValue:
                if value >= 1000 {
                    return String(format: "%.1f kHz", value / 1000)
                }
                return String(format: "%.0f Hz", value)
            case DSPKernel.ParameterAddress.delayTime.rawValue:
                return String(format: "%.0f ms", value * 1000)
            default:
                return String(format: "%.2f", value)
            }
        }
    }

    // MARK: - AUAudioUnit Overrides

    public override var parameterTree: AUParameterTree? {
        return _parameterTree
    }

    public override var inputBusses: AUAudioUnitBusArray {
        return _inputBusArray
    }

    public override var outputBusses: AUAudioUnitBusArray {
        return _outputBusArray
    }

    public override var canProcessInPlace: Bool { true }

    public override var supportsUserPresets: Bool { true }

    public override var latency: TimeInterval { 0 }

    public override var tailTime: TimeInterval {
        // Reverb + delay tail
        return Double(delayTimeParam.value) + 2.0
    }

    // MARK: - Factory Presets

    public override var factoryPresets: [AUAudioUnitPreset]? {
        return [
            AUAudioUnitPreset(number: 0, name: "Clean"),
            AUAudioUnitPreset(number: 1, name: "Small Room"),
            AUAudioUnitPreset(number: 2, name: "Large Hall"),
            AUAudioUnitPreset(number: 3, name: "Echo Chamber"),
            AUAudioUnitPreset(number: 4, name: "Bio-Reactive")
        ]
    }

    public override var currentPreset: AUAudioUnitPreset? {
        didSet {
            guard let preset = currentPreset else { return }
            if preset.number >= 0 {
                applyFactoryPreset(preset.number)
            }
        }
    }

    private func applyFactoryPreset(_ number: Int) {
        switch number {
        case 0: // Clean
            wetDryParam.value = 0.0
            delayTimeParam.value = 0.01
            feedbackParam.value = 0.0
            filterCutoffParam.value = 20000
            inputGainParam.value = 1.0
            outputGainParam.value = 1.0

        case 1: // Small Room
            wetDryParam.value = 0.2
            roomSizeParam.value = 0.3
            dampingParam.value = 0.6
            delayTimeParam.value = 0.01
            feedbackParam.value = 0.0
            filterCutoffParam.value = 12000

        case 2: // Large Hall
            wetDryParam.value = 0.5
            roomSizeParam.value = 0.85
            dampingParam.value = 0.3
            delayTimeParam.value = 0.01
            feedbackParam.value = 0.0
            filterCutoffParam.value = 6000

        case 3: // Echo Chamber
            wetDryParam.value = 0.3
            roomSizeParam.value = 0.5
            dampingParam.value = 0.4
            delayTimeParam.value = 0.375
            feedbackParam.value = 0.6
            filterCutoffParam.value = 5000

        case 4: // Bio-Reactive
            wetDryParam.value = 0.3
            roomSizeParam.value = 0.5
            dampingParam.value = 0.5
            delayTimeParam.value = 0.25
            feedbackParam.value = 0.4
            filterCutoffParam.value = 8000

        default:
            break
        }
    }

    // MARK: - State Save/Restore

    public override var fullState: [String: Any]? {
        get {
            var state = super.fullState ?? [:]
            state["wetDry"] = wetDryParam.value
            state["roomSize"] = roomSizeParam.value
            state["damping"] = dampingParam.value
            state["delayTime"] = delayTimeParam.value
            state["feedback"] = feedbackParam.value
            state["filterCutoff"] = filterCutoffParam.value
            state["filterResonance"] = filterResonanceParam.value
            state["inputGain"] = inputGainParam.value
            state["outputGain"] = outputGainParam.value
            return state
        }
        set {
            super.fullState = newValue
            guard let state = newValue else { return }
            if let v = state["wetDry"] as? Float { wetDryParam.value = v }
            if let v = state["roomSize"] as? Float { roomSizeParam.value = v }
            if let v = state["damping"] as? Float { dampingParam.value = v }
            if let v = state["delayTime"] as? Float { delayTimeParam.value = v }
            if let v = state["feedback"] as? Float { feedbackParam.value = v }
            if let v = state["filterCutoff"] as? Float { filterCutoffParam.value = v }
            if let v = state["filterResonance"] as? Float { filterResonanceParam.value = v }
            if let v = state["inputGain"] as? Float { inputGainParam.value = v }
            if let v = state["outputGain"] as? Float { outputGainParam.value = v }
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
               "Render resources allocated: %.0f Hz, %u ch, %u max frames",
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

            // Pull input from host
            guard let pullInputBlock else {
                return kAudioUnitErr_NoConnection
            }

            var pullFlags: AudioUnitRenderActionFlags = []
            let status = pullInputBlock(&pullFlags, timestamp, frameCount, 0, outputData)
            guard status == noErr else { return status }

            // Process through DSP kernel (in-place)
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
