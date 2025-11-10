import Foundation
import AVFoundation
import Accelerate

/// Effect Chain Builder - USER creates their own effect chains
/// NO AI MAGIC - just professional audio effects that the user controls
///
/// The user builds their signal chain by:
/// 1. Choosing effects from the library
/// 2. Ordering them in series/parallel
/// 3. Adjusting every parameter precisely
/// 4. Saving their own presets
///
/// This is a TOOL for creativity, not an AI that makes decisions.
@MainActor
class EffectChainBuilder: ObservableObject {

    // MARK: - Published Properties

    @Published var chains: [EffectChain] = []
    @Published var effectLibrary: [EffectDescriptor] = []

    // MARK: - Effect Chain

    struct EffectChain: Identifiable, Codable {
        let id = UUID()
        var name: String
        var effects: [EffectInstance]
        var routing: RoutingMode
        var wetDryMix: Float  // 0-1
        var enabled: Bool
        var createdBy: String  // USER!
        var createdDate: Date
        var tags: [String]

        enum RoutingMode: String, Codable {
            case series = "Series"
            case parallel = "Parallel"
            case splitter = "Splitter"  // Different effects on L/R
        }

        /// Apply effect chain to audio buffer
        func process(buffer: [Float], sampleRate: Double) -> [Float] {
            guard enabled else { return buffer }

            var processed = buffer

            switch routing {
            case .series:
                // Process effects one after another
                for effect in effects where effect.enabled {
                    processed = effect.process(buffer: processed, sampleRate: sampleRate)
                }

            case .parallel:
                // Process all effects in parallel and mix
                var parallelBuffers: [[Float]] = []
                for effect in effects where effect.enabled {
                    parallelBuffers.append(effect.process(buffer: buffer, sampleRate: sampleRate))
                }

                // Mix parallel outputs
                if !parallelBuffers.isEmpty {
                    processed = mixBuffers(parallelBuffers)
                }

            case .splitter:
                // Split stereo and process separately (would need stereo implementation)
                processed = buffer
            }

            // Apply wet/dry mix
            return mixWetDry(dry: buffer, wet: processed, mix: wetDryMix)
        }

        private func mixBuffers(_ buffers: [[Float]]) -> [Float] {
            guard !buffers.isEmpty else { return [] }

            var result = [Float](repeating: 0, count: buffers[0].count)

            for buffer in buffers {
                for i in 0..<result.count {
                    result[i] += buffer[i] / Float(buffers.count)
                }
            }

            return result
        }

        private func mixWetDry(dry: [Float], wet: [Float], mix: Float) -> [Float] {
            var result = [Float](repeating: 0, count: dry.count)

            for i in 0..<result.count {
                result[i] = dry[i] * (1.0 - mix) + wet[i] * mix
            }

            return result
        }
    }

    // MARK: - Effect Instance

    struct EffectInstance: Identifiable, Codable {
        let id = UUID()
        var effect: EffectType
        var enabled: Bool
        var parameters: [String: Float]  // parameter name -> value

        /// Process audio through this effect
        func process(buffer: [Float], sampleRate: Double) -> [Float] {
            guard enabled else { return buffer }

            switch effect {
            case .reverb(let params):
                return processReverb(buffer: buffer, params: params, sampleRate: sampleRate)
            case .delay(let params):
                return processDelay(buffer: buffer, params: params, sampleRate: sampleRate)
            case .chorus(let params):
                return processChorus(buffer: buffer, params: params, sampleRate: sampleRate)
            case .flanger(let params):
                return processFlanger(buffer: buffer, params: params, sampleRate: sampleRate)
            case .phaser(let params):
                return processPhaser(buffer: buffer, params: params, sampleRate: sampleRate)
            case .distortion(let params):
                return processDistortion(buffer: buffer, params: params, sampleRate: sampleRate)
            case .bitcrusher(let params):
                return processBitcrusher(buffer: buffer, params: params)
            case .compressor(let params):
                return processCompressor(buffer: buffer, params: params, sampleRate: sampleRate)
            case .limiter(let params):
                return processLimiter(buffer: buffer, params: params)
            case .eq(let params):
                return processEQ(buffer: buffer, params: params, sampleRate: sampleRate)
            case .filter(let params):
                return processFilter(buffer: buffer, params: params, sampleRate: sampleRate)
            case .tremolo(let params):
                return processTremolo(buffer: buffer, params: params, sampleRate: sampleRate)
            case .vibrato(let params):
                return processVibrato(buffer: buffer, params: params, sampleRate: sampleRate)
            case .ringModulator(let params):
                return processRingModulator(buffer: buffer, params: params, sampleRate: sampleRate)
            case .waveshaper(let params):
                return processWaveshaper(buffer: buffer, params: params)
            case .stereoWidth(let params):
                return buffer  // Would need stereo implementation
            case .panning(let params):
                return buffer  // Would need stereo implementation
            case .gating(let params):
                return processGate(buffer: buffer, params: params, sampleRate: sampleRate)
            }
        }

        // MARK: - Effect Processing (DSP)

        private func processReverb(buffer: [Float], params: ReverbParams, sampleRate: Double) -> [Float] {
            // Simplified reverb (in production: use proper convolution or algorithmic reverb)
            var output = buffer
            let delayTime = params.size * 0.1  // seconds
            let delaySamples = Int(delayTime * sampleRate)

            // Simple feedback delay network
            for i in delaySamples..<output.count {
                output[i] += output[i - delaySamples] * params.feedback * (1.0 - params.damping)
            }

            return output
        }

        private func processDelay(buffer: [Float], params: DelayParams, sampleRate: Double) -> [Float] {
            var output = buffer
            let delaySamples = Int(params.time * sampleRate)

            guard delaySamples < output.count else { return buffer }

            for i in delaySamples..<output.count {
                output[i] += output[i - delaySamples] * params.feedback
            }

            return output
        }

        private func processChorus(buffer: [Float], params: ChorusParams, sampleRate: Double) -> [Float] {
            // Simplified chorus using modulated delay
            var output = buffer
            let maxDelay = 0.05  // 50ms
            let delaySamples = Int(maxDelay * sampleRate)

            for i in delaySamples..<output.count {
                // Modulate delay time with LFO
                let lfoPhase = Double(i) / sampleRate * Double(params.rate)
                let lfoValue = sin(lfoPhase * 2.0 * .pi)
                let modDelay = Int(Double(delaySamples) * (1.0 + lfoValue * Double(params.depth)))

                if i >= modDelay {
                    output[i] += output[i - modDelay] * 0.5
                }
            }

            return output
        }

        private func processFlanger(buffer: [Float], params: FlangerParams, sampleRate: Double) -> [Float] {
            // Similar to chorus but shorter delay and feedback
            var output = buffer
            let maxDelay = 0.01  // 10ms
            let delaySamples = Int(maxDelay * sampleRate)

            for i in delaySamples..<output.count {
                let lfoPhase = Double(i) / sampleRate * Double(params.rate)
                let lfoValue = sin(lfoPhase * 2.0 * .pi)
                let modDelay = Int(Double(delaySamples) * (1.0 + lfoValue * Double(params.depth)))

                if i >= modDelay {
                    output[i] += output[i - modDelay] * params.feedback
                }
            }

            return output
        }

        private func processPhaser(buffer: [Float], params: PhaserParams, sampleRate: Double) -> [Float] {
            // Simplified phaser using all-pass filters
            // In production: implement proper all-pass filter cascade
            return buffer  // Placeholder
        }

        private func processDistortion(buffer: [Float], params: DistortionParams, sampleRate: Double) -> [Float] {
            var output = buffer
            let gain = 1.0 + params.drive * 10.0

            for i in 0..<output.count {
                // Soft clipping distortion
                let x = output[i] * gain
                output[i] = tanhf(x)  // Soft saturation
            }

            return output
        }

        private func processBitcrusher(buffer: [Float], params: BitcrusherParams) -> [Float] {
            var output = buffer
            let bits = max(1, Int(params.bitDepth))
            let levels = Float(1 << bits)

            for i in 0..<output.count {
                // Quantize to fewer bits
                let quantized = round(output[i] * levels) / levels
                output[i] = quantized
            }

            // Sample rate reduction
            let skipSamples = max(1, Int(params.sampleRateReduction))
            var lastSample: Float = 0
            for i in stride(from: 0, to: output.count, by: skipSamples) {
                lastSample = output[i]
                for j in i..<min(i + skipSamples, output.count) {
                    output[j] = lastSample
                }
            }

            return output
        }

        private func processCompressor(buffer: [Float], params: CompressorParams, sampleRate: Double) -> [Float] {
            var output = buffer
            let attackTime = params.attack
            let releaseTime = params.release
            let ratio = params.ratio
            let threshold = params.threshold

            var envelope: Float = 0

            for i in 0..<output.count {
                let input = abs(output[i])

                // Envelope follower
                if input > envelope {
                    envelope += (input - envelope) * Float(attackTime)
                } else {
                    envelope += (input - envelope) * Float(releaseTime)
                }

                // Apply compression
                if envelope > threshold {
                    let excess = envelope - threshold
                    let compressed = threshold + excess / ratio
                    let gain = compressed / max(0.001, envelope)
                    output[i] *= gain
                }
            }

            return output
        }

        private func processLimiter(buffer: [Float], params: LimiterParams) -> [Float] {
            var output = buffer
            let threshold = params.threshold
            let ceiling = params.ceiling

            for i in 0..<output.count {
                if output[i] > threshold {
                    output[i] = threshold + (output[i] - threshold) * 0.1
                }
                if output[i] < -threshold {
                    output[i] = -threshold + (output[i] + threshold) * 0.1
                }

                // Hard limit at ceiling
                output[i] = max(-ceiling, min(ceiling, output[i]))
            }

            return output
        }

        private func processEQ(buffer: [Float], params: EQParams, sampleRate: Double) -> [Float] {
            // Simplified EQ (in production: use proper biquad filters)
            // Would implement multi-band parametric EQ
            return buffer  // Placeholder
        }

        private func processFilter(buffer: [Float], params: FilterParams, sampleRate: Double) -> [Float] {
            // Simplified filter (in production: use proper biquad/state-variable filter)
            // Would implement lowpass, highpass, bandpass, etc.
            return buffer  // Placeholder
        }

        private func processTremolo(buffer: [Float], params: TremoloParams, sampleRate: Double) -> [Float] {
            var output = buffer

            for i in 0..<output.count {
                let phase = Double(i) / sampleRate * Double(params.rate)
                let lfo = (1.0 + sin(phase * 2.0 * .pi)) * 0.5  // 0-1
                let modulation = 1.0 - Double(params.depth) * (1.0 - lfo)
                output[i] *= Float(modulation)
            }

            return output
        }

        private func processVibrato(buffer: [Float], params: VibratoParams, sampleRate: Double) -> [Float] {
            // Simplified vibrato using pitch modulation
            // In production: implement proper delay-based vibrato
            return buffer  // Placeholder
        }

        private func processRingModulator(buffer: [Float], params: RingModulatorParams, sampleRate: Double) -> [Float] {
            var output = buffer

            for i in 0..<output.count {
                let phase = Double(i) / sampleRate * Double(params.frequency)
                let modulator = Float(sin(phase * 2.0 * .pi))
                output[i] *= modulator * params.amount + (1.0 - params.amount)
            }

            return output
        }

        private func processWaveshaper(buffer: [Float], params: WaveshaperParams) -> [Float] {
            var output = buffer

            for i in 0..<output.count {
                let x = output[i] * params.drive

                switch params.curve {
                case .hardClip:
                    output[i] = max(-1, min(1, x))
                case .softClip:
                    output[i] = tanhf(x)
                case .fold:
                    output[i] = abs(fmod(x + 1, 4) - 2) - 1
                case .asymmetric:
                    output[i] = x > 0 ? powf(x, 1.5) : powf(-x, 0.7) * -1
                }
            }

            return output
        }

        private func processGate(buffer: [Float], params: GateParams, sampleRate: Double) -> [Float] {
            var output = buffer
            let attackSamples = Int(params.attack * sampleRate)
            let releaseSamples = Int(params.release * sampleRate)
            var gateOpen = false
            var envelope: Float = 0

            for i in 0..<output.count {
                let input = abs(output[i])

                // Gate trigger
                let newGateState = input > params.threshold

                if newGateState && !gateOpen {
                    gateOpen = true
                }

                if !newGateState && gateOpen {
                    gateOpen = false
                }

                // Envelope
                if gateOpen {
                    envelope = min(1, envelope + 1.0 / Float(attackSamples))
                } else {
                    envelope = max(0, envelope - 1.0 / Float(releaseSamples))
                }

                output[i] *= envelope
            }

            return output
        }
    }

    // MARK: - Effect Types

    enum EffectType: Codable {
        case reverb(ReverbParams)
        case delay(DelayParams)
        case chorus(ChorusParams)
        case flanger(FlangerParams)
        case phaser(PhaserParams)
        case distortion(DistortionParams)
        case bitcrusher(BitcrusherParams)
        case compressor(CompressorParams)
        case limiter(LimiterParams)
        case eq(EQParams)
        case filter(FilterParams)
        case tremolo(TremoloParams)
        case vibrato(VibratoParams)
        case ringModulator(RingModulatorParams)
        case waveshaper(WaveshaperParams)
        case stereoWidth(StereoWidthParams)
        case panning(PanningParams)
        case gating(GateParams)

        var displayName: String {
            switch self {
            case .reverb: return "Reverb"
            case .delay: return "Delay"
            case .chorus: return "Chorus"
            case .flanger: return "Flanger"
            case .phaser: return "Phaser"
            case .distortion: return "Distortion"
            case .bitcrusher: return "Bitcrusher"
            case .compressor: return "Compressor"
            case .limiter: return "Limiter"
            case .eq: return "EQ"
            case .filter: return "Filter"
            case .tremolo: return "Tremolo"
            case .vibrato: return "Vibrato"
            case .ringModulator: return "Ring Modulator"
            case .waveshaper: return "Waveshaper"
            case .stereoWidth: return "Stereo Width"
            case .panning: return "Panning"
            case .gating: return "Gate"
            }
        }
    }

    // MARK: - Effect Parameters

    struct ReverbParams: Codable {
        var size: Float  // 0-1
        var damping: Float  // 0-1
        var feedback: Float  // 0-1
    }

    struct DelayParams: Codable {
        var time: Float  // seconds
        var feedback: Float  // 0-1
    }

    struct ChorusParams: Codable {
        var rate: Float  // Hz
        var depth: Float  // 0-1
    }

    struct FlangerParams: Codable {
        var rate: Float  // Hz
        var depth: Float  // 0-1
        var feedback: Float  // 0-1
    }

    struct PhaserParams: Codable {
        var rate: Float  // Hz
        var depth: Float  // 0-1
        var feedback: Float  // 0-1
    }

    struct DistortionParams: Codable {
        var drive: Float  // 0-1
    }

    struct BitcrusherParams: Codable {
        var bitDepth: Float  // 1-16
        var sampleRateReduction: Float  // 1-10
    }

    struct CompressorParams: Codable {
        var threshold: Float  // 0-1
        var ratio: Float  // 1-20
        var attack: Float  // seconds
        var release: Float  // seconds
    }

    struct LimiterParams: Codable {
        var threshold: Float  // 0-1
        var ceiling: Float  // 0-1
    }

    struct EQParams: Codable {
        var lowGain: Float  // -24 to +24 dB
        var midGain: Float
        var highGain: Float
    }

    struct FilterParams: Codable {
        var cutoff: Float  // 20-20000 Hz
        var resonance: Float  // 0-1
    }

    struct TremoloParams: Codable {
        var rate: Float  // Hz
        var depth: Float  // 0-1
    }

    struct VibratoParams: Codable {
        var rate: Float  // Hz
        var depth: Float  // 0-1
    }

    struct RingModulatorParams: Codable {
        var frequency: Float  // Hz
        var amount: Float  // 0-1
    }

    struct WaveshaperParams: Codable {
        var drive: Float  // 1-10
        var curve: CurveType

        enum CurveType: String, Codable {
            case hardClip = "Hard Clip"
            case softClip = "Soft Clip"
            case fold = "Fold"
            case asymmetric = "Asymmetric"
        }
    }

    struct StereoWidthParams: Codable {
        var width: Float  // 0-2 (1 = normal)
    }

    struct PanningParams: Codable {
        var pan: Float  // -1 to +1
    }

    struct GateParams: Codable {
        var threshold: Float  // 0-1
        var attack: Float  // seconds
        var release: Float  // seconds
    }

    // MARK: - Effect Descriptor

    struct EffectDescriptor: Identifiable {
        let id = UUID()
        var name: String
        var category: Category
        var description: String
        var defaultParams: EffectType

        enum Category: String, CaseIterable {
            case dynamics = "Dynamics"
            case filter = "Filter"
            case modulation = "Modulation"
            case delay = "Delay"
            case reverb = "Reverb"
            case distortion = "Distortion"
            case spatial = "Spatial"
            case utility = "Utility"
        }
    }

    // MARK: - Initialization

    init() {
        loadEffectLibrary()

        print("🎚️ Effect Chain Builder initialized")
        print("   📚 \(effectLibrary.count) effects available")
        print("   👤 USER builds their own chains - NO AI!")
    }

    private func loadEffectLibrary() {
        effectLibrary = [
            EffectDescriptor(name: "Reverb", category: .reverb, description: "Algorithmic reverb", defaultParams: .reverb(ReverbParams(size: 0.5, damping: 0.5, feedback: 0.5))),
            EffectDescriptor(name: "Delay", category: .delay, description: "Delay/Echo", defaultParams: .delay(DelayParams(time: 0.5, feedback: 0.3))),
            EffectDescriptor(name: "Chorus", category: .modulation, description: "Chorus effect", defaultParams: .chorus(ChorusParams(rate: 1.5, depth: 0.5))),
            EffectDescriptor(name: "Flanger", category: .modulation, description: "Flanger effect", defaultParams: .flanger(FlangerParams(rate: 0.5, depth: 0.5, feedback: 0.3))),
            EffectDescriptor(name: "Phaser", category: .modulation, description: "Phaser effect", defaultParams: .phaser(PhaserParams(rate: 0.5, depth: 0.5, feedback: 0.3))),
            EffectDescriptor(name: "Distortion", category: .distortion, description: "Distortion/Overdrive", defaultParams: .distortion(DistortionParams(drive: 0.5))),
            EffectDescriptor(name: "Bitcrusher", category: .distortion, description: "Lo-fi bitcrusher", defaultParams: .bitcrusher(BitcrusherParams(bitDepth: 8, sampleRateReduction: 1))),
            EffectDescriptor(name: "Compressor", category: .dynamics, description: "Dynamics compressor", defaultParams: .compressor(CompressorParams(threshold: 0.5, ratio: 4, attack: 0.01, release: 0.1))),
            EffectDescriptor(name: "Limiter", category: .dynamics, description: "Brick-wall limiter", defaultParams: .limiter(LimiterParams(threshold: 0.9, ceiling: 1.0))),
            EffectDescriptor(name: "Gate", category: .dynamics, description: "Noise gate", defaultParams: .gating(GateParams(threshold: 0.1, attack: 0.001, release: 0.05))),
            EffectDescriptor(name: "Tremolo", category: .modulation, description: "Amplitude modulation", defaultParams: .tremolo(TremoloParams(rate: 5, depth: 0.5))),
            EffectDescriptor(name: "Ring Modulator", category: .modulation, description: "Ring modulation", defaultParams: .ringModulator(RingModulatorParams(frequency: 440, amount: 1.0))),
            EffectDescriptor(name: "Waveshaper", category: .distortion, description: "Waveshaping distortion", defaultParams: .waveshaper(WaveshaperParams(drive: 2, curve: .softClip))),
        ]
    }

    // MARK: - Chain Management

    func createChain(name: String) -> EffectChain {
        print("➕ Creating effect chain: \(name)")

        let chain = EffectChain(
            name: name,
            effects: [],
            routing: .series,
            wetDryMix: 1.0,
            enabled: true,
            createdBy: "User",
            createdDate: Date(),
            tags: []
        )

        chains.append(chain)

        print("   ✅ Empty chain created - USER will build it!")

        return chain
    }

    func addEffect(to chainId: UUID, effect: EffectType) {
        guard let chainIndex = chains.firstIndex(where: { $0.id == chainId }) else { return }

        print("➕ Adding \(effect.displayName) to chain")

        let instance = EffectInstance(
            effect: effect,
            enabled: true,
            parameters: [:]
        )

        chains[chainIndex].effects.append(instance)
    }

    func removeEffect(from chainId: UUID, effectId: UUID) {
        guard let chainIndex = chains.firstIndex(where: { $0.id == chainId }) else { return }

        print("🗑️ Removing effect from chain")

        chains[chainIndex].effects.removeAll { $0.id == effectId }
    }

    func reorderEffects(in chainId: UUID, from source: Int, to destination: Int) {
        guard let chainIndex = chains.firstIndex(where: { $0.id == chainId }) else { return }

        print("↕️ Reordering effects in chain")

        let effect = chains[chainIndex].effects.remove(at: source)
        chains[chainIndex].effects.insert(effect, at: destination)
    }

    // MARK: - Preset Management

    func saveChain(chainId: UUID, name: String) {
        guard let chain = chains.first(where: { $0.id == chainId }) else { return }

        print("💾 Saving effect chain: \(name)")
        print("   👤 Created by: USER")
        print("   🎚️ Effects: \(chain.effects.count)")
        print("   🔗 Routing: \(chain.routing.rawValue)")
    }

    func loadChain(_ chain: EffectChain) {
        print("📂 Loading effect chain: \(chain.name)")

        chains.append(chain)

        print("   ✅ Chain loaded")
    }
}
