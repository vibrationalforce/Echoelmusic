import Foundation
import Combine
import CoreLocation
import simd

// MARK: - Vehicle Autopilot System
/// Autonomes Fahrsystem für Fahrzeuge ohne Fahrer
///
/// **Architektur (SAE Level 4/5):**
/// ```
/// Sensoren → Fusion → Wahrnehmung → Planung → Steuerung → Fahrzeug
///     ↑                                              ↓
///     └────────────── Feedback Loop ─────────────────┘
/// ```
///
/// **Unterstützte Fahrzeugtypen:**
/// - Autos, LKWs, Busse
/// - Elektrische Fahrzeuge
/// - Agrarmaschinen
/// - Baufahrzeuge
/// - Drohnen (Boden)
///
/// **Sicherheitsstufen (nach ISO 26262):**
/// - ASIL-D: Höchste Sicherheitsanforderung
/// - Redundante Systeme
/// - Fail-Safe Modi

@MainActor
public class VehicleAutopilot: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var isEnabled: Bool = false
    @Published public private(set) var mode: AutopilotDrivingMode = .manual
    @Published public private(set) var currentState: VehicleState = VehicleState()
    @Published public private(set) var navigationState: NavigationState = NavigationState()
    @Published public private(set) var safetyState: SafetyState = .nominal
    @Published public private(set) var diagnostics: AutopilotDiagnosticsData = AutopilotDiagnosticsData()

    // MARK: - Submodule

    private let sensorFusion: SensorFusionEngine
    private let perception: PerceptionEngine
    private let pathPlanner: PathPlannerEngine
    private let vehicleController: VehicleControlEngine
    private let safetySystem: DrivingSafetySystem

    // MARK: - Motor Controller (Integration mit SimulatorControlFramework)

    private var motorController: NetworkMotorController?
    private var connectedMotors: [String: MotorEndpoint] = [:]

    // MARK: - Control Loop

    private var controlTimer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    /// Steuerungsfrequenz (Hz) - höher = reaktionsschneller
    private let controlFrequency: Double = 50.0  // 50 Hz = 20ms Latenz

    // MARK: - Configuration

    public var configuration: VehicleAutopilotConfiguration

    // MARK: - Initialization

    public init(configuration: VehicleAutopilotConfiguration = .default) {
        self.configuration = configuration

        self.sensorFusion = SensorFusionEngine()
        self.perception = PerceptionEngine()
        self.pathPlanner = PathPlannerEngine()
        self.vehicleController = VehicleControlEngine()
        self.safetySystem = DrivingSafetySystem()

        setupInternalConnections()
    }

    // MARK: - Motor Connection

    /// Verbinde mit Fahrzeug-Motorsteuerung
    public func connectToVehicle(motors: [MotorEndpoint]) async throws {
        motorController = NetworkMotorController()

        for motor in motors {
            connectedMotors[motor.name] = motor
        }

        print("[VehicleAutopilot] Connected to \(motors.count) motors")
    }

    // MARK: - Sensor Input

    /// GPS-Position einspeisen
    public func feedGPS(_ location: CLLocation) {
        sensorFusion.updateGPS(location)
    }

    /// IMU-Daten einspeisen (Beschleunigung, Gyro)
    public func feedIMU(acceleration: SIMD3<Double>, gyro: SIMD3<Double>) {
        sensorFusion.updateIMU(acceleration: acceleration, gyro: gyro)
    }

    /// Kamerabild einspeisen
    public func feedCameraFrame(_ frame: CameraFrame) {
        perception.processCameraFrame(frame)
    }

    /// LiDAR-Punktwolke einspeisen
    public func feedLiDAR(_ pointCloud: LiDARPointCloud) {
        perception.processLiDAR(pointCloud)
    }

    /// Radar-Daten einspeisen
    public func feedRadar(_ data: RadarData) {
        perception.processRadar(data)
    }

    /// Ultraschall-Daten einspeisen
    public func feedUltrasonic(_ distances: [UltrasonicReading]) {
        sensorFusion.updateUltrasonic(distances)
    }

    /// Rad-Encoder einspeisen
    public func feedWheelEncoder(left: Double, right: Double) {
        sensorFusion.updateWheelEncoders(left: left, right: right)
    }

    // MARK: - Control

    /// Aktiviere Autopilot
    public func engage(mode: AutopilotDrivingMode = .fullAutonomy) {
        guard !isEnabled else { return }

        // Sicherheitsprüfung
        guard safetySystem.canEngage() else {
            print("[VehicleAutopilot] ❌ Cannot engage - safety check failed")
            return
        }

        self.mode = mode
        isEnabled = true

        startControlLoop()

        print("[VehicleAutopilot] ✅ Engaged in \(mode.displayName) mode")
    }

    /// Deaktiviere Autopilot
    public func disengage(reason: DisengageReason = .driverRequest) {
        guard isEnabled else { return }

        stopControlLoop()
        mode = .manual
        isEnabled = false

        // Sanfter Übergang zu manueller Steuerung
        vehicleController.transitionToManual()

        print("[VehicleAutopilot] ⏹ Disengaged: \(reason.rawValue)")
    }

    /// Notfall-Stopp
    public func emergencyStop() {
        print("[VehicleAutopilot] 🛑 EMERGENCY STOP")

        safetyState = .emergencyStopping

        // Sofortige Bremsung
        Task {
            await vehicleController.emergencyBrake()
        }

        disengage(reason: .emergency)
    }

    // MARK: - Navigation

    /// Setze Ziel
    public func setDestination(_ destination: CLLocationCoordinate2D) {
        navigationState.destination = destination
        navigationState.hasDestination = true

        // Route berechnen
        Task {
            await pathPlanner.calculateRoute(
                from: currentState.position,
                to: destination
            )
        }

        print("[VehicleAutopilot] 📍 Destination set")
    }

    /// Füge Wegpunkt hinzu
    public func addWaypoint(_ waypoint: CLLocationCoordinate2D) {
        navigationState.waypoints.append(waypoint)
    }

    /// Lösche Route
    public func clearRoute() {
        navigationState.destination = nil
        navigationState.hasDestination = false
        navigationState.waypoints.removeAll()
        pathPlanner.clearPath()
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
        guard isEnabled else { return }

        let startTime = Date()

        // 1. Sensor-Fusion
        let fusedState = sensorFusion.getFusedState()
        currentState = fusedState

        // 2. Wahrnehmung
        let perceivedEnvironment = perception.getEnvironment()

        // 3. Sicherheitsprüfung
        let safetyCheck = safetySystem.evaluate(
            vehicleState: fusedState,
            environment: perceivedEnvironment
        )

        if safetyCheck != .nominal {
            handleSafetyEvent(safetyCheck)
            return
        }

        // 4. Pfadplanung
        let trajectory = pathPlanner.planTrajectory(
            currentState: fusedState,
            environment: perceivedEnvironment,
            target: navigationState.currentTarget
        )

        // 5. Fahrzeugsteuerung
        let controlCommands = vehicleController.computeControl(
            currentState: fusedState,
            trajectory: trajectory
        )

        // 6. Befehle an Motoren senden
        Task {
            await sendControlCommands(controlCommands)
        }

        // Diagnostik
        let loopTime = Date().timeIntervalSince(startTime) * 1000
        diagnostics.lastLoopTimeMs = loopTime
        diagnostics.controlLoopCount += 1

        if loopTime > 1000.0 / controlFrequency {
            diagnostics.missedDeadlines += 1
        }
    }

    // MARK: - Motor Control

    private func sendControlCommands(_ commands: VehicleControlCommands) async {
        guard let controller = motorController else { return }

        // Lenkung
        if let steeringMotor = connectedMotors["steering"] {
            let steeringCommand = MotorCommand(
                motorId: steeringMotor.name,
                power: Float(commands.steeringAngle / 45.0),  // Normalisiert auf -1...1
                direction: commands.steeringAngle >= 0 ? .forward : .reverse
            )
            try? await controller.sendCommand(steeringCommand, to: steeringMotor)
        }

        // Antrieb
        if let driveMotor = connectedMotors["drive"] {
            let driveCommand = MotorCommand(
                motorId: driveMotor.name,
                power: Float(commands.throttle),
                direction: commands.gear == .reverse ? .reverse : .forward
            )
            try? await controller.sendCommand(driveCommand, to: driveMotor)
        }

        // Bremse
        if let brakeMotor = connectedMotors["brake"] {
            let brakeCommand = MotorCommand(
                motorId: brakeMotor.name,
                power: Float(commands.brakeForce),
                direction: .forward
            )
            try? await controller.sendCommand(brakeCommand, to: brakeMotor)
        }
    }

    // MARK: - Safety Handling

    private func handleSafetyEvent(_ state: SafetyState) {
        safetyState = state

        switch state {
        case .nominal:
            break

        case .warning(let reason):
            print("[VehicleAutopilot] ⚠️ Warning: \(reason)")
            // Reduziere Geschwindigkeit
            vehicleController.limitSpeed(to: configuration.warningSpeedLimit)

        case .critical(let reason):
            print("[VehicleAutopilot] 🔴 Critical: \(reason)")
            emergencyStop()

        case .collision(let timeToImpact):
            print("[VehicleAutopilot] 💥 Collision imminent in \(timeToImpact)s")
            emergencyStop()

        case .emergencyStopping:
            break  // Bereits am Stoppen

        case .stopped:
            disengage(reason: .safetyIntervention)
        }
    }

    // MARK: - Internal Setup

    private func setupInternalConnections() {
        // Perception → Safety System
        perception.$detectedObjects
            .sink { [weak self] objects in
                self?.safetySystem.updateDetectedObjects(objects)
            }
            .store(in: &cancellables)

        // Sensor Fusion → Vehicle State
        sensorFusion.$fusedState
            .assign(to: &$currentState)
    }
}

// MARK: - Driving Modes

public enum AutopilotDrivingMode: String, CaseIterable, Codable {
    case manual              // Fahrer hat volle Kontrolle
    case assistedSteering    // Lenkhilfe (Level 1)
    case adaptiveCruise      // ACC + Spurhalten (Level 2)
    case conditionalAutonomy // Autobahn-Autopilot (Level 3)
    case highAutonomy        // Stadtverkehr (Level 4)
    case fullAutonomy        // Keine Fahrer nötig (Level 5)

    public var displayName: String {
        switch self {
        case .manual: return "Manuell"
        case .assistedSteering: return "Lenkassistent"
        case .adaptiveCruise: return "Adaptiver Tempomat"
        case .conditionalAutonomy: return "Bedingte Autonomie"
        case .highAutonomy: return "Hohe Autonomie"
        case .fullAutonomy: return "Volle Autonomie"
        }
    }

    public var saeLevel: Int {
        switch self {
        case .manual: return 0
        case .assistedSteering: return 1
        case .adaptiveCruise: return 2
        case .conditionalAutonomy: return 3
        case .highAutonomy: return 4
        case .fullAutonomy: return 5
        }
    }
}

public enum DisengageReason: String, Codable {
    case driverRequest
    case systemFault
    case sensorFailure
    case safetyIntervention
    case weatherConditions
    case mapDataUnavailable
    case emergency
}

// MARK: - Safety State

public enum SafetyState: Equatable {
    case nominal
    case warning(String)
    case critical(String)
    case collision(timeToImpact: Double)
    case emergencyStopping
    case stopped
}

// MARK: - Vehicle State

public struct VehicleState: Codable {
    public var position: CLLocationCoordinate2D = CLLocationCoordinate2D()
    public var heading: Double = 0              // Grad (0 = Nord)
    public var speed: Double = 0                // m/s
    public var acceleration: SIMD3<Double> = .zero
    public var angularVelocity: SIMD3<Double> = .zero
    public var steeringAngle: Double = 0        // Grad
    public var gear: Gear = .park

    public var speedKmh: Double { speed * 3.6 }
    public var speedMph: Double { speed * 2.237 }

    public enum Gear: String, Codable {
        case park, reverse, neutral, drive
    }
}

// MARK: - Navigation State

public struct NavigationState: Codable {
    public var hasDestination: Bool = false
    public var destination: CLLocationCoordinate2D?
    public var waypoints: [CLLocationCoordinate2D] = []
    public var currentWaypointIndex: Int = 0
    public var remainingDistance: Double = 0    // Meter
    public var estimatedTimeOfArrival: Date?

    public var currentTarget: CLLocationCoordinate2D? {
        if currentWaypointIndex < waypoints.count {
            return waypoints[currentWaypointIndex]
        }
        return destination
    }
}

// MARK: - Control Commands

public struct VehicleControlCommands {
    public var throttle: Double = 0        // 0-1
    public var brakeForce: Double = 0      // 0-1
    public var steeringAngle: Double = 0   // -45 bis +45 Grad
    public var gear: VehicleState.Gear = .drive

    public static let neutral = VehicleControlCommands()

    public static func brake(force: Double) -> VehicleControlCommands {
        VehicleControlCommands(throttle: 0, brakeForce: force, steeringAngle: 0, gear: .drive)
    }
}

// MARK: - Diagnostics

public struct AutopilotDiagnosticsData: Codable {
    public var controlLoopCount: Int = 0
    public var lastLoopTimeMs: Double = 0
    public var missedDeadlines: Int = 0
    public var sensorHealth: [String: Bool] = [:]
    public var motorHealth: [String: Bool] = [:]
    public var lastError: String?
}

// MARK: - Configuration

public struct VehicleAutopilotConfiguration: Codable {
    public var maxSpeed: Double = 130           // km/h
    public var warningSpeedLimit: Double = 50   // km/h bei Warnungen
    public var minFollowDistance: Double = 2.0  // Sekunden
    public var maxSteeringRate: Double = 45     // Grad/s
    public var emergencyBrakeDecel: Double = 9.8 // m/s² (1g)

    public var useGPS: Bool = true
    public var useLiDAR: Bool = true
    public var useRadar: Bool = true
    public var useCameras: Bool = true
    public var useUltrasonic: Bool = true

    public static let `default` = VehicleAutopilotConfiguration()

    public static let urban = VehicleAutopilotConfiguration(
        maxSpeed: 50,
        warningSpeedLimit: 30,
        minFollowDistance: 3.0
    )

    public static let highway = VehicleAutopilotConfiguration(
        maxSpeed: 130,
        warningSpeedLimit: 80,
        minFollowDistance: 2.0
    )

    public static let offroad = VehicleAutopilotConfiguration(
        maxSpeed: 30,
        warningSpeedLimit: 15,
        minFollowDistance: 4.0,
        maxSteeringRate: 30
    )
}

// MARK: - Sensor Data Types

public struct CameraFrame {
    public let timestamp: Date
    public let width: Int
    public let height: Int
    public let data: Data
    public let cameraId: String

    public init(timestamp: Date = Date(), width: Int, height: Int, data: Data, cameraId: String) {
        self.timestamp = timestamp
        self.width = width
        self.height = height
        self.data = data
        self.cameraId = cameraId
    }
}

public struct LiDARPointCloud {
    public let timestamp: Date
    public let points: [SIMD3<Float>]
    public let intensities: [Float]?

    public init(timestamp: Date = Date(), points: [SIMD3<Float>], intensities: [Float]? = nil) {
        self.timestamp = timestamp
        self.points = points
        self.intensities = intensities
    }

    public var pointCount: Int { points.count }
}

public struct RadarData {
    public let timestamp: Date
    public let targets: [RadarTarget]

    public init(timestamp: Date = Date(), targets: [RadarTarget]) {
        self.timestamp = timestamp
        self.targets = targets
    }
}

public struct RadarTarget {
    public let distance: Double      // Meter
    public let velocity: Double      // m/s (relativ)
    public let angle: Double         // Grad
    public let rcs: Double           // Radar Cross Section (dBsm)

    public init(distance: Double, velocity: Double, angle: Double, rcs: Double) {
        self.distance = distance
        self.velocity = velocity
        self.angle = angle
        self.rcs = rcs
    }
}

public struct UltrasonicReading {
    public let sensorId: String
    public let distance: Double      // Meter (max ~5m)
    public let confidence: Double    // 0-1

    public init(sensorId: String, distance: Double, confidence: Double = 1.0) {
        self.sensorId = sensorId
        self.distance = distance
        self.confidence = confidence
    }
}

// MARK: - CLLocationCoordinate2D Codable Extension

extension CLLocationCoordinate2D: Codable {
    enum CodingKeys: String, CodingKey {
        case latitude, longitude
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lon = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: lat, longitude: lon)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
}
