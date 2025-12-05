import Foundation
#if canImport(SQLite3)
import SQLite3
#endif

// MARK: - Offline Queue Manager
// Persistent queue for offline operations with automatic sync
// Supports: CRUD operations, conflict resolution, background sync

@MainActor
public final class OfflineQueueManager: ObservableObject {
    public static let shared = OfflineQueueManager()

    @Published public private(set) var pendingOperations: Int = 0
    @Published public private(set) var isSyncing = false
    @Published public private(set) var lastSyncDate: Date?
    @Published public private(set) var syncProgress: Double = 0

    // Storage
    private var storage: OfflineStorage
    private var queue: [QueuedOperation] = []

    // Sync management
    private var syncTimer: Timer?
    private var isOnline = true
    private var retryCount: [UUID: Int] = [:]

    // Configuration
    public struct Configuration {
        public var maxRetries: Int = 5
        public var retryDelay: TimeInterval = 5
        public var batchSize: Int = 10
        public var syncInterval: TimeInterval = 30
        public var maxQueueSize: Int = 1000
        public var persistToDisk: Bool = true

        public static let `default` = Configuration()
    }

    private var config: Configuration = .default

    public init() {
        self.storage = OfflineStorage()
        loadPersistedQueue()
        startNetworkMonitoring()
    }

    // MARK: - Queue Operations

    /// Add operation to offline queue
    public func enqueue(_ operation: QueuedOperation) async throws {
        guard queue.count < config.maxQueueSize else {
            throw OfflineQueueError.queueFull
        }

        queue.append(operation)
        pendingOperations = queue.count

        if config.persistToDisk {
            try await storage.save(operation)
        }

        // Try immediate sync if online
        if isOnline {
            await processQueue()
        }
    }

    /// Create and enqueue a data operation
    public func enqueue(
        type: OperationType,
        entityType: String,
        entityId: String,
        data: Data?,
        priority: OperationPriority = .normal
    ) async throws {
        let operation = QueuedOperation(
            type: type,
            entityType: entityType,
            entityId: entityId,
            data: data,
            priority: priority
        )

        try await enqueue(operation)
    }

    /// Remove operation from queue
    public func dequeue(_ operationId: UUID) async {
        queue.removeAll { $0.id == operationId }
        pendingOperations = queue.count
        retryCount.removeValue(forKey: operationId)

        if config.persistToDisk {
            await storage.delete(operationId)
        }
    }

    /// Get all pending operations
    public func getPendingOperations() -> [QueuedOperation] {
        return queue.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }

    /// Clear all pending operations
    public func clearQueue() async {
        queue.removeAll()
        retryCount.removeAll()
        pendingOperations = 0

        if config.persistToDisk {
            await storage.clearAll()
        }
    }

    // MARK: - Sync Processing

    /// Process the offline queue
    public func processQueue() async {
        guard !isSyncing && isOnline && !queue.isEmpty else { return }

        isSyncing = true
        syncProgress = 0

        let sortedQueue = queue.sorted { $0.priority.rawValue > $1.priority.rawValue }
        let batch = Array(sortedQueue.prefix(config.batchSize))

        var processed = 0

        for operation in batch {
            do {
                try await processOperation(operation)
                await dequeue(operation.id)
                processed += 1
            } catch {
                await handleOperationError(operation, error: error)
            }

            syncProgress = Double(processed) / Double(batch.count)
        }

        lastSyncDate = Date()
        isSyncing = false
        syncProgress = queue.isEmpty ? 1.0 : syncProgress

        // Continue processing if more items
        if !queue.isEmpty && isOnline {
            try? await Task.sleep(nanoseconds: UInt64(config.retryDelay * 1_000_000_000))
            await processQueue()
        }
    }

    private func processOperation(_ operation: QueuedOperation) async throws {
        switch operation.type {
        case .create:
            try await syncCreate(operation)
        case .update:
            try await syncUpdate(operation)
        case .delete:
            try await syncDelete(operation)
        case .upload:
            try await syncUpload(operation)
        case .custom(let handler):
            try await handler(operation)
        }
    }

    private func syncCreate(_ operation: QueuedOperation) async throws {
        // Implement actual API call
        guard let data = operation.data else {
            throw OfflineQueueError.missingData
        }

        let url = URL(string: "https://api.echoelmusic.com/\(operation.entityType)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw OfflineQueueError.syncFailed
        }
    }

    private func syncUpdate(_ operation: QueuedOperation) async throws {
        guard let data = operation.data else {
            throw OfflineQueueError.missingData
        }

        let url = URL(string: "https://api.echoelmusic.com/\(operation.entityType)/\(operation.entityId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw OfflineQueueError.syncFailed
        }
    }

    private func syncDelete(_ operation: QueuedOperation) async throws {
        let url = URL(string: "https://api.echoelmusic.com/\(operation.entityType)/\(operation.entityId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw OfflineQueueError.syncFailed
        }
    }

    private func syncUpload(_ operation: QueuedOperation) async throws {
        guard let data = operation.data else {
            throw OfflineQueueError.missingData
        }

        let url = URL(string: "https://api.echoelmusic.com/upload/\(operation.entityType)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(operation.entityId)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw OfflineQueueError.syncFailed
        }
    }

    private func handleOperationError(_ operation: QueuedOperation, error: Error) async {
        let currentRetries = retryCount[operation.id] ?? 0

        if currentRetries < config.maxRetries {
            retryCount[operation.id] = currentRetries + 1
            print("Operation \(operation.id) failed, retry \(currentRetries + 1)/\(config.maxRetries)")
        } else {
            // Mark as failed, remove from queue
            print("Operation \(operation.id) failed permanently: \(error)")
            await dequeue(operation.id)

            // Notify failure
            NotificationCenter.default.post(
                name: .offlineOperationFailed,
                object: nil,
                userInfo: ["operation": operation, "error": error]
            )
        }
    }

    // MARK: - Persistence

    private func loadPersistedQueue() {
        Task {
            queue = await storage.loadAll()
            pendingOperations = queue.count
        }
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        // Monitor network state
        NotificationCenter.default.addObserver(
            forName: .networkStatusChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let isOnline = notification.userInfo?["isOnline"] as? Bool {
                self?.handleNetworkChange(isOnline: isOnline)
            }
        }

        // Start sync timer
        syncTimer = Timer.scheduledTimer(withTimeInterval: config.syncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.processQueue()
            }
        }
    }

    private func handleNetworkChange(isOnline: Bool) {
        self.isOnline = isOnline

        if isOnline && !queue.isEmpty {
            Task {
                await processQueue()
            }
        }
    }

    public func configure(_ config: Configuration) {
        self.config = config
    }
}

// MARK: - Queued Operation

public struct QueuedOperation: Codable, Identifiable {
    public let id: UUID
    public let type: OperationType
    public let entityType: String
    public let entityId: String
    public let data: Data?
    public let priority: OperationPriority
    public let timestamp: Date
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        type: OperationType,
        entityType: String,
        entityId: String,
        data: Data? = nil,
        priority: OperationPriority = .normal,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.entityType = entityType
        self.entityId = entityId
        self.data = data
        self.priority = priority
        self.timestamp = Date()
        self.metadata = metadata
    }
}

public enum OperationType: Codable {
    case create
    case update
    case delete
    case upload
    case custom((QueuedOperation) async throws -> Void)

    // Custom Codable implementation
    enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "create": self = .create
        case "update": self = .update
        case "delete": self = .delete
        case "upload": self = .upload
        default: self = .create
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .create: try container.encode("create", forKey: .type)
        case .update: try container.encode("update", forKey: .type)
        case .delete: try container.encode("delete", forKey: .type)
        case .upload: try container.encode("upload", forKey: .type)
        case .custom: try container.encode("custom", forKey: .type)
        }
    }
}

public enum OperationPriority: Int, Codable, Comparable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3

    public static func < (lhs: OperationPriority, rhs: OperationPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Offline Storage

public actor OfflineStorage {
    private let fileManager = FileManager.default
    private var queueDirectory: URL

    public init() {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        queueDirectory = documentsPath.appendingPathComponent("OfflineQueue", isDirectory: true)

        try? fileManager.createDirectory(at: queueDirectory, withIntermediateDirectories: true)
    }

    public func save(_ operation: QueuedOperation) throws {
        let fileURL = queueDirectory.appendingPathComponent("\(operation.id.uuidString).json")
        let data = try JSONEncoder().encode(operation)
        try data.write(to: fileURL)
    }

    public func load(_ id: UUID) -> QueuedOperation? {
        let fileURL = queueDirectory.appendingPathComponent("\(id.uuidString).json")

        guard let data = try? Data(contentsOf: fileURL),
              let operation = try? JSONDecoder().decode(QueuedOperation.self, from: data) else {
            return nil
        }

        return operation
    }

    public func loadAll() -> [QueuedOperation] {
        guard let files = try? fileManager.contentsOfDirectory(at: queueDirectory, includingPropertiesForKeys: nil) else {
            return []
        }

        return files.compactMap { url -> QueuedOperation? in
            guard url.pathExtension == "json",
                  let data = try? Data(contentsOf: url),
                  let operation = try? JSONDecoder().decode(QueuedOperation.self, from: data) else {
                return nil
            }
            return operation
        }.sorted { $0.timestamp < $1.timestamp }
    }

    public func delete(_ id: UUID) {
        let fileURL = queueDirectory.appendingPathComponent("\(id.uuidString).json")
        try? fileManager.removeItem(at: fileURL)
    }

    public func clearAll() {
        guard let files = try? fileManager.contentsOfDirectory(at: queueDirectory, includingPropertiesForKeys: nil) else {
            return
        }

        for file in files {
            try? fileManager.removeItem(at: file)
        }
    }
}

// MARK: - Conflict Resolution

public protocol ConflictResolver {
    func resolve(local: QueuedOperation, remote: Data) async -> ConflictResolution
}

public enum ConflictResolution {
    case useLocal
    case useRemote
    case merge(Data)
    case manual
}

public class LastWriteWinsResolver: ConflictResolver {
    public func resolve(local: QueuedOperation, remote: Data) async -> ConflictResolution {
        // Simple last-write-wins strategy
        return .useLocal
    }
}

public class MergeResolver: ConflictResolver {
    public func resolve(local: QueuedOperation, remote: Data) async -> ConflictResolution {
        // Attempt 3-way merge
        guard let localData = local.data else {
            return .useRemote
        }

        // Try to merge JSON data
        if let localJSON = try? JSONSerialization.jsonObject(with: localData) as? [String: Any],
           let remoteJSON = try? JSONSerialization.jsonObject(with: remote) as? [String: Any] {

            var merged = remoteJSON
            for (key, value) in localJSON {
                merged[key] = value
            }

            if let mergedData = try? JSONSerialization.data(withJSONObject: merged) {
                return .merge(mergedData)
            }
        }

        return .useLocal
    }
}

// MARK: - Errors

public enum OfflineQueueError: Error {
    case queueFull
    case missingData
    case syncFailed
    case persistenceFailed
    case conflictDetected
}

// MARK: - Notifications

extension Notification.Name {
    public static let offlineOperationFailed = Notification.Name("offlineOperationFailed")
    public static let networkStatusChanged = Notification.Name("networkStatusChanged")
    public static let offlineQueueSynced = Notification.Name("offlineQueueSynced")
}
