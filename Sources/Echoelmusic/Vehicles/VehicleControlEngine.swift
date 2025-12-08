import Foundation
import Network
import Combine
import CoreLocation
import simd
import os.log

// ═══════════════════════════════════════════════════════════════════════════════
// ECHOELMUSIC VEHICLE CONTROL ENGINE
// ═══════════════════════════════════════════════════════════════════════════════
//
// Comprehensive vehicle integration for bio-reactive and audio-reactive control
//
// Supported Vehicles:
// 🚁 Drones     - DJI SDK, MAVLink (PX4/ArduPilot), custom
// 🚗 Cars       - CAN bus, OBD-II, Tesla API, custom LED
// 🚢 Ships      - NMEA 0183/2000, marine autopilot
// 🎪 Stage      - DMX platforms, moving trusses
// 🤖 Robots     - ROS2, custom protocols
//
// Features:
// • Bio-reactive control (HRV/coherence → vehicle behavior)
// • Audio-reactive effects (music → lights/movement)
// • Swarm choreography (synchronized multi-vehicle patterns)
// • GPS-based formations
// • Safety interlocks and geofencing
//
// ═══════════════════════════════════════════════════════════════════════════════

private let logger = Logger(subsystem: "com.echoelmusic.vehicles", category: "Control")

// MARK: - Vehicle Protocol

/// Base protocol for all controllable vehicles
public protocol ControllableVehicle: AnyObject, Identifiable {
    var id: UUID { get }
    var name: String { get }
    var type: VehicleType { get }
    var connectionState: VehicleConnectionState { get }
    var position: VehiclePosition { get }
    var capabilities: VehicleCapabilities { get }
    var safetyState: VehicleSafetyState { get }

    func connect() async throws
    func disconnect() async
    func emergencyStop() async

    // Control methods
    func setTarget(position: VehiclePosition) async throws
    func setLighting(color: VehicleColor, effect: LightingEffect) async throws
    func executeCommand(_ command: VehicleCommand) async throws
}

// MARK: - Vehicle Types

public enum VehicleType: String, Codable, CaseIterable, Sendable {
    // Aerial
    case drone = "Drone"
    case droneSwarm = "Drone Swarm"
    case helicopter = "Helicopter"

    // Ground
    case car = "Car"
    case truck = "Truck"
    case motorcycle = "Motorcycle"
    case robotCar = "Robot Car"
    case golfCart = "Golf Cart"

    // Marine
    case boat = "Boat"
    case yacht = "Yacht"
    case jetski = "Jet Ski"
    case submarine = "Submarine"

    // Stage/Event
    case movingPlatform = "Moving Platform"
    case movingTruss = "Moving Truss"
    case robotArm = "Robot Arm"
    case flyingRig = "Flying Rig"

    // Other
    case custom = "Custom"

    public var icon: String {
        switch self {
        case .drone, .droneSwarm: return "airplane"
        case .helicopter: return "helicopter"
        case .car, .robotCar: return "car.fill"
        case .truck: return "truck.box.fill"
        case .motorcycle: return "bicycle"
        case .golfCart: return "car.side"
        case .boat, .yacht: return "ferry.fill"
        case .jetski: return "water.waves"
        case .submarine: return "drop.fill"
        case .movingPlatform: return "square.fill.on.square"
        case .movingTruss: return "rectangle.3.group"
        case .robotArm: return "hand.point.up.fill"
        case .flyingRig: return "person.fill.and.arrow.left.and.arrow.right"
        case .custom: return "gearshape.fill"
        }
    }

    public var supportsFlying: Bool {
        switch self {
        case .drone, .droneSwarm, .helicopter, .flyingRig: return true
        default: return false
        }
    }

    public var supportsSwimming: Bool {
        switch self {
        case .boat, .yacht, .jetski, .submarine: return true
        default: return false
        }
    }
}

// MARK: - Vehicle Position

public struct VehiclePosition: Codable, Sendable {
    // GPS coordinates (WGS84)
    public var latitude: Double
    public var longitude: Double
    public var altitude: Double  // meters above sea level

    // Local coordinates (relative to origin)
    public var localX: Float  // meters
    public var localY: Float  // meters
    public var localZ: Float  // meters (up)

    // Orientation
    public var heading: Float  // degrees (0-360, 0=North)
    public var pitch: Float    // degrees (-90 to 90)
    public var roll: Float     // degrees (-180 to 180)

    // Velocity
    public var velocityX: Float  // m/s
    public var velocityY: Float  // m/s
    public var velocityZ: Float  // m/s
    public var speed: Float      // ground speed m/s

    public init(
        latitude: Double = 0,
        longitude: Double = 0,
        altitude: Double = 0,
        localX: Float = 0,
        localY: Float = 0,
        localZ: Float = 0,
        heading: Float = 0,
        pitch: Float = 0,
        roll: Float = 0
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.localX = localX
        self.localY = localY
        self.localZ = localZ
        self.heading = heading
        self.pitch = pitch
        self.roll = roll
        self.velocityX = 0
        self.velocityY = 0
        self.velocityZ = 0
        self.speed = 0
    }

    /// Distance to another position (meters)
    public func distance(to other: VehiclePosition) -> Float {
        let dx = other.localX - localX
        let dy = other.localY - localY
        let dz = other.localZ - localZ
        return sqrt(dx * dx + dy * dy + dz * dz)
    }

    /// As SIMD vector (local coords)
    public var simdPosition: simd_float3 {
        simd_float3(localX, localY, localZ)
    }
}

// MARK: - Vehicle Connection State

public enum VehicleConnectionState: String, Codable, Sendable {
    case disconnected = "Disconnected"
    case connecting = "Connecting"
    case connected = "Connected"
    case armed = "Armed"      // Ready for movement
    case active = "Active"    // Currently moving
    case error = "Error"
    case emergencyStop = "Emergency Stop"

    public var color: String {
        switch self {
        case .disconnected: return "gray"
        case .connecting: return "yellow"
        case .connected: return "green"
        case .armed: return "blue"
        case .active: return "cyan"
        case .error: return "red"
        case .emergencyStop: return "red"
        }
    }

    public var isOperational: Bool {
        switch self {
        case .connected, .armed, .active: return true
        default: return false
        }
    }
}

// MARK: - Vehicle Capabilities

public struct VehicleCapabilities: OptionSet, Codable, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    // Movement
    public static let move3D = VehicleCapabilities(rawValue: 1 << 0)
    public static let move2D = VehicleCapabilities(rawValue: 1 << 1)
    public static let hover = VehicleCapabilities(rawValue: 1 << 2)
    public static let rotate = VehicleCapabilities(rawValue: 1 << 3)

    // Features
    public static let lighting = VehicleCapabilities(rawValue: 1 << 4)
    public static let camera = VehicleCapabilities(rawValue: 1 << 5)
    public static let audio = VehicleCapabilities(rawValue: 1 << 6)
    public static let sensors = VehicleCapabilities(rawValue: 1 << 7)

    // Communication
    public static let gps = VehicleCapabilities(rawValue: 1 << 8)
    public static let wifi = VehicleCapabilities(rawValue: 1 << 9)
    public static let cellular = VehicleCapabilities(rawValue: 1 << 10)
    public static let radio = VehicleCapabilities(rawValue: 1 << 11)

    // Safety
    public static let geofencing = VehicleCapabilities(rawValue: 1 << 12)
    public static let obstacleAvoidance = VehicleCapabilities(rawValue: 1 << 13)
    public static let returnToHome = VehicleCapabilities(rawValue: 1 << 14)
    public static let parachute = VehicleCapabilities(rawValue: 1 << 15)

    // Common sets
    public static let drone: VehicleCapabilities = [.move3D, .hover, .rotate, .lighting, .camera, .gps, .wifi, .geofencing, .obstacleAvoidance, .returnToHome]
    public static let car: VehicleCapabilities = [.move2D, .rotate, .lighting, .sensors, .gps, .wifi, .cellular]
    public static let boat: VehicleCapabilities = [.move2D, .rotate, .lighting, .sensors, .gps, .radio]
    public static let stagePlatform: VehicleCapabilities = [.move3D, .rotate, .lighting]
}

// MARK: - Vehicle Safety State

public struct VehicleSafetyState: Codable, Sendable {
    public var batteryLevel: Float      // 0-1
    public var batteryVoltage: Float    // Volts
    public var signalStrength: Float    // 0-1
    public var gpsAccuracy: Float       // meters
    public var temperature: Float       // Celsius
    public var isGeofenceOK: Bool
    public var isObstacleClear: Bool
    public var isEmergencyActive: Bool
    public var errorCodes: [Int]

    public init() {
        self.batteryLevel = 1.0
        self.batteryVoltage = 0
        self.signalStrength = 1.0
        self.gpsAccuracy = 10
        self.temperature = 25
        self.isGeofenceOK = true
        self.isObstacleClear = true
        self.isEmergencyActive = false
        self.errorCodes = []
    }

    public var isSafe: Bool {
        batteryLevel > 0.2 &&
        signalStrength > 0.3 &&
        isGeofenceOK &&
        isObstacleClear &&
        !isEmergencyActive &&
        errorCodes.isEmpty
    }

    public var warningMessage: String? {
        if batteryLevel < 0.2 { return "Low battery" }
        if signalStrength < 0.3 { return "Weak signal" }
        if !isGeofenceOK { return "Outside geofence" }
        if !isObstacleClear { return "Obstacle detected" }
        if isEmergencyActive { return "Emergency active" }
        if !errorCodes.isEmpty { return "Error: \(errorCodes)" }
        return nil
    }
}

// MARK: - Vehicle Color & Lighting

public struct VehicleColor: Codable, Sendable {
    public var red: Float    // 0-1
    public var green: Float  // 0-1
    public var blue: Float   // 0-1
    public var white: Float  // 0-1 (for RGBW)
    public var intensity: Float  // 0-1

    public init(red: Float = 1, green: Float = 1, blue: Float = 1, white: Float = 0, intensity: Float = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.white = white
        self.intensity = intensity
    }

    public static let off = VehicleColor(red: 0, green: 0, blue: 0, intensity: 0)
    public static let white = VehicleColor(red: 1, green: 1, blue: 1)
    public static let red = VehicleColor(red: 1, green: 0, blue: 0)
    public static let green = VehicleColor(red: 0, green: 1, blue: 0)
    public static let blue = VehicleColor(red: 0, green: 0, blue: 1)
    public static let cyan = VehicleColor(red: 0, green: 1, blue: 1)
    public static let magenta = VehicleColor(red: 1, green: 0, blue: 1)
    public static let yellow = VehicleColor(red: 1, green: 1, blue: 0)

    /// Create from HSV
    public static func fromHSV(hue: Float, saturation: Float, brightness: Float) -> VehicleColor {
        let c = brightness * saturation
        let x = c * (1 - abs(fmod(hue * 6, 2) - 1))
        let m = brightness - c

        var r: Float = 0, g: Float = 0, b: Float = 0
        let h6 = Int(hue * 6) % 6

        switch h6 {
        case 0: r = c; g = x; b = 0
        case 1: r = x; g = c; b = 0
        case 2: r = 0; g = c; b = x
        case 3: r = 0; g = x; b = c
        case 4: r = x; g = 0; b = c
        case 5: r = c; g = 0; b = x
        default: break
        }

        return VehicleColor(red: r + m, green: g + m, blue: b + m)
    }
}

public enum LightingEffect: String, Codable, CaseIterable, Sendable {
    case solid = "Solid"
    case pulse = "Pulse"
    case strobe = "Strobe"
    case rainbow = "Rainbow"
    case chase = "Chase"
    case breathe = "Breathe"
    case audioReactive = "Audio Reactive"
    case bioReactive = "Bio Reactive"
    case colorFade = "Color Fade"
    case sparkle = "Sparkle"
    case fire = "Fire"
    case water = "Water"
    case off = "Off"

    public var requiresAnimation: Bool {
        switch self {
        case .solid, .off: return false
        default: return true
        }
    }
}

// MARK: - Vehicle Commands

public enum VehicleCommand: Codable, Sendable {
    // Basic movement
    case moveTo(position: VehiclePosition, speed: Float)
    case moveBy(dx: Float, dy: Float, dz: Float, speed: Float)
    case rotateTo(heading: Float, speed: Float)
    case rotateBy(degrees: Float, speed: Float)

    // Flight specific
    case takeoff(altitude: Float)
    case land
    case hover
    case returnToHome

    // Speed/throttle
    case setSpeed(Float)
    case setThrottle(Float)

    // Lighting
    case setColor(VehicleColor)
    case setEffect(LightingEffect)

    // Camera
    case pointCamera(pitch: Float, yaw: Float)
    case startRecording
    case stopRecording
    case takePhoto

    // Formation
    case joinFormation(formationID: UUID, slot: Int)
    case leaveFormation

    // Safety
    case arm
    case disarm
    case emergencyStop
    case setGeofence(center: VehiclePosition, radius: Float)

    // Custom
    case custom(name: String, parameters: [String: Float])
}

// MARK: - Vehicle Control Engine

@MainActor
public final class VehicleControlEngine: ObservableObject {

    public static let shared = VehicleControlEngine()

    // MARK: - Published State

    @Published public private(set) var vehicles: [UUID: any ControllableVehicle] = [:]
    @Published public private(set) var activeFormations: [VehicleFormation] = []
    @Published public private(set) var isEmergencyActive: Bool = false

    // Bio-reactive state
    @Published public var bioCoherence: Float = 0.5
    @Published public var bioHRV: Float = 50
    @Published public var heartRate: Float = 72

    // Audio-reactive state
    @Published public var audioLevel: Float = 0
    @Published public var audioBass: Float = 0
    @Published public var audioMid: Float = 0
    @Published public var audioHigh: Float = 0
    @Published public var audioBPM: Float = 120

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?
    private let updateRate: TimeInterval = 1.0 / 30.0  // 30 Hz

    // MARK: - Initialization

    private init() {
        logger.info("VehicleControlEngine initialized")
    }

    // MARK: - Vehicle Management

    /// Register a vehicle
    public func registerVehicle(_ vehicle: any ControllableVehicle) {
        vehicles[vehicle.id] = vehicle
        logger.info("Registered vehicle: \(vehicle.name) (\(vehicle.type.rawValue))")
    }

    /// Unregister a vehicle
    public func unregisterVehicle(id: UUID) {
        if let vehicle = vehicles.removeValue(forKey: id) {
            logger.info("Unregistered vehicle: \(vehicle.name)")
        }
    }

    /// Get vehicle by ID
    public func vehicle(id: UUID) -> (any ControllableVehicle)? {
        vehicles[id]
    }

    /// Get all vehicles of a type
    public func vehicles(ofType type: VehicleType) -> [any ControllableVehicle] {
        vehicles.values.filter { $0.type == type }
    }

    // MARK: - Emergency Control

    /// Trigger emergency stop for all vehicles
    public func emergencyStopAll() async {
        logger.critical("EMERGENCY STOP TRIGGERED")
        isEmergencyActive = true

        for vehicle in vehicles.values {
            do {
                try await vehicle.emergencyStop()
            } catch {
                logger.error("Emergency stop failed for \(vehicle.name): \(error)")
            }
        }
    }

    /// Clear emergency state
    public func clearEmergency() {
        isEmergencyActive = false
        logger.info("Emergency state cleared")
    }

    // MARK: - Formation Control

    /// Create a new formation
    public func createFormation(
        name: String,
        pattern: FormationPattern,
        vehicleIDs: [UUID]
    ) -> VehicleFormation {
        let formation = VehicleFormation(
            name: name,
            pattern: pattern,
            vehicleIDs: vehicleIDs
        )
        activeFormations.append(formation)
        logger.info("Created formation: \(name) with \(vehicleIDs.count) vehicles")
        return formation
    }

    /// Update formation positions
    public func updateFormation(_ formation: VehicleFormation, center: VehiclePosition) async {
        let positions = formation.pattern.calculatePositions(
            vehicleCount: formation.vehicleIDs.count,
            center: center,
            scale: formation.scale
        )

        for (index, vehicleID) in formation.vehicleIDs.enumerated() {
            guard let vehicle = vehicles[vehicleID],
                  index < positions.count else { continue }

            do {
                try await vehicle.setTarget(position: positions[index])
            } catch {
                logger.error("Formation update failed for vehicle \(vehicle.name): \(error)")
            }
        }
    }

    // MARK: - Bio-Reactive Control

    /// Apply bio-reactive effects to all vehicles
    public func applyBioReactiveEffects() async {
        // Color based on coherence (red → green → cyan)
        let hue = bioCoherence * 0.5  // 0 = red, 0.5 = cyan
        let saturation: Float = 0.8
        let brightness = 0.5 + bioCoherence * 0.5

        let color = VehicleColor.fromHSV(hue: hue, saturation: saturation, brightness: brightness)

        // Pulse speed based on heart rate
        // let pulseRate = heartRate / 60.0  // Hz

        for vehicle in vehicles.values {
            guard vehicle.capabilities.contains(.lighting) else { continue }

            do {
                try await vehicle.setLighting(color: color, effect: .bioReactive)
            } catch {
                logger.error("Bio-reactive effect failed for \(vehicle.name): \(error)")
            }
        }
    }

    // MARK: - Audio-Reactive Control

    /// Apply audio-reactive effects to all vehicles
    public func applyAudioReactiveEffects() async {
        // Color based on frequency content
        let color = VehicleColor(
            red: audioBass,
            green: audioMid,
            blue: audioHigh,
            intensity: audioLevel
        )

        for vehicle in vehicles.values {
            guard vehicle.capabilities.contains(.lighting) else { continue }

            do {
                try await vehicle.setLighting(color: color, effect: .audioReactive)
            } catch {
                logger.error("Audio-reactive effect failed for \(vehicle.name): \(error)")
            }
        }
    }

    // MARK: - Update Loop

    /// Start the control loop
    public func start() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateRate, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.update()
            }
        }
        logger.info("Vehicle control loop started")
    }

    /// Stop the control loop
    public func stop() {
        updateTimer?.invalidate()
        updateTimer = nil
        logger.info("Vehicle control loop stopped")
    }

    private func update() {
        // Update formations, animations, etc.
        for formation in activeFormations where formation.isActive {
            // Formation animations would be processed here
        }
    }
}

// MARK: - Vehicle Formation

public struct VehicleFormation: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var pattern: FormationPattern
    public var vehicleIDs: [UUID]
    public var scale: Float = 10.0  // meters
    public var isActive: Bool = true
    public var animationSpeed: Float = 1.0

    public init(name: String, pattern: FormationPattern, vehicleIDs: [UUID]) {
        self.id = UUID()
        self.name = name
        self.pattern = pattern
        self.vehicleIDs = vehicleIDs
    }
}

// MARK: - Formation Patterns

public enum FormationPattern: String, Codable, CaseIterable, Sendable {
    case line = "Line"
    case circle = "Circle"
    case grid = "Grid"
    case vShape = "V Shape"
    case diamond = "Diamond"
    case spiral = "Spiral"
    case sphere = "Sphere"
    case cube = "Cube"
    case heart = "Heart"
    case star = "Star"
    case wave = "Wave"
    case custom = "Custom"

    /// Calculate positions for vehicles in formation
    public func calculatePositions(vehicleCount: Int, center: VehiclePosition, scale: Float) -> [VehiclePosition] {
        var positions: [VehiclePosition] = []

        switch self {
        case .line:
            let spacing = scale / Float(max(1, vehicleCount - 1))
            let startX = center.localX - scale / 2
            for i in 0..<vehicleCount {
                var pos = center
                pos.localX = startX + Float(i) * spacing
                positions.append(pos)
            }

        case .circle:
            let angleStep = 2 * Float.pi / Float(vehicleCount)
            let radius = scale / 2
            for i in 0..<vehicleCount {
                let angle = Float(i) * angleStep
                var pos = center
                pos.localX = center.localX + cos(angle) * radius
                pos.localY = center.localY + sin(angle) * radius
                positions.append(pos)
            }

        case .grid:
            let cols = Int(ceil(sqrt(Float(vehicleCount))))
            let rows = Int(ceil(Float(vehicleCount) / Float(cols)))
            let spacingX = scale / Float(max(1, cols - 1))
            let spacingY = scale / Float(max(1, rows - 1))

            for i in 0..<vehicleCount {
                let col = i % cols
                let row = i / cols
                var pos = center
                pos.localX = center.localX - scale / 2 + Float(col) * spacingX
                pos.localY = center.localY - scale / 2 + Float(row) * spacingY
                positions.append(pos)
            }

        case .vShape:
            let halfCount = vehicleCount / 2
            let spacing = scale / Float(max(1, halfCount))

            // Leader
            positions.append(center)

            // Left wing
            for i in 1...halfCount {
                var pos = center
                pos.localX = center.localX - Float(i) * spacing * 0.7
                pos.localY = center.localY - Float(i) * spacing
                positions.append(pos)
            }

            // Right wing
            for i in 1...(vehicleCount - halfCount - 1) {
                var pos = center
                pos.localX = center.localX + Float(i) * spacing * 0.7
                pos.localY = center.localY - Float(i) * spacing
                positions.append(pos)
            }

        case .diamond:
            let quarter = vehicleCount / 4
            let spacing = scale / Float(max(1, quarter))

            // Top
            positions.append(VehiclePosition(localX: center.localX, localY: center.localY + scale / 2, localZ: center.localZ))

            // Sides
            for i in 1..<quarter {
                let offset = Float(i) * spacing / 2
                positions.append(VehiclePosition(localX: center.localX - offset, localY: center.localY + scale / 2 - Float(i) * spacing, localZ: center.localZ))
                positions.append(VehiclePosition(localX: center.localX + offset, localY: center.localY + scale / 2 - Float(i) * spacing, localZ: center.localZ))
            }

            // Bottom
            positions.append(VehiclePosition(localX: center.localX, localY: center.localY - scale / 2, localZ: center.localZ))

        case .sphere:
            // 3D sphere distribution using Fibonacci spiral
            let goldenRatio = (1 + sqrt(5.0)) / 2.0
            let radius = scale / 2

            for i in 0..<vehicleCount {
                let theta = 2 * Float.pi * Float(i) / Float(goldenRatio)
                let phi = acos(1 - 2 * Float(i + 1) / Float(vehicleCount + 1))

                var pos = center
                pos.localX = center.localX + radius * sin(phi) * cos(theta)
                pos.localY = center.localY + radius * sin(phi) * sin(theta)
                pos.localZ = center.localZ + radius * cos(phi)
                positions.append(pos)
            }

        case .spiral:
            let turns: Float = 3.0
            let maxAngle = turns * 2 * Float.pi
            let radiusStep = scale / 2 / Float(vehicleCount)

            for i in 0..<vehicleCount {
                let angle = Float(i) / Float(vehicleCount) * maxAngle
                let radius = Float(i + 1) * radiusStep

                var pos = center
                pos.localX = center.localX + cos(angle) * radius
                pos.localY = center.localY + sin(angle) * radius
                positions.append(pos)
            }

        case .heart:
            // Parametric heart shape
            for i in 0..<vehicleCount {
                let t = Float(i) / Float(vehicleCount) * 2 * Float.pi
                let x = 16 * pow(sin(t), 3)
                let y = 13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)

                var pos = center
                pos.localX = center.localX + x * scale / 32
                pos.localY = center.localY + y * scale / 32
                positions.append(pos)
            }

        case .star:
            // 5-pointed star
            let innerRadius = scale / 4
            let outerRadius = scale / 2

            for i in 0..<vehicleCount {
                let angle = Float(i) * 2 * Float.pi / Float(vehicleCount) - Float.pi / 2
                let radius = (i % 2 == 0) ? outerRadius : innerRadius

                var pos = center
                pos.localX = center.localX + cos(angle) * radius
                pos.localY = center.localY + sin(angle) * radius
                positions.append(pos)
            }

        case .cube:
            // 3D cube corners and edges
            let half = scale / 2
            let corners: [simd_float3] = [
                simd_float3(-half, -half, -half),
                simd_float3(half, -half, -half),
                simd_float3(-half, half, -half),
                simd_float3(half, half, -half),
                simd_float3(-half, -half, half),
                simd_float3(half, -half, half),
                simd_float3(-half, half, half),
                simd_float3(half, half, half)
            ]

            for i in 0..<min(vehicleCount, corners.count) {
                let offset = corners[i]
                var pos = center
                pos.localX = center.localX + offset.x
                pos.localY = center.localY + offset.y
                pos.localZ = center.localZ + offset.z
                positions.append(pos)
            }

        case .wave:
            let spacing = scale / Float(vehicleCount)
            for i in 0..<vehicleCount {
                var pos = center
                pos.localX = center.localX - scale / 2 + Float(i) * spacing
                pos.localZ = center.localZ + sin(Float(i) * 0.5) * scale / 4
                positions.append(pos)
            }

        case .custom:
            // Return current center for custom handling
            for _ in 0..<vehicleCount {
                positions.append(center)
            }
        }

        // Ensure we have enough positions
        while positions.count < vehicleCount {
            positions.append(center)
        }

        return Array(positions.prefix(vehicleCount))
    }
}

// MARK: - Geofence

public struct Geofence: Codable, Sendable {
    public let id: UUID
    public var name: String
    public var center: VehiclePosition
    public var radius: Float          // meters (horizontal)
    public var minAltitude: Float     // meters
    public var maxAltitude: Float     // meters
    public var isActive: Bool

    public init(name: String, center: VehiclePosition, radius: Float, minAltitude: Float = 0, maxAltitude: Float = 120) {
        self.id = UUID()
        self.name = name
        self.center = center
        self.radius = radius
        self.minAltitude = minAltitude
        self.maxAltitude = maxAltitude
        self.isActive = true
    }

    /// Check if position is within geofence
    public func contains(_ position: VehiclePosition) -> Bool {
        let horizontalDistance = sqrt(
            pow(position.localX - center.localX, 2) +
            pow(position.localY - center.localY, 2)
        )

        let altitude = position.localZ

        return horizontalDistance <= radius &&
               altitude >= minAltitude &&
               altitude <= maxAltitude
    }
}
