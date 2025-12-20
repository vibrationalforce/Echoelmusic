import Foundation
import AVFoundation
import Combine

// ═══════════════════════════════════════════════════════════════════════════════
// MODULAR FX RACK - BEAM-STYLE FLEXIBLE EFFECT ROUTING
// ═══════════════════════════════════════════════════════════════════════════════
//
// Inspired by Lunacy Audio's "BEAM":
// • Modular effect slots with drag-and-drop
// • Parallel & serial routing modes
// • Macro controls that map to multiple parameters
// • LFO/Envelope modulation matrix
// • Bio-reactive modulation sources
// • Preset morphing between configurations
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - FX Slot

/// A slot in the FX rack that holds an effect
struct FXSlot: Identifiable {
    let id: UUID
    var effect: BaseEchoelmusicNode?
    var isEnabled: Bool = true
    var wetDry: Float = 100.0  // 0-100%
    var position: Int  // Order in the chain

    // Parallel processing
    var parallelGroupID: UUID?  // If set, processes in parallel with others in same group
    var parallelMix: Float = 100.0  // Mix level within parallel group

    var isEmpty: Bool { effect == nil }

    init(position: Int) {
        self.id = UUID()
        self.position = position
    }
}

// MARK: - Routing Mode

enum FXRoutingMode: String, CaseIterable {
    case serial = "Serial"           // A → B → C → D
    case parallel = "Parallel"       // (A + B + C + D)
    case splitMerge = "Split/Merge"  // A → (B ‖ C) → D
    case dualPath = "Dual Path"      // (A → B) + (C → D)

    var description: String {
        switch self {
        case .serial: return "Effects in series, one after another"
        case .parallel: return "All effects process in parallel, then mix"
        case .splitMerge: return "Split to parallel, then merge back"
        case .dualPath: return "Two independent parallel chains"
        }
    }
}

// MARK: - Macro Control

/// A macro that controls multiple effect parameters
struct MacroControl: Identifiable {
    let id: UUID
    var name: String
    var value: Float = 0.0  // 0-100
    var mappings: [MacroMapping] = []
    var color: MacroColor = .blue

    struct MacroMapping: Identifiable {
        let id: UUID
        var targetSlotID: UUID
        var targetParameterName: String
        var minValue: Float
        var maxValue: Float
        var curve: MappingCurve = .linear

        enum MappingCurve: String, CaseIterable {
            case linear, exponential, logarithmic, sCurve, inverted

            func apply(_ input: Float) -> Float {
                switch self {
                case .linear: return input
                case .exponential: return pow(input, 2)
                case .logarithmic: return sqrt(input)
                case .sCurve: return input * input * (3 - 2 * input)
                case .inverted: return 1.0 - input
                }
            }
        }

        init(slotID: UUID, parameter: String, min: Float, max: Float) {
            self.id = UUID()
            self.targetSlotID = slotID
            self.targetParameterName = parameter
            self.minValue = min
            self.maxValue = max
        }
    }

    enum MacroColor: String, CaseIterable {
        case red, orange, yellow, green, cyan, blue, purple, pink
    }

    init(name: String) {
        self.id = UUID()
        self.name = name
    }
}

// MARK: - Modulation Source

/// Modulation source for parameter animation
enum ModulationSource: Identifiable {
    case lfo(LFOModulator)
    case envelope(EnvelopeModulator)
    case bio(BioModulator)
    case random(RandomModulator)

    var id: UUID {
        switch self {
        case .lfo(let m): return m.id
        case .envelope(let m): return m.id
        case .bio(let m): return m.id
        case .random(let m): return m.id
        }
    }

    var name: String {
        switch self {
        case .lfo(let m): return "LFO \(m.waveform.rawValue)"
        case .envelope: return "Envelope"
        case .bio(let m): return "Bio: \(m.source.rawValue)"
        case .random(let m): return "Random \(m.style.rawValue)"
        }
    }

    func getValue(at time: Double) -> Float {
        switch self {
        case .lfo(let m): return m.getValue(at: time)
        case .envelope(let m): return m.getValue(at: time)
        case .bio(let m): return m.getValue()
        case .random(let m): return m.getValue(at: time)
        }
    }
}

// MARK: - LFO Modulator

struct LFOModulator: Identifiable {
    let id = UUID()
    var rate: Float = 1.0  // Hz
    var depth: Float = 1.0  // 0-1
    var waveform: Waveform = .sine
    var phase: Float = 0.0  // 0-1

    enum Waveform: String, CaseIterable {
        case sine, triangle, square, saw, random

        func generate(phase: Float) -> Float {
            switch self {
            case .sine: return sin(phase * Float.pi * 2)
            case .triangle: return abs(fmod(phase * 4, 4) - 2) - 1
            case .square: return phase < 0.5 ? 1 : -1
            case .saw: return fmod(phase * 2, 2) - 1
            case .random: return Float.random(in: -1...1)
            }
        }
    }

    func getValue(at time: Double) -> Float {
        let currentPhase = fmod(Float(time) * rate + phase, 1.0)
        return waveform.generate(phase: currentPhase) * depth
    }
}

// MARK: - Envelope Modulator

struct EnvelopeModulator: Identifiable {
    let id = UUID()
    var attack: Float = 0.1   // seconds
    var decay: Float = 0.2    // seconds
    var sustain: Float = 0.7  // 0-1 level
    var release: Float = 0.5  // seconds

    private var startTime: Double = 0
    private var releaseTime: Double = 0
    private var isReleasing = false

    mutating func trigger() {
        startTime = Date().timeIntervalSinceReferenceDate
        isReleasing = false
    }

    mutating func triggerRelease() {
        releaseTime = Date().timeIntervalSinceReferenceDate
        isReleasing = true
    }

    func getValue(at time: Double) -> Float {
        let elapsed = Float(time - startTime)

        if isReleasing {
            let releaseElapsed = Float(time - releaseTime)
            let releaseProgress = min(releaseElapsed / release, 1.0)
            return sustain * (1.0 - releaseProgress)
        }

        // Attack phase
        if elapsed < attack {
            return elapsed / attack
        }

        // Decay phase
        let decayStart = elapsed - attack
        if decayStart < decay {
            let decayProgress = decayStart / decay
            return 1.0 - (1.0 - sustain) * decayProgress
        }

        // Sustain phase
        return sustain
    }
}

// MARK: - Bio Modulator

struct BioModulator: Identifiable {
    let id = UUID()
    var source: BioSource = .coherence
    var smoothing: Float = 0.9  // 0-1 (higher = smoother)
    var invert: Bool = false

    private var currentValue: Float = 0.5
    private var targetValue: Float = 0.5

    enum BioSource: String, CaseIterable {
        case heartRate = "Heart Rate"
        case hrv = "HRV"
        case coherence = "Coherence"
        case energy = "Energy"
        case breathRate = "Breath Rate"
        case stress = "Stress"

        func extract(from signal: BioSignal) -> Float {
            switch self {
            case .heartRate: return min(signal.heartRate / 180.0, 1.0)
            case .hrv: return min(signal.hrv / 100.0, 1.0)
            case .coherence: return signal.coherence / 100.0
            case .energy: return signal.energy
            case .breathRate: return min(signal.breathRate / 30.0, 1.0)
            case .stress: return 1.0 - signal.coherence / 100.0
            }
        }
    }

    mutating func update(from signal: BioSignal) {
        targetValue = source.extract(from: signal)
    }

    mutating func getValue() -> Float {
        // Smooth interpolation
        currentValue = currentValue * smoothing + targetValue * (1.0 - smoothing)
        return invert ? (1.0 - currentValue) : currentValue
    }
}

// MARK: - Random Modulator

struct RandomModulator: Identifiable {
    let id = UUID()
    var rate: Float = 0.5  // Changes per second
    var smoothing: Float = 0.8
    var style: Style = .smooth

    private var currentValue: Float = 0.5
    private var targetValue: Float = 0.5
    private var lastChangeTime: Double = 0

    enum Style: String, CaseIterable {
        case stepped = "Stepped"
        case smooth = "Smooth"
        case binary = "Binary"
    }

    mutating func getValue(at time: Double) -> Float {
        // Check if we should generate a new target
        if time - lastChangeTime > Double(1.0 / rate) {
            lastChangeTime = time
            switch style {
            case .stepped:
                targetValue = Float.random(in: 0...1)
            case .smooth:
                targetValue = Float.random(in: 0...1)
            case .binary:
                targetValue = Bool.random() ? 1.0 : 0.0
            }
        }

        // Smooth or step
        if style == .stepped || style == .binary {
            currentValue = targetValue
        } else {
            currentValue = currentValue * smoothing + targetValue * (1.0 - smoothing)
        }

        return currentValue
    }
}

// MARK: - Modulation Routing

struct ModulationRouting: Identifiable {
    let id = UUID()
    var sourceID: UUID  // ModulationSource ID
    var targetSlotID: UUID
    var targetParameterName: String
    var amount: Float = 50.0  // 0-100
    var bipolar: Bool = true  // If false, 0-1 range; if true, -1 to 1

    func apply(modulationValue: Float, to currentValue: Float, paramMin: Float, paramMax: Float) -> Float {
        let range = paramMax - paramMin
        let normalizedMod = bipolar ? modulationValue : (modulationValue + 1.0) / 2.0
        let modAmount = normalizedMod * (amount / 100.0) * range
        return max(paramMin, min(paramMax, currentValue + modAmount))
    }
}

// MARK: - Modular FX Rack

@MainActor
class ModularFXRack: ObservableObject {

    // MARK: - Published State

    /// Effect slots (max 8)
    @Published var slots: [FXSlot] = []

    /// Current routing mode
    @Published var routingMode: FXRoutingMode = .serial

    /// Macro controls (max 8)
    @Published var macros: [MacroControl] = []

    /// Modulation sources
    @Published var modulationSources: [ModulationSource] = []

    /// Modulation routings
    @Published var modulationRoutings: [ModulationRouting] = []

    /// Master wet/dry
    @Published var masterWetDry: Float = 100.0

    /// Master output gain
    @Published var masterGain: Float = 1.0

    /// Is processing active
    @Published var isProcessing: Bool = false

    // MARK: - Configuration

    let maxSlots = 8
    let maxMacros = 8

    // MARK: - Private State

    private var sampleRate: Double = 44100.0
    private var cancellables = Set<AnyCancellable>()
    private var modulationTimer: Timer?
    private var currentBioSignal = BioSignal()

    // MARK: - Initialization

    init() {
        setupDefaultSlots()
        setupDefaultMacros()
        startModulationEngine()
    }

    deinit {
        modulationTimer?.invalidate()
    }

    // MARK: - Setup

    private func setupDefaultSlots() {
        slots = (0..<maxSlots).map { FXSlot(position: $0) }
    }

    private func setupDefaultMacros() {
        macros = [
            MacroControl(name: "Intensity"),
            MacroControl(name: "Depth"),
            MacroControl(name: "Speed"),
            MacroControl(name: "Character")
        ]
        macros[0].color = .orange
        macros[1].color = .cyan
        macros[2].color = .green
        macros[3].color = .purple
    }

    // MARK: - Slot Management

    /// Add effect to a slot
    func addEffect(_ effect: BaseEchoelmusicNode, to slotIndex: Int) {
        guard slotIndex >= 0 && slotIndex < slots.count else { return }
        slots[slotIndex].effect = effect
        print("🎛️ Added \(effect.name) to slot \(slotIndex + 1)")
    }

    /// Remove effect from slot
    func removeEffect(from slotIndex: Int) {
        guard slotIndex >= 0 && slotIndex < slots.count else { return }
        slots[slotIndex].effect = nil
    }

    /// Swap two slots
    func swapSlots(_ indexA: Int, _ indexB: Int) {
        guard indexA >= 0 && indexA < slots.count,
              indexB >= 0 && indexB < slots.count else { return }

        let tempEffect = slots[indexA].effect
        slots[indexA].effect = slots[indexB].effect
        slots[indexB].effect = tempEffect
    }

    /// Set slot enabled state
    func setSlotEnabled(_ slotIndex: Int, enabled: Bool) {
        guard slotIndex >= 0 && slotIndex < slots.count else { return }
        slots[slotIndex].isEnabled = enabled
    }

    /// Set slot wet/dry mix
    func setSlotWetDry(_ slotIndex: Int, wetDry: Float) {
        guard slotIndex >= 0 && slotIndex < slots.count else { return }
        slots[slotIndex].wetDry = max(0, min(100, wetDry))
    }

    // MARK: - Macro Management

    /// Add mapping to macro
    func addMacroMapping(_ macroIndex: Int, slotID: UUID, parameter: String, min: Float, max: Float) {
        guard macroIndex >= 0 && macroIndex < macros.count else { return }

        let mapping = MacroControl.MacroMapping(
            slotID: slotID,
            parameter: parameter,
            min: min,
            max: max
        )

        macros[macroIndex].mappings.append(mapping)
    }

    /// Set macro value
    func setMacroValue(_ macroIndex: Int, value: Float) {
        guard macroIndex >= 0 && macroIndex < macros.count else { return }

        macros[macroIndex].value = max(0, min(100, value))

        // Apply to all mapped parameters
        applyMacroMappings(macroIndex)
    }

    /// Apply macro to all mapped parameters
    private func applyMacroMappings(_ macroIndex: Int) {
        let macro = macros[macroIndex]
        let normalizedValue = macro.value / 100.0

        for mapping in macro.mappings {
            guard let slotIndex = slots.firstIndex(where: { $0.id == mapping.targetSlotID }),
                  let effect = slots[slotIndex].effect else { continue }

            let curvedValue = mapping.curve.apply(normalizedValue)
            let paramValue = mapping.minValue + curvedValue * (mapping.maxValue - mapping.minValue)
            effect.setParameter(name: mapping.targetParameterName, value: paramValue)
        }
    }

    // MARK: - Modulation

    /// Add modulation source
    func addLFO(rate: Float = 1.0, waveform: LFOModulator.Waveform = .sine) -> UUID {
        var lfo = LFOModulator()
        lfo.rate = rate
        lfo.waveform = waveform
        let source = ModulationSource.lfo(lfo)
        modulationSources.append(source)
        return source.id
    }

    /// Add bio modulator
    func addBioModulator(source: BioModulator.BioSource) -> UUID {
        var bioMod = BioModulator()
        bioMod.source = source
        let modSource = ModulationSource.bio(bioMod)
        modulationSources.append(modSource)
        return modSource.id
    }

    /// Add modulation routing
    func addModulationRouting(sourceID: UUID, targetSlotID: UUID, targetParameter: String, amount: Float) {
        let routing = ModulationRouting(
            sourceID: sourceID,
            targetSlotID: targetSlotID,
            targetParameterName: targetParameter,
            amount: amount
        )
        modulationRoutings.append(routing)
    }

    /// Start modulation engine
    private func startModulationEngine() {
        // 60 Hz modulation rate
        modulationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.processModulation()
            }
        }
    }

    /// Process all modulation routings
    private func processModulation() {
        let time = Date().timeIntervalSinceReferenceDate

        for routing in modulationRoutings {
            // Find source
            guard let sourceIndex = modulationSources.firstIndex(where: { $0.id == routing.sourceID }) else { continue }

            // Get modulation value
            let modValue = modulationSources[sourceIndex].getValue(at: time)

            // Find target slot and parameter
            guard let slotIndex = slots.firstIndex(where: { $0.id == routing.targetSlotID }),
                  let effect = slots[slotIndex].effect,
                  let param = effect.parameters.first(where: { $0.name == routing.targetParameterName }) else { continue }

            // Apply modulation
            let newValue = routing.apply(
                modulationValue: modValue,
                to: param.value,
                paramMin: param.min,
                paramMax: param.max
            )

            effect.setParameter(name: routing.targetParameterName, value: newValue)
        }
    }

    // MARK: - Audio Processing

    /// Process audio buffer through the rack
    func process(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) -> AVAudioPCMBuffer {
        guard isProcessing else { return buffer }

        let activeSlots = slots.filter { $0.isEnabled && $0.effect != nil }
        guard !activeSlots.isEmpty else { return buffer }

        switch routingMode {
        case .serial:
            return processSerial(buffer, time: time, slots: activeSlots)
        case .parallel:
            return processParallel(buffer, time: time, slots: activeSlots)
        case .splitMerge:
            return processSplitMerge(buffer, time: time, slots: activeSlots)
        case .dualPath:
            return processDualPath(buffer, time: time, slots: activeSlots)
        }
    }

    /// Serial processing: A → B → C → D
    private func processSerial(_ buffer: AVAudioPCMBuffer, time: AVAudioTime, slots: [FXSlot]) -> AVAudioPCMBuffer {
        var currentBuffer = buffer

        for slot in slots.sorted(by: { $0.position < $1.position }) {
            guard let effect = slot.effect else { continue }

            let dryBuffer = currentBuffer
            let wetBuffer = effect.process(currentBuffer, time: time)

            // Apply slot wet/dry
            currentBuffer = mixBuffers(dry: dryBuffer, wet: wetBuffer, wetAmount: slot.wetDry / 100.0)
        }

        return currentBuffer
    }

    /// Parallel processing: (A + B + C + D) mixed together
    private func processParallel(_ buffer: AVAudioPCMBuffer, time: AVAudioTime, slots: [FXSlot]) -> AVAudioPCMBuffer {
        guard let format = buffer.format.settings["AVLinearPCMBitDepthKey"] != nil ? buffer.format : nil,
              let mixBuffer = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameCapacity) else {
            return buffer
        }
        mixBuffer.frameLength = buffer.frameLength

        // Clear mix buffer
        if let mixData = mixBuffer.floatChannelData {
            for ch in 0..<Int(buffer.format.channelCount) {
                memset(mixData[ch], 0, Int(buffer.frameLength) * MemoryLayout<Float>.size)
            }
        }

        // Process each slot and sum
        for slot in slots {
            guard let effect = slot.effect else { continue }

            let processed = effect.process(buffer, time: time)
            let slotGain = (slot.wetDry / 100.0) / Float(slots.count)

            addBuffers(source: processed, to: mixBuffer, gain: slotGain)
        }

        return mixBuffer
    }

    /// Split/Merge: First slot serial, middle parallel, last serial
    private func processSplitMerge(_ buffer: AVAudioPCMBuffer, time: AVAudioTime, slots: [FXSlot]) -> AVAudioPCMBuffer {
        let sorted = slots.sorted(by: { $0.position < $1.position })

        guard sorted.count >= 2 else {
            return processSerial(buffer, time: time, slots: slots)
        }

        // First slot (pre-parallel)
        var currentBuffer = buffer
        if let firstEffect = sorted.first?.effect {
            currentBuffer = firstEffect.process(currentBuffer, time: time)
        }

        // Middle slots (parallel)
        if sorted.count > 2 {
            let middleSlots = Array(sorted[1..<sorted.count-1])
            currentBuffer = processParallel(currentBuffer, time: time, slots: middleSlots)
        }

        // Last slot (post-parallel)
        if let lastEffect = sorted.last?.effect, sorted.count > 1 {
            currentBuffer = lastEffect.process(currentBuffer, time: time)
        }

        return currentBuffer
    }

    /// Dual path: (A → B) + (C → D)
    private func processDualPath(_ buffer: AVAudioPCMBuffer, time: AVAudioTime, slots: [FXSlot]) -> AVAudioPCMBuffer {
        let sorted = slots.sorted(by: { $0.position < $1.position })
        let midPoint = sorted.count / 2

        let pathA = Array(sorted.prefix(midPoint))
        let pathB = Array(sorted.suffix(from: midPoint))

        let processedA = processSerial(buffer, time: time, slots: pathA)
        let processedB = processSerial(buffer, time: time, slots: pathB)

        return mixBuffers(dry: processedA, wet: processedB, wetAmount: 0.5)
    }

    // MARK: - Buffer Utilities

    private func mixBuffers(dry: AVAudioPCMBuffer, wet: AVAudioPCMBuffer, wetAmount: Float) -> AVAudioPCMBuffer {
        guard let dryData = dry.floatChannelData,
              let wetData = wet.floatChannelData else { return dry }

        let dryAmount = 1.0 - wetAmount
        let frameCount = Int(min(dry.frameLength, wet.frameLength))

        for ch in 0..<Int(dry.format.channelCount) {
            for i in 0..<frameCount {
                dryData[ch][i] = dryData[ch][i] * dryAmount + wetData[ch][i] * wetAmount
            }
        }

        return dry
    }

    private func addBuffers(source: AVAudioPCMBuffer, to destination: AVAudioPCMBuffer, gain: Float) {
        guard let srcData = source.floatChannelData,
              let dstData = destination.floatChannelData else { return }

        let frameCount = Int(min(source.frameLength, destination.frameLength))

        for ch in 0..<Int(min(source.format.channelCount, destination.format.channelCount)) {
            for i in 0..<frameCount {
                dstData[ch][i] += srcData[ch][i] * gain
            }
        }
    }

    // MARK: - Bio-Reactivity

    /// Update with bio signal
    func updateBioSignal(_ signal: BioSignal) {
        currentBioSignal = signal

        // Update all bio modulators
        for i in 0..<modulationSources.count {
            if case .bio(var bioMod) = modulationSources[i] {
                bioMod.update(from: signal)
                modulationSources[i] = .bio(bioMod)
            }
        }

        // Update all effects
        for slot in slots {
            slot.effect?.react(to: signal)
        }
    }

    // MARK: - Lifecycle

    func prepare(sampleRate: Double, maxFrames: AVAudioFrameCount) {
        self.sampleRate = sampleRate

        for slot in slots {
            slot.effect?.prepare(sampleRate: sampleRate, maxFrames: maxFrames)
        }
    }

    func start() {
        for slot in slots {
            slot.effect?.start()
        }
        isProcessing = true
        print("🎛️ ModularFXRack started with \(slots.filter { !$0.isEmpty }.count) effects")
    }

    func stop() {
        for slot in slots {
            slot.effect?.stop()
        }
        isProcessing = false
        print("🎛️ ModularFXRack stopped")
    }

    // MARK: - Preset Management

    /// Save current rack configuration
    func savePreset(name: String) -> RackPreset {
        RackPreset(
            name: name,
            routingMode: routingMode,
            slots: slots.map { slot in
                RackPreset.SlotConfig(
                    position: slot.position,
                    effectType: slot.effect?.type.rawValue,
                    effectName: slot.effect?.name,
                    isEnabled: slot.isEnabled,
                    wetDry: slot.wetDry,
                    parameters: slot.effect?.parameters.map {
                        ($0.name, $0.value)
                    } ?? []
                )
            },
            macros: macros.map { macro in
                RackPreset.MacroConfig(
                    name: macro.name,
                    value: macro.value,
                    mappings: macro.mappings.map { mapping in
                        RackPreset.MacroMappingConfig(
                            targetParameter: mapping.targetParameterName,
                            minValue: mapping.minValue,
                            maxValue: mapping.maxValue
                        )
                    }
                )
            },
            masterWetDry: masterWetDry,
            masterGain: masterGain
        )
    }

    /// Morph between two presets
    func morphPresets(from presetA: RackPreset, to presetB: RackPreset, amount: Float) {
        // Morph macro values
        for (i, macroA) in presetA.macros.enumerated() {
            guard i < presetB.macros.count && i < macros.count else { continue }
            let macroB = presetB.macros[i]
            macros[i].value = macroA.value * (1 - amount) + macroB.value * amount
            applyMacroMappings(i)
        }

        // Morph master values
        masterWetDry = presetA.masterWetDry * (1 - amount) + presetB.masterWetDry * amount
        masterGain = presetA.masterGain * (1 - amount) + presetB.masterGain * amount
    }
}

// MARK: - Rack Preset

struct RackPreset: Codable, Identifiable {
    let id: UUID
    let name: String
    let createdAt: Date
    let routingMode: FXRoutingMode
    let slots: [SlotConfig]
    let macros: [MacroConfig]
    let masterWetDry: Float
    let masterGain: Float

    struct SlotConfig: Codable {
        let position: Int
        let effectType: String?
        let effectName: String?
        let isEnabled: Bool
        let wetDry: Float
        let parameters: [(String, Float)]

        enum CodingKeys: String, CodingKey {
            case position, effectType, effectName, isEnabled, wetDry, parameters
        }

        init(position: Int, effectType: String?, effectName: String?, isEnabled: Bool, wetDry: Float, parameters: [(String, Float)]) {
            self.position = position
            self.effectType = effectType
            self.effectName = effectName
            self.isEnabled = isEnabled
            self.wetDry = wetDry
            self.parameters = parameters
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            position = try container.decode(Int.self, forKey: .position)
            effectType = try container.decodeIfPresent(String.self, forKey: .effectType)
            effectName = try container.decodeIfPresent(String.self, forKey: .effectName)
            isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
            wetDry = try container.decode(Float.self, forKey: .wetDry)

            // Decode parameters as array of dictionaries
            if let paramArray = try? container.decode([[String: Float]].self, forKey: .parameters) {
                parameters = paramArray.compactMap { dict in
                    guard let key = dict.keys.first, let value = dict[key] else { return nil }
                    return (key, value)
                }
            } else {
                parameters = []
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(position, forKey: .position)
            try container.encodeIfPresent(effectType, forKey: .effectType)
            try container.encodeIfPresent(effectName, forKey: .effectName)
            try container.encode(isEnabled, forKey: .isEnabled)
            try container.encode(wetDry, forKey: .wetDry)

            let paramDicts = parameters.map { [$0.0: $0.1] }
            try container.encode(paramDicts, forKey: .parameters)
        }
    }

    struct MacroConfig: Codable {
        let name: String
        let value: Float
        let mappings: [MacroMappingConfig]
    }

    struct MacroMappingConfig: Codable {
        let targetParameter: String
        let minValue: Float
        let maxValue: Float
    }

    init(name: String, routingMode: FXRoutingMode, slots: [SlotConfig], macros: [MacroConfig], masterWetDry: Float, masterGain: Float) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.routingMode = routingMode
        self.slots = slots
        self.macros = macros
        self.masterWetDry = masterWetDry
        self.masterGain = masterGain
    }
}

// MARK: - Codable Conformance

extension FXRoutingMode: Codable {}
