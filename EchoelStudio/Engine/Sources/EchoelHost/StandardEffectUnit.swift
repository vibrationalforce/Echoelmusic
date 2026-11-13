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
                                         name: "Echoelmusic: \(effect.title)", version: 1)
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
        /// Raised by `reset()` on the host's thread; the render drains it and empties the tails
        /// at the start of its next block, so the kernel's buffers have one writer.
        let resetRequested = Atomic<Bool>(false)
        /// The dry path a bypass plays through, as long as the effect's latency; made only in
        /// `allocateRenderResources`, never in the render.
        var bypassLine = LatencyLine(frames: 0)
        var demoFrame: Int64 = 0
        /// In another app's host (the extension's ids) the output ends in `OutputSafety`. In Echoel
        /// the unit is an insert inside a float mix whose end has its own guard, so it does not
        /// bend a hot track there.
        let guardsOutput: Bool
        init(kernel: EffectKernel, guardsOutput: Bool) {
            self.kernel = kernel
            self.guardsOutput = guardsOutput
        }
    }

    /// The dry sound `length` frames late, both sides, so a bypassed unit keeps the latency it
    /// reports and a host that compensates it keeps the track in time. Fed while the effect plays
    /// too, so switching to bypass continues the dry sound where the wet one stood instead of
    /// replaying old samples. Length 0 passes through. Its buffers are allocated once, here.
    final class LatencyLine: @unchecked Sendable {
        let length: Int
        private let heldLeft: UnsafeMutablePointer<Float>
        private let heldRight: UnsafeMutablePointer<Float>
        private var position = 0

        init(frames: Int) {
            length = Swift.max(0, frames)
            let capacity = Swift.max(1, length)
            heldLeft = .allocate(capacity: capacity)
            heldLeft.initialize(repeating: 0, count: capacity)
            heldRight = .allocate(capacity: capacity)
            heldRight.initialize(repeating: 0, count: capacity)
        }

        deinit {
            heldLeft.deallocate()
            heldRight.deallocate()
        }

        /// Render thread: replaces `frames` of the input with the input `length` frames earlier.
        func pass(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
            guard length > 0 else { return }
            var index = position
            for frame in 0..<frames {
                let earlierLeft = heldLeft[index]
                let earlierRight = heldRight[index]
                heldLeft[index] = left[frame]
                heldRight[index] = right[frame]
                left[frame] = earlierLeft
                right[frame] = earlierRight
                index += 1
                if index == length { index = 0 }
            }
            position = index
        }

        /// Render thread: remembers `frames` of the input and leaves the buffers as they are.
        func feed(left: UnsafePointer<Float>, right: UnsafePointer<Float>, frames: Int) {
            guard length > 0 else { return }
            var index = position
            for frame in 0..<frames {
                heldLeft[index] = left[frame]
                heldRight[index] = right[frame]
                index += 1
                if index == length { index = 0 }
            }
            position = index
        }

        /// Render thread: silence, as after a host's reset.
        func clear() {
            guard length > 0 else { return }
            heldLeft.update(repeating: 0, count: length)
            heldRight.update(repeating: 0, count: length)
            position = 0
        }
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
        render = RenderState(kernel: EffectKernel(effect: effect, sampleRate: 48_000),
                             guardsOutput: StandardEffect(component: component) == nil)
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
        tree = Self.makeTree(effect, render.kernel.parameters)
        let state = render
        tree?.implementorValueObserver = { parameter, value in
            state.kernel.setParameter(Int(parameter.address), value)
        }
        tree?.implementorValueProvider = { parameter in
            state.kernel.parameter(Int(parameter.address))
        }
        maximumFramesToRender = 4_096
    }

    /// The tree a host reaches: `.flag_CanRamp` exactly where the kernel runs a host's ramp over
    /// its frames (`EffectKernel.canRamp`) — never on a named choice or a switch. A host ramps the
    /// others by sending values, which a ramp event taken at its end value would skip.
    private static func makeTree(_ effect: StandardEffect, _ parameters: [EffectParameter]) -> AUParameterTree {
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
            var flags: AudioUnitParameterOptions = [.flag_IsReadable, .flag_IsWritable]
            if EffectKernel.canRamp(effect, parameter.address) { flags.insert(.flag_CanRamp) }
            let node = AUParameterTree.createParameter(
                withIdentifier: parameter.identifier, name: parameter.title,
                address: AUParameterAddress(parameter.address),
                min: parameter.range.lowerBound, max: parameter.range.upperBound, unit: unit, unitName: nil,
                flags: flags,
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

    /// Stereo in, stereo out, and nothing else: the render takes exactly two channels and
    /// `allocateRenderResources` refuses any other format. Without this a host such as AUM or
    /// Logic reads "any count" (nil) and may offer a mono or surround insert the unit then refuses
    /// at load.
    public override var channelCapabilities: [NSNumber]? { [NSNumber(value: 2), NSNumber(value: 2)] }

    /// Asked before a host changes either bus's format. The render block takes two buffers of
    /// floats on each side: an interleaved stereo format arrives as ONE buffer, which the block
    /// handed on unprocessed, and an integer one would be read as floats. Such a format is refused
    /// here, when the host sets it, so the host can choose another — the instrument unit refuses the
    /// same (`UnitFormat`).
    public override func shouldChange(to format: AVAudioFormat, for bus: AUAudioUnitBus) -> Bool {
        UnitFormat.accepts(format) && super.shouldChange(to: format, for: bus)
    }

    /// The base state (the parameter tree by address) plus the same values by identifier
    /// (`StandardEffectSettings`). A state Echoel wrote without loading the unit — the master
    /// suggestion's — carries only the identifiers; a state with both plays the identifiers.
    public override var fullState: [String: Any]? {
        get {
            var state = super.fullState ?? [:]
            let values = render.kernel.parameters.reduce(into: [String: Float]()) { $0[$1.identifier] = render.kernel.parameter($1.address) }
            if let data = StandardEffectSettings.state(values, for: effect),
               let list = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
                state[StandardEffectSettings.valuesKey] = list[StandardEffectSettings.valuesKey]
            }
            return state
        }
        set {
            // The base restore only gets a state that has its snapshot: one written by Echoel alone
            // names no unit and holds no blob.
            if let newValue, newValue[InstrumentState.baseSnapshotKey] != nil { super.fullState = newValue }
            guard let newValue else { return }
            for setting in StandardEffectSettings.values(in: newValue, for: effect) {
                if let parameter = tree?.parameter(withAddress: AUParameterAddress(setting.address)) {
                    parameter.value = setting.value
                }
                render.kernel.setParameter(setting.address, setting.value)
            }
        }
    }

    /// The document's state is the full state (some hosts keep the two apart).
    public override var fullStateForDocument: [String: Any]? {
        get { fullState }
        set { fullState = newValue }
    }

    /// The pitch correction, the multiband clipper and the tape play their output a little behind
    /// their input (`EffectKernel.latencySeconds`); a host that compensates delay (Logic, AUM) lines
    /// the track up with this. The other effects have none.
    public override var latency: TimeInterval {
        render.kernel.latencySeconds
    }

    /// How long the output rings after the input stops (`EffectKernel.tailSeconds`), from the values
    /// set now: a host that stops pulling a silent track (Logic, AUM, an offline bounce) keeps the
    /// reverb's and the delay's tails instead of cutting them. 0 for an EQ or a compressor.
    public override var tailTime: TimeInterval {
        render.kernel.tailSeconds
    }

    /// Unlocked, the unit always plays. Locked, it plays as a demo: two seconds of silence every
    /// thirty. Every unit starts unlocked, and no shell locks an effect: the effects are free in
    /// the app and in other hosts (founder 2026-10-18). The instruments' demo lives in their own
    /// shell (`Plugins/Shared/InstrumentAudioUnit`), not here.
    public var isUnlocked: Bool {
        get { render.unlocked.load(ordering: .acquiring) }
        set { render.unlocked.store(newValue, ordering: .releasing) }
    }

    /// A host's bypass (GarageBand's or AUM's switch): the input passes through unchanged — as
    /// late as the effect's `latency`, which does not change, so a host that compensates it keeps
    /// the bypassed track in time (pitch correction, multiband clipper, tape; the others pass at 0) — and
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

    /// The song's key the effect plays in: what the app's engine last handed it, or C until then —
    /// another host has no song key to give.
    public var key: SongKey { render.kernel.key }

    /// Stereo in and out at ONE sample rate: the kernel plays at the output's rate and has no
    /// resampler, so a host that sets the input at 44.1 kHz and the output at 48 kHz is refused
    /// here (before the base class allocates anything) rather than played at the wrong pitch.
    public override func allocateRenderResources() throws {
        guard let format = outputBus?.format, format.channelCount == 2,
              let input = inputBus?.format, input.channelCount == 2,
              input.sampleRate == format.sampleRate, format.sampleRate > 0 else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_FormatNotSupported))
        }
        try super.allocateRenderResources()
        let old = render.kernel
        render.kernel = EffectKernel(effect: effect, sampleRate: format.sampleRate, values: old.allValues)
        render.kernel.follow(key: old.key)
        render.bypassLine = LatencyLine(frames: Int((render.kernel.latencySeconds * format.sampleRate).rounded()))
        render.maximumFrames = Int(maximumFramesToRender)
        render.demoFrame = 0
        render.resetRequested.store(false, ordering: .releasing)
    }

    /// A host's reset (a transport jump, a stop, a new song): the delay lines, the reverb and
    /// every other tail are emptied, so the old take does not ring into the new one. The host
    /// may call this while rendering, so it only asks; the render block empties the kernel at
    /// the start of its next block. Parameters stay as they are.
    public override func reset() {
        super.reset()
        render.resetRequested.store(true, ordering: .releasing)
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
            let line = state.bypassLine
            if state.resetRequested.exchange(false, ordering: .acquiringAndReleasing) {
                kernel.reset()
                line.clear()
            }
            let bypassed = state.bypassed.load(ordering: .relaxed)
            // Playing, the dry line still hears the input, so a bypass picks it up in time.
            if !bypassed { line.feed(left: left, right: right, frames: frames) }
            // The host's numbers are read without arithmetic that can stop the process
            // (`RenderEvents`): in another app's host that process runs every Echoelmusic unit.
            let start = RenderEvents.start(sampleTime: timestamp.pointee.mSampleTime)
            var done = 0
            var event = eventList
            while let current = event {
                let header = current.pointee.head
                let offset = RenderEvents.offset(eventTime: header.eventSampleTime, start: start, done: done, frames: frames)
                if offset > done {
                    if !bypassed { kernel.process(left: left + done, right: right + done, frames: offset - done) }
                    done = offset
                }
                if header.eventType == .parameter {
                    let parameter = current.pointee.parameter
                    kernel.setParameter(RenderEvents.address(parameter.parameterAddress), parameter.value)
                } else if header.eventType == .parameterRamp {
                    // The ramp runs over its frames where the kernel can (`canRamp`); bypassed, the
                    // kernel does not play, so it takes the end value and comes back there.
                    let parameter = current.pointee.parameter
                    let address = RenderEvents.address(parameter.parameterAddress)
                    if bypassed {
                        kernel.setParameter(address, parameter.value)
                    } else {
                        kernel.rampParameter(address, to: parameter.value,
                                             frames: Int(parameter.rampDurationSampleFrames))
                    }
                }
                event = UnsafePointer(header.next)
            }
            guard !bypassed else {
                line.pass(left: left, right: right, frames: frames)
                // The late dry sound may still ring out of a silent input.
                if line.length > 0 { flags.pointee.remove(.unitRenderAction_OutputIsSilence) }
                return noErr
            }
            if done < frames { kernel.process(left: left + done, right: right + done, frames: frames - done) }
            // A flanger at feedback −0.9 still rings above full scale (audit 2026-11-04).
            if state.guardsOutput { OutputSafety.apply(left: left, right: right, frames: frames) }
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

extension StandardEffectUnit: SongKeyFollowing {
    /// The song's key from the app's engine (VOX), from any thread: the kernel takes only a change,
    /// at the start of its next block, like a parameter.
    public func follow(key: SongKey) {
        render.kernel.follow(key: key)
    }
}
