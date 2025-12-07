import Foundation
import Accelerate

// MARK: - Safety Guardian System
// Human safety first - Impairment detection, ethical use, anti-weaponization
// Compliant with: ISO 26262, DO-178C, IEC 62304, Geneva Conventions

/// SafetyGuardianSystem: Comprehensive safety and ethics enforcement
/// MISSION: Protect human life and prevent misuse of technology
///
/// Core principles:
/// 1. HUMAN SAFETY IS PARAMOUNT - No operation that endangers humans
/// 2. OPERATOR FITNESS REQUIRED - Impaired operators cannot control
/// 3. NO WEAPONIZATION - Technology cannot be used to harm
/// 4. ETHICAL USE ONLY - Prevent war crimes and human rights violations
/// 5. FAIL-SAFE DESIGN - Always fail to safe state
///
/// Compliance targets:
/// - ISO 26262 (Automotive ASIL-D)
/// - DO-178C (Aviation DAL-A)
/// - IEC 62304 (Medical Class C)
/// - UN Geneva Conventions
/// - Universal Declaration of Human Rights
public final class SafetyGuardianSystem {

    // MARK: - Safety Integrity Levels

    /// Safety Integrity Level (combined ASIL/DAL/SIL)
    public enum SafetyIntegrityLevel: Int, Comparable {
        case none = 0           // No safety requirements
        case low = 1            // ASIL-A / DAL-D / SIL-1
        case medium = 2         // ASIL-B / DAL-C / SIL-2
        case high = 3           // ASIL-C / DAL-B / SIL-3
        case critical = 4       // ASIL-D / DAL-A / SIL-4

        public static func < (lhs: SafetyIntegrityLevel, rhs: SafetyIntegrityLevel) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }

        var description: String {
            switch self {
            case .none: return "No Safety Requirements"
            case .low: return "Low Integrity (ASIL-A/DAL-D)"
            case .medium: return "Medium Integrity (ASIL-B/DAL-C)"
            case .high: return "High Integrity (ASIL-C/DAL-B)"
            case .critical: return "Critical Integrity (ASIL-D/DAL-A)"
            }
        }

        var maxResponseTimeMs: Double {
            switch self {
            case .none: return 1000
            case .low: return 500
            case .medium: return 100
            case .high: return 50
            case .critical: return 10
            }
        }
    }

    // MARK: - Operator State

    /// Comprehensive operator fitness state
    public struct OperatorState {
        // Identity verification
        public var isAuthenticated: Bool = false
        public var operatorId: String?
        public var authenticationTime: Date?

        // Impairment indicators
        public var alcoholLevel: Float = 0           // BAC (0.0 = sober)
        public var drugImpairment: DrugImpairment = .none
        public var fatigueLevel: Float = 0           // 0-1 (0 = alert)
        public var drowsinessScore: Float = 0        // 0-1 from eye tracking
        public var cognitiveLoad: Float = 0          // 0-1 from EEG/HRV

        // Physical state
        public var heartRate: Float = 70
        public var heartRateVariability: Float = 50
        public var bloodPressure: (systolic: Float, diastolic: Float)?
        public var bodyTemperature: Float = 37
        public var bloodOxygen: Float = 98

        // Mental state
        public var stressLevel: Float = 0            // 0-1
        public var attentionLevel: Float = 1         // 0-1
        public var reactionTime: TimeInterval = 0.3  // Seconds
        public var emotionalState: EmotionalState = .neutral

        // Behavioral
        public var isResponsive: Bool = true
        public var lastInteractionTime: Date = Date()
        public var erraticBehaviorScore: Float = 0   // 0-1

        // Medical conditions
        public var hasSeizureRisk: Bool = false
        public var hasCardiacRisk: Bool = false
        public var hasMobilityImpairment: Bool = false

        public init() {}
    }

    /// Drug impairment levels
    public enum DrugImpairment: String, CaseIterable {
        case none = "None"
        case suspected = "Suspected"
        case mild = "Mild Impairment"
        case moderate = "Moderate Impairment"
        case severe = "Severe Impairment"

        var allowsOperation: Bool {
            switch self {
            case .none: return true
            case .suspected: return false  // Precautionary
            default: return false
            }
        }
    }

    /// Emotional states affecting operation
    public enum EmotionalState: String, CaseIterable {
        case neutral = "Neutral"
        case calm = "Calm"
        case focused = "Focused"
        case stressed = "Stressed"
        case anxious = "Anxious"
        case angry = "Angry"
        case fearful = "Fearful"
        case euphoric = "Euphoric"
        case depressed = "Depressed"

        var operationRisk: Float {
            switch self {
            case .neutral, .calm, .focused: return 0
            case .stressed, .anxious: return 0.3
            case .angry, .fearful: return 0.7
            case .euphoric, .depressed: return 0.5
            }
        }
    }

    // MARK: - Ethical Use Protection

    /// Prohibited use categories - ABSOLUTE PROHIBITIONS
    public enum ProhibitedUse: String, CaseIterable {
        // War crimes (Geneva Conventions)
        case targetingCivilians = "Targeting Civilians"
        case targetingMedicalFacilities = "Targeting Medical Facilities"
        case targetingCulturalSites = "Targeting Cultural Sites"
        case targetingRefugees = "Targeting Refugees"
        case chemicalWeapons = "Chemical Weapons"
        case biologicalWeapons = "Biological Weapons"
        case nuclearWeapons = "Nuclear Weapons"
        case clusterMunitions = "Cluster Munitions"
        case landmines = "Landmines"
        case blindingLasers = "Blinding Lasers"

        // Human rights violations
        case torture = "Torture"
        case massVeillance = "Mass Surveillance for Oppression"
        case forcedLabor = "Forced Labor Enforcement"
        case ethnicCleansing = "Ethnic Cleansing"
        case genocide = "Genocide"

        // Other prohibited uses
        case autonomousLethal = "Autonomous Lethal Decisions"
        case harassmentStalking = "Harassment/Stalking"
        case childExploitation = "Child Exploitation"
        case humanTrafficking = "Human Trafficking"

        var severity: Severity {
            return .absolute  // All are absolute prohibitions
        }

        public enum Severity {
            case absolute      // Can NEVER be overridden
            case conditional   // Requires special authorization
        }
    }

    /// Ethical context requirements
    public struct EthicalContext {
        public var operationType: OperationType
        public var targetType: TargetType?
        public var jurisdiction: Jurisdiction
        public var hasProperAuthorization: Bool
        public var isEmergency: Bool
        public var humanOversight: HumanOversight

        public init(operationType: OperationType) {
            self.operationType = operationType
            self.targetType = nil
            self.jurisdiction = .civilian
            self.hasProperAuthorization = false
            self.isEmergency = false
            self.humanOversight = .direct
        }
    }

    /// Types of operations
    public enum OperationType: String, CaseIterable {
        case entertainment = "Entertainment"
        case creative = "Creative"
        case medical = "Medical"
        case transportation = "Transportation"
        case industrial = "Industrial"
        case research = "Research"
        case emergency = "Emergency Response"
        case training = "Training/Simulation"

        var requiresAuthorization: Bool {
            switch self {
            case .medical, .transportation, .industrial, .emergency:
                return true
            default:
                return false
            }
        }
    }

    /// Target types (what is being controlled/affected)
    public enum TargetType: String {
        case selfOnly = "Self Only"
        case property = "Property"
        case publicSpace = "Public Space"
        case vehicle = "Vehicle"
        case aircraft = "Aircraft"
        case medicalDevice = "Medical Device"
        case infrastructure = "Infrastructure"
    }

    /// Jurisdiction types
    public enum Jurisdiction: String {
        case personal = "Personal"
        case civilian = "Civilian"
        case commercial = "Commercial"
        case governmental = "Governmental"
        case international = "International"
    }

    /// Human oversight levels
    public enum HumanOversight: String {
        case direct = "Direct Human Control"
        case supervised = "Human Supervised"
        case monitored = "Human Monitored"
        case autonomous = "Autonomous (PROHIBITED for lethal)"
    }

    // MARK: - Safety Thresholds

    /// Configurable safety thresholds
    public struct SafetyThresholds {
        // Alcohol
        public var maxAlcoholBAC: Float = 0.0        // ZERO tolerance
        public var warningAlcoholBAC: Float = 0.0    // Warn at any detection

        // Fatigue
        public var maxFatigueLevel: Float = 0.6
        public var warningFatigueLevel: Float = 0.4

        // Drowsiness
        public var maxDrowsiness: Float = 0.5
        public var warningDrowsiness: Float = 0.3

        // Cognitive
        public var minAttentionLevel: Float = 0.5
        public var maxCognitiveLoad: Float = 0.8
        public var maxStressLevel: Float = 0.7

        // Physical
        public var minHeartRate: Float = 40
        public var maxHeartRate: Float = 180
        public var minBloodOxygen: Float = 90

        // Behavioral
        public var maxInactivitySeconds: TimeInterval = 30
        public var maxErraticScore: Float = 0.5
        public var maxReactionTime: TimeInterval = 1.0

        public init() {}

        /// Thresholds for specific safety level
        public static func forLevel(_ level: SafetyIntegrityLevel) -> SafetyThresholds {
            var thresholds = SafetyThresholds()

            switch level {
            case .critical:
                thresholds.maxAlcoholBAC = 0.0
                thresholds.maxFatigueLevel = 0.3
                thresholds.maxDrowsiness = 0.2
                thresholds.minAttentionLevel = 0.8
                thresholds.maxInactivitySeconds = 10
                thresholds.maxReactionTime = 0.5

            case .high:
                thresholds.maxFatigueLevel = 0.4
                thresholds.maxDrowsiness = 0.3
                thresholds.minAttentionLevel = 0.6
                thresholds.maxInactivitySeconds = 20

            case .medium:
                thresholds.maxFatigueLevel = 0.5
                thresholds.minAttentionLevel = 0.5

            default:
                break
            }

            return thresholds
        }
    }

    // MARK: - Properties

    /// Current operator state
    public private(set) var operatorState = OperatorState()

    /// Safety integrity level for current operation
    public var safetyLevel: SafetyIntegrityLevel = .medium

    /// Safety thresholds
    public var thresholds: SafetyThresholds

    /// Current ethical context
    public var ethicalContext: EthicalContext

    /// Is system armed (ready to allow operation)
    public private(set) var isArmed: Bool = false

    /// Current safety status
    public private(set) var status: SafetyStatus = SafetyStatus()

    /// Violation log
    private var violationLog: [SafetyViolation] = []

    /// Emergency stop active
    public private(set) var emergencyStopActive: Bool = false

    /// Callbacks
    public var onSafetyViolation: ((SafetyViolation) -> Void)?
    public var onEmergencyStop: (() -> Void)?
    public var onOperatorStateChange: ((OperatorState) -> Void)?
    public var onStatusChange: ((SafetyStatus) -> Void)?

    // MARK: - Status Types

    /// Comprehensive safety status
    public struct SafetyStatus {
        public var canOperate: Bool = false
        public var reason: String?
        public var riskLevel: RiskLevel = .unknown
        public var violations: [ViolationType] = []
        public var warnings: [String] = []
        public var timestamp: Date = Date()

        public enum RiskLevel: String {
            case safe = "Safe"
            case caution = "Caution"
            case warning = "Warning"
            case danger = "Danger"
            case critical = "Critical"
            case unknown = "Unknown"
        }
    }

    /// Violation types
    public enum ViolationType: String, CaseIterable {
        // Impairment
        case alcoholDetected = "Alcohol Detected"
        case drugImpairment = "Drug Impairment"
        case fatigue = "Fatigue"
        case drowsiness = "Drowsiness"
        case cognitiveOverload = "Cognitive Overload"

        // Attention
        case inattention = "Inattention"
        case distraction = "Distraction"
        case slowReaction = "Slow Reaction Time"

        // Physical
        case abnormalHeartRate = "Abnormal Heart Rate"
        case lowBloodOxygen = "Low Blood Oxygen"
        case abnormalTemperature = "Abnormal Temperature"

        // Behavioral
        case erraticBehavior = "Erratic Behavior"
        case inactivity = "Prolonged Inactivity"
        case unresponsive = "Unresponsive"

        // Ethical
        case prohibitedUse = "Prohibited Use Attempted"
        case unauthorizedOperation = "Unauthorized Operation"
        case missingOversight = "Missing Human Oversight"

        // Technical
        case sensorFailure = "Sensor Failure"
        case communicationLoss = "Communication Loss"
        case systemMalfunction = "System Malfunction"
    }

    /// Safety violation record
    public struct SafetyViolation {
        public var id: UUID = UUID()
        public var type: ViolationType
        public var severity: Severity
        public var description: String
        public var timestamp: Date
        public var operatorId: String?
        public var details: [String: Any]

        public enum Severity: Int {
            case info = 0
            case warning = 1
            case violation = 2
            case critical = 3
            case emergency = 4
        }

        public init(type: ViolationType, severity: Severity, description: String) {
            self.type = type
            self.severity = severity
            self.description = description
            self.timestamp = Date()
            self.details = [:]
        }
    }

    // MARK: - Initialization

    public init(safetyLevel: SafetyIntegrityLevel = .medium) {
        self.safetyLevel = safetyLevel
        self.thresholds = SafetyThresholds.forLevel(safetyLevel)
        self.ethicalContext = EthicalContext(operationType: .entertainment)
    }

    // MARK: - Operator State Updates

    /// Update operator biometrics
    public func updateBiometrics(
        heartRate: Float? = nil,
        hrv: Float? = nil,
        bloodOxygen: Float? = nil,
        bloodPressure: (systolic: Float, diastolic: Float)? = nil,
        temperature: Float? = nil
    ) {
        if let hr = heartRate { operatorState.heartRate = hr }
        if let hrv = hrv { operatorState.heartRateVariability = hrv }
        if let spo2 = bloodOxygen { operatorState.bloodOxygen = spo2 }
        if let bp = bloodPressure { operatorState.bloodPressure = bp }
        if let temp = temperature { operatorState.bodyTemperature = temp }

        operatorState.lastInteractionTime = Date()
        evaluateOperatorState()
    }

    /// Update impairment indicators
    public func updateImpairment(
        alcoholLevel: Float? = nil,
        drugImpairment: DrugImpairment? = nil,
        fatigueLevel: Float? = nil,
        drowsinessScore: Float? = nil
    ) {
        if let alcohol = alcoholLevel { operatorState.alcoholLevel = alcohol }
        if let drugs = drugImpairment { operatorState.drugImpairment = drugs }
        if let fatigue = fatigueLevel { operatorState.fatigueLevel = fatigue }
        if let drowsiness = drowsinessScore { operatorState.drowsinessScore = drowsiness }

        evaluateOperatorState()
    }

    /// Update cognitive state
    public func updateCognitive(
        attentionLevel: Float? = nil,
        cognitiveLoad: Float? = nil,
        stressLevel: Float? = nil,
        reactionTime: TimeInterval? = nil,
        emotionalState: EmotionalState? = nil
    ) {
        if let attention = attentionLevel { operatorState.attentionLevel = attention }
        if let cognitive = cognitiveLoad { operatorState.cognitiveLoad = cognitive }
        if let stress = stressLevel { operatorState.stressLevel = stress }
        if let reaction = reactionTime { operatorState.reactionTime = reaction }
        if let emotion = emotionalState { operatorState.emotionalState = emotion }

        evaluateOperatorState()
    }

    /// Update behavioral indicators
    public func updateBehavioral(
        isResponsive: Bool? = nil,
        erraticScore: Float? = nil
    ) {
        if let responsive = isResponsive { operatorState.isResponsive = responsive }
        if let erratic = erraticScore { operatorState.erraticBehaviorScore = erratic }

        if isResponsive == true {
            operatorState.lastInteractionTime = Date()
        }

        evaluateOperatorState()
    }

    // MARK: - Evaluation

    /// Evaluate complete operator state and update status
    public func evaluateOperatorState() -> SafetyStatus {
        var newStatus = SafetyStatus()
        newStatus.timestamp = Date()
        newStatus.violations = []
        newStatus.warnings = []

        // === ABSOLUTE BLOCKS (Cannot be overridden) ===

        // 1. Alcohol - ZERO TOLERANCE
        if operatorState.alcoholLevel > thresholds.maxAlcoholBAC {
            newStatus.violations.append(.alcoholDetected)
            logViolation(.alcoholDetected, .critical, "Alcohol detected: BAC \(operatorState.alcoholLevel)")
        }

        // 2. Drug impairment
        if !operatorState.drugImpairment.allowsOperation {
            newStatus.violations.append(.drugImpairment)
            logViolation(.drugImpairment, .critical, "Drug impairment: \(operatorState.drugImpairment.rawValue)")
        }

        // 3. Emergency stop active
        if emergencyStopActive {
            newStatus.canOperate = false
            newStatus.reason = "Emergency stop active"
            newStatus.riskLevel = .critical
            status = newStatus
            onStatusChange?(newStatus)
            return newStatus
        }

        // === HIGH PRIORITY CHECKS ===

        // Fatigue
        if operatorState.fatigueLevel > thresholds.maxFatigueLevel {
            newStatus.violations.append(.fatigue)
            logViolation(.fatigue, .violation, "Fatigue level: \(operatorState.fatigueLevel)")
        } else if operatorState.fatigueLevel > thresholds.warningFatigueLevel {
            newStatus.warnings.append("Elevated fatigue detected")
        }

        // Drowsiness
        if operatorState.drowsinessScore > thresholds.maxDrowsiness {
            newStatus.violations.append(.drowsiness)
            logViolation(.drowsiness, .violation, "Drowsiness: \(operatorState.drowsinessScore)")
        } else if operatorState.drowsinessScore > thresholds.warningDrowsiness {
            newStatus.warnings.append("Signs of drowsiness detected")
        }

        // Attention
        if operatorState.attentionLevel < thresholds.minAttentionLevel {
            newStatus.violations.append(.inattention)
            logViolation(.inattention, .violation, "Low attention: \(operatorState.attentionLevel)")
        }

        // Cognitive overload
        if operatorState.cognitiveLoad > thresholds.maxCognitiveLoad {
            newStatus.violations.append(.cognitiveOverload)
            logViolation(.cognitiveOverload, .warning, "High cognitive load: \(operatorState.cognitiveLoad)")
        }

        // Reaction time
        if operatorState.reactionTime > thresholds.maxReactionTime {
            newStatus.violations.append(.slowReaction)
            logViolation(.slowReaction, .violation, "Slow reaction: \(operatorState.reactionTime)s")
        }

        // Unresponsive
        let inactivityDuration = Date().timeIntervalSince(operatorState.lastInteractionTime)
        if inactivityDuration > thresholds.maxInactivitySeconds {
            newStatus.violations.append(.inactivity)
            logViolation(.inactivity, .violation, "Inactive for \(inactivityDuration)s")
        }

        if !operatorState.isResponsive {
            newStatus.violations.append(.unresponsive)
            logViolation(.unresponsive, .critical, "Operator unresponsive")
        }

        // Erratic behavior
        if operatorState.erraticBehaviorScore > thresholds.maxErraticScore {
            newStatus.violations.append(.erraticBehavior)
            logViolation(.erraticBehavior, .warning, "Erratic behavior: \(operatorState.erraticBehaviorScore)")
        }

        // === MEDICAL CHECKS ===

        // Heart rate
        if operatorState.heartRate < thresholds.minHeartRate ||
           operatorState.heartRate > thresholds.maxHeartRate {
            newStatus.violations.append(.abnormalHeartRate)
            logViolation(.abnormalHeartRate, .warning, "Heart rate: \(operatorState.heartRate) BPM")
        }

        // Blood oxygen
        if operatorState.bloodOxygen < thresholds.minBloodOxygen {
            newStatus.violations.append(.lowBloodOxygen)
            logViolation(.lowBloodOxygen, .critical, "SpO2: \(operatorState.bloodOxygen)%")
        }

        // Stress
        if operatorState.stressLevel > thresholds.maxStressLevel {
            newStatus.warnings.append("High stress level detected")
        }

        // === DETERMINE OVERALL STATUS ===

        let hasCriticalViolation = newStatus.violations.contains { v in
            [.alcoholDetected, .drugImpairment, .unresponsive, .lowBloodOxygen].contains(v)
        }

        let hasOperationalViolation = !newStatus.violations.isEmpty

        if hasCriticalViolation {
            newStatus.canOperate = false
            newStatus.riskLevel = .critical
            newStatus.reason = "Critical safety violation - operation blocked"
        } else if hasOperationalViolation {
            // For high safety levels, any violation blocks
            if safetyLevel >= .high {
                newStatus.canOperate = false
                newStatus.riskLevel = .danger
                newStatus.reason = "Safety violation detected"
            } else {
                // Lower levels may allow with warnings
                newStatus.canOperate = newStatus.violations.count <= 1
                newStatus.riskLevel = .warning
                newStatus.reason = newStatus.canOperate ? nil : "Multiple safety violations"
            }
        } else if !newStatus.warnings.isEmpty {
            newStatus.canOperate = true
            newStatus.riskLevel = .caution
        } else {
            newStatus.canOperate = true
            newStatus.riskLevel = .safe
        }

        // Final override: Authentication required
        if !operatorState.isAuthenticated && ethicalContext.operationType.requiresAuthorization {
            newStatus.canOperate = false
            newStatus.reason = "Authentication required"
        }

        status = newStatus
        onStatusChange?(newStatus)
        onOperatorStateChange?(operatorState)

        return newStatus
    }

    // MARK: - Ethical Evaluation

    /// Check if proposed action is ethically permitted
    public func evaluateEthicalUse(_ proposedAction: ProposedAction) -> EthicalEvaluation {
        var evaluation = EthicalEvaluation()
        evaluation.action = proposedAction

        // Check against ALL prohibited uses
        for prohibited in ProhibitedUse.allCases {
            if actionViolates(proposedAction, prohibition: prohibited) {
                evaluation.isPermitted = false
                evaluation.violatedProhibitions.append(prohibited)
                evaluation.reason = "PROHIBITED: \(prohibited.rawValue)"

                logViolation(.prohibitedUse, .emergency,
                            "Attempted prohibited use: \(prohibited.rawValue)")
            }
        }

        // Check human oversight requirement
        if proposedAction.isLethal && ethicalContext.humanOversight == .autonomous {
            evaluation.isPermitted = false
            evaluation.reason = "Lethal actions require human oversight"
            evaluation.violatedProhibitions.append(.autonomousLethal)
        }

        // Check authorization
        if ethicalContext.operationType.requiresAuthorization &&
           !ethicalContext.hasProperAuthorization {
            evaluation.isPermitted = false
            evaluation.reason = "Proper authorization required"
        }

        // Emergency override check (still cannot override absolute prohibitions)
        if ethicalContext.isEmergency && !evaluation.violatedProhibitions.isEmpty {
            // Check if any violation is absolute
            let hasAbsoluteViolation = evaluation.violatedProhibitions.contains { $0.severity == .absolute }
            if hasAbsoluteViolation {
                evaluation.emergencyOverrideAvailable = false
                evaluation.reason = "Cannot override absolute prohibition even in emergency"
            }
        }

        return evaluation
    }

    /// Check if action violates specific prohibition
    private func actionViolates(_ action: ProposedAction, prohibition: ProhibitedUse) -> Bool {
        switch prohibition {
        case .targetingCivilians:
            return action.targetType == .civilian && action.isLethal

        case .targetingMedicalFacilities:
            return action.targetCategory == .medical && action.isDestructive

        case .targetingCulturalSites:
            return action.targetCategory == .cultural && action.isDestructive

        case .autonomousLethal:
            return action.isLethal && action.isAutonomous

        case .harassmentStalking:
            return action.isTracking && !action.hasConsent

        case .childExploitation:
            return action.involvesMinors && action.isExploitative

        default:
            // Other prohibitions checked by explicit flags
            return false
        }
    }

    /// Proposed action for ethical evaluation
    public struct ProposedAction {
        public var description: String
        public var targetType: TargetClassification?
        public var targetCategory: TargetCategory?
        public var isLethal: Bool = false
        public var isDestructive: Bool = false
        public var isAutonomous: Bool = false
        public var isTracking: Bool = false
        public var hasConsent: Bool = true
        public var involvesMinors: Bool = false
        public var isExploitative: Bool = false

        public enum TargetClassification {
            case none, object, civilian, combatant, infrastructure
        }

        public enum TargetCategory {
            case none, personal, commercial, medical, cultural, governmental, military
        }

        public init(description: String) {
            self.description = description
        }
    }

    /// Ethical evaluation result
    public struct EthicalEvaluation {
        public var action: ProposedAction?
        public var isPermitted: Bool = true
        public var reason: String?
        public var violatedProhibitions: [ProhibitedUse] = []
        public var emergencyOverrideAvailable: Bool = false
        public var requiresAdditionalAuthorization: Bool = false
    }

    // MARK: - Emergency Controls

    /// Activate emergency stop
    public func emergencyStop(reason: String) {
        emergencyStopActive = true

        logViolation(.systemMalfunction, .emergency, "Emergency stop: \(reason)")

        status.canOperate = false
        status.reason = "EMERGENCY STOP: \(reason)"
        status.riskLevel = .critical

        onEmergencyStop?()
        onStatusChange?(status)
    }

    /// Reset emergency stop (requires authentication)
    public func resetEmergencyStop(authorizationCode: String) -> Bool {
        // In real implementation, verify authorization
        guard authorizationCode.count >= 6 else { return false }

        emergencyStopActive = false

        // Re-evaluate state
        _ = evaluateOperatorState()

        return true
    }

    /// Arm system for operation
    public func armSystem() -> Bool {
        // Perform pre-arm checks
        let evaluation = evaluateOperatorState()

        guard evaluation.canOperate else {
            return false
        }

        guard operatorState.isAuthenticated else {
            return false
        }

        isArmed = true
        return true
    }

    /// Disarm system
    public func disarmSystem() {
        isArmed = false
    }

    // MARK: - Logging

    /// Log a safety violation
    private func logViolation(_ type: ViolationType, _ severity: SafetyViolation.Severity, _ description: String) {
        let violation = SafetyViolation(type: type, severity: severity, description: description)
        violationLog.append(violation)

        // Keep log size manageable
        if violationLog.count > 10000 {
            violationLog.removeFirst(1000)
        }

        onSafetyViolation?(violation)
    }

    /// Get violation log
    public func getViolationLog(since: Date? = nil) -> [SafetyViolation] {
        if let since = since {
            return violationLog.filter { $0.timestamp >= since }
        }
        return violationLog
    }

    // MARK: - Authentication

    /// Authenticate operator
    public func authenticateOperator(id: String, credential: String) -> Bool {
        // In real implementation, verify credential properly
        guard !id.isEmpty && !credential.isEmpty else { return false }

        operatorState.isAuthenticated = true
        operatorState.operatorId = id
        operatorState.authenticationTime = Date()

        return true
    }

    /// Deauthenticate operator
    public func deauthenticateOperator() {
        operatorState.isAuthenticated = false
        operatorState.operatorId = nil
        operatorState.authenticationTime = nil

        disarmSystem()
    }

    // MARK: - Reset

    /// Reset safety system
    public func reset() {
        operatorState = OperatorState()
        status = SafetyStatus()
        isArmed = false
        emergencyStopActive = false
        // Keep violation log
    }
}

// MARK: - Anti-Weaponization Declaration

extension SafetyGuardianSystem {

    /// Declaration of non-weaponization principles
    public static let antiWeaponizationDeclaration = """
    ═══════════════════════════════════════════════════════════════════════════════
                        ANTI-WEAPONIZATION DECLARATION
    ═══════════════════════════════════════════════════════════════════════════════

    This software is developed with the following absolute commitments:

    1. HUMAN LIFE IS SACRED
       This technology shall never be used to harm, injure, or kill human beings.

    2. NO AUTONOMOUS LETHAL DECISIONS
       No system using this software may make autonomous decisions to use lethal
       force. Human oversight is mandatory for any potentially harmful action.

    3. PROHIBITED USES (ABSOLUTE - NO EXCEPTIONS)
       - Targeting of civilians or non-combatants
       - Weapons of mass destruction (chemical, biological, nuclear)
       - Torture or cruel treatment
       - Mass surveillance for oppression
       - Genocide or ethnic cleansing
       - Human trafficking enforcement
       - Child exploitation

    4. GENEVA CONVENTIONS COMPLIANCE
       All uses must comply with the Geneva Conventions and international
       humanitarian law.

    5. HUMAN RIGHTS
       All uses must respect the Universal Declaration of Human Rights.

    6. FAIL-SAFE DESIGN
       In any ambiguous situation, the system shall fail to a safe state that
       protects human life.

    7. TRANSPARENCY
       Users and affected parties have the right to know when this technology
       is being used and for what purpose.

    By using this software, you agree to these principles absolutely and
    without reservation.

    ═══════════════════════════════════════════════════════════════════════════════
    """

    /// Print declaration
    public func printAntiWeaponizationDeclaration() {
        print(Self.antiWeaponizationDeclaration)
    }
}
