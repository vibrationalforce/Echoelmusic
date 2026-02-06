// MARK: - GEMASentinel.swift
// Echoelmusic Suite - Echoela Constitutional Compliance
// Copyright 2026 Echoelmusic. All rights reserved.
//
// GEMA-Sentinel Sub-Agent: Automated copyright compliance based on
// LG München I (11.11.2025, Az. 42 O 14139/24) - GEMA vs. OpenAI
//
// This ruling established that AI models can "memorize" copyrighted content
// (analogous to lossy compression like MP3), making the operator liable
// for unauthorized public reproduction (§ 19a UrhG).
//
// The Sentinel proactively prevents memorization-based output by:
// 1. Scanning generated content for similarity to known works
// 2. Enforcing ISRC/GEMA registration before distribution
// 3. Providing Transparent Refusal with legal reasoning
// 4. Logging all compliance decisions with cryptographic attestation

import Foundation
import Combine
import CryptoKit

// MARK: - Legal Reference

/// Key legal references from LG München I ruling
public enum GEMALegalReference {
    /// § 19a UrhG - Right of public accessibility
    static let publicAccessRight = "§ 19a UrhG (Recht der öffentlichen Zugänglichmachung)"
    /// § 44b UrhG - Text and Data Mining exception (ruled NOT applicable for reproduction)
    static let tdmException = "§ 44b UrhG (Text- und Data-Mining)"
    /// LG München I ruling reference
    static let rulingReference = "LG München I, 11.11.2025, Az. 42 O 14139/24"
    /// GEMA portal AI checkbox requirement
    static let gemaAICheckbox = "GEMA-Portal KI-Kennzeichnungspflicht (2026)"
}

// MARK: - Memorization Risk

/// Risk level for content memorization
public enum MemorizationRisk: String, Codable, CaseIterable {
    case none = "No Risk"
    case low = "Low Risk"
    case medium = "Medium Risk"
    case high = "High Risk"
    case critical = "Critical - Blocked"

    public var requiresAction: Bool {
        switch self {
        case .none, .low: return false
        case .medium, .high, .critical: return true
        }
    }

    public var isBlocking: Bool {
        self == .critical || self == .high
    }
}

// MARK: - Content Origin Classification

/// Classification of content creation method (GEMA AI checkbox)
public enum ContentOriginClass: String, Codable {
    case fullyHuman = "Vollständig ohne KI erstellt"
    case humanWithAIAssist = "Überwiegend menschlich, KI-unterstützt"
    case aiWithHumanOversight = "KI-generiert mit menschlicher Aufsicht"
    case fullyAIGenerated = "Vollständig KI-generiert"

    /// Whether GEMA AI disclosure is required
    public var requiresAIDisclosure: Bool {
        switch self {
        case .fullyHuman: return false
        case .humanWithAIAssist: return true
        case .aiWithHumanOversight: return true
        case .fullyAIGenerated: return true
        }
    }

    /// Penalty multiplier risk without proper disclosure
    public var penaltyRisk: String {
        switch self {
        case .fullyHuman: return "None"
        case .humanWithAIAssist: return "Low - disclose to avoid 100% surcharge"
        case .aiWithHumanOversight: return "Medium - mandatory GEMA portal disclosure"
        case .fullyAIGenerated: return "High - 100% Strafzuschlag bei Kontrollen ohne Meldung"
        }
    }
}

// MARK: - Similarity Check Result

/// Result of checking generated content against known works
public struct SimilarityCheckResult: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let contentType: ContentType
    public let similarityScore: Double // 0.0 = no match, 1.0 = exact match
    public let matchedWorkID: String?
    public let matchedWorkTitle: String?
    public let matchedRightsHolder: String?
    public let risk: MemorizationRisk
    public let recommendation: String

    public enum ContentType: String, Codable {
        case melody = "Melodie"
        case harmony = "Harmonie"
        case lyrics = "Text/Lyrics"
        case rhythm = "Rhythmus"
        case timbre = "Klangfarbe"
        case dspAlgorithm = "DSP-Algorithmus"
        case sampleContent = "Sample"
    }

    /// Whether this result blocks distribution
    public var isBlocking: Bool {
        risk.isBlocking
    }
}

// MARK: - Transparent Refusal

/// A structured refusal with legal reasoning (Phronesis - practical wisdom)
public struct TransparentRefusal: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let requestedAction: String
    public let refusalReason: String
    public let legalBasis: String
    public let recommendation: String
    public let alternativeActions: [String]

    /// Human-readable explanation for the user
    public var userFacingMessage: String {
        """
        Ich kann diesen Vorgang nicht abschließen: \(refusalReason)

        Rechtliche Grundlage: \(legalBasis)

        Empfehlung: \(recommendation)
        \(alternativeActions.isEmpty ? "" : "\nAlternativen:\n" + alternativeActions.enumerated().map { "  \($0.offset + 1). \($0.element)" }.joined(separator: "\n"))
        """
    }
}

// MARK: - Compliance Attestation

/// Cryptographically signed compliance decision
public struct ComplianceAttestation: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let decision: Decision
    public let contentHash: String
    public let signatureHex: String
    public let details: String

    public enum Decision: String, Codable {
        case approved = "Approved"
        case approvedWithDisclosure = "Approved with AI Disclosure"
        case rejected = "Rejected"
        case pendingReview = "Pending Manual Review"
    }
}

// MARK: - GEMA Sentinel

/// Automated copyright compliance sub-agent for Echoela
/// Implements proactive memorization detection and transparent refusal
@MainActor
public final class GEMASentinel: ObservableObject {

    // MARK: - Singleton

    public static let shared = GEMASentinel()

    // MARK: - Published State

    @Published public private(set) var isScanning: Bool = false
    @Published public private(set) var lastScanResult: [SimilarityCheckResult] = []
    @Published public private(set) var refusals: [TransparentRefusal] = []
    @Published public private(set) var attestations: [ComplianceAttestation] = []
    @Published public private(set) var totalScans: Int = 0
    @Published public private(set) var blockedActions: Int = 0

    // MARK: - Configuration

    /// Similarity threshold above which content is flagged (0-1)
    public var similarityThreshold: Double = 0.85

    /// Strict mode: block at medium risk instead of high
    public var strictMode: Bool = false

    /// HMAC key for attestation signing (derived from Secure Enclave in production)
    private let attestationKey: SymmetricKey

    // MARK: - Initialization

    private init() {
        // In production: derive key from Secure Enclave
        // For now: generate a session key
        self.attestationKey = SymmetricKey(size: .bits256)
    }

    // MARK: - Content Scanning

    /// Scan generated audio content for memorization of copyrighted works
    /// This is the core safety check before any content distribution
    public func scanForMemorization(
        contentDescription: String,
        contentType: SimilarityCheckResult.ContentType,
        originClass: ContentOriginClass
    ) async -> SimilarityCheckResult {
        isScanning = true
        defer { isScanning = false }
        totalScans += 1

        // Simulate similarity analysis
        // In production: compare against GEMA database, audio fingerprint DB, melody contour matching
        let similarityScore = analyzeSimilarity(description: contentDescription, type: contentType)

        let risk: MemorizationRisk
        switch similarityScore {
        case 0..<0.3: risk = .none
        case 0.3..<0.5: risk = .low
        case 0.5..<0.7: risk = .medium
        case 0.7..<similarityThreshold: risk = .high
        default: risk = .critical
        }

        let recommendation: String
        switch risk {
        case .none:
            recommendation = "Keine Ähnlichkeit zu bekannten Werken erkannt. Verbreitung möglich."
        case .low:
            recommendation = "Geringe Ähnlichkeit. Empfehlung: ISRC-Registrierung vor Veröffentlichung."
        case .medium:
            recommendation = "Mittlere Ähnlichkeit. Bitte Lizenzdaten hinterlegen oder Werk anpassen."
        case .high:
            recommendation = "Hohe Ähnlichkeit zu geschütztem Werk. Verbreitung blockiert bis Lizenznachweis erbracht."
        case .critical:
            recommendation = "Kritische Übereinstimmung. Verdacht auf Memorisierung gemäß \(GEMALegalReference.rulingReference). Ausgabe wird verhindert."
        }

        let result = SimilarityCheckResult(
            id: UUID(),
            timestamp: Date(),
            contentType: contentType,
            similarityScore: similarityScore,
            matchedWorkID: similarityScore > 0.5 ? "GEMA-\(Int.random(in: 1000000...9999999))" : nil,
            matchedWorkTitle: similarityScore > 0.5 ? "Protected Work (simulated)" : nil,
            matchedRightsHolder: similarityScore > 0.5 ? "GEMA Member" : nil,
            risk: risk,
            recommendation: recommendation
        )

        lastScanResult.append(result)

        // Log the scan
        log.info("GEMA-Sentinel: Scan completed - risk: \(risk.rawValue), score: \(String(format: "%.2f", similarityScore))", category: .privacy)

        return result
    }

    // MARK: - Transparent Refusal

    /// Generate a transparent refusal with legal reasoning
    /// Implements "Phronesis" (practical wisdom) - not just saying no, but explaining why
    public func generateRefusal(
        requestedAction: String,
        reason: RefusalReason
    ) -> TransparentRefusal {
        blockedActions += 1

        let refusal = TransparentRefusal(
            id: UUID(),
            timestamp: Date(),
            requestedAction: requestedAction,
            refusalReason: reason.description,
            legalBasis: reason.legalBasis,
            recommendation: reason.recommendation,
            alternativeActions: reason.alternatives
        )

        refusals.append(refusal)
        log.warning("GEMA-Sentinel: Transparent Refusal - \(requestedAction): \(reason.description)", category: .privacy)
        return refusal
    }

    /// Pre-defined refusal reasons
    public enum RefusalReason {
        case memorization(similarity: Double)
        case missingISRC
        case missingGEMARegistration
        case missingAIDisclosure(originClass: ContentOriginClass)
        case unlicensedSample(sampleID: String)
        case missingLicenseData

        public var description: String {
            switch self {
            case .memorization(let similarity):
                return "Gefahr der Memorisierung geschützter Inhalte (Ähnlichkeit: \(Int(similarity * 100))%)"
            case .missingISRC:
                return "Fehlende ISRC-Hinterlegung für die Verbreitung"
            case .missingGEMARegistration:
                return "Fehlende GEMA-Werkregistrierung"
            case .missingAIDisclosure(let origin):
                return "KI-Kennzeichnung fehlt für Werk der Klasse '\(origin.rawValue)'"
            case .unlicensedSample(let id):
                return "Unlizenziertes Sample verwendet (ID: \(id))"
            case .missingLicenseData:
                return "Fehlende Lizenzdaten in der Aura-Zone"
            }
        }

        public var legalBasis: String {
            switch self {
            case .memorization:
                return "\(GEMALegalReference.rulingReference) - Memorisierung als Vervielfältigung; \(GEMALegalReference.publicAccessRight)"
            case .missingISRC:
                return "IFPI ISRC Standard (ISO 3901) - Pflichtregistrierung für kommerzielle Verbreitung"
            case .missingGEMARegistration:
                return "GEMA Wahrnehmungsvertrag - Werkregistrierung für Vergütungsanspruch"
            case .missingAIDisclosure:
                return "\(GEMALegalReference.gemaAICheckbox) - Verpflichtende KI-Kennzeichnung im GEMA-Portal"
            case .unlicensedSample:
                return "\(GEMALegalReference.publicAccessRight) - Vervielfältigung ohne Lizenz"
            case .missingLicenseData:
                return "§ 44b Abs. 3 UrhG - Nutzungsvorbehalt des Rechteinhabers"
            }
        }

        public var recommendation: String {
            switch self {
            case .memorization:
                return "Bitte hinterlege die Lizenzdaten in der Aura-Zone oder passe das Werk an, um die Ähnlichkeit zu reduzieren."
            case .missingISRC:
                return "Registriere einen ISRC-Code über dein Label oder die IFPI-Nationalagentur."
            case .missingGEMARegistration:
                return "Melde das Werk im GEMA-Online-Portal an und nutze die KI-Checkbox."
            case .missingAIDisclosure:
                return "Kennzeichne den KI-Anteil im GEMA-Portal, um den 100% Strafzuschlag zu vermeiden."
            case .unlicensedSample:
                return "Lizenziere das Sample über den Rechteinhaber oder ersetze es durch eigenes Material."
            case .missingLicenseData:
                return "Hinterlege alle erforderlichen Lizenzdaten bevor du das Werk verbreitest."
            }
        }

        public var alternatives: [String] {
            switch self {
            case .memorization:
                return [
                    "Morphic Engine nutzen, um ein originales Klangdesign zu erstellen",
                    "Parameter anpassen, bis die Ähnlichkeit unter den Schwellwert fällt",
                    "Lizenz beim Rechteinhaber anfragen"
                ]
            case .missingISRC:
                return [
                    "ISRC über Echoelmusic Distribution beantragen",
                    "Werk nur für privaten Gebrauch exportieren (kein ISRC nötig)"
                ]
            case .missingGEMARegistration:
                return [
                    "Werk als GEMA-frei kennzeichnen (nur wenn keine GEMA-Mitgliedschaft)",
                    "Werk im GEMA-Portal registrieren"
                ]
            case .missingAIDisclosure:
                return [
                    "KI-Anteil im Echoelmusic Export-Dialog angeben",
                    "Werk als 'vollständig ohne KI' klassifizieren (nur wenn zutreffend)"
                ]
            case .unlicensedSample, .missingLicenseData:
                return [
                    "Sample durch Echoela-generiertes Material ersetzen",
                    "Lizenz beim Rechteinhaber anfragen"
                ]
            }
        }
    }

    // MARK: - Compliance Attestation

    /// Create a cryptographically signed attestation of a compliance decision
    public func createAttestation(
        decision: ComplianceAttestation.Decision,
        contentHash: String,
        details: String
    ) -> ComplianceAttestation {
        // Sign the decision with HMAC-SHA256
        let dataToSign = "\(decision.rawValue)|\(contentHash)|\(details)|\(Date().timeIntervalSince1970)"
        let signature = HMAC<SHA256>.authenticationCode(
            for: Data(dataToSign.utf8),
            using: attestationKey
        )
        let signatureHex = signature.map { String(format: "%02x", $0) }.joined()

        let attestation = ComplianceAttestation(
            id: UUID(),
            timestamp: Date(),
            decision: decision,
            contentHash: contentHash,
            signatureHex: signatureHex,
            details: details
        )

        attestations.append(attestation)

        // Trim attestation log
        if attestations.count > 1000 {
            attestations = Array(attestations.suffix(1000))
        }

        log.info("GEMA-Sentinel: Attestation created - \(decision.rawValue)", category: .privacy)
        return attestation
    }

    // MARK: - Pre-Distribution Check

    /// Complete pre-distribution compliance check
    /// Call this before any content is exported, shared, or minted as NFT
    public func preDistributionCheck(
        contentDescription: String,
        originClass: ContentOriginClass,
        hasISRC: Bool,
        hasGEMARegistration: Bool,
        isForPublicDistribution: Bool
    ) async -> PreDistributionResult {
        var issues: [TransparentRefusal] = []
        var approved = true

        // 1. Memorization scan
        let melodyScan = await scanForMemorization(
            contentDescription: contentDescription,
            contentType: .melody,
            originClass: originClass
        )
        if melodyScan.isBlocking {
            issues.append(generateRefusal(
                requestedAction: "Distribute content",
                reason: .memorization(similarity: melodyScan.similarityScore)
            ))
            approved = false
        }

        // 2. ISRC check (required for public distribution)
        if isForPublicDistribution && !hasISRC {
            issues.append(generateRefusal(
                requestedAction: "Public distribution",
                reason: .missingISRC
            ))
            approved = false
        }

        // 3. AI disclosure check
        if originClass.requiresAIDisclosure {
            issues.append(generateRefusal(
                requestedAction: "Distribute AI-assisted content",
                reason: .missingAIDisclosure(originClass: originClass)
            ))
            // Non-blocking warning, but logged
            if !isForPublicDistribution { approved = true }
        }

        // 4. GEMA registration check
        if isForPublicDistribution && !hasGEMARegistration {
            // Warning, not blocking (user might not be GEMA member)
            log.info("GEMA-Sentinel: No GEMA registration - user may not be GEMA member", category: .privacy)
        }

        // Create attestation
        let contentHash = SHA256.hash(data: Data(contentDescription.utf8))
            .map { String(format: "%02x", $0) }.joined()

        let decision: ComplianceAttestation.Decision = approved ? .approved : .rejected
        let attestation = createAttestation(
            decision: decision,
            contentHash: String(contentHash.prefix(16)),
            details: "Pre-distribution check: \(issues.count) issues found"
        )

        return PreDistributionResult(
            approved: approved,
            issues: issues,
            attestation: attestation,
            originClass: originClass,
            memorizationRisk: melodyScan.risk
        )
    }

    /// Result of pre-distribution compliance check
    public struct PreDistributionResult {
        public let approved: Bool
        public let issues: [TransparentRefusal]
        public let attestation: ComplianceAttestation
        public let originClass: ContentOriginClass
        public let memorizationRisk: MemorizationRisk
    }

    // MARK: - Morphic Engine Integration

    /// Check Morphic Engine output for memorization before activation
    /// Called by MorphicSandboxManager before activating a generated DSP graph
    public func validateMorphicOutput(graphDescription: String) async -> Bool {
        let result = await scanForMemorization(
            contentDescription: graphDescription,
            contentType: .dspAlgorithm,
            originClass: .aiWithHumanOversight
        )

        if result.isBlocking {
            _ = generateRefusal(
                requestedAction: "Activate Morphic DSP graph",
                reason: .memorization(similarity: result.similarityScore)
            )
            return false
        }
        return true
    }

    // MARK: - Private Helpers

    /// Analyze content similarity (placeholder for production fingerprinting)
    private func analyzeSimilarity(
        description: String,
        type: SimilarityCheckResult.ContentType
    ) -> Double {
        // In production: use audio fingerprinting (Chromaprint/AcoustID),
        // melody contour matching, and GEMA database lookup
        //
        // For now: heuristic based on description keywords
        // This will be replaced with actual audio analysis
        let lowered = description.lowercased()

        // Known protected patterns (simplified heuristic)
        let protectedKeywords = [
            "yesterday", "bohemian", "stairway", "hotel california",
            "imagine", "let it be", "hey jude", "thriller",
            "smells like teen spirit", "wonderwall"
        ]

        for keyword in protectedKeywords {
            if lowered.contains(keyword) {
                return 0.95 // Critical match
            }
        }

        // Generic similarity score based on specificity
        if lowered.contains("copy") || lowered.contains("like the song") || lowered.contains("sound like") {
            return 0.7 // High risk
        }

        // Default: low similarity for original descriptions
        return Double.random(in: 0.0...0.2)
    }

    // MARK: - Statistics

    /// Get sentinel health report
    public var healthReport: SentinelHealthReport {
        SentinelHealthReport(
            totalScans: totalScans,
            blockedActions: blockedActions,
            blockRate: totalScans > 0 ? Double(blockedActions) / Double(totalScans) : 0,
            recentRefusals: Array(refusals.suffix(5)),
            attestationCount: attestations.count
        )
    }

    public struct SentinelHealthReport {
        public let totalScans: Int
        public let blockedActions: Int
        public let blockRate: Double
        public let recentRefusals: [TransparentRefusal]
        public let attestationCount: Int
    }
}
