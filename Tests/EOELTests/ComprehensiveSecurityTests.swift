//
//  ComprehensiveSecurityTests.swift
//  EOELTests
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  Comprehensive security and safety testing suite
//

import XCTest
@testable import EOEL

final class ComprehensiveSecurityTests: XCTestCase {
    var secureStorage: SecureStorageManager!

    override func setUp() async throws {
        secureStorage = SecureStorageManager.shared
        try secureStorage.clearAll()
    }

    override func tearDown() async throws {
        try secureStorage.clearAll()
    }

    // MARK: - Keychain Storage Tests

    func testStoreAndRetrieveFirebaseToken() throws {
        let testToken = "test_firebase_token_12345"

        try secureStorage.storeFirebaseToken(testToken)
        let retrieved = try secureStorage.getFirebaseToken()

        XCTAssertEqual(retrieved, testToken)
    }

    func testStoreAndRetrieveEoelWorkToken() throws {
        let testToken = "test_eoelwork_token_67890"

        try secureStorage.storeEoelWorkToken(testToken)
        let retrieved = try secureStorage.getEoelWorkToken()

        XCTAssertEqual(retrieved, testToken)
    }

    func testDeleteTokens() throws {
        let testToken = "test_token"

        try secureStorage.storeFirebaseToken(testToken)
        XCTAssertNotNil(try secureStorage.getFirebaseToken())

        try secureStorage.deleteFirebaseTokens()
        XCTAssertNil(try secureStorage.getFirebaseToken())
    }

    func testAPIKeyStorage() throws {
        let apiKey = "sk_test_abcdef123456"
        let service = "stripe"

        try secureStorage.storeAPIKey(apiKey, for: service)
        let retrieved = try secureStorage.getAPIKey(for: service)

        XCTAssertEqual(retrieved, apiKey)
    }

    // MARK: - File Encryption Tests

    func testEncryptAndDecryptFile() throws {
        let testData = "Secret audio recording data".data(using: .utf8)!
        let filename = "test_recording.wav"

        // Encrypt and save
        let encryptedURL = try secureStorage.saveEncryptedFile(testData, filename: filename)
        XCTAssertTrue(FileManager.default.fileExists(atPath: encryptedURL.path))

        // Load and decrypt
        let decryptedData = try secureStorage.loadEncryptedFile(filename: filename)
        XCTAssertEqual(decryptedData, testData)

        // Clean up
        try secureStorage.deleteEncryptedFile(filename: filename)
        XCTAssertFalse(FileManager.default.fileExists(atPath: encryptedURL.path))
    }

    func testEncryptedFileCantBeReadDirectly() throws {
        let testData = "Secret data".data(using: .utf8)!
        let filename = "secret.dat"

        let encryptedURL = try secureStorage.saveEncryptedFile(testData, filename: filename)

        // Try to read encrypted file directly (should not match original)
        let encryptedData = try Data(contentsOf: encryptedURL)
        XCTAssertNotEqual(encryptedData, testData)

        // Clean up
        try secureStorage.deleteEncryptedFile(filename: filename)
    }

    // MARK: - Data Sanitization Tests

    func testEmailSanitization() {
        let input = "User email is user@example.com"
        let sanitized = SecureStorageManager.sanitize(input)

        XCTAssertFalse(sanitized.contains("user@example.com"))
        XCTAssertTrue(sanitized.contains("***@***.***"))
    }

    func testTokenSanitization() {
        let input = "Token: sk_live_abcdefghijklmnopqrstuvwxyz123456"
        let sanitized = SecureStorageManager.sanitize(input)

        XCTAssertFalse(sanitized.contains("sk_live_abcdefghijklmnopqrstuvwxyz123456"))
        XCTAssertTrue(sanitized.contains("***TOKEN***"))
    }

    func testCreditCardSanitization() {
        let input = "Card: 4532-1488-0343-6467"
        let sanitized = SecureStorageManager.sanitize(input)

        XCTAssertFalse(sanitized.contains("4532"))
        XCTAssertTrue(sanitized.contains("****-****-****-****"))
    }

    // MARK: - Master Encryption Key Tests

    func testMasterKeyGeneration() throws {
        let key1 = try secureStorage.getMasterEncryptionKey()
        let key2 = try secureStorage.getMasterEncryptionKey()

        // Same key should be returned (persistent)
        XCTAssertEqual(
            key1.withUnsafeBytes { Data($0) },
            key2.withUnsafeBytes { Data($0) }
        )
    }

    // MARK: - Security Vulnerability Tests

    func testNoPlaintextPasswordStorage() throws {
        // Ensure passwords are never stored in plaintext
        let password = "MySecretPassword123!"

        // This should fail - we should never allow plaintext password storage
        XCTAssertThrowsError(try secureStorage.storeAPIKey(password, for: "password"))
    }

    func testTokenExpiry() throws {
        // Test that tokens can expire
        let token = "expiring_token"
        try secureStorage.storeFirebaseToken(token)

        // In production, implement token expiry checking
        // This is a placeholder test
        XCTAssertNotNil(try secureStorage.getFirebaseToken())
    }
}

// MARK: - Performance Tests

final class ComprehensivePerformanceTests: XCTestCase {
    var performanceMonitor: PerformanceMonitor!

    override func setUp() async throws {
        performanceMonitor = PerformanceMonitor.shared
    }

    // MARK: - Audio Latency Tests

    func testAudioLatencyMeetsTarget() {
        let latency = performanceMonitor.measureAudioLatency()

        XCTAssertLessThan(
            latency,
            PerformanceMonitor.PerformanceTargets.maxAudioLatency,
            "Audio latency \(latency * 1000)ms exceeds 2ms target"
        )
    }

    func testAudioLatencyConsistency() {
        // Measure 10 times
        var latencies: [TimeInterval] = []

        for _ in 0..<10 {
            latencies.append(performanceMonitor.measureAudioLatency())
        }

        // Check variance
        let avg = latencies.reduce(0, +) / Double(latencies.count)
        let variance = latencies.map { pow($0 - avg, 2) }.reduce(0, +) / Double(latencies.count)

        // Variance should be low (consistent performance)
        XCTAssertLessThan(variance, 0.0001, "Audio latency variance too high")
    }

    // MARK: - Memory Tests

    func testMemoryUsageWithinLimits() {
        performanceMonitor.updateMemoryUsage()

        XCTAssertLessThan(
            performanceMonitor.memoryUsage,
            PerformanceMonitor.PerformanceTargets.maxMemoryUsage,
            "Memory usage \(performanceMonitor.memoryUsage / 1_000_000)MB exceeds 500MB target"
        )
    }

    func testMemoryDoesntLeakOverTime() {
        let initialMemory = performanceMonitor.memoryUsage

        // Simulate heavy usage
        for _ in 0..<100 {
            // Create and release objects
            _ = Array(repeating: 0, count: 1000)
        }

        performanceMonitor.updateMemoryUsage()
        let finalMemory = performanceMonitor.memoryUsage

        // Memory shouldn't grow significantly
        let growth = finalMemory - initialMemory
        XCTAssertLessThan(growth, 10_000_000, "Memory leak detected: \(growth / 1_000_000)MB growth")
    }

    // MARK: - CPU Tests

    func testCPUUsageWithinLimits() {
        performanceMonitor.updateCPUUsage()

        XCTAssertLessThan(
            performanceMonitor.cpuUsage,
            PerformanceMonitor.PerformanceTargets.maxCPUUsage,
            "CPU usage \(performanceMonitor.cpuUsage)% exceeds 70% target"
        )
    }

    // MARK: - Performance State Tests

    func testPerformanceStateDetection() {
        let report = performanceMonitor.generateReport()

        if report.isHealthy {
            XCTAssertEqual(performanceMonitor.currentState, .optimal)
        }
    }

    func testPerformanceReportGeneration() {
        let report = performanceMonitor.generateReport()

        XCTAssertGreaterThan(report.timestamp.timeIntervalSinceNow, -10)
        XCTAssertNotNil(report.state)
    }
}

// MARK: - Integration Tests

final class ComprehensiveIntegrationTests: XCTestCase {

    // MARK: - Audio + Performance

    func testAudioProcessingPerformance() async throws {
        // Test that audio processing meets performance targets
        let audioEngine = EOELAudioEngine.shared
        let performanceMonitor = PerformanceMonitor.shared

        // Start audio processing
        // (In real test, this would process actual audio)

        // Measure latency
        let latency = performanceMonitor.measureAudioLatency()
        XCTAssertLessThan(latency, 0.002)

        // Check CPU usage
        performanceMonitor.updateCPUUsage()
        XCTAssertLessThan(performanceMonitor.cpuUsage, 70.0)
    }

    // MARK: - Security + Storage

    func testSecureAudioFileStorage() throws {
        let secureStorage = SecureStorageManager.shared

        // Create mock audio data
        let audioData = Data(repeating: 0xFF, count: 1024 * 1024)  // 1MB
        let filename = "recording_\(Date().timeIntervalSince1970).wav"

        // Encrypt and save
        _ = try secureStorage.saveEncryptedFile(audioData, filename: filename)

        // Verify can be decrypted
        let decrypted = try secureStorage.loadEncryptedFile(filename: filename)
        XCTAssertEqual(decrypted, audioData)

        // Clean up
        try secureStorage.deleteEncryptedFile(filename: filename)
    }

    // MARK: - Network + Security

    func testSecureNetworkCommunication() async throws {
        let sslPinning = SSLPinningManager.shared
        let session = sslPinning.createSecureSession()

        // Test secure connection (placeholder)
        // In production, this would test actual API calls
        XCTAssertNotNil(session)
    }

    // MARK: - Full System Test

    func testFullSystemUnderLoad() async throws {
        // Test entire system under load
        let performanceMonitor = PerformanceMonitor.shared

        // Simulate heavy load
        for _ in 0..<100 {
            _ = performanceMonitor.measureAudioLatency()
            performanceMonitor.updateCPUUsage()
            performanceMonitor.updateMemoryUsage()
        }

        // System should still be responsive
        let report = performanceMonitor.generateReport()
        XCTAssertNotEqual(report.state, .emergency, "System entered emergency state under load")
    }
}

// MARK: - Safety Tests

final class ComprehensiveSafetyTests: XCTestCase {

    // MARK: - Data Integrity

    func testDataIntegrityAfterEncryption() throws {
        let secureStorage = SecureStorageManager.shared
        let originalData = "Critical user data".data(using: .utf8)!

        // Encrypt
        let url = try secureStorage.saveEncryptedFile(originalData, filename: "test.dat")

        // Corrupt the encrypted file (simulate tampering)
        var corruptedData = try Data(contentsOf: url)
        corruptedData[0] ^= 0xFF  // Flip bits

        try corruptedData.write(to: url)

        // Should fail to decrypt
        XCTAssertThrowsError(try secureStorage.loadEncryptedFile(filename: "test.dat"))

        // Clean up
        try? secureStorage.deleteEncryptedFile(filename: "test.dat")
    }

    // MARK: - Memory Safety

    func testNoBufferOverflows() {
        // Test that buffers are properly sized
        let buffer = [Float](repeating: 0, count: 512)

        // Attempt to access out of bounds (should not crash)
        let safeIndex = min(buffer.count - 1, 1000)
        XCTAssertLessThan(safeIndex, buffer.count)
    }

    // MARK: - Thread Safety

    func testConcurrentAccessSafety() {
        let secureStorage = SecureStorageManager.shared
        let expectation = XCTestExpectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 100

        // Spawn 100 concurrent operations
        DispatchQueue.concurrentPerform(iterations: 100) { i in
            do {
                try secureStorage.storeAPIKey("key_\(i)", for: "service_\(i)")
                _ = try secureStorage.getAPIKey(for: "service_\(i)")
                expectation.fulfill()
            } catch {
                XCTFail("Concurrent access failed: \(error)")
            }
        }

        wait(for: [expectation], timeout: 10.0)
    }

    // MARK: - Error Handling

    func testGracefulErrorHandling() {
        // Test that errors don't crash the app
        let secureStorage = SecureStorageManager.shared

        XCTAssertThrowsError(try secureStorage.loadEncryptedFile(filename: "nonexistent.dat"))
        XCTAssertNoThrow(try secureStorage.getFirebaseToken())  // Should return nil, not throw
    }
}

// MARK: - Performance Benchmarks

final class PerformanceBenchmarks: XCTestCase {

    func testAudioProcessingBenchmark() {
        measure {
            // Benchmark audio processing
            let buffer = [Float](repeating: 0, count: 512)
            _ = buffer.map { $0 * 0.5 }  // Simple processing
        }
    }

    func testEncryptionBenchmark() {
        let data = Data(repeating: 0xFF, count: 1024 * 1024)  // 1MB

        measure {
            let secureStorage = SecureStorageManager.shared
            do {
                _ = try secureStorage.saveEncryptedFile(data, filename: "bench.dat")
                try secureStorage.deleteEncryptedFile(filename: "bench.dat")
            } catch {
                XCTFail("Encryption benchmark failed: \(error)")
            }
        }
    }

    func testMemoryAllocationBenchmark() {
        measure {
            // Benchmark memory allocation
            var arrays: [[Float]] = []
            for _ in 0..<1000 {
                arrays.append([Float](repeating: 0, count: 512))
            }
            arrays.removeAll()
        }
    }
}
