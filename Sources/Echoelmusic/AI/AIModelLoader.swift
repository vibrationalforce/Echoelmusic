import Foundation
import CoreML
import Combine

#if canImport(CreateML)
import CreateML
#endif

// MARK: - AI Model Loader

/// Unified CoreML model loading, caching, and management system
/// Supports lazy loading, background compilation, and fallback to algorithmic generation
@MainActor
class AIModelLoader: ObservableObject {

    // MARK: - Singleton

    static let shared = AIModelLoader()

    // MARK: - Published State

    @Published private(set) var loadedModels: [ModelType: ModelInfo] = [:]
    @Published private(set) var loadingProgress: Float = 0.0
    @Published private(set) var status: LoaderStatus = .idle

    // MARK: - Model Types

    enum ModelType: String, CaseIterable {
        case melodyGenerator = "MelodyGenerator"
        case chordPredictor = "ChordPredictor"
        case drumPatternGenerator = "DrumPatternGenerator"
        case emotionClassifier = "EmotionClassifier"
        case bioStatePredictor = "BioStatePredictor"
        case audioStyleTransfer = "AudioStyleTransfer"
        case voiceActivityDetector = "VoiceActivityDetector"
        case gestureRecognizer = "GestureRecognizer"

        var fileName: String {
            rawValue
        }

        var requiredInputs: [String] {
            switch self {
            case .melodyGenerator:
                return ["seed_notes", "key", "scale", "bars"]
            case .chordPredictor:
                return ["current_chord", "key", "mood"]
            case .drumPatternGenerator:
                return ["style", "tempo", "intensity"]
            case .emotionClassifier:
                return ["audio_features"]
            case .bioStatePredictor:
                return ["hrv", "heart_rate", "breathing_rate"]
            case .audioStyleTransfer:
                return ["source_audio", "target_style"]
            case .voiceActivityDetector:
                return ["audio_buffer"]
            case .gestureRecognizer:
                return ["hand_landmarks"]
            }
        }

        var isCritical: Bool {
            switch self {
            case .melodyGenerator, .chordPredictor, .drumPatternGenerator:
                return false // Has algorithmic fallback
            case .emotionClassifier, .bioStatePredictor, .voiceActivityDetector, .gestureRecognizer:
                return true // Core functionality
            case .audioStyleTransfer:
                return false // Optional feature
            }
        }
    }

    // MARK: - Model Info

    struct ModelInfo {
        let type: ModelType
        let model: MLModel
        let configuration: MLModelConfiguration
        let loadedAt: Date
        let fileSize: Int64
        var inferenceCount: Int = 0
        var averageInferenceTime: TimeInterval = 0

        var memoryFootprint: String {
            ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .memory)
        }
    }

    // MARK: - Loader Status

    enum LoaderStatus: Equatable {
        case idle
        case loading(ModelType)
        case ready
        case error(String)
    }

    // MARK: - Cache

    private var modelCache: [ModelType: URL] = [:]
    private let cacheDirectory: URL

    // MARK: - Initialization

    private init() {
        // Setup cache directory
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("AIModels", isDirectory: true)

        // Create cache directory if needed
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        log.info("🤖 AIModelLoader: Initialized with cache at \(cacheDirectory.path)", category: .system)
    }

    // MARK: - Loading Methods

    /// Load all available models
    func loadAllModels() async {
        status = .loading(.melodyGenerator)
        loadingProgress = 0.0

        let totalModels = ModelType.allCases.count
        var loadedCount = 0

        for modelType in ModelType.allCases {
            status = .loading(modelType)

            do {
                if let model = try await loadModel(modelType) {
                    loadedModels[modelType] = model
                    log.info("✅ AIModelLoader: Loaded \(modelType.rawValue)", category: .system)
                }
            } catch {
                log.info("⚠️ AIModelLoader: Failed to load \(modelType.rawValue) - \(error.localizedDescription)", level: .warning, category: .system)
                if modelType.isCritical {
                    status = .error("Critical model failed: \(modelType.rawValue)")
                    return
                }
            }

            loadedCount += 1
            loadingProgress = Float(loadedCount) / Float(totalModels)
        }

        status = .ready
        log.info("✅ AIModelLoader: Ready with \(loadedModels.count)/\(totalModels) models", category: .system)
    }

    /// Load a specific model
    func loadModel(_ type: ModelType) async throws -> ModelInfo? {
        // Check if already loaded
        if let existing = loadedModels[type] {
            return existing
        }

        // Check bundle for compiled model
        if let modelURL = Bundle.main.url(forResource: type.fileName, withExtension: "mlmodelc") {
            return try await loadCompiledModel(type: type, url: modelURL)
        }

        // Check bundle for source model (needs compilation)
        if let modelURL = Bundle.main.url(forResource: type.fileName, withExtension: "mlmodel") {
            return try await compileAndLoadModel(type: type, url: modelURL)
        }

        // Check cache
        if let cachedURL = modelCache[type], FileManager.default.fileExists(atPath: cachedURL.path) {
            return try await loadCompiledModel(type: type, url: cachedURL)
        }

        // Model not available - return nil (use algorithmic fallback)
        log.info("ℹ️ AIModelLoader: Model \(type.rawValue) not found, using fallback", category: .system)
        return nil
    }

    /// Load a compiled .mlmodelc model
    private func loadCompiledModel(type: ModelType, url: URL) async throws -> ModelInfo {
        let config = createConfiguration(for: type)

        let model = try await Task.detached {
            try MLModel(contentsOf: url, configuration: config)
        }.value

        let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0

        return ModelInfo(
            type: type,
            model: model,
            configuration: config,
            loadedAt: Date(),
            fileSize: fileSize
        )
    }

    /// Compile and load a source .mlmodel
    private func compileAndLoadModel(type: ModelType, url: URL) async throws -> ModelInfo {
        let compiledURL = try await Task.detached {
            try MLModel.compileModel(at: url)
        }.value

        // Cache the compiled model
        let cachedURL = cacheDirectory.appendingPathComponent("\(type.fileName).mlmodelc")
        try? FileManager.default.removeItem(at: cachedURL)
        try FileManager.default.copyItem(at: compiledURL, to: cachedURL)
        modelCache[type] = cachedURL

        return try await loadCompiledModel(type: type, url: cachedURL)
    }

    /// Create optimal configuration for model type
    private func createConfiguration(for type: ModelType) -> MLModelConfiguration {
        let config = MLModelConfiguration()

        switch type {
        case .melodyGenerator, .chordPredictor, .drumPatternGenerator:
            // Music generation - can use CPU
            config.computeUnits = .cpuAndGPU

        case .emotionClassifier, .bioStatePredictor:
            // Real-time classification - prefer Neural Engine
            config.computeUnits = .all

        case .audioStyleTransfer:
            // Heavy computation - GPU required
            config.computeUnits = .cpuAndGPU

        case .voiceActivityDetector:
            // Low latency - CPU is fine
            config.computeUnits = .cpuOnly

        case .gestureRecognizer:
            // Real-time - prefer Neural Engine
            config.computeUnits = .all
        }

        return config
    }

    // MARK: - Inference

    /// Run inference on a loaded model
    func predict<T: MLFeatureProvider>(modelType: ModelType, input: T) async throws -> MLFeatureProvider {
        guard let modelInfo = loadedModels[modelType] else {
            throw AIModelError.modelNotLoaded(modelType)
        }

        let startTime = Date()

        let output = try await Task.detached {
            try modelInfo.model.prediction(from: input)
        }.value

        // Update inference stats
        let inferenceTime = Date().timeIntervalSince(startTime)
        if var info = loadedModels[modelType] {
            info.inferenceCount += 1
            info.averageInferenceTime = (info.averageInferenceTime * Double(info.inferenceCount - 1) + inferenceTime) / Double(info.inferenceCount)
            loadedModels[modelType] = info
        }

        return output
    }

    // MARK: - Memory Management

    /// Unload a specific model
    func unloadModel(_ type: ModelType) {
        loadedModels.removeValue(forKey: type)
        log.info("🗑️ AIModelLoader: Unloaded \(type.rawValue)", category: .system)
    }

    /// Unload all non-critical models
    func unloadNonCriticalModels() {
        for type in ModelType.allCases where !type.isCritical {
            unloadModel(type)
        }
    }

    /// Get total memory usage
    var totalMemoryUsage: Int64 {
        loadedModels.values.reduce(0) { $0 + $1.fileSize }
    }

    var totalMemoryUsageString: String {
        ByteCountFormatter.string(fromByteCount: totalMemoryUsage, countStyle: .memory)
    }

    // MARK: - Model Discovery

    /// Check if model is available (in bundle or cache)
    func isModelAvailable(_ type: ModelType) -> Bool {
        Bundle.main.url(forResource: type.fileName, withExtension: "mlmodelc") != nil ||
        Bundle.main.url(forResource: type.fileName, withExtension: "mlmodel") != nil ||
        modelCache[type] != nil
    }

    /// Get list of available models
    var availableModels: [ModelType] {
        ModelType.allCases.filter { isModelAvailable($0) }
    }

    // MARK: - Warm-up

    /// Pre-warm models with dummy input
    func warmUpModels() async {
        log.info("🔥 AIModelLoader: Warming up models...", category: .system)

        for (type, info) in loadedModels {
            do {
                // Create dummy input based on model type
                let dummyInput = try createDummyInput(for: type)
                _ = try await predict(modelType: type, input: dummyInput)
                log.info("  ✓ \(type.rawValue) warmed up", category: .system)
            } catch {
                log.info("  ✗ \(type.rawValue) warm-up failed: \(error.localizedDescription)", category: .system)
            }
        }
    }

    private func createDummyInput(for type: ModelType) throws -> MLDictionaryFeatureProvider {
        var inputs: [String: MLFeatureValue] = [:]

        switch type {
        case .melodyGenerator:
            inputs["seed_notes"] = MLFeatureValue(multiArray: try MLMultiArray(shape: [8], dataType: .float32))
            inputs["key"] = MLFeatureValue(int64: 0)
            inputs["scale"] = MLFeatureValue(int64: 0)
            inputs["bars"] = MLFeatureValue(int64: 4)

        case .chordPredictor:
            inputs["current_chord"] = MLFeatureValue(int64: 0)
            inputs["key"] = MLFeatureValue(int64: 0)
            inputs["mood"] = MLFeatureValue(int64: 0)

        case .drumPatternGenerator:
            inputs["style"] = MLFeatureValue(int64: 0)
            inputs["tempo"] = MLFeatureValue(double: 120.0)
            inputs["intensity"] = MLFeatureValue(double: 0.5)

        case .emotionClassifier:
            inputs["audio_features"] = MLFeatureValue(multiArray: try MLMultiArray(shape: [256], dataType: .float32))

        case .bioStatePredictor:
            inputs["hrv"] = MLFeatureValue(double: 50.0)
            inputs["heart_rate"] = MLFeatureValue(double: 70.0)
            inputs["breathing_rate"] = MLFeatureValue(double: 6.0)

        case .audioStyleTransfer:
            inputs["source_audio"] = MLFeatureValue(multiArray: try MLMultiArray(shape: [44100], dataType: .float32))
            inputs["target_style"] = MLFeatureValue(int64: 0)

        case .voiceActivityDetector:
            inputs["audio_buffer"] = MLFeatureValue(multiArray: try MLMultiArray(shape: [512], dataType: .float32))

        case .gestureRecognizer:
            inputs["hand_landmarks"] = MLFeatureValue(multiArray: try MLMultiArray(shape: [21, 3], dataType: .float32))
        }

        return try MLDictionaryFeatureProvider(dictionary: inputs)
    }
}

// MARK: - Errors

enum AIModelError: LocalizedError {
    case modelNotLoaded(AIModelLoader.ModelType)
    case inferenceError(String)
    case compilationFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded(let type):
            return "Model \(type.rawValue) is not loaded"
        case .inferenceError(let message):
            return "Inference error: \(message)"
        case .compilationFailed(let message):
            return "Model compilation failed: \(message)"
        }
    }
}

// MARK: - Bio State Prediction

extension AIModelLoader {

    /// Predict user bio state from HRV and heart rate data
    func predictBioState(hrv: Double, heartRate: Double, breathingRate: Double) async throws -> BioStatePrediction {
        // Try ML model first
        if let _ = loadedModels[.bioStatePredictor] {
            let input = try MLDictionaryFeatureProvider(dictionary: [
                "hrv": MLFeatureValue(double: hrv),
                "heart_rate": MLFeatureValue(double: heartRate),
                "breathing_rate": MLFeatureValue(double: breathingRate)
            ])

            let output = try await predict(modelType: .bioStatePredictor, input: input)

            if let stateIndex = output.featureValue(for: "state")?.int64Value,
               let confidence = output.featureValue(for: "confidence")?.doubleValue {
                let state = BioState(rawValue: Int(stateIndex)) ?? .balanced
                return BioStatePrediction(state: state, confidence: confidence)
            }
        }

        // Algorithmic fallback
        return predictBioStateAlgorithmically(hrv: hrv, heartRate: heartRate, breathingRate: breathingRate)
    }

    private func predictBioStateAlgorithmically(hrv: Double, heartRate: Double, breathingRate: Double) -> BioStatePrediction {
        // Calculate coherence (simplified formula)
        let coherence = min(1.0, hrv / 100.0 * (1.0 - abs(breathingRate - 6.0) / 10.0))

        let state: BioState
        let confidence: Double

        if coherence > 0.8 && heartRate < 75 {
            state = .deepRelaxation
            confidence = min(1.0, coherence * 1.1)
        } else if coherence > 0.6 {
            state = .calm
            confidence = coherence
        } else if heartRate > 100 {
            state = .stressed
            confidence = min(1.0, Double(heartRate - 100) / 30.0)
        } else if hrv < 30 {
            state = .fatigued
            confidence = 1.0 - (hrv / 30.0)
        } else if heartRate > 80 && heartRate < 100 {
            state = .focused
            confidence = 0.7
        } else {
            state = .balanced
            confidence = 0.5
        }

        return BioStatePrediction(state: state, confidence: confidence)
    }
}

// MARK: - Bio State Types

enum BioState: Int, CaseIterable {
    case stressed = 0
    case fatigued = 1
    case balanced = 2
    case focused = 3
    case calm = 4
    case deepRelaxation = 5

    var displayName: String {
        switch self {
        case .stressed: return "Stressed"
        case .fatigued: return "Fatigued"
        case .balanced: return "Balanced"
        case .focused: return "Focused"
        case .calm: return "Calm"
        case .deepRelaxation: return "Deep Relaxation"
        }
    }

    var suggestedAudioStyle: MusicStyle {
        switch self {
        case .stressed: return .calm
        case .fatigued: return .uplifting
        case .balanced: return .balanced
        case .focused: return .balanced
        case .calm: return .meditative
        case .deepRelaxation: return .meditative
        }
    }
}

struct BioStatePrediction {
    let state: BioState
    let confidence: Double

    var isHighConfidence: Bool {
        confidence > 0.7
    }
}
