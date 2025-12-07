import Foundation
import Combine
import CoreLocation
import simd

// MARK: - Multi-Domain Vehicle Controller
/// Universelles Steuerungssystem für Fahrzeuge aller Domänen
///
/// **Unterstützte Domänen:**
/// - 🚗 Land (Autos, LKWs, Panzer, Rover)
/// - ✈️ Luft (Flugzeuge, Helikopter, Drohnen, eVTOL)
/// - 🚢 Wasser (Boote, Schiffe, Jetskis, Hovercrafts)
/// - 🤿 Unterwasser (U-Boote, ROVs, AUVs)
/// - 🚀 Weltraum (Satelliten, Raumschiffe) [Zukunft]
///
/// **Multi-Domain Fahrzeuge:**
/// - Amphibienfahrzeuge (Land ↔ Wasser)
/// - Flugautos (Land ↔ Luft)
/// - Ekranoplans (Wasser ↔ Luft)
/// - Tauchdrohnen (Luft ↔ Wasser ↔ Unterwasser)

@MainActor
public class MultiDomainController: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var currentDomain: VehicleDomain = .land
    @Published public private(set) var targetDomain: VehicleDomain?
    @Published public private(set) var isTransitioning: Bool = false
    @Published public private(set) var transitionProgress: Double = 0.0
    @Published public private(set) var vehicleState: UniversalVehicleState = UniversalVehicleState()
    @Published public private(set) var controlMode: UniversalControlMode = .manual

    // MARK: - Domain Controllers

    private let landController: LandDomainController
    private let airController: AirDomainController
    private let waterController: WaterDomainController
    private let underwaterController: UnderwaterDomainController

    // MARK: - Transition Engine

    private let transitionEngine: DomainTransitionEngine

    // MARK: - Neural Interface

    private var neuralInterface: NeuralInterfaceLayer?

    // MARK: - Input Sources

    private var activeInputSources: Set<InputSourceType> = [.manual]

    // MARK: - Configuration

    public var configuration: MultiDomainConfiguration

    // MARK: - Control Loop

    private var controlTimer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private let controlFrequency: Double = 100.0  // 100 Hz für alle Domänen

    // MARK: - Initialization

    public init(configuration: MultiDomainConfiguration = .default) {
        self.configuration = configuration

        self.landController = LandDomainController()
        self.airController = AirDomainController()
        self.waterController = WaterDomainController()
        self.underwaterController = UnderwaterDomainController()
        self.transitionEngine = DomainTransitionEngine()

        setupInternalConnections()
    }

    // MARK: - Domain Selection

    /// Aktive Domäne wechseln (mit Transition)
    public func switchDomain(to domain: VehicleDomain) async {
        guard domain != currentDomain else { return }
        guard canTransitionTo(domain) else {
            print("[MultiDomain] ❌ Cannot transition to \(domain) from \(currentDomain)")
            return
        }

        targetDomain = domain
        isTransitioning = true

        print("[MultiDomain] 🔄 Transitioning: \(currentDomain) → \(domain)")

        // Transition durchführen
        await transitionEngine.performTransition(
            from: currentDomain,
            to: domain,
            vehicleState: vehicleState,
            onProgress: { [weak self] progress in
                self?.transitionProgress = progress
            }
        )

        currentDomain = domain
        targetDomain = nil
        isTransitioning = false
        transitionProgress = 0

        print("[MultiDomain] ✅ Transition complete: Now in \(domain)")
    }

    /// Prüfe ob Transition möglich
    public func canTransitionTo(_ domain: VehicleDomain) -> Bool {
        let validTransitions = configuration.vehicleCapabilities.supportedTransitions
        let transition = DomainTransition(from: currentDomain, to: domain)
        return validTransitions.contains(transition)
    }

    // MARK: - Control

    /// Starte autonome Steuerung
    public func engage(mode: UniversalControlMode = .fullAutonomy) {
        controlMode = mode
        startControlLoop()
        print("[MultiDomain] ✅ Engaged in \(mode) mode")
    }

    /// Stoppe autonome Steuerung
    public func disengage() {
        stopControlLoop()
        controlMode = .manual
        print("[MultiDomain] ⏹ Disengaged")
    }

    /// Notfall-Stopp (domänenspezifisch)
    public func emergencyStop() {
        print("[MultiDomain] 🛑 EMERGENCY STOP")

        switch currentDomain {
        case .land:
            landController.emergencyBrake()
        case .air:
            airController.emergencyHover()  // oder Autorotation
        case .water:
            waterController.emergencyStop()
        case .underwater:
            underwaterController.emergencySurface()
        case .space:
            break  // Weltraum: komplexer
        }

        disengage()
    }

    // MARK: - Input Sources

    /// Aktiviere Neural Interface
    public func enableNeuralInterface(type: NeuralInterfaceType) {
        neuralInterface = NeuralInterfaceLayer(type: type)
        activeInputSources.insert(.neural)
        print("[MultiDomain] 🧠 Neural interface enabled: \(type)")
    }

    /// Aktiviere Eingabequelle
    public func enableInputSource(_ source: InputSourceType) {
        activeInputSources.insert(source)
    }

    /// Deaktiviere Eingabequelle
    public func disableInputSource(_ source: InputSourceType) {
        activeInputSources.remove(source)
    }

    // MARK: - Unified Commands

    /// Universeller Bewegungsbefehl (domänenunabhängig)
    public func move(direction: SIMD3<Double>, intensity: Double) {
        let command = UniversalMovementCommand(
            direction: direction,
            intensity: intensity,
            domain: currentDomain
        )

        applyCommand(command)
    }

    /// Zielposition setzen
    public func setDestination(_ destination: CLLocationCoordinate2D, altitude: Double? = nil, depth: Double? = nil) {
        vehicleState.navigation.destination = destination
        vehicleState.navigation.targetAltitude = altitude
        vehicleState.navigation.targetDepth = depth

        // Route berechnen
        Task {
            await calculateRoute()
        }
    }

    // MARK: - Control Loop

    private func startControlLoop() {
        let interval = 1.0 / controlFrequency

        controlTimer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.controlLoopTick()
            }
    }

    private func stopControlLoop() {
        controlTimer?.cancel()
        controlTimer = nil
    }

    private func controlLoopTick() {
        guard controlMode != .manual else { return }

        // 1. Eingaben sammeln (alle aktiven Quellen)
        let inputs = gatherInputs()

        // 2. Eingaben fusionieren
        let fusedCommand = fuseInputs(inputs)

        // 3. An aktuellen Domain Controller weiterleiten
        applyCommand(fusedCommand)

        // 4. Zustand aktualisieren
        updateVehicleState()
    }

    private func gatherInputs() -> [UniversalMovementCommand] {
        var inputs: [UniversalMovementCommand] = []

        // Neural Interface
        if activeInputSources.contains(.neural), let neural = neuralInterface {
            if let cmd = neural.getCurrentCommand() {
                inputs.append(cmd)
            }
        }

        // Weitere Eingabequellen...

        return inputs
    }

    private func fuseInputs(_ inputs: [UniversalMovementCommand]) -> UniversalMovementCommand {
        guard !inputs.isEmpty else {
            return UniversalMovementCommand(direction: .zero, intensity: 0, domain: currentDomain)
        }

        // Gewichteter Durchschnitt
        var totalDirection: SIMD3<Double> = .zero
        var totalIntensity: Double = 0
        var totalWeight: Double = 0

        for input in inputs {
            let weight = 1.0  // Alle gleich gewichtet (erweiterbar)
            totalDirection += input.direction * weight
            totalIntensity += input.intensity * weight
            totalWeight += weight
        }

        return UniversalMovementCommand(
            direction: totalDirection / totalWeight,
            intensity: totalIntensity / totalWeight,
            domain: currentDomain
        )
    }

    private func applyCommand(_ command: UniversalMovementCommand) {
        switch currentDomain {
        case .land:
            let landCmd = command.toLandCommand()
            landController.applyCommand(landCmd)

        case .air:
            let airCmd = command.toAirCommand()
            airController.applyCommand(airCmd)

        case .water:
            let waterCmd = command.toWaterCommand()
            waterController.applyCommand(waterCmd)

        case .underwater:
            let underwaterCmd = command.toUnderwaterCommand()
            underwaterController.applyCommand(underwaterCmd)

        case .space:
            break
        }
    }

    private func calculateRoute() async {
        // Route für aktuelle Domäne berechnen
    }

    private func updateVehicleState() {
        // Zustand von aktivem Controller holen
        switch currentDomain {
        case .land:
            vehicleState.position = landController.currentPosition
            vehicleState.velocity = landController.currentVelocity
            vehicleState.heading = landController.currentHeading

        case .air:
            vehicleState.position = airController.currentPosition
            vehicleState.velocity = airController.currentVelocity
            vehicleState.altitude = airController.currentAltitude
            vehicleState.attitude = airController.currentAttitude

        case .water:
            vehicleState.position = waterController.currentPosition
            vehicleState.velocity = waterController.currentVelocity
            vehicleState.heading = waterController.currentHeading

        case .underwater:
            vehicleState.position = underwaterController.currentPosition
            vehicleState.velocity = underwaterController.currentVelocity
            vehicleState.depth = underwaterController.currentDepth
            vehicleState.attitude = underwaterController.currentAttitude

        case .space:
            break
        }
    }

    // MARK: - Setup

    private func setupInternalConnections() {
        // Transition Engine Progress
        transitionEngine.$progress
            .assign(to: &$transitionProgress)
    }
}

// MARK: - Vehicle Domain

public enum VehicleDomain: String, CaseIterable, Codable {
    case land       // 🚗 Boden
    case air        // ✈️ Luft
    case water      // 🚢 Wasseroberfläche
    case underwater // 🤿 Unter Wasser
    case space      // 🚀 Weltraum (Zukunft)

    public var emoji: String {
        switch self {
        case .land: return "🚗"
        case .air: return "✈️"
        case .water: return "🚢"
        case .underwater: return "🤿"
        case .space: return "🚀"
        }
    }

    public var displayName: String {
        switch self {
        case .land: return "Land"
        case .air: return "Luft"
        case .water: return "Wasser"
        case .underwater: return "Unterwasser"
        case .space: return "Weltraum"
        }
    }
}

// MARK: - Domain Transition

public struct DomainTransition: Hashable, Codable {
    public let from: VehicleDomain
    public let to: VehicleDomain

    public var isValid: Bool {
        // Gültige Übergänge
        switch (from, to) {
        case (.land, .air): return true      // Flugauto startet
        case (.air, .land): return true      // Flugauto landet
        case (.land, .water): return true    // Amphibie ins Wasser
        case (.water, .land): return true    // Amphibie an Land
        case (.water, .air): return true     // Wasserflugzeug startet
        case (.air, .water): return true     // Wasserflugzeug landet
        case (.water, .underwater): return true  // Tauchen
        case (.underwater, .water): return true  // Auftauchen
        case (.air, .underwater): return true    // Tauchdrohne
        case (.underwater, .air): return true    // Tauchdrohne
        default: return false
        }
    }

    public var transitionDuration: TimeInterval {
        switch (from, to) {
        case (.land, .air), (.air, .land):
            return 30.0  // 30 Sekunden Start/Landung
        case (.water, .underwater), (.underwater, .water):
            return 60.0  // 1 Minute Tauchen/Auftauchen
        case (.land, .water), (.water, .land):
            return 10.0  // 10 Sekunden
        default:
            return 20.0
        }
    }
}

// MARK: - Universal Vehicle State

public struct UniversalVehicleState: Codable {
    // Position
    public var position: CLLocationCoordinate2D = CLLocationCoordinate2D()
    public var altitude: Double = 0        // Meter über Grund/Wasser
    public var depth: Double = 0           // Meter unter Wasser

    // Bewegung
    public var velocity: SIMD3<Double> = .zero
    public var acceleration: SIMD3<Double> = .zero
    public var heading: Double = 0         // Grad (0 = Nord)

    // Lage (für Luft/Wasser)
    public var attitude: Attitude = Attitude()

    // Navigation
    public var navigation: NavigationData = NavigationData()

    // Systeme
    public var batteryLevel: Double = 1.0
    public var fuelLevel: Double = 1.0
    public var systemHealth: Double = 1.0

    public struct Attitude: Codable {
        public var pitch: Double = 0    // Nicken (Grad)
        public var roll: Double = 0     // Rollen (Grad)
        public var yaw: Double = 0      // Gieren (Grad)
    }

    public struct NavigationData: Codable {
        public var destination: CLLocationCoordinate2D?
        public var targetAltitude: Double?
        public var targetDepth: Double?
        public var eta: Date?
        public var remainingDistance: Double = 0
    }
}

// MARK: - Universal Movement Command

public struct UniversalMovementCommand {
    public var direction: SIMD3<Double>  // Normalisiert (-1 bis 1)
    public var intensity: Double          // 0 bis 1
    public var domain: VehicleDomain

    // Konvertierungen zu domänenspezifischen Befehlen

    public func toLandCommand() -> LandMovementCommand {
        return LandMovementCommand(
            throttle: max(0, direction.y) * intensity,
            brake: max(0, -direction.y) * intensity,
            steering: direction.x * 45.0  // Max 45° Lenkung
        )
    }

    public func toAirCommand() -> AirMovementCommand {
        return AirMovementCommand(
            pitch: direction.y * 30.0,    // Max 30° Pitch
            roll: direction.x * 45.0,     // Max 45° Roll
            yaw: direction.z * 20.0,      // Max 20° Yaw
            throttle: intensity
        )
    }

    public func toWaterCommand() -> WaterMovementCommand {
        return WaterMovementCommand(
            throttle: direction.y * intensity,
            rudder: direction.x * 35.0    // Max 35° Ruder
        )
    }

    public func toUnderwaterCommand() -> UnderwaterMovementCommand {
        return UnderwaterMovementCommand(
            thrust: direction.y * intensity,
            lateral: direction.x * intensity,
            vertical: direction.z * intensity,
            yaw: 0
        )
    }
}

// MARK: - Domain-Specific Commands

public struct LandMovementCommand {
    public var throttle: Double = 0     // 0-1
    public var brake: Double = 0        // 0-1
    public var steering: Double = 0     // -45 bis +45 Grad
}

public struct AirMovementCommand {
    public var pitch: Double = 0        // Grad
    public var roll: Double = 0         // Grad
    public var yaw: Double = 0          // Grad
    public var throttle: Double = 0     // 0-1
    public var collective: Double = 0   // Für Helikopter
}

public struct WaterMovementCommand {
    public var throttle: Double = 0     // -1 bis 1 (Rückwärts möglich)
    public var rudder: Double = 0       // Grad
    public var trim: Double = 0         // Trimmung
}

public struct UnderwaterMovementCommand {
    public var thrust: Double = 0       // Vorwärts/Rückwärts
    public var lateral: Double = 0      // Seitlich
    public var vertical: Double = 0     // Auf/Ab
    public var yaw: Double = 0          // Drehung
}

// MARK: - Control Mode

public enum UniversalControlMode: String, CaseIterable, Codable {
    case manual             // Volle manuelle Kontrolle
    case assisted           // Assistenzsysteme aktiv
    case semiAutonomous     // Teilautonom
    case fullAutonomy       // Vollständig autonom
    case emergency          // Notfallmodus
}

// MARK: - Input Source Type

public enum InputSourceType: String, CaseIterable, Codable {
    case manual         // Gamepad, Joystick, Lenkrad
    case touch          // Touchscreen
    case gesture        // Handgesten
    case voice          // Sprachbefehle
    case gaze           // Blicksteuerung
    case neural         // Neuralink, EEG, etc.
    case autonomous     // KI-gesteuert
}

// MARK: - Configuration

public struct MultiDomainConfiguration: Codable {
    public var vehicleCapabilities: VehicleCapabilities = VehicleCapabilities()
    public var safetyLimits: SafetyLimits = SafetyLimits()

    public static let `default` = MultiDomainConfiguration()

    public static let amphibious = MultiDomainConfiguration(
        vehicleCapabilities: VehicleCapabilities(
            supportedDomains: [.land, .water],
            supportedTransitions: [
                DomainTransition(from: .land, to: .water),
                DomainTransition(from: .water, to: .land)
            ]
        )
    )

    public static let flyingCar = MultiDomainConfiguration(
        vehicleCapabilities: VehicleCapabilities(
            supportedDomains: [.land, .air],
            supportedTransitions: [
                DomainTransition(from: .land, to: .air),
                DomainTransition(from: .air, to: .land)
            ]
        )
    )

    public static let submersibleDrone = MultiDomainConfiguration(
        vehicleCapabilities: VehicleCapabilities(
            supportedDomains: [.air, .water, .underwater],
            supportedTransitions: [
                DomainTransition(from: .air, to: .water),
                DomainTransition(from: .water, to: .air),
                DomainTransition(from: .water, to: .underwater),
                DomainTransition(from: .underwater, to: .water),
                DomainTransition(from: .air, to: .underwater),
                DomainTransition(from: .underwater, to: .air)
            ]
        )
    )
}

public struct VehicleCapabilities: Codable {
    public var supportedDomains: Set<VehicleDomain> = [.land]
    public var supportedTransitions: Set<DomainTransition> = []

    public var maxSpeedLand: Double = 200       // km/h
    public var maxSpeedAir: Double = 300        // km/h
    public var maxSpeedWater: Double = 80       // km/h (Knoten * 1.852)
    public var maxSpeedUnderwater: Double = 20  // km/h

    public var maxAltitude: Double = 5000       // Meter
    public var maxDepth: Double = 100           // Meter
}

public struct SafetyLimits: Codable {
    public var minBatteryForOperation: Double = 0.2
    public var maxGForce: Double = 4.0
    public var minVisibility: Double = 100      // Meter
    public var maxWindSpeed: Double = 50        // km/h
    public var maxWaveHeight: Double = 3.0      // Meter
}

// MARK: - Hashable for Set

extension DomainTransition {
    public static func == (lhs: DomainTransition, rhs: DomainTransition) -> Bool {
        return lhs.from == rhs.from && lhs.to == rhs.to
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(from)
        hasher.combine(to)
    }
}

extension VehicleDomain: Hashable {}
