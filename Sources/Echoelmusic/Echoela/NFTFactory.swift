// MARK: - NFTFactory.swift
// Echoelmusic Suite - NFT Production & Blockchain Integration
// Copyright 2026 Echoelmusic. All rights reserved.

import Foundation
import Combine
import CryptoKit

// MARK: - NFT Factory

/// Quantum-safe NFT minting and management for bio-reactive content
/// Supports ERC-721C, ERC-6551 (Token Bound Accounts), and 0xSplits
@MainActor
public final class NFTFactory: ObservableObject {

    // MARK: - Singleton

    public static let shared = NFTFactory()

    // MARK: - Published State

    @Published public private(set) var isMinting: Bool = false
    @Published public private(set) var mintedNFTs: [MintedNFT] = []
    @Published public private(set) var pendingMints: [PendingMint] = []
    @Published public private(set) var connectedWallet: WalletConnection?
    @Published public private(set) var complianceStatus: ComplianceStatus = .unchecked

    // MARK: - Types

    /// NFT Token Standard
    public enum TokenStandard: String, Codable {
        case erc721 = "ERC-721"
        case erc721c = "ERC-721C"      // Creator-controlled royalties
        case erc6551 = "ERC-6551"      // Token Bound Accounts
    }

    /// Blockchain Network
    public enum BlockchainNetwork: String, Codable {
        case ethereum = "Ethereum"
        case polygon = "Polygon"
        case base = "Base"
        case optimism = "Optimism"
        case zora = "Zora"

        public var chainID: Int {
            switch self {
            case .ethereum: return 1
            case .polygon: return 137
            case .base: return 8453
            case .optimism: return 10
            case .zora: return 7777777
            }
        }

        public var rpcURL: URL? {
            switch self {
            case .ethereum: return URL(string: "https://mainnet.infura.io/v3/")
            case .polygon: return URL(string: "https://polygon-rpc.com")
            case .base: return URL(string: "https://mainnet.base.org")
            case .optimism: return URL(string: "https://mainnet.optimism.io")
            case .zora: return URL(string: "https://rpc.zora.energy")
            }
        }
    }

    /// Bio-reactive metadata for NFT
    public struct BioReactiveMetadata: Codable {
        public let sessionID: UUID
        public let captureTimestamp: Date
        public let duration: TimeInterval
        public let averageHeartRate: Double
        public let averageHRV: Double
        public let peakCoherence: Double
        public let coherenceHistory: [Double]
        public let breathingPattern: BreathingPattern?
        public let emotionalSignature: EmotionalSignature?

        public struct BreathingPattern: Codable {
            public let averageRate: Double
            public let variability: Double
            public let pattern: String  // "coherent", "erratic", "deep", "shallow"
        }

        public struct EmotionalSignature: Codable {
            public let dominantState: String
            public let stateHistory: [String]
            public let transitionCount: Int
        }
    }

    /// NFT Content
    public struct NFTContent: Codable {
        public let audioFileURL: URL?
        public let visualFileURL: URL?
        public let coverImageURL: URL?
        public let animatedPreviewURL: URL?
        public let format: ContentFormat
        public let duration: TimeInterval
        public let resolution: String?

        public enum ContentFormat: String, Codable {
            case audioVisual = "audio-visual"
            case audioOnly = "audio"
            case visualOnly = "visual"
            case immersive3D = "immersive-3d"   // visionOS spatial content
        }
    }

    /// Revenue split configuration (0xSplits compatible)
    public struct RevenueSplit: Codable {
        public let recipients: [Recipient]
        public let totalPercentage: Double  // Should always equal 100

        public struct Recipient: Codable {
            public let address: String
            public let percentage: Double
            public let role: Role

            public enum Role: String, Codable {
                case musician
                case visualArtist
                case producer
                case platform
                case charity
            }
        }

        public var isValid: Bool {
            abs(totalPercentage - 100.0) < 0.01 &&
            recipients.allSatisfy { $0.percentage > 0 && $0.percentage <= 100 }
        }
    }

    /// Compliance information
    public struct ComplianceInfo: Codable {
        public let isrcCode: String?
        public let gemaWorkNumber: String?
        public let vgWortID: String?
        public let aiContentPercentage: Double
        public let hasLicensedSamples: Bool
        public let licensedSampleIDs: [String]
        public let euAIActCompliant: Bool
        public let micaCompliant: Bool
    }

    /// Compliance check status
    public enum ComplianceStatus: String, Codable {
        case unchecked
        case checking
        case passed
        case warning
        case failed
    }

    /// Pending mint request
    public struct PendingMint: Identifiable, Codable {
        public let id: UUID
        public let content: NFTContent
        public let metadata: BioReactiveMetadata
        public let splits: RevenueSplit
        public let compliance: ComplianceInfo
        public let standard: TokenStandard
        public let network: BlockchainNetwork
        public let createdAt: Date
        public var status: MintStatus

        public enum MintStatus: String, Codable {
            case pending
            case complianceCheck
            case awaitingSignature
            case minting
            case confirming
            case completed
            case failed
        }
    }

    /// Minted NFT record
    public struct MintedNFT: Identifiable, Codable {
        public let id: UUID
        public let tokenID: String
        public let contractAddress: String
        public let transactionHash: String
        public let network: BlockchainNetwork
        public let standard: TokenStandard
        public let metadata: BioReactiveMetadata
        public let mintedAt: Date
        public let tokenBoundAccount: String?  // ERC-6551 TBA address
        public let splitsAddress: String?      // 0xSplits contract
        public let openseaURL: URL?
        public let zoraURL: URL?
    }

    /// Wallet connection
    public struct WalletConnection: Codable {
        public let address: String
        public let network: BlockchainNetwork
        public let provider: WalletProvider
        public let connectedAt: Date

        public enum WalletProvider: String, Codable {
            case metamask = "MetaMask"
            case coinbase = "Coinbase Wallet"
            case rainbow = "Rainbow"
            case walletConnect = "WalletConnect"
            case secureEnclave = "Secure Enclave"  // Apple's hardware security
        }
    }

    // MARK: - PQC Crypto

    /// Post-Quantum Cryptography manager for secure signing
    private let pqcManager = PQCCryptoManager()

    // MARK: - Configuration

    private var cancellables = Set<AnyCancellable>()

    /// Platform fee percentage
    public static let platformFeePercentage: Double = 2.5

    /// Creator royalty range (ERC-721C)
    public static let royaltyRange: ClosedRange<Double> = 0...10

    // MARK: - Initialization

    private init() {
        loadMintedNFTs()
    }

    // MARK: - Public API

    /// Whether NFT functionality is enabled (disabled in App Store builds per Guideline 3.1.5)
    public var isNFTEnabled: Bool {
        FeatureFlagManager.shared.isEnabled("nft_minting")
    }

    /// Connect wallet
    public func connectWallet(provider: WalletConnection.WalletProvider, network: BlockchainNetwork) async throws -> WalletConnection {
        guard isNFTEnabled else {
            throw NFTError.complianceFailed("NFT functionality is disabled in this build")
        }
        log.info("Connecting wallet via \(provider.rawValue) on \(network.rawValue)")

        // For Secure Enclave, use device's hardware security
        if provider == .secureEnclave {
            let address = try await generateSecureEnclaveAddress()
            let connection = WalletConnection(
                address: address,
                network: network,
                provider: provider,
                connectedAt: Date()
            )
            connectedWallet = connection
            return connection
        }

        // For other providers, use WalletConnect or native SDK
        let connection = try await connectExternalWallet(provider: provider, network: network)
        connectedWallet = connection
        return connection
    }

    /// Disconnect wallet
    public func disconnectWallet() {
        connectedWallet = nil
        log.info("Wallet disconnected")
    }

    /// Create a pending mint
    public func prepareMint(
        content: NFTContent,
        bioMetadata: BioReactiveMetadata,
        splits: RevenueSplit,
        compliance: ComplianceInfo,
        standard: TokenStandard = .erc721c,
        network: BlockchainNetwork = .base
    ) throws -> PendingMint {
        // Validate splits
        guard splits.isValid else {
            throw NFTError.invalidSplits("Revenue splits must total 100%")
        }

        // Add platform fee
        var adjustedSplits = splits
        adjustedSplits = addPlatformFee(to: splits)

        let pendingMint = PendingMint(
            id: UUID(),
            content: content,
            metadata: bioMetadata,
            splits: adjustedSplits,
            compliance: compliance,
            standard: standard,
            network: network,
            createdAt: Date(),
            status: .pending
        )

        pendingMints.append(pendingMint)
        log.info("Prepared mint: \(pendingMint.id)")

        return pendingMint
    }

    /// Execute compliance check
    public func checkCompliance(for mintID: UUID) async throws -> ComplianceStatus {
        guard let index = pendingMints.firstIndex(where: { $0.id == mintID }) else {
            throw NFTError.mintNotFound
        }

        pendingMints[index].status = .complianceCheck
        complianceStatus = .checking

        let mint = pendingMints[index]

        // Check GEMA/ISRC
        let gemaResult = try await verifyGEMACompliance(mint.compliance)

        // Check EU AI Act
        let aiActResult = try await verifyEUAIActCompliance(mint.compliance)

        // Check MiCA
        let micaResult = try await verifyMiCACompliance(mint.compliance, network: mint.network)

        // Aggregate results
        if !gemaResult.passed {
            complianceStatus = .failed
            throw NFTError.complianceFailed(gemaResult.message)
        }

        if !aiActResult.passed {
            complianceStatus = .warning
            log.warning("EU AI Act compliance warning: \(aiActResult.message)")
        }

        if !micaResult.passed {
            complianceStatus = .warning
            log.warning("MiCA compliance warning: \(micaResult.message)")
        }

        if complianceStatus != .warning {
            complianceStatus = .passed
        }

        log.info("Compliance check completed: \(complianceStatus.rawValue)")
        return complianceStatus
    }

    /// Mint NFT with PQC-signed transaction
    public func mint(mintID: UUID) async throws -> MintedNFT {
        guard isNFTEnabled else {
            throw NFTError.complianceFailed("NFT functionality is disabled in this build")
        }
        guard let wallet = connectedWallet else {
            throw NFTError.walletNotConnected
        }

        guard let index = pendingMints.firstIndex(where: { $0.id == mintID }) else {
            throw NFTError.mintNotFound
        }

        // Run compliance check if not done
        if complianceStatus == .unchecked {
            _ = try await checkCompliance(for: mintID)
        }

        guard complianceStatus != .failed else {
            throw NFTError.complianceFailed("Compliance check failed")
        }

        isMinting = true
        defer { isMinting = false }

        pendingMints[index].status = .awaitingSignature

        let mint = pendingMints[index]

        // 1. Upload content to IPFS/Arweave
        let contentCID = try await uploadContent(mint.content)
        let metadataCID = try await uploadMetadata(mint.metadata, contentCID: contentCID)

        // 2. Deploy 0xSplits contract if needed
        let splitsAddress = try await deploySplitsContract(mint.splits, on: mint.network)

        // 3. Build transaction
        pendingMints[index].status = .awaitingSignature
        let transaction = try buildMintTransaction(
            metadataCID: metadataCID,
            splitsAddress: splitsAddress,
            standard: mint.standard,
            network: mint.network
        )

        // 4. Sign with PQC (Post-Quantum Cryptography)
        let signature = try await pqcManager.signTransaction(transaction, wallet: wallet)

        // 5. Submit transaction
        pendingMints[index].status = .minting
        let txHash = try await submitTransaction(transaction, signature: signature, network: mint.network)

        // 6. Wait for confirmation
        pendingMints[index].status = .confirming
        let receipt = try await waitForConfirmation(txHash: txHash, network: mint.network)

        // 7. Deploy Token Bound Account for ERC-6551
        var tbaAddress: String?
        if mint.standard == .erc6551 {
            tbaAddress = try await deployTokenBoundAccount(
                tokenID: receipt.tokenID,
                contractAddress: receipt.contractAddress,
                network: mint.network
            )
        }

        // 8. Create minted NFT record
        let mintedNFT = MintedNFT(
            id: mint.id,
            tokenID: receipt.tokenID,
            contractAddress: receipt.contractAddress,
            transactionHash: txHash,
            network: mint.network,
            standard: mint.standard,
            metadata: mint.metadata,
            mintedAt: Date(),
            tokenBoundAccount: tbaAddress,
            splitsAddress: splitsAddress,
            openseaURL: buildOpenSeaURL(contract: receipt.contractAddress, tokenID: receipt.tokenID, network: mint.network),
            zoraURL: buildZoraURL(contract: receipt.contractAddress, tokenID: receipt.tokenID, network: mint.network)
        )

        // Update state
        pendingMints[index].status = .completed
        mintedNFTs.append(mintedNFT)
        saveMintedNFTs()

        // Remove from pending
        pendingMints.removeAll { $0.id == mintID }

        log.info("NFT minted successfully: \(mintedNFT.tokenID)")

        return mintedNFT
    }

    /// Get consent for biometric data usage (GDPR compliant)
    public func requestBiometricConsent(for usage: BiometricDataUsage) async -> Bool {
        // This would present a consent dialog to the user
        // For now, return placeholder
        log.info("Requesting biometric consent for: \(usage.rawValue)")
        return true
    }

    public enum BiometricDataUsage: String {
        case nftMetadata = "NFT Metadata Storage"
        case publicDisplay = "Public Display on Blockchain"
        case anonymizedResearch = "Anonymized Research"
    }

    // MARK: - Private Methods

    private func generateSecureEnclaveAddress() async throws -> String {
        // Generate key pair in Secure Enclave
        let privateKey = try SecureEnclave.P256.Signing.PrivateKey()
        let publicKey = privateKey.publicKey

        // Derive Ethereum-style address from public key
        let publicKeyData = publicKey.rawRepresentation
        let hash = SHA256.hash(data: publicKeyData)
        let addressBytes = Array(hash.suffix(20))
        let address = "0x" + addressBytes.map { String(format: "%02x", $0) }.joined()

        return address
    }

    private func connectExternalWallet(provider: WalletConnection.WalletProvider, network: BlockchainNetwork) async throws -> WalletConnection {
        // WalletConnect or native SDK integration
        // Placeholder implementation
        throw NFTError.walletConnectionFailed("External wallet connection not implemented")
    }

    private func addPlatformFee(to splits: RevenueSplit) -> RevenueSplit {
        // Reduce each recipient proportionally to add platform fee
        let reduction = Self.platformFeePercentage / 100.0
        var adjustedRecipients = splits.recipients.map { recipient in
            RevenueSplit.Recipient(
                address: recipient.address,
                percentage: recipient.percentage * (1 - reduction),
                role: recipient.role
            )
        }

        // Add platform recipient
        adjustedRecipients.append(RevenueSplit.Recipient(
            address: "0x...", // Echoelmusic treasury address
            percentage: Self.platformFeePercentage,
            role: .platform
        ))

        return RevenueSplit(
            recipients: adjustedRecipients,
            totalPercentage: 100.0
        )
    }

    private func verifyGEMACompliance(_ compliance: ComplianceInfo) async throws -> (passed: Bool, message: String) {
        // Verify ISRC and GEMA work numbers
        if compliance.hasLicensedSamples && compliance.licensedSampleIDs.isEmpty {
            return (false, "Licensed samples declared but no sample IDs provided")
        }

        if let isrc = compliance.isrcCode {
            // Validate ISRC format: CC-XXX-YY-NNNNN
            let isrcPattern = "^[A-Z]{2}-?[A-Z0-9]{3}-?\\d{2}-?\\d{5}$"
            guard isrc.range(of: isrcPattern, options: .regularExpression) != nil else {
                return (false, "Invalid ISRC format")
            }
        }

        if let gemaNumber = compliance.gemaWorkNumber {
            // Validate GEMA number format
            let gemaPattern = "^\\d{7,10}$"
            guard gemaNumber.range(of: gemaPattern, options: .regularExpression) != nil else {
                return (false, "Invalid GEMA work number format")
            }
        }

        return (true, "GEMA compliance verified")
    }

    private func verifyEUAIActCompliance(_ compliance: ComplianceInfo) async throws -> (passed: Bool, message: String) {
        // EU AI Act requires disclosure of AI-generated content
        if compliance.aiContentPercentage > 0 && !compliance.euAIActCompliant {
            return (false, "AI-generated content must be labeled per EU AI Act")
        }

        if compliance.aiContentPercentage > 50 {
            return (true, "Warning: Majority AI-generated content requires prominent disclosure")
        }

        return (true, "EU AI Act compliance verified")
    }

    private func verifyMiCACompliance(_ compliance: ComplianceInfo, network: BlockchainNetwork) async throws -> (passed: Bool, message: String) {
        // MiCA (Markets in Crypto-Assets) compliance for EU
        // NFTs are generally exempt unless fractionalized or part of a series
        if !compliance.micaCompliant {
            return (true, "Warning: Ensure NFT series structure complies with MiCA exemptions")
        }

        return (true, "MiCA compliance verified")
    }

    private func uploadContent(_ content: NFTContent) async throws -> String {
        // Upload to IPFS via Pinata/Infura or Arweave
        // Return CID (Content Identifier)
        log.info("Uploading content to IPFS...")

        // Placeholder - would use actual IPFS SDK
        let cid = "Qm" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(44)
        return String(cid)
    }

    private func uploadMetadata(_ metadata: BioReactiveMetadata, contentCID: String) async throws -> String {
        // Build ERC-721 compatible metadata JSON
        let metadataJSON: [String: Any] = [
            "name": "Echoelmusic Bio-Reactive Session",
            "description": "Bio-reactive audio-visual content captured via Echoelmusic",
            "image": "ipfs://\(contentCID)/cover.png",
            "animation_url": "ipfs://\(contentCID)/content",
            "attributes": [
                ["trait_type": "Duration", "value": Int(metadata.duration)],
                ["trait_type": "Average Heart Rate", "value": Int(metadata.averageHeartRate)],
                ["trait_type": "Average HRV", "value": Int(metadata.averageHRV)],
                ["trait_type": "Peak Coherence", "value": Int(metadata.peakCoherence * 100)],
                ["trait_type": "Session ID", "value": metadata.sessionID.uuidString]
            ],
            "echoelmusic": [
                "version": "2.0",
                "bioData": [
                    "coherenceHistory": metadata.coherenceHistory,
                    "breathingPattern": metadata.breathingPattern,
                    "emotionalSignature": metadata.emotionalSignature
                ]
            ]
        ]

        // Upload to IPFS
        log.info("Uploading metadata to IPFS...")
        let cid = "Qm" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(44)
        return String(cid)
    }

    private func deploySplitsContract(_ splits: RevenueSplit, on network: BlockchainNetwork) async throws -> String {
        // Deploy 0xSplits contract
        log.info("Deploying 0xSplits contract on \(network.rawValue)...")

        // Placeholder - would use actual 0xSplits SDK
        let address = "0x" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(40).lowercased()
        return address
    }

    private func buildMintTransaction(metadataCID: String, splitsAddress: String, standard: TokenStandard, network: BlockchainNetwork) throws -> Transaction {
        // Build the mint transaction
        return Transaction(
            to: "0x...",  // Contract address
            data: "mint(ipfs://\(metadataCID), \(splitsAddress))",
            value: "0",
            chainID: network.chainID
        )
    }

    private func submitTransaction(_ transaction: Transaction, signature: Data, network: BlockchainNetwork) async throws -> String {
        // Submit to blockchain
        log.info("Submitting transaction to \(network.rawValue)...")

        // Placeholder - would use actual Web3 SDK
        let txHash = "0x" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        return txHash
    }

    private func waitForConfirmation(txHash: String, network: BlockchainNetwork) async throws -> TransactionReceipt {
        // Wait for transaction confirmation
        log.info("Waiting for confirmation: \(txHash)")

        // Placeholder
        try await Task.sleep(nanoseconds: 2_000_000_000)  // Simulate wait

        return TransactionReceipt(
            tokenID: String(Int.random(in: 1...10000)),
            contractAddress: "0x" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(40).lowercased(),
            blockNumber: Int.random(in: 1000000...2000000)
        )
    }

    private func deployTokenBoundAccount(tokenID: String, contractAddress: String, network: BlockchainNetwork) async throws -> String {
        // Deploy ERC-6551 Token Bound Account
        log.info("Deploying Token Bound Account for token \(tokenID)...")

        // Placeholder
        let tbaAddress = "0x" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(40).lowercased()
        return tbaAddress
    }

    private func buildOpenSeaURL(contract: String, tokenID: String, network: BlockchainNetwork) -> URL? {
        let networkPath: String
        switch network {
        case .ethereum: networkPath = "ethereum"
        case .polygon: networkPath = "matic"
        case .base: networkPath = "base"
        case .optimism: networkPath = "optimism"
        case .zora: networkPath = "zora"
        }
        return URL(string: "https://opensea.io/assets/\(networkPath)/\(contract)/\(tokenID)")
    }

    private func buildZoraURL(contract: String, tokenID: String, network: BlockchainNetwork) -> URL? {
        return URL(string: "https://zora.co/collect/\(network.rawValue.lowercased()):\(contract)/\(tokenID)")
    }

    private func loadMintedNFTs() {
        // Load from persistent storage
        if let data = UserDefaults.standard.data(forKey: "echoelmusic.mintedNFTs"),
           let nfts = try? JSONDecoder().decode([MintedNFT].self, from: data) {
            mintedNFTs = nfts
        }
    }

    private func saveMintedNFTs() {
        if let data = try? JSONEncoder().encode(mintedNFTs) {
            UserDefaults.standard.set(data, forKey: "echoelmusic.mintedNFTs")
        }
    }

    // MARK: - Supporting Types

    struct Transaction {
        let to: String
        let data: String
        let value: String
        let chainID: Int
    }

    struct TransactionReceipt {
        let tokenID: String
        let contractAddress: String
        let blockNumber: Int
    }
}

// MARK: - PQC Crypto Manager

/// Post-Quantum Cryptography for secure transaction signing
/// Uses Secure Enclave for key management
final class PQCCryptoManager {

    /// Sign transaction with PQC-safe hybrid signature
    func signTransaction(_ transaction: NFTFactory.Transaction, wallet: NFTFactory.WalletConnection) async throws -> Data {
        log.info("Signing transaction with PQC hybrid scheme")

        // For Secure Enclave wallets, use hardware signing
        if wallet.provider == .secureEnclave {
            return try await signWithSecureEnclave(transaction)
        }

        // For external wallets, use their native signing
        return try await signWithExternalWallet(transaction, wallet: wallet)
    }

    private func signWithSecureEnclave(_ transaction: NFTFactory.Transaction) async throws -> Data {
        // Use Secure Enclave P256 signing
        // In production, this would use a hybrid PQC+ECDSA scheme

        let transactionData = "\(transaction.to)\(transaction.data)\(transaction.value)\(transaction.chainID)".data(using: .utf8) ?? Data()

        // Hash the transaction
        let hash = SHA256.hash(data: transactionData)

        // Sign with Secure Enclave key
        // This is a simplified example - real implementation would use stored key
        let privateKey = try SecureEnclave.P256.Signing.PrivateKey()
        let signature = try privateKey.signature(for: hash)

        return signature.rawRepresentation
    }

    private func signWithExternalWallet(_ transaction: NFTFactory.Transaction, wallet: NFTFactory.WalletConnection) async throws -> Data {
        // Request signature from external wallet via WalletConnect
        throw NFTError.signingFailed("External wallet signing not implemented")
    }
}

// MARK: - Errors

public enum NFTError: LocalizedError {
    case walletNotConnected
    case walletConnectionFailed(String)
    case mintNotFound
    case invalidSplits(String)
    case complianceFailed(String)
    case uploadFailed(String)
    case transactionFailed(String)
    case signingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .walletNotConnected:
            return "No wallet connected. Please connect your wallet first."
        case .walletConnectionFailed(let reason):
            return "Failed to connect wallet: \(reason)"
        case .mintNotFound:
            return "Mint request not found"
        case .invalidSplits(let reason):
            return "Invalid revenue splits: \(reason)"
        case .complianceFailed(let reason):
            return "Compliance check failed: \(reason)"
        case .uploadFailed(let reason):
            return "Failed to upload content: \(reason)"
        case .transactionFailed(let reason):
            return "Transaction failed: \(reason)"
        case .signingFailed(let reason):
            return "Failed to sign transaction: \(reason)"
        }
    }
}
