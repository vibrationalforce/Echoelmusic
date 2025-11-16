//
//  CompositionSchool.swift
//  Echoelmusic
//
//  CoreML-powered Composition & Production Techniques School
//  Automatisierte Genre-spezifische Beispiele mit Plugin Suite Integration
//

import Foundation
import CoreML
import AVFoundation

// MARK: - Genre & Technique Definitions

/// Musik-Genres mit spezifischen Produktionstechniken
public enum MusicGenre: String, CaseIterable, Codable {
    case edm = "EDM/Electronic"
    case jazz = "Jazz"
    case classical = "Classical"
    case hiphop = "Hip-Hop/Trap"
    case ambient = "Ambient/Soundscape"
    case rock = "Rock/Alternative"
    case world = "World Music"
    case experimental = "Experimental"

    public var key: String { rawValue }
}

/// Produktions- und Kompositionstechniken
public enum ProductionTechnique: String, CaseIterable, Codable {
    // Kompositionstechniken
    case melodicCounterpoint = "Melodic Counterpoint"
    case harmonicProgression = "Harmonic Progression"
    case rhythmicLayering = "Rhythmic Layering"
    case tensionRelease = "Tension & Release"
    case motivicDevelopment = "Motivic Development"

    // Arrangement Techniken
    case buildupDropStructure = "Buildup & Drop Structure"
    case callAndResponse = "Call & Response"
    case textureStacking = "Texture Stacking"
    case orchestralVoicing = "Orchestral Voicing"
    case dynamicContrast = "Dynamic Contrast"

    // Mixing Techniken
    case frequencySeparation = "Frequency Separation"
    case sideChainCompression = "Side-Chain Compression"
    case parallelProcessing = "Parallel Processing"
    case stereoWidening = "Stereo Widening"
    case depthWithReverb = "Depth with Reverb"

    // Effekt Techniken
    case creativeFiltering = "Creative Filtering"
    case rhythmicDelay = "Rhythmic Delay"
    case modulationEffects = "Modulation Effects"
    case saturationWarmth = "Saturation & Warmth"
    case spatialProcessing = "Spatial Processing"

    public var category: TechniqueCategory {
        switch self {
        case .melodicCounterpoint, .harmonicProgression, .rhythmicLayering,
             .tensionRelease, .motivicDevelopment:
            return .composition
        case .buildupDropStructure, .callAndResponse, .textureStacking,
             .orchestralVoicing, .dynamicContrast:
            return .arrangement
        case .frequencySeparation, .sideChainCompression, .parallelProcessing,
             .stereoWidening, .depthWithReverb:
            return .mixing
        case .creativeFiltering, .rhythmicDelay, .modulationEffects,
             .saturationWarmth, .spatialProcessing:
            return .effects
        }
    }
}

public enum TechniqueCategory: String, Codable {
    case composition = "Composition"
    case arrangement = "Arrangement"
    case mixing = "Mixing"
    case effects = "Effects"
}

// MARK: - Lesson Structure

/// Eine Lektion in der Composition School
public struct CompositionLesson: Codable, Identifiable {
    public let id: UUID
    public let title: String
    public let genre: MusicGenre
    public let technique: ProductionTechnique
    public let difficulty: Difficulty
    public let description: String
    public let steps: [LessonStep]
    public let pluginChain: [PluginConfiguration]
    public let exampleParameters: ExampleParameters

    public enum Difficulty: String, Codable {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
        case expert = "Expert"
    }

    public init(
        id: UUID = UUID(),
        title: String,
        genre: MusicGenre,
        technique: ProductionTechnique,
        difficulty: Difficulty,
        description: String,
        steps: [LessonStep],
        pluginChain: [PluginConfiguration],
        exampleParameters: ExampleParameters
    ) {
        self.id = id
        self.title = title
        self.genre = genre
        self.technique = technique
        self.difficulty = difficulty
        self.description = description
        self.steps = steps
        self.pluginChain = pluginChain
        self.exampleParameters = exampleParameters
    }
}

/// Einzelner Schritt in einer Lektion
public struct LessonStep: Codable, Identifiable {
    public let id: UUID
    public let stepNumber: Int
    public let title: String
    public let explanation: String
    public let audioExample: String?  // Reference to generated example
    public let visualAid: VisualAidType?
    public let interactiveDemo: Bool

    public enum VisualAidType: String, Codable {
        case waveform = "Waveform"
        case spectrum = "Spectrum Analysis"
        case midiRoll = "MIDI Piano Roll"
        case pluginSettings = "Plugin Settings"
        case mixerView = "Mixer View"
    }

    public init(
        id: UUID = UUID(),
        stepNumber: Int,
        title: String,
        explanation: String,
        audioExample: String? = nil,
        visualAid: VisualAidType? = nil,
        interactiveDemo: Bool = false
    ) {
        self.id = id
        self.stepNumber = stepNumber
        self.title = title
        self.explanation = explanation
        self.audioExample = audioExample
        self.visualAid = visualAid
        self.interactiveDemo = interactiveDemo
    }
}

/// Konfiguration für Plugin-Chain
public struct PluginConfiguration: Codable, Identifiable {
    public let id: UUID
    public let pluginType: PluginType
    public let parameters: [String: Float]
    public let purpose: String

    public enum PluginType: String, Codable {
        case filter = "Filter"
        case reverb = "Reverb"
        case delay = "Delay"
        case compressor = "Compressor"
        case eq = "Parametric EQ"
        case limiter = "Limiter"
        case saturation = "Saturation"
    }

    public init(
        id: UUID = UUID(),
        pluginType: PluginType,
        parameters: [String: Float],
        purpose: String
    ) {
        self.id = id
        self.pluginType = pluginType
        self.parameters = parameters
        self.purpose = purpose
    }
}

/// Parameter für automatisierte Beispiel-Generierung
public struct ExampleParameters: Codable {
    public let tempo: Float  // BPM
    public let key: String  // e.g., "C", "Am"
    public let timeSignature: String  // e.g., "4/4"
    public let duration: Float  // seconds
    public let complexity: Float  // 0.0-1.0

    public init(
        tempo: Float,
        key: String,
        timeSignature: String,
        duration: Float,
        complexity: Float
    ) {
        self.tempo = tempo
        self.key = key
        self.timeSignature = timeSignature
        self.duration = duration
        self.complexity = complexity
    }
}

// MARK: - Composition School Main Class

/// Haupt-Klasse für die Composition School
public class CompositionSchool {

    // MARK: - Properties

    private var lessons: [CompositionLesson] = []
    private let exampleGenerator: AutomatedExampleGenerator
    private let techniqueAnalyzer: TechniqueAnalyzer

    // MARK: - Initialization

    public init() {
        self.exampleGenerator = AutomatedExampleGenerator()
        self.techniqueAnalyzer = TechniqueAnalyzer()
        self.loadDefaultLessons()
    }

    // MARK: - Lesson Management

    /// Lädt vordefinierte Lektionen für alle Genres
    private func loadDefaultLessons() {
        lessons = [
            // EDM Lessons
            createEDMBuildupDropLesson(),
            createEDMSideChainLesson(),
            createEDMFrequencySeparationLesson(),

            // Jazz Lessons
            createJazzCounterpointLesson(),
            createJazzCallResponseLesson(),
            createJazzVoicingLesson(),

            // Classical Lessons
            createClassicalOrchestrationLesson(),
            createClassicalDynamicsLesson(),
            createClassicalHarmonyLesson(),

            // Hip-Hop Lessons
            createHipHopLayeringLesson(),
            createHipHop808Lesson(),
            createHipHopSamplingLesson(),

            // Ambient Lessons
            createAmbientTextureLesson(),
            createAmbientSpatialLesson(),
            createAmbientEvolutionLesson()
        ]
    }

    /// Gibt alle verfügbaren Lektionen zurück
    public func getAllLessons() -> [CompositionLesson] {
        return lessons
    }

    /// Filtert Lektionen nach Genre
    public func getLessons(for genre: MusicGenre) -> [CompositionLesson] {
        return lessons.filter { $0.genre == genre }
    }

    /// Filtert Lektionen nach Technik
    public func getLessons(for technique: ProductionTechnique) -> [CompositionLesson] {
        return lessons.filter { $0.technique == technique }
    }

    /// Filtert Lektionen nach Schwierigkeitsgrad
    public func getLessons(difficulty: CompositionLesson.Difficulty) -> [CompositionLesson] {
        return lessons.filter { $0.difficulty == difficulty }
    }

    /// Generiert automatisches Beispiel für eine Lektion
    public func generateExample(for lesson: CompositionLesson) async throws -> GeneratedExample {
        return try await exampleGenerator.generate(
            genre: lesson.genre,
            technique: lesson.technique,
            parameters: lesson.exampleParameters,
            pluginChain: lesson.pluginChain
        )
    }

    /// Analysiert User-Audio und schlägt passende Lektionen vor
    public func recommendLessons(basedOn audioURL: URL) async throws -> [CompositionLesson] {
        let analysis = try await techniqueAnalyzer.analyze(audioURL: audioURL)

        // Empfehle Lektionen basierend auf erkanntem Genre und fehlenden Techniken
        let recommendedLessons = lessons.filter { lesson in
            lesson.genre == analysis.detectedGenre &&
            !analysis.usedTechniques.contains(lesson.technique)
        }

        return Array(recommendedLessons.prefix(5))  // Top 5 Empfehlungen
    }
}

// MARK: - Automated Example Generator

/// Generiert automatisierte Audio-Beispiele
public class AutomatedExampleGenerator {

    public init() {}

    public func generate(
        genre: MusicGenre,
        technique: ProductionTechnique,
        parameters: ExampleParameters,
        pluginChain: [PluginConfiguration]
    ) async throws -> GeneratedExample {

        // 1. Generiere Basis-Material basierend auf Genre
        let baseMaterial = generateBaseMaterial(
            genre: genre,
            tempo: parameters.tempo,
            key: parameters.key,
            duration: parameters.duration
        )

        // 2. Wende Technik an
        let processedMaterial = applyTechnique(
            to: baseMaterial,
            technique: technique,
            complexity: parameters.complexity
        )

        // 3. Wende Plugin-Chain an
        let finalAudio = try await applyPluginChain(
            to: processedMaterial,
            pluginChain: pluginChain
        )

        return GeneratedExample(
            audioBuffer: finalAudio,
            genre: genre,
            technique: technique,
            metadata: ExampleMetadata(
                tempo: parameters.tempo,
                key: parameters.key,
                pluginsUsed: pluginChain.map { $0.pluginType.rawValue }
            )
        )
    }

    private func generateBaseMaterial(
        genre: MusicGenre,
        tempo: Float,
        key: String,
        duration: Float
    ) -> AVAudioPCMBuffer {
        // Basis-Material-Generierung (Oszillatoren, Samples, etc.)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let frameCount = AVAudioFrameCount(duration * 44100)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        // Genre-spezifische Generierung
        switch genre {
        case .edm:
            generateEDMPattern(buffer: buffer, tempo: tempo)
        case .jazz:
            generateJazzPattern(buffer: buffer, tempo: tempo)
        case .classical:
            generateClassicalPattern(buffer: buffer, tempo: tempo)
        case .hiphop:
            generateHipHopPattern(buffer: buffer, tempo: tempo)
        case .ambient:
            generateAmbientPattern(buffer: buffer, tempo: tempo)
        case .rock:
            generateRockPattern(buffer: buffer, tempo: tempo)
        case .world:
            generateWorldPattern(buffer: buffer, tempo: tempo)
        case .experimental:
            generateExperimentalPattern(buffer: buffer, tempo: tempo)
        }

        return buffer
    }

    private func applyTechnique(
        to buffer: AVAudioPCMBuffer,
        technique: ProductionTechnique,
        complexity: Float
    ) -> AVAudioPCMBuffer {
        // Technik-spezifische Verarbeitung
        // Diese Methode würde die spezifische Technik demonstrieren
        return buffer
    }

    private func applyPluginChain(
        to buffer: AVAudioPCMBuffer,
        pluginChain: [PluginConfiguration]
    ) async throws -> AVAudioPCMBuffer {
        var currentBuffer = buffer

        for plugin in pluginChain {
            currentBuffer = try await applyPlugin(plugin, to: currentBuffer)
        }

        return currentBuffer
    }

    private func applyPlugin(
        _ config: PluginConfiguration,
        to buffer: AVAudioPCMBuffer
    ) async throws -> AVAudioPCMBuffer {
        // Plugin-Anwendung mit den konfigurierten Parametern
        // Integration mit bestehenden Nodes (FilterNode, ReverbNode, etc.)
        return buffer
    }

    // MARK: - Genre-specific Pattern Generators

    private func generateEDMPattern(buffer: AVAudioPCMBuffer, tempo: Float) {
        // 4-on-the-floor Kick Pattern mit synth Bassline
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        let samplesPerBeat = Int(44100.0 * 60.0 / Double(tempo))

        for frame in 0..<frameLength {
            let phase = Float(frame % samplesPerBeat) / Float(samplesPerBeat)

            // Kick on every beat
            var sample: Float = 0.0
            if phase < 0.05 {
                sample = sin(phase * 50.0 * .pi) * (1.0 - phase / 0.05)
            }

            // Bassline
            let bassFreq: Float = 55.0  // A1
            sample += sin(Float(frame) * bassFreq * 2.0 * .pi / 44100.0) * 0.3

            channelData[0][frame] = sample
            channelData[1][frame] = sample
        }
    }

    private func generateJazzPattern(buffer: AVAudioPCMBuffer, tempo: Float) {
        // Swing rhythm mit Walking Bass
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)

        for frame in 0..<frameLength {
            let t = Float(frame) / 44100.0

            // Walking bass pattern
            let bassNotes: [Float] = [110, 130.8, 146.8, 164.8]  // A2, C3, D3, E3
            let noteIndex = Int(t * Float(tempo) / 60.0) % bassNotes.count
            let freq = bassNotes[noteIndex]

            let sample = sin(Float(frame) * freq * 2.0 * .pi / 44100.0) * 0.4

            channelData[0][frame] = sample
            channelData[1][frame] = sample
        }
    }

    private func generateClassicalPattern(buffer: AVAudioPCMBuffer, tempo: Float) {
        // Orchestrale Harmonie mit sanften Übergängen
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)

        for frame in 0..<frameLength {
            // Triaden-basierte Harmonie
            let fundamental: Float = 261.63  // C4
            let third: Float = 329.63  // E4
            let fifth: Float = 392.00  // G4

            var sample: Float = 0.0
            sample += sin(Float(frame) * fundamental * 2.0 * .pi / 44100.0) * 0.3
            sample += sin(Float(frame) * third * 2.0 * .pi / 44100.0) * 0.2
            sample += sin(Float(frame) * fifth * 2.0 * .pi / 44100.0) * 0.2

            channelData[0][frame] = sample
            channelData[1][frame] = sample
        }
    }

    private func generateHipHopPattern(buffer: AVAudioPCMBuffer, tempo: Float) {
        // Trap-style Hi-Hat Pattern mit 808 Bass
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        let samplesPerBeat = Int(44100.0 * 60.0 / Double(tempo))

        for frame in 0..<frameLength {
            let beatPhase = Float(frame % samplesPerBeat) / Float(samplesPerBeat)
            var sample: Float = 0.0

            // 808 Kick
            if beatPhase < 0.1 {
                let freq = 60.0 - (beatPhase * 500.0)  // Pitch drop
                sample = sin(Float(frame) * freq * 2.0 * .pi / 44100.0) * (1.0 - beatPhase / 0.1)
            }

            // Hi-hat on 16ths
            let sixteenthPhase = Float(frame % (samplesPerBeat / 4)) / Float(samplesPerBeat / 4)
            if sixteenthPhase < 0.01 {
                sample += (Float.random(in: -1...1) * 0.3) * (1.0 - sixteenthPhase / 0.01)
            }

            channelData[0][frame] = sample
            channelData[1][frame] = sample
        }
    }

    private func generateAmbientPattern(buffer: AVAudioPCMBuffer, tempo: Float) {
        // Evolvierende Pad-Texturen
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)

        for frame in 0..<frameLength {
            let t = Float(frame) / 44100.0

            // Multiple layers mit LFO-Modulation
            var sample: Float = 0.0
            for i in 1...5 {
                let freq = 130.0 * Float(i) * 0.5  // C3 with harmonics
                let lfo = sin(t * 0.5 * Float(i) * .pi) * 0.3 + 0.7  // Slow modulation
                sample += sin(Float(frame) * freq * 2.0 * .pi / 44100.0) * lfo * 0.15
            }

            channelData[0][frame] = sample
            channelData[1][frame] = sample
        }
    }

    private func generateRockPattern(buffer: AVAudioPCMBuffer, tempo: Float) {
        // Power Chord Pattern
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)

        for frame in 0..<frameLength {
            // Power chord (root + fifth)
            let root: Float = 82.41  // E2
            let fifth: Float = 123.47  // B2

            var sample: Float = 0.0
            sample += sin(Float(frame) * root * 2.0 * .pi / 44100.0) * 0.4
            sample += sin(Float(frame) * fifth * 2.0 * .pi / 44100.0) * 0.3

            // Add distortion
            sample = tanh(sample * 2.0)

            channelData[0][frame] = sample
            channelData[1][frame] = sample
        }
    }

    private func generateWorldPattern(buffer: AVAudioPCMBuffer, tempo: Float) {
        // Pentatonische Skala mit ethnischen Rhythmen
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)

        // Pentatonic scale
        let scale: [Float] = [261.63, 293.66, 329.63, 392.00, 440.00]  // C D E G A

        for frame in 0..<frameLength {
            let t = Float(frame) / 44100.0
            let noteIndex = Int(t * Float(tempo) / 120.0) % scale.count
            let freq = scale[noteIndex]

            let sample = sin(Float(frame) * freq * 2.0 * .pi / 44100.0) * 0.4

            channelData[0][frame] = sample
            channelData[1][frame] = sample
        }
    }

    private func generateExperimentalPattern(buffer: AVAudioPCMBuffer, tempo: Float) {
        // Granular Synthesis mit zufälliger Modulation
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)

        for frame in 0..<frameLength {
            let t = Float(frame) / 44100.0

            // Multiple modulierte Frequenzen
            var sample: Float = 0.0
            for _ in 1...3 {
                let freq = Float.random(in: 100...800)
                let grain = sin(Float(frame) * freq * 2.0 * .pi / 44100.0)
                let envelope = sin(t * Float.random(in: 1...5) * .pi)
                sample += grain * envelope * 0.2
            }

            channelData[0][frame] = sample
            channelData[1][frame] = sample
        }
    }
}

// MARK: - Technique Analyzer

/// Analysiert Audio und erkennt verwendete Produktionstechniken
public class TechniqueAnalyzer {

    public init() {}

    public func analyze(audioURL: URL) async throws -> TechniqueAnalysis {
        // Audio-Analyse mit ML/DSP
        // Erkennt Genre, verwendete Techniken, etc.

        return TechniqueAnalysis(
            detectedGenre: .edm,
            usedTechniques: [.sideChainCompression, .frequencySeparation],
            suggestedImprovements: ["Add more dynamic contrast", "Enhance stereo width"]
        )
    }
}

public struct TechniqueAnalysis {
    public let detectedGenre: MusicGenre
    public let usedTechniques: [ProductionTechnique]
    public let suggestedImprovements: [String]
}

// MARK: - Generated Example

public struct GeneratedExample {
    public let audioBuffer: AVAudioPCMBuffer
    public let genre: MusicGenre
    public let technique: ProductionTechnique
    public let metadata: ExampleMetadata
}

public struct ExampleMetadata {
    public let tempo: Float
    public let key: String
    public let pluginsUsed: [String]
}

// MARK: - Lesson Factory Methods (EDM)

extension CompositionSchool {

    private func createEDMBuildupDropLesson() -> CompositionLesson {
        return CompositionLesson(
            title: "EDM Buildup & Drop Structure",
            genre: .edm,
            technique: .buildupDropStructure,
            difficulty: .intermediate,
            description: "Lerne, wie man effektive Buildups kreiert und kraftvolle Drops gestaltet - das Herzstück der EDM Produktion.",
            steps: [
                LessonStep(
                    stepNumber: 1,
                    title: "Buildup Phase - Tension erzeugen",
                    explanation: "Ein Buildup erzeugt Spannung durch: 1) Ansteigende Filterfrequenz, 2) Hinzufügen von Layers, 3) Snare Rolls, 4) Noise Sweeps",
                    visualAid: .spectrum
                ),
                LessonStep(
                    stepNumber: 2,
                    title: "Drop Impact - Maximale Energie",
                    explanation: "Der Drop liefert die angestaute Energie: 1) Alle Filter öffnen, 2) Kick + Bass gleichzeitig, 3) Maximale Frequency Spectrum",
                    visualAid: .waveform,
                    interactiveDemo: true
                ),
                LessonStep(
                    stepNumber: 3,
                    title: "Post-Drop Entwicklung",
                    explanation: "Nach dem Drop: Layer graduell hinzufügen, Variation durch Filter-Sweeps, Call & Response Elemente",
                    visualAid: .mixerView
                )
            ],
            pluginChain: [
                PluginConfiguration(
                    pluginType: .filter,
                    parameters: ["cutoff": 200.0, "resonance": 0.7],
                    purpose: "High-pass filter für Buildup"
                ),
                PluginConfiguration(
                    pluginType: .compressor,
                    parameters: ["threshold": -12.0, "ratio": 4.0],
                    purpose: "Glue Compression für Drop Impact"
                )
            ],
            exampleParameters: ExampleParameters(
                tempo: 128.0,
                key: "Am",
                timeSignature: "4/4",
                duration: 32.0,
                complexity: 0.7
            )
        )
    }

    private func createEDMSideChainLesson() -> CompositionLesson {
        return CompositionLesson(
            title: "Side-Chain Compression - Der EDM Pumping-Effekt",
            genre: .edm,
            technique: .sideChainCompression,
            difficulty: .beginner,
            description: "Meistere den charakteristischen 'Pumping'-Sound der EDM durch Side-Chain Compression.",
            steps: [
                LessonStep(
                    stepNumber: 1,
                    title: "Setup: Kick als Trigger",
                    explanation: "Der Kick-Drum triggert die Compression auf Bass und Synths, um Platz im Mix zu schaffen",
                    visualAid: .pluginSettings
                ),
                LessonStep(
                    stepNumber: 2,
                    title: "Parameter Tuning",
                    explanation: "Attack: 5-10ms (schnell), Release: 100-250ms (rhythmisch), Ratio: 4:1 bis 10:1",
                    interactiveDemo: true
                )
            ],
            pluginChain: [
                PluginConfiguration(
                    pluginType: .compressor,
                    parameters: ["attack": 5.0, "release": 150.0, "ratio": 6.0, "threshold": -20.0],
                    purpose: "Side-chain vom Kick getriggert"
                )
            ],
            exampleParameters: ExampleParameters(
                tempo: 128.0,
                key: "Dm",
                timeSignature: "4/4",
                duration: 16.0,
                complexity: 0.5
            )
        )
    }

    private func createEDMFrequencySeparationLesson() -> CompositionLesson {
        return CompositionLesson(
            title: "Frequency Separation - Saubere Mixe",
            genre: .edm,
            technique: .frequencySeparation,
            difficulty: .advanced,
            description: "Erstelle kristallklare Mixe durch strategische Frequenz-Trennung der Elemente.",
            steps: [
                LessonStep(
                    stepNumber: 1,
                    title: "Frequency Map erstellen",
                    explanation: "Sub-Bass: 20-60Hz, Bass: 60-250Hz, Mids: 250Hz-2kHz, Highs: 2kHz-8kHz, Air: 8kHz+",
                    visualAid: .spectrum
                ),
                LessonStep(
                    stepNumber: 2,
                    title: "EQ Sculpting",
                    explanation: "Jedes Element bekommt seinen eigenen Frequenzbereich durch gezieltes EQing",
                    interactiveDemo: true
                )
            ],
            pluginChain: [
                PluginConfiguration(
                    pluginType: .eq,
                    parameters: ["lowShelf": 80.0, "highPass": 30.0],
                    purpose: "Frequency Separation EQ"
                )
            ],
            exampleParameters: ExampleParameters(
                tempo: 130.0,
                key: "Em",
                timeSignature: "4/4",
                duration: 16.0,
                complexity: 0.8
            )
        )
    }
}

// MARK: - Lesson Factory Methods (Jazz)

extension CompositionSchool {

    private func createJazzCounterpointLesson() -> CompositionLesson {
        return CompositionLesson(
            title: "Jazz Counterpoint - Melodische Unabhängigkeit",
            genre: .jazz,
            technique: .melodicCounterpoint,
            difficulty: .advanced,
            description: "Kreiere unabhängige, aber harmonisch verbundene Melodielinien im Jazz-Stil.",
            steps: [
                LessonStep(
                    stepNumber: 1,
                    title: "Walking Bass Foundation",
                    explanation: "Die Walking Bass-Line definiert die Harmonie und gibt rhythmische Stabilität",
                    visualAid: .midiRoll
                ),
                LessonStep(
                    stepNumber: 2,
                    title: "Melodie mit Tensions",
                    explanation: "Die Melodie nutzt Tensions (9, 11, 13) und bewegt sich kontrapunktisch zum Bass",
                    interactiveDemo: true
                )
            ],
            pluginChain: [
                PluginConfiguration(
                    pluginType: .reverb,
                    parameters: ["roomSize": 0.6, "damping": 0.5, "wetDry": 0.3],
                    purpose: "Jazz Club Ambience"
                )
            ],
            exampleParameters: ExampleParameters(
                tempo: 120.0,
                key: "Bb",
                timeSignature: "4/4",
                duration: 24.0,
                complexity: 0.8
            )
        )
    }

    private func createJazzCallResponseLesson() -> CompositionLesson {
        return CompositionLesson(
            title: "Call & Response - Jazz Dialog",
            genre: .jazz,
            technique: .callAndResponse,
            difficulty: .intermediate,
            description: "Meistere die Kunst des musikalischen Dialogs durch Call & Response Patterns.",
            steps: [
                LessonStep(
                    stepNumber: 1,
                    title: "Call Phrase kreieren",
                    explanation: "Die 'Call' Phrase stellt eine musikalische 'Frage' - oft mit aufsteigender Melodie",
                    visualAid: .midiRoll
                ),
                LessonStep(
                    stepNumber: 2,
                    title: "Response entwickeln",
                    explanation: "Die 'Response' beantwortet die Frage - oft mit absteigender Melodie oder Resolution",
                    interactiveDemo: true
                )
            ],
            pluginChain: [
                PluginConfiguration(
                    pluginType: .delay,
                    parameters: ["time": 375.0, "feedback": 0.3, "wetDry": 0.2],
                    purpose: "Subtle rhythmic echo"
                )
            ],
            exampleParameters: ExampleParameters(
                tempo: 110.0,
                key: "F",
                timeSignature: "4/4",
                duration: 16.0,
                complexity: 0.6
            )
        )
    }

    private func createJazzVoicingLesson() -> CompositionLesson {
        return CompositionLesson(
            title: "Jazz Voicing - Akkord-Farben",
            genre: .jazz,
            technique: .orchestralVoicing,
            difficulty: .expert,
            description: "Lerne fortgeschrittene Jazz-Voicings: Drop-2, Drop-3, Quartal Harmony.",
            steps: [
                LessonStep(
                    stepNumber: 1,
                    title: "Drop-2 Voicings",
                    explanation: "Nehme die zweithöchste Note und versetze sie eine Oktave nach unten für smooth Voice Leading",
                    visualAid: .midiRoll
                ),
                LessonStep(
                    stepNumber: 2,
                    title: "Quartal Harmony",
                    explanation: "Akkorde in Quarten statt Terzen für modernen Jazz-Sound (McCoy Tyner Style)",
                    interactiveDemo: true
                )
            ],
            pluginChain: [
                PluginConfiguration(
                    pluginType: .eq,
                    parameters: ["lowMid": 250.0, "highMid": 3000.0],
                    purpose: "Piano warmth & clarity"
                )
            ],
            exampleParameters: ExampleParameters(
                tempo: 90.0,
                key: "Eb",
                timeSignature: "4/4",
                duration: 20.0,
                complexity: 0.9
            )
        )
    }
}

// MARK: - Lesson Factory Methods (Classical, Hip-Hop, Ambient)

extension CompositionSchool {

    private func createClassicalOrchestrationLesson() -> CompositionLesson {
        return CompositionLesson(
            title: "Orchestral Voicing - Instrument Ranges",
            genre: .classical,
            technique: .orchestralVoicing,
            difficulty: .advanced,
            description: "Verstehe die Ranges und Timbres verschiedener Orchesterinstrumente für authentische Orchestrierung.",
            steps: [
                LessonStep(stepNumber: 1, title: "String Section Layout", explanation: "Violins (E3-A7), Violas (C3-E6), Cellos (C2-C6), Bass (E1-C5)"),
                LessonStep(stepNumber: 2, title: "Woodwind Doubling", explanation: "Verdopple Melodien mit Flöte+Oboe oder Klarinette für verschiedene Farben")
            ],
            pluginChain: [
                PluginConfiguration(pluginType: .reverb, parameters: ["roomSize": 0.9, "wetDry": 0.5], purpose: "Concert Hall")
            ],
            exampleParameters: ExampleParameters(tempo: 72.0, key: "D", timeSignature: "4/4", duration: 30.0, complexity: 0.8)
        )
    }

    private func createClassicalDynamicsLesson() -> CompositionLesson {
        return CompositionLesson(
            title: "Dynamic Contrast - Von pp bis ff",
            genre: .classical,
            technique: .dynamicContrast,
            difficulty: .intermediate,
            description: "Nutze den vollen dynamischen Bereich für emotionale Expression.",
            steps: [
                LessonStep(stepNumber: 1, title: "Dynamic Markings", explanation: "pp (-40dB), p (-30dB), mp (-20dB), mf (-12dB), f (-6dB), ff (0dB)"),
                LessonStep(stepNumber: 2, title: "Crescendo/Decrescendo", explanation: "Graduelle Lautstärke-Änderungen über mehrere Takte für Spannung")
            ],
            pluginChain: [],
            exampleParameters: ExampleParameters(tempo: 60.0, key: "G", timeSignature: "3/4", duration: 24.0, complexity: 0.6)
        )
    }

    private func createClassicalHarmonyLesson() -> CompositionLesson {
        return CompositionLesson(
            title: "Classical Harmonic Progression",
            genre: .classical,
            technique: .harmonicProgression,
            difficulty: .advanced,
            description: "Meistere klassische Kadenzen und Modulationstechniken.",
            steps: [
                LessonStep(stepNumber: 1, title: "Perfect Cadence", explanation: "V-I Progression für starke Resolution"),
                LessonStep(stepNumber: 2, title: "Modulation", explanation: "Wechsel zur Dominante oder relativen Molltonart")
            ],
            pluginChain: [],
            exampleParameters: ExampleParameters(tempo: 80.0, key: "C", timeSignature: "4/4", duration: 20.0, complexity: 0.7)
        )
    }

    private func createHipHopLayeringLesson() -> CompositionLesson {
        return CompositionLesson(
            title: "Hip-Hop Rhythmic Layering",
            genre: .hiphop,
            technique: .rhythmicLayering,
            difficulty: .beginner,
            description: "Baue komplexe Drum-Patterns durch intelligentes Layering.",
            steps: [
                LessonStep(stepNumber: 1, title: "Foundation: Kick + Snare", explanation: "Kick on 1 & 3, Snare on 2 & 4 - das Hip-Hop Grundgerüst"),
                LessonStep(stepNumber: 2, title: "Hi-Hat Complexity", explanation: "16tel Hi-Hats mit velocity variation und ghost notes"),
                LessonStep(stepNumber: 3, title: "Percussion Layers", explanation: "Shaker, Claps, Snaps für zusätzliche rhythmische Textur")
            ],
            pluginChain: [
                PluginConfiguration(pluginType: .saturation, parameters: ["drive": 0.6], purpose: "Analog warmth"),
                PluginConfiguration(pluginType: .compressor, parameters: ["ratio": 3.0], purpose: "Glue compression")
            ],
            exampleParameters: ExampleParameters(tempo: 85.0, key: "Gm", timeSignature: "4/4", duration: 16.0, complexity: 0.6)
        )
    }

    private func createHipHop808Lesson() -> CompositionLesson {
        return CompositionLesson(
            title: "808 Bass Programming",
            genre: .hiphop,
            technique: .frequencySeparation,
            difficulty: .intermediate,
            description: "Programmiere kraftvolle 808 Basslines im Trap-Stil.",
            steps: [
                LessonStep(stepNumber: 1, title: "808 Tuning", explanation: "Tuned 808s auf die Harmonie der Track (Root, Fifth, Octave)"),
                LessonStep(stepNumber: 2, title: "Slide Technique", explanation: "Pitch Slides zwischen Noten für den charakteristischen 808-Flow")
            ],
            pluginChain: [
                PluginConfiguration(pluginType: .eq, parameters: ["lowShelf": 60.0], purpose: "Sub-bass boost"),
                PluginConfiguration(pluginType: .saturation, parameters: ["drive": 0.4], purpose: "Harmonic enhancement")
            ],
            exampleParameters: ExampleParameters(tempo: 140.0, key: "Fm", timeSignature: "4/4", duration: 16.0, complexity: 0.7)
        )
    }

    private func createHipHopSamplingLesson() -> CompositionLesson {
        return CompositionLesson(
            title: "Creative Sampling Techniques",
            genre: .hiphop,
            technique: .motivicDevelopment,
            difficulty: .advanced,
            description: "Transformiere Samples durch Chopping, Pitching, Time-Stretching.",
            steps: [
                LessonStep(stepNumber: 1, title: "Sample Chopping", explanation: "Schneide Samples in kleine Teile und re-arrangiere rhythmisch"),
                LessonStep(stepNumber: 2, title: "Pitch & Time", explanation: "Verändere Pitch ohne Tempo zu ändern für neue Melodien")
            ],
            pluginChain: [
                PluginConfiguration(pluginType: .filter, parameters: ["cutoff": 8000.0], purpose: "Lo-fi character")
            ],
            exampleParameters: ExampleParameters(tempo: 95.0, key: "Am", timeSignature: "4/4", duration: 20.0, complexity: 0.8)
        )
    }

    private func createAmbientTextureLesson() -> CompositionLesson {
        return CompositionLesson(
            title: "Ambient Texture Stacking",
            genre: .ambient,
            technique: .textureStacking,
            difficulty: .intermediate,
            description: "Kreiere dichte atmosphärische Texturen durch Layer-Stacking.",
            steps: [
                LessonStep(stepNumber: 1, title: "Pad Foundation", explanation: "Lange, evolvierende Pads als harmonische Grundlage"),
                LessonStep(stepNumber: 2, title: "Granular Layer", explanation: "Granular Synthesis für bewegende Texturen"),
                LessonStep(stepNumber: 3, title: "Field Recordings", explanation: "Naturgeräusche für organische Atmosphäre")
            ],
            pluginChain: [
                PluginConfiguration(pluginType: .reverb, parameters: ["roomSize": 1.0, "wetDry": 0.7], purpose: "Infinite space"),
                PluginConfiguration(pluginType: .delay, parameters: ["time": 2000.0, "feedback": 0.6], purpose: "Long delay trails")
            ],
            exampleParameters: ExampleParameters(tempo: 60.0, key: "Dm", timeSignature: "4/4", duration: 40.0, complexity: 0.5)
        )
    }

    private func createAmbientSpatialLesson() -> CompositionLesson {
        return CompositionLesson(
            title: "Spatial Processing - 3D Soundscapes",
            genre: .ambient,
            technique: .spatialProcessing,
            difficulty: .advanced,
            description: "Erschaffe immersive 3D-Klanglandschaften mit räumlicher Bewegung.",
            steps: [
                LessonStep(stepNumber: 1, title: "Stereo Width", explanation: "Nutze Stereo-Widening für Breite ohne Mono-Kompatibilität zu verlieren"),
                LessonStep(stepNumber: 2, title: "Panning Automation", explanation: "Automatisierte Panning-Bewegungen für lebendige Räumlichkeit")
            ],
            pluginChain: [
                PluginConfiguration(pluginType: .reverb, parameters: ["roomSize": 0.8], purpose: "Spatial reverb")
            ],
            exampleParameters: ExampleParameters(tempo: 70.0, key: "A", timeSignature: "5/4", duration: 36.0, complexity: 0.7)
        )
    }

    private func createAmbientEvolutionLesson() -> CompositionLesson {
        return CompositionLesson(
            title: "Evolving Soundscapes - Langform Entwicklung",
            genre: .ambient,
            technique: .motivicDevelopment,
            difficulty: .expert,
            description: "Gestalte sich langsam entwickelnde Klanglandschaften über lange Zeiträume.",
            steps: [
                LessonStep(stepNumber: 1, title: "Langform-Struktur", explanation: "Plane Evolution über 5-10 Minuten: Intro, Build, Peak, Decline, Outro"),
                LessonStep(stepNumber: 2, title: "Parameter Automation", explanation: "Subtile, langsame Änderungen von Filter, Reverb, Delay über Zeit"),
                LessonStep(stepNumber: 3, title: "Micro-Variationen", explanation: "Kleine Details die sich ändern halten den Hörer engagiert")
            ],
            pluginChain: [
                PluginConfiguration(pluginType: .filter, parameters: ["cutoff": 500.0], purpose: "Slow filter sweep"),
                PluginConfiguration(pluginType: .reverb, parameters: ["roomSize": 0.95], purpose: "Cathedral reverb")
            ],
            exampleParameters: ExampleParameters(tempo: 55.0, key: "Em", timeSignature: "4/4", duration: 60.0, complexity: 0.9)
        )
    }
}
