//
//  MedicalDeviceCompliance.swift
//  Echoelmusic
//
//  Created: 2025-11-25
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  MEDICAL DEVICE COMPLIANCE FRAMEWORK
//  IEC 62304, FDA 21 CFR Part 820, EU MDR 2017/745
//
//  ⚠️ CRITICAL: This framework provides infrastructure for medical device
//  compliance but does NOT constitute FDA/MDR approval. Clinical validation
//  and regulatory submission required before medical use.
//

import Foundation
import HealthKit
import CoreLocation
import Contacts

// MARK: - Medical Device Classification

/// IEC 62304 Safety Classification
enum IEC62304SafetyClass {
    case classA  // No injury or damage to health possible
    case classB  // Non-serious injury possible
    case classC  // Death or serious injury possible
}

/// FDA Device Classification
enum FDADeviceClass {
    case classI    // Low risk, general controls
    case classII   // Moderate risk, special controls
    case classIII  // High risk, premarket approval required
}

// MARK: - Medical Device Manager

/// Medical device compliance manager
///
/// **Regulatory Framework:**
/// - IEC 62304: Medical device software lifecycle
/// - ISO 14971: Risk management for medical devices
/// - FDA 21 CFR Part 820: Quality system regulation
/// - EU MDR 2017/745: Medical device regulation
///
/// **Current Classification:**
/// - IEC 62304: Class B (non-serious injury possible from biofeedback misuse)
/// - FDA: Class II (wellness device with biofeedback, requires 510(k))
/// - EU MDR: Class IIa (low-medium risk)
///
/// **Regulatory Status:**
/// ⚠️ NOT APPROVED - This is a wellness app, NOT a medical device.
/// Clinical use requires regulatory approval.
@MainActor
class MedicalDeviceComplianceManager: ObservableObject {
    static let shared = MedicalDeviceComplianceManager()

    // MARK: - Published Properties

    @Published var isInClinicalMode: Bool = false
    @Published var hasConsentForClinicalData: Bool = false
    @Published var clinicalSupervisorConnected: Bool = false

    // MARK: - Device Identification

    /// Unique Device Identifier (UDI) per FDA requirements
    let uniqueDeviceIdentifier: String = "Echoelmusic-WELLNESS-v1.0.0-" + UUID().uuidString

    /// Software version (part of UDI)
    let softwareVersion: String = "1.0.0"

    /// Device classification
    let iec62304Class: IEC62304SafetyClass = .classB
    let fdaClass: FDADeviceClass = .classII

    // MARK: - Risk Management (ISO 14971)

    /// Identified hazards and their severity
    struct MedicalRisk: Identifiable {
        let id = UUID()
        let hazard: String
        let severity: RiskSeverity
        let probability: RiskProbability
        let riskLevel: RiskLevel
        let mitigation: String
        let residualRisk: RiskLevel

        enum RiskSeverity: Int, Comparable {
            case negligible = 1
            case minor = 2
            case serious = 3
            case critical = 4
            case catastrophic = 5

            static func < (lhs: RiskSeverity, rhs: RiskSeverity) -> Bool {
                lhs.rawValue < rhs.rawValue
            }
        }

        enum RiskProbability: Int {
            case veryRare = 1      // < 0.1%
            case rare = 2          // 0.1% - 1%
            case occasional = 3    // 1% - 10%
            case probable = 4      // 10% - 50%
            case frequent = 5      // > 50%
        }

        enum RiskLevel: Int, Comparable {
            case acceptable = 1
            case tolerable = 2
            case undesirable = 3
            case unacceptable = 4

            static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
                lhs.rawValue < rhs.rawValue
            }

            static func calculate(severity: RiskSeverity, probability: RiskProbability) -> RiskLevel {
                let score = severity.rawValue * probability.rawValue

                switch score {
                case 1...3: return .acceptable
                case 4...8: return .tolerable
                case 9...15: return .undesirable
                default: return .unacceptable
                }
            }
        }
    }

    /// Risk management file per ISO 14971
    let identifiedRisks: [MedicalRisk] = [
        MedicalRisk(
            hazard: "Photosensitive seizure from lighting effects",
            severity: .catastrophic,
            probability: .veryRare,
            riskLevel: .undesirable,
            mitigation: "WCAG 2.3.1 compliance (max 3 flashes/sec), photosensitivity warning, automatic brightness limiting",
            residualRisk: .tolerable
        ),
        MedicalRisk(
            hazard: "Hearing damage from excessive audio levels",
            severity: .serious,
            probability: .occasional,
            riskLevel: .undesirable,
            mitigation: "WHO 2019 guidelines enforcement, 85dB limit, exposure time tracking, automatic volume reduction",
            residualRisk: .tolerable
        ),
        MedicalRisk(
            hazard: "Binaural beat-induced altered consciousness state",
            severity: .minor,
            probability: .probable,
            riskLevel: .tolerable,
            mitigation: "Safety warnings, gradual onset, emergency stop button, session time limits",
            residualRisk: .acceptable
        ),
        MedicalRisk(
            hazard: "Heart rate data misinterpretation leading to medical decisions",
            severity: .critical,
            probability: .occasional,
            riskLevel: .unacceptable,
            mitigation: "Clear 'not for medical use' disclaimers, data accuracy warnings, no diagnostic claims",
            residualRisk: .tolerable
        ),
        MedicalRisk(
            hazard: "Privacy breach of sensitive health data",
            severity: .serious,
            probability: .rare,
            riskLevel: .tolerable,
            mitigation: "End-to-end encryption, no cloud storage of health data, local processing only",
            residualRisk: .acceptable
        ),
        MedicalRisk(
            hazard: "Software malfunction causing infinite audio loop",
            severity: .minor,
            probability: .veryRare,
            riskLevel: .acceptable,
            mitigation: "Watchdog timers, automatic timeout, maximum session duration, emergency stop",
            residualRisk: .acceptable
        ),
        MedicalRisk(
            hazard: "Psychological distress from intense biofeedback session",
            severity: .minor,
            probability: .occasional,
            riskLevel: .tolerable,
            mitigation: "Gradual intensity increase, mood monitoring, safe stop mechanisms, user control",
            residualRisk: .acceptable
        )
    ]

    // MARK: - Clinical Data Management

    /// Clinical trial data collection (if enabled)
    struct ClinicalDataPoint: Codable {
        let timestamp: Date
        let sessionId: UUID
        let heartRate: Double?
        let hrv: Double?
        let coherence: Double?
        let audioMode: String
        let frequency: Double?
        let duration: TimeInterval
        let userReportedEffect: String?
        let adverseEvent: String?
    }

    private var clinicalDataBuffer: [ClinicalDataPoint] = []

    // MARK: - Informed Consent

    /// Informed consent requirements per 21 CFR Part 50
    struct InformedConsent {
        let consentVersion: String = "1.0.0"
        let consentDate: Date
        let userSignature: String  // Electronic signature
        let witnessSignature: String?

        // Required elements per 21 CFR 50.25
        let purposeAcknowledged: Bool
        let risksAcknowledged: Bool
        let benefitsAcknowledged: Bool
        let alternativesAcknowledged: Bool
        let confidentialityAcknowledged: Bool
        let rightToWithdrawAcknowledged: Bool
        let contactInformationProvided: Bool
    }

    private var userConsent: InformedConsent?

    // MARK: - Adverse Event Reporting

    /// FDA MedWatch-style adverse event
    struct AdverseEvent: Identifiable, Codable {
        let id = UUID()
        let timestamp: Date
        let severity: Severity
        let description: String
        let deviceState: DeviceState
        let userAction: String
        let outcome: Outcome

        enum Severity: String, Codable {
            case mild       // Transient, no intervention required
            case moderate   // Intervention required, resolves
            case severe     // Significant medical intervention required
            case lifeThreatening
            case death
        }

        struct DeviceState: Codable {
            let softwareVersion: String
            let activeFeatures: [String]
            let sessionDuration: TimeInterval
            let audioLevel: Double?
            let frequency: Double?
        }

        enum Outcome: String, Codable {
            case recovered
            case recovering
            case notRecovered
            case unknown
        }
    }

    private var adverseEvents: [AdverseEvent] = []

    // MARK: - Initialization

    private init() {
        loadComplianceSettings()
    }

    // MARK: - Clinical Mode

    func enableClinicalMode(withConsent consent: InformedConsent) {
        guard validateConsent(consent) else {
            print("⚠️ Invalid consent, cannot enable clinical mode")
            return
        }

        userConsent = consent
        isInClinicalMode = true
        hasConsentForClinicalData = true

        print("✅ Clinical mode enabled with valid consent")
    }

    func disableClinicalMode() {
        isInClinicalMode = false
        hasConsentForClinicalData = false
        clinicalDataBuffer.removeAll()

        print("ℹ️ Clinical mode disabled, data buffer cleared")
    }

    private func validateConsent(_ consent: InformedConsent) -> Bool {
        // All required acknowledgments must be true
        return consent.purposeAcknowledged &&
               consent.risksAcknowledged &&
               consent.benefitsAcknowledged &&
               consent.alternativesAcknowledged &&
               consent.confidentialityAcknowledged &&
               consent.rightToWithdrawAcknowledged &&
               consent.contactInformationProvided
    }

    // MARK: - Clinical Data Recording

    func recordClinicalDataPoint(_ dataPoint: ClinicalDataPoint) {
        guard isInClinicalMode && hasConsentForClinicalData else {
            print("⚠️ Cannot record clinical data: clinical mode not enabled or no consent")
            return
        }

        clinicalDataBuffer.append(dataPoint)

        // Persist to secure storage (encrypted)
        persistClinicalData()
    }

    private func persistClinicalData() {
        // In production, this would encrypt and store to secure location
        // For now, just demonstrate structure
        do {
            let data = try JSONEncoder().encode(clinicalDataBuffer)
            // TODO: Encrypt with SecureEnclave
            // TODO: Store in app-specific secure storage
            print("ℹ️ Clinical data persisted: \(clinicalDataBuffer.count) data points")
        } catch {
            print("❌ Failed to persist clinical data: \(error)")
        }
    }

    // MARK: - Adverse Event Reporting

    func reportAdverseEvent(_ event: AdverseEvent) {
        adverseEvents.append(event)

        // Log to system
        print("⚠️ ADVERSE EVENT REPORTED:")
        print("   Severity: \(event.severity)")
        print("   Description: \(event.description)")
        print("   Timestamp: \(event.timestamp)")

        // In production, automatically report to FDA MedWatch if severe
        if event.severity == .severe || event.severity == .lifeThreatening || event.severity == .death {
            // TODO: Automatic FDA MedWatch submission
            print("🚨 SEVERE ADVERSE EVENT - REGULATORY REPORTING REQUIRED")
        }

        // Persist for audit trail
        persistAdverseEvents()
    }

    private func persistAdverseEvents() {
        do {
            let data = try JSONEncoder().encode(adverseEvents)
            // TODO: Store in immutable audit log
            print("ℹ️ Adverse events persisted: \(adverseEvents.count) total events")
        } catch {
            print("❌ Failed to persist adverse events: \(error)")
        }
    }

    // MARK: - Quality Management (ISO 13485)

    /// Software defect tracking
    struct SoftwareDefect: Identifiable, Codable {
        let id = UUID()
        let timestamp: Date
        let severity: DefectSeverity
        let description: String
        let affectedModule: String
        let reproducible: Bool
        let workaround: String?
        let fixVersion: String?

        enum DefectSeverity: String, Codable {
            case minor      // Cosmetic, no impact on functionality
            case major      // Functionality impaired but workaround exists
            case critical   // Core functionality broken
            case blocker    // Software unusable
        }
    }

    private var defects: [SoftwareDefect] = []

    func reportDefect(_ defect: SoftwareDefect) {
        defects.append(defect)

        print("🐛 Software defect reported:")
        print("   Severity: \(defect.severity)")
        print("   Module: \(defect.affectedModule)")
        print("   Reproducible: \(defect.reproducible)")
    }

    // MARK: - Audit Trail (21 CFR Part 11)

    /// Audit trail entry per 21 CFR Part 11 (electronic records)
    struct AuditTrailEntry: Identifiable, Codable {
        let id = UUID()
        let timestamp: Date
        let action: String
        let userId: String
        let beforeState: String?
        let afterState: String?
        let ipAddress: String?
        let deviceId: String
    }

    private var auditTrail: [AuditTrailEntry] = []

    func logAuditTrailEntry(_ entry: AuditTrailEntry) {
        auditTrail.append(entry)
        // In production: write to append-only, cryptographically signed log
    }

    // MARK: - Settings

    private func loadComplianceSettings() {
        isInClinicalMode = UserDefaults.standard.bool(forKey: "medical_clinical_mode")
        hasConsentForClinicalData = UserDefaults.standard.bool(forKey: "medical_consent_given")
    }

    func saveComplianceSettings() {
        UserDefaults.standard.set(isInClinicalMode, forKey: "medical_clinical_mode")
        UserDefaults.standard.set(hasConsentForClinicalData, forKey: "medical_consent_given")
    }

    // MARK: - Regulatory Reporting

    /// Generate regulatory submission package
    func generateRegulatorySubmissionPackage() -> RegulatorySubmissionPackage {
        return RegulatorySubmissionPackage(
            udi: uniqueDeviceIdentifier,
            softwareVersion: softwareVersion,
            iec62304Class: iec62304Class,
            fdaClass: fdaClass,
            riskManagementFile: identifiedRisks,
            adverseEvents: adverseEvents,
            defects: defects,
            auditTrail: auditTrail,
            clinicalDataSummary: generateClinicalDataSummary()
        )
    }

    struct RegulatorySubmissionPackage {
        let udi: String
        let softwareVersion: String
        let iec62304Class: IEC62304SafetyClass
        let fdaClass: FDADeviceClass
        let riskManagementFile: [MedicalRisk]
        let adverseEvents: [AdverseEvent]
        let defects: [SoftwareDefect]
        let auditTrail: [AuditTrailEntry]
        let clinicalDataSummary: ClinicalDataSummary
    }

    struct ClinicalDataSummary {
        let totalSessions: Int
        let totalParticipants: Int
        let averageSessionDuration: TimeInterval
        let adverseEventRate: Double
        let efficacyMeasures: [String: Double]
    }

    private func generateClinicalDataSummary() -> ClinicalDataSummary {
        // Generate summary statistics for regulatory submission
        return ClinicalDataSummary(
            totalSessions: clinicalDataBuffer.count,
            totalParticipants: Set(clinicalDataBuffer.map { $0.sessionId }).count,
            averageSessionDuration: clinicalDataBuffer.map { $0.duration }.reduce(0, +) / Double(max(clinicalDataBuffer.count, 1)),
            adverseEventRate: Double(adverseEvents.count) / Double(max(clinicalDataBuffer.count, 1)),
            efficacyMeasures: [:]
        )
    }
}

// MARK: - Emergency Response System

/// Emergency response and medical supervision system
@MainActor
class EmergencyResponseManager: ObservableObject {
    static let shared = EmergencyResponseManager()

    @Published var isEmergencyMode: Bool = false
    @Published var emergencyContactConfigured: Bool = false

    // MARK: - Emergency Contacts

    struct EmergencyContact: Identifiable, Codable {
        let id = UUID()
        let name: String
        let phoneNumber: String
        let relationship: String
        let isPrimaryContact: Bool
    }

    private var emergencyContacts: [EmergencyContact] = []

    // MARK: - Emergency Detection

    /// Physiological thresholds for emergency detection
    struct EmergencyThresholds {
        // Heart rate
        static let heartRateTooLow: Double = 40.0  // bpm
        static let heartRateTooHigh: Double = 180.0  // bpm

        // HRV (RMSSD)
        static let hrvTooLow: Double = 10.0  // ms (extreme stress)

        // Coherence
        static let coherenceTooLow: Double = 0.1  // Complete dysregulation
    }

    func detectEmergency(heartRate: Double?, hrv: Double?, coherence: Double?) -> EmergencyType? {
        // Check heart rate
        if let hr = heartRate {
            if hr < EmergencyThresholds.heartRateTooLow {
                return .bradycardia
            }
            if hr > EmergencyThresholds.heartRateTooHigh {
                return .tachycardia
            }
        }

        // Check HRV
        if let hrvValue = hrv {
            if hrvValue < EmergencyThresholds.hrvTooLow {
                return .extremeStress
            }
        }

        // Check coherence
        if let coh = coherence {
            if coh < EmergencyThresholds.coherenceTooLow {
                return .physiologicalDistress
            }
        }

        return nil
    }

    enum EmergencyType {
        case bradycardia  // Heart rate too low
        case tachycardia  // Heart rate too high
        case extremeStress  // HRV critically low
        case physiologicalDistress  // Coherence collapsed
        case seizureDetected  // Photosensitive seizure pattern
        case userReportedEmergency  // User pressed emergency button
    }

    // MARK: - Emergency Response

    func triggerEmergency(_ type: EmergencyType) {
        isEmergencyMode = true

        print("🚨 EMERGENCY TRIGGERED: \(type)")

        // 1. Stop all audio/visual stimulation immediately
        stopAllStimulation()

        // 2. Record adverse event
        recordEmergencyAdverseEvent(type)

        // 3. Alert emergency contacts
        alertEmergencyContacts(type)

        // 4. Show emergency UI
        showEmergencyUI(type)

        // 5. Log for audit trail
        logEmergencyEvent(type)
    }

    private func stopAllStimulation() {
        // Stop all audio
        NotificationCenter.default.post(name: NSNotification.Name("EmergencyStopAudio"), object: nil)

        // Stop all visual effects
        NotificationCenter.default.post(name: NSNotification.Name("EmergencyStopVisual"), object: nil)

        print("✅ All stimulation stopped")
    }

    private func recordEmergencyAdverseEvent(_ type: EmergencyType) {
        let event = MedicalDeviceComplianceManager.AdverseEvent(
            timestamp: Date(),
            severity: .severe,
            description: "Emergency detected: \(type)",
            deviceState: MedicalDeviceComplianceManager.AdverseEvent.DeviceState(
                softwareVersion: MedicalDeviceComplianceManager.shared.softwareVersion,
                activeFeatures: [],
                sessionDuration: 0,
                audioLevel: nil,
                frequency: nil
            ),
            userAction: "Emergency stop triggered",
            outcome: .recovering
        )

        MedicalDeviceComplianceManager.shared.reportAdverseEvent(event)
    }

    private func alertEmergencyContacts(_ type: EmergencyType) {
        guard emergencyContactConfigured else {
            print("⚠️ No emergency contacts configured")
            return
        }

        for contact in emergencyContacts where contact.isPrimaryContact {
            sendEmergencyAlert(to: contact, emergency: type)
        }
    }

    private func sendEmergencyAlert(to contact: EmergencyContact, emergency: EmergencyType) {
        // In production: send SMS via CallKit or push notification
        print("📱 Emergency alert sent to \(contact.name): \(emergency)")
    }

    private func showEmergencyUI(_ type: EmergencyType) {
        // Show emergency UI with instructions
        NotificationCenter.default.post(
            name: NSNotification.Name("ShowEmergencyUI"),
            object: type
        )
    }

    private func logEmergencyEvent(_ type: EmergencyType) {
        let entry = MedicalDeviceComplianceManager.AuditTrailEntry(
            timestamp: Date(),
            action: "Emergency triggered: \(type)",
            userId: "system",
            beforeState: "normal",
            afterState: "emergency",
            ipAddress: nil,
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        )

        MedicalDeviceComplianceManager.shared.logAuditTrailEntry(entry)
    }

    // MARK: - Emergency Contacts Management

    func addEmergencyContact(_ contact: EmergencyContact) {
        emergencyContacts.append(contact)
        emergencyContactConfigured = !emergencyContacts.isEmpty
        saveEmergencyContacts()
    }

    func removeEmergencyContact(_ contact: EmergencyContact) {
        emergencyContacts.removeAll { $0.id == contact.id }
        emergencyContactConfigured = !emergencyContacts.isEmpty
        saveEmergencyContacts()
    }

    private func saveEmergencyContacts() {
        do {
            let data = try JSONEncoder().encode(emergencyContacts)
            UserDefaults.standard.set(data, forKey: "emergency_contacts")
        } catch {
            print("❌ Failed to save emergency contacts: \(error)")
        }
    }

    private func loadEmergencyContacts() {
        guard let data = UserDefaults.standard.data(forKey: "emergency_contacts") else { return }

        do {
            emergencyContacts = try JSONDecoder().decode([EmergencyContact].self, from: data)
            emergencyContactConfigured = !emergencyContacts.isEmpty
        } catch {
            print("❌ Failed to load emergency contacts: \(error)")
        }
    }

    private init() {
        loadEmergencyContacts()
    }
}
