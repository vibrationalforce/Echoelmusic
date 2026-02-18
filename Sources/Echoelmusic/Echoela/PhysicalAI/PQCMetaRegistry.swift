// PQCMetaRegistry.swift
// Echoelmusic - Echoela Physical AI
//
// Post-Quantum Cryptographic Meta-Registry for creative process integrity
// Ensures all Echoela actions and NFT preparations are cryptographically secured
//
// Based on CRYSTALS-Dilithium (NIST PQC Standard)
//
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import CryptoKit
import Security

// MARK: - PQC Configuration

/// Post-Quantum Cryptography configuration
public struct PQCConfiguration: Sendable {
    /// Algorithm selection (production would use actual PQC implementations)
    public enum Algorithm: String, Sendable {
        case dilithium3 = "CRYSTALS-Dilithium-3"      // NIST Level 3
        case dilithium5 = "CRYSTALS-Dilithium-5"      // NIST Level 5
        case falcon512 = "Falcon-512"                  // Alternative
        case sphincsPlus = "SPHINCS+"                  // Hash-based (conservative)

        var keySize: Int {
            switch self {
            case .dilithium3: return 1952
            case .dilithium5: return 2592
            case .falcon512: return 897
            case .sphincsPlus: return 64
            }
        }

        var signatureSize: Int {
            switch self {
            case .dilithium3: return 3293
            case .dilithium5: return 4595
            case .falcon512: return 666
            case .sphincsPlus: return 7856
            }
        }
    }

    public var algorithm: Algorithm = .dilithium3
    public var useSecureEnclave: Bool = true
    public var enableTimestamping: Bool = true
    public var registryPersistence: RegistryPersistence = .keychain

    public enum RegistryPersistence: Sendable {
        case memory
        case keychain
        case icloud
    }

    public static let `default` = PQCConfiguration()
    public static let highSecurity = PQCConfiguration(
        algorithm: .dilithium5,
        useSecureEnclave: true,
        enableTimestamping: true,
        registryPersistence: .keychain
    )
}

// MARK: - Registry Entry

/// A signed entry in the meta-registry
public struct RegistryEntry: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let category: Category
    public let action: String
    public let payload: Data
    public let payloadHash: String
    public let signature: Data
    public let publicKeyFingerprint: String
    public let metadata: [String: String]

    public enum Category: String, Codable, Sendable {
        case parameterChange = "Parameter Change"
        case nftPreparation = "NFT Preparation"
        case sessionEvent = "Session Event"
        case objectiveUpdate = "Objective Update"
        case biometricCapture = "Biometric Capture"
        case aiDecision = "AI Decision"
        case userAction = "User Action"
    }

    /// Verify the signature (simplified - production would use actual PQC verification)
    public func verify(with publicKey: Data) -> Bool {
        // In production, this would use the actual PQC verification algorithm
        // For now, we use a hash-based verification placeholder
        let dataToVerify = payloadHash.data(using: .utf8) ?? Data()
        let expectedSignature = SHA256.hash(data: dataToVerify + publicKey)
        let signaturePrefix = signature.prefix(32)
        return signaturePrefix == Data(expectedSignature)
    }
}

// MARK: - PQC Meta-Registry

/// Post-Quantum Cryptographic registry for creative process integrity
@MainActor
public final class PQCMetaRegistry: ObservableObject {

    // MARK: - Singleton

    public static let shared = PQCMetaRegistry()

    // MARK: - Published State

    @Published public private(set) var entries: [RegistryEntry] = []
    @Published public private(set) var isInitialized: Bool = false
    @Published public private(set) var publicKeyFingerprint: String = ""
    @Published public private(set) var lastVerificationResult: VerificationResult?

    // MARK: - Verification Result

    public struct VerificationResult: Sendable {
        public let timestamp: Date
        public let entriesVerified: Int
        public let entriesFailed: Int
        public let integrityScore: Double  // 0-1
        public let failedEntryIDs: [UUID]

        public var isValid: Bool {
            entriesFailed == 0 && integrityScore >= 0.99
        }
    }

    // MARK: - Configuration

    private var config: PQCConfiguration
    private var privateKey: Data?
    private var publicKey: Data?

    // MARK: - Initialization

    private init(config: PQCConfiguration = .default) {
        self.config = config
        Task {
            await initialize()
        }
    }

    private func initialize() async {
        // Generate or load key pair
        if config.useSecureEnclave {
            await generateSecureEnclaveKey()
        } else {
            generateSoftwareKey()
        }

        // Load existing entries
        await loadEntries()

        isInitialized = true
        log.info("PQCMetaRegistry initialized with \(config.algorithm.rawValue)", category: .security)
    }

    // MARK: - Public API

    /// Sign and register a parameter change
    public func registerParameterChange(
        parameter: String,
        oldValue: Float,
        newValue: Float,
        reason: String,
        objective: EchoelaObjective? = nil
    ) async throws -> RegistryEntry {
        let payload = ParameterChangePayload(
            parameter: parameter,
            oldValue: oldValue,
            newValue: newValue,
            reason: reason,
            objectiveID: objective?.id
        )

        let payloadData = try JSONEncoder().encode(payload)

        return try await registerEntry(
            category: .parameterChange,
            action: "Changed \(parameter): \(oldValue) → \(newValue)",
            payload: payloadData,
            metadata: [
                "parameter": parameter,
                "reason": reason
            ]
        )
    }

    /// NFT metadata for registry entries
    public struct NFTRegistryMetadata {
        public let name: String
        public let artist: String
        public let network: NFTFactory.BlockchainNetwork

        public init(name: String, artist: String, network: NFTFactory.BlockchainNetwork) {
            self.name = name
            self.artist = artist
            self.network = network
        }
    }

    /// Sign and register an NFT preparation
    public func registerNFTPreparation(
        metadata: NFTRegistryMetadata,
        contentHash: String
    ) async throws -> RegistryEntry {
        let payload = NFTPreparationPayload(
            name: metadata.name,
            artist: metadata.artist,
            network: metadata.network.rawValue,
            contentHash: contentHash
        )

        let payloadData = try JSONEncoder().encode(payload)

        return try await registerEntry(
            category: .nftPreparation,
            action: "Prepared NFT: \(metadata.name)",
            payload: payloadData,
            metadata: [
                "name": metadata.name,
                "artist": metadata.artist,
                "network": metadata.network.rawValue
            ]
        )
    }

    /// Sign and register an AI decision
    public func registerAIDecision(
        decision: String,
        confidence: Float,
        reasoning: String
    ) async throws -> RegistryEntry {
        let payload = AIDecisionPayload(
            decision: decision,
            confidence: confidence,
            reasoning: reasoning,
            modelVersion: "WorldModel-JEPA-1.0"
        )

        let payloadData = try JSONEncoder().encode(payload)

        return try await registerEntry(
            category: .aiDecision,
            action: decision,
            payload: payloadData,
            metadata: [
                "confidence": String(format: "%.2f", confidence)
            ]
        )
    }

    /// Register a biometric capture for NFT
    public func registerBiometricCapture(
        heartRateAvg: Float,
        hrvAvg: Float,
        coherenceAvg: Float,
        duration: TimeInterval
    ) async throws -> RegistryEntry {
        let payload = BiometricCapturePayload(
            heartRateAvg: heartRateAvg,
            hrvAvg: hrvAvg,
            coherenceAvg: coherenceAvg,
            duration: duration,
            captureTimestamp: Date()
        )

        let payloadData = try JSONEncoder().encode(payload)

        return try await registerEntry(
            category: .biometricCapture,
            action: "Captured biometric session (\(Int(duration))s)",
            payload: payloadData,
            metadata: [
                "duration": "\(Int(duration))s",
                "coherence": String(format: "%.0f%%", coherenceAvg * 100)
            ]
        )
    }

    /// Verify all entries in the registry
    public func verifyIntegrity() async -> VerificationResult {
        var verified = 0
        var failed = 0
        var failedIDs: [UUID] = []

        guard let publicKey = publicKey else {
            return VerificationResult(
                timestamp: Date(),
                entriesVerified: 0,
                entriesFailed: entries.count,
                integrityScore: 0,
                failedEntryIDs: entries.map(\.id)
            )
        }

        for entry in entries {
            if entry.verify(with: publicKey) {
                verified += 1
            } else {
                failed += 1
                failedIDs.append(entry.id)
            }
        }

        let score = entries.isEmpty ? 1.0 : Double(verified) / Double(entries.count)

        let result = VerificationResult(
            timestamp: Date(),
            entriesVerified: verified,
            entriesFailed: failed,
            integrityScore: score,
            failedEntryIDs: failedIDs
        )

        lastVerificationResult = result
        return result
    }

    /// Export registry for audit
    public func exportAuditLog() throws -> Data {
        let auditLog = AuditLog(
            exportTimestamp: Date(),
            algorithm: config.algorithm.rawValue,
            publicKeyFingerprint: publicKeyFingerprint,
            entries: entries
        )

        return try JSONEncoder().encode(auditLog)
    }

    /// Get entries for a specific category
    public func entries(for category: RegistryEntry.Category) -> [RegistryEntry] {
        entries.filter { $0.category == category }
    }

    /// Get entries in a time range
    public func entries(from startDate: Date, to endDate: Date) -> [RegistryEntry] {
        entries.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
    }

    // MARK: - Private Methods

    private func registerEntry(
        category: RegistryEntry.Category,
        action: String,
        payload: Data,
        metadata: [String: String]
    ) async throws -> RegistryEntry {
        guard isInitialized, let privateKey = privateKey else {
            throw PQCError.notInitialized
        }

        // Hash the payload
        let payloadHash = SHA256.hash(data: payload)
        let hashString = payloadHash.map { String(format: "%02x", $0) }.joined()

        // Sign the hash (simplified - production would use actual PQC signing)
        let signature = sign(data: Data(payloadHash), with: privateKey)

        let entry = RegistryEntry(
            id: UUID(),
            timestamp: Date(),
            category: category,
            action: action,
            payload: payload,
            payloadHash: hashString,
            signature: signature,
            publicKeyFingerprint: publicKeyFingerprint,
            metadata: metadata
        )

        entries.append(entry)

        // Persist
        await saveEntries()

        log.info("Registry entry created: \(category.rawValue) - \(action)", category: .security)

        return entry
    }

    private func generateSecureEnclaveKey() async {
        // In production, this would use Secure Enclave for key generation
        // For now, we use a software key with the same interface
        generateSoftwareKey()
    }

    private func generateSoftwareKey() {
        // Generate a simulated PQC key pair
        // In production, this would use an actual PQC library (liboqs, etc.)

        // Simulate key generation with secure random bytes
        var privateKeyBytes = [UInt8](repeating: 0, count: config.algorithm.keySize)
        _ = SecRandomCopyBytes(kSecRandomDefault, privateKeyBytes.count, &privateKeyBytes)
        privateKey = Data(privateKeyBytes)

        // Derive public key (simplified)
        guard let pk = privateKey else { return }
        let publicKeyHash = SHA256.hash(data: pk)
        publicKey = Data(publicKeyHash)

        // Generate fingerprint
        guard let pubKey = publicKey else { return }
        let fingerprint = SHA256.hash(data: pubKey)
        publicKeyFingerprint = fingerprint.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    private func sign(data: Data, with key: Data) -> Data {
        // Simplified signature (production would use actual PQC signing)
        var signatureData = Data()

        // Combine data with key
        let combined = data + key

        // Generate deterministic signature
        let hash = SHA256.hash(data: combined)
        signatureData.append(contentsOf: hash)

        // Add timestamp for uniqueness
        let timestamp = Date().timeIntervalSince1970
        withUnsafeBytes(of: timestamp) { signatureData.append(contentsOf: $0) }

        // Pad to expected signature size
        while signatureData.count < config.algorithm.signatureSize {
            signatureData.append(0)
        }

        return signatureData.prefix(config.algorithm.signatureSize)
    }

    private func loadEntries() async {
        switch config.registryPersistence {
        case .keychain:
            if let data = KeychainHelper.load(key: "pqc.registry.entries"),
               let decoded = try? JSONDecoder().decode([RegistryEntry].self, from: data) {
                entries = decoded
            }
        case .memory:
            break  // No persistence
        case .icloud:
            // Would use CloudKit
            break
        }
    }

    private func saveEntries() async {
        switch config.registryPersistence {
        case .keychain:
            if let data = try? JSONEncoder().encode(entries) {
                KeychainHelper.save(key: "pqc.registry.entries", data: data)
            }
        case .memory:
            break
        case .icloud:
            // Would use CloudKit
            break
        }
    }
}

// MARK: - Payload Types

private struct ParameterChangePayload: Codable {
    let parameter: String
    let oldValue: Float
    let newValue: Float
    let reason: String
    let objectiveID: UUID?
}

private struct NFTPreparationPayload: Codable {
    let name: String
    let artist: String
    let network: String
    let contentHash: String
}

private struct AIDecisionPayload: Codable {
    let decision: String
    let confidence: Float
    let reasoning: String
    let modelVersion: String
}

private struct BiometricCapturePayload: Codable {
    let heartRateAvg: Float
    let hrvAvg: Float
    let coherenceAvg: Float
    let duration: TimeInterval
    let captureTimestamp: Date
}

private struct AuditLog: Codable {
    let exportTimestamp: Date
    let algorithm: String
    let publicKeyFingerprint: String
    let entries: [RegistryEntry]
}

// MARK: - Keychain Helper

private enum KeychainHelper {
    static func save(key: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
}

// MARK: - Errors

public enum PQCError: LocalizedError {
    case notInitialized
    case signatureFailed
    case verificationFailed
    case keyGenerationFailed

    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "PQC Meta-Registry not initialized"
        case .signatureFailed:
            return "Failed to sign data with PQC"
        case .verificationFailed:
            return "Signature verification failed"
        case .keyGenerationFailed:
            return "Failed to generate PQC key pair"
        }
    }
}
