import Foundation
import Combine

// MARK: - Autopilot System
/// Intelligentes autonomes Steuerungssystem für Echoelmusic
///
/// Das Autopilot-System analysiert kontinuierlich biometrische Daten,
/// erkennt den Zustand des Benutzers und passt Audio/Visual-Parameter
/// automatisch an, um optimale Ergebnisse zu erzielen.
///
/// **Architektur:**
/// ```
/// Biometrics → StateAnalyzer → DecisionEngine → ParameterController → Output
///                    ↑                                    ↓
///                    └──────── FeedbackLoop ─────────────┘
/// ```
///
/// **Evidenz-Level:**
/// - ✅ HRV-basierte Stresserkennung (peer-reviewed)
/// - ✅ Binaural Beat Entrainment (Oster 1973, Lane 1998)
/// - ⚠️ Adaptive Frequenzanpassung (preliminary research)
/// - ❌ Organ-spezifische Frequenzen (unvalidiert, nur Exploration)

@MainActor
public class AutopilotSystem: ObservableObject {

    // MARK: - Published State

    /// Aktueller Autopilot-Modus
    @Published public private(set) var currentMode: AutopilotMode = .balanced

    /// Ob Autopilot aktiv ist
    @Published public private(set) var isActive: Bool = false

    /// Aktueller erkannter Benutzerzustand
    @Published public private(set) var detectedState: UserPhysiologicalState = .neutral

    /// Zielzustand (was der Autopilot anstrebt)
    @Published public private(set) var targetState: UserPhysiologicalState = .relaxed

    /// Konvergenz zum Zielzustand (0.0-1.0)
    @Published public private(set) var convergenceProgress: Double = 0.0

    /// Aktuelle Autopilot-Entscheidung
    @Published public private(set) var currentDecision: AutopilotDecision?

    /// Sicherheitsstatus
    @Published public private(set) var safetyStatus: SafetyStatus = .nominal

    /// Diagnostik-Informationen
    @Published public private(set) var diagnostics: AutopilotDiagnostics = AutopilotDiagnostics()

    // MARK: - Submodule

    private let stateAnalyzer: StateAnalyzer
    private let decisionEngine: DecisionEngine
    private let parameterController: ParameterController
    private let feedbackLoop: FeedbackLoop
    private let safetyMonitor: SafetyMonitor

    // MARK: - Dependencies

    private weak var audioEngine: AudioEngine?
    private weak var bioMapper: BioParameterMapper?
    private weak var frequencyScanner: IndividualFrequencyScanner?
    private weak var spatialAudio: SpatialAudioEngine?

    // MARK: - Control Loop

    private var controlTimer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    /// Update-Frequenz in Hz (wissenschaftlich: 10Hz ausreichend für bio-feedback)
    private let updateFrequency: Double = 10.0

    /// Minimale Zeit zwischen Parameteränderungen (verhindert oszillation)
    private let minChangeInterval: TimeInterval = 0.5
    private var lastChangeTime: Date = .distantPast

    // MARK: - Configuration

    public var configuration: AutopilotConfiguration {
        didSet {
            updateConfiguration()
        }
    }

    // MARK: - Initialization

    public init(configuration: AutopilotConfiguration = .default) {
        self.configuration = configuration

        self.stateAnalyzer = StateAnalyzer()
        self.decisionEngine = DecisionEngine()
        self.parameterController = ParameterController()
        self.feedbackLoop = FeedbackLoop()
        self.safetyMonitor = SafetyMonitor()

        setupInternalConnections()
    }

    // MARK: - Dependency Injection

    /// Verbinde mit externen Systemen
    public func connect(
        audioEngine: AudioEngine? = nil,
        bioMapper: BioParameterMapper? = nil,
        frequencyScanner: IndividualFrequencyScanner? = nil,
        spatialAudio: SpatialAudioEngine? = nil
    ) {
        self.audioEngine = audioEngine
        self.bioMapper = bioMapper
        self.frequencyScanner = frequencyScanner
        self.spatialAudio = spatialAudio

        print("[Autopilot] Connected to \(connectedSystemsCount) systems")
    }

    private var connectedSystemsCount: Int {
        var count = 0
        if audioEngine != nil { count += 1 }
        if bioMapper != nil { count += 1 }
        if frequencyScanner != nil { count += 1 }
        if spatialAudio != nil { count += 1 }
        return count
    }

    // MARK: - Control

    /// Starte Autopilot
    public func start(mode: AutopilotMode = .balanced) {
        guard !isActive else {
            print("[Autopilot] Already active")
            return
        }

        currentMode = mode
        targetState = mode.targetState
        isActive = true

        startControlLoop()

        print("[Autopilot] ✅ Started in \(mode.displayName) mode")
        print("[Autopilot] Target state: \(targetState.displayName)")
    }

    /// Stoppe Autopilot
    public func stop() {
        guard isActive else { return }

        controlTimer?.cancel()
        controlTimer = nil
        isActive = false

        // Sanftes Ausblenden der Parameter
        parameterController.fadeToNeutral(duration: 2.0)

        print("[Autopilot] ⏹ Stopped")
    }

    /// Wechsle Modus während Betrieb
    public func switchMode(_ newMode: AutopilotMode) {
        let wasActive = isActive

        if wasActive {
            // Sanfter Übergang
            parameterController.prepareTransition()
        }

        currentMode = newMode
        targetState = newMode.targetState
        decisionEngine.updateStrategy(for: newMode)

        print("[Autopilot] Mode switched to: \(newMode.displayName)")
    }

    // MARK: - Biometric Input

    /// Empfange biometrische Daten (von HealthKit/Sensoren)
    public func feedBiometrics(_ data: BiometricDataPoint) {
        // Sicherheitsprüfung
        let safetyResult = safetyMonitor.validate(data)
        if safetyResult != .nominal {
            safetyStatus = safetyResult
            handleSafetyEvent(safetyResult, data: data)
            return
        }

        // An StateAnalyzer weiterleiten
        stateAnalyzer.process(data)

        // Diagnostik aktualisieren
        diagnostics.lastBiometricUpdate = Date()
        diagnostics.dataPointsProcessed += 1
    }

    /// Empfange individuelle Frequenzmessung
    public func feedFrequencyMeasurement(_ measurement: MeasuredFrequency, organ: Organ) {
        stateAnalyzer.processFrequency(measurement, organ: organ)
    }

    // MARK: - Control Loop

    private func startControlLoop() {
        let interval = 1.0 / updateFrequency

        controlTimer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.controlLoopTick()
            }
    }

    private func controlLoopTick() {
        guard isActive else { return }

        // 1. Zustand analysieren
        let analyzedState = stateAnalyzer.currentState
        detectedState = analyzedState

        // 2. Konvergenz berechnen
        convergenceProgress = calculateConvergence(
            current: analyzedState,
            target: targetState
        )

        // 3. Entscheidung treffen
        let decision = decisionEngine.decide(
            currentState: analyzedState,
            targetState: targetState,
            mode: currentMode,
            feedback: feedbackLoop.currentFeedback
        )
        currentDecision = decision

        // 4. Rate-Limiting prüfen
        let now = Date()
        guard now.timeIntervalSince(lastChangeTime) >= minChangeInterval else {
            return
        }

        // 5. Nur bei signifikanter Änderung anwenden
        if decision.shouldApply {
            applyDecision(decision)
            lastChangeTime = now
        }

        // 6. Feedback-Loop aktualisieren
        feedbackLoop.update(
            decision: decision,
            resultingState: analyzedState
        )

        // 7. Diagnostik
        diagnostics.controlLoopIterations += 1
        diagnostics.lastControlLoopTime = now
    }

    // MARK: - Decision Application

    private func applyDecision(_ decision: AutopilotDecision) {
        // Audio-Parameter
        if let audioParams = decision.audioParameters {
            applyAudioParameters(audioParams)
        }

        // Frequenz-Parameter
        if let freqParams = decision.frequencyParameters {
            applyFrequencyParameters(freqParams)
        }

        // Spatial-Audio
        if let spatialParams = decision.spatialParameters {
            applySpatialParameters(spatialParams)
        }

        diagnostics.decisionsApplied += 1
    }

    private func applyAudioParameters(_ params: AudioParameterSet) {
        guard let audio = audioEngine else { return }

        // Sanfte Übergänge mit Rampen
        if let carrier = params.carrierFrequency {
            audio.setBinauralCarrier(carrier, rampTime: params.rampTime)
        }

        if let beat = params.beatFrequency {
            audio.setBinauralBeat(beat, rampTime: params.rampTime)
        }

        if let amplitude = params.amplitude {
            audio.setBinauralAmplitude(amplitude)
        }

        if let reverb = params.reverbMix {
            audio.setReverbMix(reverb)
        }
    }

    private func applyFrequencyParameters(_ params: FrequencyParameterSet) {
        guard let scanner = frequencyScanner else { return }

        // Individuelle Frequenz-Anpassungen basierend auf Scan-Profil
        if let targetOrgan = params.targetOrgan,
           let profile = scanner.currentProfile {

            // Hole individuelle Baseline für dieses Organ
            if let baseline = profile.organBaselines[targetOrgan] {
                // Berechne optimale Frequenz basierend auf individuellem Profil
                let optimalFreq = calculateOptimalFrequency(
                    baseline: baseline,
                    adjustment: params.frequencyAdjustment
                )

                // Wende an (über Audio-Engine oder andere Ausgabe)
                print("[Autopilot] Applying individual frequency: \(optimalFreq) Hz for \(targetOrgan)")
            }
        }
    }

    private func applySpatialParameters(_ params: SpatialParameterSet) {
        guard let spatial = spatialAudio else { return }

        if let position = params.listenerPosition {
            spatial.setListenerPosition(position)
        }

        if let rotation = params.fieldRotation {
            spatial.setFieldRotation(rotation)
        }
    }

    // MARK: - Calculations

    private func calculateConvergence(
        current: UserPhysiologicalState,
        target: UserPhysiologicalState
    ) -> Double {
        // Distanz zwischen aktuellem und Zielzustand
        let distance = current.distance(to: target)

        // Konvergenz = 1.0 - normalisierte Distanz
        return max(0, 1.0 - distance)
    }

    private func calculateOptimalFrequency(
        baseline: BiologicalOscillation,
        adjustment: Double
    ) -> Double {
        // Wissenschaftlich: Frequenz basierend auf individueller Baseline anpassen
        // adjustment ist ein Faktor (-1.0 bis +1.0) für Abweichung vom Baseline

        let range = baseline.variabilitySD * 2.0  // 2 Standardabweichungen
        let adjusted = baseline.baseFrequency + (range * adjustment)

        return adjusted
    }

    // MARK: - Safety

    private func handleSafetyEvent(_ status: SafetyStatus, data: BiometricDataPoint) {
        switch status {
        case .nominal:
            break

        case .warning(let message):
            print("[Autopilot] ⚠️ Warning: \(message)")
            // Reduziere Intensität
            parameterController.reduceIntensity(by: 0.3)

        case .critical(let message):
            print("[Autopilot] 🛑 CRITICAL: \(message)")
            // Sofortiger Stopp
            stop()

        case .limitReached(let limit):
            print("[Autopilot] ⚡ Limit reached: \(limit)")
            // Halte aktuelle Parameter, keine weiteren Änderungen
            parameterController.hold()
        }

        diagnostics.safetyEvents.append(SafetyEvent(
            timestamp: Date(),
            status: status,
            data: data
        ))
    }

    // MARK: - Setup

    private func setupInternalConnections() {
        // StateAnalyzer → Published State
        stateAnalyzer.$currentState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.detectedState = state
            }
            .store(in: &cancellables)
    }

    private func updateConfiguration() {
        stateAnalyzer.sensitivity = configuration.stateSensitivity
        decisionEngine.aggressiveness = configuration.decisionAggressiveness
        parameterController.smoothingFactor = configuration.parameterSmoothing
        feedbackLoop.learningRate = configuration.feedbackLearningRate
        safetyMonitor.thresholds = configuration.safetyThresholds
    }
}

// MARK: - Autopilot Mode

public enum AutopilotMode: String, CaseIterable, Codable, Identifiable {
    case balanced       // Ausgewogener Allround-Modus
    case meditation     // Tiefe Entspannung, Alpha/Theta-Fokus
    case focus          // Konzentration, Beta-Fokus
    case creativity     // Kreativität, Theta/Alpha-Übergang
    case sleep          // Einschlafhilfe, Delta-Fokus
    case recovery       // Erholung nach Stress
    case energy         // Aktivierung, Beta/Gamma
    case custom         // Benutzerdefiniert

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .balanced: return "Ausgewogen"
        case .meditation: return "Meditation"
        case .focus: return "Fokus"
        case .creativity: return "Kreativität"
        case .sleep: return "Schlaf"
        case .recovery: return "Erholung"
        case .energy: return "Energie"
        case .custom: return "Benutzerdefiniert"
        }
    }

    public var targetState: UserPhysiologicalState {
        switch self {
        case .balanced: return .neutral
        case .meditation: return .deepRelaxation
        case .focus: return .focused
        case .creativity: return .creative
        case .sleep: return .drowsy
        case .recovery: return .relaxed
        case .energy: return .energized
        case .custom: return .neutral
        }
    }

    /// Ziel-Brainwave-Bereich für diesen Modus
    public var targetBrainwaveRange: ClosedRange<Double> {
        switch self {
        case .balanced: return 8.0...12.0      // Alpha
        case .meditation: return 4.0...8.0    // Theta
        case .focus: return 15.0...25.0       // Beta
        case .creativity: return 6.0...10.0   // Theta-Alpha
        case .sleep: return 0.5...4.0         // Delta
        case .recovery: return 8.0...13.0     // Alpha
        case .energy: return 20.0...40.0      // Beta-Gamma
        case .custom: return 1.0...100.0      // Full range
        }
    }

    /// Evidenz-Level für diesen Modus
    public var evidenceLevel: EvidenceLevel {
        switch self {
        case .meditation, .focus, .sleep:
            return .peerReviewed  // ✅ Binaural beats für diese Zustände gut untersucht
        case .balanced, .recovery:
            return .preliminary   // ⚠️ Begrenzte Studien
        case .creativity, .energy, .custom:
            return .anecdotal     // ❌ Hauptsächlich anekdotisch
        }
    }
}

// MARK: - User Physiological State

public enum UserPhysiologicalState: String, CaseIterable, Codable {
    case stressed       // Hoher Stress, niedriges HRV
    case anxious        // Ängstlich, erhöhte HR
    case neutral        // Baseline, normal
    case relaxed        // Entspannt, hohes HRV
    case deepRelaxation // Tiefe Entspannung
    case focused        // Konzentriert, mittleres Beta
    case creative       // Kreativ, Theta-Alpha
    case drowsy         // Müde, Delta-Theta
    case energized      // Aktiviert, hohes Beta

    public var displayName: String {
        switch self {
        case .stressed: return "Gestresst"
        case .anxious: return "Ängstlich"
        case .neutral: return "Neutral"
        case .relaxed: return "Entspannt"
        case .deepRelaxation: return "Tief entspannt"
        case .focused: return "Fokussiert"
        case .creative: return "Kreativ"
        case .drowsy: return "Müde"
        case .energized: return "Energetisiert"
        }
    }

    /// Berechne Distanz zu anderem Zustand (0.0 = gleich, 1.0 = maximal unterschiedlich)
    public func distance(to other: UserPhysiologicalState) -> Double {
        // Vereinfachte Arousal-Valenz-Modellierung
        let selfArousal = self.arousalLevel
        let selfValence = self.valenceLevel
        let otherArousal = other.arousalLevel
        let otherValence = other.valenceLevel

        let arousalDiff = abs(selfArousal - otherArousal)
        let valenceDiff = abs(selfValence - otherValence)

        // Euklidische Distanz, normalisiert auf 0-1
        return sqrt(arousalDiff * arousalDiff + valenceDiff * valenceDiff) / sqrt(2.0)
    }

    /// Arousal-Level (0.0 = niedrig/müde, 1.0 = hoch/aktiviert)
    public var arousalLevel: Double {
        switch self {
        case .drowsy: return 0.1
        case .deepRelaxation: return 0.2
        case .relaxed: return 0.3
        case .neutral: return 0.5
        case .creative: return 0.5
        case .focused: return 0.7
        case .anxious: return 0.8
        case .stressed: return 0.9
        case .energized: return 0.9
        }
    }

    /// Valenz-Level (0.0 = negativ, 1.0 = positiv)
    public var valenceLevel: Double {
        switch self {
        case .stressed: return 0.1
        case .anxious: return 0.2
        case .drowsy: return 0.4
        case .neutral: return 0.5
        case .focused: return 0.6
        case .relaxed: return 0.7
        case .creative: return 0.8
        case .energized: return 0.8
        case .deepRelaxation: return 0.9
        }
    }
}

// MARK: - Safety Status

public enum SafetyStatus: Equatable {
    case nominal
    case warning(String)
    case critical(String)
    case limitReached(String)
}

// MARK: - Evidence Level

public enum EvidenceLevel: String, Codable {
    case peerReviewed = "peer_reviewed"   // ✅ Peer-reviewed Studien
    case preliminary = "preliminary"       // ⚠️ Preliminary/Pilotstudien
    case anecdotal = "anecdotal"          // ❌ Anekdotisch/unvalidiert
}

// MARK: - Supporting Types

public struct AutopilotDecision: Codable {
    public let timestamp: Date
    public let confidence: Double          // 0.0-1.0
    public let shouldApply: Bool
    public let reasoning: String

    public var audioParameters: AudioParameterSet?
    public var frequencyParameters: FrequencyParameterSet?
    public var spatialParameters: SpatialParameterSet?
}

public struct AudioParameterSet: Codable {
    public var carrierFrequency: Float?
    public var beatFrequency: Float?
    public var amplitude: Float?
    public var reverbMix: Float?
    public var rampTime: Float = 0.5       // Übergangszeit in Sekunden
}

public struct FrequencyParameterSet: Codable {
    public var targetOrgan: Organ?
    public var frequencyAdjustment: Double  // -1.0 bis +1.0
}

public struct SpatialParameterSet: Codable {
    public var listenerPosition: SIMD3<Float>?
    public var fieldRotation: Float?
}

public struct BiometricDataPoint: Codable {
    public let timestamp: Date
    public var heartRate: Double?          // BPM
    public var hrv: Double?                // RMSSD in ms
    public var respirationRate: Double?    // Breaths per minute
    public var skinConductance: Double?    // μS (Microsiemens)
    public var temperature: Double?        // °C
    public var coherence: Double?          // 0.0-1.0

    public init(
        timestamp: Date = Date(),
        heartRate: Double? = nil,
        hrv: Double? = nil,
        respirationRate: Double? = nil,
        skinConductance: Double? = nil,
        temperature: Double? = nil,
        coherence: Double? = nil
    ) {
        self.timestamp = timestamp
        self.heartRate = heartRate
        self.hrv = hrv
        self.respirationRate = respirationRate
        self.skinConductance = skinConductance
        self.temperature = temperature
        self.coherence = coherence
    }
}

public struct AutopilotDiagnostics: Codable {
    public var controlLoopIterations: Int = 0
    public var decisionsApplied: Int = 0
    public var dataPointsProcessed: Int = 0
    public var lastBiometricUpdate: Date?
    public var lastControlLoopTime: Date?
    public var safetyEvents: [SafetyEvent] = []
    public var averageConvergenceRate: Double = 0.0
}

public struct SafetyEvent: Codable {
    public let timestamp: Date
    public let status: SafetyStatusCodable
    public let dataSnapshot: BiometricDataPoint?

    init(timestamp: Date, status: SafetyStatus, data: BiometricDataPoint?) {
        self.timestamp = timestamp
        self.status = SafetyStatusCodable(from: status)
        self.dataSnapshot = data
    }
}

/// Codable wrapper für SafetyStatus
public struct SafetyStatusCodable: Codable {
    public let type: String
    public let message: String?

    init(from status: SafetyStatus) {
        switch status {
        case .nominal:
            self.type = "nominal"
            self.message = nil
        case .warning(let msg):
            self.type = "warning"
            self.message = msg
        case .critical(let msg):
            self.type = "critical"
            self.message = msg
        case .limitReached(let limit):
            self.type = "limitReached"
            self.message = limit
        }
    }
}

// MARK: - Configuration

public struct AutopilotConfiguration: Codable {
    public var stateSensitivity: Double = 0.5        // 0.0-1.0
    public var decisionAggressiveness: Double = 0.3  // 0.0-1.0
    public var parameterSmoothing: Double = 0.7      // 0.0-1.0
    public var feedbackLearningRate: Double = 0.1    // 0.0-1.0
    public var safetyThresholds: SafetyThresholds = SafetyThresholds()

    public static let `default` = AutopilotConfiguration()

    public static let conservative = AutopilotConfiguration(
        stateSensitivity: 0.3,
        decisionAggressiveness: 0.1,
        parameterSmoothing: 0.9,
        feedbackLearningRate: 0.05
    )

    public static let responsive = AutopilotConfiguration(
        stateSensitivity: 0.8,
        decisionAggressiveness: 0.6,
        parameterSmoothing: 0.4,
        feedbackLearningRate: 0.2
    )
}

public struct SafetyThresholds: Codable {
    /// Maximale Herzfrequenz bevor Warnung
    public var maxHeartRate: Double = 150.0

    /// Minimale Herzfrequenz bevor Warnung
    public var minHeartRate: Double = 40.0

    /// Maximale HRV-Änderung pro Minute
    public var maxHRVChangeRate: Double = 50.0

    /// Maximale kontinuierliche Sitzungsdauer (Sekunden)
    public var maxSessionDuration: TimeInterval = 7200  // 2 Stunden

    /// Minimale Frequenz (Hz) - unter 0.5 Hz nicht sicher
    public var minFrequency: Double = 0.5

    /// Maximale Frequenz (Hz) - über 20kHz nicht sicher
    public var maxFrequency: Double = 20000.0
}
