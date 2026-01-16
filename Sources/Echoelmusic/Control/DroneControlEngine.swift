import Foundation
import CoreLocation
#if canImport(Combine)
import Combine
#endif

// ╔═══════════════════════════════════════════════════════════════════════════════════════════════════════╗
// ║                                                                                                       ║
// ║   ██████╗ ██████╗  ██████╗ ███╗   ██╗███████╗     ██████╗ ██████╗ ███╗   ██╗████████╗██████╗  ██████╗ ║
// ║   ██╔══██╗██╔══██╗██╔═══██╗████╗  ██║██╔════╝    ██╔════╝██╔═══██╗████╗  ██║╚══██╔══╝██╔══██╗██╔═══██╗║
// ║   ██║  ██║██████╔╝██║   ██║██╔██╗ ██║█████╗      ██║     ██║   ██║██╔██╗ ██║   ██║   ██████╔╝██║   ██║║
// ║   ██║  ██║██╔══██╗██║   ██║██║╚██╗██║██╔══╝      ██║     ██║   ██║██║╚██╗██║   ██║   ██╔══██╗██║   ██║║
// ║   ██████╔╝██║  ██║╚██████╔╝██║ ╚████║███████╗    ╚██████╗╚██████╔╝██║ ╚████║   ██║   ██║  ██║╚██████╔╝║
// ║   ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝     ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝ ║
// ║                                                                                                       ║
// ║   🚁 DRONE CONTROL ENGINE - MAVLink Protocol Implementation 🚁                                        ║
// ║                                                                                                       ║
// ║   DJI • ArduPilot • PX4 • Custom Drones • Bio-Reactive Flight • Waypoints                            ║
// ║                                                                                                       ║
// ║   ⚠️ SAFETY WARNING: Always follow local regulations. Maintain line of sight.                        ║
// ║   This is a control INTERFACE - actual flight requires certified hardware.                           ║
// ║                                                                                                       ║
// ╚═══════════════════════════════════════════════════════════════════════════════════════════════════════╝

// MARK: - Safety Disclaimer

public struct DroneControlDisclaimer {
    public static let safety = """
    ⚠️ CRITICAL SAFETY WARNING / WICHTIGE SICHERHEITSWARNUNG:

    1. ALWAYS follow local aviation regulations (FAA, EASA, etc.)
    2. NEVER fly over people, crowds, or restricted areas
    3. MAINTAIN visual line of sight at all times
    4. CHECK weather conditions before flight
    5. ENSURE batteries are fully charged
    6. REGISTER your drone if required by law
    7. This software is a CONTROL INTERFACE only
    8. Actual flight requires certified, approved hardware
    9. Bio-reactive features are EXPERIMENTAL - use manual override

    Echoelmusic is NOT responsible for accidents, injuries, or legal violations.
    By using this feature, you accept full responsibility for safe operation.

    IMMER lokale Luftfahrtvorschriften befolgen. Sichtkontakt halten.
    """

    public static let accepted: Bool = false
}

// MARK: - Drone Type

public enum DroneManufacturer: String, CaseIterable, Codable {
    case dji = "DJI"
    case ardupilot = "ArduPilot"
    case px4 = "PX4"
    case parrot = "Parrot"
    case autel = "Autel"
    case skydio = "Skydio"
    case custom = "Custom MAVLink"

    public var icon: String {
        switch self {
        case .dji: return "🇨🇳"
        case .ardupilot: return "🔧"
        case .px4: return "📡"
        case .parrot: return "🦜"
        case .autel: return "🎬"
        case .skydio: return "🤖"
        case .custom: return "⚙️"
        }
    }

    public var supportsMAVLink: Bool {
        switch self {
        case .ardupilot, .px4, .custom: return true
        case .dji, .parrot, .autel, .skydio: return false // Use proprietary SDK
        }
    }
}

public enum DroneType: String, CaseIterable, Codable {
    case quadcopter = "Quadcopter"
    case hexacopter = "Hexacopter"
    case octocopter = "Octocopter"
    case fixedWing = "Fixed Wing"
    case vtol = "VTOL"
    case submarine = "Underwater ROV"
    case rover = "Ground Rover"

    public var icon: String {
        switch self {
        case .quadcopter: return "🚁"
        case .hexacopter: return "⬡"
        case .octocopter: return "✴️"
        case .fixedWing: return "✈️"
        case .vtol: return "🛩️"
        case .submarine: return "🤿"
        case .rover: return "🛻"
        }
    }
}

// MARK: - Flight Mode

public enum FlightMode: String, CaseIterable, Codable {
    case manual = "Manual"
    case stabilize = "Stabilize"
    case altitudeHold = "Altitude Hold"
    case positionHold = "Position Hold"
    case loiter = "Loiter"
    case returnToHome = "Return to Home"
    case waypoint = "Waypoint"
    case followMe = "Follow Me"
    case orbit = "Orbit"
    case sport = "Sport"
    case cinematic = "Cinematic"
    case tripod = "Tripod"
    case bioReactive = "Bio-Reactive"
    case autoLand = "Auto Land"
    case emergency = "Emergency"

    public var icon: String {
        switch self {
        case .manual: return "🎮"
        case .stabilize: return "⚖️"
        case .altitudeHold: return "📏"
        case .positionHold: return "📍"
        case .loiter: return "🔄"
        case .returnToHome: return "🏠"
        case .waypoint: return "📌"
        case .followMe: return "🏃"
        case .orbit: return "🌀"
        case .sport: return "🏎️"
        case .cinematic: return "🎬"
        case .tripod: return "📸"
        case .bioReactive: return "💓"
        case .autoLand: return "⬇️"
        case .emergency: return "🆘"
        }
    }

    public var requiresGPS: Bool {
        switch self {
        case .manual, .stabilize, .altitudeHold, .emergency: return false
        default: return true
        }
    }

    public var maxSpeed: Double { // m/s
        switch self {
        case .tripod: return 1.0
        case .cinematic: return 5.0
        case .bioReactive: return 8.0
        case .manual, .stabilize, .altitudeHold, .positionHold, .loiter: return 15.0
        case .sport: return 25.0
        default: return 10.0
        }
    }
}

// MARK: - Drone State

public struct DroneState: Codable, Equatable {
    // Position
    public var latitude: Double
    public var longitude: Double
    public var altitude: Double           // meters above takeoff
    public var altitudeASL: Double        // meters above sea level
    public var heading: Double            // degrees (0-360)

    // Velocity
    public var groundSpeed: Double        // m/s
    public var verticalSpeed: Double      // m/s (positive = up)
    public var airSpeed: Double           // m/s

    // Attitude
    public var roll: Double               // degrees
    public var pitch: Double              // degrees
    public var yaw: Double                // degrees

    // System
    public var batteryPercent: Float
    public var batteryVoltage: Float
    public var flightTimeRemaining: Int   // seconds
    public var signalStrength: Float      // 0-1
    public var gpsFixType: GPSFixType
    public var satelliteCount: Int

    // Status
    public var isArmed: Bool
    public var isFlying: Bool
    public var flightMode: FlightMode
    public var homeLocation: CLLocationCoordinate2D?
    public var distanceToHome: Double     // meters

    // Sensors
    public var temperature: Float?        // celsius
    public var humidity: Float?
    public var windSpeed: Float?          // m/s (estimated)

    public init() {
        latitude = 0
        longitude = 0
        altitude = 0
        altitudeASL = 0
        heading = 0
        groundSpeed = 0
        verticalSpeed = 0
        airSpeed = 0
        roll = 0
        pitch = 0
        yaw = 0
        batteryPercent = 1.0
        batteryVoltage = 16.8
        flightTimeRemaining = 1800
        signalStrength = 1.0
        gpsFixType = .noFix
        satelliteCount = 0
        isArmed = false
        isFlying = false
        flightMode = .manual
        homeLocation = nil
        distanceToHome = 0
    }
}

public enum GPSFixType: String, Codable {
    case noFix = "No Fix"
    case fix2D = "2D Fix"
    case fix3D = "3D Fix"
    case dgps = "DGPS"
    case rtk = "RTK Fixed"
    case rtkFloat = "RTK Float"

    public var icon: String {
        switch self {
        case .noFix: return "📡❌"
        case .fix2D: return "📡"
        case .fix3D: return "📡✓"
        case .dgps: return "📡+"
        case .rtk, .rtkFloat: return "📡⭐"
        }
    }

    public var accuracy: String {
        switch self {
        case .noFix: return "N/A"
        case .fix2D: return "~10m"
        case .fix3D: return "~3m"
        case .dgps: return "~1m"
        case .rtkFloat: return "~0.5m"
        case .rtk: return "~2cm"
        }
    }
}

// MARK: - Waypoint

public struct Waypoint: Identifiable, Codable {
    public var id: UUID
    public var coordinate: CLLocationCoordinate2D
    public var altitude: Double           // meters
    public var speed: Double              // m/s
    public var holdTime: TimeInterval     // seconds to hover
    public var action: WaypointAction
    public var gimbalPitch: Double?       // degrees
    public var heading: Double?           // degrees (nil = auto)

    public init(
        id: UUID = UUID(),
        coordinate: CLLocationCoordinate2D,
        altitude: Double = 50,
        speed: Double = 5,
        holdTime: TimeInterval = 0,
        action: WaypointAction = .flyThrough,
        gimbalPitch: Double? = nil,
        heading: Double? = nil
    ) {
        self.id = id
        self.coordinate = coordinate
        self.altitude = altitude
        self.speed = speed
        self.holdTime = holdTime
        self.action = action
        self.gimbalPitch = gimbalPitch
        self.heading = heading
    }
}

// Make CLLocationCoordinate2D Codable
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

public enum WaypointAction: String, CaseIterable, Codable {
    case flyThrough = "Fly Through"
    case stop = "Stop & Hover"
    case takePhoto = "Take Photo"
    case startVideo = "Start Video"
    case stopVideo = "Stop Video"
    case rotateGimbal = "Rotate Gimbal"
    case setHeading = "Set Heading"
    case poi = "Point of Interest"

    public var icon: String {
        switch self {
        case .flyThrough: return "➡️"
        case .stop: return "⏸️"
        case .takePhoto: return "📷"
        case .startVideo: return "🎬"
        case .stopVideo: return "⏹️"
        case .rotateGimbal: return "🔄"
        case .setHeading: return "🧭"
        case .poi: return "🎯"
        }
    }
}

// MARK: - Mission

public struct DroneMission: Identifiable, Codable {
    public var id: UUID
    public var name: String
    public var waypoints: [Waypoint]
    public var defaultAltitude: Double
    public var defaultSpeed: Double
    public var finishAction: MissionFinishAction
    public var createdAt: Date
    public var estimatedDuration: TimeInterval
    public var estimatedDistance: Double

    public init(
        id: UUID = UUID(),
        name: String = "New Mission",
        waypoints: [Waypoint] = [],
        defaultAltitude: Double = 50,
        defaultSpeed: Double = 5,
        finishAction: MissionFinishAction = .returnToHome
    ) {
        self.id = id
        self.name = name
        self.waypoints = waypoints
        self.defaultAltitude = defaultAltitude
        self.defaultSpeed = defaultSpeed
        self.finishAction = finishAction
        self.createdAt = Date()
        self.estimatedDuration = 0
        self.estimatedDistance = 0
    }
}

public enum MissionFinishAction: String, CaseIterable, Codable {
    case hover = "Hover"
    case land = "Land"
    case returnToHome = "Return to Home"
    case loop = "Loop Mission"
}

// MARK: - MAVLink Message Types (Stub)

public enum MAVLinkMessageType: UInt8 {
    case heartbeat = 0
    case sysStatus = 1
    case gpsRawInt = 24
    case attitude = 30
    case globalPositionInt = 33
    case rcChannels = 65
    case vfrHud = 74
    case command = 76
    case commandAck = 77
    case setMode = 11
    case missionItem = 39
    case missionRequest = 40
    case missionAck = 47
    case missionCount = 44
    case missionCurrent = 42
    case paramValue = 22
    case paramSet = 23
    case statusText = 253
}

/// MAVLink packet structure (simplified)
public struct MAVLinkPacket {
    public var startByte: UInt8 = 0xFE  // MAVLink 1.0
    public var payloadLength: UInt8
    public var sequence: UInt8
    public var systemId: UInt8
    public var componentId: UInt8
    public var messageId: UInt8
    public var payload: Data
    public var checksum: UInt16

    public init(messageId: MAVLinkMessageType, payload: Data, systemId: UInt8 = 1, componentId: UInt8 = 1, sequence: UInt8 = 0) {
        self.payloadLength = UInt8(payload.count)
        self.sequence = sequence
        self.systemId = systemId
        self.componentId = componentId
        self.messageId = messageId.rawValue
        self.payload = payload
        self.checksum = 0 // Would calculate CRC16
    }

    /// Serialize to bytes for transmission
    public func toBytes() -> Data {
        var data = Data()
        data.append(startByte)
        data.append(payloadLength)
        data.append(sequence)
        data.append(systemId)
        data.append(componentId)
        data.append(messageId)
        data.append(payload)
        // Append checksum (little-endian)
        data.append(UInt8(checksum & 0xFF))
        data.append(UInt8((checksum >> 8) & 0xFF))
        return data
    }
}

// MARK: - Bio-Reactive Flight Parameters

public struct BioReactiveFlightParams: Codable {
    public var isEnabled: Bool
    public var hrvToSmoothness: Float      // HRV coherence → flight smoothness
    public var heartRateToSpeed: Float     // Heart rate → max speed multiplier
    public var coherenceToAltitude: Float  // Coherence → altitude stability
    public var breathingToVertical: Float  // Breathing phase → vertical movement

    public var minHRV: Double = 20         // Below this: more aggressive damping
    public var maxHRV: Double = 100        // Above this: smoother flight

    public init() {
        isEnabled = false
        hrvToSmoothness = 0.5
        heartRateToSpeed = 0.3
        coherenceToAltitude = 0.4
        breathingToVertical = 0.2
    }

    /// Calculate flight smoothness from HRV
    public func calculateSmoothness(hrv: Double) -> Float {
        let normalized = (hrv - minHRV) / (maxHRV - minHRV)
        return Float(max(0.3, min(1.0, normalized))) * hrvToSmoothness
    }

    /// Calculate speed limit from heart rate
    public func calculateSpeedLimit(heartRate: Int, baseSpeed: Double) -> Double {
        // Higher HR = slower, safer flight
        let hrNormalized = Double(max(60, min(180, heartRate)) - 60) / 120.0
        let multiplier = 1.0 - (hrNormalized * Double(heartRateToSpeed))
        return baseSpeed * max(0.3, multiplier)
    }
}

// MARK: - Main Drone Control Engine

@MainActor
public class DroneControlEngine: ObservableObject {

    // MARK: - Published State

    @Published public var isConnected: Bool = false
    @Published public var droneState: DroneState = DroneState()
    @Published public var currentMission: DroneMission?
    @Published public var savedMissions: [DroneMission] = []
    @Published public var bioParams: BioReactiveFlightParams = BioReactiveFlightParams()
    @Published public var lastError: String?
    @Published public var isEmergency: Bool = false

    // Connection
    @Published public var connectionType: ConnectionType = .wifi
    @Published public var manufacturer: DroneManufacturer = .dji
    @Published public var droneModel: String = ""

    // Telemetry
    @Published public var telemetryRate: Int = 10 // Hz

    // MARK: - Connection Types

    public enum ConnectionType: String, CaseIterable {
        case wifi = "WiFi"
        case bluetooth = "Bluetooth"
        case usb = "USB"
        case radio = "Radio (RC)"
        case cellular = "Cellular (4G/5G)"

        public var icon: String {
            switch self {
            case .wifi: return "📶"
            case .bluetooth: return "🔵"
            case .usb: return "🔌"
            case .radio: return "📻"
            case .cellular: return "📱"
            }
        }
    }

    // MARK: - Internal

    private var packetSequence: UInt8 = 0
    private var telemetryTask: Task<Void, Never>?
    private var connectionTask: Task<Void, Never>?

    // MARK: - Callbacks

    public var onStateUpdate: ((DroneState) -> Void)?
    public var onMissionProgress: ((Int, Int) -> Void)?  // (current, total)
    public var onEmergency: ((String) -> Void)?
    public var onDisconnect: (() -> Void)?

    // MARK: - Initialization

    public init() {
        // Load saved missions
        loadSavedMissions()
    }

    deinit {
        telemetryTask?.cancel()
        connectionTask?.cancel()
    }

    // MARK: - Connection

    /// Connect to drone
    public func connect(
        manufacturer: DroneManufacturer,
        model: String,
        connectionType: ConnectionType,
        address: String? = nil
    ) async -> Bool {
        self.manufacturer = manufacturer
        self.droneModel = model
        self.connectionType = connectionType

        lastError = nil

        // Simulate connection process
        print("🚁 Connecting to \(manufacturer.rawValue) \(model) via \(connectionType.rawValue)...")

        do {
            try await Task.sleep(nanoseconds: 2_000_000_000)

            if manufacturer.supportsMAVLink {
                // MAVLink connection
                let success = await connectMAVLink(address: address ?? "192.168.4.1")
                if success {
                    isConnected = true
                    startTelemetry()
                    return true
                }
            } else {
                // Proprietary SDK (DJI, etc.)
                let success = await connectProprietarySDK()
                if success {
                    isConnected = true
                    startTelemetry()
                    return true
                }
            }

            lastError = "Connection failed"
            return false

        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    private func connectMAVLink(address: String) async -> Bool {
        // STUB: In production, establish TCP/UDP socket to MAVLink endpoint
        print("📡 MAVLink: Connecting to \(address):14550...")

        // Send heartbeat
        let heartbeat = createHeartbeat()
        print("💓 Sending heartbeat: \(heartbeat.toBytes().count) bytes")

        // Simulate successful connection
        return true
    }

    private func connectProprietarySDK() async -> Bool {
        // STUB: In production, use DJI Mobile SDK, Parrot SDK, etc.
        print("📱 Using proprietary SDK for \(manufacturer.rawValue)...")

        switch manufacturer {
        case .dji:
            print("   DJI Mobile SDK v5.x integration")
        case .parrot:
            print("   Parrot Ground SDK integration")
        case .autel:
            print("   Autel SDK integration")
        case .skydio:
            print("   Skydio Skills SDK integration")
        default:
            break
        }

        return true
    }

    /// Disconnect from drone
    public func disconnect() {
        telemetryTask?.cancel()
        telemetryTask = nil

        isConnected = false
        droneState = DroneState()

        onDisconnect?()
        print("🚁 Disconnected from drone")
    }

    // MARK: - Telemetry

    private func startTelemetry() {
        telemetryTask = Task {
            while !Task.isCancelled && isConnected {
                await updateTelemetry()
                try? await Task.sleep(nanoseconds: UInt64(1_000_000_000 / telemetryRate))
            }
        }
    }

    private func updateTelemetry() async {
        // STUB: In production, parse incoming MAVLink messages
        // Simulate telemetry updates

        if droneState.isFlying {
            // Simulate movement
            droneState.groundSpeed = Double.random(in: 3...8)
            droneState.altitude += Double.random(in: -0.5...0.5)
            droneState.heading = (droneState.heading + Double.random(in: -2...2)).truncatingRemainder(dividingBy: 360)
        }

        // Simulate battery drain
        if droneState.isArmed {
            droneState.batteryPercent -= 0.001
            droneState.flightTimeRemaining = Int(droneState.batteryPercent * 1800)
        }

        // Update distance to home
        if let home = droneState.homeLocation {
            let current = CLLocation(latitude: droneState.latitude, longitude: droneState.longitude)
            let homeLocation = CLLocation(latitude: home.latitude, longitude: home.longitude)
            droneState.distanceToHome = current.distance(from: homeLocation)
        }

        onStateUpdate?(droneState)

        // Check for low battery
        if droneState.batteryPercent < 0.2 && droneState.isFlying {
            triggerEmergency("Low battery - \(Int(droneState.batteryPercent * 100))%")
        }
    }

    // MARK: - Flight Commands

    /// Arm the drone
    public func arm() async -> Bool {
        guard isConnected else {
            lastError = "Not connected"
            return false
        }

        guard droneState.gpsFixType != .noFix else {
            lastError = "No GPS fix"
            return false
        }

        print("🔓 Arming drone...")

        // STUB: Send MAVLink ARM command
        let armCommand = createCommand(command: .componentArmDisarm, param1: 1)
        await sendPacket(armCommand)

        try? await Task.sleep(nanoseconds: 1_000_000_000)

        droneState.isArmed = true
        droneState.homeLocation = CLLocationCoordinate2D(latitude: droneState.latitude, longitude: droneState.longitude)

        print("✅ Drone armed. Home location set.")
        return true
    }

    /// Disarm the drone
    public func disarm() async -> Bool {
        guard !droneState.isFlying else {
            lastError = "Cannot disarm while flying"
            return false
        }

        print("🔒 Disarming drone...")

        let disarmCommand = createCommand(command: .componentArmDisarm, param1: 0)
        await sendPacket(disarmCommand)

        droneState.isArmed = false
        print("✅ Drone disarmed")
        return true
    }

    /// Takeoff to specified altitude
    public func takeoff(altitude: Double = 10) async -> Bool {
        guard droneState.isArmed else {
            lastError = "Drone not armed"
            return false
        }

        print("🛫 Taking off to \(altitude)m...")

        let takeoffCommand = createCommand(command: .navTakeoff, param7: Float(altitude))
        await sendPacket(takeoffCommand)

        droneState.isFlying = true
        droneState.flightMode = .altitudeHold

        // Simulate takeoff
        for _ in 0..<10 {
            droneState.altitude += altitude / 10
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        print("✅ Takeoff complete at \(droneState.altitude)m")
        return true
    }

    /// Land the drone
    public func land() async {
        print("🛬 Landing...")

        droneState.flightMode = .autoLand

        let landCommand = createCommand(command: .navLand)
        await sendPacket(landCommand)

        // Simulate landing
        while droneState.altitude > 0.5 {
            droneState.altitude -= 0.5
            droneState.verticalSpeed = -0.5
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        droneState.altitude = 0
        droneState.isFlying = false
        droneState.verticalSpeed = 0

        print("✅ Landed")
    }

    /// Return to home
    public func returnToHome() async {
        guard let home = droneState.homeLocation else {
            lastError = "No home location set"
            return
        }

        print("🏠 Returning to home...")

        droneState.flightMode = .returnToHome

        let rthCommand = createCommand(command: .navReturnToLaunch)
        await sendPacket(rthCommand)

        // Simulate RTH
        print("   Flying to: \(home.latitude), \(home.longitude)")
    }

    /// Set flight mode
    public func setFlightMode(_ mode: FlightMode) async {
        guard isConnected else { return }

        if mode.requiresGPS && droneState.gpsFixType == .noFix {
            lastError = "Mode requires GPS fix"
            return
        }

        print("🎮 Setting flight mode: \(mode.rawValue)")

        // STUB: Send MAVLink SET_MODE command
        droneState.flightMode = mode
    }

    // MARK: - Manual Control

    /// Send manual control input
    public func sendManualControl(
        throttle: Float,    // -1 to 1 (vertical)
        yaw: Float,         // -1 to 1 (rotation)
        pitch: Float,       // -1 to 1 (forward/back)
        roll: Float         // -1 to 1 (left/right)
    ) async {
        guard droneState.isFlying && droneState.flightMode == .manual else { return }

        // Apply bio-reactive modulation if enabled
        var adjustedThrottle = throttle
        var adjustedYaw = yaw
        var adjustedPitch = pitch
        var adjustedRoll = roll

        if bioParams.isEnabled {
            let smoothness = bioParams.calculateSmoothness(hrv: 50) // Would use real HRV
            adjustedPitch *= smoothness
            adjustedRoll *= smoothness
            adjustedYaw *= smoothness
        }

        // STUB: Send MAVLink MANUAL_CONTROL message
        print("🎮 Manual: T=\(adjustedThrottle) Y=\(adjustedYaw) P=\(adjustedPitch) R=\(adjustedRoll)")
    }

    // MARK: - Mission Control

    /// Upload mission to drone
    public func uploadMission(_ mission: DroneMission) async -> Bool {
        guard isConnected else {
            lastError = "Not connected"
            return false
        }

        guard !mission.waypoints.isEmpty else {
            lastError = "Mission has no waypoints"
            return false
        }

        print("📤 Uploading mission: \(mission.name) (\(mission.waypoints.count) waypoints)")

        // STUB: Send MAVLink mission items
        for (index, waypoint) in mission.waypoints.enumerated() {
            let missionItem = createMissionItem(index: index, waypoint: waypoint)
            await sendPacket(missionItem)
            print("   Waypoint \(index + 1): \(waypoint.coordinate.latitude), \(waypoint.coordinate.longitude) @ \(waypoint.altitude)m")
        }

        currentMission = mission
        print("✅ Mission uploaded")
        return true
    }

    /// Start mission
    public func startMission() async {
        guard currentMission != nil else {
            lastError = "No mission loaded"
            return
        }

        guard droneState.isArmed else {
            lastError = "Drone not armed"
            return
        }

        print("▶️ Starting mission...")

        droneState.flightMode = .waypoint

        let startCommand = createCommand(command: .missionStart)
        await sendPacket(startCommand)
    }

    /// Pause mission
    public func pauseMission() async {
        print("⏸️ Pausing mission...")
        droneState.flightMode = .positionHold
    }

    /// Resume mission
    public func resumeMission() async {
        print("▶️ Resuming mission...")
        droneState.flightMode = .waypoint
    }

    // MARK: - Emergency

    /// Trigger emergency stop
    public func emergencyStop() {
        print("🆘 EMERGENCY STOP")

        isEmergency = true
        droneState.flightMode = .emergency

        // STUB: Send emergency command
        Task {
            let emergencyCommand = createCommand(command: .componentArmDisarm, param1: 0, param2: 21196)
            await sendPacket(emergencyCommand)
        }

        onEmergency?("Emergency stop triggered by user")
    }

    private func triggerEmergency(_ reason: String) {
        isEmergency = true
        print("⚠️ EMERGENCY: \(reason)")

        // Auto-RTH on low battery
        if reason.contains("battery") {
            Task {
                await returnToHome()
            }
        }

        onEmergency?(reason)
    }

    /// Clear emergency state
    public func clearEmergency() {
        isEmergency = false
        droneState.flightMode = .manual
        print("✅ Emergency cleared")
    }

    // MARK: - Bio-Reactive Mode

    /// Enable bio-reactive flight
    public func enableBioReactiveMode(
        hrvCoherence: Double,
        heartRate: Int,
        breathingPhase: Float
    ) {
        bioParams.isEnabled = true
        droneState.flightMode = .bioReactive

        // Calculate adaptive parameters
        let smoothness = bioParams.calculateSmoothness(hrv: hrvCoherence)
        let speedLimit = bioParams.calculateSpeedLimit(heartRate: heartRate, baseSpeed: 10.0)

        print("💓 Bio-Reactive Mode: Smoothness=\(smoothness), MaxSpeed=\(speedLimit)m/s")
    }

    /// Disable bio-reactive flight
    public func disableBioReactiveMode() {
        bioParams.isEnabled = false
        if droneState.flightMode == .bioReactive {
            droneState.flightMode = .positionHold
        }
    }

    // MARK: - MAVLink Packet Creation (Stubs)

    private func createHeartbeat() -> MAVLinkPacket {
        // STUB: Heartbeat payload
        var payload = Data(count: 9)
        // Type, autopilot, base_mode, custom_mode, system_status, mavlink_version
        return MAVLinkPacket(messageId: .heartbeat, payload: payload, sequence: nextSequence())
    }

    private func createCommand(
        command: MAVCommand,
        param1: Float = 0,
        param2: Float = 0,
        param3: Float = 0,
        param4: Float = 0,
        param5: Float = 0,
        param6: Float = 0,
        param7: Float = 0
    ) -> MAVLinkPacket {
        // STUB: Command payload
        var payload = Data(count: 33)
        return MAVLinkPacket(messageId: .command, payload: payload, sequence: nextSequence())
    }

    private func createMissionItem(index: Int, waypoint: Waypoint) -> MAVLinkPacket {
        // STUB: Mission item payload
        var payload = Data(count: 37)
        return MAVLinkPacket(messageId: .missionItem, payload: payload, sequence: nextSequence())
    }

    private func nextSequence() -> UInt8 {
        packetSequence = packetSequence &+ 1
        return packetSequence
    }

    private func sendPacket(_ packet: MAVLinkPacket) async {
        // STUB: In production, send via socket
        let bytes = packet.toBytes()
        print("📤 TX: \(bytes.count) bytes (msg=\(packet.messageId))")
    }

    // MARK: - Mission Persistence

    private func loadSavedMissions() {
        // STUB: Load from UserDefaults or file
        savedMissions = []
    }

    public func saveMission(_ mission: DroneMission) {
        if let index = savedMissions.firstIndex(where: { $0.id == mission.id }) {
            savedMissions[index] = mission
        } else {
            savedMissions.append(mission)
        }
        // STUB: Persist to storage
    }

    public func deleteMission(_ mission: DroneMission) {
        savedMissions.removeAll { $0.id == mission.id }
    }
}

// MARK: - MAVLink Commands

private enum MAVCommand: UInt16 {
    case componentArmDisarm = 400
    case navTakeoff = 22
    case navLand = 21
    case navReturnToLaunch = 20
    case navWaypoint = 16
    case missionStart = 300
    case doSetMode = 176
    case doChangeSpeed = 178
}
