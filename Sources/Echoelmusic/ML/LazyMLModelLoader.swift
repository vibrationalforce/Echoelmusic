import Foundation
#if canImport(CoreML)
import CoreML
#endif

// MARK: - Lazy ML Model Loader
// On-demand loading of ML models with memory management
// Supports: Lazy loading, LRU cache, background compilation, memory pressure handling

@MainActor
public final class LazyMLModelLoader: ObservableObject {
    public static let shared = LazyMLModelLoader()

    @Published public private(set) var loadedModels: Set<String> = []
    @Published public private(set) var memoryUsageMB: Double = 0
    @Published public private(set) var isCompiling = false

    // Model cache with LRU eviction
    private var modelCache: LRUCache<String, MLModelWrapper>

    // Loading state
    private var loadingTasks: [String: Task<MLModelWrapper, Error>] = [:]

    // Configuration
    public struct Configuration {
        public var maxCachedModels: Int = 5
        public var maxMemoryMB: Double = 500
        public var precompileOnLoad: Bool = true
        public var useBackgroundCompilation: Bool = true
        public var evictionPolicy: EvictionPolicy = .lru

        public enum EvictionPolicy {
            case lru      // Least Recently Used
            case lfu      // Least Frequently Used
            case fifo     // First In First Out
            case size     // Largest first
        }

        public static let `default` = Configuration()
        public static let lowMemory = Configuration(maxCachedModels: 2, maxMemoryMB: 200)
        public static let highPerformance = Configuration(maxCachedModels: 10, maxMemoryMB: 1000)
    }

    private var config: Configuration = .default

    // Model registry
    private var modelRegistry: [String: ModelRegistration] = [:]

    public init() {
        self.modelCache = LRUCache(maxSize: 5)
        setupMemoryPressureHandling()
        registerBuiltInModels()
    }

    // MARK: - Model Registration

    /// Register a model for lazy loading
    public func register(
        name: String,
        modelURL: URL,
        compiledURL: URL? = nil,
        estimatedSizeMB: Double = 50,
        priority: ModelPriority = .normal
    ) {
        modelRegistry[name] = ModelRegistration(
            name: name,
            modelURL: modelURL,
            compiledURL: compiledURL,
            estimatedSizeMB: estimatedSizeMB,
            priority: priority
        )
    }

    private func registerBuiltInModels() {
        // Register built-in Echoelmusic models
        let modelNames = [
            "AudioClassifier",
            "MoodDetector",
            "GenreClassifier",
            "BeatTracker",
            "PitchDetector",
            "StemSeparator",
            "MelodyGenerator",
            "HarmonyAnalyzer"
        ]

        for name in modelNames {
            if let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc") {
                register(name: name, modelURL: url, estimatedSizeMB: 50)
            }
        }
    }

    // MARK: - Model Loading

    /// Get a model, loading it lazily if needed
    public func getModel(_ name: String) async throws -> MLModelWrapper {
        // Check cache first
        if let cached = modelCache.get(name) {
            loadedModels.insert(name)
            return cached
        }

        // Check if already loading
        if let existingTask = loadingTasks[name] {
            return try await existingTask.value
        }

        // Start loading
        let task = Task<MLModelWrapper, Error> {
            try await loadModel(name)
        }

        loadingTasks[name] = task

        do {
            let model = try await task.value
            loadingTasks.removeValue(forKey: name)
            return model
        } catch {
            loadingTasks.removeValue(forKey: name)
            throw error
        }
    }

    /// Preload models in background
    public func preload(_ modelNames: [String]) async {
        await withTaskGroup(of: Void.self) { group in
            for name in modelNames {
                group.addTask {
                    _ = try? await self.getModel(name)
                }
            }
        }
    }

    private func loadModel(_ name: String) async throws -> MLModelWrapper {
        guard let registration = modelRegistry[name] else {
            throw MLModelError.modelNotRegistered(name)
        }

        // Check memory before loading
        try await ensureMemoryAvailable(for: registration)

        isCompiling = true
        defer { isCompiling = false }

        #if canImport(CoreML)
        let model: MLModel

        if let compiledURL = registration.compiledURL,
           FileManager.default.fileExists(atPath: compiledURL.path) {
            // Load pre-compiled model
            model = try MLModel(contentsOf: compiledURL)
        } else {
            // Compile on demand
            if config.useBackgroundCompilation {
                model = try await compileModelInBackground(registration)
            } else {
                let compiledURL = try MLModel.compileModel(at: registration.modelURL)
                model = try MLModel(contentsOf: compiledURL)
            }
        }

        let wrapper = MLModelWrapper(
            name: name,
            model: model,
            sizeMB: registration.estimatedSizeMB
        )

        // Add to cache
        modelCache.set(name, wrapper)
        loadedModels.insert(name)
        updateMemoryUsage()

        return wrapper
        #else
        throw MLModelError.coreMLNotAvailable
        #endif
    }

    #if canImport(CoreML)
    private func compileModelInBackground(_ registration: ModelRegistration) async throws -> MLModel {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let compiledURL = try MLModel.compileModel(at: registration.modelURL)
                    let model = try MLModel(contentsOf: compiledURL)
                    continuation.resume(returning: model)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    #endif

    // MARK: - Memory Management

    private func ensureMemoryAvailable(for registration: ModelRegistration) async throws {
        let requiredMB = registration.estimatedSizeMB
        let availableMB = config.maxMemoryMB - memoryUsageMB

        if requiredMB > availableMB {
            // Need to evict models
            await evictModels(toFreeMB: requiredMB - availableMB)
        }

        // Check again after eviction
        if requiredMB > config.maxMemoryMB - memoryUsageMB {
            throw MLModelError.insufficientMemory
        }
    }

    private func evictModels(toFreeMB targetMB: Double) async {
        var freedMB: Double = 0

        switch config.evictionPolicy {
        case .lru:
            while freedMB < targetMB, let (name, model) = modelCache.evictLRU() {
                freedMB += model.sizeMB
                loadedModels.remove(name)
            }

        case .lfu:
            // Evict least frequently used
            while freedMB < targetMB, let (name, model) = modelCache.evictLFU() {
                freedMB += model.sizeMB
                loadedModels.remove(name)
            }

        case .fifo:
            while freedMB < targetMB, let (name, model) = modelCache.evictFIFO() {
                freedMB += model.sizeMB
                loadedModels.remove(name)
            }

        case .size:
            // Evict largest models first
            while freedMB < targetMB, let (name, model) = modelCache.evictLargest() {
                freedMB += model.sizeMB
                loadedModels.remove(name)
            }
        }

        updateMemoryUsage()
    }

    private func setupMemoryPressureHandling() {
        #if os(iOS) || os(macOS)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleMemoryPressure()
            }
        }
        #endif
    }

    private func handleMemoryPressure() async {
        // Evict half of cached models
        let targetEvict = memoryUsageMB / 2
        await evictModels(toFreeMB: targetEvict)
    }

    private func updateMemoryUsage() {
        memoryUsageMB = modelCache.allValues().reduce(0) { $0 + $1.sizeMB }
    }

    /// Unload specific model
    public func unload(_ name: String) {
        modelCache.remove(name)
        loadedModels.remove(name)
        updateMemoryUsage()
    }

    /// Unload all models
    public func unloadAll() {
        modelCache.clear()
        loadedModels.removeAll()
        memoryUsageMB = 0
    }

    public func configure(_ config: Configuration) {
        self.config = config
        modelCache = LRUCache(maxSize: config.maxCachedModels)
    }
}

// MARK: - ML Model Wrapper

public class MLModelWrapper {
    public let name: String
    public let sizeMB: Double
    public var lastUsed: Date = Date()
    public var useCount: Int = 0

    #if canImport(CoreML)
    private let model: MLModel

    public init(name: String, model: MLModel, sizeMB: Double) {
        self.name = name
        self.model = model
        self.sizeMB = sizeMB
    }

    /// Make prediction with automatic usage tracking
    public func predict(input: MLFeatureProvider) throws -> MLFeatureProvider {
        lastUsed = Date()
        useCount += 1
        return try model.prediction(from: input)
    }

    /// Get model description
    public var modelDescription: MLModelDescription {
        model.modelDescription
    }

    /// Batch prediction
    public func predictions(inputs: [MLFeatureProvider]) throws -> [MLFeatureProvider] {
        lastUsed = Date()
        useCount += 1

        return try inputs.map { try model.prediction(from: $0) }
    }
    #else
    public init(name: String, sizeMB: Double) {
        self.name = name
        self.sizeMB = sizeMB
    }
    #endif
}

// MARK: - Model Registration

public struct ModelRegistration {
    public let name: String
    public let modelURL: URL
    public let compiledURL: URL?
    public let estimatedSizeMB: Double
    public let priority: ModelPriority
}

public enum ModelPriority: Int, Comparable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3

    public static func < (lhs: ModelPriority, rhs: ModelPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - LRU Cache

public class LRUCache<Key: Hashable, Value> {
    private var cache: [Key: CacheEntry<Value>] = [:]
    private var accessOrder: [Key] = []
    private let maxSize: Int

    private struct CacheEntry<V> {
        let value: V
        var accessCount: Int
        var insertTime: Date
    }

    public init(maxSize: Int) {
        self.maxSize = maxSize
    }

    public func get(_ key: Key) -> Value? {
        guard let entry = cache[key] else { return nil }

        // Update access order
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
            accessOrder.append(key)
        }

        cache[key]?.accessCount += 1

        return entry.value
    }

    public func set(_ key: Key, _ value: Value) {
        // Remove if exists
        if cache[key] != nil {
            accessOrder.removeAll { $0 == key }
        }

        cache[key] = CacheEntry(value: value, accessCount: 1, insertTime: Date())
        accessOrder.append(key)

        // Evict if over capacity
        while cache.count > maxSize {
            _ = evictLRU()
        }
    }

    public func remove(_ key: Key) {
        cache.removeValue(forKey: key)
        accessOrder.removeAll { $0 == key }
    }

    public func clear() {
        cache.removeAll()
        accessOrder.removeAll()
    }

    public func evictLRU() -> (Key, Value)? {
        guard let key = accessOrder.first else { return nil }
        let value = cache[key]?.value
        remove(key)
        return value.map { (key, $0) }
    }

    public func evictLFU() -> (Key, Value)? {
        guard let (key, entry) = cache.min(by: { $0.value.accessCount < $1.value.accessCount }) else {
            return nil
        }
        let value = entry.value
        remove(key)
        return (key, value)
    }

    public func evictFIFO() -> (Key, Value)? {
        guard let (key, entry) = cache.min(by: { $0.value.insertTime < $1.value.insertTime }) else {
            return nil
        }
        let value = entry.value
        remove(key)
        return (key, value)
    }

    public func evictLargest() -> (Key, Value)? {
        // For this we need Value to have a size property
        // Fall back to LRU
        return evictLRU()
    }

    public func allValues() -> [Value] {
        cache.values.map { $0.value }
    }
}

// MARK: - Errors

public enum MLModelError: Error {
    case modelNotRegistered(String)
    case compilationFailed
    case insufficientMemory
    case predictionFailed
    case coreMLNotAvailable
}

// MARK: - Model Prediction Helpers

#if canImport(CoreML)
extension MLModelWrapper {
    /// Predict with dictionary input
    public func predict(dictionary: [String: Any]) throws -> [String: Any] {
        let provider = try MLDictionaryFeatureProvider(dictionary: dictionary)
        let result = try predict(input: provider)

        var output: [String: Any] = [:]
        for name in result.featureNames {
            if let value = result.featureValue(for: name) {
                output[name] = value.multiArrayValue ?? value.stringValue ?? value.dictionaryValue ?? value.int64Value
            }
        }
        return output
    }

    /// Predict with multi-array input
    public func predict(multiArray: MLMultiArray, inputName: String = "input") throws -> MLMultiArray? {
        let provider = try MLDictionaryFeatureProvider(dictionary: [inputName: multiArray])
        let result = try predict(input: provider)

        // Get first multi-array output
        for name in result.featureNames {
            if let value = result.featureValue(for: name)?.multiArrayValue {
                return value
            }
        }
        return nil
    }

    /// Predict with image input
    public func predict(image: CGImage, inputName: String = "image") throws -> [String: Any] {
        let featureValue = try MLFeatureValue(cgImage: image, pixelsWide: 224, pixelsHigh: 224, pixelFormatType: kCVPixelFormatType_32BGRA, options: nil)
        let provider = try MLDictionaryFeatureProvider(dictionary: [inputName: featureValue])
        let result = try predict(input: provider)

        var output: [String: Any] = [:]
        for name in result.featureNames {
            if let value = result.featureValue(for: name) {
                output[name] = value.multiArrayValue ?? value.stringValue ?? value.dictionaryValue ?? value.int64Value
            }
        }
        return output
    }
}
#endif

// MARK: - Async Model Loading Extensions

extension LazyMLModelLoader {
    /// Load model with timeout
    public func getModel(_ name: String, timeout: TimeInterval) async throws -> MLModelWrapper {
        try await withThrowingTaskGroup(of: MLModelWrapper.self) { group in
            group.addTask {
                try await self.getModel(name)
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw MLModelError.compilationFailed
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    /// Check if model is loaded
    public func isLoaded(_ name: String) -> Bool {
        loadedModels.contains(name)
    }

    /// Get estimated load time
    public func estimatedLoadTime(_ name: String) -> TimeInterval {
        guard let registration = modelRegistry[name] else { return 0 }

        // Rough estimate: 1 second per 50MB
        return registration.estimatedSizeMB / 50.0
    }
}

#if os(iOS)
import UIKit
#endif
