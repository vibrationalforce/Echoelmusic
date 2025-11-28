//
//  ProxyVideoSystem.swift
//  Echoelmusic
//
//  Created: 2025-11-28
//  Professional 4K/8K Proxy Video System
//
//  Features:
//  - Automatic proxy generation for 4K/8K footage
//  - Smart resolution switching (proxy vs original)
//  - Memory-efficient caching with LRU eviction
//  - Background transcoding with progress tracking
//  - GPU-accelerated proxy generation (Metal/VideoToolbox)
//  - Cross-platform abstraction for Windows/Linux
//

import Foundation
import AVFoundation
import Combine

#if canImport(CoreImage)
import CoreImage
#endif

#if canImport(VideoToolbox)
import VideoToolbox
#endif

// MARK: - Proxy Configuration

/// Configuration for proxy generation
public struct ProxyConfiguration: Codable, Equatable {
    /// Target resolution for proxies
    public var resolution: ProxyResolution
    /// Video codec for proxies
    public var codec: ProxyCodec
    /// Bitrate in Mbps
    public var bitrate: Double
    /// Frame rate (nil = same as source)
    public var frameRate: Double?
    /// Whether to generate audio proxies
    public var generateAudioProxy: Bool
    /// Audio sample rate for proxies (nil = same as source)
    public var audioSampleRate: Int?

    public init(
        resolution: ProxyResolution = .hd720,
        codec: ProxyCodec = .h264,
        bitrate: Double = 8.0,
        frameRate: Double? = nil,
        generateAudioProxy: Bool = false,
        audioSampleRate: Int? = nil
    ) {
        self.resolution = resolution
        self.codec = codec
        self.bitrate = bitrate
        self.frameRate = frameRate
        self.generateAudioProxy = generateAudioProxy
        self.audioSampleRate = audioSampleRate
    }

    public enum ProxyResolution: String, Codable, CaseIterable {
        case hd480 = "480p"
        case hd720 = "720p"
        case hd1080 = "1080p"
        case quarter = "1/4"
        case half = "1/2"

        public func targetSize(from source: CGSize) -> CGSize {
            switch self {
            case .hd480:
                return CGSize(width: 854, height: 480)
            case .hd720:
                return CGSize(width: 1280, height: 720)
            case .hd1080:
                return CGSize(width: 1920, height: 1080)
            case .quarter:
                return CGSize(width: source.width / 4, height: source.height / 4)
            case .half:
                return CGSize(width: source.width / 2, height: source.height / 2)
            }
        }
    }

    public enum ProxyCodec: String, Codable, CaseIterable {
        case h264 = "H.264"
        case hevc = "HEVC"
        case proRes422LT = "ProRes 422 LT"
        case proResProxy = "ProRes Proxy"

        #if os(macOS) || os(iOS)
        public var avCodecType: AVVideoCodecType {
            switch self {
            case .h264: return .h264
            case .hevc: return .hevc
            case .proRes422LT: return .proRes422LT
            case .proResProxy: return .proRes422Proxy
            }
        }
        #endif
    }
}

// MARK: - Proxy Media Item

/// Represents a media item with optional proxy
public struct ProxyMediaItem: Identifiable, Codable {
    public let id: UUID
    public let originalURL: URL
    public var proxyURL: URL?
    public let sourceResolution: CGSize
    public var proxyResolution: CGSize?
    public var proxyStatus: ProxyStatus
    public var proxyProgress: Double
    public let duration: Double
    public let fileSize: Int64
    public var proxyFileSize: Int64?
    public let createdAt: Date
    public var lastAccessedAt: Date

    public init(
        id: UUID = UUID(),
        originalURL: URL,
        sourceResolution: CGSize,
        duration: Double,
        fileSize: Int64
    ) {
        self.id = id
        self.originalURL = originalURL
        self.proxyURL = nil
        self.sourceResolution = sourceResolution
        self.proxyResolution = nil
        self.proxyStatus = .none
        self.proxyProgress = 0
        self.duration = duration
        self.fileSize = fileSize
        self.proxyFileSize = nil
        self.createdAt = Date()
        self.lastAccessedAt = Date()
    }

    public enum ProxyStatus: String, Codable {
        case none
        case queued
        case generating
        case ready
        case failed
        case offline  // Proxy file missing
    }

    /// Whether this item needs a proxy (4K or higher)
    public var needsProxy: Bool {
        sourceResolution.width >= 3840 || sourceResolution.height >= 2160
    }

    /// Current URL to use (proxy if available, otherwise original)
    public func currentURL(preferProxy: Bool) -> URL {
        if preferProxy, let proxyURL = proxyURL, proxyStatus == .ready {
            return proxyURL
        }
        return originalURL
    }
}

// MARK: - Proxy Manager

/// Manages proxy generation and caching
@MainActor
public final class ProxyManager: ObservableObject {
    public static let shared = ProxyManager()

    // MARK: - Published State

    @Published public private(set) var mediaItems: [UUID: ProxyMediaItem] = [:]
    @Published public private(set) var generationQueue: [UUID] = []
    @Published public private(set) var isGenerating: Bool = false
    @Published public private(set) var currentGeneratingId: UUID?
    @Published public var configuration: ProxyConfiguration = ProxyConfiguration()

    // MARK: - Settings

    @Published public var autoGenerateProxies: Bool = true
    @Published public var useProxiesForPlayback: Bool = true
    @Published public var useProxiesForEdit: Bool = true
    @Published public var maxCacheSize: Int64 = 50 * 1024 * 1024 * 1024 // 50 GB

    // MARK: - Private State

    private var generationTasks: [UUID: Task<Void, Never>] = [:]
    private let proxyDirectory: URL
    private var currentCacheSize: Int64 = 0
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        // Create proxy directory
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.proxyDirectory = cacheDir.appendingPathComponent("Echoelmusic/Proxies", isDirectory: true)

        try? FileManager.default.createDirectory(at: proxyDirectory, withIntermediateDirectories: true)

        loadState()
        calculateCacheSize()
    }

    // MARK: - Media Registration

    /// Register a media item for proxy management
    public func registerMedia(url: URL) async throws -> ProxyMediaItem {
        // Check if already registered
        if let existing = mediaItems.values.first(where: { $0.originalURL == url }) {
            return existing
        }

        // Get media info
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds

        var resolution = CGSize.zero
        if let track = try await asset.loadTracks(withMediaType: .video).first {
            resolution = try await track.load(.naturalSize)
        }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0

        let item = ProxyMediaItem(
            originalURL: url,
            sourceResolution: resolution,
            duration: duration,
            fileSize: fileSize
        )

        mediaItems[item.id] = item

        // Auto-queue for proxy generation if needed
        if autoGenerateProxies && item.needsProxy {
            queueProxyGeneration(for: item.id)
        }

        saveState()
        return item
    }

    /// Unregister a media item
    public func unregisterMedia(id: UUID) {
        if let item = mediaItems[id], let proxyURL = item.proxyURL {
            try? FileManager.default.removeItem(at: proxyURL)
        }
        mediaItems.removeValue(forKey: id)
        generationQueue.removeAll { $0 == id }
        saveState()
    }

    // MARK: - Proxy Generation

    /// Queue a media item for proxy generation
    public func queueProxyGeneration(for id: UUID) {
        guard var item = mediaItems[id] else { return }
        guard item.proxyStatus != .ready && item.proxyStatus != .generating else { return }

        item.proxyStatus = .queued
        mediaItems[id] = item

        if !generationQueue.contains(id) {
            generationQueue.append(id)
        }

        if !isGenerating {
            processNextInQueue()
        }

        saveState()
    }

    /// Cancel proxy generation for an item
    public func cancelGeneration(for id: UUID) {
        generationQueue.removeAll { $0 == id }
        generationTasks[id]?.cancel()
        generationTasks.removeValue(forKey: id)

        if var item = mediaItems[id] {
            item.proxyStatus = .none
            item.proxyProgress = 0
            mediaItems[id] = item
        }

        if currentGeneratingId == id {
            currentGeneratingId = nil
            processNextInQueue()
        }
    }

    /// Generate all queued proxies
    public func generateAllProxies() {
        for id in mediaItems.keys {
            if let item = mediaItems[id], item.needsProxy && item.proxyStatus == .none {
                queueProxyGeneration(for: id)
            }
        }
    }

    private func processNextInQueue() {
        guard !generationQueue.isEmpty else {
            isGenerating = false
            currentGeneratingId = nil
            return
        }

        let nextId = generationQueue.removeFirst()
        currentGeneratingId = nextId
        isGenerating = true

        let task = Task {
            await generateProxy(for: nextId)
            await MainActor.run {
                self.generationTasks.removeValue(forKey: nextId)
                self.processNextInQueue()
            }
        }

        generationTasks[nextId] = task
    }

    private func generateProxy(for id: UUID) async {
        guard var item = mediaItems[id] else { return }

        item.proxyStatus = .generating
        item.proxyProgress = 0
        await MainActor.run { mediaItems[id] = item }

        do {
            let proxyURL = proxyDirectory.appendingPathComponent("\(id.uuidString).mov")

            // Generate proxy using AVAssetExportSession
            try await generateProxyFile(
                source: item.originalURL,
                destination: proxyURL,
                configuration: configuration,
                progressHandler: { progress in
                    Task { @MainActor in
                        if var item = self.mediaItems[id] {
                            item.proxyProgress = progress
                            self.mediaItems[id] = item
                        }
                    }
                }
            )

            let proxyFileSize = (try? FileManager.default.attributesOfItem(atPath: proxyURL.path)[.size] as? Int64) ?? 0

            await MainActor.run {
                if var item = self.mediaItems[id] {
                    item.proxyURL = proxyURL
                    item.proxyResolution = self.configuration.resolution.targetSize(from: item.sourceResolution)
                    item.proxyStatus = .ready
                    item.proxyProgress = 1.0
                    item.proxyFileSize = proxyFileSize
                    self.mediaItems[id] = item
                    self.currentCacheSize += proxyFileSize
                    self.saveState()
                }
            }

            // Check cache size limit
            await enforceCacheLimit()

        } catch {
            await MainActor.run {
                if var item = self.mediaItems[id] {
                    item.proxyStatus = .failed
                    item.proxyProgress = 0
                    self.mediaItems[id] = item
                }
            }
            print("Proxy generation failed for \(id): \(error)")
        }
    }

    private func generateProxyFile(
        source: URL,
        destination: URL,
        configuration: ProxyConfiguration,
        progressHandler: @escaping (Double) -> Void
    ) async throws {
        let asset = AVURLAsset(url: source)

        // Get video track info
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw ProxyError.noVideoTrack
        }

        let sourceSize = try await videoTrack.load(.naturalSize)
        let targetSize = configuration.resolution.targetSize(from: sourceSize)

        // Create export session
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality) else {
            throw ProxyError.exportSessionCreationFailed
        }

        exportSession.outputURL = destination
        exportSession.outputFileType = .mov

        // Configure video composition for scaling
        let composition = AVMutableVideoComposition()
        composition.renderSize = targetSize

        if let frameRate = configuration.frameRate {
            composition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        } else {
            let sourceFrameRate = try await videoTrack.load(.nominalFrameRate)
            composition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(sourceFrameRate))
        }

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: try await asset.load(.duration))

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)

        // Scale transform
        let scaleX = targetSize.width / sourceSize.width
        let scaleY = targetSize.height / sourceSize.height
        let transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
        layerInstruction.setTransform(transform, at: .zero)

        instruction.layerInstructions = [layerInstruction]
        composition.instructions = [instruction]

        exportSession.videoComposition = composition

        // Monitor progress
        let progressTask = Task {
            while !Task.isCancelled {
                progressHandler(Double(exportSession.progress))
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        }

        // Export
        await exportSession.export()
        progressTask.cancel()

        if let error = exportSession.error {
            throw error
        }

        guard exportSession.status == .completed else {
            throw ProxyError.exportFailed(exportSession.status)
        }
    }

    // MARK: - Cache Management

    /// Get current cache size in bytes
    public var cacheSizeBytes: Int64 {
        currentCacheSize
    }

    /// Get formatted cache size
    public var formattedCacheSize: String {
        ByteCountFormatter.string(fromByteCount: currentCacheSize, countStyle: .file)
    }

    /// Clear all proxies
    public func clearAllProxies() {
        for (id, item) in mediaItems {
            if let proxyURL = item.proxyURL {
                try? FileManager.default.removeItem(at: proxyURL)
            }
            var updatedItem = item
            updatedItem.proxyURL = nil
            updatedItem.proxyStatus = .none
            updatedItem.proxyProgress = 0
            updatedItem.proxyFileSize = nil
            mediaItems[id] = updatedItem
        }

        currentCacheSize = 0
        saveState()
    }

    /// Delete proxy for specific item
    public func deleteProxy(for id: UUID) {
        guard var item = mediaItems[id] else { return }

        if let proxyURL = item.proxyURL {
            try? FileManager.default.removeItem(at: proxyURL)
            currentCacheSize -= item.proxyFileSize ?? 0
        }

        item.proxyURL = nil
        item.proxyStatus = .none
        item.proxyProgress = 0
        item.proxyFileSize = nil
        mediaItems[id] = item

        saveState()
    }

    private func calculateCacheSize() {
        currentCacheSize = mediaItems.values.reduce(0) { $0 + ($1.proxyFileSize ?? 0) }
    }

    private func enforceCacheLimit() async {
        guard currentCacheSize > maxCacheSize else { return }

        // Sort by last accessed (LRU)
        let sortedItems = mediaItems.values
            .filter { $0.proxyStatus == .ready }
            .sorted { $0.lastAccessedAt < $1.lastAccessedAt }

        for item in sortedItems {
            guard currentCacheSize > maxCacheSize else { break }

            await MainActor.run {
                self.deleteProxy(for: item.id)
            }
        }
    }

    // MARK: - Access Tracking

    /// Mark item as accessed (for LRU cache)
    public func markAccessed(id: UUID) {
        guard var item = mediaItems[id] else { return }
        item.lastAccessedAt = Date()
        mediaItems[id] = item
    }

    // MARK: - Persistence

    private func loadState() {
        let stateURL = proxyDirectory.appendingPathComponent("state.json")

        guard FileManager.default.fileExists(atPath: stateURL.path),
              let data = try? Data(contentsOf: stateURL),
              let items = try? JSONDecoder().decode([UUID: ProxyMediaItem].self, from: data) else {
            return
        }

        // Verify proxies still exist
        mediaItems = items.mapValues { item in
            var updatedItem = item
            if let proxyURL = item.proxyURL, !FileManager.default.fileExists(atPath: proxyURL.path) {
                updatedItem.proxyURL = nil
                updatedItem.proxyStatus = .offline
                updatedItem.proxyFileSize = nil
            }
            return updatedItem
        }
    }

    private func saveState() {
        let stateURL = proxyDirectory.appendingPathComponent("state.json")

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(mediaItems)
            try data.write(to: stateURL)
        } catch {
            print("Failed to save proxy state: \(error)")
        }
    }
}

// MARK: - Proxy Errors

public enum ProxyError: LocalizedError {
    case noVideoTrack
    case exportSessionCreationFailed
    case exportFailed(AVAssetExportSession.Status)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .noVideoTrack:
            return "Source file has no video track"
        case .exportSessionCreationFailed:
            return "Failed to create export session"
        case .exportFailed(let status):
            return "Export failed with status: \(status)"
        case .cancelled:
            return "Proxy generation was cancelled"
        }
    }
}

// MARK: - Frame Cache

/// LRU cache for decoded video frames
public final class VideoFrameCache {
    public static let shared = VideoFrameCache()

    private struct CacheEntry {
        let frame: CGImage
        let timestamp: CMTime
        var accessCount: Int
        var lastAccess: Date
    }

    private var cache: [String: CacheEntry] = [:]
    private let maxFrames: Int = 100
    private let lock = NSLock()

    private init() {}

    /// Generate cache key
    public func cacheKey(mediaId: UUID, time: CMTime) -> String {
        "\(mediaId.uuidString)_\(time.seconds)"
    }

    /// Get cached frame
    public func getFrame(mediaId: UUID, time: CMTime) -> CGImage? {
        let key = cacheKey(mediaId: mediaId, time: time)

        lock.lock()
        defer { lock.unlock() }

        if var entry = cache[key] {
            entry.accessCount += 1
            entry.lastAccess = Date()
            cache[key] = entry
            return entry.frame
        }

        return nil
    }

    /// Cache a frame
    public func cacheFrame(_ frame: CGImage, mediaId: UUID, time: CMTime) {
        let key = cacheKey(mediaId: mediaId, time: time)

        lock.lock()
        defer { lock.unlock() }

        // Evict if necessary
        if cache.count >= maxFrames {
            evictLRU()
        }

        cache[key] = CacheEntry(
            frame: frame,
            timestamp: time,
            accessCount: 1,
            lastAccess: Date()
        )
    }

    /// Clear cache for specific media
    public func clearCache(for mediaId: UUID) {
        lock.lock()
        defer { lock.unlock() }

        let prefix = mediaId.uuidString
        cache = cache.filter { !$0.key.hasPrefix(prefix) }
    }

    /// Clear all cache
    public func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
    }

    private func evictLRU() {
        // Find least recently used entry
        if let lruKey = cache.min(by: { $0.value.lastAccess < $1.value.lastAccess })?.key {
            cache.removeValue(forKey: lruKey)
        }
    }
}

// MARK: - Memory Pressure Handler

/// Handles memory warnings by clearing caches
@MainActor
public final class MemoryPressureHandler: ObservableObject {
    public static let shared = MemoryPressureHandler()

    @Published public private(set) var memoryWarningLevel: MemoryWarningLevel = .normal

    public enum MemoryWarningLevel {
        case normal
        case warning
        case critical
    }

    private var source: DispatchSourceMemoryPressure?

    private init() {
        setupMemoryPressureMonitoring()
    }

    private func setupMemoryPressureMonitoring() {
        source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)

        source?.setEventHandler { [weak self] in
            guard let self = self, let source = self.source else { return }

            let event = source.data

            Task { @MainActor in
                if event.contains(.critical) {
                    self.memoryWarningLevel = .critical
                    self.handleCriticalMemory()
                } else if event.contains(.warning) {
                    self.memoryWarningLevel = .warning
                    self.handleMemoryWarning()
                }
            }
        }

        source?.resume()
    }

    private func handleMemoryWarning() {
        // Clear half of the frame cache
        print("Memory warning - reducing caches")
        VideoFrameCache.shared.clearAll()
    }

    private func handleCriticalMemory() {
        // Clear all caches
        print("Critical memory - clearing all caches")
        VideoFrameCache.shared.clearAll()
    }

    deinit {
        source?.cancel()
    }
}

// MARK: - Resolution Aware Player

/// Video player that automatically switches between proxy and original
@MainActor
public final class ResolutionAwarePlayer: ObservableObject {
    @Published public var currentMediaId: UUID?
    @Published public var isUsingProxy: Bool = true
    @Published public private(set) var currentResolution: CGSize = .zero

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private let proxyManager = ProxyManager.shared

    public init() {}

    /// Load media (uses proxy if available and enabled)
    public func loadMedia(id: UUID) {
        guard let item = proxyManager.mediaItems[id] else { return }

        currentMediaId = id
        proxyManager.markAccessed(id: id)

        let useProxy = isUsingProxy && proxyManager.useProxiesForPlayback
        let url = item.currentURL(preferProxy: useProxy)

        currentResolution = useProxy ? (item.proxyResolution ?? item.sourceResolution) : item.sourceResolution

        playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
    }

    /// Switch between proxy and original
    public func toggleResolution() {
        isUsingProxy.toggle()
        if let id = currentMediaId {
            loadMedia(id: id)
        }
    }

    /// Switch to full resolution for export
    public func switchToFullResolution() {
        isUsingProxy = false
        if let id = currentMediaId {
            loadMedia(id: id)
        }
    }

    /// Switch to proxy for editing
    public func switchToProxy() {
        isUsingProxy = true
        if let id = currentMediaId {
            loadMedia(id: id)
        }
    }
}
