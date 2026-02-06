// MARK: - EchoelaConstitution.swift
// Echoelmusic Suite - Echoela Constitutional Framework
// Copyright 2026 Echoelmusic. All rights reserved.
//
// The Constitutional Layer ensures Echoela operates within legal, ethical,
// and artistic boundaries. Inspired by Anthropic's Constitutional AI approach
// and mandated by LG München I (Az. 42 O 14139/24).
//
// Principles:
// 1. Transparent Refusal (Phronesis) - explain, don't just block
// 2. Copyright Respect - no memorization-based reproduction
// 3. Creator Sovereignty - artists own their work
// 4. Privacy by Design - biometric data stays local
// 5. Accessibility First - universal design for all abilities
// 6. Scientific Honesty - no unsubstantiated health claims
// 7. Fair Compensation - proper licensing and attribution

import Foundation
import Combine

// MARK: - Constitutional Principles

/// The core principles governing Echoela's behavior
public enum ConstitutionalPrinciple: String, CaseIterable, Codable {
    case transparentRefusal = "Transparent Refusal"
    case copyrightRespect = "Copyright Respect"
    case creatorSovereignty = "Creator Sovereignty"
    case privacyByDesign = "Privacy by Design"
    case accessibilityFirst = "Accessibility First"
    case scientificHonesty = "Scientific Honesty"
    case fairCompensation = "Fair Compensation"

    public var description: String {
        switch self {
        case .transparentRefusal:
            return "Echoela erklärt Ablehnungen transparent mit rechtlicher Begründung (Phronesis)"
        case .copyrightRespect:
            return "Keine Reproduktion memorisierter geschützter Inhalte (LG München I, 2025)"
        case .creatorSovereignty:
            return "Künstler behalten die volle Kontrolle über ihre Werke"
        case .privacyByDesign:
            return "Biometrische Daten werden ausschließlich lokal verarbeitet"
        case .accessibilityFirst:
            return "Universelles Design für alle Fähigkeiten (WCAG 2.2 AAA)"
        case .scientificHonesty:
            return "Keine unbelegten Gesundheits- oder Wellness-Versprechen"
        case .fairCompensation:
            return "Korrekte Lizenzierung, Attribution und Vergütung"
        }
    }

    public var legalBasis: String {
        switch self {
        case .transparentRefusal:
            return "EU AI Act Art. 13 (Transparenzpflichten)"
        case .copyrightRespect:
            return "§ 19a UrhG; LG München I Az. 42 O 14139/24"
        case .creatorSovereignty:
            return "§ 11 UrhG (Urheberrecht schützt den Urheber)"
        case .privacyByDesign:
            return "DSGVO Art. 25 (Datenschutz durch Technikgestaltung)"
        case .accessibilityFirst:
            return "EU Accessibility Act (EAA) 2025; BFSG"
        case .scientificHonesty:
            return "UWG § 5 (Irreführende geschäftliche Handlungen)"
        case .fairCompensation:
            return "GEMA Wahrnehmungsvertrag; VGG"
        }
    }
}

// MARK: - EU AI Act Risk Classification

/// EU AI Act risk classification for Echoela features
public enum AIActRiskLevel: String, Codable, CaseIterable {
    case minimal = "Minimal Risk"
    case limited = "Limited Risk"
    case high = "High Risk"
    case unacceptable = "Unacceptable Risk"

    /// Required transparency measures per risk level
    public var requiredMeasures: [String] {
        switch self {
        case .minimal:
            return ["Optional: Code of Practice adherence"]
        case .limited:
            return [
                "AI content disclosure label",
                "User notification of AI interaction",
                "Logging of AI-assisted decisions"
            ]
        case .high:
            return [
                "Conformity assessment",
                "Risk management system",
                "Technical documentation",
                "Record-keeping",
                "Transparency to users",
                "Human oversight measures",
                "Accuracy, robustness, cybersecurity"
            ]
        case .unacceptable:
            return ["PROHIBITED - Must not be implemented"]
        }
    }
}

// MARK: - Echoela Feature Risk Assessment

/// Risk classification of each Echoela feature under EU AI Act
public struct FeatureRiskAssessment: Identifiable, Codable {
    public let id: UUID
    public let featureName: String
    public let riskLevel: AIActRiskLevel
    public let rationale: String
    public let mitigations: [String]
    public let humanOversightRequired: Bool
}

// MARK: - Constitution Engine

/// The Constitutional Engine enforces principles across all Echoela operations
@MainActor
public final class EchoelaConstitution: ObservableObject {

    // MARK: - Singleton

    public static let shared = EchoelaConstitution()

    // MARK: - Published State

    @Published public private(set) var principleViolations: [PrincipleViolation] = []
    @Published public private(set) var featureAssessments: [FeatureRiskAssessment] = []
    @Published public private(set) var isCompliant: Bool = true

    // MARK: - Types

    public struct PrincipleViolation: Identifiable, Codable {
        public let id: UUID
        public let timestamp: Date
        public let principle: ConstitutionalPrinciple
        public let severity: Severity
        public let context: String
        public let resolution: String?

        public enum Severity: String, Codable {
            case warning = "Warning"
            case violation = "Violation"
            case critical = "Critical"
        }
    }

    // MARK: - Initialization

    private init() {
        registerFeatureAssessments()
    }

    // MARK: - Feature Risk Assessment Registry

    private func registerFeatureAssessments() {
        featureAssessments = [
            // Morphic Engine: Limited Risk (AI generates DSP, but no safety-critical output)
            FeatureRiskAssessment(
                id: UUID(),
                featureName: "Morphic Engine (DSP Generation)",
                riskLevel: .limited,
                rationale: "AI generates audio processing graphs from natural language. Output is creative/artistic, not safety-critical.",
                mitigations: [
                    "GEMA-Sentinel scans output for memorization",
                    "Sandbox limits prevent harmful audio levels",
                    "AI disclosure label on generated content",
                    "Human approval before distribution"
                ],
                humanOversightRequired: false
            ),

            // Echoela Chat: Limited Risk
            FeatureRiskAssessment(
                id: UUID(),
                featureName: "Echoela Assistant (Chat)",
                riskLevel: .limited,
                rationale: "Conversational AI for music creation guidance. No autonomous decisions affecting rights or safety.",
                mitigations: [
                    "Transparent AI disclosure",
                    "No medical/health advice",
                    "Transparent refusal for copyright violations",
                    "User controls all final decisions"
                ],
                humanOversightRequired: false
            ),

            // Bio-Reactive Features: Minimal Risk
            FeatureRiskAssessment(
                id: UUID(),
                featureName: "Bio-Reactive Audio/Visual",
                riskLevel: .minimal,
                rationale: "Maps biometric signals to creative parameters. Explicitly not a medical device.",
                mitigations: [
                    "Health disclaimers on all biometric features",
                    "Local-only data processing",
                    "No diagnostic or therapeutic claims",
                    "Seizure/photosensitivity warnings"
                ],
                humanOversightRequired: false
            ),

            // NFT Minting: Limited Risk
            FeatureRiskAssessment(
                id: UUID(),
                featureName: "NFT Factory (Content Distribution)",
                riskLevel: .limited,
                rationale: "Enables content distribution on blockchain. Requires compliance checks before minting.",
                mitigations: [
                    "GEMA-Sentinel pre-distribution check mandatory",
                    "ISRC validation required",
                    "AI disclosure label required",
                    "MiCA compliance verification",
                    "Biometric consent verification"
                ],
                humanOversightRequired: true
            ),

            // Brainwave Entrainment: Limited Risk
            FeatureRiskAssessment(
                id: UUID(),
                featureName: "Brainwave Entrainment (Binaural Beats)",
                riskLevel: .limited,
                rationale: "Audio-based relaxation tool. Evidence for neurophysiological effects is inconsistent (meta-analysis).",
                mitigations: [
                    "Scientific honesty disclaimer",
                    "No 'healing' or 'treatment' claims",
                    "Seizure warning for photosensitive users",
                    "Clear 'not a medical device' label"
                ],
                humanOversightRequired: false
            )
        ]
    }

    // MARK: - Principle Validation

    /// Validate an action against constitutional principles
    public func validateAction(
        action: String,
        context: ActionContext
    ) -> ValidationResult {
        var violations: [PrincipleViolation] = []

        // Check copyright respect
        if context.involvesGeneratedContent && !context.hasMemorizationCheck {
            violations.append(PrincipleViolation(
                id: UUID(),
                timestamp: Date(),
                principle: .copyrightRespect,
                severity: .violation,
                context: "Generated content distributed without memorization check",
                resolution: "Run GEMA-Sentinel scan before distribution"
            ))
        }

        // Check transparency
        if context.involvesAI && !context.hasAIDisclosure {
            violations.append(PrincipleViolation(
                id: UUID(),
                timestamp: Date(),
                principle: .transparentRefusal,
                severity: .warning,
                context: "AI-assisted content without disclosure label",
                resolution: "Add AI content disclosure per EU AI Act Art. 52"
            ))
        }

        // Check scientific honesty
        if context.involvesHealthClaims && !context.hasDisclaimer {
            violations.append(PrincipleViolation(
                id: UUID(),
                timestamp: Date(),
                principle: .scientificHonesty,
                severity: .critical,
                context: "Health-related feature without proper disclaimer",
                resolution: "Add 'not a medical device' disclaimer"
            ))
        }

        // Check privacy
        if context.involvesBiometricData && !context.hasConsent {
            violations.append(PrincipleViolation(
                id: UUID(),
                timestamp: Date(),
                principle: .privacyByDesign,
                severity: .critical,
                context: "Biometric data processing without explicit consent",
                resolution: "Obtain GDPR-compliant explicit consent"
            ))
        }

        // Check fair compensation
        if context.involvesDistribution && !context.hasLicenseCheck {
            violations.append(PrincipleViolation(
                id: UUID(),
                timestamp: Date(),
                principle: .fairCompensation,
                severity: .warning,
                context: "Content distribution without license verification",
                resolution: "Verify ISRC, GEMA registration, and sample licenses"
            ))
        }

        principleViolations.append(contentsOf: violations)
        isCompliant = violations.filter { $0.severity == .critical || $0.severity == .violation }.isEmpty

        return ValidationResult(
            isValid: violations.isEmpty,
            violations: violations,
            canProceed: isCompliant
        )
    }

    /// Context for action validation
    public struct ActionContext {
        public let involvesGeneratedContent: Bool
        public let involvesAI: Bool
        public let involvesHealthClaims: Bool
        public let involvesBiometricData: Bool
        public let involvesDistribution: Bool
        public let hasMemorizationCheck: Bool
        public let hasAIDisclosure: Bool
        public let hasDisclaimer: Bool
        public let hasConsent: Bool
        public let hasLicenseCheck: Bool

        public init(
            involvesGeneratedContent: Bool = false,
            involvesAI: Bool = false,
            involvesHealthClaims: Bool = false,
            involvesBiometricData: Bool = false,
            involvesDistribution: Bool = false,
            hasMemorizationCheck: Bool = false,
            hasAIDisclosure: Bool = false,
            hasDisclaimer: Bool = false,
            hasConsent: Bool = false,
            hasLicenseCheck: Bool = false
        ) {
            self.involvesGeneratedContent = involvesGeneratedContent
            self.involvesAI = involvesAI
            self.involvesHealthClaims = involvesHealthClaims
            self.involvesBiometricData = involvesBiometricData
            self.involvesDistribution = involvesDistribution
            self.hasMemorizationCheck = hasMemorizationCheck
            self.hasAIDisclosure = hasAIDisclosure
            self.hasDisclaimer = hasDisclaimer
            self.hasConsent = hasConsent
            self.hasLicenseCheck = hasLicenseCheck
        }
    }

    /// Result of constitutional validation
    public struct ValidationResult {
        public let isValid: Bool
        public let violations: [PrincipleViolation]
        public let canProceed: Bool
    }

    // MARK: - Compliance Report

    /// Generate a comprehensive compliance report
    public var complianceReport: ComplianceReport {
        let criticalCount = principleViolations.filter { $0.severity == .critical }.count
        let violationCount = principleViolations.filter { $0.severity == .violation }.count
        let warningCount = principleViolations.filter { $0.severity == .warning }.count

        return ComplianceReport(
            timestamp: Date(),
            isCompliant: isCompliant,
            criticalIssues: criticalCount,
            violations: violationCount,
            warnings: warningCount,
            featureAssessments: featureAssessments,
            recentViolations: Array(principleViolations.suffix(10)),
            sentinelReport: GEMASentinel.shared.healthReport
        )
    }

    public struct ComplianceReport {
        public let timestamp: Date
        public let isCompliant: Bool
        public let criticalIssues: Int
        public let violations: Int
        public let warnings: Int
        public let featureAssessments: [FeatureRiskAssessment]
        public let recentViolations: [PrincipleViolation]
        public let sentinelReport: GEMASentinel.SentinelHealthReport
    }

    // MARK: - Prune Old Data

    /// Clear resolved violations older than 30 days
    public func pruneHistory() {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 3600)
        principleViolations.removeAll { $0.timestamp < cutoff }
    }
}
