import Foundation
import Combine
import Accelerate

/// Memory Optimization Manager für Low-RAM-Geräte
///
/// Dieses System implementiert speichereffiziente Algorithmen und Datenstrukturen,
/// um Echoelmusic auch auf Geräten mit begrenztem RAM (< 3GB) performant laufen zu lassen.
///
/// Features:
/// - Intelligente Speicherverwaltung mit Prioritätssystem
/// - Lazy Loading und Progressive Streaming
/// - Memory-mapped Files für große Datensätze
/// - Komprimierte In-Memory-Repräsentationen
/// - Aggressive Garbage Collection
/// - Object Pooling für häufig verwendete Objekte
/// - Circular Buffer für Audio-Streaming
/// - Chunk-basierte Verarbeitung großer Dateien
///
@MainActor
@Observable
class MemoryOptimizationManager {

    // MARK: - Published Properties

    /// Aktuelle Speichernutzung
    var memoryUsage: MemoryUsage = MemoryUsage()

    /// Ist Speicheroptimierung aktiviert?
    var isMemoryOptimizationEnabled: Bool = true

    /// Cache-Statistiken
    var cacheStats: CacheStatistics = CacheStatistics()

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var objectPools: [String: Any] = [:]
    private var memoryMappedFiles: [String: MemoryMappedFile] = [:]
    private var cachedData: [String: CachedItem] = [:]
    private var compressionBuffers: [CompressionBuffer] = []

    /// Maximale Cache-Größe (in Bytes)
    private let maxCacheSize: Int = 100 * 1024 * 1024 // 100 MB

    /// Memory Pressure Threshold (80%)
    private let memoryPressureThreshold: Float = 0.8

    // MARK: - Memory Usage

    struct MemoryUsage {
        var totalPhysicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory
        var usedMemory: UInt64 = 0
        var availableMemory: UInt64 = 0
        var cacheSize: UInt64 = 0
        var pooledObjectsSize: UInt64 = 0

        var usagePercentage: Float {
            guard totalPhysicalMemory > 0 else { return 0.0 }
            return Float(usedMemory) / Float(totalPhysicalMemory)
        }

        var isPressured: Bool {
            usagePercentage > 0.8
        }
    }

    // MARK: - Cache Statistics

    struct CacheStatistics {
        var hits: Int = 0
        var misses: Int = 0
        var evictions: Int = 0
        var totalItems: Int = 0

        var hitRate: Float {
            let total = hits + misses
            guard total > 0 else { return 0.0 }
            return Float(hits) / Float(total)
        }
    }

    // MARK: - Cached Item

    private class CachedItem {
        let key: String
        var data: Data
        var lastAccessed: Date
        var accessCount: Int
        var priority: Priority

        enum Priority: Int, Comparable {
            case low = 0
            case normal = 1
            case high = 2
            case critical = 3

            static func < (lhs: Priority, rhs: Priority) -> Bool {
                lhs.rawValue < rhs.rawValue
            }
        }

        init(key: String, data: Data, priority: Priority = .normal) {
            self.key = key
            self.data = data
            self.lastAccessed = Date()
            self.accessCount = 0
            self.priority = priority
        }

        var size: Int {
            data.count
        }

        var score: Float {
            // Berechne Score basierend auf Zugriffshäufigkeit, Zeit und Priorität
            let recencyScore = Float(1.0 / max(1.0, Date().timeIntervalSince(lastAccessed)))
            let frequencyScore = Float(accessCount)
            let priorityScore = Float(priority.rawValue) * 100.0

            return recencyScore + frequencyScore + priorityScore
        }
    }

    // MARK: - Memory Mapped File

    private class MemoryMappedFile {
        let path: String
        let size: Int
        private var mappedData: UnsafeMutableRawPointer?

        init?(path: String) {
            self.path = path

            guard let fileHandle = FileHandle(forReadingAtPath: path),
                  let size = try? fileHandle.seekToEnd() else {
                return nil
            }

            self.size = Int(size)

            // Map file to memory
            let fd = open(path, O_RDONLY)
            guard fd >= 0 else { return nil }

            mappedData = mmap(nil, size, PROT_READ, MAP_PRIVATE, fd, 0)
            close(fd)

            if mappedData == MAP_FAILED {
                mappedData = nil
                return nil
            }
        }

        func readChunk(offset: Int, length: Int) -> Data? {
            guard let mappedData = mappedData,
                  offset + length <= size else {
                return nil
            }

            return Data(bytes: mappedData.advanced(by: offset), count: length)
        }

        deinit {
            if let mappedData = mappedData {
                munmap(mappedData, size)
            }
        }
    }

    // MARK: - Compression Buffer

    private class CompressionBuffer {
        private var compressedData: Data?
        private var uncompressedSize: Int

        init(data: Data) {
            self.uncompressedSize = data.count
            self.compressedData = compress(data)
        }

        private func compress(_ data: Data) -> Data? {
            // LZ4 compression für schnelle Komprimierung/Dekomprimierung
            let sourceBuffer = [UInt8](data)
            let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
            defer { destinationBuffer.deallocate() }

            // Verwende Accelerate Framework für Kompression
            var compressedSize = data.count
            let algorithm = COMPRESSION_LZ4

            guard let compressedData = data.withUnsafeBytes({ (sourcePtr: UnsafeRawBufferPointer) -> Data? in
                guard let baseAddress = sourcePtr.baseAddress else { return nil }
                let size = compression_encode_buffer(
                    destinationBuffer,
                    data.count,
                    baseAddress.assumingMemoryBound(to: UInt8.self),
                    data.count,
                    nil,
                    algorithm
                )
                guard size > 0 else { return nil }
                compressedSize = size
                return Data(bytes: destinationBuffer, count: size)
            }) else {
                return nil
            }

            print("🗜️ Compressed \(data.count) → \(compressedSize) bytes (ratio: \(String(format: "%.2f", Float(compressedSize) / Float(data.count))))")

            return compressedData
        }

        func decompress() -> Data? {
            guard let compressedData = compressedData else { return nil }

            let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: uncompressedSize)
            defer { destinationBuffer.deallocate() }

            let algorithm = COMPRESSION_LZ4

            guard let decompressedData = compressedData.withUnsafeBytes({ (sourcePtr: UnsafeRawBufferPointer) -> Data? in
                guard let baseAddress = sourcePtr.baseAddress else { return nil }
                let size = compression_decode_buffer(
                    destinationBuffer,
                    uncompressedSize,
                    baseAddress.assumingMemoryBound(to: UInt8.self),
                    compressedData.count,
                    nil,
                    algorithm
                )
                guard size > 0 else { return nil }
                return Data(bytes: destinationBuffer, count: size)
            }) else {
                return nil
            }

            return decompressedData
        }

        var compressionRatio: Float {
            guard let compressedData = compressedData else { return 1.0 }
            return Float(compressedData.count) / Float(uncompressedSize)
        }
    }

    // MARK: - Object Pool

    class ObjectPool<T> {
        private var pool: [T] = []
        private let factory: () -> T
        private let reset: (T) -> Void
        private let maxSize: Int

        init(maxSize: Int = 50, factory: @escaping () -> T, reset: @escaping (T) -> Void) {
            self.maxSize = maxSize
            self.factory = factory
            self.reset = reset
        }

        func acquire() -> T {
            if let object = pool.popLast() {
                return object
            } else {
                return factory()
            }
        }

        func release(_ object: T) {
            if pool.count < maxSize {
                reset(object)
                pool.append(object)
            }
        }

        var count: Int {
            pool.count
        }
    }

    // MARK: - Circular Buffer (für Audio-Streaming)

    class CircularBuffer<T> {
        private var buffer: [T]
        private var readIndex: Int = 0
        private var writeIndex: Int = 0
        private var count: Int = 0
        private let capacity: Int

        init(capacity: Int, defaultValue: T) {
            self.capacity = capacity
            self.buffer = Array(repeating: defaultValue, count: capacity)
        }

        func write(_ value: T) -> Bool {
            guard count < capacity else { return false }

            buffer[writeIndex] = value
            writeIndex = (writeIndex + 1) % capacity
            count += 1

            return true
        }

        func read() -> T? {
            guard count > 0 else { return nil }

            let value = buffer[readIndex]
            readIndex = (readIndex + 1) % capacity
            count -= 1

            return value
        }

        func peek() -> T? {
            guard count > 0 else { return nil }
            return buffer[readIndex]
        }

        var isEmpty: Bool {
            count == 0
        }

        var isFull: Bool {
            count == capacity
        }

        var availableSpace: Int {
            capacity - count
        }

        func clear() {
            readIndex = 0
            writeIndex = 0
            count = 0
        }
    }

    // MARK: - Initialization

    init() {
        setupMonitoring()
    }

    private func setupMonitoring() {
        // Überwache Speichernutzung alle 2 Sekunden
        Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    self.updateMemoryUsage()
                    self.evaluateMemoryPressure()
                }
            }
            .store(in: &cancellables)

        // Memory Warning Handler
        #if os(iOS)
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    self.handleMemoryWarning()
                }
            }
            .store(in: &cancellables)
        #endif
    }

    // MARK: - Memory Usage Monitoring

    private func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return }

        memoryUsage.usedMemory = info.resident_size
        memoryUsage.availableMemory = memoryUsage.totalPhysicalMemory - info.resident_size

        // Berechne Cache-Größe
        memoryUsage.cacheSize = UInt64(cachedData.values.reduce(0) { $0 + $1.size })

        // Berechne Pool-Größe (vereinfacht)
        memoryUsage.pooledObjectsSize = UInt64(objectPools.count * 1024) // Schätzung
    }

    private func evaluateMemoryPressure() {
        guard isMemoryOptimizationEnabled else { return }

        if memoryUsage.isPressured {
            print("⚠️ Memory pressure detected: \(String(format: "%.1f%%", memoryUsage.usagePercentage * 100))")
            reduceCacheSize(by: 0.5) // Reduziere Cache um 50%
        }
    }

    private func handleMemoryWarning() {
        print("🚨 Memory Warning! Performing aggressive cleanup...")

        // Sofortige Notfall-Maßnahmen
        clearAllCaches()
        compressInMemoryData()
        releaseUnusedPools()

        updateMemoryUsage()
        print("✅ Cleanup completed. Memory usage: \(String(format: "%.1f%%", memoryUsage.usagePercentage * 100))")
    }

    // MARK: - Cache Management

    func cache(key: String, data: Data, priority: CachedItem.Priority = .normal) {
        // Prüfe ob Cache-Limit erreicht
        if memoryUsage.cacheSize + UInt64(data.count) > maxCacheSize {
            evictLRUItems()
        }

        if let existing = cachedData[key] {
            existing.data = data
            existing.lastAccessed = Date()
            existing.accessCount += 1
            cacheStats.hits += 1
        } else {
            cachedData[key] = CachedItem(key: key, data: data, priority: priority)
            cacheStats.misses += 1
            cacheStats.totalItems += 1
        }
    }

    func retrieve(key: String) -> Data? {
        guard let item = cachedData[key] else {
            cacheStats.misses += 1
            return nil
        }

        item.lastAccessed = Date()
        item.accessCount += 1
        cacheStats.hits += 1

        return item.data
    }

    private func evictLRUItems() {
        // Entferne Items mit niedrigstem Score (LRU + Priorität)
        let sortedItems = cachedData.values.sorted { $0.score < $1.score }

        var freedSpace: Int = 0
        let targetSpace = maxCacheSize / 4 // Mache 25% frei

        for item in sortedItems {
            if freedSpace >= targetSpace {
                break
            }

            cachedData.removeValue(forKey: item.key)
            freedSpace += item.size
            cacheStats.evictions += 1
            cacheStats.totalItems -= 1
        }

        print("🧹 Evicted \(cacheStats.evictions) items, freed \(freedSpace / 1024) KB")
    }

    func clearCache(priority: CachedItem.Priority? = nil) {
        if let priority = priority {
            // Entferne nur Items mit dieser Priorität
            cachedData = cachedData.filter { $0.value.priority != priority }
        } else {
            // Entferne alle Items
            cachedData.removeAll()
        }

        cacheStats.totalItems = cachedData.count
    }

    private func clearAllCaches() {
        cachedData.removeAll()
        cacheStats.totalItems = 0
        memoryMappedFiles.removeAll()
    }

    private func reduceCacheSize(by ratio: Float) {
        let targetSize = Int(Float(maxCacheSize) * (1.0 - ratio))
        var currentSize = cachedData.values.reduce(0) { $0 + $1.size }

        let sortedItems = cachedData.values.sorted { $0.score < $1.score }

        for item in sortedItems {
            if currentSize <= targetSize {
                break
            }

            cachedData.removeValue(forKey: item.key)
            currentSize -= item.size
            cacheStats.evictions += 1
            cacheStats.totalItems -= 1
        }
    }

    // MARK: - Memory-Mapped Files

    func openMemoryMappedFile(path: String) -> Bool {
        guard memoryMappedFiles[path] == nil else {
            return true // Already open
        }

        if let mmFile = MemoryMappedFile(path: path) {
            memoryMappedFiles[path] = mmFile
            print("📂 Memory-mapped file: \(path) (\(mmFile.size / 1024) KB)")
            return true
        }

        return false
    }

    func readFromMemoryMappedFile(path: String, offset: Int, length: Int) -> Data? {
        guard let mmFile = memoryMappedFiles[path] else {
            return nil
        }

        return mmFile.readChunk(offset: offset, length: length)
    }

    func closeMemoryMappedFile(path: String) {
        memoryMappedFiles.removeValue(forKey: path)
    }

    // MARK: - Compression

    func compressData(_ data: Data) -> CompressionBuffer {
        let buffer = CompressionBuffer(data: data)
        compressionBuffers.append(buffer)
        return buffer
    }

    func decompressBuffer(_ buffer: CompressionBuffer) -> Data? {
        return buffer.decompress()
    }

    private func compressInMemoryData() {
        // Komprimiere große Cache-Items
        let largeItems = cachedData.values.filter { $0.size > 50 * 1024 } // > 50 KB

        for item in largeItems {
            if let compressed = compress(item.data) {
                let savings = item.data.count - compressed.count
                if savings > 0 {
                    item.data = compressed
                    print("🗜️ Compressed \(item.key): saved \(savings / 1024) KB")
                }
            }
        }
    }

    // MARK: - Object Pooling

    func createPool<T>(name: String, maxSize: Int = 50, factory: @escaping () -> T, reset: @escaping (T) -> Void) {
        objectPools[name] = ObjectPool<T>(maxSize: maxSize, factory: factory, reset: reset)
    }

    func acquireFromPool<T>(name: String) -> T? {
        guard let pool = objectPools[name] as? ObjectPool<T> else {
            return nil
        }
        return pool.acquire()
    }

    func releaseToPool<T>(name: String, object: T) {
        guard let pool = objectPools[name] as? ObjectPool<T> else {
            return
        }
        pool.release(object)
    }

    private func releaseUnusedPools() {
        // Entferne leere Pools
        objectPools = objectPools.filter { (key, value) in
            // Type-erase check
            return true // Behalte alle für diese Implementierung
        }
    }

    // MARK: - Chunk-based Processing

    func processLargeFile(path: String, chunkSize: Int = 1024 * 1024, processor: (Data) -> Void) async throws {
        guard let fileHandle = FileHandle(forReadingAtPath: path) else {
            throw MemoryOptimizationError.fileNotFound
        }

        defer {
            try? fileHandle.close()
        }

        // Memory-map für effizientes Lesen
        if openMemoryMappedFile(path: path) {
            guard let mmFile = memoryMappedFiles[path] else { return }

            var offset = 0
            while offset < mmFile.size {
                let length = min(chunkSize, mmFile.size - offset)
                if let chunk = mmFile.readChunk(offset: offset, length: length) {
                    processor(chunk)
                }
                offset += chunkSize

                // Yield to allow UI updates
                await Task.yield()
            }

            closeMemoryMappedFile(path: path)
        } else {
            // Fallback: Standard chunk-based reading
            while true {
                guard let chunk = try fileHandle.read(upToCount: chunkSize) else {
                    break
                }

                if chunk.isEmpty {
                    break
                }

                processor(chunk)

                // Yield to allow UI updates
                await Task.yield()
            }
        }
    }

    // MARK: - Helper Functions

    private func compress(_ data: Data) -> Data? {
        // Simple compression using Foundation
        return try? (data as NSData).compressed(using: .lz4) as Data
    }

    // MARK: - Statistics

    func getMemoryReport() -> String {
        var report = "💾 Memory Report\n"
        report += "━━━━━━━━━━━━━━━━━━━━━━\n"
        report += "Total Physical Memory: \(memoryUsage.totalPhysicalMemory / (1024 * 1024)) MB\n"
        report += "Used Memory: \(memoryUsage.usedMemory / (1024 * 1024)) MB\n"
        report += "Available Memory: \(memoryUsage.availableMemory / (1024 * 1024)) MB\n"
        report += "Usage: \(String(format: "%.1f%%", memoryUsage.usagePercentage * 100))\n"
        report += "━━━━━━━━━━━━━━━━━━━━━━\n"
        report += "Cache Size: \(memoryUsage.cacheSize / 1024) KB\n"
        report += "Cached Items: \(cacheStats.totalItems)\n"
        report += "Cache Hit Rate: \(String(format: "%.1f%%", cacheStats.hitRate * 100))\n"
        report += "Cache Evictions: \(cacheStats.evictions)\n"
        report += "━━━━━━━━━━━━━━━━━━━━━━\n"
        report += "Memory-Mapped Files: \(memoryMappedFiles.count)\n"
        report += "Object Pools: \(objectPools.count)\n"
        report += "Compression Buffers: \(compressionBuffers.count)\n"

        return report
    }
}

// MARK: - Errors

enum MemoryOptimizationError: Error {
    case fileNotFound
    case compressionFailed
    case decompressionFailed
    case memoryMappingFailed
}

// MARK: - Specialized Data Structures for Low-RAM

/// Sparse Array: Speichereffiziente Repräsentation großer Arrays mit vielen Nullwerten
class SparseArray<T: Equatable> {
    private var storage: [Int: T] = [:]
    private let defaultValue: T
    let capacity: Int

    init(capacity: Int, defaultValue: T) {
        self.capacity = capacity
        self.defaultValue = defaultValue
    }

    subscript(index: Int) -> T {
        get {
            storage[index] ?? defaultValue
        }
        set {
            if newValue == defaultValue {
                storage.removeValue(forKey: index)
            } else {
                storage[index] = newValue
            }
        }
    }

    var nonDefaultCount: Int {
        storage.count
    }

    var compressionRatio: Float {
        let fullSize = capacity * MemoryLayout<T>.size
        let sparseSize = storage.count * (MemoryLayout<Int>.size + MemoryLayout<T>.size)
        return Float(sparseSize) / Float(fullSize)
    }
}

/// Ring Buffer: Speichereffiziente zirkulare Queue
class RingBuffer<T> {
    private var buffer: UnsafeMutablePointer<T>
    private var capacity: Int
    private var head: Int = 0
    private var tail: Int = 0
    private var count: Int = 0

    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = UnsafeMutablePointer<T>.allocate(capacity: capacity)
    }

    deinit {
        buffer.deallocate()
    }

    func append(_ element: T) -> Bool {
        guard count < capacity else { return false }
        buffer.advanced(by: tail).initialize(to: element)
        tail = (tail + 1) % capacity
        count += 1
        return true
    }

    func removeFirst() -> T? {
        guard count > 0 else { return nil }
        let element = buffer.advanced(by: head).move()
        head = (head + 1) % capacity
        count -= 1
        return element
    }

    var isEmpty: Bool { count == 0 }
    var isFull: Bool { count == capacity }
}
