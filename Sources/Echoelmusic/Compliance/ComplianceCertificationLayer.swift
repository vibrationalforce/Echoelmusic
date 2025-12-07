// ComplianceCertificationLayer.swift
// Echoelmusic - Regulatory Compliance and Certification Framework
//
// Comprehensive compliance tracking for international standards:
// - TÜV (German Technical Inspection Association)
// - ISO (International Organization for Standardization)
// - IEC (International Electrotechnical Commission)
// - Patent and Intellectual Property tracking
// - CE Marking requirements
// - FDA guidelines (for medical applications)
//
// This framework documents compliance status and provides
// traceability for certification processes.

import Foundation
import Combine

// MARK: - Standards and Regulations

/// International standards applicable to the system
public enum ComplianceStandard: String, CaseIterable, Codable {

    // MARK: - Safety Standards

    // Functional Safety
    case iso26262 = "ISO 26262"          // Road vehicles - Functional safety
    case iso13849 = "ISO 13849"          // Safety of machinery - Safety-related parts
    case iec61508 = "IEC 61508"          // Functional safety of E/E/PE systems
    case iec62443 = "IEC 62443"          // Industrial cybersecurity

    // Aviation
    case do178c = "DO-178C"              // Software in Airborne Systems
    case do254 = "DO-254"                // Design Assurance for Airborne Electronic Hardware
    case easa = "EASA CS-25"             // European Aviation Safety Agency

    // Medical Devices
    case iec62304 = "IEC 62304"          // Medical device software lifecycle
    case iso13485 = "ISO 13485"          // Medical devices - QMS
    case iso14971 = "ISO 14971"          // Medical devices - Risk management
    case mdr = "EU MDR 2017/745"         // EU Medical Device Regulation
    case fda21cfr820 = "FDA 21 CFR 820"  // Quality System Regulation

    // Maritime
    case imoSolas = "IMO SOLAS"          // Safety of Life at Sea
    case marpol = "MARPOL"               // Marine Pollution

    // MARK: - Quality Standards

    case iso9001 = "ISO 9001"            // Quality management systems
    case iso27001 = "ISO 27001"          // Information security management
    case iso27701 = "ISO 27701"          // Privacy information management

    // MARK: - Environmental

    case iso14001 = "ISO 14001"          // Environmental management
    case rohs = "RoHS"                    // Restriction of Hazardous Substances
    case weee = "WEEE"                    // Waste Electrical & Electronic Equipment

    // MARK: - Accessibility

    case wcag21 = "WCAG 2.1"             // Web Content Accessibility Guidelines
    case en301549 = "EN 301 549"          // ICT Accessibility

    // MARK: - Electromagnetic

    case iec61000 = "IEC 61000"          // Electromagnetic compatibility (EMC)
    case ceMark = "CE Marking"           // European Conformity

    // MARK: - Data Protection

    case gdpr = "GDPR"                   // General Data Protection Regulation
    case ccpa = "CCPA"                   // California Consumer Privacy Act

    public var fullName: String {
        switch self {
        case .iso26262: return "ISO 26262 - Road vehicles - Functional safety"
        case .iso13849: return "ISO 13849 - Safety of machinery"
        case .iec61508: return "IEC 61508 - Functional safety of E/E/PE systems"
        case .iec62443: return "IEC 62443 - Industrial automation cybersecurity"
        case .do178c: return "DO-178C - Software Considerations in Airborne Systems"
        case .do254: return "DO-254 - Design Assurance for Airborne Electronic Hardware"
        case .easa: return "EASA CS-25 - Large Aeroplanes Certification"
        case .iec62304: return "IEC 62304 - Medical device software - Lifecycle processes"
        case .iso13485: return "ISO 13485 - Medical devices - Quality management"
        case .iso14971: return "ISO 14971 - Medical devices - Risk management"
        case .mdr: return "EU MDR 2017/745 - Medical Device Regulation"
        case .fda21cfr820: return "FDA 21 CFR Part 820 - Quality System Regulation"
        case .imoSolas: return "IMO SOLAS - International Convention for Safety of Life at Sea"
        case .marpol: return "MARPOL - International Convention for Marine Pollution"
        case .iso9001: return "ISO 9001 - Quality management systems"
        case .iso27001: return "ISO 27001 - Information security management"
        case .iso27701: return "ISO 27701 - Privacy information management"
        case .iso14001: return "ISO 14001 - Environmental management systems"
        case .rohs: return "RoHS - Restriction of Hazardous Substances"
        case .weee: return "WEEE - Waste Electrical and Electronic Equipment"
        case .wcag21: return "WCAG 2.1 - Web Content Accessibility Guidelines"
        case .en301549: return "EN 301 549 - Accessibility requirements for ICT products"
        case .iec61000: return "IEC 61000 - Electromagnetic compatibility"
        case .ceMark: return "CE Marking - European Conformity"
        case .gdpr: return "GDPR - General Data Protection Regulation"
        case .ccpa: return "CCPA - California Consumer Privacy Act"
        }
    }

    public var category: StandardCategory {
        switch self {
        case .iso26262, .iso13849, .iec61508, .iec62443,
             .do178c, .do254, .easa, .imoSolas, .marpol:
            return .safety
        case .iec62304, .iso13485, .iso14971, .mdr, .fda21cfr820:
            return .medical
        case .iso9001, .iso27001, .iso27701:
            return .quality
        case .iso14001, .rohs, .weee:
            return .environmental
        case .wcag21, .en301549:
            return .accessibility
        case .iec61000, .ceMark:
            return .electromagnetic
        case .gdpr, .ccpa:
            return .dataProtection
        }
    }

    public var certifyingBodies: [String] {
        switch self {
        case .iso26262, .iso13849, .iso9001, .iso27001, .iso14001, .iso13485, .iso14971:
            return ["TÜV SÜD", "TÜV Rheinland", "TÜV NORD", "SGS", "Bureau Veritas", "DNV"]
        case .do178c, .do254, .easa:
            return ["EASA", "FAA", "TÜV SÜD Aerospace"]
        case .iec62304, .mdr:
            return ["TÜV SÜD", "BSI", "DEKRA", "Notified Bodies"]
        case .fda21cfr820:
            return ["FDA"]
        case .ceMark:
            return ["EU Notified Bodies", "TÜV", "SGS"]
        case .gdpr:
            return ["Data Protection Authorities", "TÜV"]
        default:
            return ["Various accredited bodies"]
        }
    }
}

public enum StandardCategory: String, CaseIterable {
    case safety = "Functional Safety"
    case medical = "Medical Device"
    case quality = "Quality Management"
    case environmental = "Environmental"
    case accessibility = "Accessibility"
    case electromagnetic = "Electromagnetic"
    case dataProtection = "Data Protection"
}

// MARK: - Compliance Status

public enum ComplianceStatus: String, Codable {
    case notApplicable = "Not Applicable"
    case notStarted = "Not Started"
    case inProgress = "In Progress"
    case underReview = "Under Review"
    case pendingCertification = "Pending Certification"
    case certified = "Certified"
    case expired = "Expired"
    case nonCompliant = "Non-Compliant"
}

// MARK: - Compliance Record

public struct ComplianceRecord: Identifiable, Codable {
    public var id: UUID
    public var standard: ComplianceStandard
    public var status: ComplianceStatus
    public var applicableModules: [String]           // Which parts of the system
    public var requirements: [Requirement]
    public var evidence: [Evidence]
    public var audits: [AuditRecord]
    public var certificationNumber: String?
    public var certificationDate: Date?
    public var expirationDate: Date?
    public var certifyingBody: String?
    public var notes: String?
    public var lastUpdated: Date

    public struct Requirement: Identifiable, Codable {
        public var id: UUID
        public var clause: String                     // e.g., "4.3.2"
        public var description: String
        public var status: RequirementStatus
        public var evidence: [UUID]                   // References to Evidence
        public var assignee: String?
        public var dueDate: Date?

        public enum RequirementStatus: String, Codable {
            case notStarted = "Not Started"
            case inProgress = "In Progress"
            case implemented = "Implemented"
            case verified = "Verified"
            case notApplicable = "N/A"
        }
    }

    public struct Evidence: Identifiable, Codable {
        public var id: UUID
        public var type: EvidenceType
        public var title: String
        public var description: String
        public var filePath: String?
        public var url: String?
        public var dateCreated: Date
        public var version: String

        public enum EvidenceType: String, Codable {
            case document = "Document"
            case testReport = "Test Report"
            case designRecord = "Design Record"
            case riskAssessment = "Risk Assessment"
            case codeReview = "Code Review"
            case traceabilityMatrix = "Traceability Matrix"
            case validationReport = "Validation Report"
            case auditReport = "Audit Report"
            case certificate = "Certificate"
        }
    }

    public struct AuditRecord: Identifiable, Codable {
        public var id: UUID
        public var auditType: AuditType
        public var auditor: String
        public var auditDate: Date
        public var findings: [Finding]
        public var result: AuditResult

        public enum AuditType: String, Codable {
            case selfAssessment = "Self-Assessment"
            case internalAudit = "Internal Audit"
            case externalAudit = "External Audit"
            case certificationAudit = "Certification Audit"
            case surveillanceAudit = "Surveillance Audit"
        }

        public struct Finding: Codable {
            public var severity: Severity
            public var description: String
            public var correctiveAction: String?
            public var resolved: Bool

            public enum Severity: String, Codable {
                case observation = "Observation"
                case minor = "Minor Non-Conformity"
                case major = "Major Non-Conformity"
                case critical = "Critical"
            }
        }

        public enum AuditResult: String, Codable {
            case passed = "Passed"
            case passedWithObservations = "Passed with Observations"
            case conditionalPass = "Conditional Pass"
            case failed = "Failed"
        }
    }
}

// MARK: - TÜV Certification Tracking

public struct TUVCertification: Codable {
    public var provider: TUVProvider
    public var scope: String
    public var certificateNumber: String?
    public var status: CertificationStatus
    public var validFrom: Date?
    public var validUntil: Date?
    public var audits: [AuditSchedule]

    public enum TUVProvider: String, CaseIterable, Codable {
        case tuvSud = "TÜV SÜD"
        case tuvRheinland = "TÜV Rheinland"
        case tuvNord = "TÜV NORD"
        case tuvAustria = "TÜV AUSTRIA"
        case tuvSaarland = "TÜV Saarland"
    }

    public enum CertificationStatus: String, Codable {
        case planning = "Planning"
        case application = "Application Submitted"
        case documentReview = "Document Review"
        case onSiteAudit = "On-Site Audit"
        case correctiveActions = "Corrective Actions"
        case certification = "Certified"
        case surveillance = "Under Surveillance"
        case recertification = "Recertification Due"
        case suspended = "Suspended"
        case withdrawn = "Withdrawn"
    }

    public struct AuditSchedule: Codable {
        public var auditType: String
        public var scheduledDate: Date
        public var completed: Bool
        public var result: String?
    }
}

// MARK: - Patent and IP Tracking

public struct IntellectualPropertyRecord: Identifiable, Codable {
    public var id: UUID
    public var type: IPType
    public var title: String
    public var description: String
    public var status: IPStatus
    public var filingDate: Date?
    public var applicationNumber: String?
    public var grantDate: Date?
    public var patentNumber: String?
    public var jurisdictions: [Jurisdiction]
    public var inventors: [String]
    public var assignee: String
    public var claims: [String]
    public var relatedArt: [String]              // Prior art references
    public var annuityDue: Date?

    public enum IPType: String, CaseIterable, Codable {
        case utilityPatent = "Utility Patent"
        case designPatent = "Design Patent"
        case provisionalPatent = "Provisional Patent"
        case trademark = "Trademark"
        case copyright = "Copyright"
        case tradeSecret = "Trade Secret"
    }

    public enum IPStatus: String, Codable {
        case ideation = "Ideation"
        case draftingClaims = "Drafting Claims"
        case priorArtSearch = "Prior Art Search"
        case filed = "Filed"
        case published = "Published"
        case underExamination = "Under Examination"
        case allowance = "Allowance"
        case granted = "Granted"
        case maintained = "Maintained"
        case abandoned = "Abandoned"
        case expired = "Expired"
        case litigated = "In Litigation"
    }

    public enum Jurisdiction: String, CaseIterable, Codable {
        case uspto = "USPTO (USA)"
        case epo = "EPO (Europe)"
        case dpma = "DPMA (Germany)"
        case jpo = "JPO (Japan)"
        case cnipa = "CNIPA (China)"
        case kipo = "KIPO (Korea)"
        case wipo = "WIPO (International)"
        case ukipo = "UKIPO (UK)"
        case inpi = "INPI (France)"
    }
}

// MARK: - Patent Ideas from Echoelmusic

public struct EchoelmusicPatentPortfolio {

    public static let potentialPatents: [IntellectualPropertyRecord] = [
        IntellectualPropertyRecord(
            id: UUID(),
            type: .utilityPatent,
            title: "Bio-Reactive Audio-Visual Generation System",
            description: "System and method for generating and modifying audio-visual content in real-time based on biometric feedback including heart rate variability, skin conductance, brainwave patterns, and emotional state detection.",
            status: .ideation,
            jurisdictions: [.epo, .uspto, .wipo],
            inventors: ["Echoelmusic Team"],
            assignee: "Echoelmusic",
            claims: [
                "A system for real-time audio-visual content generation comprising biometric sensors, signal processing, and adaptive media synthesis.",
                "Method for emotional state detection and corresponding media parameter adjustment.",
                "Apparatus for multi-modal biofeedback integration in creative applications."
            ],
            relatedArt: []
        ),

        IntellectualPropertyRecord(
            id: UUID(),
            type: .utilityPatent,
            title: "Universal Gesture-to-Control Interface for Multi-Domain Applications",
            description: "Universal interface system that translates human gestures, neural signals, and biometric inputs into control commands for diverse applications including vehicle control, surgical robotics, and creative tools.",
            status: .ideation,
            jurisdictions: [.epo, .uspto],
            inventors: ["Echoelmusic Team"],
            assignee: "Echoelmusic",
            claims: [
                "A universal control interface translating multi-modal human inputs to standardized control outputs.",
                "Method for adaptive input mapping across different control domains.",
                "Safety verification system for gesture-based critical system control."
            ],
            relatedArt: []
        ),

        IntellectualPropertyRecord(
            id: UUID(),
            type: .utilityPatent,
            title: "Organ Resonance Frequency Therapy System",
            description: "System combining audio frequencies and light wavelengths calibrated to organ-specific resonance frequencies for wellness and therapeutic applications, with safety monitoring and contraindication detection.",
            status: .ideation,
            jurisdictions: [.epo, .uspto, .dpma],
            inventors: ["Echoelmusic Team"],
            assignee: "Echoelmusic",
            claims: [
                "Organ-specific frequency protocol generation based on resonance characteristics.",
                "Combined audio-light therapy system with synchronized output.",
                "Safety monitoring system for frequency-based therapy applications."
            ],
            relatedArt: []
        ),

        IntellectualPropertyRecord(
            id: UUID(),
            type: .utilityPatent,
            title: "Psychosomatic Audio Parameter Mapping System",
            description: "System using polyvagal theory and psychological models to map physiological states to audio parameters, enabling therapeutic and artistic applications responsive to body-mind states.",
            status: .ideation,
            jurisdictions: [.epo, .uspto],
            inventors: ["Echoelmusic Team"],
            assignee: "Echoelmusic",
            claims: [
                "Polyvagal state detection and audio parameter correlation system.",
                "Method for psychosomatic feedback loop in audio-visual applications.",
                "Therapeutic audio generation based on autonomic nervous system state."
            ],
            relatedArt: []
        ),

        IntellectualPropertyRecord(
            id: UUID(),
            type: .utilityPatent,
            title: "3D Spatial Canvas with Bio-Reactive Brush Modulation",
            description: "Three-dimensional drawing and painting system where brush parameters are modulated in real-time by audio analysis and biometric feedback, enabling creation of living, responsive artwork.",
            status: .ideation,
            jurisdictions: [.epo, .uspto],
            inventors: ["Echoelmusic Team"],
            assignee: "Echoelmusic",
            claims: [
                "3D spatial drawing system with audio-reactive brush parameter modulation.",
                "Biofeedback-driven artistic expression in three-dimensional space.",
                "Collaborative 3D canvas with shared biometric influence."
            ],
            relatedArt: []
        ),

        IntellectualPropertyRecord(
            id: UUID(),
            type: .utilityPatent,
            title: "Impairment Detection and Safety Interlock for Remote Vehicle Control",
            description: "Safety system that detects operator impairment through multi-modal analysis and prevents operation of vehicles, drones, or other controlled systems when impairment is detected.",
            status: .ideation,
            jurisdictions: [.epo, .uspto, .dpma],
            inventors: ["Echoelmusic Team"],
            assignee: "Echoelmusic",
            claims: [
                "Multi-modal impairment detection system for remote operators.",
                "Safety interlock preventing controlled system operation during detected impairment.",
                "Graduated response system based on impairment severity level."
            ],
            relatedArt: []
        )
    ]
}

// MARK: - Compliance Manager

@MainActor
public class ComplianceManager: ObservableObject {

    @Published public var records: [ComplianceRecord] = []
    @Published public var tuvCertifications: [TUVCertification] = []
    @Published public var intellectualProperty: [IntellectualPropertyRecord] = []
    @Published public var overallComplianceScore: Float = 0

    public init() {
        initializeDefaultRecords()
    }

    private func initializeDefaultRecords() {
        // Initialize with applicable standards for Echoelmusic
        let applicableStandards: [ComplianceStandard] = [
            .iso27001,      // Information security
            .gdpr,          // Data protection
            .wcag21,        // Accessibility
            .ceMark,        // European conformity
            .iec61508,      // Functional safety (for control systems)
            .iso26262,      // Automotive (for vehicle control)
            .do178c,        // Aviation (for drone/aircraft control)
            .iec62304,      // Medical device software (for therapy features)
            .iso14971       // Medical risk management
        ]

        for standard in applicableStandards {
            let record = ComplianceRecord(
                id: UUID(),
                standard: standard,
                status: .notStarted,
                applicableModules: determineApplicableModules(for: standard),
                requirements: [],
                evidence: [],
                audits: [],
                lastUpdated: Date()
            )
            records.append(record)
        }

        // Initialize IP portfolio
        intellectualProperty = EchoelmusicPatentPortfolio.potentialPatents

        updateComplianceScore()
    }

    private func determineApplicableModules(for standard: ComplianceStandard) -> [String] {
        switch standard {
        case .iso27001, .gdpr:
            return ["All modules - Data handling"]
        case .wcag21:
            return ["UI/UX components", "Accessibility features"]
        case .iec61508, .iso26262:
            return ["SimulatorControlFramework", "SafetyGuardianSystem"]
        case .do178c:
            return ["SimulatorControlFramework (Aviation)", "DroneControl"]
        case .iec62304, .iso14971:
            return ["OrganResonanceTherapy", "MedicalIntegration"]
        default:
            return ["To be determined"]
        }
    }

    /// Calculate overall compliance score
    public func updateComplianceScore() {
        guard !records.isEmpty else {
            overallComplianceScore = 0
            return
        }

        var totalScore: Float = 0
        var applicableCount: Float = 0

        for record in records {
            if record.status != .notApplicable {
                applicableCount += 1

                switch record.status {
                case .certified:
                    totalScore += 1.0
                case .pendingCertification:
                    totalScore += 0.8
                case .underReview:
                    totalScore += 0.6
                case .inProgress:
                    totalScore += 0.4
                case .notStarted:
                    totalScore += 0.1
                case .expired, .nonCompliant:
                    totalScore += 0.0
                case .notApplicable:
                    break
                }
            }
        }

        overallComplianceScore = applicableCount > 0 ? totalScore / applicableCount : 0
    }

    /// Get status summary for dashboard
    public func getStatusSummary() -> ComplianceStatusSummary {
        var summary = ComplianceStatusSummary()

        for record in records {
            switch record.status {
            case .certified:
                summary.certified += 1
            case .inProgress, .underReview, .pendingCertification:
                summary.inProgress += 1
            case .notStarted:
                summary.notStarted += 1
            case .expired, .nonCompliant:
                summary.needsAttention += 1
            case .notApplicable:
                break
            }
        }

        return summary
    }

    /// Check upcoming certification expirations
    public func getUpcomingExpirations(within days: Int = 90) -> [ComplianceRecord] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: days, to: Date())!

        return records.filter { record in
            if let expiration = record.expirationDate {
                return expiration <= cutoffDate && record.status == .certified
            }
            return false
        }
    }

    /// Get patent renewal reminders
    public func getPatentRenewals(within days: Int = 90) -> [IntellectualPropertyRecord] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: days, to: Date())!

        return intellectualProperty.filter { ip in
            if let annuityDue = ip.annuityDue {
                return annuityDue <= cutoffDate && ip.status == .granted
            }
            return false
        }
    }

    public struct ComplianceStatusSummary {
        public var certified: Int = 0
        public var inProgress: Int = 0
        public var notStarted: Int = 0
        public var needsAttention: Int = 0

        public var total: Int {
            return certified + inProgress + notStarted + needsAttention
        }
    }
}

// MARK: - Compliance Report Generator

public struct ComplianceReportGenerator {

    /// Generate a compliance summary report
    public static func generateSummaryReport(manager: ComplianceManager) -> String {
        var report = """
        ═══════════════════════════════════════════════════════════════
        ECHOELMUSIC COMPLIANCE STATUS REPORT
        Generated: \(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .short))
        ═══════════════════════════════════════════════════════════════

        OVERALL COMPLIANCE SCORE: \(String(format: "%.1f%%", manager.overallComplianceScore * 100))

        STATUS SUMMARY
        ───────────────────────────────────────────────────────────────
        """

        let summary = manager.getStatusSummary()
        report += """

        ✓ Certified:        \(summary.certified)
        ⟳ In Progress:      \(summary.inProgress)
        ○ Not Started:      \(summary.notStarted)
        ⚠ Needs Attention:  \(summary.needsAttention)
        ───────────────────────────────────────────────────────────────
        Total Standards:    \(summary.total)


        DETAILED STATUS BY CATEGORY
        ═══════════════════════════════════════════════════════════════
        """

        // Group by category
        let grouped = Dictionary(grouping: manager.records) { $0.standard.category }

        for category in StandardCategory.allCases {
            if let categoryRecords = grouped[category] {
                report += "\n\(category.rawValue.uppercased())\n"
                report += String(repeating: "─", count: 40) + "\n"

                for record in categoryRecords {
                    let statusIcon = statusIcon(for: record.status)
                    report += "\(statusIcon) \(record.standard.rawValue): \(record.status.rawValue)\n"

                    if let certDate = record.certificationDate {
                        report += "   Certified: \(DateFormatter.localizedString(from: certDate, dateStyle: .medium, timeStyle: .none))\n"
                    }
                    if let expDate = record.expirationDate {
                        report += "   Expires: \(DateFormatter.localizedString(from: expDate, dateStyle: .medium, timeStyle: .none))\n"
                    }
                }
            }
        }

        // Intellectual Property Summary
        report += """


        INTELLECTUAL PROPERTY PORTFOLIO
        ═══════════════════════════════════════════════════════════════

        """

        for ip in manager.intellectualProperty {
            report += "• \(ip.title)\n"
            report += "  Type: \(ip.type.rawValue) | Status: \(ip.status.rawValue)\n"
            report += "  Jurisdictions: \(ip.jurisdictions.map { $0.rawValue }.joined(separator: ", "))\n\n"
        }

        report += """

        ═══════════════════════════════════════════════════════════════
        END OF REPORT
        ═══════════════════════════════════════════════════════════════
        """

        return report
    }

    private static func statusIcon(for status: ComplianceStatus) -> String {
        switch status {
        case .certified: return "✓"
        case .inProgress, .underReview, .pendingCertification: return "⟳"
        case .notStarted: return "○"
        case .expired, .nonCompliant: return "⚠"
        case .notApplicable: return "–"
        }
    }
}

// MARK: - CE Marking Requirements

public struct CEMarkingRequirements {

    public static let requiredDocumentation = [
        "Technical Documentation",
        "Declaration of Conformity (DoC)",
        "Risk Assessment",
        "User Instructions",
        "Product Labeling"
    ]

    public struct DirectiveRequirement: Identifiable {
        public var id: UUID
        public var directive: String
        public var applicableTo: String
        public var requirements: [String]
    }

    public static let applicableDirectives: [DirectiveRequirement] = [
        DirectiveRequirement(
            id: UUID(),
            directive: "2014/53/EU (RED)",
            applicableTo: "Radio equipment (WiFi, Bluetooth control)",
            requirements: [
                "Radio spectrum efficiency",
                "Electromagnetic compatibility",
                "Electrical safety",
                "Health and safety"
            ]
        ),
        DirectiveRequirement(
            id: UUID(),
            directive: "2006/42/EC (Machinery)",
            applicableTo: "Simulator control systems",
            requirements: [
                "Risk assessment",
                "Safety requirements",
                "Technical documentation",
                "Instructions"
            ]
        ),
        DirectiveRequirement(
            id: UUID(),
            directive: "2017/745 (MDR)",
            applicableTo: "Medical/therapy features",
            requirements: [
                "Clinical evaluation",
                "Quality management system",
                "Post-market surveillance",
                "Notified body assessment"
            ]
        )
    ]
}

// MARK: - Navigation and Drone Regulations

public struct NavigationRegulations {

    public enum DroneCategory: String, CaseIterable {
        case open = "Open Category"
        case specific = "Specific Category"
        case certified = "Certified Category"

        public var requirements: [String] {
            switch self {
            case .open:
                return [
                    "MTOM < 25kg",
                    "Visual line of sight",
                    "< 120m AGL",
                    "No flights over assemblies of people"
                ]
            case .specific:
                return [
                    "Operational authorization required",
                    "Risk assessment (SORA)",
                    "Remote pilot competency"
                ]
            case .certified:
                return [
                    "Type certification",
                    "Licensed remote pilot",
                    "Certified operator"
                ]
            }
        }
    }

    public struct GeofencingRequirement {
        public var zoneType: String
        public var restriction: String
        public var enforcementMethod: String
    }

    public static let geofencingZones: [GeofencingRequirement] = [
        GeofencingRequirement(
            zoneType: "Airport",
            restriction: "No-fly zone",
            enforcementMethod: "GPS geofencing with altitude limit"
        ),
        GeofencingRequirement(
            zoneType: "Military",
            restriction: "Prohibited",
            enforcementMethod: "Hard block"
        ),
        GeofencingRequirement(
            zoneType: "National Parks",
            restriction: "Authorization required",
            enforcementMethod: "Warning + logging"
        ),
        GeofencingRequirement(
            zoneType: "Urban",
            restriction: "Specific category rules",
            enforcementMethod: "Speed + altitude limits"
        )
    ]
}
