import Foundation
import CoreLocation
#if canImport(Combine)
import Combine
#endif

// ╔═══════════════════════════════════════════════════════════════════════════════════════════════════════╗
// ║                                                                                                       ║
// ║   ████████╗ █████╗ ██╗   ██╗ ██████╗██╗  ██╗███████╗██╗     ██╗███████╗ ██████╗ ███████╗███╗   ██╗   ║
// ║   ╚══██╔══╝██╔══██╗██║   ██║██╔════╝██║  ██║██╔════╝██║     ██║██╔════╝██╔════╝ ██╔════╝████╗  ██║   ║
// ║      ██║   ███████║██║   ██║██║     ███████║█████╗  ██║     ██║█████╗  ██║  ███╗█████╗  ██╔██╗ ██║   ║
// ║      ██║   ██╔══██║██║   ██║██║     ██╔══██║██╔══╝  ██║     ██║██╔══╝  ██║   ██║██╔══╝  ██║╚██╗██║   ║
// ║      ██║   ██║  ██║╚██████╔╝╚██████╗██║  ██║██║     ███████╗██║███████╗╚██████╔╝███████╗██║ ╚████║   ║
// ║      ╚═╝   ╚═╝  ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚═╝     ╚══════╝╚═╝╚══════╝ ╚═════╝ ╚══════╝╚═╝  ╚═══╝   ║
// ║                                                                                                       ║
// ║   🤿 DIVING & FLYING CONTROL ENGINE - Underwater ROV & Aerial Vehicle Control 🤿                     ║
// ║                                                                                                       ║
// ║   Underwater ROV • Submarine • Paraglider • Hang Glider • Jetpack • eVTOL                            ║
// ║   Bio-Reactive Navigation • Depth/Altitude Control • Environment Awareness                           ║
// ║                                                                                                       ║
// ║   ⚠️ EXPERIMENTAL FEATURE - Professional certification required for operation.                       ║
// ║                                                                                                       ║
// ╚═══════════════════════════════════════════════════════════════════════════════════════════════════════╝

// MARK: - Safety Disclaimer

public struct DivingFlyingDisclaimer {
    public static let safety = """
    ⚠️ CRITICAL SAFETY WARNING / WICHTIGE SICHERHEITSWARNUNG:

    UNDERWATER OPERATIONS:
    - Requires certified diving/ROV operator license
    - Monitor depth limits and decompression times
    - Check equipment before every dive
    - Never dive alone - use buddy system
    - Know emergency ascent procedures

    AERIAL OPERATIONS:
    - Requires appropriate pilot certification
    - Check weather conditions before flight
    - Maintain minimum safe altitudes
    - Know emergency landing procedures
    - Follow all aviation regulations

    This software is an INTERFACE only.
    Actual operation requires certified, approved equipment and training.
    Echoelmusic is NOT responsible for accidents, injuries, or fatalities.

    TAUCHEN NUR MIT ZERTIFIZIERUNG. FLIEGEN NUR MIT LIZENZ.
    """

    public static var isAccepted: Bool = false
}

// MARK: - Vehicle Domain

public enum OperationDomain: String, CaseIterable, Codable {
    case underwater = "Underwater"
    case surface = "Surface"
    case aerial = "Aerial"
    case space = "Space"          // Future: suborbital
    case amphibious = "Amphibious"

    public var icon: String {
        switch self {
        case .underwater: return "🤿"
        case .surface: return "🚤"
        case .aerial: return "🪂"
        case .space: return "🚀"
        case .amphibious: return "🦆"
        }
    }

    public var depthOrAltitudeLabel: String {
        switch self {
        case .underwater: return "Depth"
        case .aerial, .space: return "Altitude"
        case .surface, .amphibious: return "Level"
        }
    }
}

// MARK: - Vehicle Type

public enum DivingFlyingVehicleType: String, CaseIterable, Codable {
    // Underwater
    case rov = "ROV (Remotely Operated Vehicle)"
    case auv = "AUV (Autonomous Underwater)"
    case submarine = "Personal Submarine"
    case divePropulsion = "Dive Propulsion Vehicle"
    case underwaterScooter = "Underwater Scooter"

    // Aerial
    case paraglider = "Paraglider"
    case hangGlider = "Hang Glider"
    case paramotor = "Paramotor"
    case wingsuit = "Wingsuit"
    case jetpack = "Jetpack"
    case evtol = "eVTOL Air Taxi"
    case gyrocopter = "Gyrocopter"
    case ultralight = "Ultralight"
    case hotAirBalloon = "Hot Air Balloon"

    // Amphibious
    case flyingBoat = "Flying Boat"
    case seaplane = "Seaplane"
    case hovercraft = "Hovercraft"

    public var domain: OperationDomain {
        switch self {
        case .rov, .auv, .submarine, .divePropulsion, .underwaterScooter:
            return .underwater
        case .paraglider, .hangGlider, .paramotor, .wingsuit, .jetpack, .evtol, .gyrocopter, .ultralight, .hotAirBalloon:
            return .aerial
        case .flyingBoat, .seaplane, .hovercraft:
            return .amphibious
        }
    }

    public var icon: String {
        switch self {
        case .rov: return "🤖"
        case .auv: return "🐟"
        case .submarine: return "🛥️"
        case .divePropulsion, .underwaterScooter: return "🏊"
        case .paraglider: return "🪂"
        case .hangGlider: return "🦅"
        case .paramotor: return "🌀"
        case .wingsuit: return "🦇"
        case .jetpack: return "🚀"
        case .evtol: return "🛸"
        case .gyrocopter: return "🚁"
        case .ultralight: return "✈️"
        case .hotAirBalloon: return "🎈"
        case .flyingBoat, .seaplane: return "🛩️"
        case .hovercraft: return "🛶"
        }
    }

    public var requiresCertification: String {
        switch self {
        case .rov, .auv:
            return "ROV Pilot Certification"
        case .submarine:
            return "Submarine Pilot License"
        case .divePropulsion, .underwaterScooter:
            return "PADI/SSI Certification"
        case .paraglider, .hangGlider:
            return "USHPA P2+ Rating"
        case .paramotor:
            return "USPPA PPG License"
        case .wingsuit:
            return "500+ skydives minimum"
        case .jetpack:
            return "Jetpack Operator License"
        case .evtol:
            return "eVTOL Type Rating"
        case .gyrocopter:
            return "Gyroplane License"
        case .ultralight:
            return "Ultralight Pilot Permit"
        case .hotAirBalloon:
            return "Balloon Pilot Certificate"
        case .flyingBoat, .seaplane:
            return "Seaplane Rating"
        case .hovercraft:
            return "Hovercraft Operator Certificate"
        }
    }

    public var maxOperatingDepthOrAltitude: Double { // meters
        switch self {
        case .rov: return 1000       // Commercial ROV depth
        case .auv: return 6000       // Deep sea AUV
        case .submarine: return 300  // Personal sub
        case .divePropulsion: return 40
        case .underwaterScooter: return 30
        case .paraglider: return 5000
        case .hangGlider: return 4000
        case .paramotor: return 3000
        case .wingsuit: return 4500
        case .jetpack: return 1000
        case .evtol: return 3000
        case .gyrocopter: return 3000
        case .ultralight: return 3000
        case .hotAirBalloon: return 6000
        case .flyingBoat, .seaplane: return 4000
        case .hovercraft: return 0   // Surface only
        }
    }
}

// MARK: - Operation Mode

public enum OperationMode: String, CaseIterable, Codable {
    case manual = "Manual"
    case assisted = "Assisted"
    case stabilized = "Stabilized"
    case depthHold = "Depth Hold"
    case altitudeHold = "Altitude Hold"
    case positionHold = "Position Hold"
    case waypoint = "Waypoint"
    case followMe = "Follow Me"
    case returnToBase = "Return to Base"
    case emergency = "Emergency"
    case bioReactive = "Bio-Reactive"
    case scenic = "Scenic Auto-Pilot"

    public var icon: String {
        switch self {
        case .manual: return "🎮"
        case .assisted: return "🤝"
        case .stabilized: return "⚖️"
        case .depthHold: return "📏"
        case .altitudeHold: return "📐"
        case .positionHold: return "📍"
        case .waypoint: return "📌"
        case .followMe: return "🏃"
        case .returnToBase: return "🏠"
        case .emergency: return "🆘"
        case .bioReactive: return "💓"
        case .scenic: return "🌅"
        }
    }
}

// MARK: - Vehicle State

public struct DivingFlyingState: Codable, Equatable {
    // Identity
    public var domain: OperationDomain
    public var vehicleType: DivingFlyingVehicleType
    public var mode: OperationMode

    // Position
    public var latitude: Double
    public var longitude: Double
    public var depthOrAltitude: Double       // meters (negative for underwater)
    public var heading: Double               // degrees
    public var pitch: Double                 // degrees
    public var roll: Double                  // degrees

    // Velocity
    public var horizontalSpeed: Double       // m/s
    public var verticalSpeed: Double         // m/s (positive = up/ascending)
    public var groundSpeed: Double           // m/s

    // Environment
    public var waterTemperature: Float?      // celsius (underwater)
    public var airTemperature: Float?        // celsius (aerial)
    public var pressure: Double              // bar (underwater) or hPa (aerial)
    public var visibility: Float             // meters
    public var currentStrength: Float?       // m/s (underwater current)
    public var windSpeed: Float?             // m/s (aerial wind)
    public var windDirection: Float?         // degrees

    // System
    public var batteryPercent: Float
    public var remainingTime: Int            // seconds
    public var signalStrength: Float         // 0-1
    public var isConnected: Bool
    public var isArmed: Bool
    public var isOperating: Bool

    // Safety
    public var decompressionStop: DecompressionInfo?  // Underwater only
    public var noFlyZone: Bool                        // Aerial only
    public var warningMessages: [String]

    public init(vehicleType: DivingFlyingVehicleType = .rov) {
        self.domain = vehicleType.domain
        self.vehicleType = vehicleType
        self.mode = .manual
        self.latitude = 0
        self.longitude = 0
        self.depthOrAltitude = 0
        self.heading = 0
        self.pitch = 0
        self.roll = 0
        self.horizontalSpeed = 0
        self.verticalSpeed = 0
        self.groundSpeed = 0
        self.waterTemperature = nil
        self.airTemperature = nil
        self.pressure = vehicleType.domain == .underwater ? 1.0 : 1013.25
        self.visibility = 20
        self.currentStrength = nil
        self.windSpeed = nil
        self.windDirection = nil
        self.batteryPercent = 1.0
        self.remainingTime = 3600
        self.signalStrength = 1.0
        self.isConnected = false
        self.isArmed = false
        self.isOperating = false
        self.decompressionStop = nil
        self.noFlyZone = false
        self.warningMessages = []
    }

    /// Depth string for display (underwater)
    public var depthString: String {
        if domain == .underwater {
            return String(format: "%.1fm", abs(depthOrAltitude))
        }
        return String(format: "%.0fm", depthOrAltitude)
    }

    /// Pressure in atmospheres (underwater)
    public var atmospheres: Double {
        guard domain == .underwater else { return 1.0 }
        return 1.0 + (abs(depthOrAltitude) / 10.0)
    }
}

// MARK: - Decompression Info

public struct DecompressionInfo: Codable, Equatable {
    public var isRequired: Bool
    public var stopDepth: Double             // meters
    public var stopDuration: Int             // seconds
    public var noDecoLimit: Int              // seconds remaining at current depth
    public var ascentRate: Double            // m/min (recommended max 9m/min)

    public init() {
        isRequired = false
        stopDepth = 0
        stopDuration = 0
        noDecoLimit = 3600
        ascentRate = 9.0
    }

    public var warningLevel: String {
        if noDecoLimit < 60 { return "🔴 CRITICAL" }
        if noDecoLimit < 300 { return "🟠 WARNING" }
        if noDecoLimit < 600 { return "🟡 CAUTION" }
        return "🟢 OK"
    }
}

// MARK: - Bio-Reactive Parameters

public struct BioReactiveExtremeParams: Codable {
    public var isEnabled: Bool

    // Underwater
    public var hrvToAscentRate: Float        // HRV → safe ascent rate
    public var heartRateToDepthLimit: Float  // HR → max depth warning
    public var coherenceToLighting: Float    // Coherence → ROV lights

    // Aerial
    public var hrvToSmoothness: Float        // HRV → flight smoothness
    public var heartRateToAltitudeLimit: Float  // HR → altitude warning
    public var coherenceToSpeed: Float       // Coherence → max speed

    // Thresholds
    public var maxSafeHeartRate: Int         // Abort if exceeded
    public var minSafeHRV: Double            // Warning if below
    public var panicThreshold: Double        // Emergency if exceeded

    public init() {
        isEnabled = false
        hrvToAscentRate = 0.5
        heartRateToDepthLimit = 0.3
        coherenceToLighting = 0.4
        hrvToSmoothness = 0.5
        heartRateToAltitudeLimit = 0.3
        coherenceToSpeed = 0.4
        maxSafeHeartRate = 160
        minSafeHRV = 20
        panicThreshold = 0.8
    }
}

// MARK: - Waypoint (3D)

public struct Waypoint3D: Identifiable, Codable {
    public var id: UUID
    public var coordinate: CLLocationCoordinate2D
    public var depthOrAltitude: Double
    public var speed: Double
    public var holdTime: TimeInterval
    public var action: Waypoint3DAction

    public init(
        id: UUID = UUID(),
        coordinate: CLLocationCoordinate2D,
        depthOrAltitude: Double,
        speed: Double = 2.0,
        holdTime: TimeInterval = 0,
        action: Waypoint3DAction = .passThrough
    ) {
        self.id = id
        self.coordinate = coordinate
        self.depthOrAltitude = depthOrAltitude
        self.speed = speed
        self.holdTime = holdTime
        self.action = action
    }
}

public enum Waypoint3DAction: String, CaseIterable, Codable {
    case passThrough = "Pass Through"
    case stop = "Stop & Hold"
    case takePhoto = "Take Photo"
    case startVideo = "Start Video"
    case stopVideo = "Stop Video"
    case collectSample = "Collect Sample"
    case deployMarker = "Deploy Marker"
    case scan360 = "360° Scan"
}

// MARK: - Main Engine

@MainActor
public class DivingFlyingControlEngine: ObservableObject {

    // MARK: - Published State

    @Published public var isConnected: Bool = false
    @Published public var state: DivingFlyingState = DivingFlyingState()
    @Published public var bioParams: BioReactiveExtremeParams = BioReactiveExtremeParams()
    @Published public var currentMission: [Waypoint3D] = []
    @Published public var lastError: String?
    @Published public var isEmergency: Bool = false

    // MARK: - Callbacks

    public var onStateUpdate: ((DivingFlyingState) -> Void)?
    public var onDepthWarning: ((Double, String) -> Void)?
    public var onDecompressionWarning: ((DecompressionInfo) -> Void)?
    public var onEmergency: ((String) -> Void)?

    // MARK: - Internal

    private var telemetryTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(vehicleType: DivingFlyingVehicleType = .rov) {
        state = DivingFlyingState(vehicleType: vehicleType)
    }

    deinit {
        telemetryTask?.cancel()
    }

    // MARK: - Connection

    /// Connect to vehicle
    public func connect(
        vehicleType: DivingFlyingVehicleType,
        connectionString: String
    ) async -> Bool {
        state = DivingFlyingState(vehicleType: vehicleType)
        lastError = nil

        print("\(vehicleType.icon) Connecting to \(vehicleType.rawValue)...")
        print("   Certification required: \(vehicleType.requiresCertification)")

        // STUB: In production, establish connection based on vehicle protocol
        // - ROV: Often uses tether + Ethernet
        // - AUV: Acoustic modem or WiFi at surface
        // - Aerial: Radio link (various protocols)

        try? await Task.sleep(nanoseconds: 2_000_000_000)

        isConnected = true
        state.isConnected = true
        startTelemetry()

        print("✅ Connected to \(vehicleType.rawValue)")
        return true
    }

    /// Disconnect
    public func disconnect() {
        telemetryTask?.cancel()
        isConnected = false
        state.isConnected = false
        state.isArmed = false
        state.isOperating = false
        print("🔌 Disconnected")
    }

    // MARK: - Telemetry

    private func startTelemetry() {
        telemetryTask = Task {
            while !Task.isCancelled && isConnected {
                await updateTelemetry()
                try? await Task.sleep(nanoseconds: 100_000_000) // 10Hz
            }
        }
    }

    private func updateTelemetry() async {
        // STUB: Parse incoming telemetry

        // Simulate environment
        if state.domain == .underwater {
            // Pressure increases with depth
            state.pressure = 1.0 + (abs(state.depthOrAltitude) / 10.0)

            // Update decompression info
            updateDecompressionInfo()

            // Simulate temperature decrease with depth
            state.waterTemperature = Float(20.0 - abs(state.depthOrAltitude) * 0.05)

        } else if state.domain == .aerial {
            // Pressure decreases with altitude
            state.pressure = 1013.25 * pow(1 - 0.0000225577 * state.depthOrAltitude, 5.25588)

            // Temperature lapse rate: ~6.5°C per 1000m
            state.airTemperature = Float(15.0 - state.depthOrAltitude * 0.0065)
        }

        // Battery drain
        if state.isOperating {
            state.batteryPercent -= 0.0001
            state.remainingTime = Int(state.batteryPercent * 3600)

            // Low battery warning
            if state.batteryPercent < 0.2 {
                state.warningMessages = ["⚠️ Low battery - \(Int(state.batteryPercent * 100))%"]
                if state.batteryPercent < 0.1 {
                    triggerEmergency("Critical battery level")
                }
            }
        }

        onStateUpdate?(state)
    }

    private func updateDecompressionInfo() {
        guard state.domain == .underwater else { return }

        var decoInfo = state.decompressionStop ?? DecompressionInfo()

        let depth = abs(state.depthOrAltitude)

        // Simplified no-deco limits (recreational diving tables approximation)
        // Real implementation would use Bühlmann or similar algorithm
        if depth < 12 {
            decoInfo.noDecoLimit = 3600  // Practically unlimited
        } else if depth < 18 {
            decoInfo.noDecoLimit = 2400  // 40 min
        } else if depth < 25 {
            decoInfo.noDecoLimit = 1500  // 25 min
        } else if depth < 30 {
            decoInfo.noDecoLimit = 1200  // 20 min
        } else if depth < 40 {
            decoInfo.noDecoLimit = 600   // 10 min
        } else {
            decoInfo.noDecoLimit = 300   // 5 min
        }

        decoInfo.isRequired = depth > 30 && state.remainingTime < decoInfo.noDecoLimit

        if decoInfo.isRequired {
            decoInfo.stopDepth = 5.0  // Standard safety stop
            decoInfo.stopDuration = 180  // 3 minutes
            onDecompressionWarning?(decoInfo)
        }

        state.decompressionStop = decoInfo
    }

    // MARK: - Control Commands

    /// Arm the vehicle
    public func arm() async -> Bool {
        guard isConnected else {
            lastError = "Not connected"
            return false
        }

        print("🔓 Arming \(state.vehicleType.rawValue)...")

        // STUB: Send arm command
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        state.isArmed = true
        print("✅ Armed")
        return true
    }

    /// Disarm the vehicle
    public func disarm() async -> Bool {
        guard !state.isOperating else {
            lastError = "Cannot disarm while operating"
            return false
        }

        state.isArmed = false
        print("🔒 Disarmed")
        return true
    }

    /// Start operation (dive/takeoff)
    public func startOperation() async -> Bool {
        guard state.isArmed else {
            lastError = "Not armed"
            return false
        }

        if state.domain == .underwater {
            print("🤿 Starting dive...")
        } else {
            print("🛫 Starting flight...")
        }

        state.isOperating = true
        return true
    }

    /// End operation (surface/land)
    public func endOperation() async {
        if state.domain == .underwater {
            print("⬆️ Surfacing...")

            // Safe ascent
            while state.depthOrAltitude < -1 {
                state.depthOrAltitude += 0.15  // 9m/min ascent rate
                state.verticalSpeed = 0.15
                try? await Task.sleep(nanoseconds: 100_000_000)
            }

            state.depthOrAltitude = 0
            print("🏊 Surfaced")

        } else {
            print("🛬 Landing...")

            while state.depthOrAltitude > 1 {
                state.depthOrAltitude -= 0.5
                state.verticalSpeed = -0.5
                try? await Task.sleep(nanoseconds: 100_000_000)
            }

            state.depthOrAltitude = 0
            print("✅ Landed")
        }

        state.isOperating = false
        state.verticalSpeed = 0
    }

    /// Set operation mode
    public func setMode(_ mode: OperationMode) {
        state.mode = mode
        print("🎮 Mode: \(mode.rawValue)")
    }

    // MARK: - Manual Control

    /// Send manual control
    public func sendManualControl(
        forward: Float,      // -1 to 1
        lateral: Float,      // -1 to 1 (strafe)
        vertical: Float,     // -1 to 1 (up/down or dive/surface)
        yaw: Float           // -1 to 1 (rotation)
    ) async {
        guard state.isOperating && state.mode == .manual else { return }

        // Apply bio-reactive modulation
        var adjVertical = vertical
        var adjForward = forward

        if bioParams.isEnabled {
            // Limit descent/ascent rate based on HRV
            let hrvFactor = bioParams.hrvToAscentRate
            adjVertical *= hrvFactor

            // Limit speed based on coherence
            let coherenceFactor = bioParams.coherenceToSpeed
            adjForward *= coherenceFactor
        }

        // Update state
        state.verticalSpeed = Double(adjVertical) * 2.0  // Max 2 m/s
        state.horizontalSpeed = Double(adjForward) * 3.0 // Max 3 m/s

        // Update depth/altitude
        if state.domain == .underwater {
            state.depthOrAltitude -= Double(adjVertical) * 0.2
            state.depthOrAltitude = max(-state.vehicleType.maxOperatingDepthOrAltitude, state.depthOrAltitude)
            state.depthOrAltitude = min(0, state.depthOrAltitude)

            // Depth limit warning
            if abs(state.depthOrAltitude) > state.vehicleType.maxOperatingDepthOrAltitude * 0.9 {
                onDepthWarning?(state.depthOrAltitude, "Approaching max depth!")
            }

        } else {
            state.depthOrAltitude += Double(adjVertical) * 0.5
            state.depthOrAltitude = max(0, state.depthOrAltitude)
            state.depthOrAltitude = min(state.vehicleType.maxOperatingDepthOrAltitude, state.depthOrAltitude)
        }

        // Update heading
        state.heading = (state.heading + Double(yaw) * 5).truncatingRemainder(dividingBy: 360)
        if state.heading < 0 { state.heading += 360 }
    }

    /// Go to specific depth/altitude
    public func goToDepthOrAltitude(_ target: Double) async {
        guard state.isOperating else { return }

        print("📍 Going to \(state.domain == .underwater ? "depth" : "altitude"): \(target)m")

        state.mode = state.domain == .underwater ? .depthHold : .altitudeHold

        // Simulate movement
        let step = target > state.depthOrAltitude ? 0.5 : -0.5
        while abs(state.depthOrAltitude - target) > 1 {
            state.depthOrAltitude += step
            state.verticalSpeed = step
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        state.depthOrAltitude = target
        state.verticalSpeed = 0
        print("✅ Reached target")
    }

    // MARK: - Mission

    /// Upload and start mission
    public func startMission(_ waypoints: [Waypoint3D]) async {
        guard state.isArmed else {
            lastError = "Not armed"
            return
        }

        currentMission = waypoints
        state.mode = .waypoint

        print("📌 Starting mission with \(waypoints.count) waypoints...")

        for (index, waypoint) in waypoints.enumerated() {
            print("   → Waypoint \(index + 1): \(waypoint.depthOrAltitude)m, \(waypoint.action.rawValue)")

            // Simulate navigation to waypoint
            await goToDepthOrAltitude(waypoint.depthOrAltitude)

            if waypoint.holdTime > 0 {
                print("   ⏸️ Holding for \(waypoint.holdTime)s")
                try? await Task.sleep(nanoseconds: UInt64(waypoint.holdTime * 1_000_000_000))
            }

            // Execute action
            await executeWaypointAction(waypoint.action)
        }

        print("✅ Mission complete")
        state.mode = .positionHold
    }

    private func executeWaypointAction(_ action: Waypoint3DAction) async {
        switch action {
        case .takePhoto:
            print("📷 Taking photo...")
        case .startVideo:
            print("🎬 Starting video...")
        case .stopVideo:
            print("⏹️ Stopping video...")
        case .collectSample:
            print("🧪 Collecting sample...")
        case .deployMarker:
            print("📍 Deploying marker...")
        case .scan360:
            print("🔄 Performing 360° scan...")
            for angle in stride(from: 0, to: 360, by: 45) {
                state.heading = Double(angle)
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        case .passThrough, .stop:
            break
        }
    }

    // MARK: - Emergency

    /// Trigger emergency ascent/landing
    public func emergencyReturn() {
        print("🆘 EMERGENCY RETURN")

        isEmergency = true
        state.mode = .emergency

        Task {
            await endOperation()
        }

        onEmergency?("Emergency return triggered")
    }

    /// Clear emergency
    public func clearEmergency() {
        isEmergency = false
        state.mode = .manual
        state.warningMessages.removeAll()
        print("✅ Emergency cleared")
    }

    private func triggerEmergency(_ reason: String) {
        isEmergency = true
        state.mode = .emergency
        state.warningMessages.append("🆘 \(reason)")
        onEmergency?(reason)

        // Auto-return
        Task {
            await endOperation()
        }
    }

    // MARK: - Bio-Reactive Mode

    /// Update bio-reactive parameters
    public func updateBioReactive(
        heartRate: Int,
        hrvMs: Double,
        coherence: Double,
        stressLevel: Double
    ) {
        guard bioParams.isEnabled && state.isOperating else { return }

        // Check panic threshold
        if stressLevel > bioParams.panicThreshold {
            triggerEmergency("Panic detected - stress level \(Int(stressLevel * 100))%")
            return
        }

        // Check heart rate
        if heartRate > bioParams.maxSafeHeartRate {
            state.warningMessages.append("⚠️ High heart rate: \(heartRate) BPM")
            // Reduce max depth/altitude
        }

        // Check HRV
        if hrvMs < bioParams.minSafeHRV {
            state.warningMessages.append("⚠️ Low HRV: \(Int(hrvMs))ms")
        }

        // Adjust operational limits based on biometrics
        if state.domain == .underwater {
            // Higher stress = shallower max depth
            let depthMultiplier = 1.0 - (stressLevel * Double(bioParams.heartRateToDepthLimit))
            let maxSafeDepth = state.vehicleType.maxOperatingDepthOrAltitude * depthMultiplier

            if abs(state.depthOrAltitude) > maxSafeDepth {
                onDepthWarning?(state.depthOrAltitude, "Depth limit adjusted for safety")
            }
        }
    }

    /// Enable bio-reactive mode
    public func enableBioReactiveMode() {
        bioParams.isEnabled = true
        state.mode = .bioReactive
        print("💓 Bio-reactive mode enabled")
    }

    /// Disable bio-reactive mode
    public func disableBioReactiveMode() {
        bioParams.isEnabled = false
        if state.mode == .bioReactive {
            state.mode = .manual
        }
        print("💓 Bio-reactive mode disabled")
    }

    // MARK: - Utilities

    /// Get status summary
    public var statusSummary: String {
        let depthAlt = state.domain == .underwater ? "Depth" : "Alt"
        return "\(state.vehicleType.icon) \(state.mode.rawValue) | \(depthAlt): \(state.depthString) | 🔋\(Int(state.batteryPercent * 100))%"
    }

    /// Get environment summary
    public var environmentSummary: String {
        if state.domain == .underwater {
            let temp = state.waterTemperature.map { String(format: "%.1f°C", $0) } ?? "N/A"
            return "🌡️\(temp) | 📏\(String(format: "%.1f", state.atmospheres)) ATM | 👁️\(Int(state.visibility))m vis"
        } else {
            let temp = state.airTemperature.map { String(format: "%.1f°C", $0) } ?? "N/A"
            let wind = state.windSpeed.map { String(format: "%.1f m/s", $0) } ?? "N/A"
            return "🌡️\(temp) | 💨\(wind) | 📊\(Int(state.pressure)) hPa"
        }
    }
}
