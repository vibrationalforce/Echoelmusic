import AudioToolbox
import AVFoundation
import EchoelCore
import EchoelEngine
import Synchronization
import os

/// An Echoel instrument as an Audio Unit (`aumu`) for other apps: a kernel's parameters in a
/// tree, MIDI in, stereo out. Until it is unlocked (a purchase in Echoel) it plays as a demo:
/// two seconds of silence every thirty. Every instrument extension uses this one class.
final class InstrumentAudioUnit: AUAudioUnit, EchoelPluginUnit {
    let plugin: OwnPlugin
    var title: String { plugin.component.name }
    let help: String?
    private let kernelType: any InstrumentKernel.Type
    private var outputBus: AUAudioUnitBus?
    private var busArray: AUAudioUnitBusArray?
    private var tree: AUParameterTree?
    private let render: RenderState
    private let log = Logger(subsystem: "com.echoelmusic.studio.plugins", category: "instrument")

    /// What the render block reads. Swapped only in `allocateRenderResources`, which a host
    /// never calls while rendering.
    final class RenderState: @unchecked Sendable {
        var kernel: any InstrumentKernel
        var left: UnsafeMutablePointer<Float>?
        var right: UnsafeMutablePointer<Float>?
        let unlocked = Atomic<Bool>(true)
        var demoFrame: Int64 = 0
        init(kernel: any InstrumentKernel) { self.kernel = kernel }
    }

    init(kernel: any InstrumentKernel.Type, plugin: OwnPlugin, help: String? = nil,
         componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
        kernelType = kernel
        self.plugin = plugin
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
                unitName: nil, flags: [.flag_IsReadable, .flag_IsWritable, .flag_CanRamp],
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
        log.info("allocate \(self.plugin.productID, privacy: .public) \(format.sampleRate, privacy: .public) Hz, \(frames, privacy: .public) frames")
        render.kernel = kernel
        render.left = .allocate(capacity: frames)
        render.right = .allocate(capacity: frames)
        render.demoFrame = 0
    }

    override func deallocateRenderResources() {
        render.left?.deallocate()
        render.right?.deallocate()
        render.left = nil
        render.right = nil
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
            // The host may hand buffers or ask for ours.
            if buffers[0].mData == nil { buffers[0].mData = UnsafeMutableRawPointer(ownLeft) }
            if buffers[1].mData == nil { buffers[1].mData = UnsafeMutableRawPointer(ownRight) }
            buffers[0].mDataByteSize = UInt32(frames * MemoryLayout<Float>.size)
            buffers[1].mDataByteSize = UInt32(frames * MemoryLayout<Float>.size)
            guard let left = buffers[0].mData?.assumingMemoryBound(to: Float.self),
                  let right = buffers[1].mData?.assumingMemoryBound(to: Float.self) else { return noErr }

            let start = AUEventSampleTime(timestamp.pointee.mSampleTime)
            let second = Swift.max(Int64(state.kernel.sampleRate), 1)
            let gain: Float = state.unlocked.load(ordering: .relaxed) || state.demoFrame % (30 * second) < 28 * second ? 1 : 0
            state.demoFrame += Int64(frames)
            var done = 0
            var event = eventList
            while let current = event {
                let header = current.pointee.head
                let offset = Swift.min(Swift.max(Int(header.eventSampleTime - start), done), frames)
                if offset > done {
                    state.kernel.render(frames: offset - done, left: left + done, right: right + done, gain: gain)
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
                state.kernel.render(frames: frames - done, left: left + done, right: right + done, gain: gain)
            }
            return noErr
        }
    }
}
