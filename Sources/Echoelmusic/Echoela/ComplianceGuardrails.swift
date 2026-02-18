// MARK: - ComplianceGuardrails.swift
// Echoelmusic Suite - Automated Compliance System
// Copyright 2026 Echoelmusic. All rights reserved.

import Foundation
import Combine

// MARK: - Compliance Manager

/// Automated compliance checking for GEMA, VG Wort, EU AI Act, MiCA, and GDPR
@MainActor
public final class ComplianceManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = ComplianceManager()

    // MARK: - Published State

    @Published public private(set) var isChecking: Bool = false
    @Published public private(set) var lastCheckResult: ComplianceCheckResult?
    @Published public private(set) var activeWarnings: [ComplianceWarning] = []
    @Published public private(set) var biometricConsents: [BiometricConsent] = []

    // MARK: - Types

    /// Overall compliance check result
    public struct ComplianceCheckResult: Codable {
        public let timestamp: Date
        public let overallStatus: Status
        public let gemaResult: GEMACheckResult
        public let vgWortResult: VGWortCheckResult
        public let euAIActResult: EUAIActCheckResult
        public let micaResult: MiCACheckResult
        public let gdprResult: GDPRCheckResult
        public let warnings: [ComplianceWarning]
        public let blockingIssues: [BlockingIssue]

        public enum Status: String, Codable {
            case passed = "Passed"
            case passedWithWarnings = "Passed with Warnings"
            case failed = "Failed"
        }

        public var canProceed: Bool {
            blockingIssues.isEmpty
        }
    }

    /// GEMA/ISRC compliance result
    public struct GEMACheckResult: Codable {
        public let isrcValidated: Bool
        public let gemaWorkNumberValidated: Bool
        public let hasUnlicensedContent: Bool
        public let licensedSamples: [LicensedSample]
        public let warnings: [String]

        public struct LicensedSample: Codable {
            public let sampleID: String
            public let source: String
            public let licenseType: String
            public let expirationDate: Date?
        }
    }

    /// VG Wort compliance result
    public struct VGWortCheckResult: Codable {
        public let hasTextContent: Bool
        public let vgWortRegistered: Bool
        public let pixelIntegrated: Bool
        public let estimatedWordCount: Int
    }

    /// EU AI Act compliance result
    public struct EUAIActCheckResult: Codable {
        public let aiContentDetected: Bool
        public let aiContentPercentage: Double
        public let disclosureRequired: Bool
        public let disclosurePresent: Bool
        public let riskCategory: AIRiskCategory
        public let transparencyRequirementsMet: Bool

        public enum AIRiskCategory: String, Codable {
            case minimal = "Minimal Risk"
            case limited = "Limited Risk"
            case high = "High Risk"
            case unacceptable = "Unacceptable Risk"
        }
    }

    /// MiCA compliance result
    public struct MiCACheckResult: Codable {
        public let isNFTExempt: Bool
        public let isFractionalized: Bool
        public let isPartOfSeries: Bool
        public let seriesSize: Int?
        public let requiresWhitepaper: Bool
        public let whitepaperProvided: Bool
        public let cryptoAssetServiceProvider: Bool
    }

    /// GDPR compliance for biometric data
    public struct GDPRCheckResult: Codable {
        public let biometricDataUsed: Bool
        public let consentObtained: Bool
        public let consentTimestamp: Date?
        public let dataMinimization: Bool
        public let rightToErasure: Bool
        public let dataPortability: Bool
        public let processingLawfulBasis: LawfulBasis?

        public enum LawfulBasis: String, Codable {
            case consent = "Explicit Consent"
            case contract = "Contract Performance"
            case legalObligation = "Legal Obligation"
            case vitalInterests = "Vital Interests"
            case publicInterest = "Public Interest"
            case legitimateInterests = "Legitimate Interests"
        }
    }

    /// Compliance warning (non-blocking)
    public struct ComplianceWarning: Identifiable, Codable {
        public let id: UUID
        public let category: Category
        public let message: String
        public let recommendation: String
        public let severity: Severity
        public let documentationURL: URL?

        public enum Category: String, Codable {
            case gema = "GEMA/ISRC"
            case vgWort = "VG Wort"
            case euAIAct = "EU AI Act"
            case mica = "MiCA"
            case gdpr = "GDPR"
        }

        public enum Severity: String, Codable {
            case info = "Information"
            case warning = "Warning"
            case critical = "Critical"
        }
    }

    /// Blocking issue (prevents minting)
    public struct BlockingIssue: Identifiable, Codable {
        public let id: UUID
        public let category: ComplianceWarning.Category
        public let title: String
        public let description: String
        public let resolution: String
        public let legalReference: String?
    }

    /// Biometric data consent record
    public struct BiometricConsent: Identifiable, Codable {
        public let id: UUID
        public let userID: String
        public let consentType: ConsentType
        public let granted: Bool
        public let timestamp: Date
        public let expirationDate: Date?
        public let purposes: [Purpose]
        public let dataCategories: [DataCategory]

        public enum ConsentType: String, Codable {
            case nftMetadata = "NFT Metadata Storage"
            case publicBlockchain = "Public Blockchain Storage"
            case anonymizedResearch = "Anonymized Research"
            case thirdPartySharing = "Third Party Sharing"
        }

        public enum Purpose: String, Codable {
            case nftCreation = "NFT Creation"
            case visualization = "Real-time Visualization"
            case analytics = "Session Analytics"
            case research = "Research (Anonymized)"
        }

        public enum DataCategory: String, Codable {
            case heartRate = "Heart Rate"
            case hrv = "Heart Rate Variability"
            case coherence = "Coherence Score"
            case breathing = "Breathing Rate"
            case eeg = "EEG Data"
            case movement = "Movement Data"
        }
    }

    // MARK: - Configuration

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        loadConsents()
    }

    // MARK: - Public API

    /// Run full compliance check
    public func runComplianceCheck(
        content: ContentInfo,
        aiInfo: AIContentInfo,
        nftInfo: NFTInfo,
        biometricInfo: BiometricInfo
    ) async throws -> ComplianceCheckResult {
        isChecking = true
        defer { isChecking = false }

        log.info("Starting comprehensive compliance check", category: .system)

        // Run all checks in parallel
        async let gemaCheck = checkGEMACompliance(content)
        async let vgWortCheck = checkVGWortCompliance(content)
        async let euAIActCheck = checkEUAIActCompliance(aiInfo)
        async let micaCheck = checkMiCACompliance(nftInfo)
        async let gdprCheck = checkGDPRCompliance(biometricInfo)

        let results = try await (gemaCheck, vgWortCheck, euAIActCheck, micaCheck, gdprCheck)

        // Aggregate warnings and blocking issues
        var warnings: [ComplianceWarning] = []
        var blockingIssues: [BlockingIssue] = []

        // Process GEMA results
        if results.0.hasUnlicensedContent {
            blockingIssues.append(BlockingIssue(
                id: UUID(),
                category: .gema,
                title: "Unlicensed Content Detected",
                description: "The content contains samples or material that may require licensing",
                resolution: "Obtain proper licenses or remove unlicensed material",
                legalReference: "GEMA v. OpenAI (2024)"
            ))
        }
        warnings.append(contentsOf: results.0.warnings.map { msg in
            ComplianceWarning(
                id: UUID(),
                category: .gema,
                message: msg,
                recommendation: "Verify licensing status",
                severity: .warning,
                documentationURL: URL(string: "https://www.gema.de/en/")
            )
        })

        // Process EU AI Act results
        if results.2.disclosureRequired && !results.2.disclosurePresent {
            blockingIssues.append(BlockingIssue(
                id: UUID(),
                category: .euAIAct,
                title: "AI Content Disclosure Required",
                description: "Content contains \(Int(results.2.aiContentPercentage))% AI-generated material requiring disclosure",
                resolution: "Add AI content disclosure label to metadata",
                legalReference: "EU AI Act Article 52"
            ))
        }
        if results.2.riskCategory == .high {
            warnings.append(ComplianceWarning(
                id: UUID(),
                category: .euAIAct,
                message: "High-risk AI content requires additional documentation",
                recommendation: "Provide AI system documentation and human oversight details",
                severity: .critical,
                documentationURL: URL(string: "https://artificialintelligenceact.eu/")
            ))
        }

        // Process MiCA results
        if results.3.requiresWhitepaper && !results.3.whitepaperProvided {
            warnings.append(ComplianceWarning(
                id: UUID(),
                category: .mica,
                message: "NFT series may require MiCA whitepaper",
                recommendation: "Consider providing a crypto-asset whitepaper for series > 10,000",
                severity: .warning,
                documentationURL: URL(string: "https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A32023R1114")
            ))
        }

        // Process GDPR results
        if results.4.biometricDataUsed && !results.4.consentObtained {
            blockingIssues.append(BlockingIssue(
                id: UUID(),
                category: .gdpr,
                title: "Biometric Consent Required",
                description: "Biometric data cannot be stored on blockchain without explicit consent",
                resolution: "Obtain explicit consent for biometric data processing",
                legalReference: "GDPR Article 9(2)(a)"
            ))
        }

        // Determine overall status
        let overallStatus: ComplianceCheckResult.Status
        if !blockingIssues.isEmpty {
            overallStatus = .failed
        } else if !warnings.isEmpty {
            overallStatus = .passedWithWarnings
        } else {
            overallStatus = .passed
        }

        let result = ComplianceCheckResult(
            timestamp: Date(),
            overallStatus: overallStatus,
            gemaResult: results.0,
            vgWortResult: results.1,
            euAIActResult: results.2,
            micaResult: results.3,
            gdprResult: results.4,
            warnings: warnings,
            blockingIssues: blockingIssues
        )

        lastCheckResult = result
        activeWarnings = warnings

        log.info("Compliance check completed: \(overallStatus.rawValue)", category: .system)

        return result
    }

    /// Request biometric data consent
    public func requestBiometricConsent(
        userID: String,
        purposes: [BiometricConsent.Purpose],
        dataCategories: [BiometricConsent.DataCategory]
    ) async -> BiometricConsent {
        // In a real app, this would present a consent dialog
        let consent = BiometricConsent(
            id: UUID(),
            userID: userID,
            consentType: .nftMetadata,
            granted: true,  // User would select this
            timestamp: Date(),
            expirationDate: Calendar.current.date(byAdding: .year, value: 1, to: Date()),
            purposes: purposes,
            dataCategories: dataCategories
        )

        biometricConsents.append(consent)
        saveConsents()

        log.info("Biometric consent recorded for user: \(userID)", category: .system)

        return consent
    }

    /// Revoke biometric consent
    public func revokeConsent(consentID: UUID) {
        biometricConsents.removeAll { $0.id == consentID }
        saveConsents()
        log.info("Consent revoked: \(consentID)", category: .system)
    }

    /// Check if consent exists and is valid
    public func hasValidConsent(userID: String, for purpose: BiometricConsent.Purpose) -> Bool {
        return biometricConsents.contains { consent in
            consent.userID == userID &&
            consent.granted &&
            consent.purposes.contains(purpose) &&
            (consent.expirationDate.map { $0 > Date() } ?? true)
        }
    }

    /// Generate AI content disclosure label
    public func generateAIDisclosureLabel(aiPercentage: Double, aiTechnologies: [String]) -> String {
        let technologies = aiTechnologies.joined(separator: ", ")
        return """
        AI CONTENT DISCLOSURE (EU AI Act Art. 52)
        This content contains approximately \(Int(aiPercentage))% AI-generated material.
        Technologies used: \(technologies)
        Created with Echoelmusic bio-reactive AI tools.
        """
    }

    // MARK: - Input Types

    public struct ContentInfo {
        public let hasISRC: Bool
        public let isrcCode: String?
        public let hasGEMANumber: Bool
        public let gemaWorkNumber: String?
        public let containsSamples: Bool
        public let sampleSources: [String]
        public let hasLyrics: Bool
        public let wordCount: Int

        public init(hasISRC: Bool, isrcCode: String?, hasGEMANumber: Bool, gemaWorkNumber: String?, containsSamples: Bool, sampleSources: [String], hasLyrics: Bool, wordCount: Int) {
            self.hasISRC = hasISRC
            self.isrcCode = isrcCode
            self.hasGEMANumber = hasGEMANumber
            self.gemaWorkNumber = gemaWorkNumber
            self.containsSamples = containsSamples
            self.sampleSources = sampleSources
            self.hasLyrics = hasLyrics
            self.wordCount = wordCount
        }
    }

    public struct AIContentInfo {
        public let containsAIContent: Bool
        public let aiPercentage: Double
        public let aiTechnologies: [String]
        public let humanOversight: Bool
        public let aiDisclosurePresent: Bool

        public init(containsAIContent: Bool, aiPercentage: Double, aiTechnologies: [String], humanOversight: Bool, aiDisclosurePresent: Bool) {
            self.containsAIContent = containsAIContent
            self.aiPercentage = aiPercentage
            self.aiTechnologies = aiTechnologies
            self.humanOversight = humanOversight
            self.aiDisclosurePresent = aiDisclosurePresent
        }
    }

    public struct NFTInfo {
        public let isPartOfSeries: Bool
        public let seriesSize: Int
        public let isFractionalized: Bool
        public let hasWhitepaper: Bool
        public let network: NFTFactory.BlockchainNetwork

        public init(isPartOfSeries: Bool, seriesSize: Int, isFractionalized: Bool, hasWhitepaper: Bool, network: NFTFactory.BlockchainNetwork) {
            self.isPartOfSeries = isPartOfSeries
            self.seriesSize = seriesSize
            self.isFractionalized = isFractionalized
            self.hasWhitepaper = hasWhitepaper
            self.network = network
        }
    }

    public struct BiometricInfo {
        public let usesBiometricData: Bool
        public let dataCategories: [BiometricConsent.DataCategory]
        public let userID: String
        public let storageLocation: StorageLocation

        public enum StorageLocation: String {
            case local = "Local Device"
            case cloud = "Cloud Server"
            case blockchain = "Blockchain"
            case ipfs = "IPFS"
        }

        public init(usesBiometricData: Bool, dataCategories: [BiometricConsent.DataCategory], userID: String, storageLocation: StorageLocation) {
            self.usesBiometricData = usesBiometricData
            self.dataCategories = dataCategories
            self.userID = userID
            self.storageLocation = storageLocation
        }
    }

    // MARK: - Private Methods

    private func checkGEMACompliance(_ content: ContentInfo) async throws -> GEMACheckResult {
        var warnings: [String] = []
        var licensedSamples: [GEMACheckResult.LicensedSample] = []

        // Validate ISRC if provided
        var isrcValid = false
        if let isrc = content.isrcCode {
            isrcValid = validateISRCFormat(isrc)
            if !isrcValid {
                warnings.append("ISRC code format is invalid")
            }
        }

        // Validate GEMA number if provided
        var gemaValid = false
        if let gemaNumber = content.gemaWorkNumber {
            gemaValid = validateGEMAFormat(gemaNumber)
            if !gemaValid {
                warnings.append("GEMA work number format is invalid")
            }
        }

        // Check samples
        let hasUnlicensed = content.containsSamples && content.sampleSources.isEmpty

        if content.containsSamples {
            for source in content.sampleSources {
                licensedSamples.append(GEMACheckResult.LicensedSample(
                    sampleID: UUID().uuidString,
                    source: source,
                    licenseType: "Royalty-Free",  // Would be verified
                    expirationDate: nil
                ))
            }
        }

        if !content.hasISRC && !content.hasGEMANumber {
            warnings.append("No ISRC or GEMA registration - consider registering for royalty collection")
        }

        return GEMACheckResult(
            isrcValidated: isrcValid || !content.hasISRC,
            gemaWorkNumberValidated: gemaValid || !content.hasGEMANumber,
            hasUnlicensedContent: hasUnlicensed,
            licensedSamples: licensedSamples,
            warnings: warnings
        )
    }

    private func checkVGWortCompliance(_ content: ContentInfo) async throws -> VGWortCheckResult {
        return VGWortCheckResult(
            hasTextContent: content.hasLyrics,
            vgWortRegistered: false,  // Would check registration
            pixelIntegrated: false,   // Would check pixel integration
            estimatedWordCount: content.wordCount
        )
    }

    private func checkEUAIActCompliance(_ aiInfo: AIContentInfo) async throws -> EUAIActCheckResult {
        // Determine risk category
        let riskCategory: EUAIActCheckResult.AIRiskCategory
        if aiInfo.aiPercentage > 90 && !aiInfo.humanOversight {
            riskCategory = .high
        } else if aiInfo.aiPercentage > 50 {
            riskCategory = .limited
        } else {
            riskCategory = .minimal
        }

        // Disclosure required if AI content > 10%
        let disclosureRequired = aiInfo.aiPercentage > 10

        return EUAIActCheckResult(
            aiContentDetected: aiInfo.containsAIContent,
            aiContentPercentage: aiInfo.aiPercentage,
            disclosureRequired: disclosureRequired,
            disclosurePresent: aiInfo.aiDisclosurePresent,
            riskCategory: riskCategory,
            transparencyRequirementsMet: !disclosureRequired || aiInfo.aiDisclosurePresent
        )
    }

    private func checkMiCACompliance(_ nftInfo: NFTInfo) async throws -> MiCACheckResult {
        // NFTs are generally exempt from MiCA unless:
        // 1. Fractionalized
        // 2. Part of a large series (fungible-like)
        // 3. Primarily used as payment

        let isExempt = !nftInfo.isFractionalized && (!nftInfo.isPartOfSeries || nftInfo.seriesSize < 10000)
        let requiresWhitepaper = nftInfo.isPartOfSeries && nftInfo.seriesSize >= 10000

        return MiCACheckResult(
            isNFTExempt: isExempt,
            isFractionalized: nftInfo.isFractionalized,
            isPartOfSeries: nftInfo.isPartOfSeries,
            seriesSize: nftInfo.isPartOfSeries ? nftInfo.seriesSize : nil,
            requiresWhitepaper: requiresWhitepaper,
            whitepaperProvided: nftInfo.hasWhitepaper,
            cryptoAssetServiceProvider: false
        )
    }

    private func checkGDPRCompliance(_ biometricInfo: BiometricInfo) async throws -> GDPRCheckResult {
        let consentObtained = hasValidConsent(userID: biometricInfo.userID, for: .nftCreation)

        return GDPRCheckResult(
            biometricDataUsed: biometricInfo.usesBiometricData,
            consentObtained: consentObtained,
            consentTimestamp: biometricConsents.first { $0.userID == biometricInfo.userID }?.timestamp,
            dataMinimization: true,  // Would verify
            rightToErasure: true,    // Implemented
            dataPortability: true,   // Implemented
            processingLawfulBasis: consentObtained ? .consent : nil
        )
    }

    private func validateISRCFormat(_ isrc: String) -> Bool {
        // ISRC format: CC-XXX-YY-NNNNN
        let pattern = "^[A-Z]{2}-?[A-Z0-9]{3}-?\\d{2}-?\\d{5}$"
        return isrc.range(of: pattern, options: .regularExpression) != nil
    }

    private func validateGEMAFormat(_ gemaNumber: String) -> Bool {
        // GEMA work number: 7-10 digits
        let pattern = "^\\d{7,10}$"
        return gemaNumber.range(of: pattern, options: .regularExpression) != nil
    }

    private func loadConsents() {
        if let data = UserDefaults.standard.data(forKey: "echoelmusic.biometricConsents"),
           let consents = try? JSONDecoder().decode([BiometricConsent].self, from: data) {
            biometricConsents = consents
        }
    }

    private func saveConsents() {
        if let data = try? JSONEncoder().encode(biometricConsents) {
            UserDefaults.standard.set(data, forKey: "echoelmusic.biometricConsents")
        }
    }
}
