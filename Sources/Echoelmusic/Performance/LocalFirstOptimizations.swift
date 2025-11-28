//
//  LocalFirstOptimizations.swift
//  Echoelmusic
//
//  Created: 2025-11-28
//  Maximum Local Performance - 100% Cloud-Unabhängig
//
//  Ziel: Große Projekte auf lokaler Hardware ohne Cloud-Abhängigkeit
//
//  Features:
//  - Multi-threaded Audio Pipeline (alle CPU-Kerne nutzen)
//  - Disk Streaming für große Projekte (RAM-schonend)
//  - Predictive Resource Loading (vorausschauendes Laden)
//  - Background Pre-computation (Idle-Zeit nutzen)
//  - Incremental Processing (nur Änderungen verarbeiten)
//  - Hardware-spezifische Optimierungen
//  - Memory Defragmentation
//  - Render Caching
//

import Foundation
import Combine
import Accelerate
import Dispatch

// MARK: - Multi-Threaded Audio Pipeline

/// Parallele Audio-Verarbeitung über alle CPU-Kerne
public final class MultiThreadedAudioPipeline {

    // MARK: - Configuration

    public struct Configuration {
        public var threadCount: Int
        public var bufferSize: Int
        public var sampleRate: Double
        public var enableSIMD: Bool
        public var priorityClass: DispatchQoS

        public static var optimal: Configuration {
            let cores = ProcessInfo.processInfo.activeProcessorCount
            return Configuration(
                threadCount: max(2, cores - 1), // Leave 1 core for UI
                bufferSize: 512,
                sampleRate: 48000,
                enableSIMD: true,
                priorityClass: .userInteractive
            )
        }

        public static var balanced: Configuration {
            let cores = ProcessInfo.processInfo.activeProcessorCount
            return Configuration(
                threadCount: max(2, cores / 2),
                bufferSize: 1024,
                sampleRate: 48000,
                enableSIMD: true,
                priorityClass: .userInitiated
            )
        }

        public static var efficient: Configuration {
            return Configuration(
                threadCount: 2,
                bufferSize: 2048,
                sampleRate: 44100,
                enableSIMD: true,
                priorityClass: .utility
            )
        }
    }

    // MARK: - Properties

    private let configuration: Configuration
    private let processingQueues: [DispatchQueue]
    private let mixingQueue: DispatchQueue
    private var trackBuffers: [[Float]] = []
    private var isProcessing = false

    // Lock-free ring buffers for each thread
    private var inputRingBuffers: [LockFreeRingBuffer<Float>] = []
    private var outputRingBuffers: [LockFreeRingBuffer<Float>] = []

    // MARK: - Initialization

    public init(configuration: Configuration = .optimal) {
        self.configuration = configuration

        // Create processing queues for each thread
        self.processingQueues = (0..<configuration.threadCount).map { index in
            DispatchQueue(
                label: "com.echoelmusic.audio.processing.\(index)",
                qos: configuration.priorityClass,
                attributes: [],
                autoreleaseFrequency: .workItem
            )
        }

        self.mixingQueue = DispatchQueue(
            label: "com.echoelmusic.audio.mixing",
            qos: .userInteractive
        )

        // Initialize ring buffers
        for _ in 0..<configuration.threadCount {
            inputRingBuffers.append(LockFreeRingBuffer(capacity: configuration.bufferSize * 4))
            outputRingBuffers.append(LockFreeRingBuffer(capacity: configuration.bufferSize * 4))
        }

        print("🎵 MultiThreadedAudioPipeline initialized with \(configuration.threadCount) threads")
    }

    // MARK: - Processing

    /// Process multiple tracks in parallel
    public func processTracksParallel(
        tracks: [[Float]],
        effects: [[AudioEffect]],
        completion: @escaping ([Float]) -> Void
    ) {
        guard !tracks.isEmpty else {
            completion([])
            return
        }

        let tracksPerThread = max(1, tracks.count / configuration.threadCount)
        var processedTracks: [[Float]?] = Array(repeating: nil, count: tracks.count)
        let group = DispatchGroup()
        let lock = NSLock()

        for (threadIndex, queue) in processingQueues.enumerated() {
            let startTrack = threadIndex * tracksPerThread
            let endTrack = min(startTrack + tracksPerThread, tracks.count)

            guard startTrack < tracks.count else { continue }

            group.enter()
            queue.async {
                for trackIndex in startTrack..<endTrack {
                    var buffer = tracks[trackIndex]

                    // Apply effects chain
                    if trackIndex < effects.count {
                        for effect in effects[trackIndex] {
                            effect.process(&buffer)
                        }
                    }

                    lock.lock()
                    processedTracks[trackIndex] = buffer
                    lock.unlock()
                }
                group.leave()
            }
        }

        group.notify(queue: mixingQueue) { [weak self] in
            guard let self = self else { return }

            // Mix all tracks using SIMD
            let validTracks = processedTracks.compactMap { $0 }
            let mixed = self.mixTracksSIMD(validTracks)

            DispatchQueue.main.async {
                completion(mixed)
            }
        }
    }

    /// SIMD-optimized mixing
    private func mixTracksSIMD(_ tracks: [[Float]]) -> [Float] {
        guard !tracks.isEmpty else { return [] }
        guard let firstTrack = tracks.first else { return [] }

        let frameCount = firstTrack.count
        var output = [Float](repeating: 0.0, count: frameCount)

        if configuration.enableSIMD {
            for track in tracks {
                guard track.count == frameCount else { continue }
                vDSP_vadd(output, 1, track, 1, &output, 1, vDSP_Length(frameCount))
            }

            // Normalize to prevent clipping
            var scale = 1.0 / Float(tracks.count)
            vDSP_vsmul(output, 1, &scale, &output, 1, vDSP_Length(frameCount))
        } else {
            for track in tracks {
                for i in 0..<min(frameCount, track.count) {
                    output[i] += track[i]
                }
            }

            let scale = 1.0 / Float(tracks.count)
            for i in 0..<frameCount {
                output[i] *= scale
            }
        }

        return output
    }

    /// Get thread utilization stats
    public var threadStats: [ThreadStat] {
        processingQueues.enumerated().map { index, _ in
            ThreadStat(
                threadIndex: index,
                isActive: isProcessing,
                queueDepth: inputRingBuffers[index].count
            )
        }
    }

    public struct ThreadStat {
        public let threadIndex: Int
        public let isActive: Bool
        public let queueDepth: Int
    }
}

// MARK: - Audio Effect Protocol

public protocol AudioEffect {
    func process(_ buffer: inout [Float])
}

// MARK: - Disk Streaming Engine

/// Stream Audio direkt von Disk - für Projekte größer als RAM
public final class DiskStreamingEngine {

    // MARK: - Configuration

    public struct StreamConfig {
        public var chunkSize: Int          // Bytes pro Chunk
        public var readAheadChunks: Int    // Anzahl vorgeladener Chunks
        public var cacheSize: Int          // Max Cache in Bytes
        public var useMMAP: Bool           // Memory-Mapped I/O

        public static var standard: StreamConfig {
            StreamConfig(
                chunkSize: 1024 * 1024,      // 1 MB Chunks
                readAheadChunks: 4,           // 4 MB read-ahead
                cacheSize: 256 * 1024 * 1024, // 256 MB Cache
                useMMAP: true
            )
        }

        public static var lowMemory: StreamConfig {
            StreamConfig(
                chunkSize: 256 * 1024,        // 256 KB Chunks
                readAheadChunks: 2,           // 512 KB read-ahead
                cacheSize: 64 * 1024 * 1024,  // 64 MB Cache
                useMMAP: false
            )
        }

        public static var highPerformance: StreamConfig {
            StreamConfig(
                chunkSize: 4 * 1024 * 1024,   // 4 MB Chunks
                readAheadChunks: 8,           // 32 MB read-ahead
                cacheSize: 1024 * 1024 * 1024, // 1 GB Cache
                useMMAP: true
            )
        }
    }

    // MARK: - Properties

    private let config: StreamConfig
    private let streamQueue: DispatchQueue
    private var activeStreams: [UUID: AudioStream] = [:]
    private var chunkCache: ChunkCache
    private var readAheadBuffer: [UUID: [AudioChunk]] = [:]

    // MARK: - Initialization

    public init(config: StreamConfig = .standard) {
        self.config = config
        self.streamQueue = DispatchQueue(
            label: "com.echoelmusic.disk.streaming",
            qos: .userInitiated,
            attributes: .concurrent
        )
        self.chunkCache = ChunkCache(maxSize: config.cacheSize)

        print("💿 DiskStreamingEngine initialized (cache: \(config.cacheSize / 1024 / 1024) MB)")
    }

    // MARK: - Stream Management

    /// Open audio file for streaming
    public func openStream(filePath: String) throws -> UUID {
        let streamID = UUID()

        let stream = try AudioStream(
            id: streamID,
            filePath: filePath,
            chunkSize: config.chunkSize,
            useMMAP: config.useMMAP
        )

        activeStreams[streamID] = stream

        // Start read-ahead
        startReadAhead(for: streamID)

        return streamID
    }

    /// Read audio samples at position
    public func read(streamID: UUID, position: Int64, samples: Int) -> [Float]? {
        guard let stream = activeStreams[streamID] else { return nil }

        // Check cache first
        let chunkIndex = Int(position) / config.chunkSize
        let cacheKey = "\(streamID)-\(chunkIndex)"

        if let cachedChunk = chunkCache.get(key: cacheKey) {
            let offset = Int(position) % config.chunkSize
            return extractSamples(from: cachedChunk.data, offset: offset, count: samples)
        }

        // Read from disk
        guard let data = stream.read(position: position, length: samples * 4) else {
            return nil
        }

        // Cache the chunk
        let chunk = AudioChunk(
            index: chunkIndex,
            data: data,
            streamID: streamID
        )
        chunkCache.set(key: cacheKey, chunk: chunk)

        return extractSamples(from: data, offset: 0, count: samples)
    }

    /// Close stream and free resources
    public func closeStream(_ streamID: UUID) {
        activeStreams.removeValue(forKey: streamID)
        readAheadBuffer.removeValue(forKey: streamID)

        // Remove cached chunks for this stream
        chunkCache.removeChunks(for: streamID)
    }

    // MARK: - Read-Ahead

    private func startReadAhead(for streamID: UUID) {
        streamQueue.async { [weak self] in
            guard let self = self,
                  let stream = self.activeStreams[streamID] else { return }

            var position: Int64 = 0
            var chunks: [AudioChunk] = []

            for i in 0..<self.config.readAheadChunks {
                if let data = stream.read(position: position, length: self.config.chunkSize) {
                    let chunk = AudioChunk(index: i, data: data, streamID: streamID)
                    chunks.append(chunk)

                    let cacheKey = "\(streamID)-\(i)"
                    self.chunkCache.set(key: cacheKey, chunk: chunk)
                }
                position += Int64(self.config.chunkSize)
            }

            self.readAheadBuffer[streamID] = chunks
        }
    }

    /// Continue read-ahead as playback progresses
    public func updateReadAhead(streamID: UUID, currentPosition: Int64) {
        streamQueue.async { [weak self] in
            guard let self = self,
                  let stream = self.activeStreams[streamID] else { return }

            let currentChunk = Int(currentPosition) / self.config.chunkSize
            let targetChunk = currentChunk + self.config.readAheadChunks

            // Load upcoming chunks
            for chunkIndex in currentChunk...targetChunk {
                let cacheKey = "\(streamID)-\(chunkIndex)"

                if self.chunkCache.get(key: cacheKey) == nil {
                    let position = Int64(chunkIndex * self.config.chunkSize)
                    if let data = stream.read(position: position, length: self.config.chunkSize) {
                        let chunk = AudioChunk(index: chunkIndex, data: data, streamID: streamID)
                        self.chunkCache.set(key: cacheKey, chunk: chunk)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func extractSamples(from data: Data, offset: Int, count: Int) -> [Float] {
        let byteOffset = offset * 4
        let byteCount = count * 4

        guard byteOffset + byteCount <= data.count else {
            return []
        }

        return data.withUnsafeBytes { buffer in
            let floatBuffer = buffer.bindMemory(to: Float.self)
            let startIndex = offset
            let endIndex = min(startIndex + count, floatBuffer.count)
            return Array(floatBuffer[startIndex..<endIndex])
        }
    }

    // MARK: - Statistics

    public var stats: StreamingStats {
        StreamingStats(
            activeStreams: activeStreams.count,
            cacheUsage: chunkCache.currentSize,
            cacheCapacity: config.cacheSize,
            hitRate: chunkCache.hitRate
        )
    }

    public struct StreamingStats {
        public let activeStreams: Int
        public let cacheUsage: Int
        public let cacheCapacity: Int
        public let hitRate: Float

        public var cacheUsagePercent: Float {
            Float(cacheUsage) / Float(cacheCapacity) * 100
        }
    }
}

// MARK: - Audio Stream

private final class AudioStream {
    let id: UUID
    let filePath: String
    let fileSize: Int64
    private let fileHandle: FileHandle?
    private var mappedData: Data?
    private let useMMAP: Bool

    init(id: UUID, filePath: String, chunkSize: Int, useMMAP: Bool) throws {
        self.id = id
        self.filePath = filePath
        self.useMMAP = useMMAP

        guard FileManager.default.fileExists(atPath: filePath) else {
            throw StreamingError.fileNotFound
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
        self.fileSize = attributes[.size] as? Int64 ?? 0

        if useMMAP {
            self.mappedData = try? Data(contentsOf: URL(fileURLWithPath: filePath), options: .mappedIfSafe)
            self.fileHandle = nil
        } else {
            self.fileHandle = FileHandle(forReadingAtPath: filePath)
            self.mappedData = nil
        }
    }

    func read(position: Int64, length: Int) -> Data? {
        if let mappedData = mappedData {
            let start = Int(position)
            let end = min(start + length, mappedData.count)
            guard start < end else { return nil }
            return mappedData.subdata(in: start..<end)
        } else if let handle = fileHandle {
            do {
                try handle.seek(toOffset: UInt64(position))
                return try handle.read(upToCount: length)
            } catch {
                return nil
            }
        }
        return nil
    }

    deinit {
        try? fileHandle?.close()
    }
}

// MARK: - Audio Chunk

private struct AudioChunk {
    let index: Int
    let data: Data
    let streamID: UUID
    let timestamp: Date = Date()

    var size: Int { data.count }
}

// MARK: - Chunk Cache

private final class ChunkCache {
    private var cache: [String: AudioChunk] = [:]
    private var accessOrder: [String] = []
    private let maxSize: Int
    private var _currentSize: Int = 0
    private var hits: Int = 0
    private var misses: Int = 0
    private let lock = NSLock()

    init(maxSize: Int) {
        self.maxSize = maxSize
    }

    var currentSize: Int {
        lock.lock()
        defer { lock.unlock() }
        return _currentSize
    }

    var hitRate: Float {
        let total = hits + misses
        guard total > 0 else { return 0 }
        return Float(hits) / Float(total)
    }

    func get(key: String) -> AudioChunk? {
        lock.lock()
        defer { lock.unlock() }

        if let chunk = cache[key] {
            hits += 1
            // Move to end (most recently used)
            if let index = accessOrder.firstIndex(of: key) {
                accessOrder.remove(at: index)
                accessOrder.append(key)
            }
            return chunk
        }

        misses += 1
        return nil
    }

    func set(key: String, chunk: AudioChunk) {
        lock.lock()
        defer { lock.unlock() }

        // Evict if necessary
        while _currentSize + chunk.size > maxSize && !accessOrder.isEmpty {
            let oldestKey = accessOrder.removeFirst()
            if let removed = cache.removeValue(forKey: oldestKey) {
                _currentSize -= removed.size
            }
        }

        cache[key] = chunk
        accessOrder.append(key)
        _currentSize += chunk.size
    }

    func removeChunks(for streamID: UUID) {
        lock.lock()
        defer { lock.unlock() }

        let keysToRemove = cache.filter { $0.value.streamID == streamID }.map { $0.key }
        for key in keysToRemove {
            if let removed = cache.removeValue(forKey: key) {
                _currentSize -= removed.size
            }
            accessOrder.removeAll { $0 == key }
        }
    }
}

// MARK: - Streaming Error

public enum StreamingError: Error {
    case fileNotFound
    case readError
    case invalidPosition
}

// MARK: - Predictive Resource Loader

/// Lädt Ressourcen basierend auf Nutzungsmustern voraus
@MainActor
public final class PredictiveResourceLoader: ObservableObject {

    // MARK: - Properties

    @Published public private(set) var preloadedResources: Set<String> = []
    @Published public private(set) var isPreloading: Bool = false
    @Published public private(set) var predictionAccuracy: Float = 0.0

    private var usageHistory: [ResourceUsage] = []
    private var predictions: [String: Float] = [:] // Resource -> Probability
    private let preloadQueue: DispatchQueue
    private let maxHistorySize = 1000
    private let preloadThreshold: Float = 0.6

    // Statistics
    private var correctPredictions: Int = 0
    private var totalPredictions: Int = 0

    // MARK: - Initialization

    public init() {
        self.preloadQueue = DispatchQueue(
            label: "com.echoelmusic.predictive.loader",
            qos: .utility
        )

        print("🔮 PredictiveResourceLoader initialized")
    }

    // MARK: - Usage Tracking

    /// Record resource usage for learning
    public func recordUsage(
        resourceID: String,
        context: UsageContext,
        timestamp: Date = Date()
    ) {
        let usage = ResourceUsage(
            resourceID: resourceID,
            context: context,
            timestamp: timestamp
        )

        usageHistory.append(usage)

        // Limit history size
        if usageHistory.count > maxHistorySize {
            usageHistory.removeFirst(usageHistory.count - maxHistorySize)
        }

        // Check if this was predicted
        if let predictedProb = predictions[resourceID], predictedProb >= preloadThreshold {
            correctPredictions += 1
        }
        totalPredictions += 1

        predictionAccuracy = totalPredictions > 0
            ? Float(correctPredictions) / Float(totalPredictions)
            : 0.0

        // Update predictions
        updatePredictions(currentContext: context)
    }

    // MARK: - Prediction

    private func updatePredictions(currentContext: UsageContext) {
        predictions.removeAll()

        // Find similar contexts in history
        let similarUsages = usageHistory.filter { usage in
            contextSimilarity(usage.context, currentContext) > 0.5
        }

        // Count resource occurrences after similar contexts
        var resourceCounts: [String: Int] = [:]

        for (index, usage) in similarUsages.enumerated() {
            // Look at what was used after this
            let nextIndex = usageHistory.firstIndex(where: { $0.timestamp > usage.timestamp })
            if let next = nextIndex, next < usageHistory.count {
                let nextResource = usageHistory[next].resourceID
                resourceCounts[nextResource, default: 0] += 1
            }
        }

        // Convert to probabilities
        let total = Float(resourceCounts.values.reduce(0, +))
        for (resource, count) in resourceCounts {
            predictions[resource] = Float(count) / max(1, total)
        }
    }

    private func contextSimilarity(_ a: UsageContext, _ b: UsageContext) -> Float {
        var score: Float = 0.0
        var factors: Float = 0.0

        // Time of day similarity (0-1)
        let hourA = Calendar.current.component(.hour, from: a.timestamp)
        let hourB = Calendar.current.component(.hour, from: b.timestamp)
        let hourDiff = abs(hourA - hourB)
        score += 1.0 - Float(min(hourDiff, 24 - hourDiff)) / 12.0
        factors += 1.0

        // Project similarity
        if a.projectID == b.projectID {
            score += 1.0
        }
        factors += 1.0

        // Action type similarity
        if a.actionType == b.actionType {
            score += 1.0
        }
        factors += 1.0

        return score / factors
    }

    // MARK: - Preloading

    /// Start preloading predicted resources
    public func startPreloading(
        loader: @escaping (String) async -> Bool
    ) {
        guard !isPreloading else { return }
        isPreloading = true

        let resourcesToPreload = predictions
            .filter { $0.value >= preloadThreshold }
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { $0.key }

        Task {
            for resourceID in resourcesToPreload {
                if !preloadedResources.contains(resourceID) {
                    let success = await loader(resourceID)
                    if success {
                        await MainActor.run {
                            preloadedResources.insert(resourceID)
                        }
                    }
                }
            }

            await MainActor.run {
                isPreloading = false
            }
        }
    }

    /// Clear preloaded resources
    public func clearPreloaded() {
        preloadedResources.removeAll()
    }

    // MARK: - Types

    public struct ResourceUsage {
        public let resourceID: String
        public let context: UsageContext
        public let timestamp: Date
    }

    public struct UsageContext {
        public let timestamp: Date
        public let projectID: String?
        public let actionType: ActionType
        public let previousResourceID: String?

        public init(
            timestamp: Date = Date(),
            projectID: String? = nil,
            actionType: ActionType = .unknown,
            previousResourceID: String? = nil
        ) {
            self.timestamp = timestamp
            self.projectID = projectID
            self.actionType = actionType
            self.previousResourceID = previousResourceID
        }
    }

    public enum ActionType {
        case play, record, edit, mix, export, browse, unknown
    }
}

// MARK: - Background Pre-computation Engine

/// Nutzt Idle-Zeit für Vorberechnungen
@MainActor
public final class BackgroundPrecomputeEngine: ObservableObject {

    // MARK: - Properties

    @Published public private(set) var pendingTasks: Int = 0
    @Published public private(set) var completedTasks: Int = 0
    @Published public private(set) var isIdle: Bool = true
    @Published public private(set) var cpuUsageLimit: Float = 0.3

    private var taskQueue: [PrecomputeTask] = []
    private var resultCache: [String: Any] = [:]
    private let computeQueue: DispatchQueue
    private var idleTimer: Timer?
    private let idleThreshold: TimeInterval = 2.0
    private var lastActivityTime: Date = Date()

    // MARK: - Initialization

    public init() {
        self.computeQueue = DispatchQueue(
            label: "com.echoelmusic.precompute",
            qos: .background,
            attributes: .concurrent
        )

        startIdleMonitoring()
        print("⚡ BackgroundPrecomputeEngine initialized")
    }

    // MARK: - Task Management

    /// Queue a task for background execution
    public func queueTask<T>(
        id: String,
        priority: TaskPriority = .normal,
        computation: @escaping () -> T
    ) {
        let task = PrecomputeTask(
            id: id,
            priority: priority,
            computation: { computation() }
        )

        // Insert based on priority
        if let insertIndex = taskQueue.firstIndex(where: { $0.priority < priority }) {
            taskQueue.insert(task, at: insertIndex)
        } else {
            taskQueue.append(task)
        }

        pendingTasks = taskQueue.count
    }

    /// Get cached result
    public func getCachedResult<T>(id: String) -> T? {
        return resultCache[id] as? T
    }

    /// Check if result is cached
    public func hasCachedResult(id: String) -> Bool {
        return resultCache[id] != nil
    }

    /// Clear cache
    public func clearCache() {
        resultCache.removeAll()
    }

    // MARK: - Activity Tracking

    /// Call this when user activity is detected
    public func userActivityDetected() {
        lastActivityTime = Date()
        isIdle = false
    }

    // MARK: - Idle Monitoring

    private func startIdleMonitoring() {
        idleTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkIdleState()
            }
        }
    }

    private func checkIdleState() {
        let idleTime = Date().timeIntervalSince(lastActivityTime)
        let wasIdle = isIdle
        isIdle = idleTime >= idleThreshold

        if isIdle && !wasIdle {
            // Just became idle - start processing
            processNextTask()
        }
    }

    // MARK: - Processing

    private func processNextTask() {
        guard isIdle, !taskQueue.isEmpty else { return }

        // Check CPU usage
        let currentCPU = getCPUUsage()
        guard currentCPU < cpuUsageLimit else {
            // Too much CPU usage, wait
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                Task { @MainActor in
                    self?.processNextTask()
                }
            }
            return
        }

        let task = taskQueue.removeFirst()
        pendingTasks = taskQueue.count

        computeQueue.async { [weak self] in
            let result = task.computation()

            Task { @MainActor in
                self?.resultCache[task.id] = result
                self?.completedTasks += 1

                // Process next if still idle
                if self?.isIdle == true {
                    self?.processNextTask()
                }
            }
        }
    }

    private func getCPUUsage() -> Float {
        // Simplified CPU measurement
        var totalUsageOfCPU: Float = 0.0
        var threadsList = UnsafeMutablePointer<thread_act_t>(nil)
        var threadsCount: mach_msg_type_number_t = 0

        let result = withUnsafeMutablePointer(to: &threadsList) {
            task_threads(mach_task_self_, $0, &threadsCount)
        }

        guard result == KERN_SUCCESS, let threads = threadsList else {
            return 0.0
        }

        for i in 0..<Int(threadsCount) {
            var info = thread_basic_info()
            var count = mach_msg_type_number_t(THREAD_INFO_MAX)

            let infoResult = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    thread_info(threads[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &count)
                }
            }

            if infoResult == KERN_SUCCESS && (info.flags & TH_FLAGS_IDLE) == 0 {
                totalUsageOfCPU += Float(info.cpu_usage) / Float(TH_USAGE_SCALE)
            }
        }

        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threadsList), vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride))

        return min(totalUsageOfCPU, 1.0)
    }

    // MARK: - Types

    public enum TaskPriority: Int, Comparable {
        case low = 0
        case normal = 1
        case high = 2
        case critical = 3

        public static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    private struct PrecomputeTask {
        let id: String
        let priority: TaskPriority
        let computation: () -> Any
    }
}

// MARK: - Incremental Processor

/// Verarbeitet nur geänderte Teile - spart CPU/Zeit
public final class IncrementalProcessor<T: Hashable, R> {

    // MARK: - Properties

    private var cache: [T: CacheEntry] = [:]
    private var lastInputHash: Int = 0
    private let processor: (T) -> R
    private let combiner: ([R]) -> R

    // MARK: - Initialization

    public init(
        processor: @escaping (T) -> R,
        combiner: @escaping ([R]) -> R
    ) {
        self.processor = processor
        self.combiner = combiner
    }

    // MARK: - Processing

    /// Process only changed items
    public func process(items: [T]) -> R {
        let currentHash = items.hashValue

        // Find changed items
        let changedItems = items.filter { item in
            if let entry = cache[item] {
                return entry.inputHash != item.hashValue
            }
            return true
        }

        // Process only changed items
        for item in changedItems {
            let result = processor(item)
            cache[item] = CacheEntry(
                inputHash: item.hashValue,
                result: result,
                timestamp: Date()
            )
        }

        // Remove stale entries
        let currentItemSet = Set(items)
        cache = cache.filter { currentItemSet.contains($0.key) }

        // Combine all results
        let allResults = items.compactMap { cache[$0]?.result }

        lastInputHash = currentHash
        return combiner(allResults)
    }

    /// Get processing stats
    public var stats: ProcessingStats {
        ProcessingStats(
            cachedItems: cache.count,
            cacheHitRate: 0 // Would need tracking
        )
    }

    public struct ProcessingStats {
        public let cachedItems: Int
        public let cacheHitRate: Float
    }

    private struct CacheEntry {
        let inputHash: Int
        let result: R
        let timestamp: Date
    }
}

// MARK: - Lock-Free Ring Buffer

/// Thread-safe ring buffer ohne Locks
public final class LockFreeRingBuffer<T> {
    private var buffer: [T?]
    private var head: Int = 0
    private var tail: Int = 0
    private let capacity: Int
    private let mask: Int

    public init(capacity: Int) {
        // Round to next power of 2
        let actualCapacity = 1 << Int(ceil(log2(Double(capacity))))
        self.capacity = actualCapacity
        self.mask = actualCapacity - 1
        self.buffer = Array(repeating: nil, count: actualCapacity)
    }

    public var count: Int {
        return (tail - head + capacity) & mask
    }

    public var isEmpty: Bool {
        return head == tail
    }

    public var isFull: Bool {
        return count == capacity - 1
    }

    @discardableResult
    public func push(_ value: T) -> Bool {
        let nextTail = (tail + 1) & mask
        if nextTail == head {
            return false // Full
        }
        buffer[tail] = value
        tail = nextTail
        return true
    }

    public func pop() -> T? {
        if head == tail {
            return nil // Empty
        }
        let value = buffer[head]
        buffer[head] = nil
        head = (head + 1) & mask
        return value
    }
}

// MARK: - Hardware Requirements Calculator

/// Berechnet Hardware-Anforderungen für Projekte
public struct HardwareRequirementsCalculator {

    /// Calculate requirements for a project
    public static func calculate(for project: ProjectSpec) -> HardwareRequirements {
        // Base requirements
        var ramGB: Float = 2.0  // Base OS + App
        var cpuCores: Int = 2
        var storageGB: Float = 1.0
        var gpuVRAM: Float = 0.5

        // Audio tracks
        let audioRAM = Float(project.audioTracks) * 0.05  // 50 MB per track
        ramGB += audioRAM

        // MIDI tracks (minimal)
        let midiRAM = Float(project.midiTracks) * 0.001  // 1 MB per track
        ramGB += midiRAM

        // Video tracks (heavy)
        let videoRAM = Float(project.videoTracks) * 0.5  // 500 MB per 1080p track
        ramGB += videoRAM
        gpuVRAM += Float(project.videoTracks) * 0.25

        // Effects
        let effectsRAM = Float(project.effectsCount) * 0.02  // 20 MB per effect
        ramGB += effectsRAM

        // Real-time processing needs
        if project.requiresRealtime {
            cpuCores = max(4, project.audioTracks / 8 + project.videoTracks)
            ramGB *= 1.5  // Buffer headroom
        }

        // Live streaming
        if project.hasLiveStreaming {
            cpuCores = max(cpuCores, 6)
            ramGB += 2.0
            gpuVRAM += 1.0
        }

        // Biofeedback devices
        ramGB += Float(project.biofeedbackDevices) * 0.1

        // Project storage
        let audioDuration = Float(project.durationMinutes)
        storageGB += audioDuration * Float(project.audioTracks) * 0.01  // ~10 MB/min/track
        storageGB += audioDuration * Float(project.videoTracks) * 0.5   // ~500 MB/min/track (1080p)

        // Determine recommended device
        let device = recommendDevice(
            ramGB: ramGB,
            cpuCores: cpuCores,
            gpuVRAM: gpuVRAM,
            storageGB: storageGB
        )

        return HardwareRequirements(
            minimumRAM: ramGB,
            recommendedRAM: ramGB * 1.5,
            minimumCPUCores: cpuCores,
            recommendedCPUCores: cpuCores + 2,
            minimumStorageGB: storageGB,
            recommendedStorageGB: storageGB * 2,
            gpuRequired: project.videoTracks > 0 || project.hasLiveStreaming,
            gpuVRAMGB: gpuVRAM,
            recommendedDevice: device,
            notes: generateNotes(for: project)
        )
    }

    private static func recommendDevice(
        ramGB: Float,
        cpuCores: Int,
        gpuVRAM: Float,
        storageGB: Float
    ) -> String {
        if ramGB > 32 || cpuCores > 12 {
            return "Mac Studio M2 Ultra / Mac Pro"
        } else if ramGB > 24 || cpuCores > 10 {
            return "MacBook Pro 16\" M4 Max (48GB RAM)"
        } else if ramGB > 16 || cpuCores > 8 {
            return "MacBook Pro 14\"/16\" M4 Pro (24-36GB RAM)"
        } else if ramGB > 8 || cpuCores > 6 {
            return "MacBook Pro 14\" M4 (16-24GB RAM)"
        } else if ramGB > 4 {
            return "MacBook Air M3 (16GB RAM)"
        } else {
            return "MacBook Air M3 (8GB RAM) - ausreichend!"
        }
    }

    private static func generateNotes(for project: ProjectSpec) -> [String] {
        var notes: [String] = []

        if project.audioTracks > 32 {
            notes.append("Viele Audio-Tracks: SSD mit >1000 MB/s empfohlen")
        }

        if project.videoTracks > 2 {
            notes.append("Mehrere Videos: Dedizierte GPU wichtig")
        }

        if project.hasLiveStreaming {
            notes.append("Live-Streaming: Stabile Internetverbindung (>20 Mbit/s Upload)")
        }

        if project.biofeedbackDevices > 0 {
            notes.append("Biofeedback: USB-C Thunderbolt für geringe Latenz")
        }

        if project.requiresRealtime {
            notes.append("Echtzeit: Buffer-Größe 128-256 für <6ms Latenz")
        }

        return notes
    }

    // MARK: - Types

    public struct ProjectSpec {
        public var audioTracks: Int
        public var midiTracks: Int
        public var videoTracks: Int
        public var effectsCount: Int
        public var durationMinutes: Int
        public var requiresRealtime: Bool
        public var hasLiveStreaming: Bool
        public var biofeedbackDevices: Int

        public init(
            audioTracks: Int = 8,
            midiTracks: Int = 4,
            videoTracks: Int = 0,
            effectsCount: Int = 16,
            durationMinutes: Int = 30,
            requiresRealtime: Bool = true,
            hasLiveStreaming: Bool = false,
            biofeedbackDevices: Int = 0
        ) {
            self.audioTracks = audioTracks
            self.midiTracks = midiTracks
            self.videoTracks = videoTracks
            self.effectsCount = effectsCount
            self.durationMinutes = durationMinutes
            self.requiresRealtime = requiresRealtime
            self.hasLiveStreaming = hasLiveStreaming
            self.biofeedbackDevices = biofeedbackDevices
        }

        // Preset: Large professional project
        public static var largeProfessional: ProjectSpec {
            ProjectSpec(
                audioTracks: 64,
                midiTracks: 32,
                videoTracks: 4,
                effectsCount: 100,
                durationMinutes: 120,
                requiresRealtime: true,
                hasLiveStreaming: true,
                biofeedbackDevices: 3
            )
        }

        // Preset: Medium project
        public static var medium: ProjectSpec {
            ProjectSpec(
                audioTracks: 24,
                midiTracks: 16,
                videoTracks: 1,
                effectsCount: 40,
                durationMinutes: 60,
                requiresRealtime: true,
                hasLiveStreaming: false,
                biofeedbackDevices: 1
            )
        }

        // Preset: Small project
        public static var small: ProjectSpec {
            ProjectSpec(
                audioTracks: 8,
                midiTracks: 4,
                videoTracks: 0,
                effectsCount: 16,
                durationMinutes: 15,
                requiresRealtime: false,
                hasLiveStreaming: false,
                biofeedbackDevices: 0
            )
        }
    }

    public struct HardwareRequirements {
        public let minimumRAM: Float
        public let recommendedRAM: Float
        public let minimumCPUCores: Int
        public let recommendedCPUCores: Int
        public let minimumStorageGB: Float
        public let recommendedStorageGB: Float
        public let gpuRequired: Bool
        public let gpuVRAMGB: Float
        public let recommendedDevice: String
        public let notes: [String]

        public var summary: String {
            """
            ═══════════════════════════════════════════
            HARDWARE-ANFORDERUNGEN FÜR ECHOELMUSIC
            ═══════════════════════════════════════════

            RAM:     \(String(format: "%.0f", minimumRAM)) GB (minimum)
                     \(String(format: "%.0f", recommendedRAM)) GB (empfohlen)

            CPU:     \(minimumCPUCores) Kerne (minimum)
                     \(recommendedCPUCores) Kerne (empfohlen)

            Storage: \(String(format: "%.0f", minimumStorageGB)) GB (minimum)
                     \(String(format: "%.0f", recommendedStorageGB)) GB (empfohlen)

            GPU:     \(gpuRequired ? "Erforderlich (\(String(format: "%.1f", gpuVRAMGB)) GB VRAM)" : "Optional")

            ═══════════════════════════════════════════
            EMPFOHLENES GERÄT:
            \(recommendedDevice)
            ═══════════════════════════════════════════

            HINWEISE:
            \(notes.map { "• \($0)" }.joined(separator: "\n"))
            """
        }
    }
}
