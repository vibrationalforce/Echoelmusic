import AudioToolbox
import AVFoundation
import EchoelCore
import EchoelKernels
import Foundation
import Synchronization

/// A standard effect as an Audio Unit effect (`aufx`): stereo in, stereo out, its parameters in
/// a tree that hosts, automation and MIDI learn reach like any plugin's. The app registers it in
/// its own process, so it loads without an extension and without a purchase. The Echoel Effects
/// extension makes the same unit from its own ids (`StandardEffect.extensionComponent`) — and
/// leaves it unlocked: the effects are free in other hosts too (founder 2026-10-18; the
/// extension's shell declares `needsPurchase == false`). The demo branch below stays so a shell
/// COULD lock a unit; today only `StandardEffectUnitTests` exercises it.
public final class StandardEffectUnit: AUAudioUnit {
    /// Registers every standard effect in this process. Call once, before the first load.
    public static func register() {
        for effect in StandardEffect.allCases {
            AUAudioUnit.registerSubclass(StandardEffectUnit.self, as: audioComponent(effect.component),
                                         name: "Echoel: \(effect.title)", version: 1)
        }
    }

    public static func audioComponent(_ component: PluginComponent) -> AudioComponentDescription {
        AudioComponentDescription(componentType: component.type, componentSubType: component.subtype,
                                  componentManufacturer: component.manufacturer, componentFlags: 0,
                                  componentFlagsMask: 0)
    }

    /// What the render block reads; the kernel is swapped only in `allocateRenderResources`.
    final class RenderState: @unchecked Sendable {
        var kernel: EffectKernel
        /// `maximumFramesToRender` when the resources were allocated; a render call asking for
        /// more is refused (`kAudioUnitErr_TooManyFramesToProcess`), 0 until allocated.
        var maximumFrames = 0
        let unlocked = Atomic<Bool>(true)
        let bypassed = Atomic<Bool>(false)
        var demoFrame: Int64 = 0
        init(kernel: EffectKernel) { self.kernel = kernel }
    }

    public let effect: StandardEffect
    private let render: RenderState
    private var inputBus: AUAudioUnitBus?
    private var outputBus: AUAudioUnitBus?
    private var inputs: AUAudioUnitBusArray?
    private var outputs: AUAudioUnitBusArray?
    private var tree: AUParameterTree?

    public override init(componentDescription: AudioComponentDescription,
                         options: AudioComponentInstantiationOptions = []) throws {
        let component = PluginComponent(type: componentDescription.componentType,
                                        subtype: componentDescription.componentSubType,
                                        manufacturer: componentDescription.componentManufacturer, name: "",
                                        manufacturerName: "")
        guard let effect = StandardEffect(component: component) ?? StandardEffect(extensionComponent: component) else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_InvalidProperty))
        }
        self.effect = effect
        render = RenderState(kernel: EffectKernel(effect: effect, sampleRate: 48_000))
        try super.init(componentDescription: componentDescription, options: options)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2) else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_FormatNotSupported))
        }
        let input = try AUAudioUnitBus(format: format)
        let output = try AUAudioUnitBus(format: format)
        input.maximumChannelCount = 2
        output.maximumChannelCount = 2
        inputBus = input
        outputBus = output
        inputs = AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [input])
        outputs = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [output])
        tree = Self.makeTree(render.kernel.parameters)
        let state = render
        tree?.implementorValueObserver = { parameter, value in
            state.kernel.setParameter(Int(parameter.address), value)
        }
        tree?.implementorValueProvider = { parameter in
            state.kernel.parameter(Int(parameter.address))
        }
        maximumFramesToRender = 4_096
    }

    private static func makeTree(_ parameters: [EffectParameter]) -> AUParameterTree {
        let children = parameters.map { parameter in
            let unit: AudioUnitParameterUnit = switch parameter.unit {
            case .seconds: .seconds
            case .hertz: .hertz
            case .decibels: .decibels
            case .ratio: .ratio
            case .amount: .generic
            case .boolean: .boolean
            case .choice: .indexed
            }
            let node = AUParameterTree.createParameter(
                withIdentifier: parameter.identifier, name: parameter.title,
                address: AUParameterAddress(parameter.address),
                min: parameter.range.lowerBound, max: parameter.range.upperBound, unit: unit, unitName: nil,
                // No `.flag_CanRamp`: a ramp event is taken as its end value, so the host ramps (A9).
                flags: [.flag_IsReadable, .flag_IsWritable],
                // A named choice reaches a host as its names: GarageBand and AUM show a menu.
                valueStrings: parameter.choices.isEmpty ? nil : parameter.choices,
                dependentParameters: nil)
            node.value = parameter.defaultValue
            return node
        }
        return AUParameterTree.createTree(withChildren: children)
    }

    public override var parameterTree: AUParameterTree? {
        get { tree }
        set { tree = newValue }
    }

    public override var inputBusses: AUAudioUnitBusArray {
        inputs ?? AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [])
    }

    public override var outputBusses: AUAudioUnitBusArray {
        outputs ?? AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [])
    }

    public override var canProcessInPlace: Bool { true }

    /// Unlocked, the unit always plays. Locked, it plays as a demo: two seconds of silence every
    /// thirty. Every unit starts unlocked, and no shell locks an effect: the effects are free in
    /// the app and in other hosts (founder 2026-10-18). The instruments' demo lives in their own
    /// shell (`Plugins/Shared/InstrumentAudioUnit`), not here.
    public var isUnlocked: Bool {
        get { render.unlocked.load(ordering: .acquiring) }
        set { render.unlocked.store(newValue, ordering: .releasing) }
    }

    /// A host's bypass (GarageBand's or AUM's switch): the input passes through unchanged, and
    /// parameter changes still reach the kernel, so the effect comes back as the host left it. In
    /// the app the engine drops a bypassed insert from its chain instead (`HostedEffect`), so only
    /// other hosts set this (review 2026-10-23).
    public override var shouldBypassEffect: Bool {
        get { render.bypassed.load(ordering: .acquiring) }
        set { render.bypassed.store(newValue, ordering: .releasing) }
    }

    /// Whether a locked unit is silent `frame` frames after its resources were allocated.
    public static func demoIsSilent(atFrame frame: Int64, sampleRate: Double) -> Bool {
        DemoGate.isSilent(atFrame: frame, sampleRate: sampleRate)
    }

    /// The compressor's gain reduction in dB, for a meter.
    public var gainReduction: Float { render.kernel.gainReduction }

    public override func allocateRenderResources() throws {
        try super.allocateRenderResources()
        guard let format = outputBus?.format, format.channelCount == 2,
              inputBus?.format.channelCount == 2 else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_FormatNotSupported))
        }
        let old = render.kernel
        render.kernel = EffectKernel(effect: effect, sampleRate: format.sampleRate, values: old.allValues)
        render.maximumFrames = Int(maximumFramesToRender)
        render.demoFrame = 0
    }

    public override var internalRenderBlock: AUInternalRenderBlock {
        let state = render
        return { flags, timestamp, frameCount, _, outputData, eventList, pullInput in
            let frames = Int(frameCount)
            guard frames <= state.maximumFrames else { return kAudioUnitErr_TooManyFramesToProcess }
            guard let pullInput else { return kAudioUnitErr_NoConnection }
            // In place: the input arrives in the output's buffers (or the host's own).
            let status = pullInput(flags, timestamp, frameCount, 0, outputData)
            guard status == noErr else { return status }
            let buffers = UnsafeMutableAudioBufferListPointer(outputData)
            guard buffers.count >= 2,
                  let left = buffers[0].mData?.assumingMemoryBound(to: Float.self),
                  let right = buffers[1].mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            let kernel = state.kernel
            let bypassed = state.bypassed.load(ordering: .relaxed)
            let start = AUEventSampleTime(timestamp.pointee.mSampleTime)
            var done = 0
            var event = eventList
            while let current = event {
                let header = current.pointee.head
                let offset = Swift.min(Swift.max(Int(header.eventSampleTime - start), done), frames)
                if offset > done {
                    if !bypassed { kernel.process(left: left + done, right: right + done, frames: offset - done) }
                    done = offset
                }
                if header.eventType == .parameter || header.eventType == .parameterRamp {
                    let parameter = current.pointee.parameter
                    kernel.setParameter(Int(parameter.parameterAddress), parameter.value)
                }
                event = UnsafePointer(header.next)
            }
            guard !bypassed else { return noErr }
            if done < frames { kernel.process(left: left + done, right: right + done, frames: frames - done) }
            // The pull may have reported a silent input; a delay or reverb tail is not silent, so the
            // hint must not travel on to the host, which may skip a buffer it thinks is empty.
            flags.pointee.remove(.unitRenderAction_OutputIsSilence)
            if !state.unlocked.load(ordering: .relaxed) {
                DemoGate.apply(left: left, right: right, frames: frames, fromFrame: state.demoFrame,
                               sampleRate: kernel.sampleRate)
                state.demoFrame += Int64(frames)
            }
            return noErr
        }
    }
}
