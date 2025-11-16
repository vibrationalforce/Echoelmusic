//
//  CoreMLIntegration.swift
//  Echoelmusic
//
//  CoreML Model Integration für Composition School
//  Genre-Analyse, Technique Recognition, Pattern Generation
//

import Foundation
import CoreML
import AVFoundation
import Accelerate

// MARK: - CoreML Model Manager

/// Verwaltet alle CoreML-Modelle für die Composition School
public class CoreMLModelManager {

    // MARK: - Singleton

    public static let shared = CoreMLModelManager()

    // MARK: - Model References

    private var genreClassifierModel: MLModel?
    private var techniqueRecognizerModel: MLModel?
    private var patternGeneratorModel: MLModel?
    private var mixAnalyzerModel: MLModel?

    // MARK: - Model Status

    public struct ModelStatus {
        public let isLoaded: Bool
        public let modelVersion: String?
        public let error: Error?
    }

    public private(set) var modelStatuses: [String: ModelStatus] = [:]

    // MARK: - Initialization

    private init() {
        loadAllModels()
    }

    // MARK: - Model Loading

    private func loadAllModels() {
        // Genre Classifier
        loadModel(
            name: "GenreClassifier",
            filename: "GenreClassifier",
            modelRef: &genreClassifierModel
        )

        // Technique Recognizer
        loadModel(
            name: "TechniqueRecognizer",
            filename: "TechniqueRecognizer",
            modelRef: &techniqueRecognizerModel
        )

        // Pattern Generator
        loadModel(
            name: "PatternGenerator",
            filename: "PatternGenerator",
            modelRef: &patternGeneratorModel
        )

        // Mix Analyzer
        loadModel(
            name: "MixAnalyzer",
            filename: "MixAnalyzer",
            modelRef: &mixAnalyzerModel
        )
    }

    private func loadModel(name: String, filename: String, modelRef: inout MLModel?) {
        do {
            // Versuche Modell aus Bundle zu laden
            if let modelURL = Bundle.main.url(forResource: filename, withExtension: "mlmodelc") {
                modelRef = try MLModel(contentsOf: modelURL)
                modelStatuses[name] = ModelStatus(
                    isLoaded: true,
                    modelVersion: "1.0",
                    error: nil
                )
                print("✅ CoreML Model loaded: \(name)")
            } else {
                // Modell nicht gefunden - verwende Fallback
                modelStatuses[name] = ModelStatus(
                    isLoaded: false,
                    modelVersion: nil,
                    error: NSError(domain: "CoreML", code: 404, userInfo: [
                        NSLocalizedDescriptionKey: "Model file not found: \(filename).mlmodelc"
                    ])
                )
                print("⚠️ CoreML Model not found: \(name) - using rule-based fallback")
            }
        } catch {
            modelStatuses[name] = ModelStatus(
                isLoaded: false,
                modelVersion: nil,
                error: error
            )
            print("❌ Failed to load CoreML Model: \(name) - \(error.localizedDescription)")
        }
    }

    // MARK: - Public Interface

    public func getGenreClassifier() -> GenreClassifierProtocol {
        if let model = genreClassifierModel {
            return CoreMLGenreClassifier(model: model)
        } else {
            return RuleBasedGenreClassifier()
        }
    }

    public func getTechniqueRecognizer() -> TechniqueRecognizerProtocol {
        if let model = techniqueRecognizerModel {
            return CoreMLTechniqueRecognizer(model: model)
        } else {
            return RuleBasedTechniqueRecognizer()
        }
    }

    public func getPatternGenerator() -> PatternGeneratorProtocol {
        if let model = patternGeneratorModel {
            return CoreMLPatternGenerator(model: model)
        } else {
            return RuleBasedPatternGenerator()
        }
    }

    public func getMixAnalyzer() -> MixAnalyzerProtocol {
        if let model = mixAnalyzerModel {
            return CoreMLMixAnalyzer(model: model)
        } else {
            return RuleBasedMixAnalyzer()
        }
    }
}

// MARK: - Genre Classifier Protocol

public protocol GenreClassifierProtocol {
    func classify(audioFeatures: AudioFeatures) -> GenreClassificationResult
}

public struct AudioFeatures {
    public let tempo: Float
    public let spectralCentroid: Float
    public let spectralRolloff: Float
    public let zeroCrossingRate: Float
    public let mfcc: [Float]  // 13 coefficients
    public let chroma: [Float]  // 12 bins
    public let rms: Float
    public let spectralFlux: Float
    public let spectralContrast: Float

    public init(
        tempo: Float,
        spectralCentroid: Float,
        spectralRolloff: Float,
        zeroCrossingRate: Float,
        mfcc: [Float],
        chroma: [Float],
        rms: Float,
        spectralFlux: Float,
        spectralContrast: Float
    ) {
        self.tempo = tempo
        self.spectralCentroid = spectralCentroid
        self.spectralRolloff = spectralRolloff
        self.zeroCrossingRate = zeroCrossingRate
        self.mfcc = mfcc
        self.chroma = chroma
        self.rms = rms
        self.spectralFlux = spectralFlux
        self.spectralContrast = spectralContrast
    }
}

public struct GenreClassificationResult {
    public let primaryGenre: MusicGenre
    public let confidence: Float
    public let secondaryGenres: [(genre: MusicGenre, confidence: Float)]

    public init(
        primaryGenre: MusicGenre,
        confidence: Float,
        secondaryGenres: [(genre: MusicGenre, confidence: Float)] = []
    ) {
        self.primaryGenre = primaryGenre
        self.confidence = confidence
        self.secondaryGenres = secondaryGenres
    }
}

// MARK: - CoreML Genre Classifier

class CoreMLGenreClassifier: GenreClassifierProtocol {
    private let model: MLModel

    init(model: MLModel) {
        self.model = model
    }

    func classify(audioFeatures: AudioFeatures) -> GenreClassificationResult {
        do {
            // Prepare input features
            let inputFeatures = try prepareMLFeatures(audioFeatures)

            // Run prediction
            let prediction = try model.prediction(from: inputFeatures)

            // Parse output
            if let genreString = prediction.featureValue(for: "genre")?.stringValue,
               let confidence = prediction.featureValue(for: "confidence")?.doubleValue {

                let genre = MusicGenre(rawValue: genreString) ?? .experimental
                return GenreClassificationResult(
                    primaryGenre: genre,
                    confidence: Float(confidence)
                )
            }

            throw NSError(domain: "CoreML", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Invalid model output"
            ])

        } catch {
            print("❌ CoreML Genre Classification failed: \(error)")
            // Fallback to rule-based
            return RuleBasedGenreClassifier().classify(audioFeatures: audioFeatures)
        }
    }

    private func prepareMLFeatures(_ features: AudioFeatures) throws -> MLFeatureProvider {
        // Convert AudioFeatures to MLFeatureProvider
        // This depends on the actual model input specification
        var featureDict: [String: Any] = [:]
        featureDict["tempo"] = features.tempo
        featureDict["spectral_centroid"] = features.spectralCentroid
        featureDict["spectral_rolloff"] = features.spectralRolloff
        featureDict["zero_crossing_rate"] = features.zeroCrossingRate
        featureDict["rms"] = features.rms
        featureDict["spectral_flux"] = features.spectralFlux
        featureDict["spectral_contrast"] = features.spectralContrast

        // MFCC as MLMultiArray
        let mfccArray = try MLMultiArray(shape: [13], dataType: .float32)
        for (i, value) in features.mfcc.enumerated() {
            mfccArray[i] = NSNumber(value: value)
        }
        featureDict["mfcc"] = mfccArray

        // Chroma as MLMultiArray
        let chromaArray = try MLMultiArray(shape: [12], dataType: .float32)
        for (i, value) in features.chroma.enumerated() {
            chromaArray[i] = NSNumber(value: value)
        }
        featureDict["chroma"] = chromaArray

        return try MLDictionaryFeatureProvider(dictionary: featureDict)
    }
}

// MARK: - Rule-Based Genre Classifier (Fallback)

class RuleBasedGenreClassifier: GenreClassifierProtocol {
    func classify(audioFeatures: AudioFeatures) -> GenreClassificationResult {
        // Rule-based classification as fallback
        var scores: [MusicGenre: Float] = [:]

        // EDM: Fast tempo (120-140), high spectral centroid
        if audioFeatures.tempo >= 120 && audioFeatures.tempo <= 140 {
            scores[.edm] = audioFeatures.spectralCentroid > 0.6 ? 0.8 : 0.4
        }

        // Jazz: Medium tempo (90-130), complex harmony
        if audioFeatures.tempo >= 90 && audioFeatures.tempo <= 130 {
            let harmonicComplexity = audioFeatures.chroma.reduce(0, +) / Float(audioFeatures.chroma.count)
            scores[.jazz] = harmonicComplexity > 0.6 ? 0.7 : 0.3
        }

        // Classical: Variable tempo, low spectral flux
        if audioFeatures.spectralFlux < 0.3 {
            scores[.classical] = 0.6
        }

        // Hip-Hop: 80-100 BPM, strong rhythmic elements
        if audioFeatures.tempo >= 80 && audioFeatures.tempo <= 100 {
            scores[.hiphop] = audioFeatures.rms > 0.5 ? 0.7 : 0.4
        }

        // Ambient: Slow tempo, low rhythmic complexity
        if audioFeatures.tempo < 80 && audioFeatures.spectralContrast < 0.4 {
            scores[.ambient] = 0.75
        }

        // Rock: Fast tempo, high energy
        if audioFeatures.tempo > 120 && audioFeatures.rms > 0.6 {
            scores[.rock] = 0.65
        }

        // Find best match
        if let best = scores.max(by: { $0.value < $1.value }) {
            return GenreClassificationResult(
                primaryGenre: best.key,
                confidence: best.value
            )
        }

        return GenreClassificationResult(
            primaryGenre: .experimental,
            confidence: 0.3
        )
    }
}

// MARK: - Technique Recognizer Protocol

public protocol TechniqueRecognizerProtocol {
    func recognize(audioBuffer: AVAudioPCMBuffer) -> [RecognizedTechnique]
}

public struct RecognizedTechnique {
    public let technique: ProductionTechnique
    public let confidence: Float
    public let description: String
    public let parameters: [String: Float]

    public init(
        technique: ProductionTechnique,
        confidence: Float,
        description: String,
        parameters: [String: Float] = [:]
    ) {
        self.technique = technique
        self.confidence = confidence
        self.description = description
        self.parameters = parameters
    }
}

// MARK: - CoreML Technique Recognizer

class CoreMLTechniqueRecognizer: TechniqueRecognizerProtocol {
    private let model: MLModel

    init(model: MLModel) {
        self.model = model
    }

    func recognize(audioBuffer: AVAudioPCMBuffer) -> [RecognizedTechnique] {
        do {
            // Extract features from audio
            let features = extractTechniqueFeatures(from: audioBuffer)

            // Run ML prediction
            let inputFeatures = try prepareTechniqueFeatures(features)
            let prediction = try model.prediction(from: inputFeatures)

            // Parse multi-label output
            return parseTechniquePrediction(prediction)

        } catch {
            print("❌ CoreML Technique Recognition failed: \(error)")
            return RuleBasedTechniqueRecognizer().recognize(audioBuffer: audioBuffer)
        }
    }

    private func extractTechniqueFeatures(from buffer: AVAudioPCMBuffer) -> [String: Float] {
        // Extract relevant features for technique recognition
        var features: [String: Float] = [:]

        guard let channelData = buffer.floatChannelData else { return features }
        let frameLength = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))

        // Dynamic range (for compression detection)
        features["dynamic_range"] = calculateDynamicRange(samples)

        // Stereo width (for stereo widening detection)
        if buffer.format.channelCount == 2 {
            features["stereo_width"] = calculateStereoWidth(buffer)
        }

        // Frequency spectrum variance (for filtering detection)
        features["spectrum_variance"] = calculateSpectrumVariance(samples)

        // Temporal modulation (for delay/reverb detection)
        features["temporal_modulation"] = calculateTemporalModulation(samples)

        return features
    }

    private func prepareTechniqueFeatures(_ features: [String: Float]) throws -> MLFeatureProvider {
        return try MLDictionaryFeatureProvider(dictionary: features)
    }

    private func parseTechniquePrediction(_ prediction: MLFeatureProvider) -> [RecognizedTechnique] {
        var techniques: [RecognizedTechnique] = []

        // Parse multi-label output (depends on model specification)
        for technique in ProductionTechnique.allCases {
            if let confidence = prediction.featureValue(for: technique.rawValue)?.doubleValue,
               confidence > 0.5 {
                techniques.append(RecognizedTechnique(
                    technique: technique,
                    confidence: Float(confidence),
                    description: "Detected via CoreML"
                ))
            }
        }

        return techniques
    }

    // MARK: - Feature Extraction Helpers

    private func calculateDynamicRange(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0.0 }
        let max = samples.max() ?? 0.0
        let min = samples.min() ?? 0.0
        return max - min
    }

    private func calculateStereoWidth(_ buffer: AVAudioPCMBuffer) -> Float {
        guard buffer.format.channelCount == 2,
              let leftChannel = buffer.floatChannelData?[0],
              let rightChannel = buffer.floatChannelData?[1] else {
            return 0.0
        }

        let frameLength = Int(buffer.frameLength)
        var correlation: Float = 0.0

        for i in 0..<frameLength {
            correlation += leftChannel[i] * rightChannel[i]
        }

        return 1.0 - (correlation / Float(frameLength))
    }

    private func calculateSpectrumVariance(_ samples: [Float]) -> Float {
        // Simplified spectral variance calculation
        guard samples.count >= 1024 else { return 0.0 }

        var variance: Float = 0.0
        let mean = samples.reduce(0, +) / Float(samples.count)

        for sample in samples {
            variance += pow(sample - mean, 2)
        }

        return variance / Float(samples.count)
    }

    private func calculateTemporalModulation(_ samples: [Float]) -> Float {
        // Detect repeating patterns (delay/reverb)
        guard samples.count >= 4096 else { return 0.0 }

        var maxCorrelation: Float = 0.0

        // Check for delays between 100ms and 1s
        for delay in stride(from: 4410, to: 44100, by: 4410) {
            var correlation: Float = 0.0
            for i in 0..<min(samples.count - delay, 4096) {
                correlation += samples[i] * samples[i + delay]
            }
            maxCorrelation = max(maxCorrelation, abs(correlation))
        }

        return maxCorrelation / 4096.0
    }
}

// MARK: - Rule-Based Technique Recognizer (Fallback)

class RuleBasedTechniqueRecognizer: TechniqueRecognizerProtocol {
    func recognize(audioBuffer: AVAudioPCMBuffer) -> [RecognizedTechnique] {
        var techniques: [RecognizedTechnique] = []

        guard let channelData = audioBuffer.floatChannelData else { return techniques }
        let frameLength = Int(audioBuffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))

        // Simple heuristics
        let dynamicRange = samples.max()! - samples.min()!

        if dynamicRange < 0.3 {
            techniques.append(RecognizedTechnique(
                technique: .parallelProcessing,
                confidence: 0.6,
                description: "Low dynamic range suggests compression"
            ))
        }

        return techniques
    }
}

// MARK: - Pattern Generator Protocol

public protocol PatternGeneratorProtocol {
    func generatePattern(
        genre: MusicGenre,
        technique: ProductionTechnique,
        parameters: PatternParameters
    ) async throws -> GeneratedPattern
}

public struct PatternParameters {
    public let tempo: Float
    public let key: String
    public let bars: Int
    public let complexity: Float  // 0.0 - 1.0

    public init(tempo: Float, key: String, bars: Int, complexity: Float) {
        self.tempo = tempo
        self.key = key
        self.bars = bars
        self.complexity = complexity
    }
}

public struct GeneratedPattern {
    public let midiNotes: [MIDINote]
    public let automationCurves: [AutomationCurve]
    public let metadata: PatternMetadata

    public struct MIDINote {
        public let pitch: UInt8
        public let velocity: UInt8
        public let startTime: Float  // in beats
        public let duration: Float   // in beats

        public init(pitch: UInt8, velocity: UInt8, startTime: Float, duration: Float) {
            self.pitch = pitch
            self.velocity = velocity
            self.startTime = startTime
            self.duration = duration
        }
    }

    public struct AutomationCurve {
        public let parameter: String
        public let points: [(time: Float, value: Float)]

        public init(parameter: String, points: [(time: Float, value: Float)]) {
            self.parameter = parameter
            self.points = points
        }
    }

    public struct PatternMetadata {
        public let genre: MusicGenre
        public let technique: ProductionTechnique
        public let description: String

        public init(genre: MusicGenre, technique: ProductionTechnique, description: String) {
            self.genre = genre
            self.technique = technique
            self.description = description
        }
    }

    public init(
        midiNotes: [MIDINote],
        automationCurves: [AutomationCurve],
        metadata: PatternMetadata
    ) {
        self.midiNotes = midiNotes
        self.automationCurves = automationCurves
        self.metadata = metadata
    }
}

// MARK: - CoreML Pattern Generator

class CoreMLPatternGenerator: PatternGeneratorProtocol {
    private let model: MLModel

    init(model: MLModel) {
        self.model = model
    }

    func generatePattern(
        genre: MusicGenre,
        technique: ProductionTechnique,
        parameters: PatternParameters
    ) async throws -> GeneratedPattern {
        // Prepare input
        let inputFeatures = try preparePatternInput(genre: genre, technique: technique, parameters: parameters)

        // Run LSTM/Transformer model
        let prediction = try model.prediction(from: inputFeatures)

        // Parse output to MIDI notes and automation
        return try parsePatternOutput(prediction, genre: genre, technique: technique)
    }

    private func preparePatternInput(
        genre: MusicGenre,
        technique: ProductionTechnique,
        parameters: PatternParameters
    ) throws -> MLFeatureProvider {
        var featureDict: [String: Any] = [:]

        // One-hot encode genre
        let genreEncoding = try MLMultiArray(shape: [8], dataType: .float32)
        if let genreIndex = MusicGenre.allCases.firstIndex(of: genre) {
            genreEncoding[genreIndex] = 1.0
        }
        featureDict["genre"] = genreEncoding

        // One-hot encode technique
        let techniqueEncoding = try MLMultiArray(shape: [20], dataType: .float32)
        if let techniqueIndex = ProductionTechnique.allCases.firstIndex(of: technique) {
            techniqueEncoding[techniqueIndex] = 1.0
        }
        featureDict["technique"] = techniqueEncoding

        // Continuous parameters
        featureDict["tempo"] = parameters.tempo
        featureDict["bars"] = Float(parameters.bars)
        featureDict["complexity"] = parameters.complexity

        return try MLDictionaryFeatureProvider(dictionary: featureDict)
    }

    private func parsePatternOutput(
        _ prediction: MLFeatureProvider,
        genre: MusicGenre,
        technique: ProductionTechnique
    ) throws -> GeneratedPattern {
        // Parse LSTM output to MIDI notes
        // This is model-specific and depends on output format
        var midiNotes: [GeneratedPattern.MIDINote] = []

        if let notesArray = prediction.featureValue(for: "notes")?.multiArrayValue {
            // Assuming output is [numNotes, 4] where 4 = [pitch, velocity, start, duration]
            let numNotes = notesArray.shape[0].intValue
            for i in 0..<numNotes {
                let pitch = UInt8(notesArray[[i, 0] as [NSNumber]].floatValue)
                let velocity = UInt8(notesArray[[i, 1] as [NSNumber]].floatValue)
                let startTime = notesArray[[i, 2] as [NSNumber]].floatValue
                let duration = notesArray[[i, 3] as [NSNumber]].floatValue

                midiNotes.append(GeneratedPattern.MIDINote(
                    pitch: pitch,
                    velocity: velocity,
                    startTime: startTime,
                    duration: duration
                ))
            }
        }

        return GeneratedPattern(
            midiNotes: midiNotes,
            automationCurves: [],
            metadata: GeneratedPattern.PatternMetadata(
                genre: genre,
                technique: technique,
                description: "Generated by CoreML"
            )
        )
    }
}

// MARK: - Rule-Based Pattern Generator (Fallback)

class RuleBasedPatternGenerator: PatternGeneratorProtocol {
    func generatePattern(
        genre: MusicGenre,
        technique: ProductionTechnique,
        parameters: PatternParameters
    ) async throws -> GeneratedPattern {

        var midiNotes: [GeneratedPattern.MIDINote] = []

        // Generate simple pattern based on genre
        switch genre {
        case .edm:
            midiNotes = generateEDMPattern(parameters: parameters)
        case .jazz:
            midiNotes = generateJazzPattern(parameters: parameters)
        case .classical:
            midiNotes = generateClassicalPattern(parameters: parameters)
        case .hiphop:
            midiNotes = generateHipHopPattern(parameters: parameters)
        case .ambient:
            midiNotes = generateAmbientPattern(parameters: parameters)
        default:
            midiNotes = generateGenericPattern(parameters: parameters)
        }

        return GeneratedPattern(
            midiNotes: midiNotes,
            automationCurves: [],
            metadata: GeneratedPattern.PatternMetadata(
                genre: genre,
                technique: technique,
                description: "Rule-based generation"
            )
        )
    }

    private func generateEDMPattern(parameters: PatternParameters) -> [GeneratedPattern.MIDINote] {
        var notes: [GeneratedPattern.MIDINote] = []

        // 4-on-the-floor kick
        for beat in 0..<(parameters.bars * 4) {
            notes.append(GeneratedPattern.MIDINote(
                pitch: 36,  // C1 (kick)
                velocity: 100,
                startTime: Float(beat),
                duration: 0.25
            ))
        }

        // Bassline
        let bassNotes: [UInt8] = [40, 42, 43, 45]  // E, F#, G, A
        for bar in 0..<parameters.bars {
            for (i, pitch) in bassNotes.enumerated() {
                notes.append(GeneratedPattern.MIDINote(
                    pitch: pitch,
                    velocity: 80,
                    startTime: Float(bar * 4 + i),
                    duration: 0.75
                ))
            }
        }

        return notes
    }

    private func generateJazzPattern(parameters: PatternParameters) -> [GeneratedPattern.MIDINote] {
        var notes: [GeneratedPattern.MIDINote] = []

        // Walking bass
        let jazzBass: [UInt8] = [45, 48, 50, 52]  // A, C, D, E
        for (i, pitch) in jazzBass.enumerated() {
            notes.append(GeneratedPattern.MIDINote(
                pitch: pitch,
                velocity: 70,
                startTime: Float(i),
                duration: 0.9
            ))
        }

        return notes
    }

    private func generateClassicalPattern(parameters: PatternParameters) -> [GeneratedPattern.MIDINote] {
        var notes: [GeneratedPattern.MIDINote] = []

        // Arpeggio
        let arpeggio: [UInt8] = [60, 64, 67, 72]  // C major triad
        for (i, pitch) in arpeggio.enumerated() {
            notes.append(GeneratedPattern.MIDINote(
                pitch: pitch,
                velocity: 60,
                startTime: Float(i) * 0.5,
                duration: 0.4
            ))
        }

        return notes
    }

    private func generateHipHopPattern(parameters: PatternParameters) -> [GeneratedPattern.MIDINote] {
        var notes: [GeneratedPattern.MIDINote] = []

        // Trap hi-hats
        for i in 0..<(parameters.bars * 16) {
            notes.append(GeneratedPattern.MIDINote(
                pitch: 42,  // Closed hi-hat
                velocity: UInt8.random(in: 60...90),
                startTime: Float(i) * 0.25,
                duration: 0.125
            ))
        }

        return notes
    }

    private func generateAmbientPattern(parameters: PatternParameters) -> [GeneratedPattern.MIDINote] {
        var notes: [GeneratedPattern.MIDINote] = []

        // Long pads
        let pad: [UInt8] = [60, 64, 67]  // C E G
        for (i, pitch) in pad.enumerated() {
            notes.append(GeneratedPattern.MIDINote(
                pitch: pitch,
                velocity: 40,
                startTime: Float(i) * 2.0,
                duration: 4.0
            ))
        }

        return notes
    }

    private func generateGenericPattern(parameters: PatternParameters) -> [GeneratedPattern.MIDINote] {
        return []
    }
}

// MARK: - Mix Analyzer Protocol

public protocol MixAnalyzerProtocol {
    func analyze(audioBuffer: AVAudioPCMBuffer) -> MixAnalysisResult
}

public struct MixAnalysisResult {
    public let frequencyBalance: FrequencyBalance
    public let dynamicRange: Float
    public let stereoWidth: Float
    public let peakLevel: Float
    public let rmsLevel: Float
    public let suggestions: [String]

    public struct FrequencyBalance {
        public let sub: Float      // 20-60 Hz
        public let bass: Float     // 60-250 Hz
        public let lowMid: Float   // 250-500 Hz
        public let mid: Float      // 500-2k Hz
        public let highMid: Float  // 2k-6k Hz
        public let high: Float     // 6k-20k Hz

        public init(sub: Float, bass: Float, lowMid: Float, mid: Float, highMid: Float, high: Float) {
            self.sub = sub
            self.bass = bass
            self.lowMid = lowMid
            self.mid = mid
            self.highMid = highMid
            self.high = high
        }
    }

    public init(
        frequencyBalance: FrequencyBalance,
        dynamicRange: Float,
        stereoWidth: Float,
        peakLevel: Float,
        rmsLevel: Float,
        suggestions: [String]
    ) {
        self.frequencyBalance = frequencyBalance
        self.dynamicRange = dynamicRange
        self.stereoWidth = stereoWidth
        self.peakLevel = peakLevel
        self.rmsLevel = rmsLevel
        self.suggestions = suggestions
    }
}

// MARK: - CoreML Mix Analyzer

class CoreMLMixAnalyzer: MixAnalyzerProtocol {
    private let model: MLModel

    init(model: MLModel) {
        self.model = model
    }

    func analyze(audioBuffer: AVAudioPCMBuffer) -> MixAnalysisResult {
        // Extract mix features and analyze with CoreML
        // Fallback to rule-based if fails
        return RuleBasedMixAnalyzer().analyze(audioBuffer: audioBuffer)
    }
}

// MARK: - Rule-Based Mix Analyzer (Fallback)

class RuleBasedMixAnalyzer: MixAnalyzerProtocol {
    func analyze(audioBuffer: AVAudioPCMBuffer) -> MixAnalysisResult {
        guard let channelData = audioBuffer.floatChannelData else {
            return createEmptyResult()
        }

        let frameLength = Int(audioBuffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))

        // Calculate basic metrics
        let peak = samples.map { abs($0) }.max() ?? 0.0
        let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count))
        let dynamicRange = 20.0 * log10(peak / (rms + 0.0001))

        // Frequency balance (simplified)
        let balance = MixAnalysisResult.FrequencyBalance(
            sub: 0.5,
            bass: 0.6,
            lowMid: 0.5,
            mid: 0.7,
            highMid: 0.6,
            high: 0.4
        )

        // Generate suggestions
        var suggestions: [String] = []
        if rms < 0.3 {
            suggestions.append("Increase overall level")
        }
        if peak > 0.95 {
            suggestions.append("Reduce peaks to avoid clipping")
        }

        return MixAnalysisResult(
            frequencyBalance: balance,
            dynamicRange: dynamicRange,
            stereoWidth: 0.5,
            peakLevel: peak,
            rmsLevel: rms,
            suggestions: suggestions
        )
    }

    private func createEmptyResult() -> MixAnalysisResult {
        return MixAnalysisResult(
            frequencyBalance: MixAnalysisResult.FrequencyBalance(
                sub: 0, bass: 0, lowMid: 0, mid: 0, highMid: 0, high: 0
            ),
            dynamicRange: 0,
            stereoWidth: 0,
            peakLevel: 0,
            rmsLevel: 0,
            suggestions: []
        )
    }
}
