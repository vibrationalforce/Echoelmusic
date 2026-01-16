import Foundation
import Accelerate

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║   ███████╗ ██████╗██╗  ██╗ ██████╗ ███████╗██╗      ██████╗ ██████╗ ██████╗ ║
// ║   ██╔════╝██╔════╝██║  ██║██╔═══██╗██╔════╝██║     ██╔════╝██╔═══██╗██╔══██╗║
// ║   █████╗  ██║     ███████║██║   ██║█████╗  ██║     ██║     ██║   ██║██████╔╝║
// ║   ██╔══╝  ██║     ██╔══██║██║   ██║██╔══╝  ██║     ██║     ██║   ██║██╔══██╗║
// ║   ███████╗╚██████╗██║  ██║╚██████╔╝███████╗███████╗╚██████╗╚██████╔╝██║  ██║║
// ║   ╚══════╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═╝║
// ║                                                                           ║
// ║   🎵 Pure Native DSP - No JUCE, No Dependencies, Just Vibes 🎵            ║
// ║   Cross-Platform: iOS • macOS • watchOS • tvOS • visionOS • Android       ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

// MARK: - EchoelCore Configuration

/// The heart of Echoelmusic's audio processing
/// Pure Swift/Kotlin - NO external dependencies
public enum EchoelCore {

    /// Current EchoelCore version
    public static let version = "1.0.0"

    /// Default sample rate
    public static let defaultSampleRate: Float = 48000

    /// Framework identifier
    public static let identifier = "com.echoelmusic.core"

    /// Fun motto
    public static let motto = "breath → sound → light → consciousness ✨"
}

// MARK: - 🔥 EchoelWarmth - Analog Hardware Emulations

/// Classic analog hardware with that warm, fuzzy feeling
/// "Like a hug for your audio" - EchoelWarmth
public enum EchoelWarmth {

    // MARK: - 🎛️ The Console - One Knob to Rule Them All

    /// Unified analog console - switch between legends with one knob
    @MainActor
    public class TheConsole {

        /// Which legend are we channeling today?
        public enum Legend: String, CaseIterable {
            case ssl = "SSL Glue"           // 🇬🇧 Solid State Logic
            case api = "API Punch"          // 🇺🇸 API 2500
            case neve = "Neve Magic"        // 🇬🇧 Rupert's Secret Sauce
            case pultec = "Pultec Silk"     // 🇺🇸 The Boost/Cut Trick
            case fairchild = "Fairchild Dream" // 🇺🇸 Variable-Mu Heaven
            case la2a = "LA-2A Love"        // 🇺🇸 Optical Smoothness
            case eleven76 = "1176 Bite"     // 🇺🇸 FET Aggression
            case manley = "Manley Velvet"   // 🇺🇸 Tube Mastering

            public var emoji: String {
                switch self {
                case .ssl: return "🔵"
                case .api: return "⚫"
                case .neve: return "🔷"
                case .pultec: return "🟡"
                case .fairchild: return "⚪"
                case .la2a: return "🪩"
                case .eleven76: return "🖤"
                case .manley: return "🟠"
                }
            }

            public var vibe: String {
                switch self {
                case .ssl: return "Punchy. Glue. Modern."
                case .api: return "Thrust. Power. Drums."
                case .neve: return "Silk. Warmth. Magic."
                case .pultec: return "Air. Bottom. Classic."
                case .fairchild: return "Smooth. Vintage. Rare."
                case .la2a: return "Vocals. Bass. Butter."
                case .eleven76: return "Fast. Aggressive. Bite."
                case .manley: return "Master. Tube. Velvet."
                }
            }
        }

        /// The magic knob - 0 to 💯
        public var vibe: Float = 50.0 {
            didSet { updateVibes() }
        }

        /// Current legend
        public var legend: Legend = .neve {
            didSet { updateVibes() }
        }

        /// Output level
        public var output: Float = 50.0

        /// Parallel blend
        public var blend: Float = 100.0

        /// Bypass
        public var bypassed: Bool = false

        private let sampleRate: Float

        public init(sampleRate: Float = EchoelCore.defaultSampleRate) {
            self.sampleRate = sampleRate
        }

        public func process(_ input: [Float]) -> [Float] {
            guard !bypassed else { return input }

            // Apply the legend's magic
            var processed = applyLegend(input)

            // Output and blend
            let outputGain = pow(10.0, (output - 50.0) / 50.0 * 12.0 / 20.0)
            let wet = blend / 100.0

            return input.indices.map { i in
                let wetSignal = processed[i] * outputGain
                return input[i] * (1.0 - wet) + wetSignal * wet
            }
        }

        private func applyLegend(_ input: [Float]) -> [Float] {
            let amount = vibe / 100.0

            return input.map { sample in
                var out = sample

                switch legend {
                case .ssl:
                    // VCA compression character
                    let threshold: Float = 0.3 - amount * 0.2
                    if abs(out) > threshold {
                        let excess = abs(out) - threshold
                        let compressed = threshold + excess / (1.0 + excess * 3.0 * amount)
                        out = out > 0 ? compressed : -compressed
                    }

                case .api:
                    // Thrust circuit + punch
                    out = tanh(out * (1.0 + amount * 2.0)) * (0.9 + amount * 0.1)

                case .neve:
                    // Transformer saturation + silk
                    let second = out * out * 0.15 * amount
                    let fourth = out * out * out * out * 0.05 * amount
                    out = out + (out > 0 ? second + fourth : -second - fourth)
                    out = out / (1.0 + abs(out) * amount * 0.1)

                case .pultec:
                    // Famous boost/cut curve approximation
                    out = out * (1.0 + amount * 0.3)

                case .fairchild:
                    // Variable-mu tube compression
                    let level = abs(out)
                    if level > 0.2 {
                        let ratio = 2.0 + level * amount * 4.0
                        out = out / (1.0 + level * (ratio - 1.0) * amount)
                    }

                case .la2a:
                    // Optical smoothness
                    out = out / (1.0 + abs(out) * amount * 0.5)

                case .eleven76:
                    // FET bite with odd harmonics
                    out = tanh(out * (1.0 + amount * 3.0))
                    out = out + out * out * out * 0.1 * amount

                case .manley:
                    // Tube velvet
                    if out >= 0 {
                        out = out / (1.0 + out * amount * 0.4)
                    } else {
                        out = out / (1.0 - out * amount * 0.3)
                    }
                }

                return out
            }
        }

        private func updateVibes() {
            // Could trigger UI updates, animations, etc.
        }
    }
}

// MARK: - 🌱 EchoelSeed - Genetic Sound Evolution

/// Sounds that grow, evolve, and mutate
/// "Plant a seed, grow a sound" - EchoelSeed
public enum EchoelSeed {

    /// The DNA of sound - 16 genes that define a voice
    public struct SoundDNA: Codable, Equatable {
        public var genes: [Float]        // 16 harmonic genes
        public var attack: Float         // Birth speed
        public var decay: Float          // Life span
        public var brightness: Float     // Sunshine amount
        public var movement: Float       // Dance factor
        public var mutationRate: Float   // Chaos level
        public var generation: Int       // Family tree depth

        /// Plant a random seed
        public static func randomSeed() -> SoundDNA {
            SoundDNA(
                genes: (0..<16).map { _ in Float.random(in: 0...1) },
                attack: Float.random(in: 0.001...0.5),
                decay: Float.random(in: 0.1...2.0),
                brightness: Float.random(in: 0.2...1.0),
                movement: Float.random(in: 0...0.5),
                mutationRate: Float.random(in: 0...0.1),
                generation: 0
            )
        }

        /// Make babies 👶
        public func breed(with partner: SoundDNA) -> SoundDNA {
            var child = SoundDNA.randomSeed()
            child.generation = max(self.generation, partner.generation) + 1

            // Genetic crossover
            for i in 0..<16 {
                child.genes[i] = Bool.random() ? self.genes[i] : partner.genes[i]

                // Random mutation
                if Float.random(in: 0...1) < mutationRate {
                    child.genes[i] = Float.random(in: 0...1)
                }
            }

            // Blend traits
            child.attack = (self.attack + partner.attack) / 2.0
            child.decay = (self.decay + partner.decay) / 2.0
            child.brightness = (self.brightness + partner.brightness) / 2.0
            child.movement = (self.movement + partner.movement) / 2.0
            child.mutationRate = (self.mutationRate + partner.mutationRate) / 2.0

            return child
        }
    }

    /// The Garden - where sounds grow
    @MainActor
    public class Garden {

        public var dna: SoundDNA
        public var frequency: Float = 440.0
        public var volume: Float = 0.8

        private let sampleRate: Float
        private var phase: Float = 0.0
        private var envelope: Float = 0.0
        private var lfoPhase: Float = 0.0

        public init(sampleRate: Float = EchoelCore.defaultSampleRate) {
            self.sampleRate = sampleRate
            self.dna = SoundDNA.randomSeed()
        }

        /// 🌱 Plant a new seed
        public func plantSeed() {
            dna = SoundDNA.randomSeed()
            phase = 0
            envelope = 0
        }

        /// 🧬 Mutate the current sound
        public func mutate(chaos: Float = 0.1) {
            for i in 0..<dna.genes.count {
                if Float.random(in: 0...1) < chaos {
                    dna.genes[i] = Float.random(in: 0...1)
                }
            }
            dna.generation += 1
        }

        /// 👶 Breed with another sound
        public func breed(with partner: SoundDNA) {
            dna = dna.breed(with: partner)
        }

        /// 🎵 Generate audio
        public func grow(_ frameCount: Int) -> [Float] {
            var output = [Float](repeating: 0, count: frameCount)
            let phaseIncrement = frequency / sampleRate

            for i in 0..<frameCount {
                // Movement LFO
                lfoPhase += 2.0 * Float.pi * 2.0 / sampleRate
                let lfo = sin(lfoPhase) * dna.movement

                // Additive synthesis from genes
                var sample: Float = 0.0
                for (harmonic, gene) in dna.genes.enumerated() {
                    let harmonicPhase = phase * Float(harmonic + 1)
                    sample += sin(harmonicPhase * 2.0 * Float.pi) * gene / Float(harmonic + 1)
                }

                // Brightness filter
                let filtered = sample * dna.brightness + sample * (1.0 - dna.brightness) * 0.3

                // Apply movement
                let modulated = filtered * (1.0 + lfo)

                // Envelope
                envelope = max(0, envelope * (1.0 - 1.0 / (dna.decay * sampleRate)))
                output[i] = modulated * envelope * volume

                phase += phaseIncrement
                if phase > 1.0 { phase -= 1.0 }
            }

            return output
        }

        /// 🎹 Note on
        public func noteOn() {
            envelope = 1.0
        }

        /// 🔇 Note off
        public func noteOff() {
            // Natural decay from DNA
        }
    }
}

// MARK: - 💓 EchoelPulse - Bio-Reactive Audio

/// Sound that breathes with you
/// "Your heartbeat is the tempo" - EchoelPulse
public enum EchoelPulse {

    /// Your body's music data
    public struct BodyMusic {
        public var heartRate: Float = 70.0       // 💓 BPM
        public var hrv: Float = 50.0             // 📊 SDNN ms
        public var coherence: Float = 50.0       // ✨ 0-100
        public var breathRate: Float = 12.0      // 🌬️ BPM
        public var breathPhase: Float = 0.0      // 🔄 0-1 (inhale→exhale)

        public init() {}

        public init(heartRate: Float, hrv: Float, coherence: Float, breathRate: Float, breathPhase: Float) {
            self.heartRate = heartRate
            self.hrv = hrv
            self.coherence = coherence
            self.breathRate = breathRate
            self.breathPhase = breathPhase
        }
    }

    /// Heart-synced audio processor
    @MainActor
    public class HeartSync {

        public var body: BodyMusic = BodyMusic()

        // Mapped parameters
        public private(set) var filterCutoff: Float = 1000.0
        public private(set) var reverbAmount: Float = 0.3
        public private(set) var delayTime: Float = 500.0
        public private(set) var warmth: Float = 0.2

        private let sampleRate: Float

        public init(sampleRate: Float = EchoelCore.defaultSampleRate) {
            self.sampleRate = sampleRate
        }

        /// Update from biometrics
        public func sync(with body: BodyMusic) {
            self.body = body

            // 💓 Heart rate → Filter brightness
            let hrNorm = ((body.heartRate - 60.0) / 60.0).clamped(to: 0...1)
            filterCutoff = 500.0 + hrNorm * 4500.0

            // 📊 HRV → Reverb (more variability = more space)
            let hrvNorm = ((body.hrv - 20.0) / 80.0).clamped(to: 0...1)
            reverbAmount = 0.1 + hrvNorm * 0.6

            // ✨ Coherence → Warmth
            let cohNorm = body.coherence / 100.0
            warmth = cohNorm * 0.4

            // 🌬️ Breathing → Delay time
            let breathNorm = ((20.0 - body.breathRate) / 14.0).clamped(to: 0...1)
            delayTime = 200.0 + breathNorm * 800.0
        }

        /// Process audio with body sync
        public func process(_ input: [Float]) -> [Float] {
            var output = input

            // 🌬️ Breath envelope
            let breathEnvelope = 0.8 + body.breathPhase * 0.2
            for i in 0..<output.count {
                output[i] *= breathEnvelope
            }

            // ✨ Coherence warmth
            if warmth > 0.01 {
                for i in 0..<output.count {
                    output[i] = tanh(output[i] * (1.0 + warmth * 2.0)) / (1.0 + warmth)
                }
            }

            return output
        }
    }
}

// MARK: - 🎨 EchoelVibe - Creative Effects

/// Fun, creative audio mangling
/// "Make it weird, make it wonderful" - EchoelVibe
public enum EchoelVibe {

    /// Saturation styles for The Punisher
    public enum SaturationFlavor: String, CaseIterable {
        case warm = "Warm Hug"          // 🤗 Gentle tube
        case aggressive = "Angry Cat"    // 😾 Aggressive tube
        case clean = "Glass of Water"    // 💧 Transparent
        case crunchy = "Broken Speaker"  // 📢 Transistor
        case nuclear = "Chernobyl"       // ☢️ Pentode destruction

        public var emoji: String {
            switch self {
            case .warm: return "🤗"
            case .aggressive: return "😾"
            case .clean: return "💧"
            case .crunchy: return "📢"
            case .nuclear: return "☢️"
            }
        }
    }

    /// The Punisher - Saturation that goes to 11
    @MainActor
    public class ThePunisher {

        public var drive: Float = 50.0      // How much pain
        public var flavor: SaturationFlavor = .warm
        public var punish: Bool = false     // THE BUTTON 🔴
        public var tone: Float = 50.0       // Dark ↔ Bright
        public var blend: Float = 100.0     // Dry/Wet

        private let sampleRate: Float

        public init(sampleRate: Float = EchoelCore.defaultSampleRate) {
            self.sampleRate = sampleRate
        }

        public func process(_ input: [Float]) -> [Float] {
            let driveAmount = (drive / 100.0) * (punish ? 3.0 : 1.0)
            let wet = blend / 100.0

            return input.map { sample in
                let driven = sample * (1.0 + driveAmount * 5.0)

                let saturated: Float
                switch flavor {
                case .warm:
                    let norm = driven / (1.0 + abs(driven) * 0.3)
                    let second = norm * norm * 0.15
                    saturated = norm + (driven > 0 ? second : -second)

                case .aggressive:
                    saturated = driven >= 0 ? tanh(driven * 1.5) : tanh(driven * 1.2) * 0.9

                case .clean:
                    saturated = driven / (1.0 + abs(driven) * 0.1)

                case .crunchy:
                    let threshold: Float = 0.7
                    if abs(driven) < threshold {
                        saturated = driven
                    } else {
                        let sign: Float = driven > 0 ? 1.0 : -1.0
                        let excess = abs(driven) - threshold
                        saturated = sign * (threshold + excess / (1.0 + excess * 3.0))
                    }

                case .nuclear:
                    let clipped = max(-1.0, min(1.0, driven * 2.0))
                    saturated = clipped + clipped * clipped * clipped * 0.3
                }

                let toneAmount = (tone - 50.0) / 50.0
                let toned = saturated * (1.0 + toneAmount * 0.3)

                return sample * (1.0 - wet) + toned * wet
            }
        }
    }

    /// Echo style for The Time Machine
    public enum EchoStyle: String, CaseIterable {
        case digital = "Crystal Clear"      // 💎 Digital
        case tape = "Grandpa's Reel"        // 📼 Tape
        case analog = "Bucket Brigade"       // 🪣 BBD
        case lofi = "Broken Walkman"        // 📻 Lo-Fi
        case space = "Event Horizon"        // 🕳️ Diffused

        public var emoji: String {
            switch self {
            case .digital: return "💎"
            case .tape: return "📼"
            case .analog: return "🪣"
            case .lofi: return "📻"
            case .space: return "🕳️"
            }
        }
    }

    /// The Time Machine - Delay with character
    @MainActor
    public class TheTimeMachine {

        public var time: Float = 500.0       // Delay time ms
        public var feedback: Float = 40.0    // Repeats
        public var style: EchoStyle = .tape
        public var wobble: Float = 10.0      // Wow/flutter
        public var warmth: Float = 20.0      // Saturation
        public var blend: Float = 30.0       // Dry/Wet

        private var buffer: [Float] = []
        private var writePos: Int = 0
        private var modPhase: Float = 0.0
        private let sampleRate: Float

        public init(sampleRate: Float = EchoelCore.defaultSampleRate) {
            self.sampleRate = sampleRate
            let maxSamples = Int(3000.0 * sampleRate / 1000.0)
            buffer = Array(repeating: 0, count: maxSamples)
        }

        public func process(_ input: [Float]) -> [Float] {
            var output = [Float](repeating: 0, count: input.count)
            let delaySamples = Int(time * sampleRate / 1000.0)
            let fbAmount = feedback / 100.0
            let wet = blend / 100.0

            for i in 0..<input.count {
                // Wobble modulation
                let modAmount = wobble / 100.0 * Float(delaySamples) * 0.02
                modPhase += 2.0 * Float.pi * 0.5 / sampleRate
                let modOffset = Int(sin(modPhase) * modAmount)

                let actualDelay = max(1, delaySamples + modOffset)
                let readPos = (writePos - actualDelay + buffer.count) % buffer.count

                var delayed = buffer[readPos]
                delayed = applyStyle(delayed)

                // Warmth
                if warmth > 0 {
                    delayed = tanh(delayed * (1.0 + warmth / 50.0)) / (1.0 + warmth / 100.0)
                }

                buffer[writePos] = input[i] + delayed * fbAmount
                output[i] = input[i] * (1.0 - wet) + delayed * wet

                writePos = (writePos + 1) % buffer.count
            }

            return output
        }

        private func applyStyle(_ x: Float) -> Float {
            switch style {
            case .digital: return x
            case .tape: return tanh(x * 1.2) * 0.95
            case .analog: return round(x * 128.0) / 128.0 * 0.98
            case .lofi: return round(x * 32.0) / 32.0 * 0.85
            case .space: return x * 0.9
            }
        }
    }

    /// The Voice Changer - Formant & pitch fun
    @MainActor
    public class TheVoiceChanger {

        public var pitch: Float = 0.0        // Semitones
        public var formant: Float = 0.0      // -100 to +100
        public var robot: Bool = false       // 🤖 mode
        public var blend: Float = 100.0

        private let sampleRate: Float
        private var robotPhase: Float = 0.0
        private var inputBuffer: [Float] = []
        private var grainPos: Int = 0

        public init(sampleRate: Float = EchoelCore.defaultSampleRate) {
            self.sampleRate = sampleRate
            inputBuffer = Array(repeating: 0, count: 2048)
        }

        public func process(_ input: [Float]) -> [Float] {
            let pitchRatio = pow(2.0, pitch / 12.0)
            let wet = blend / 100.0

            return input.enumerated().map { (i, sample) in
                var processed = sample

                // Pitch shift
                if abs(pitch) > 0.1 {
                    inputBuffer[grainPos] = sample
                    grainPos = (grainPos + 1) % inputBuffer.count
                    let readPos = Float(grainPos) / pitchRatio
                    processed = inputBuffer[Int(readPos) % inputBuffer.count]
                }

                // Formant
                if abs(formant) > 1.0 {
                    processed *= (1.0 + formant / 100.0 * 0.2)
                }

                // Robot 🤖
                if robot {
                    robotPhase += 2.0 * Float.pi * 200.0 / sampleRate
                    if robotPhase > 2.0 * Float.pi { robotPhase -= 2.0 * Float.pi }
                    processed = abs(processed) * sin(robotPhase) * 2.0
                }

                return sample * (1.0 - wet) + processed * wet
            }
        }
    }
}

// MARK: - Float Extension

extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
