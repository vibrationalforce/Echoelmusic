//
// MLModelManager.swift
// Echoelmusic
//
// Comprehensive ML Model Management System
// Handles model loading, versioning, downloads, validation, and inference
//
// Created: 2026-01-07
// Phase: 10000 ULTIMATE LOOP MODE - Production ML Infrastructure
//

import Foundation
import CoreML
import Combine
import CryptoKit

#if os(iOS) || os(macOS) || os(visionOS)
import Vision
#endif

// MARK: - ML Model Errors

enum MLModelError: Error, LocalizedError {
    case modelNotFound(EchoelmusicMLModels)
    case modelLoadFailed(EchoelmusicMLModels, Error)
    case invalidChecksum(expected: String, actual: String)
    case downloadFailed(Error)
    case unsupportedPlatform
    case insufficientMemory(required: UInt64, available: UInt64)
    case modelVersionMismatch(expected: String, actual: String)
    case invalidModelFormat
    case inferenceError(Error)
    case modelNotLoaded(EchoelmusicMLModels)
    case batchProcessingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .modelNotFound(let model):
            return "ML model not found: \(model.rawValue)"
        case .modelLoadFailed(let model, let error):
            return "Failed to load model \(model.rawValue): \(error.localizedDescription)"
        case .invalidChecksum(let expected, let actual):
            return "Model checksum validation failed. Expected: \(expected), Got: \(actual)"
        case .downloadFailed(let error):
            return "Model download failed: \(error.localizedDescription)"
        case .unsupportedPlatform:
            return "ML models not supported on this platform"
        case .insufficientMemory(let required, let available):
            return "Insufficient memory. Required: \(required) bytes, Available: \(available) bytes"
        case .modelVersionMismatch(let expected, let actual):
            return "Model version mismatch. Expected: \(expected), Got: \(actual)"
        case .invalidModelFormat:
            return "Invalid model format or corrupted file"
        case .inferenceError(let error):
            return "Model inference failed: \(error.localizedDescription)"
        case .modelNotLoaded(let model):
            return "Model not loaded: \(model.rawValue)"
        case .batchProcessingFailed(let error):
            return "Batch processing failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Echoelmusic ML Models

enum EchoelmusicMLModels: String, CaseIterable {
    case soundStyleTransfer = "sound_style_transfer"
    case voiceToMIDI = "voice_to_midi"
    case emotionRecognition = "emotion_recognition"
    case hrvCoherencePredictor = "hrv_coherence_predictor"
    case musicGeneration = "music_generation"
    case visualStyleTransfer = "visual_style_transfer"
    case gestureRecognition = "gesture_recognition"
    case breathingPatternAnalysis = "breathing_pattern_analysis"

    var displayName: String {
        switch self {
        case .soundStyleTransfer: return "AI Sound Designer"
        case .voiceToMIDI: return "Voice to MIDI Converter"
        case .emotionRecognition: return "Emotion Recognition"
        case .hrvCoherencePredictor: return "HRV Coherence Predictor"
        case .musicGeneration: return "AI Music Composer"
        case .visualStyleTransfer: return "Visual Style Transfer"
        case .gestureRecognition: return "Gesture Recognition"
        case .breathingPatternAnalysis: return "Breathing Pattern Analyzer"
        }
    }

    var description: String {
        switch self {
        case .soundStyleTransfer:
            return "Transform audio with AI-powered style transfer"
        case .voiceToMIDI:
            return "Convert vocal pitch to MIDI notes in real-time"
        case .emotionRecognition:
            return "Detect emotions from facial expressions"
        case .hrvCoherencePredictor:
            return "Predict coherence trends from HRV data"
        case .musicGeneration:
            return "Generate original music compositions"
        case .visualStyleTransfer:
            return "Apply artistic styles to visual content"
        case .gestureRecognition:
            return "Recognize hand gestures for control"
        case .breathingPatternAnalysis:
            return "Analyze breathing patterns for wellness insights"
        }
    }
}

// MARK: - ML Model Configuration

struct EchoelMLModelConfiguration {
    let modelType: EchoelmusicMLModels
    let version: String
    let localURL: URL?
    let remoteURL: URL?
    let checksum: String
    let computeUnits: MLComputeUnits
    let memoryRequirements: UInt64 // bytes
    let minimumIOSVersion: String
    let minimumMacOSVersion: String
    let supportsBatchProcessing: Bool
    let maxBatchSize: Int
    let inputDimensions: [String: [Int]]
    let outputDimensions: [String: [Int]]

    /// Returns nil if documents directory is inaccessible (shouldn't happen on iOS/macOS)
    static func defaultConfiguration(for model: EchoelmusicMLModels) -> EchoelMLModelConfiguration {
        // Use fallback to temporary directory if documents unavailable
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let modelsPath = documentsPath.appendingPathComponent("MLModels", isDirectory: true)

        switch model {
        case .soundStyleTransfer:
            return EchoelMLModelConfiguration(
                modelType: model,
                version: "1.0.0",
                localURL: modelsPath.appendingPathComponent("SoundStyleTransfer.mlmodelc"),
                remoteURL: URL(string: "https://models.echoelmusic.com/sound_style_transfer_v1.mlmodelc.zip"),
                checksum: "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6",
                computeUnits: .cpuAndNeuralEngine,
                memoryRequirements: 150_000_000, // 150MB
                minimumIOSVersion: "15.0",
                minimumMacOSVersion: "12.0",
                supportsBatchProcessing: true,
                maxBatchSize: 8,
                inputDimensions: ["audio_input": [1, 44100]],
                outputDimensions: ["audio_output": [1, 44100]]
            )

        case .voiceToMIDI:
            return EchoelMLModelConfiguration(
                modelType: model,
                version: "1.2.0",
                localURL: modelsPath.appendingPathComponent("VoiceToMIDI.mlmodelc"),
                remoteURL: URL(string: "https://models.echoelmusic.com/voice_to_midi_v1.2.mlmodelc.zip"),
                checksum: "b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7",
                computeUnits: .cpuAndNeuralEngine,
                memoryRequirements: 80_000_000, // 80MB
                minimumIOSVersion: "15.0",
                minimumMacOSVersion: "12.0",
                supportsBatchProcessing: true,
                maxBatchSize: 16,
                inputDimensions: ["audio_frames": [1, 2048]],
                outputDimensions: ["midi_note": [1], "confidence": [1]]
            )

        case .emotionRecognition:
            return EchoelMLModelConfiguration(
                modelType: model,
                version: "2.0.0",
                localURL: modelsPath.appendingPathComponent("EmotionRecognition.mlmodelc"),
                remoteURL: URL(string: "https://models.echoelmusic.com/emotion_recognition_v2.mlmodelc.zip"),
                checksum: "c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8",
                computeUnits: .cpuAndNeuralEngine,
                memoryRequirements: 120_000_000, // 120MB
                minimumIOSVersion: "15.0",
                minimumMacOSVersion: "12.0",
                supportsBatchProcessing: true,
                maxBatchSize: 4,
                inputDimensions: ["face_landmarks": [1, 468, 3]],
                outputDimensions: ["emotion_probabilities": [1, 7]]
            )

        case .hrvCoherencePredictor:
            return EchoelMLModelConfiguration(
                modelType: model,
                version: "1.1.0",
                localURL: modelsPath.appendingPathComponent("HRVCoherencePredictor.mlmodelc"),
                remoteURL: URL(string: "https://models.echoelmusic.com/hrv_coherence_v1.1.mlmodelc.zip"),
                checksum: "d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9",
                computeUnits: .cpuAndNeuralEngine,
                memoryRequirements: 50_000_000, // 50MB
                minimumIOSVersion: "15.0",
                minimumMacOSVersion: "12.0",
                supportsBatchProcessing: true,
                maxBatchSize: 32,
                inputDimensions: ["hrv_sequence": [1, 60]],
                outputDimensions: ["coherence_prediction": [1], "trend": [1]]
            )

        case .musicGeneration:
            return EchoelMLModelConfiguration(
                modelType: model,
                version: "1.5.0",
                localURL: modelsPath.appendingPathComponent("MusicGeneration.mlmodelc"),
                remoteURL: URL(string: "https://models.echoelmusic.com/music_generation_v1.5.mlmodelc.zip"),
                checksum: "e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0",
                computeUnits: .all,
                memoryRequirements: 300_000_000, // 300MB
                minimumIOSVersion: "16.0",
                minimumMacOSVersion: "13.0",
                supportsBatchProcessing: false,
                maxBatchSize: 1,
                inputDimensions: ["seed_notes": [1, 16], "style_embedding": [1, 128]],
                outputDimensions: ["generated_audio": [1, 88200]]
            )

        case .visualStyleTransfer:
            return EchoelMLModelConfiguration(
                modelType: model,
                version: "2.1.0",
                localURL: modelsPath.appendingPathComponent("VisualStyleTransfer.mlmodelc"),
                remoteURL: URL(string: "https://models.echoelmusic.com/visual_style_v2.1.mlmodelc.zip"),
                checksum: "f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1",
                computeUnits: .cpuAndGPU,
                memoryRequirements: 200_000_000, // 200MB
                minimumIOSVersion: "15.0",
                minimumMacOSVersion: "12.0",
                supportsBatchProcessing: true,
                maxBatchSize: 4,
                inputDimensions: ["content_image": [1, 512, 512, 3], "style_vector": [1, 256]],
                outputDimensions: ["stylized_image": [1, 512, 512, 3]]
            )

        case .gestureRecognition:
            return EchoelMLModelConfiguration(
                modelType: model,
                version: "1.3.0",
                localURL: modelsPath.appendingPathComponent("GestureRecognition.mlmodelc"),
                remoteURL: URL(string: "https://models.echoelmusic.com/gesture_recognition_v1.3.mlmodelc.zip"),
                checksum: "g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2",
                computeUnits: .cpuAndNeuralEngine,
                memoryRequirements: 90_000_000, // 90MB
                minimumIOSVersion: "15.0",
                minimumMacOSVersion: "12.0",
                supportsBatchProcessing: true,
                maxBatchSize: 8,
                inputDimensions: ["hand_landmarks": [1, 21, 3], "temporal_sequence": [1, 30, 63]],
                outputDimensions: ["gesture_class": [1], "gesture_confidence": [1]]
            )

        case .breathingPatternAnalysis:
            return EchoelMLModelConfiguration(
                modelType: model,
                version: "1.0.0",
                localURL: modelsPath.appendingPathComponent("BreathingPatternAnalysis.mlmodelc"),
                remoteURL: URL(string: "https://models.echoelmusic.com/breathing_pattern_v1.mlmodelc.zip"),
                checksum: "h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3",
                computeUnits: .cpuAndNeuralEngine,
                memoryRequirements: 60_000_000, // 60MB
                minimumIOSVersion: "15.0",
                minimumMacOSVersion: "12.0",
                supportsBatchProcessing: true,
                maxBatchSize: 16,
                inputDimensions: ["breathing_waveform": [1, 120]],
                outputDimensions: ["breathing_rate": [1], "pattern_type": [1], "coherence": [1]]
            )
        }
    }
}

// MARK: - ML Model Cache Entry

private struct MLModelCacheEntry {
    let model: MLModel
    let configuration: EchoelMLModelConfiguration
    let loadedAt: Date
    var lastAccessedAt: Date
    var accessCount: Int

    var memoryFootprint: UInt64 {
        configuration.memoryRequirements
    }
}

// MARK: - ML Model Cache

@MainActor
class MLModelCache {
    static let shared = MLModelCache()

    private var cache: [EchoelmusicMLModels: MLModelCacheEntry] = [:]
    private let maxCacheSize: UInt64 = 800_000_000 // 800MB max cache
    private let maxIdleTime: TimeInterval = 600 // 10 minutes

    var totalMemoryUsage: UInt64 {
        cache.values.reduce(0) { $0 + $1.memoryFootprint }
    }

    var cachedModels: [EchoelmusicMLModels] {
        Array(cache.keys)
    }

    func get(_ modelType: EchoelmusicMLModels) -> MLModel? {
        guard var entry = cache[modelType] else { return nil }

        // Update access time and count
        entry.lastAccessedAt = Date()
        entry.accessCount += 1
        cache[modelType] = entry

        return entry.model
    }

    func set(_ model: MLModel, configuration: EchoelMLModelConfiguration) {
        let entry = MLModelCacheEntry(
            model: model,
            configuration: configuration,
            loadedAt: Date(),
            lastAccessedAt: Date(),
            accessCount: 1
        )

        cache[configuration.modelType] = entry

        // Evict if over memory limit
        evictIfNeeded()
    }

    func remove(_ modelType: EchoelmusicMLModels) {
        cache.removeValue(forKey: modelType)
    }

    func clearAll() {
        cache.removeAll()
    }

    private func evictIfNeeded() {
        while totalMemoryUsage > maxCacheSize && !cache.isEmpty {
            // Find least recently used model
            let lru = cache.min { a, b in
                a.value.lastAccessedAt < b.value.lastAccessedAt
            }

            if let lru = lru {
                cache.removeValue(forKey: lru.key)
            }
        }
    }

    func evictIdleModels() {
        let now = Date()
        let keysToRemove = cache.filter { _, entry in
            now.timeIntervalSince(entry.lastAccessedAt) > maxIdleTime
        }.map { $0.key }

        keysToRemove.forEach { cache.removeValue(forKey: $0) }
    }
}

// MARK: - Download Progress

struct MLModelDownloadProgress {
    let modelType: EchoelmusicMLModels
    let bytesDownloaded: Int64
    let totalBytes: Int64
    let percentage: Double
    let estimatedTimeRemaining: TimeInterval?

    var isComplete: Bool {
        bytesDownloaded >= totalBytes
    }
}

// MARK: - ML Model Download Manager

actor MLModelDownloadManager {
    static let shared = MLModelDownloadManager()

    private var activeDownloads: [EchoelmusicMLModels: URLSessionDownloadTask] = [:]
    private var downloadProgress: [EchoelmusicMLModels: MLModelDownloadProgress] = [:]

    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 600
        return URLSession(configuration: config, delegate: nil, delegateQueue: nil)
    }()

    func downloadModel(
        configuration: EchoelMLModelConfiguration,
        progressHandler: @escaping @Sendable (MLModelDownloadProgress) -> Void
    ) async throws -> URL {
        guard let remoteURL = configuration.remoteURL else {
            throw MLModelError.downloadFailed(NSError(domain: "MLModelDownload", code: -1, userInfo: [NSLocalizedDescriptionKey: "No remote URL configured"]))
        }

        // Cancel existing download if any
        await cancelDownload(for: configuration.modelType)

        let (localURL, response) = try await urlSession.download(from: remoteURL)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MLModelError.downloadFailed(NSError(domain: "MLModelDownload", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"]))
        }

        // Move to permanent location (fallback to temp if documents unavailable)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let modelsPath = documentsPath.appendingPathComponent("MLModels", isDirectory: true)

        try? FileManager.default.createDirectory(at: modelsPath, withIntermediateDirectories: true)

        let destinationURL = modelsPath.appendingPathComponent("\(configuration.modelType.rawValue)_v\(configuration.version).mlmodelc")

        // Remove existing file if present
        try? FileManager.default.removeItem(at: destinationURL)

        // Move downloaded file
        try FileManager.default.moveItem(at: localURL, to: destinationURL)

        // Validate checksum
        try await validateChecksum(fileURL: destinationURL, expectedChecksum: configuration.checksum)

        return destinationURL
    }

    func cancelDownload(for modelType: EchoelmusicMLModels) {
        activeDownloads[modelType]?.cancel()
        activeDownloads.removeValue(forKey: modelType)
        downloadProgress.removeValue(forKey: modelType)
    }

    func getProgress(for modelType: EchoelmusicMLModels) -> MLModelDownloadProgress? {
        downloadProgress[modelType]
    }

    private func validateChecksum(fileURL: URL, expectedChecksum: String) async throws {
        let data = try Data(contentsOf: fileURL)
        let hash = SHA256.hash(data: data)
        let actualChecksum = hash.compactMap { String(format: "%02x", $0) }.joined()

        guard actualChecksum.prefix(32) == expectedChecksum.prefix(32) else {
            throw MLModelError.invalidChecksum(expected: expectedChecksum, actual: actualChecksum)
        }
    }
}

// MARK: - ML Performance Metrics

struct MLPerformanceMetrics {
    let modelType: EchoelmusicMLModels
    let inferenceTime: TimeInterval
    let preprocessingTime: TimeInterval
    let postprocessingTime: TimeInterval
    let totalTime: TimeInterval
    let timestamp: Date
    let batchSize: Int

    var throughput: Double {
        guard totalTime > 0 else { return 0 }
        return Double(batchSize) / totalTime
    }
}

// MARK: - ML Model Performance Monitor

actor MLModelPerformanceMonitor {
    static let shared = MLModelPerformanceMonitor()

    private var metrics: [EchoelmusicMLModels: [MLPerformanceMetrics]] = [:]
    private let maxMetricsPerModel = 100

    func recordMetrics(_ metrics: MLPerformanceMetrics) {
        var modelMetrics = self.metrics[metrics.modelType] ?? []
        modelMetrics.append(metrics)

        // Keep only recent metrics
        if modelMetrics.count > maxMetricsPerModel {
            modelMetrics.removeFirst(modelMetrics.count - maxMetricsPerModel)
        }

        self.metrics[metrics.modelType] = modelMetrics
    }

    func getMetrics(for modelType: EchoelmusicMLModels) -> [MLPerformanceMetrics] {
        metrics[modelType] ?? []
    }

    func getAverageInferenceTime(for modelType: EchoelmusicMLModels) -> TimeInterval? {
        guard let modelMetrics = metrics[modelType], !modelMetrics.isEmpty else { return nil }
        let total = modelMetrics.reduce(0.0) { $0 + $1.inferenceTime }
        return total / Double(modelMetrics.count)
    }

    func getAverageThroughput(for modelType: EchoelmusicMLModels) -> Double? {
        guard let modelMetrics = metrics[modelType], !modelMetrics.isEmpty else { return nil }
        let total = modelMetrics.reduce(0.0) { $0 + $1.throughput }
        return total / Double(modelMetrics.count)
    }

    func clearMetrics(for modelType: EchoelmusicMLModels) {
        metrics.removeValue(forKey: modelType)
    }

    func clearAllMetrics() {
        metrics.removeAll()
    }
}

// MARK: - ML Inference Result

struct MLInferenceResult {
    let modelType: EchoelmusicMLModels
    let output: MLFeatureProvider
    let metrics: MLPerformanceMetrics
    let metadata: [String: Any]

    func getValue<T>(for key: String) -> T? {
        if let feature = output.featureValue(for: key) {
            return feature.value as? T
        }
        return metadata[key] as? T
    }

    func getArray(for key: String) -> MLMultiArray? {
        output.featureValue(for: key)?.multiArrayValue
    }

    func getDouble(for key: String) -> Double? {
        output.featureValue(for: key)?.doubleValue
    }

    func getInt(for key: String) -> Int? {
        guard let value = output.featureValue(for: key)?.int64Value else { return nil }
        return Int(value)
    }
}

// MARK: - ML Inference Engine

@MainActor
class MLInferenceEngine {
    static let shared = MLInferenceEngine()

    private let performanceMonitor = MLModelPerformanceMonitor.shared

    func predict(
        modelType: EchoelmusicMLModels,
        input: MLFeatureProvider,
        metadata: [String: Any] = [:]
    ) async throws -> MLInferenceResult {
        let startTime = Date()

        // Get model from manager
        guard let model = await MLModelManager.shared.getLoadedModel(modelType) else {
            throw MLModelError.modelNotLoaded(modelType)
        }

        let preprocessingTime = Date().timeIntervalSince(startTime)
        let inferenceStart = Date()

        // Run prediction
        let output = try model.prediction(from: input)

        let inferenceTime = Date().timeIntervalSince(inferenceStart)
        let postprocessingStart = Date()

        // Any post-processing would go here

        let postprocessingTime = Date().timeIntervalSince(postprocessingStart)
        let totalTime = Date().timeIntervalSince(startTime)

        // Record metrics
        let metrics = MLPerformanceMetrics(
            modelType: modelType,
            inferenceTime: inferenceTime,
            preprocessingTime: preprocessingTime,
            postprocessingTime: postprocessingTime,
            totalTime: totalTime,
            timestamp: Date(),
            batchSize: 1
        )

        await performanceMonitor.recordMetrics(metrics)

        return MLInferenceResult(
            modelType: modelType,
            output: output,
            metrics: metrics,
            metadata: metadata
        )
    }

    func batchPredict(
        modelType: EchoelmusicMLModels,
        inputs: [MLFeatureProvider],
        metadata: [String: Any] = [:]
    ) async throws -> [MLInferenceResult] {
        guard let model = await MLModelManager.shared.getLoadedModel(modelType) else {
            throw MLModelError.modelNotLoaded(modelType)
        }

        let configuration = await MLModelManager.shared.getConfiguration(for: modelType)

        guard configuration?.supportsBatchProcessing == true else {
            // Fall back to sequential processing
            var results: [MLInferenceResult] = []
            for input in inputs {
                let result = try await predict(modelType: modelType, input: input, metadata: metadata)
                results.append(result)
            }
            return results
        }

        let maxBatchSize = configuration?.maxBatchSize ?? 1
        var allResults: [MLInferenceResult] = []

        // Process in batches
        for batchStart in stride(from: 0, to: inputs.count, by: maxBatchSize) {
            let batchEnd = min(batchStart + maxBatchSize, inputs.count)
            let batch = Array(inputs[batchStart..<batchEnd])

            let startTime = Date()

            // Process batch
            var batchResults: [MLInferenceResult] = []
            for input in batch {
                let output = try model.prediction(from: input)
                let totalTime = Date().timeIntervalSince(startTime)

                let metrics = MLPerformanceMetrics(
                    modelType: modelType,
                    inferenceTime: totalTime,
                    preprocessingTime: 0,
                    postprocessingTime: 0,
                    totalTime: totalTime,
                    timestamp: Date(),
                    batchSize: batch.count
                )

                await performanceMonitor.recordMetrics(metrics)

                let result = MLInferenceResult(
                    modelType: modelType,
                    output: output,
                    metrics: metrics,
                    metadata: metadata
                )
                batchResults.append(result)
            }

            allResults.append(contentsOf: batchResults)
        }

        return allResults
    }
}

// MARK: - ML Model Manager

@MainActor
class MLModelManager {
    static let shared = MLModelManager()

    private let cache = MLModelCache.shared
    private let downloadManager = MLModelDownloadManager.shared
    private var configurations: [EchoelmusicMLModels: EchoelMLModelConfiguration] = [:]
    private var loadingTasks: [EchoelmusicMLModels: Task<MLModel, Error>] = [:]

    // Publishers for SwiftUI/Combine
    @Published private(set) var loadedModels: Set<EchoelmusicMLModels> = []
    @Published private(set) var downloadProgress: [EchoelmusicMLModels: MLModelDownloadProgress] = [:]

    private init() {
        // Load default configurations
        for modelType in EchoelmusicMLModels.allCases {
            configurations[modelType] = EchoelMLModelConfiguration.defaultConfiguration(for: modelType)
        }

        // Start idle model eviction timer
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
                await cache.evictIdleModels()
            }
        }
    }

    // MARK: - Model Configuration

    func getConfiguration(for modelType: EchoelmusicMLModels) -> EchoelMLModelConfiguration? {
        configurations[modelType]
    }

    func setConfiguration(_ configuration: EchoelMLModelConfiguration) {
        configurations[configuration.modelType] = configuration
    }

    // MARK: - Model Loading

    func loadModel(_ modelType: EchoelmusicMLModels, forceReload: Bool = false) async throws -> MLModel {
        // Check cache first
        if !forceReload, let cachedModel = cache.get(modelType) {
            return cachedModel
        }

        // Check if already loading
        if let existingTask = loadingTasks[modelType] {
            return try await existingTask.value
        }

        // Start loading
        let loadTask = Task<MLModel, Error> {
            defer { loadingTasks.removeValue(forKey: modelType) }

            guard let configuration = configurations[modelType] else {
                throw MLModelError.modelNotFound(modelType)
            }

            // Check platform compatibility
            try checkPlatformCompatibility(configuration)

            // Check memory availability
            try checkMemoryAvailability(configuration)

            var modelURL = configuration.localURL

            // Download if not available locally
            let needsDownload: Bool
            if let localPath = modelURL?.path {
                needsDownload = !FileManager.default.fileExists(atPath: localPath)
            } else {
                needsDownload = true
            }

            if needsDownload {
                modelURL = try await downloadModel(configuration)
            }

            guard let finalURL = modelURL else {
                throw MLModelError.modelNotFound(modelType)
            }

            // Validate model file
            try validateModelFile(at: finalURL, configuration: configuration)

            // Compile if needed (for .mlmodel files)
            let compiledURL = try await compileModelIfNeeded(at: finalURL)

            // Load model
            let mlConfig = CoreML.MLModelConfiguration()
            mlConfig.computeUnits = configuration.computeUnits

            do {
                let model = try MLModel(contentsOf: compiledURL, configuration: mlConfig)

                // Cache the model
                cache.set(model, configuration: configuration)
                loadedModels.insert(modelType)

                return model
            } catch {
                throw MLModelError.modelLoadFailed(modelType, error)
            }
        }

        loadingTasks[modelType] = loadTask
        return try await loadTask.value
    }

    func unloadModel(_ modelType: EchoelmusicMLModels) {
        cache.remove(modelType)
        loadedModels.remove(modelType)
        loadingTasks[modelType]?.cancel()
        loadingTasks.removeValue(forKey: modelType)
    }

    func unloadAllModels() {
        cache.clearAll()
        loadedModels.removeAll()
        loadingTasks.values.forEach { $0.cancel() }
        loadingTasks.removeAll()
    }

    func getLoadedModel(_ modelType: EchoelmusicMLModels) -> MLModel? {
        cache.get(modelType)
    }

    func isModelLoaded(_ modelType: EchoelmusicMLModels) -> Bool {
        cache.get(modelType) != nil
    }

    // MARK: - Model Download

    private func downloadModel(_ configuration: EchoelMLModelConfiguration) async throws -> URL {
        return try await downloadManager.downloadModel(configuration: configuration) { [weak self] progress in
            Task { @MainActor [weak self] in
                self?.downloadProgress[configuration.modelType] = progress
            }
        }
    }

    func cancelDownload(for modelType: EchoelmusicMLModels) async {
        await downloadManager.cancelDownload(for: modelType)
        downloadProgress.removeValue(forKey: modelType)
    }

    // MARK: - Validation

    private func checkPlatformCompatibility(_ configuration: EchoelMLModelConfiguration) throws {
        #if os(iOS)
        let currentVersion = ProcessInfo.processInfo.operatingSystemVersion
        let minimumVersion = parseVersion(configuration.minimumIOSVersion)
        guard currentVersion.majorVersion >= minimumVersion.major &&
              currentVersion.minorVersion >= minimumVersion.minor else {
            throw MLModelError.unsupportedPlatform
        }
        #elseif os(macOS)
        let currentVersion = ProcessInfo.processInfo.operatingSystemVersion
        let minimumVersion = parseVersion(configuration.minimumMacOSVersion)
        guard currentVersion.majorVersion >= minimumVersion.major &&
              currentVersion.minorVersion >= minimumVersion.minor else {
            throw MLModelError.unsupportedPlatform
        }
        #endif
    }

    private func checkMemoryAvailability(_ configuration: EchoelMLModelConfiguration) throws {
        let available = ProcessInfo.processInfo.physicalMemory
        let required = configuration.memoryRequirements

        // Ensure at least 1.5x required memory is available
        guard available > required * 3 / 2 else {
            throw MLModelError.insufficientMemory(required: required, available: available)
        }
    }

    private func validateModelFile(at url: URL, configuration: EchoelMLModelConfiguration) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw MLModelError.modelNotFound(configuration.modelType)
        }

        // Validate file is not corrupted (basic check)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? UInt64,
              fileSize > 1000 else { // At least 1KB
            throw MLModelError.invalidModelFormat
        }
    }

    private func compileModelIfNeeded(at url: URL) async throws -> URL {
        // If already compiled (.mlmodelc), return as-is
        if url.pathExtension == "mlmodelc" {
            return url
        }

        // Compile .mlmodel to .mlmodelc
        if url.pathExtension == "mlmodel" {
            let compiledURL = try MLModel.compileModel(at: url)
            return compiledURL
        }

        return url
    }

    private func parseVersion(_ versionString: String) -> (major: Int, minor: Int, patch: Int) {
        let components = versionString.split(separator: ".").compactMap { Int($0) }
        return (
            major: components.count > 0 ? components[0] : 0,
            minor: components.count > 1 ? components[1] : 0,
            patch: components.count > 2 ? components[2] : 0
        )
    }

    // MARK: - Cache Management

    var totalCacheMemoryUsage: UInt64 {
        cache.totalMemoryUsage
    }

    var cachedModelTypes: [EchoelmusicMLModels] {
        cache.cachedModels
    }

    func clearCache() {
        cache.clearAll()
        loadedModels.removeAll()
    }

    // MARK: - Batch Operations

    func loadModels(_ modelTypes: [EchoelmusicMLModels]) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for modelType in modelTypes {
                group.addTask {
                    _ = try await self.loadModel(modelType)
                }
            }
            try await group.waitForAll()
        }
    }

    func preloadCriticalModels() async {
        // Load most commonly used models
        let criticalModels: [EchoelmusicMLModels] = [
            .voiceToMIDI,
            .gestureRecognition,
            .hrvCoherencePredictor
        ]

        for modelType in criticalModels {
            do {
                try await loadModel(modelType)
            } catch {
                log.warning("⚠️ Failed to preload critical model \(modelType): \(error.localizedDescription)")
                // Continue loading other models - don't fail entire preload
            }
        }
    }
}

// MARK: - Convenience Extensions

extension MLModelManager {
    /// Quick access to specific model predictions

    func predictVoiceToMIDI(audioFrames: MLMultiArray) async throws -> (note: Int, confidence: Double) {
        let input = try MLDictionaryFeatureProvider(dictionary: ["audio_frames": audioFrames])
        let result = try await MLInferenceEngine.shared.predict(modelType: .voiceToMIDI, input: input)

        guard let note = result.getInt(for: "midi_note"),
              let confidence = result.getDouble(for: "confidence") else {
            throw MLModelError.inferenceError(NSError(domain: "MLModelManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid output format"]))
        }

        return (note, confidence)
    }

    func predictHRVCoherence(hrvSequence: [Double]) async throws -> (coherence: Double, trend: Double) {
        let array = try MLMultiArray(shape: [1, NSNumber(value: hrvSequence.count)], dataType: .double)
        for (i, value) in hrvSequence.enumerated() {
            array[i] = NSNumber(value: value)
        }

        let input = try MLDictionaryFeatureProvider(dictionary: ["hrv_sequence": array])
        let result = try await MLInferenceEngine.shared.predict(modelType: .hrvCoherencePredictor, input: input)

        guard let coherence = result.getDouble(for: "coherence_prediction"),
              let trend = result.getDouble(for: "trend") else {
            throw MLModelError.inferenceError(NSError(domain: "MLModelManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid output format"]))
        }

        return (coherence, trend)
    }

    func predictBreathingPattern(waveform: [Float]) async throws -> (rate: Double, patternType: Int, coherence: Double) {
        let array = try MLMultiArray(shape: [1, NSNumber(value: waveform.count)], dataType: .float32)
        for (i, value) in waveform.enumerated() {
            array[i] = NSNumber(value: value)
        }

        let input = try MLDictionaryFeatureProvider(dictionary: ["breathing_waveform": array])
        let result = try await MLInferenceEngine.shared.predict(modelType: .breathingPatternAnalysis, input: input)

        guard let rate = result.getDouble(for: "breathing_rate"),
              let patternType = result.getInt(for: "pattern_type"),
              let coherence = result.getDouble(for: "coherence") else {
            throw MLModelError.inferenceError(NSError(domain: "MLModelManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid output format"]))
        }

        return (rate, patternType, coherence)
    }
}
