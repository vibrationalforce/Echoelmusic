//
//  RateLimiter.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  API rate limiting and network optimization
//

import Foundation

/// Actor-based rate limiter for API calls
actor RateLimiter {
    // MARK: - Rate Limit Configuration

    struct RateLimitConfig {
        let maxRequests: Int
        let timeWindow: TimeInterval

        static let standard = RateLimitConfig(maxRequests: 100, timeWindow: 60.0)  // 100 req/min
        static let strict = RateLimitConfig(maxRequests: 10, timeWindow: 60.0)     // 10 req/min
        static let lenient = RateLimitConfig(maxRequests: 1000, timeWindow: 60.0)  // 1000 req/min
    }

    // MARK: - Request Tracking

    private struct RequestRecord {
        let timestamp: Date
        let endpoint: String
    }

    private var requestHistory: [String: [RequestRecord]] = [:]
    private let config: RateLimitConfig

    // MARK: - Initialization

    init(config: RateLimitConfig = .standard) {
        self.config = config
    }

    // MARK: - Rate Limiting

    func canMakeRequest(for endpoint: String) async -> Bool {
        cleanupOldRecords(for: endpoint)

        let currentRequests = requestHistory[endpoint] ?? []

        if currentRequests.count >= config.maxRequests {
            return false  // Rate limit exceeded
        }

        // Record this request
        let record = RequestRecord(timestamp: Date(), endpoint: endpoint)
        requestHistory[endpoint, default: []].append(record)

        return true
    }

    func waitForAvailability(for endpoint: String) async throws {
        while !(await canMakeRequest(for: endpoint)) {
            // Wait before retrying
            try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
        }
    }

    private func cleanupOldRecords(for endpoint: String) {
        let cutoffTime = Date().addingTimeInterval(-config.timeWindow)

        requestHistory[endpoint]?.removeAll { record in
            record.timestamp < cutoffTime
        }
    }

    // MARK: - Statistics

    func getCurrentUsage(for endpoint: String) async -> (current: Int, max: Int) {
        cleanupOldRecords(for: endpoint)
        let current = requestHistory[endpoint]?.count ?? 0
        return (current, config.maxRequests)
    }

    func reset() async {
        requestHistory.removeAll()
    }
}

// MARK: - Network Optimizer

final class NetworkOptimizer {
    static let shared = NetworkOptimizer()

    private let rateLimiter = RateLimiter()
    private let cache = URLCache(
        memoryCapacity: 50_000_000,   // 50 MB
        diskCapacity: 100_000_000      // 100 MB
    )

    private init() {
        URLCache.shared = cache
    }

    // MARK: - Cached Requests

    func fetchWithCache(url: URL, cachePolicy: URLRequest.CachePolicy = .returnCacheDataElseLoad) async throws -> Data {
        let request = URLRequest(url: url, cachePolicy: cachePolicy)

        // Check rate limit
        guard await rateLimiter.canMakeRequest(for: url.absoluteString) else {
            throw NetworkError.rateLimitExceeded
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        // Cache successful response
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            cache.storeCachedResponse(
                CachedURLResponse(response: response, data: data),
                for: request
            )
        }

        return data
    }

    // MARK: - Retry with Exponential Backoff

    func retryWithBackoff<T>(
        maxRetries: Int = 3,
        initialDelay: TimeInterval = 2.0,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        var delay = initialDelay

        for attempt in 0..<maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error

                if attempt < maxRetries - 1 {
                    // Wait with exponential backoff
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    delay *= 2.0  // Double the delay
                }
            }
        }

        throw lastError ?? NetworkError.maxRetriesExceeded
    }

    // MARK: - Batch Requests

    func batchRequests(_ urls: [URL]) async throws -> [Data] {
        try await withThrowingTaskGroup(of: (Int, Data).self) { group in
            for (index, url) in urls.enumerated() {
                group.addTask {
                    let data = try await self.fetchWithCache(url: url)
                    return (index, data)
                }
            }

            var results: [Data?] = Array(repeating: nil, count: urls.count)

            for try await (index, data) in group {
                results[index] = data
            }

            return results.compactMap { $0 }
        }
    }

    // MARK: - Network Reachability

    func checkReachability() async -> Bool {
        do {
            let (_, response) = try await URLSession.shared.data(from: URL(string: "https://www.apple.com")!)

            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
        } catch {
            return false
        }

        return false
    }

    // MARK: - Request Compression

    func compressRequest(_ data: Data) throws -> Data {
        return try (data as NSData).compressed(using: .lzfse) as Data
    }

    func decompressResponse(_ data: Data) throws -> Data {
        return try (data as NSData).decompressed(using: .lzfse) as Data
    }
}

// MARK: - Network Errors

enum NetworkError: Error {
    case rateLimitExceeded
    case maxRetriesExceeded
    case networkUnavailable
    case invalidResponse
    case timeout
}

// MARK: - Offline Queue

actor OfflineQueue {
    private var queuedRequests: [(url: URL, data: Data?, method: String)] = []

    func enqueue(url: URL, data: Data? = nil, method: String = "GET") {
        queuedRequests.append((url, data, method))
    }

    func processQueue() async throws {
        for request in queuedRequests {
            // Try to process each queued request
            var urlRequest = URLRequest(url: request.url)
            urlRequest.httpMethod = request.method
            urlRequest.httpBody = request.data

            do {
                _ = try await URLSession.shared.data(for: urlRequest)
            } catch {
                // Keep in queue if still failing
                continue
            }
        }

        // Clear successfully processed requests
        queuedRequests.removeAll()
    }

    func clearQueue() {
        queuedRequests.removeAll()
    }

    func queueSize() -> Int {
        queuedRequests.count
    }
}
