import Foundation
import Combine
import simd

// MARK: - Neural Interface Layer
/// Schnittstelle für Gehirn-Computer-Interfaces (BCI)
///
/// **Unterstützte Technologien:**
/// - 🧠 Neuralink (invasiv, hohe Bandbreite)
/// - 📡 EEG-Headsets (nicht-invasiv, OpenBCI, Muse, Emotiv)
/// - 💪 EMG (Muskelaktivität)
/// - 👁️ EOG (Augenbewegungen)
/// - 🎯 fNIRS (Hirnaktivität via Infrarot)
///
/// **Steuermodi:**
/// - Gedankensteuerung (Motor Imagery)
/// - Aufmerksamkeitssteuerung
/// - Emotionsbasierte Steuerung
/// - Hybrid (Neural + konventionell)
///
/// **Sicherheit:**
/// - Fail-Safe bei Signalverlust
/// - Intention Verification
/// - Fatigue Detection

@MainActor
public class NeuralInterfaceLayer: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var signalQuality: Double = 0.0
    @Published public private(set) var currentIntention: DetectedIntention?
    @Published public private(set) var mentalState: MentalState = MentalState()
    @Published public private(set) var fatigueLevelL: Double = 0.0

    // MARK: - Interface Type

    public let interfaceType: NeuralInterfaceType

    // MARK: - Signal Processing

    private var signalProcessor: NeuralSignalProcessor
    private var intentionDecoder: IntentionDecoder
    private var safetyMonitor: NeuralSafetyMonitor

    // MARK: - Data Buffers

    private var rawSignalBuffer: RingBuffer<NeuralSample> = RingBuffer(capacity: 1000)
    private var processedBuffer: RingBuffer<ProcessedSignal> = RingBuffer(capacity: 100)

    // MARK: - Calibration

    private var calibrationProfile: CalibrationProfile?
    private var isCalibrated: Bool = false

    // MARK: - Control

    private var controlTimer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init(type: NeuralInterfaceType) {
        self.interfaceType = type
        self.signalProcessor = NeuralSignalProcessor(type: type)
        self.intentionDecoder = IntentionDecoder()
        self.safetyMonitor = NeuralSafetyMonitor()

        print("[NeuralInterface] Initialized: \(type)")
    }

    // MARK: - Connection

    /// Verbinde mit Neural Interface Hardware
    public func connect() async throws {
        print("[NeuralInterface] Connecting to \(interfaceType)...")

        switch interfaceType {
        case .neuralink:
            try await connectNeuralink()
        case .eegOpenBCI:
            try await connectOpenBCI()
        case .eegMuse:
            try await connectMuse()
        case .eegEmotiv:
            try await connectEmotiv()
        case .emg:
            try await connectEMG()
        case .eog:
            try await connectEOG()
        case .fnirs:
            try await connectFNIRS()
        case .hybrid:
            try await connectHybrid()
        case .simulated:
            // Simulierter Modus für Entwicklung
            isConnected = true
            signalQuality = 0.95
        }

        if isConnected {
            startSignalProcessing()
            print("[NeuralInterface] ✅ Connected")
        }
    }

    /// Trenne Verbindung
    public func disconnect() {
        stopSignalProcessing()
        isConnected = false
        print("[NeuralInterface] Disconnected")
    }

    // MARK: - Calibration

    /// Kalibriere Interface für Benutzer
    public func calibrate() async -> CalibrationProfile? {
        guard isConnected else { return nil }

        print("[NeuralInterface] Starting calibration...")

        var profile = CalibrationProfile()

        // Phase 1: Baseline (Ruhe)
        print("[NeuralInterface] Phase 1: Baseline - Please relax...")
        await collectBaselineData(into: &profile)

        // Phase 2: Motor Imagery (Bewegungsvorstellung)
        print("[NeuralInterface] Phase 2: Imagine moving left hand...")
        await collectMotorImageryData(direction: .left, into: &profile)

        print("[NeuralInterface] Phase 3: Imagine moving right hand...")
        await collectMotorImageryData(direction: .right, into: &profile)

        print("[NeuralInterface] Phase 4: Imagine moving forward...")
        await collectMotorImageryData(direction: .forward, into: &profile)

        // Phase 3: Attention (Aufmerksamkeit)
        print("[NeuralInterface] Phase 5: Focus on the target...")
        await collectAttentionData(into: &profile)

        calibrationProfile = profile
        isCalibrated = true
        intentionDecoder.loadCalibration(profile)

        print("[NeuralInterface] ✅ Calibration complete")
        return profile
    }

    private func collectBaselineData(into profile: inout CalibrationProfile) async {
        try? await Task.sleep(nanoseconds: 5_000_000_000)  // 5 Sekunden
        // Daten sammeln und in Profil speichern
        profile.baselineAlpha = mentalState.alphaPower
        profile.baselineBeta = mentalState.betaPower
    }

    private func collectMotorImageryData(direction: IntentionDirection, into profile: inout CalibrationProfile) async {
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        // ERD/ERS Muster für diese Bewegung erfassen
        profile.motorImageryPatterns[direction] = signalProcessor.currentERDPattern
    }

    private func collectAttentionData(into profile: inout CalibrationProfile) async {
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        profile.attentionBaseline = mentalState.attention
    }

    // MARK: - Signal Processing

    private func startSignalProcessing() {
        let interval = 1.0 / 250.0  // 250 Hz Verarbeitung

        controlTimer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.processSignals()
            }
    }

    private func stopSignalProcessing() {
        controlTimer?.cancel()
        controlTimer = nil
    }

    private func processSignals() {
        // 1. Rohsignal verarbeiten
        let processed = signalProcessor.process(rawSignalBuffer.all)
        processedBuffer.append(processed)

        // 2. Signalqualität aktualisieren
        signalQuality = signalProcessor.calculateSignalQuality()

        // 3. Mental State extrahieren
        mentalState = signalProcessor.extractMentalState(from: processed)

        // 4. Intention dekodieren
        if isCalibrated {
            currentIntention = intentionDecoder.decode(
                signal: processed,
                mentalState: mentalState
            )
        }

        // 5. Fatigue erkennen
        fatigueLevelL = safetyMonitor.detectFatigue(mentalState: mentalState)

        // 6. Sicherheitsprüfung
        safetyMonitor.check(signalQuality: signalQuality, fatigue: fatigueLevelL)
    }

    // MARK: - Command Output

    /// Hole aktuellen Steuerbefehl
    public func getCurrentCommand() -> UniversalMovementCommand? {
        guard isConnected, isCalibrated else { return nil }
        guard let intention = currentIntention else { return nil }
        guard intention.confidence > 0.7 else { return nil }  // Mindest-Konfidenz

        return intention.toMovementCommand()
    }

    // MARK: - Hardware Connection (Stubs)

    private func connectNeuralink() async throws {
        // Neuralink SDK Integration
        // Höchste Bandbreite, invasiv
        print("[NeuralInterface] ⚠️ Neuralink: Requires surgical implant")
        throw NeuralInterfaceError.notImplemented
    }

    private func connectOpenBCI() async throws {
        // OpenBCI via Bluetooth/Serial
        // 8-16 Kanäle, 250 Hz
        isConnected = true
        signalQuality = 0.8
    }

    private func connectMuse() async throws {
        // Muse Headband via Bluetooth
        // 4 Kanäle, Consumer-Grade
        isConnected = true
        signalQuality = 0.7
    }

    private func connectEmotiv() async throws {
        // Emotiv EPOC/Insight
        // 5-14 Kanäle
        isConnected = true
        signalQuality = 0.75
    }

    private func connectEMG() async throws {
        // EMG Sensoren (Myo, Thalmic)
        isConnected = true
        signalQuality = 0.85
    }

    private func connectEOG() async throws {
        // Elektrookulographie
        isConnected = true
        signalQuality = 0.8
    }

    private func connectFNIRS() async throws {
        // Funktionelle Nahinfrarotspektroskopie
        isConnected = true
        signalQuality = 0.7
    }

    private func connectHybrid() async throws {
        // Kombination mehrerer Modalitäten
        try await connectOpenBCI()
        try await connectEMG()
    }
}

// MARK: - Neural Interface Type

public enum NeuralInterfaceType: String, CaseIterable, Codable {
    case neuralink      // Invasives BCI (Zukunft)
    case eegOpenBCI     // OpenBCI (Open Source)
    case eegMuse        // Muse Headband
    case eegEmotiv      // Emotiv EPOC/Insight
    case emg            // Muskelaktivität
    case eog            // Augenbewegungen
    case fnirs          // Nahinfrarot
    case hybrid         // Kombination
    case simulated      // Simulation für Entwicklung

    public var displayName: String {
        switch self {
        case .neuralink: return "Neuralink"
        case .eegOpenBCI: return "OpenBCI EEG"
        case .eegMuse: return "Muse Headband"
        case .eegEmotiv: return "Emotiv EPOC"
        case .emg: return "EMG Sensors"
        case .eog: return "Eye Tracking (EOG)"
        case .fnirs: return "fNIRS"
        case .hybrid: return "Hybrid Multi-Modal"
        case .simulated: return "Simulated (Dev)"
        }
    }

    public var channelCount: Int {
        switch self {
        case .neuralink: return 1024
        case .eegOpenBCI: return 16
        case .eegMuse: return 4
        case .eegEmotiv: return 14
        case .emg: return 8
        case .eog: return 4
        case .fnirs: return 16
        case .hybrid: return 32
        case .simulated: return 8
        }
    }

    public var sampleRate: Double {
        switch self {
        case .neuralink: return 20000
        case .eegOpenBCI: return 250
        case .eegMuse: return 256
        case .eegEmotiv: return 128
        case .emg: return 1000
        case .eog: return 250
        case .fnirs: return 10
        case .hybrid: return 250
        case .simulated: return 250
        }
    }

    public var isInvasive: Bool {
        return self == .neuralink
    }

    public var evidenceLevel: String {
        switch self {
        case .neuralink: return "⚠️ Experimental (FDA Breakthrough Device)"
        case .eegOpenBCI, .eegEmotiv: return "✅ Research-Grade"
        case .eegMuse: return "⚠️ Consumer-Grade"
        case .emg: return "✅ Clinical Standard"
        case .eog: return "✅ Clinical Standard"
        case .fnirs: return "✅ Research-Grade"
        case .hybrid: return "⚠️ Experimental"
        case .simulated: return "🔬 Development Only"
        }
    }
}

// MARK: - Mental State

public struct MentalState: Codable {
    // Brainwave Power (0-1 normalisiert)
    public var deltaPower: Double = 0      // 0.5-4 Hz (Schlaf)
    public var thetaPower: Double = 0      // 4-8 Hz (Meditation)
    public var alphaPower: Double = 0      // 8-13 Hz (Entspannung)
    public var betaPower: Double = 0       // 13-30 Hz (Fokus)
    public var gammaPower: Double = 0      // 30-100 Hz (Kognition)

    // Abgeleitete Metriken
    public var attention: Double = 0       // Aufmerksamkeitslevel
    public var meditation: Double = 0      // Entspannungslevel
    public var stress: Double = 0          // Stresslevel
    public var engagement: Double = 0      // Engagement/Flow
    public var drowsiness: Double = 0      // Müdigkeit

    // Asymmetrie (für Emotionserkennung)
    public var frontalAsymmetry: Double = 0  // Links-Rechts Asymmetrie

    public var dominantBand: BrainwaveBand {
        let bands: [(BrainwaveBand, Double)] = [
            (.delta, deltaPower),
            (.theta, thetaPower),
            (.alpha, alphaPower),
            (.beta, betaPower),
            (.gamma, gammaPower)
        ]
        return bands.max(by: { $0.1 < $1.1 })?.0 ?? .alpha
    }

    public enum BrainwaveBand: String, Codable {
        case delta, theta, alpha, beta, gamma
    }
}

// MARK: - Detected Intention

public struct DetectedIntention: Codable {
    public let timestamp: Date
    public let type: IntentionType
    public let direction: IntentionDirection
    public let intensity: Double       // 0-1
    public let confidence: Double      // 0-1

    public func toMovementCommand() -> UniversalMovementCommand {
        var dir: SIMD3<Double> = .zero

        switch direction {
        case .forward: dir.y = 1
        case .backward: dir.y = -1
        case .left: dir.x = -1
        case .right: dir.x = 1
        case .up: dir.z = 1
        case .down: dir.z = -1
        case .none: break
        }

        return UniversalMovementCommand(
            direction: dir * intensity,
            intensity: intensity,
            domain: .land  // Wird vom MultiDomainController überschrieben
        )
    }
}

public enum IntentionType: String, Codable {
    case motorImagery     // Bewegungsvorstellung
    case attention        // Aufmerksamkeitssteuerung
    case ssvep            // Steady-State Visual Evoked Potential
    case p300             // P300 Evoked Potential
    case hybrid
}

public enum IntentionDirection: String, Codable, Hashable {
    case forward
    case backward
    case left
    case right
    case up
    case down
    case none
}

// MARK: - Calibration Profile

public struct CalibrationProfile: Codable {
    public var userId: UUID = UUID()
    public var createdAt: Date = Date()

    // Baseline
    public var baselineAlpha: Double = 0
    public var baselineBeta: Double = 0
    public var attentionBaseline: Double = 0

    // Motor Imagery Patterns
    public var motorImageryPatterns: [IntentionDirection: [Double]] = [:]

    // Thresholds
    public var intentionThreshold: Double = 0.6
    public var attentionThreshold: Double = 0.5
}

// MARK: - Signal Types

public struct NeuralSample {
    public let timestamp: Date
    public let channels: [Double]
}

public struct ProcessedSignal {
    public let timestamp: Date
    public let bandPowers: [Double]  // Delta, Theta, Alpha, Beta, Gamma
    public let features: [Double]    // Extrahierte Features
}

// MARK: - Signal Processor

public class NeuralSignalProcessor {
    private let interfaceType: NeuralInterfaceType
    public var currentERDPattern: [Double] = []

    public init(type: NeuralInterfaceType) {
        self.interfaceType = type
    }

    public func process(_ samples: [NeuralSample]) -> ProcessedSignal {
        // FFT für Frequenzbänder
        // Artefakt-Entfernung (Augen, Muskeln)
        // Feature-Extraktion

        return ProcessedSignal(
            timestamp: Date(),
            bandPowers: [0.2, 0.3, 0.4, 0.3, 0.1],  // Simuliert
            features: []
        )
    }

    public func calculateSignalQuality() -> Double {
        // Impedanz, Rauschen, Artefakte prüfen
        return 0.8
    }

    public func extractMentalState(from signal: ProcessedSignal) -> MentalState {
        var state = MentalState()

        if signal.bandPowers.count >= 5 {
            state.deltaPower = signal.bandPowers[0]
            state.thetaPower = signal.bandPowers[1]
            state.alphaPower = signal.bandPowers[2]
            state.betaPower = signal.bandPowers[3]
            state.gammaPower = signal.bandPowers[4]
        }

        // Abgeleitete Metriken
        state.attention = state.betaPower / max(0.01, state.alphaPower + state.thetaPower)
        state.meditation = state.alphaPower
        state.engagement = (state.betaPower + state.gammaPower) / 2.0

        return state
    }
}

// MARK: - Intention Decoder

public class IntentionDecoder {
    private var calibration: CalibrationProfile?

    public func loadCalibration(_ profile: CalibrationProfile) {
        self.calibration = profile
    }

    public func decode(signal: ProcessedSignal, mentalState: MentalState) -> DetectedIntention? {
        guard calibration != nil else { return nil }

        // CSP (Common Spatial Patterns) für Motor Imagery
        // LDA (Linear Discriminant Analysis) für Klassifikation

        // Simulierte Dekodierung
        let direction = detectDirection(from: signal)
        let intensity = mentalState.betaPower
        let confidence = mentalState.engagement

        guard confidence > 0.5 else { return nil }

        return DetectedIntention(
            timestamp: Date(),
            type: .motorImagery,
            direction: direction,
            intensity: intensity,
            confidence: confidence
        )
    }

    private func detectDirection(from signal: ProcessedSignal) -> IntentionDirection {
        // Placeholder - echte Implementierung würde ML-Modell nutzen
        return .forward
    }
}

// MARK: - Neural Safety Monitor

public class NeuralSafetyMonitor {
    private var consecutiveLowQuality: Int = 0
    private let maxLowQuality: Int = 10

    public func detectFatigue(mentalState: MentalState) -> Double {
        // Fatigue erkennbar an:
        // - Erhöhtem Theta
        // - Reduziertem Alpha
        // - Langsame Augenbewegungen

        let fatigueScore = mentalState.thetaPower * 0.4 +
                          (1 - mentalState.alphaPower) * 0.3 +
                          mentalState.deltaPower * 0.3

        return min(1, max(0, fatigueScore))
    }

    public func check(signalQuality: Double, fatigue: Double) {
        // Signalqualität prüfen
        if signalQuality < 0.5 {
            consecutiveLowQuality += 1
            if consecutiveLowQuality >= maxLowQuality {
                triggerSafetyAlert(.lowSignalQuality)
            }
        } else {
            consecutiveLowQuality = 0
        }

        // Fatigue prüfen
        if fatigue > 0.8 {
            triggerSafetyAlert(.highFatigue)
        }
    }

    private func triggerSafetyAlert(_ type: SafetyAlertType) {
        print("[NeuralSafety] ⚠️ Alert: \(type)")
        NotificationCenter.default.post(
            name: .neuralInterfaceSafetyAlert,
            object: nil,
            userInfo: ["alertType": type]
        )
    }

    public enum SafetyAlertType: String {
        case lowSignalQuality
        case highFatigue
        case connectionLost
        case abnormalActivity
    }
}

// MARK: - Errors

public enum NeuralInterfaceError: Error, LocalizedError {
    case notImplemented
    case connectionFailed
    case calibrationFailed
    case lowSignalQuality

    public var errorDescription: String? {
        switch self {
        case .notImplemented: return "This neural interface is not yet implemented"
        case .connectionFailed: return "Failed to connect to neural interface"
        case .calibrationFailed: return "Calibration failed"
        case .lowSignalQuality: return "Signal quality too low"
        }
    }
}

// MARK: - Notifications

public extension Notification.Name {
    static let neuralInterfaceSafetyAlert = Notification.Name("neuralInterfaceSafetyAlert")
    static let neuralInterfaceConnected = Notification.Name("neuralInterfaceConnected")
    static let neuralInterfaceDisconnected = Notification.Name("neuralInterfaceDisconnected")
}

// MARK: - Alternative Interfaces (für Zukunft)

/// Gestik-basierte Alternative zu Neural Interface
public class GestureAlternativeInterface {
    // Hand-Tracking als Alternative
    // Weniger direkt, aber zugänglicher
}

/// Sprach-basierte Alternative
public class VoiceAlternativeInterface {
    // Sprachbefehle als Alternative
    // "Links fahren", "Schneller", etc.
}

/// Blick-basierte Alternative
public class GazeAlternativeInterface {
    // Eye-Tracking als Alternative
    // Blickrichtung = Bewegungsrichtung
}
