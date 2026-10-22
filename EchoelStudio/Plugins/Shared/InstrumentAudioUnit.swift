import AudioToolbox
import AVFoundation
import EchoelCore
import EchoelDSP
import EchoelEngine
import EchoelHost
import EchoelKernels
import Synchronization
import os

/// An Echoel instrument as an Audio Unit (`aumu`) for other apps: a kernel's parameters in a
/// tree, MIDI in, stereo out. Until it is unlocked (a purchase in Echoel) it plays as a demo:
/// two seconds of silence every thirty. Every instrument extension uses this one class.
final class InstrumentAudioUnit: AUAudioUnit, EchoelPluginUnit {
    let title: String
    let help: String?
    private let kernelType: any InstrumentKernel.Type
    private var outputBus: AUAudioUnitBus?
    private var busArray: AUAudioUnitBusArray?
    private var tree: AUParameterTree?
    private let render: RenderState
    private let log = Logger(subsystem: "com.echoelmusic.studio.plugins", category: "instrument")

    /// The sample a sampler kernel plays, kept here so a new kernel (a new sample rate) and the
    /// host's saved session both get it back.
    struct LoadedSample {
        let buffer: SampleBuffer
        let name: String
    }
    private(set) var sample: LoadedSample?
    /// The longest sample the plugin takes. A host keeps it inside its session, so it stays short.
    static let maximumSampleSeconds: Double = 30
    private enum StateKey {
        static let frames = "echoel.sample.frames", rate = "echoel.sample.rate", name = "echoel.sample.name"
    }

    /// Whether this instrument plays a sample the user loads.
    var acceptsSamples: Bool { kernelType is any SampleLoadingKernel.Type }

    /// What the render block reads. Swapped only in `allocateRenderResources`, which a host
    /// never calls while rendering.
    final class RenderState: @unchecked Sendable {
        var kernel: any InstrumentKernel
        var left: UnsafeMutablePointer<Float>?
        var right: UnsafeMutablePointer<Float>?
        /// The frames `left`, `right` and the kernel were allocated for. A render call asking for
        /// more is refused instead of writing past them.
        var capacity = 0
        let unlocked = Atomic<Bool>(true)
        var demoFrame: Int64 = 0
        init(kernel: any InstrumentKernel) { self.kernel = kernel }
    }

    init(kernel: any InstrumentKernel.Type, title: String, help: String? = nil,
         componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
        kernelType = kernel
        self.title = title
        self.help = help
        render = RenderState(kernel: kernel.init(sampleRate: 48_000, maximumFrames: 4_096))
        try super.init(componentDescription: componentDescription, options: options)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2) else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_FormatNotSupported))
        }
        let bus = try AUAudioUnitBus(format: format)
        bus.maximumChannelCount = 2
        outputBus = bus
        busArray = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [bus])
        tree = Self.makeTree(kernel.parameters)
        let state = render
        tree?.implementorValueObserver = { parameter, value in
            state.kernel.setParameter(Int(parameter.address), value)
        }
        tree?.implementorValueProvider = { parameter in
            state.kernel.parameter(Int(parameter.address))
        }
        maximumFramesToRender = 4_096
    }

    private static func makeTree(_ parameters: [InstrumentKernelParameter]) -> AUParameterTree {
        let nodes = parameters.enumerated().map { index, parameter in
            let unit: AudioUnitParameterUnit = switch parameter.unit {
            case .hertz: .hertz
            case .seconds: .seconds
            case .octaves: .octaves
            case .choice: .indexed
            default: .generic
            }
            let node = AUParameterTree.createParameter(
                withIdentifier: parameter.identifier, name: parameter.title, address: AUParameterAddress(index),
                min: AUValue(parameter.range.lowerBound), max: AUValue(parameter.range.upperBound), unit: unit,
                // No `.flag_CanRamp`: a ramp event is taken as its end value, so the host ramps (A9).
                unitName: nil, flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: parameter.choices.isEmpty ? nil : parameter.choices, dependentParameters: nil)
            node.value = AUValue(parameter.defaultValue)
            return node
        }
        return AUParameterTree.createTree(withChildren: nodes)
    }

    override var parameterTree: AUParameterTree? {
        get { tree }
        set { tree = newValue }
    }

    override var outputBusses: AUAudioUnitBusArray {
        busArray ?? AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [])
    }

    override var canProcessInPlace: Bool { false }

    var isUnlocked: Bool {
        get { render.unlocked.load(ordering: .acquiring) }
        set { render.unlocked.store(newValue, ordering: .releasing) }
    }

    override func allocateRenderResources() throws {
        try super.allocateRenderResources()
        guard let format = outputBus?.format, format.channelCount == 2 else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_FormatNotSupported))
        }
        let frames = Int(maximumFramesToRender)
        let kernel = kernelType.init(sampleRate: format.sampleRate, maximumFrames: frames)
        for index in kernelType.parameters.indices {
            kernel.setParameter(index, render.kernel.parameter(index))
        }
        log.info("allocate \(self.title, privacy: .public) \(format.sampleRate, privacy: .public) Hz, \(frames, privacy: .public) frames")
        if let sample, let sampler = kernel as? any SampleLoadingKernel { sampler.load(sample.buffer) }
        render.kernel = kernel
        render.left = .allocate(capacity: frames)
        render.right = .allocate(capacity: frames)
        render.capacity = frames
        render.demoFrame = 0
    }

    /// Makes `mono` the sample, or takes the sample away. Off the render thread.
    func installSample(_ mono: SampleFile.Mono?, name: String) throws {
        guard acceptsSamples else { return }
        var loaded: LoadedSample?
        if let mono {
            guard let buffer = SampleBuffer(samples: mono.samples, sampleRate: mono.sampleRate) else {
                throw SampleFile.ReadError.empty
            }
            loaded = LoadedSample(buffer: buffer, name: name)
        }
        sample = loaded
        (render.kernel as? any SampleLoadingKernel)?.load(loaded?.buffer)
    }

    /// The parameters (the system's part) plus the sample, so a host's session brings it back.
    override var fullState: [String: Any]? {
        get {
            var state = super.fullState ?? [:]
            if acceptsSamples, let sample {
                let frames = sample.buffer.copyFrames()
                state[StateKey.frames] = frames.withUnsafeBufferPointer { Data(buffer: $0) }
                state[StateKey.rate] = sample.buffer.sampleRate
                state[StateKey.name] = sample.name
            }
            return state
        }
        set {
            super.fullState = newValue
            guard acceptsSamples else { return }
            guard let data = newValue?[StateKey.frames] as? Data, let rate = newValue?[StateKey.rate] as? Double,
                  rate.isFinite, rate > 0, Double(data.count / 4) / rate <= Self.maximumSampleSeconds else {
                try? installSample(nil, name: "")
                return
            }
            var frames = [Float](repeating: 0, count: data.count / MemoryLayout<Float>.size)
            _ = frames.withUnsafeMutableBytes { data.copyBytes(to: $0) }
            let name = newValue?[StateKey.name] as? String ?? "Sample"
            try? installSample(SampleFile.Mono(samples: frames, sampleRate: rate), name: name)
        }
    }

    override func deallocateRenderResources() {
        render.left?.deallocate()
        render.right?.deallocate()
        render.left = nil
        render.right = nil
        render.capacity = 0
        super.deallocateRenderResources()
    }

    override var internalRenderBlock: AUInternalRenderBlock {
        let state = render
        return { _, timestamp, frameCount, _, outputData, eventList, _ in
            let frames = Int(frameCount)
            let buffers = UnsafeMutableAudioBufferListPointer(outputData)
            guard buffers.count >= 2, let ownLeft = state.left, let ownRight = state.right else {
                return kAudioUnitErr_Uninitialized
            }
            // More frames than were allocated would write past our buffers and the kernel's.
            guard frames <= state.capacity else { return kAudioUnitErr_TooManyFramesToProcess }
            // The host may hand buffers or ask for ours.
            if buffers[0].mData == nil { buffers[0].mData = UnsafeMutableRawPointer(ownLeft) }
            if buffers[1].mData == nil { buffers[1].mData = UnsafeMutableRawPointer(ownRight) }
            buffers[0].mDataByteSize = UInt32(frames * MemoryLayout<Float>.size)
            buffers[1].mDataByteSize = UInt32(frames * MemoryLayout<Float>.size)
            guard let left = buffers[0].mData?.assumingMemoryBound(to: Float.self),
                  let right = buffers[1].mData?.assumingMemoryBound(to: Float.self) else { return noErr }

            let start = AUEventSampleTime(timestamp.pointee.mSampleTime)
            let demoFrom = state.demoFrame
            state.demoFrame += Int64(frames)
            var done = 0
            var event = eventList
            while let current = event {
                let header = current.pointee.head
                let offset = Swift.min(Swift.max(Int(header.eventSampleTime - start), done), frames)
                if offset > done {
                    state.kernel.render(frames: offset - done, left: left + done, right: right + done, gain: 1)
                    done = offset
                }
                switch header.eventType {
                case .MIDI:
                    let midi = current.pointee.MIDI
                    if midi.length >= 3 { state.kernel.receive(status: midi.data.0, midi.data.1, midi.data.2) }
                case .parameter, .parameterRamp:
                    let parameter = current.pointee.parameter
                    state.kernel.setParameter(Int(parameter.parameterAddress), parameter.value)
                default:
                    break
                }
                event = UnsafePointer(header.next)
            }
            if done < frames {
                state.kernel.render(frames: frames - done, left: left + done, right: right + done, gain: 1)
            }
            // Locked, the demo's silence fades in and out instead of switching (A9).
            if !state.unlocked.load(ordering: .relaxed) {
                DemoGate.apply(left: left, right: right, frames: frames, fromFrame: demoFrom,
                               sampleRate: state.kernel.sampleRate)
            }
            return noErr
        }
    }
}
