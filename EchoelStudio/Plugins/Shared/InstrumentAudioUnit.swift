import AudioToolbox
import AVFoundation
import EchoelCore
import EchoelDSP
import EchoelHost
import EchoelKernels
import Synchronization
import os

/// An Echoel instrument as an Audio Unit (`aumu`) for other apps: a kernel's parameters in a
/// tree, MIDI in, stereo out. Once the purchase is on sale (`PluginUnlock.isOnSale`), it plays as
/// a demo until it is unlocked in the app: two seconds of silence every thirty. Every instrument
/// extension uses this one class.
final class InstrumentAudioUnit: AUAudioUnit, EchoelPluginUnit {
    let title: String
    let help: String?
    private let kernelType: any InstrumentKernel.Type
    private var outputBus: AUAudioUnitBus?
    private var busArray: AUAudioUnitBusArray?
    private var tree: AUParameterTree?
    private let render: RenderState
    /// The kernel's starting sounds, and the menu a host shows for them (`factoryPresets`).
    private let presets: [InstrumentKernelPreset]
    private let presetMenu: [AUAudioUnitPreset]
    private var selectedPreset: AUAudioUnitPreset?
    private let log = Logger(subsystem: "com.echoelmusic.studio.plugins", category: "instrument")

    /// The sample a sampler kernel plays, kept here so a new kernel (a new sample rate) and the
    /// host's saved session both get it back.
    struct LoadedSample {
        let buffer: SampleBuffer
        let name: String
    }
    private(set) var sample: LoadedSample?
    /// A sample the host's session holds that the free memory could not load at the restore: its
    /// bytes are kept as they came, so the next save hands the session back what it gave. Without
    /// them, a moment of low memory in the extension erased the sample from the host's song
    /// (seventh night review, 2026-10-23). Any sample installed replaces it.
    private var unloadedSample: (frames: Data, rate: Double, name: String)?
    /// What the window names: the sample that plays, or one the session holds that the free memory
    /// could not load — shown as no sample, it could not be cleared while every save kept it
    /// (eighth night review, 2026-10-23). `sampleIsUnloaded` says which, so the window gives the
    /// reason its own line instead of a suffix the one-line title cuts off (ninth night review).
    var sampleTitle: String? { sample?.name ?? unloadedSample?.name }
    var sampleIsUnloaded: Bool { sample == nil && unloadedSample != nil }
    /// Told the new sample's name (nil: none) after every change — from the window, or from a
    /// host restoring its session or loading a preset — so an open window names what plays.
    private let sampleObserver = Mutex<(@Sendable (String?, Bool) -> Void)?>(nil)
    /// The longest sample the plugin takes. A host keeps it inside its session, so it stays short.
    static let maximumSampleSeconds: Double = 30
    /// The same limit in frames — 30 s at 192 kHz, 23 MB. Seconds alone let a 768 kHz file take
    /// 23 M frames, 92 MB, in the extension, which has the tightest memory limit of all (second
    /// night review, 2026-10-23): a limit in frames is what bounds the memory, as in the app. It is
    /// not 30 s at 48 kHz, because the builds before it took 30 s at any rate and wrote such samples
    /// into host sessions: at 48 kHz a 25 s, 96 kHz sample a host kept came back as an empty slot
    /// (third night review). 192 kHz is the highest rate a recorder commonly writes.
    static let maximumSampleFrames = 5_760_000
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
        presets = kernel.factoryPresets
        presetMenu = InstrumentPresets.menu(presets)
        try super.init(componentDescription: componentDescription, options: options)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2) else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_FormatNotSupported))
        }
        let bus = try AUAudioUnitBus(format: format)
        bus.maximumChannelCount = 2
        // Stereo only, said on the bus too: it checks a new format's channels before it asks us.
        bus.supportedChannelCounts = UnitFormat.channelCounts
        outputBus = bus
        busArray = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [bus])
        // `.flag_CanRamp` only where the kernel glides a host's ramp (the synth's numbers).
        tree = InstrumentParameterTree.make(for: kernel)
        let state = render
        tree?.implementorValueObserver = { parameter, value in
            state.kernel.setParameter(Int(parameter.address), value)
        }
        tree?.implementorValueProvider = { parameter in
            state.kernel.parameter(Int(parameter.address))
        }
        maximumFramesToRender = 4_096
        // The tree starts at the parameters' defaults, which is the first preset ("Init").
        selectedPreset = presetMenu.first
    }

    override var parameterTree: AUParameterTree? {
        get { tree }
        set { tree = newValue }
    }

    /// The app's presets for this instrument, numbered by their place; none for the drums and the
    /// sampler, which have none in the app either.
    override var factoryPresets: [AUAudioUnitPreset]? { presetMenu }

    /// A host may save the musician's own sounds as user presets: the system keeps each as this
    /// unit's `fullState` (the parameters, and the sampler's sample), the state a session keeps.
    override var supportsUserPresets: Bool { true }

    /// A host chooses a preset from its own interface, never on the render thread. A factory
    /// preset sets every value through the parameter tree, so the host's controls follow; a user
    /// preset restores the state it was saved with. A number this build does not list, or a user
    /// preset that cannot be read, changes nothing and keeps the preset chosen before.
    override var currentPreset: AUAudioUnitPreset? {
        get { selectedPreset }
        set {
            guard let newValue else {
                selectedPreset = nil
                return
            }
            let chosen = InstrumentPresets.choose(newValue, from: presets, tree: tree) { preset in
                fullState = try presetState(for: preset)
            }
            if chosen {
                selectedPreset = newValue
            } else {
                log.error("preset \(newValue.number, privacy: .public) not chosen")
            }
        }
    }

    override var outputBusses: AUAudioUnitBusArray {
        busArray ?? AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [])
    }

    override var canProcessInPlace: Bool { false }

    /// No input, stereo out, and nothing else: the render block fills exactly two buffers. Without
    /// this a host reads "any number of channels" and may offer the instrument in mono, which
    /// `allocateRenderResources` then refuses (the effects say theirs in `StandardEffectUnit`).
    override var channelCapabilities: [NSNumber]? { UnitFormat.instrumentCapabilities }

    /// Asked before a host changes the output's format. A format the render block cannot fill — an
    /// interleaved one arrives as a single buffer, an integer one would be handed float bits — is
    /// refused here, so the host hears it when it sets the format and can choose another, instead
    /// of at allocation or as an error in every render call. The earlier instrument refused the
    /// same (`Sources/EchoelmusicAUv3`).
    override func shouldChange(to format: AVAudioFormat, for bus: AUAudioUnitBus) -> Bool {
        UnitFormat.accepts(format) && super.shouldChange(to: format, for: bus)
    }

    var isUnlocked: Bool {
        get { render.unlocked.load(ordering: .acquiring) }
        set { render.unlocked.store(newValue, ordering: .releasing) }
    }

    /// The format is checked BEFORE the base class counts the unit as allocated, as the effects do.
    /// Refused after it, the unit stayed marked allocated with no buffers: the base class then
    /// turns down every new bus format until the host deallocates, so a host that tried a format
    /// we do not play could not go on to one we do.
    override func allocateRenderResources() throws {
        guard let format = outputBus?.format, UnitFormat.accepts(format) else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_FormatNotSupported))
        }
        try super.allocateRenderResources()
        let frames = Int(maximumFramesToRender)
        let kernel = kernelType.init(sampleRate: format.sampleRate, maximumFrames: frames)
        for index in kernelType.parameters.indices {
            kernel.setParameter(index, render.kernel.parameter(index))
        }
        log.info("allocate \(self.title, privacy: .public) \(format.sampleRate, privacy: .public) Hz, \(frames, privacy: .public) frames")
        if let sample, let sampler = kernel as? any SampleLoadingKernel { sampler.load(sample.buffer) }
        // A host may allocate twice with no deallocation between: the earlier buffers go first.
        releaseBuffers()
        render.kernel = kernel
        render.left = .allocate(capacity: frames)
        render.right = .allocate(capacity: frames)
        render.capacity = frames
        render.demoFrame = 0
    }

    /// Frees the buffers a host may ask the render block to supply. Never while a render call
    /// runs: a host renders only between allocation and deallocation.
    private func releaseBuffers() {
        render.left?.deallocate()
        render.right?.deallocate()
        render.left = nil
        render.right = nil
        render.capacity = 0
    }

    /// A host may let the unit go without deallocating its render resources.
    deinit {
        render.left?.deallocate()
        render.right?.deallocate()
    }

    /// Makes `buffer` the sample, or takes the sample away. Off the render thread.
    func installSample(_ buffer: SampleBuffer?, name: String) {
        guard acceptsSamples else { return }
        install(buffer, name: name)
    }

    /// Makes `buffer` the sample, or none — keeping `unloaded`, a session's sample the memory
    /// refused, when there is none. The window is told once: two notices could reach it in either
    /// order (ninth night review, 2026-10-23).
    private func install(_ buffer: SampleBuffer?, name: String,
                         unloaded: (frames: Data, rate: Double, name: String)? = nil) {
        let loaded = buffer.map { LoadedSample(buffer: $0, name: name) }
        unloadedSample = loaded == nil ? unloaded : nil
        sample = loaded
        (render.kernel as? any SampleLoadingKernel)?.load(loaded?.buffer)
        let observer = sampleObserver.withLock { $0 }
        observer?(sampleTitle, sampleIsUnloaded)
    }

    func observeSample(_ observer: (@Sendable (String?, Bool) -> Void)?) {
        sampleObserver.withLock { $0 = observer }
    }

    /// The parameters (the system's part) plus the sample, so a host's session brings it back.
    override var fullState: [String: Any]? {
        get {
            var state = super.fullState ?? [:]
            state[InstrumentState.markerKey] = 1
            if acceptsSamples, let sample {
                // Straight from the sample's memory into the session's bytes, no array between.
                state[StateKey.frames] = sample.buffer.withFrames { Data(buffer: $0) }
                state[StateKey.rate] = sample.buffer.sampleRate
                state[StateKey.name] = sample.name
            } else if acceptsSamples, let unloadedSample {
                state[StateKey.frames] = unloadedSample.frames
                state[StateKey.rate] = unloadedSample.rate
                state[StateKey.name] = unloadedSample.name
            }
            return state
        }
        set {
            super.fullState = InstrumentState.forBaseRestore(newValue, subtype: componentDescription.componentSubType)
            guard acceptsSamples else { return }
            guard let data = newValue?[StateKey.frames] as? Data, let rate = newValue?[StateKey.rate] as? Double,
                  rate.isFinite, rate > 0, Double(data.count / 4) / rate <= Self.maximumSampleSeconds,
                  data.count / 4 <= Self.maximumSampleFrames else {
                install(nil, name: "")
                return
            }
            // Copied from the session straight into the sample's own memory: held once beside the
            // host's data, never a third time as an array on the way.
            let count = data.count / MemoryLayout<Float>.size
            let name = newValue?[StateKey.name] as? String ?? "Sample"
            do {
                let buffer = try SampleBuffer(capacity: count, sampleRate: rate) { frames in
                    data.copyBytes(to: frames) / MemoryLayout<Float>.size
                }
                install(buffer, name: name)
            } catch {
                // Only the memory refuses here: silent for now, and the session keeps its sample.
                log.error("sample not loaded at restore: no free memory")
                install(nil, name: "", unloaded: (frames: data, rate: rate, name: name))
            }
        }
    }

    override func deallocateRenderResources() {
        releaseBuffers()
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

            // The host's numbers are read without arithmetic that can stop the process
            // (`RenderEvents`): a sample time that is no number, an event time or an address at
            // the edge of its type.
            let start = RenderEvents.start(sampleTime: timestamp.pointee.mSampleTime)
            let demoFrom = state.demoFrame
            state.demoFrame += Int64(frames)
            var done = 0
            var event = eventList
            while let current = event {
                let header = current.pointee.head
                let offset = RenderEvents.offset(eventTime: header.eventSampleTime, start: start, done: done, frames: frames)
                if offset > done {
                    state.kernel.render(frames: offset - done, left: left + done, right: right + done, gain: 1)
                    done = offset
                }
                switch header.eventType {
                case .MIDI:
                    // Two-byte messages too: channel pressure and program change (audit 2026-11-04).
                    let midi = current.pointee.MIDI
                    state.kernel.receive(midi: Int(midi.length), midi.data.0, midi.data.1, midi.data.2)
                case .parameter:
                    let parameter = current.pointee.parameter
                    state.kernel.setParameter(RenderEvents.address(parameter.parameterAddress), parameter.value)
                case .parameterRamp:
                    // The ramp runs over its frames, as the host asked, where the kernel can glide.
                    let parameter = current.pointee.parameter
                    state.kernel.rampParameter(RenderEvents.address(parameter.parameterAddress), to: parameter.value,
                                               frames: Int(parameter.rampDurationSampleFrames))
                default:
                    break
                }
                event = UnsafePointer(header.next)
            }
            if done < frames {
                state.kernel.render(frames: frames - done, left: left + done, right: right + done, gain: 1)
            }
            // Under full scale whatever the patch: a host may sum into a bus that cuts flat.
            OutputSafety.apply(left: left, right: right, frames: frames)
            // Locked, the demo's silence fades in and out instead of switching (A9).
            if !state.unlocked.load(ordering: .relaxed) {
                DemoGate.apply(left: left, right: right, frames: frames, fromFrame: demoFrom,
                               sampleRate: state.kernel.sampleRate)
            }
            return noErr
        }
    }
}
