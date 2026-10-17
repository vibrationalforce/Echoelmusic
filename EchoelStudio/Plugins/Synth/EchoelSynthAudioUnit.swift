import AudioToolbox
import AVFoundation
import EchoelCore
import EchoelEngine
import Synchronization
import os

/// Echoel Synth as an Audio Unit instrument for other apps: the studio's own synth, MIDI in,
/// stereo out. Until it is unlocked (a purchase in Echoel) it plays as a demo: two seconds of
/// silence every thirty.
final class EchoelSynthAudioUnit: AUAudioUnit {
    static let component = AudioComponentDescription(componentType: kAudioUnitType_MusicDevice,
                                                     componentSubType: 0x6553_796E, // 'eSyn'
                                                     componentManufacturer: 0x4563_686F, // 'Echo'
                                                     componentFlags: 0, componentFlagsMask: 0)

    private var outputBus: AUAudioUnitBus?
    private var busArray: AUAudioUnitBusArray?
    private var tree: AUParameterTree?
    private let render = RenderState()
    private let log = Logger(subsystem: "com.echoelmusic.studio.synth", category: "audiounit")

    /// What the render block reads. Swapped only in `allocateRenderResources`, which a host
    /// never calls while rendering.
    final class RenderState: @unchecked Sendable {
        var kernel = SynthKernel(sampleRate: 48_000)
        var left: UnsafeMutablePointer<Float>?
        var right: UnsafeMutablePointer<Float>?
        let unlocked = Atomic<Bool>(false)
        var demoFrame: Int64 = 0
    }

    override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
        try super.init(componentDescription: componentDescription, options: options)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2) else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_FormatNotSupported))
        }
        let bus = try AUAudioUnitBus(format: format)
        bus.maximumChannelCount = 2
        outputBus = bus
        busArray = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [bus])
        tree = Self.makeTree()
        let state = render
        tree?.implementorValueObserver = { parameter, value in
            state.kernel.setParameter(Int(parameter.address), value)
        }
        tree?.implementorValueProvider = { parameter in
            state.kernel.parameter(Int(parameter.address))
        }
        maximumFramesToRender = 4_096
        Task { [state] in state.unlocked.store(await PluginLicense.isUnlocked(), ordering: .releasing) }
    }

    private static func makeTree() -> AUParameterTree {
        let parameters = SynthKernel.parameters.enumerated().map { index, parameter in
            let unit: AudioUnitParameterUnit = switch parameter.unit {
            case .hertz: .hertz
            case .seconds: .seconds
            case .octaves: .octaves
            case .choice: .indexed
            default: .generic
            }
            let p = AUParameterTree.createParameter(
                withIdentifier: parameter.key.rawValue.replacingOccurrences(of: ".", with: "_"),
                name: parameter.title, address: AUParameterAddress(index),
                min: AUValue(parameter.range.lowerBound), max: AUValue(parameter.range.upperBound), unit: unit,
                unitName: nil, flags: [.flag_IsReadable, .flag_IsWritable, .flag_CanRamp],
                valueStrings: parameter.choices.isEmpty ? nil : parameter.choices, dependentParameters: nil)
            p.value = AUValue(parameter.defaultValue)
            return p
        }
        return AUParameterTree.createTree(withChildren: parameters)
    }

    override var parameterTree: AUParameterTree? {
        get { tree }
        set { tree = newValue }
    }

    override var outputBusses: AUAudioUnitBusArray {
        busArray ?? AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [])
    }

    override var canProcessInPlace: Bool { false }

    var isUnlocked: Bool { render.unlocked.load(ordering: .acquiring) }

    override func allocateRenderResources() throws {
        try super.allocateRenderResources()
        guard let format = outputBus?.format, format.channelCount == 2 else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_FormatNotSupported))
        }
        let frames = Int(maximumFramesToRender)
        let kernel = SynthKernel(sampleRate: format.sampleRate, maximumFrames: frames)
        for index in SynthKernel.parameters.indices {
            kernel.setParameter(index, render.kernel.parameter(index))
        }
        log.info("allocate \(format.sampleRate, privacy: .public) Hz, \(frames, privacy: .public) frames")
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
