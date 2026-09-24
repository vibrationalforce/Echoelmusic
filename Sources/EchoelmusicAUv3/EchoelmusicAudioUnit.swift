#if canImport(AVFoundation)
import Foundation
import AVFoundation
import os

/// AUv3 Audio Unit — Bio-Reactive Instrument (Music Device)
///
/// A playable DAW instrument: host MIDI notes drive the pitch (walked from the
/// render block's realtime event list) while bio-reactive parameters (coherence,
/// HRV, heart rate, breath) shape the timbre. Before the first MIDI note a
/// free-running bio tone plays as the idle default (armed once in
/// `allocateRenderResources`); once the host plays notes, a note-off releases the
/// voice like any instrument. Parameters are automatable from Logic Pro,
/// GarageBand, AUM, etc.
///
/// Component: aumu/echl/Echo (instrument — MIDI in, no audio input needed)
public final class EchoelmusicAudioUnit: AUAudioUnit {

    private static let auLog = OSLog(
        subsystem: "com.echoelmusic.app.auv3",
        category: "AudioUnit"
    )

    // MARK: - DSP

    /// ⚠️ The 48000 here is a PLACEHOLDER, not the rate this plug-in runs at. A property
    /// initialiser has no host to ask; `allocateRenderResources()` re-points both engines at
    /// `outputBus.format.sampleRate` before the first render, and the long comment there is
    /// the one that explains why (#1407). Both are `let` on purpose — the rate changes IN
    /// PLACE, the references never move.
    private let synth = EchoelDDSP(sampleRate: 48000)
    private let texture = EchoelCellular(cellCount: 128, sampleRate: 48000)
    /// ⭐ WA3.3 — the audible consumer of host address 6 ("Reverb"). The same Freeverb stage the
    /// app's FX chain runs on its audio thread; its tanks are allocated here and, re-sized for the
    /// host rate, in `allocateRenderResources` — never in render. `let`, like the engines: the
    /// reference never moves.
    /// ⛔ Until 2026-09-24 the tanks stayed sized for 48 kHz whatever the host ran at: about 9 %
    /// larger a room at 44.1 kHz and half the room, in seconds, at 96 kHz.
    private let reverb = EchoelReverb(sampleRate: 48000)
    private var isNoteOn = false

    /// Shared vitals from the main app over the App Group. Refreshed OFF the
    /// render thread by `vitalsTimer`; the render block never reads UserDefaults.
    private let bioFeedback = BioFeedbackManager()
    nonisolated(unsafe) private var vitalsTimer: DispatchSourceTimer?

    /// Timestamp of the last shared frame folded into the bio params — dedupe
    /// so an unchanged store never re-fires the param observer. Touched only
    /// on the vitals timer's serial queue.
    nonisolated(unsafe) private var lastVitalsTimestamp: TimeInterval = -1

    /// Only shared vitals younger than this may overwrite the host-automatable
    /// bio params. Stale / absent / non-egress data ⇒ the params keep whatever
    /// the host, automation, or preset set — byte-identical behavior to running
    /// without the main app. `nonisolated` explicitly: read from the vitals
    /// timer queue (CLAUDE.md static-let isolation gotcha).
    nonisolated private static let vitalsMaxAge: TimeInterval = 2

    /// Pre-allocated render scratch — NO heap allocation on the audio thread. Held INSIDE a
    /// class so the render block owns the SOLE reference to each array: `&scratch.pad` then
    /// mutates in place (isKnownUniquelyReferenced == true), no copy-on-write. Two plain
    /// `[Float]` stored props captured by value were referenced by BOTH self and the capture,
    /// so the first write COW-copied ~16 KB each (~32 KB) on EVERY render callback — a malloc
    /// on the audio thread. Same class-owns-the-buffer pattern as GainMirror below.
    private final class RenderScratch {
        nonisolated(unsafe) var pad: [Float]
        /// WA3.3: the reverb's right channel (`pad` carries the left).
        nonisolated(unsafe) var padR: [Float]
        nonisolated(unsafe) var tex: [Float]
        /// ⭐ 2026-09-24 (overnight P8g) — the output memory the AU OWNS. `AURenderBlock`'s
        /// contract: *"The buffer pointers may be null on entry, in which case the block will
        /// render into memory it owns and modify the `mData` pointers to point to that
        /// memory"*, valid until the next render or `deallocateRenderResources()`. The block
        /// used to `continue` past a null `mData`, so a host that asks the AU to supply its
        /// buffers got none written. Allocated ONCE here (never in render), freed in `deinit`,
        /// so the pointer outlives every render call; sized with the same `capacity` as the
        /// scratch above, i.e. in lockstep with the 4096-frame ceiling. A host bus wider than
        /// `ownedChannels` with null pointers past that index still gets nothing — recorded,
        /// not hidden. Guard: `TheAUv3SuppliesItsOwnOutputBuffersTests`.
        /// NEEDS-FOUNDER-VERIFY: load the plug-in in a host other than AUM (GarageBand, Logic) and hear it — whether any of them passes null output pointers is unmeasured.
        static let ownedChannels = 8
        let capacity: Int
        let ownedOutput: UnsafeMutablePointer<Float>
        init(capacity: Int) {
            self.capacity = capacity
            pad = [Float](repeating: 0, count: capacity)
            padR = [Float](repeating: 0, count: capacity)
            tex = [Float](repeating: 0, count: capacity)
            ownedOutput = UnsafeMutablePointer<Float>.allocate(capacity: capacity * Self.ownedChannels)
            ownedOutput.initialize(repeating: 0, count: capacity * Self.ownedChannels)
        }
        deinit {
            ownedOutput.deallocate()
        }
    }
    private let renderScratch = RenderScratch(capacity: 4096)

    /// Lock-free master-gain mirror for the render thread. The host sets gain via
    /// the ObjC/KVO-backed `AUParameter.value`, which must NOT be read on the audio
    /// thread — the value observer writes it here and the render block reads this
    /// plain Float (atomic-width, no ObjC, no locks). Captured by the block instead
    /// of `self` (capture a value holder, not the actor).
    private final class GainMirror { nonisolated(unsafe) var value: Float = 0.7 }
    private let gainMirror = GainMirror()

    /// Render-thread mirror of the four bio parameters (same pattern as GainMirror).
    /// The parameter value observer can fire on ANY control thread (the vitals utility
    /// queue via pullSharedVitals, host automation, the plugin UI), so it writes these
    /// atomic-width Floats; the render block reads them and calls `applyBioReactive`
    /// RENDER-SIDE (throttled ~10 Hz). That keeps the synth's `harmonicAmplitudes`
    /// array single-owner (render-thread only): its every-6th-call in-place rewrite
    /// (`updateSpectralEnvelope`, verified all-subscript, no realloc) can then never
    /// race a concurrent render read AND never triggers a copy-on-write allocation
    /// (COW copies only when a 2nd thread holds a reference). This closes the
    /// KNOWN-SMELL bio-path COW hazard documented on EchoelDDSP. A MIRROR (not an SPSC
    /// queue like PolySynthVoice v337) is required here because the producer side is
    /// multi-threaded, which single-producer SPSC forbids.
    private final class BioMirror {
        nonisolated(unsafe) var coherence: Float = 0.5
        nonisolated(unsafe) var hrv: Float = 0.5
        nonisolated(unsafe) var heartRate: Float = 0.5
        nonisolated(unsafe) var breathPhase: Float = 0.5
    }
    private let bioMirror = BioMirror()
    /// Render-owned frame accumulator throttling the render-side bio application to
    /// ~10 Hz (the vitals poll rate) — bounds the audio-thread cost to what it was.
    /// Touched ONLY by the render thread (single-owner), so the plain field is safe.
    private final class BioRenderState { nonisolated(unsafe) var frameAccum = 0 }
    private let bioRenderState = BioRenderState()
    /// Render-owned last-note-priority tracker for the mono voice: the MIDI note number
    /// currently sounding (-1 = none, or the free-running bio drone). A note-off silences
    /// the voice ONLY when it releases THAT note, so releasing a still-held earlier note
    /// no longer kills the current one. Touched ONLY by the render thread (single-owner),
    /// so the plain field is safe. `Int32` holds a 7-bit MIDI note plus the -1 sentinel.
    private final class RenderNoteState { nonisolated(unsafe) var current: Int32 = -1 }
    private let renderNoteState = RenderNoteState()

    // MARK: - Buses

    private var _outputBusArray: AUAudioUnitBusArray!
    private var outputBus: AUAudioUnitBus!

    // MARK: - Parameters

    private var _parameterTree: AUParameterTree!

    // Bio parameters (automatable from host)
    private var coherenceParam: AUParameter!
    private var hrvParam: AUParameter!
    private var heartRateParam: AUParameter!
    private var breathPhaseParam: AUParameter!
    private var baseFreqParam: AUParameter!
    private var textureAmountParam: AUParameter!
    private var reverbMixParam: AUParameter!
    private var masterGainParam: AUParameter!

    /// ⭐ WA3.2: the canonical ID and the engine binding for each host address, resolved ONCE
    /// in `setupParameterTree` from `EchoelBodyVibeAUv3Mapping`. Read by the parameter observer
    /// and the preset path (control threads); the render block never touches them.
    private var canonicalIDByAddress: [UInt64: String] = [:]
    private var engineBindingByAddress: [UInt64: EchoelBodyVibeDevice.Binding] = [:]

    // MARK: - Init

    public override init(
        componentDescription: AudioComponentDescription,
        options: AudioComponentInstantiationOptions = []
    ) throws {
        try super.init(componentDescription: componentDescription, options: options)

        guard let defaultFormat = AVAudioFormat(
            standardFormatWithSampleRate: 48000, channels: 2
        ) else {
            throw NSError(domain: "com.echoelmusic.app.auv3", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create audio format"])
        }

        outputBus = try AUAudioUnitBus(format: defaultFormat)
        _outputBusArray = AUAudioUnitBusArray(
            audioUnit: self, busType: .output, busses: [outputBus]
        )

        // Configure texture
        texture.synthMode = .additive
        texture.rule = .rule90
        texture.evolutionRate = 8

        try setupParameterTree()
        // ⭐ 2026-09-24 (P2): the engines start from the tree's own defaults. Until now the
        // texture gain was a literal 0.15 here while the host showed 0.3 — the observer never
        // fires for the defaults, because they are written before it is installed.
        gainMirror.value = EchoelBodyVibeDevice.seed([:], synth: synth, texture: texture)
        os_log(.info, log: Self.auLog, "AUv3 Instrument initialized")
    }

    // MARK: - Parameter Tree

    enum ParameterAddress: UInt64 {
        case coherence = 0
        case hrv = 1
        case heartRate = 2
        case breathPhase = 3
        case baseFrequency = 4
        case textureAmount = 5
        case reverbMix = 6
        case masterGain = 7
    }

    /// ⭐ WA3.2 — the tree is BUILT from the canonical descriptors plus the AUv3 adapter table
    /// (`DSP/EchoelBodyVibeDevice.swift`), no longer hand-written here. Every host-visible
    /// fact — identifier, address, name, range, default, unit, group and order — is the value
    /// the plug-in has always published; `TheParameterIdentityIsFormatNeutralTests` pins them.
    /// A mapping that cannot be resolved throws, and `init` throws with it: a host shows a
    /// plug-in that failed to load rather than one whose knobs drive the wrong parameter.
    private func setupParameterTree() throws {
        let resolved = try EchoelBodyVibeAUv3Mapping.resolve()
        // ⭐ WA3.3: every creative parameter MUST have a runtime binding, or setup throws.
        // Before WA3.3 a missing binding was skipped with `if let`, leaving a knob that moved
        // nothing.
        engineBindingByAddress = try EchoelBodyVibeAUv3Mapping.resolveBindings(resolved)
        var created: [UInt64: AUParameter] = [:]
        var bioChildren: [AUParameter] = []
        var soundChildren: [AUParameter] = []
        for r in resolved {
            let p = AUParameterTree.createParameter(
                withIdentifier: r.identifier, name: r.name,
                address: r.address,
                min: r.min, max: r.max, unit: Self.auUnit(r.unit), unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: nil, dependentParameters: nil
            )
            p.value = r.defaultValue
            created[r.address] = p
            if case .creative(let id) = r.target {
                canonicalIDByAddress[r.address] = id
            }
            switch r.group {
            case .bio: bioChildren.append(p)
            case .sound: soundChildren.append(p)
            }
        }
        guard let coherence = created[ParameterAddress.coherence.rawValue],
              let hrv = created[ParameterAddress.hrv.rawValue],
              let heartRate = created[ParameterAddress.heartRate.rawValue],
              let breathPhase = created[ParameterAddress.breathPhase.rawValue],
              let baseFrequency = created[ParameterAddress.baseFrequency.rawValue],
              let textureAmount = created[ParameterAddress.textureAmount.rawValue],
              let reverbMix = created[ParameterAddress.reverbMix.rawValue],
              let masterGain = created[ParameterAddress.masterGain.rawValue] else {
            throw NSError(domain: "com.echoelmusic.app.auv3", code: -2,
                          userInfo: [NSLocalizedDescriptionKey:
                                        "Parameter mapping does not cover addresses 0...7"])
        }
        coherenceParam = coherence
        hrvParam = hrv
        heartRateParam = heartRate
        breathPhaseParam = breathPhase
        baseFreqParam = baseFrequency
        textureAmountParam = textureAmount
        reverbMixParam = reverbMix
        masterGainParam = masterGain

        let bioGroup = AUParameterTree.createGroup(
            withIdentifier: "bio", name: "Bio-Reactive", children: bioChildren
        )
        let soundGroup = AUParameterTree.createGroup(
            withIdentifier: "sound", name: "Sound", children: soundChildren
        )

        _parameterTree = AUParameterTree.createTree(withChildren: [bioGroup, soundGroup])
        self.parameterTree = _parameterTree

        // NO implementorValueProvider (deliberately). Every parameter here is a CONTROL
        // input — host automation and the App-Group bio bridge write AUParameter.value
        // directly — NOT a DSP-owned value. The old provider read the values back FROM
        // the synth (coherence→harmonicity, hrv→brightness, breathPhase→amplitude), but
        // applyBioReactive MODULATES exactly those render-side, so the host read back
        // bio-modulated values and `fullState` captured a modulated snapshot that never
        // round-tripped (broken preset save/restore). Falling back to AUParameter's own
        // stored value fixes both host read-back AND state save-restore. The synth is
        // driven purely by the write path (implementorValueObserver + the render-side
        // bio mirrors) below, which is unchanged. Do NOT re-add a value provider.

        // Value observer — write to synth
        _parameterTree.implementorValueObserver = { [weak self] param, value in
            guard let self,
                  let addr = ParameterAddress(rawValue: param.address) else { return }
            switch addr {
            case .coherence, .hrv, .heartRate, .breathPhase:
                // Mirror the four bio params for the render thread; applyBioReactive now
                // runs RENDER-SIDE (see internalRenderBlock) so the synth's
                // harmonicAmplitudes array stays single-owner — no cross-thread COW race
                // and no audio-thread allocation. texture.coherence is a scalar
                // (atomic-width Float) — safe to set directly here. Its didSet replaces
                // `texture.rule`, which the render thread reads per cell; that is safe only
                // because `CARule` is ONE BYTE with no heap storage (overnight P8 — it used to
                // carry a [UInt8] table, released under a live render read).
                self.bioMirror.coherence = self.coherenceParam.value
                self.bioMirror.hrv = self.hrvParam.value
                self.bioMirror.heartRate = self.heartRateParam.value
                self.bioMirror.breathPhase = self.breathPhaseParam.value
                self.texture.coherence = self.coherenceParam.value
            case .baseFrequency, .textureAmount, .reverbMix:
                // WA3.2: the same three engine writes as before, now through the one shared
                // binding (`EchoelBodyVibeDevice.apply`) resolved at setup. Overnight P8: the
                // host's value passes `admitted` first — non-finite is refused (the engine keeps
                // what sounds), anything else is clamped to the descriptor's range.
                if let binding = self.engineBindingByAddress[param.address],
                   let id = self.canonicalIDByAddress[param.address],
                   let admitted = EchoelBodyVibeDevice.admitted(value, forCreativeID: id) {
                    EchoelBodyVibeDevice.apply(binding, value: admitted,
                                               synth: self.synth, texture: self.texture)
                }
            case .masterGain:
                // Mirror for the render thread — through the same gate, or a NaN reaches the
                // host's bus (`(synth + texture) * gain` has no finite guard after it).
                if let id = self.canonicalIDByAddress[param.address],
                   let admitted = EchoelBodyVibeDevice.admitted(value, forCreativeID: id) {
                    self.gainMirror.value = admitted
                }
            }
        }
    }

    // MARK: - AUAudioUnit Overrides

    public override var inputBusses: AUAudioUnitBusArray {
        // Instrument — no audio input (MIDI drives pitch)
        AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [])
    }

    public override var outputBusses: AUAudioUnitBusArray { _outputBusArray }

    public override var canProcessInPlace: Bool { false }
    public override var supportsUserPresets: Bool { true }
    public override var latency: TimeInterval { 0 }
    /// The synth's release plus the reverb's decay (`EchoelBodyVibeDevice.tailSeconds`). Reads
    /// three scalars the render thread never writes. ⛔ Was a literal 2.0 — the release alone.
    public override var tailTime: TimeInterval {
        EchoelBodyVibeDevice.tailSeconds(synth: synth, reverb: reverb)
    }

    // MARK: - Presets

    /// WA3.2: the presets are creative state keyed by canonical ID
    /// (`EchoelBodyVibeDevice.factoryPresets`); numbers and names are unchanged.
    public override var factoryPresets: [AUAudioUnitPreset]? {
        EchoelBodyVibeDevice.factoryPresets.map { preset in
            let p = AUAudioUnitPreset()
            p.number = preset.number
            p.name = preset.name
            return p
        }
    }

    /// `AudioUnitParameterUnit` for the adapter's unit kind (AudioToolbox stays in the adapter).
    private static func auUnit(_ unit: AUv3ParameterEntry.Unit) -> AudioUnitParameterUnit {
        switch unit {
        case .generic: return .generic
        case .hertz: return .hertz
        case .linearGain: return .linearGain
        }
    }

    /// The render scratch buffers are 4096 frames, allocated once at `init` and never resized
    /// (allocating during render is banned). The render block used to clamp with
    /// `min(Int(frameCount), 4096)` and then write only `0..<count` — which silently left
    /// samples `4096..<frameCount` of every output buffer EXACTLY as the host handed them
    /// over: stale audio from a previous block, or uninitialised memory. And it returned
    /// `noErr` while doing it. That is not a glitch anyone would mistake for DSP; it is a
    /// loud periodic burst of garbage at the block boundary, in that host and that render
    /// mode only (an offline bounce is the realistic case — nothing in the simulator at 512
    /// frames would ever show it).
    ///
    /// `maximumFramesToRender` is the HOST's to set, so the defence belongs on the contract,
    /// not on the data: clamp what we promise to accept and the host allocates accordingly.
    /// Added 2026-09-20 (#1385, audio-thread-reviewer). The clamp inside the render block
    /// stays as a belt-and-braces bound — it is one `min` on scalars and costs nothing.
    ///
    /// ⚠️ Raising 4096 here is NOT one number: `RenderScratch` and `EchoelDDSP`'s
    /// `reverbFrameBuffer`/`reverbWetBuffer` (sized `max(frameSize, 4096)` in its init) must
    /// rise in lockstep, or the reverb silently skips oversized blocks — a bug that file
    /// records having already been fixed once, at 2048.
    public override var maximumFramesToRender: AUAudioFrameCount {
        get { min(super.maximumFramesToRender, 4096) }
        set { super.maximumFramesToRender = min(newValue, 4096) }
    }

    public override var currentPreset: AUAudioUnitPreset? {
        didSet {
            guard let p = currentPreset, p.number >= 0,
                  let preset = EchoelBodyVibeDevice.factoryPresets.first(
                      where: { $0.number == p.number }) else { return }
            for param in stateParameters {
                if let id = canonicalIDByAddress[param.address],
                   let value = preset.creativeValues[id] {
                    param.value = value
                }
            }
            // ⛔ HOLD-FOR-FOUNDER (WA3.2): a LIVE seed, not creative state — see
            // `EchoelBodyVibeDevice.Preset.legacyCoherenceSeed` for the measured dependency.
            if let seed = preset.legacyCoherenceSeed {
                coherenceParam.value = seed
            }
        }
    }

    // MARK: - State

    // ⭐ WA3.1 — RUNTIME BIO INPUT IS NOT SAVED PLUGIN STATE. The four bio parameters are
    // written live (App-Group bridge, host automation) and a host stores `fullState` in ITS
    // project file, which Echoel cannot erase. The getter used to save all eight; it now saves
    // the four creative ones and nothing else of the tree. The policy lives in
    // `AUv3StateContract` (Core/BioFeedbackManager.swift) so the blocking bundle can drive it.
    // Addresses, identifiers and tree order are unchanged; only what reaches a document moved.
    private var stateParameters: [AUParameter] {
        let all: [AUParameter?] = [coherenceParam, hrvParam, heartRateParam, breathPhaseParam,
                                   baseFreqParam, textureAmountParam, reverbMixParam,
                                   masterGainParam]
        return all.compactMap { $0 }
    }

    public override var fullState: [String: Any]? {
        get {
            var persisted: [String: Float] = [:]
            for p in stateParameters
            where AUv3StateContract.persistedParameterIdentifiers.contains(p.identifier) {
                persisted[p.identifier] = p.value
            }
            return AUv3StateContract.savedState(base: super.fullState, persistedValues: persisted)
        }
        set {
            // LEGACY READ-ONLY: a document from an older build carries bio values, explicitly
            // and inside the base class's parameter snapshot. Neither may become the plug-in's
            // state, so the live transient values are held across the base restore and put
            // back; a parameter in neither contract list counts as transient (fails closed).
            let transient = stateParameters.filter {
                !AUv3StateContract.persistedParameterIdentifiers.contains($0.identifier)
            }
            let live = transient.map { ($0, $0.value) }
            super.fullState = AUv3StateContract.stateForBaseRestore(newValue)
            for (p, v) in live where p.value != v { p.value = v }

            // fullState is host/preset-file controlled (third-party documents): the contract
            // rejects non-finite values and clamps to each param's range so a malformed preset
            // can't inject NaN/huge gain into the render block.
            var ranges: [String: ClosedRange<Float>] = [:]
            for p in stateParameters where p.minValue <= p.maxValue {
                ranges[p.identifier] = p.minValue...p.maxValue
            }
            let restored = AUv3StateContract.restorableValues(from: newValue, ranges: ranges)
            for p in stateParameters {
                if let v = restored[p.identifier] { p.value = v }
            }
        }
    }

    // MARK: - Rendering

    public override func allocateRenderResources() throws {
        try super.allocateRenderResources()

        // ⭐ THE HOST OWNS THE RATE (#1407, board A10). `init` declares the output bus at
        // 48 kHz because something has to be declared before a host has spoken — but the host
        // then WRITES `outputBus.format`, and an AUv3 renders straight into that bus with no
        // converter in between. Both engines were built at the 48 kHz literal and never asked
        // again, so in a 44.1 kHz session every partial came out multiplied by 44100/48000 =
        // 0.91875: roughly 1.47 semitones FLAT, with the LFO and the envelopes 8.8 % slow.
        //
        // ⚠️ IT SURVIVED THE FIRST DEVICE SESSION BECAUSE OF WHERE IT WAS MEASURED. #1386
        // loaded the plug-in in AUM at 48 kHz — the one rate at which the defect is invisible
        // — and read 220.15 Hz against a 220 Hz default. A matching rate proves the signal
        // path, not the rate path.
        //
        // ⚠️ THIS IS THE ONLY LEGAL MOMENT. The engine setters mutate in place (never reseating a
        // reference the render block holds — the ARC-reseat law lives at
        // `EchoelDDSP.updateReverbDecay`), and Apple guarantees no render is in flight between
        // `allocateRenderResources` and the first callback. It runs BEFORE `noteOn` so the
        // idle tone starts at the right pitch rather than sliding into it, and before
        // `internalRenderBlock` is fetched, so the `bioInterval` derived there
        // (`synth.sampleRate / 10`) is the host's rate too.
        //
        // ⚠️ NOT PROPAGATED TO THE MAIN APP, DELIBERATELY. Its voices feed `AVAudioSourceNode`s
        // that DECLARE 48 kHz, and `AVAudioEngine` converts to the hardware rate on their
        // behalf. Calling a setter there would break that contract instead of honouring it.
        let hostRate = Float(outputBus.format.sampleRate)
        synth.setSampleRate(hostRate)
        texture.setSampleRate(hostRate)
        // The reverb follows too (2026-09-24). Unlike the two above it REBUILDS its tanks, so it
        // allocates — legal here and nowhere later. It also empties them.
        reverb.setSampleRate(hostRate)

        // ⭐ WA3.3 + P2 (2026-09-24): EVERY creative engine field starts at the HOST value —
        // pitch, texture, the reverb anchor (the synth's own default is 0.25, the parameter's
        // 0.3) and the output gain — through the one shared seeding path. WA3.3 seeded the
        // reverb alone; texture and gain then played their construction values until a host
        // moved them. The tank starts empty, not with a previous session's tail. Both run
        // here, before render starts.
        var creativeValues: [String: Float] = [:]
        for param in stateParameters {
            if let id = canonicalIDByAddress[param.address] { creativeValues[id] = param.value }
        }
        gainMirror.value = EchoelBodyVibeDevice.seed(creativeValues, synth: synth, texture: texture)
        reverb.reset()

        // Start generating
        synth.amplitude = 0.6
        // ⛔ 2026-09-24 (overnight P8h): this read `noteOn(frequency: baseFreqParam.value)` —
        // the RAW parameter, two lines after `seed` had written the ADMITTED one. An
        // `AUParameter` keeps whatever a host or a restored blob wrote even when the observer
        // refuses it, so a NaN here poisoned `smoothedFreq` and every partial phase for the
        // life of the instance (the render's finite guard then zeroes the synth; no later
        // MIDI note recovers it). The argument-less `noteOn()` plays `synth.frequency`, which
        // `seed` set from `ParameterDescriptor.admitted` or the default.
        // Guard: `TheHostValueIsAdmittedOnceTests` claim 5.
        synth.noteOn()
        isNoteOn = true
        startVitalsPolling()
        os_log(.info, log: Self.auLog, "Instrument started: %.0f Hz at %.0f Hz host rate",
               synth.frequency, Double(synth.sampleRate))
    }

    public override func deallocateRenderResources() {
        super.deallocateRenderResources()
        vitalsTimer?.cancel()
        vitalsTimer = nil
        if isNoteOn { synth.noteOff(); isNoteOn = false }
        os_log(.info, log: Self.auLog, "Instrument stopped")
    }

    // MARK: - Shared vitals (App Group → bio params)

    /// Starts a 10 Hz utility-queue timer (NOT the render thread) that reads the
    /// latest vitals shared by the main app and pushes them into the bio params.
    /// 10 Hz matches the app's publish tick so breath phase moves like a live
    /// signal; the per-frame timestamp dedupe below keeps actual param writes
    /// at the source frame rate. UserDefaults reads are cfprefsd-cached — this
    /// stays control-plane cheap.
    private func startVitalsPolling() {
        // Cancel any timer still installed. A host MAY call allocateRenderResources() twice
        // without an intervening deallocate; overwriting `vitalsTimer` would then release a
        // RESUMED, UN-CANCELLED DispatchSource, and libdispatch does not leak that — it traps
        // ("BUG IN CLIENT OF LIBDISPATCH: Release of a source that has not been cancelled"),
        // i.e. a hard crash inside someone else's DAW. One line, added 2026-09-20 (#1385).
        vitalsTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(
            queue: DispatchQueue(label: "com.echoelmusic.app.auv3.vitals", qos: .utility)
        )
        timer.schedule(deadline: .now() + 0.1, repeating: 0.1)
        timer.setEventHandler { [weak self] in self?.pullSharedVitals() }
        timer.resume()
        vitalsTimer = timer
    }

    /// Folds the latest App-Group vitals into the bio params; the existing
    /// param observer applies them to the synth. Runs off the render thread.
    ///
    /// Guard chain (any failure leaves the params EXACTLY as the host set them —
    /// live bridge and host automation share the same `AUParameter.value` path):
    ///   1. decodes + all-finite (BioFeedbackManager rejects NaN/∞ payloads),
    ///   2. `egressAllowed` — 5.1.3: HealthKit-store frames must never surface
    ///      in host-visible params; only Echoel's own measurements pass,
    ///   3. fresh (< ~2 s on the shared reference-date clock) — a quit/crashed
    ///      main app stops steering within 2 s instead of freezing the params
    ///      on the last value forever,
    ///   4. new timestamp — an unchanged store never re-fires the observer.
    private func pullSharedVitals() {
        guard let vitals = bioFeedback.refreshFromSharedStore(),
              vitals.egressAllowed,
              vitals.isFresh(within: Self.vitalsMaxAge),
              vitals.timestamp != lastVitalsTimestamp else { return }
        lastVitalsTimestamp = vitals.timestamp
        coherenceParam.value = min(max(vitals.coherence, 0), 1)
        hrvParam.value = min(max(vitals.hrvNormalized, 0), 1)
        heartRateParam.value = max(0, min(1, (vitals.heartRateBPM - 40) / 160))
        breathPhaseParam.value = min(max(vitals.breathPhase, 0), 1)
    }

    public override var internalRenderBlock: AUInternalRenderBlock {
        let synthRef = self.synth
        let textureRef = self.texture
        let gainBox = self.gainMirror
        let scratch = self.renderScratch
        let bioBox = self.bioMirror
        let bioState = self.bioRenderState
        let noteState = self.renderNoteState
        let reverbRef = self.reverb
        // ~10 Hz throttle for the render-side bio application (sampleRate/10 frames).
        let bioInterval = max(1, Int(self.synth.sampleRate / 10))

        return { (actionFlags, timestamp, frameCount, outputBusNumber,
                  outputData, renderEvent, pullInputBlock) in

            let count = min(Int(frameCount), 4096)

            // MIDI note input (music-device / aumu). Walk the host's realtime event
            // list and drive the mono voice's pitch. This is pure pointer + scalar
            // work plus EchoelDDSP.noteOn/noteOff (both scalar-assignment only) — no
            // allocation, no lock, no ObjC, no GCD: audio-thread safe. Block-granular
            // (all events applied before the block renders); the last note-on in the
            // block wins for a mono voice, and last-note priority means a note-off only
            // silences the voice when it releases the note that is actually sounding (so
            // releasing a still-held earlier note no longer cuts the current one). With
            // NO note event, nothing changes and the free-running bio tone armed in
            // allocateRenderResources keeps playing.
            // Only legacy AUMIDIEvent (.MIDI) is handled — correct for the default
            // MIDI-1.0 protocol, where hosts translate to legacy events. A future host
            // negotiating MIDI-2.0 UMP would deliver .MIDIEventList instead (add a
            // branch here if that is ever adopted).
            var event: UnsafePointer<AURenderEvent>? = renderEvent
            while let e = event {
                let header = e.pointee.head
                if header.eventType == .MIDI {
                    let midi = e.pointee.MIDI
                    if midi.length >= 3 {
                        switch EchoelMIDIDecode.action(status: midi.data.0,
                                                       data1: midi.data.1,
                                                       data2: midi.data.2) {
                        case let .noteOn(frequency, velocity):
                            synthRef.noteVelocity = velocity
                            synthRef.noteOn(frequency: frequency)
                            noteState.current = Int32(midi.data.1)   // now the sounding note
                        case .noteOff:
                            // Last-note priority: only release the voice if this note-off
                            // is for the note that is actually sounding.
                            if Int32(midi.data.1) == noteState.current {
                                synthRef.noteOff()
                                noteState.current = -1
                            }
                        case .panic:
                            // Host All Sound/Notes Off — force-release regardless of note.
                            synthRef.noteOff()
                            noteState.current = -1
                        case .ignore:
                            break
                        }
                    }
                }
                // `AURenderEventHeader.next` imports as an UnsafeMutablePointer while the
                // list head is a const UnsafePointer — convert so the walk stays const.
                event = header.next.map { UnsafePointer($0) }
            }

            // Apply bio params RENDER-SIDE (throttled ~10 Hz) from the atomic mirrors —
            // never read AUParameter here. Running applyBioReactive on the render thread
            // keeps the synth's harmonicAmplitudes array single-owner: no cross-thread
            // COW race, and its in-place rewrite triggers no allocation. See BioMirror.
            bioState.frameAccum += count
            if bioState.frameAccum >= bioInterval {
                bioState.frameAccum = 0
                synthRef.applyBioReactive(coherence: bioBox.coherence,
                                          hrvVariability: bioBox.hrv,
                                          heartRate: bioBox.heartRate,
                                          breathPhase: bioBox.breathPhase)
            }

            // Render each voice into the block's SOLE-OWNED scratch. RenderScratch holds the
            // ONLY reference to each array, so `&scratch.pad` mutates IN PLACE — no copy-on-write,
            // no audio-thread allocation. (The old `var pad = padRef` aliased a buffer still held
            // by both self and the capture, COW-copying ~32 KB per callback.) Both EchoelDDSP.render
            // and EchoelCellular.render OVERWRITE [0..<count] — the exact region mixed below — so the
            // previous defensive zero-fill was redundant and is dropped.
            synthRef.render(buffer: &scratch.pad, frameCount: count)
            textureRef.render(buffer: &scratch.tex, frameCount: count)

            // WA3.3 — the synth through the reverb, wet by its EFFECTIVE mix (host anchor plus
            // bounded bio offset). In place, sole-owned scratch, no allocation.
            scratch.pad.withUnsafeMutableBufferPointer { left in
                scratch.padR.withUnsafeMutableBufferPointer { right in
                    EchoelBodyVibeDevice.renderSpace(reverbRef, synth: synthRef,
                                                     left: left, right: right, count: count)
                }
            }

            // Mix and apply master gain (lock-free mirror — never read AUParameter here). Bind the
            // scratch to unsafe buffer pointers so the per-sample loop takes no per-element ARC on
            // the class-held arrays.
            let gain = gainBox.value
            let ablPointer = UnsafeMutableAudioBufferListPointer(outputData)
            let mono = ablPointer.count == 1
            scratch.pad.withUnsafeBufferPointer { padBuf in
                scratch.padR.withUnsafeBufferPointer { padRBuf in
                    scratch.tex.withUnsafeBufferPointer { texBuf in
                        for channel in 0..<ablPointer.count {
                            // A null pointer is the host asking the AU for its own memory
                            // (AURenderBlock contract, see `RenderScratch.ownedOutput`).
                            // Pointer and size stores only — no allocation here.
                            if ablPointer[channel].mData == nil, channel < RenderScratch.ownedChannels {
                                ablPointer[channel].mData = UnsafeMutableRawPointer(
                                    scratch.ownedOutput + channel * scratch.capacity)
                            }
                            guard let data = ablPointer[channel].mData?.assumingMemoryBound(to: Float.self) else { continue }
                            ablPointer[channel].mDataByteSize = UInt32(count * MemoryLayout<Float>.size)
                            for i in 0..<count {
                                // Channel 0 = the reverb's left, every other = its right; a
                                // mono bus gets their mean. At mix 0 all three equal the dry
                                // synth, which is the pre-WA3.3 output exactly.
                                let synthSample = mono ? (padBuf[i] + padRBuf[i]) * 0.5
                                                       : (channel == 0 ? padBuf[i] : padRBuf[i])
                                data[i] = (synthSample + texBuf[i]) * gain
                            }
                        }
                    }
                }
            }

            return noErr
        }
    }
}
#endif
