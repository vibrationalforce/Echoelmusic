// SimulatorControlFramework.swift
// Echoelmusic - Universal Simulator Control
//
// "Technical Telekinesis" - Control any vehicle, drone, robot, or device
// through gestures, neural interfaces, biofeedback, or traditional inputs.
//
// Supports: Aircraft, helicopters, drones, cars, ships, submarines,
// surgical robots, flying cars, personal drones, and future inventions.
//
// References:
// - SAE J3016: Levels of Driving Automation
// - DO-178C: Software in Airborne Systems
// - ISO 26262: Automotive Functional Safety
// - IEC 62304: Medical Device Software
// - IMO SOLAS: Maritime Safety

import Foundation
import simd
import Combine

// MARK: - Simulator Types

/// All controllable simulator/vehicle types
public enum SimulatorType: String, CaseIterable, Codable {
    // Aerial
    case fixedWingAircraft = "Fixed Wing Aircraft"
    case helicopter = "Helicopter"
    case multirotorDrone = "Multirotor Drone"
    case fixedWingDrone = "Fixed Wing Drone"
    case vtolAircraft = "VTOL Aircraft"
    case flyingCar = "Flying Car"
    case personalJetpack = "Personal Jetpack"
    case airship = "Airship/Blimp"

    // Ground
    case car = "Automobile"
    case motorcycle = "Motorcycle"
    case truck = "Truck"
    case bus = "Bus"
    case tank = "Tank"
    case allTerrainVehicle = "ATV"
    case bicycle = "Electric Bicycle"
    case exoskeleton = "Exoskeleton"

    // Marine
    case motorboat = "Motorboat"
    case sailboat = "Sailboat"
    case yacht = "Yacht"
    case submarine = "Submarine"
    case underwaterDrone = "Underwater Drone"
    case hovercraft = "Hovercraft"
    case jetski = "Jet Ski"
    case solarShip = "Solar Ship"

    // Medical/Surgical
    case surgicalRobot = "Surgical Robot"
    case nanobot = "Nanobot Swarm"
    case endoscope = "Robotic Endoscope"
    case prosthetic = "Prosthetic Limb"
    case rehabilitationBot = "Rehabilitation Robot"

    // Industrial/Utility
    case roboticArm = "Robotic Arm"
    case forklift = "Forklift"
    case crane = "Crane"
    case excavator = "Excavator"
    case agriculturalDrone = "Agricultural Drone"

    // Future/Experimental
    case spaceVehicle = "Space Vehicle"
    case hyperloop = "Hyperloop Pod"
    case magneticLevTrain = "Maglev Train"
    case customVehicle = "Custom Vehicle"

    public var category: SimulatorCategory {
        switch self {
        case .fixedWingAircraft, .helicopter, .multirotorDrone, .fixedWingDrone,
             .vtolAircraft, .flyingCar, .personalJetpack, .airship:
            return .aerial
        case .car, .motorcycle, .truck, .bus, .tank, .allTerrainVehicle,
             .bicycle, .exoskeleton:
            return .ground
        case .motorboat, .sailboat, .yacht, .submarine, .underwaterDrone,
             .hovercraft, .jetski, .solarShip:
            return .marine
        case .surgicalRobot, .nanobot, .endoscope, .prosthetic, .rehabilitationBot:
            return .medical
        case .roboticArm, .forklift, .crane, .excavator, .agriculturalDrone:
            return .industrial
        case .spaceVehicle, .hyperloop, .magneticLevTrain, .customVehicle:
            return .experimental
        }
    }

    public var requiredSafetyLevel: SafetyIntegrityLevel {
        switch category {
        case .medical: return .silD     // Highest for medical
        case .aerial: return .silC      // High for aircraft
        case .marine: return .silB      // Moderate for boats
        case .ground: return .silB      // Moderate for vehicles
        case .industrial: return .silB  // Moderate for industrial
        case .experimental: return .silD // Highest for experimental
        }
    }
}

public enum SimulatorCategory: String, CaseIterable {
    case aerial = "Aerial"
    case ground = "Ground"
    case marine = "Marine"
    case medical = "Medical"
    case industrial = "Industrial"
    case experimental = "Experimental"
}

public enum SafetyIntegrityLevel: String, CaseIterable, Comparable {
    case silA = "SIL-A"  // Lowest
    case silB = "SIL-B"
    case silC = "SIL-C"
    case silD = "SIL-D"  // Highest (Life-critical)

    public static func < (lhs: SafetyIntegrityLevel, rhs: SafetyIntegrityLevel) -> Bool {
        let order: [SafetyIntegrityLevel] = [.silA, .silB, .silC, .silD]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

// MARK: - Control Axis Definition

/// Universal control axis for any vehicle type
public struct ControlAxis: Codable {
    public var name: String
    public var value: Float           // -1.0 to 1.0
    public var deadzone: Float        // Ignore values within deadzone
    public var sensitivity: Float     // Multiplier
    public var inverted: Bool
    public var smoothing: Float       // 0 = instant, 1 = very smooth

    private var smoothedValue: Float = 0

    public init(name: String, deadzone: Float = 0.05, sensitivity: Float = 1.0,
                inverted: Bool = false, smoothing: Float = 0.1) {
        self.name = name
        self.value = 0
        self.deadzone = deadzone
        self.sensitivity = sensitivity
        self.inverted = inverted
        self.smoothing = smoothing
    }

    public mutating func update(rawValue: Float) {
        var processed = rawValue

        // Apply deadzone
        if abs(processed) < deadzone {
            processed = 0
        } else {
            // Rescale to use full range outside deadzone
            let sign: Float = processed > 0 ? 1 : -1
            processed = sign * (abs(processed) - deadzone) / (1.0 - deadzone)
        }

        // Apply sensitivity
        processed *= sensitivity

        // Apply inversion
        if inverted {
            processed = -processed
        }

        // Apply smoothing
        smoothedValue = smoothedValue * smoothing + processed * (1.0 - smoothing)
        value = max(-1.0, min(1.0, smoothedValue))
    }
}

// MARK: - Vehicle Control State

/// Complete state for controlling any vehicle
public struct VehicleControlState: Codable {
    // Primary axes (universal)
    public var throttle: ControlAxis
    public var pitch: ControlAxis       // Forward/back tilt or nose up/down
    public var roll: ControlAxis        // Left/right tilt
    public var yaw: ControlAxis         // Rotation around vertical axis

    // Secondary controls
    public var brake: ControlAxis
    public var steering: ControlAxis    // For ground vehicles
    public var collective: ControlAxis  // For helicopters
    public var trim: SIMD3<Float>       // Fine adjustment

    // Additional axes (configurable)
    public var auxiliaryAxes: [String: ControlAxis]

    // Discrete controls
    public var buttons: [String: Bool]
    public var switches: [String: Int]  // Multi-position switches

    // Mode and state
    public var controlMode: ControlMode
    public var stabilizationLevel: Float  // 0 = full manual, 1 = full auto-stabilize
    public var emergencyStop: Bool

    public init(simulatorType: SimulatorType) {
        self.throttle = ControlAxis(name: "Throttle", deadzone: 0.02)
        self.pitch = ControlAxis(name: "Pitch")
        self.roll = ControlAxis(name: "Roll")
        self.yaw = ControlAxis(name: "Yaw", deadzone: 0.08)
        self.brake = ControlAxis(name: "Brake", deadzone: 0.02)
        self.steering = ControlAxis(name: "Steering")
        self.collective = ControlAxis(name: "Collective")
        self.trim = .zero
        self.auxiliaryAxes = [:]
        self.buttons = [:]
        self.switches = [:]
        self.controlMode = .manual
        self.stabilizationLevel = 0.5
        self.emergencyStop = false

        // Configure based on simulator type
        configureFor(simulatorType)
    }

    private mutating func configureFor(_ type: SimulatorType) {
        switch type.category {
        case .aerial:
            auxiliaryAxes["flaps"] = ControlAxis(name: "Flaps")
            auxiliaryAxes["airbrake"] = ControlAxis(name: "Airbrake")
            buttons["landingGear"] = false
            buttons["autopilot"] = false

        case .ground:
            auxiliaryAxes["handbrake"] = ControlAxis(name: "Handbrake")
            auxiliaryAxes["gear"] = ControlAxis(name: "Gear")
            switches["driveMode"] = 0  // Park, Reverse, Neutral, Drive

        case .marine:
            auxiliaryAxes["depth"] = ControlAxis(name: "Depth")
            auxiliaryAxes["ballast"] = ControlAxis(name: "Ballast")
            buttons["anchor"] = false

        case .medical:
            stabilizationLevel = 0.95  // High precision required
            auxiliaryAxes["precision"] = ControlAxis(name: "Precision", sensitivity: 0.1)
            auxiliaryAxes["rotation"] = ControlAxis(name: "Tool Rotation")
            auxiliaryAxes["grip"] = ControlAxis(name: "Grip Force")

        case .industrial:
            auxiliaryAxes["armExtend"] = ControlAxis(name: "Arm Extension")
            auxiliaryAxes["grip"] = ControlAxis(name: "Gripper")

        case .experimental:
            // Fully configurable
            break
        }
    }
}

public enum ControlMode: String, CaseIterable, Codable {
    case manual = "Manual"
    case assisted = "Assisted"
    case semiAutonomous = "Semi-Autonomous"
    case autonomous = "Autonomous"
    case emergency = "Emergency"
}

// MARK: - Input Mapping

/// Maps any input device to vehicle controls
public struct InputMapping: Codable {
    public var deviceType: InputDeviceType
    public var axisBindings: [String: AxisBinding]
    public var buttonBindings: [String: ButtonBinding]

    public struct AxisBinding: Codable {
        public var inputAxis: String       // e.g., "leftStickX"
        public var targetAxis: String      // e.g., "roll"
        public var curve: ResponseCurve
        public var multiplier: Float
    }

    public struct ButtonBinding: Codable {
        public var inputButton: String     // e.g., "buttonA"
        public var action: String          // e.g., "emergencyStop"
        public var holdTime: Float?        // For hold actions
    }

    public enum ResponseCurve: String, Codable, CaseIterable {
        case linear = "Linear"
        case exponential = "Exponential"
        case logarithmic = "Logarithmic"
        case sCurve = "S-Curve"
        case custom = "Custom"

        public func apply(_ value: Float) -> Float {
            switch self {
            case .linear:
                return value
            case .exponential:
                let sign: Float = value >= 0 ? 1 : -1
                return sign * pow(abs(value), 2)
            case .logarithmic:
                let sign: Float = value >= 0 ? 1 : -1
                return sign * sqrt(abs(value))
            case .sCurve:
                // Smooth S-curve using cubic interpolation
                let t = (value + 1) / 2  // Normalize to 0-1
                let s = t * t * (3 - 2 * t)  // Smoothstep
                return s * 2 - 1  // Back to -1 to 1
            case .custom:
                return value
            }
        }
    }
}

public enum InputDeviceType: String, CaseIterable, Codable {
    // Traditional
    case keyboard = "Keyboard"
    case mouse = "Mouse"
    case touchpad = "Touchpad"
    case touchscreen = "Touchscreen"
    case gamepad = "Gamepad"
    case joystick = "Joystick"
    case flightStick = "Flight Stick"
    case throttleQuadrant = "Throttle Quadrant"
    case steeringWheel = "Steering Wheel"
    case pedals = "Pedals"

    // Advanced
    case motionController = "Motion Controller"
    case vrController = "VR Controller"
    case leapMotion = "Hand Tracking"
    case eyeTracker = "Eye Tracker"
    case headTracker = "Head Tracker"

    // Biometric
    case emgSensor = "EMG Sensor"
    case eegHeadset = "EEG Headset"
    case neuralInterface = "Neural Interface"
    case brainComputerInterface = "BCI"

    // Wearable
    case smartwatch = "Smart Watch"
    case smartRing = "Smart Ring"
    case hapticGlove = "Haptic Glove"
    case fullBodySuit = "Body Tracking Suit"

    // Voice
    case voiceCommand = "Voice Command"

    // Custom
    case custom = "Custom Device"
}

// MARK: - Network Motor Controller

/// Controls motors and actuators over WiFi/network
public class NetworkMotorController: ObservableObject {

    public struct MotorEndpoint: Codable, Identifiable {
        public var id: UUID
        public var name: String
        public var ipAddress: String
        public var port: Int
        public var protocol: CommunicationProtocol
        public var motorType: MotorType
        public var maxPower: Float        // Watts
        public var currentPower: Float
        public var status: MotorStatus
        public var lastHeartbeat: Date?
    }

    public enum CommunicationProtocol: String, CaseIterable, Codable {
        case http = "HTTP REST"
        case websocket = "WebSocket"
        case mqtt = "MQTT"
        case udp = "UDP"
        case tcp = "TCP Raw"
        case mavlink = "MAVLink"
        case ros2 = "ROS 2"
        case modbus = "Modbus TCP"
        case canOverEthernet = "CAN over Ethernet"
    }

    public enum MotorType: String, CaseIterable, Codable {
        case brushlessDC = "Brushless DC"
        case brushedDC = "Brushed DC"
        case stepper = "Stepper"
        case servo = "Servo"
        case linearActuator = "Linear Actuator"
        case hydraulic = "Hydraulic"
        case pneumatic = "Pneumatic"
        case solarElectric = "Solar Electric"
        case jetTurbine = "Jet Turbine"
        case propeller = "Propeller"
        case rotor = "Rotor"
        case thruster = "Thruster"
    }

    public enum MotorStatus: String, Codable {
        case offline = "Offline"
        case standby = "Standby"
        case running = "Running"
        case error = "Error"
        case emergency = "Emergency Stop"
    }

    @Published public var connectedMotors: [MotorEndpoint] = []
    @Published public var isScanning: Bool = false
    @Published public var connectionQuality: Float = 0

    private var heartbeatTimer: Timer?

    public init() {
        startHeartbeatMonitor()
    }

    /// Scan local network for controllable motors
    public func scanNetwork(subnet: String = "192.168.1") async -> [MotorEndpoint] {
        isScanning = true
        var discovered: [MotorEndpoint] = []

        // Scan common ports for motor controllers
        let ports = [80, 8080, 1883, 9090, 502, 5000]

        // Simulated discovery (real implementation would use network scanning)
        for i in 1...10 {
            let endpoint = MotorEndpoint(
                id: UUID(),
                name: "Motor_\(i)",
                ipAddress: "\(subnet).\(100 + i)",
                port: ports[i % ports.count],
                protocol: .websocket,
                motorType: .brushlessDC,
                maxPower: 1000,
                currentPower: 0,
                status: .standby,
                lastHeartbeat: Date()
            )
            discovered.append(endpoint)
        }

        isScanning = false
        return discovered
    }

    /// Connect to a specific motor endpoint
    public func connect(to endpoint: MotorEndpoint) async throws {
        var motor = endpoint
        motor.status = .standby
        motor.lastHeartbeat = Date()

        if let index = connectedMotors.firstIndex(where: { $0.id == endpoint.id }) {
            connectedMotors[index] = motor
        } else {
            connectedMotors.append(motor)
        }
    }

    /// Send control command to motor
    public func setMotorPower(_ motorId: UUID, power: Float) async throws {
        guard var motor = connectedMotors.first(where: { $0.id == motorId }) else {
            throw MotorError.motorNotFound
        }

        // Clamp power to safe range
        let safePower = max(0, min(1.0, power))

        // Create command packet
        let command = MotorCommand(
            motorId: motorId,
            power: safePower,
            timestamp: Date()
        )

        // Send command based on protocol
        try await sendCommand(command, to: motor)

        motor.currentPower = safePower * motor.maxPower
        motor.status = power > 0 ? .running : .standby

        if let index = connectedMotors.firstIndex(where: { $0.id == motorId }) {
            connectedMotors[index] = motor
        }
    }

    /// Emergency stop all motors
    public func emergencyStopAll() {
        for (index, _) in connectedMotors.enumerated() {
            connectedMotors[index].currentPower = 0
            connectedMotors[index].status = .emergency
        }

        // Broadcast emergency stop
        Task {
            await broadcastEmergencyStop()
        }
    }

    private func sendCommand(_ command: MotorCommand, to motor: MotorEndpoint) async throws {
        // Protocol-specific command sending
        switch motor.protocol {
        case .websocket:
            try await sendWebSocketCommand(command, to: motor)
        case .mqtt:
            try await sendMQTTCommand(command, to: motor)
        case .http:
            try await sendHTTPCommand(command, to: motor)
        case .mavlink:
            try await sendMAVLinkCommand(command, to: motor)
        default:
            try await sendTCPCommand(command, to: motor)
        }
    }

    private func sendWebSocketCommand(_ command: MotorCommand, to motor: MotorEndpoint) async throws {
        // WebSocket implementation
        let url = URL(string: "ws://\(motor.ipAddress):\(motor.port)/motor")!
        let data = try JSONEncoder().encode(command)
        // URLSessionWebSocketTask would be used here
        print("WebSocket command sent to \(url): \(data.count) bytes")
    }

    private func sendMQTTCommand(_ command: MotorCommand, to motor: MotorEndpoint) async throws {
        // MQTT implementation for IoT devices
        let topic = "echoelmusic/motor/\(motor.id)"
        print("MQTT publish to \(topic)")
    }

    private func sendHTTPCommand(_ command: MotorCommand, to motor: MotorEndpoint) async throws {
        // REST API implementation
        let url = URL(string: "http://\(motor.ipAddress):\(motor.port)/api/motor/control")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(command)
        // URLSession.shared.data(for: request) would be used here
    }

    private func sendMAVLinkCommand(_ command: MotorCommand, to motor: MotorEndpoint) async throws {
        // MAVLink protocol for drones
        // Uses standardized drone communication
        print("MAVLink command sent to \(motor.ipAddress)")
    }

    private func sendTCPCommand(_ command: MotorCommand, to motor: MotorEndpoint) async throws {
        // Raw TCP for industrial motors
        print("TCP command sent to \(motor.ipAddress):\(motor.port)")
    }

    private func broadcastEmergencyStop() async {
        for motor in connectedMotors {
            let command = MotorCommand(motorId: motor.id, power: 0, timestamp: Date(), emergency: true)
            try? await sendCommand(command, to: motor)
        }
    }

    private func startHeartbeatMonitor() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkHeartbeats()
        }
    }

    private func checkHeartbeats() {
        let timeout: TimeInterval = 5.0
        let now = Date()

        for (index, motor) in connectedMotors.enumerated() {
            if let lastBeat = motor.lastHeartbeat,
               now.timeIntervalSince(lastBeat) > timeout {
                connectedMotors[index].status = .offline
            }
        }

        // Calculate overall connection quality
        let onlineCount = connectedMotors.filter { $0.status != .offline }.count
        connectionQuality = connectedMotors.isEmpty ? 0 : Float(onlineCount) / Float(connectedMotors.count)
    }

    public struct MotorCommand: Codable {
        public var motorId: UUID
        public var power: Float          // 0-1
        public var timestamp: Date
        public var emergency: Bool = false
    }

    public enum MotorError: Error {
        case motorNotFound
        case connectionFailed
        case commandTimeout
        case invalidPower
        case emergencyStopped
    }
}

// MARK: - Multi-Motor Orchestrator

/// Coordinates multiple motors for complex vehicle control
public class MultiMotorOrchestrator: ObservableObject {

    @Published public var motorGroups: [MotorGroup] = []
    @Published public var activeConfiguration: VehicleConfiguration?

    private let networkController: NetworkMotorController

    public init(networkController: NetworkMotorController = NetworkMotorController()) {
        self.networkController = networkController
    }

    /// Define a group of motors that work together
    public struct MotorGroup: Identifiable, Codable {
        public var id: UUID
        public var name: String
        public var motorIds: [UUID]
        public var mixingMatrix: [[Float]]  // How control inputs map to each motor
        public var safetyLimits: SafetyLimits
    }

    public struct SafetyLimits: Codable {
        public var maxPower: Float = 1.0
        public var maxRateOfChange: Float = 0.5  // Per second
        public var emergencyRampDown: Float = 2.0  // Seconds to stop
        public var requireHeartbeat: Bool = true
    }

    /// Common vehicle configurations
    public struct VehicleConfiguration: Codable, Identifiable {
        public var id: UUID
        public var name: String
        public var type: SimulatorType
        public var motorGroups: [MotorGroup]
        public var controlMapping: [String: MotorMixing]

        public struct MotorMixing: Codable {
            public var axis: String           // e.g., "pitch", "throttle"
            public var motorWeights: [UUID: Float]  // Motor ID to weight
        }
    }

    // MARK: - Pre-defined Configurations

    /// Quadcopter drone configuration
    public static func quadcopterConfig() -> VehicleConfiguration {
        let frontLeft = UUID()
        let frontRight = UUID()
        let rearLeft = UUID()
        let rearRight = UUID()

        let allMotors = MotorGroup(
            id: UUID(),
            name: "All Rotors",
            motorIds: [frontLeft, frontRight, rearLeft, rearRight],
            mixingMatrix: [
                [1, 1, 1, 1],      // Throttle: all equal
                [1, 1, -1, -1],    // Pitch: front vs rear
                [-1, 1, -1, 1],    // Roll: left vs right
                [1, -1, -1, 1]     // Yaw: diagonal pairs
            ],
            safetyLimits: SafetyLimits()
        )

        return VehicleConfiguration(
            id: UUID(),
            name: "Quadcopter",
            type: .multirotorDrone,
            motorGroups: [allMotors],
            controlMapping: [
                "throttle": VehicleConfiguration.MotorMixing(
                    axis: "throttle",
                    motorWeights: [frontLeft: 1, frontRight: 1, rearLeft: 1, rearRight: 1]
                )
            ]
        )
    }

    /// Solar ship with multiple electric motors
    public static func solarShipConfig(motorCount: Int = 2) -> VehicleConfiguration {
        var motors: [UUID] = []
        for _ in 0..<motorCount {
            motors.append(UUID())
        }

        let propulsion = MotorGroup(
            id: UUID(),
            name: "Propulsion",
            motorIds: motors,
            mixingMatrix: motors.map { _ in Array(repeating: Float(1.0), count: motorCount) },
            safetyLimits: SafetyLimits(maxPower: 0.8)  // Solar power limit
        )

        return VehicleConfiguration(
            id: UUID(),
            name: "Solar Ship",
            type: .solarShip,
            motorGroups: [propulsion],
            controlMapping: [:]
        )
    }

    /// Submarine with thrusters
    public static func submarineConfig() -> VehicleConfiguration {
        let mainPropeller = UUID()
        let verticalFront = UUID()
        let verticalRear = UUID()
        let lateralBow = UUID()
        let lateralStern = UUID()

        let allThrusters = MotorGroup(
            id: UUID(),
            name: "All Thrusters",
            motorIds: [mainPropeller, verticalFront, verticalRear, lateralBow, lateralStern],
            mixingMatrix: [
                [1, 0, 0, 0, 0],     // Forward: main only
                [0, 1, 1, 0, 0],     // Depth: vertical thrusters
                [0, 1, -1, 0, 0],    // Pitch: vertical differential
                [0, 0, 0, 1, 1],     // Lateral: bow/stern thrusters
                [0, 0, 0, 1, -1]     // Yaw: lateral differential
            ],
            safetyLimits: SafetyLimits(maxPower: 0.9)
        )

        return VehicleConfiguration(
            id: UUID(),
            name: "Submarine",
            type: .submarine,
            motorGroups: [allThrusters],
            controlMapping: [:]
        )
    }

    // MARK: - Control Application

    /// Apply vehicle control state to all motors
    public func applyControl(_ state: VehicleControlState) async throws {
        guard let config = activeConfiguration else { return }

        for group in config.motorGroups {
            let inputs: [Float] = [
                state.throttle.value,
                state.pitch.value,
                state.roll.value,
                state.yaw.value
            ]

            // Apply mixing matrix
            for (motorIndex, motorId) in group.motorIds.enumerated() {
                if motorIndex < group.mixingMatrix.count {
                    var power: Float = 0
                    for (inputIndex, weight) in group.mixingMatrix[motorIndex].enumerated() {
                        if inputIndex < inputs.count {
                            power += inputs[inputIndex] * weight
                        }
                    }

                    // Apply safety limits
                    power = max(0, min(group.safetyLimits.maxPower, power))

                    // Handle emergency stop
                    if state.emergencyStop {
                        power = 0
                    }

                    try await networkController.setMotorPower(motorId, power: power)
                }
            }
        }
    }
}

// MARK: - Traditional Input Handler

/// Handles keyboard, gamepad, joystick, and other traditional inputs
public class TraditionalInputHandler: ObservableObject {

    @Published public var connectedDevices: [InputDevice] = []
    @Published public var activeDevice: InputDevice?

    public struct InputDevice: Identifiable {
        public var id: UUID
        public var name: String
        public var type: InputDeviceType
        public var vendorId: Int?
        public var productId: Int?
        public var axes: [String: Float]
        public var buttons: [String: Bool]
        public var isConnected: Bool
    }

    // MARK: - Standard Mappings

    /// Xbox/PlayStation gamepad mapping
    public static let gamepadMapping = InputMapping(
        deviceType: .gamepad,
        axisBindings: [
            "leftStickX": InputMapping.AxisBinding(inputAxis: "leftStickX", targetAxis: "roll", curve: .exponential, multiplier: 1.0),
            "leftStickY": InputMapping.AxisBinding(inputAxis: "leftStickY", targetAxis: "pitch", curve: .exponential, multiplier: 1.0),
            "rightStickX": InputMapping.AxisBinding(inputAxis: "rightStickX", targetAxis: "yaw", curve: .linear, multiplier: 0.8),
            "rightStickY": InputMapping.AxisBinding(inputAxis: "rightStickY", targetAxis: "throttle", curve: .linear, multiplier: 1.0),
            "leftTrigger": InputMapping.AxisBinding(inputAxis: "leftTrigger", targetAxis: "brake", curve: .linear, multiplier: 1.0),
            "rightTrigger": InputMapping.AxisBinding(inputAxis: "rightTrigger", targetAxis: "throttle", curve: .linear, multiplier: 1.0)
        ],
        buttonBindings: [
            "buttonA": InputMapping.ButtonBinding(inputButton: "buttonA", action: "activate"),
            "buttonB": InputMapping.ButtonBinding(inputButton: "buttonB", action: "cancel"),
            "buttonX": InputMapping.ButtonBinding(inputButton: "buttonX", action: "secondaryAction"),
            "buttonY": InputMapping.ButtonBinding(inputButton: "buttonY", action: "toggleMode"),
            "leftBumper": InputMapping.ButtonBinding(inputButton: "leftBumper", action: "previousItem"),
            "rightBumper": InputMapping.ButtonBinding(inputButton: "rightBumper", action: "nextItem"),
            "start": InputMapping.ButtonBinding(inputButton: "start", action: "pause"),
            "select": InputMapping.ButtonBinding(inputButton: "select", action: "menu")
        ]
    )

    /// Flight stick mapping
    public static let flightStickMapping = InputMapping(
        deviceType: .flightStick,
        axisBindings: [
            "stickX": InputMapping.AxisBinding(inputAxis: "stickX", targetAxis: "roll", curve: .sCurve, multiplier: 1.0),
            "stickY": InputMapping.AxisBinding(inputAxis: "stickY", targetAxis: "pitch", curve: .sCurve, multiplier: 1.0),
            "stickZ": InputMapping.AxisBinding(inputAxis: "stickZ", targetAxis: "yaw", curve: .linear, multiplier: 1.0),
            "throttle": InputMapping.AxisBinding(inputAxis: "throttle", targetAxis: "throttle", curve: .linear, multiplier: 1.0)
        ],
        buttonBindings: [
            "trigger": InputMapping.ButtonBinding(inputButton: "trigger", action: "primaryFire"),
            "thumb": InputMapping.ButtonBinding(inputButton: "thumb", action: "secondaryAction"),
            "hatUp": InputMapping.ButtonBinding(inputButton: "hatUp", action: "trimUp"),
            "hatDown": InputMapping.ButtonBinding(inputButton: "hatDown", action: "trimDown"),
            "hatLeft": InputMapping.ButtonBinding(inputButton: "hatLeft", action: "trimLeft"),
            "hatRight": InputMapping.ButtonBinding(inputButton: "hatRight", action: "trimRight")
        ]
    )

    /// Keyboard mapping (WASD + arrows)
    public static let keyboardMapping = InputMapping(
        deviceType: .keyboard,
        axisBindings: [:],  // Keyboard uses digital inputs, converted in handler
        buttonBindings: [
            "w": InputMapping.ButtonBinding(inputButton: "w", action: "pitchDown"),
            "s": InputMapping.ButtonBinding(inputButton: "s", action: "pitchUp"),
            "a": InputMapping.ButtonBinding(inputButton: "a", action: "rollLeft"),
            "d": InputMapping.ButtonBinding(inputButton: "d", action: "rollRight"),
            "q": InputMapping.ButtonBinding(inputButton: "q", action: "yawLeft"),
            "e": InputMapping.ButtonBinding(inputButton: "e", action: "yawRight"),
            "shift": InputMapping.ButtonBinding(inputButton: "shift", action: "throttleUp"),
            "ctrl": InputMapping.ButtonBinding(inputButton: "ctrl", action: "throttleDown"),
            "space": InputMapping.ButtonBinding(inputButton: "space", action: "brake"),
            "escape": InputMapping.ButtonBinding(inputButton: "escape", action: "emergencyStop")
        ]
    )

    /// Touchpad safe mode mapping
    public static let touchpadMapping = InputMapping(
        deviceType: .touchpad,
        axisBindings: [
            "touchX": InputMapping.AxisBinding(inputAxis: "touchX", targetAxis: "roll", curve: .linear, multiplier: 0.5),
            "touchY": InputMapping.AxisBinding(inputAxis: "touchY", targetAxis: "pitch", curve: .linear, multiplier: 0.5),
            "pressure": InputMapping.AxisBinding(inputAxis: "pressure", targetAxis: "throttle", curve: .logarithmic, multiplier: 0.3)
        ],
        buttonBindings: [
            "tap": InputMapping.ButtonBinding(inputButton: "tap", action: "activate"),
            "doubleTap": InputMapping.ButtonBinding(inputButton: "doubleTap", action: "center"),
            "twoFingerTap": InputMapping.ButtonBinding(inputButton: "twoFingerTap", action: "emergencyStop")
        ]
    )

    // MARK: - Input Processing

    /// Convert keyboard digital inputs to axis values
    public func keyboardToAxis(pressedKeys: Set<String>) -> VehicleControlState {
        var state = VehicleControlState(simulatorType: .multirotorDrone)

        // Pitch (W/S)
        if pressedKeys.contains("w") { state.pitch.value = -1.0 }
        if pressedKeys.contains("s") { state.pitch.value = 1.0 }

        // Roll (A/D)
        if pressedKeys.contains("a") { state.roll.value = -1.0 }
        if pressedKeys.contains("d") { state.roll.value = 1.0 }

        // Yaw (Q/E)
        if pressedKeys.contains("q") { state.yaw.value = -1.0 }
        if pressedKeys.contains("e") { state.yaw.value = 1.0 }

        // Throttle (Shift/Ctrl)
        if pressedKeys.contains("shift") { state.throttle.value = 1.0 }
        if pressedKeys.contains("ctrl") { state.throttle.value = -1.0 }

        // Brake (Space)
        if pressedKeys.contains("space") { state.brake.value = 1.0 }

        // Emergency Stop (Escape)
        if pressedKeys.contains("escape") { state.emergencyStop = true }

        return state
    }

    /// Process touchpad gestures for safe mode control
    public func processTouchpadGesture(_ gesture: TouchpadGesture) -> VehicleControlState {
        var state = VehicleControlState(simulatorType: .multirotorDrone)

        // Limit sensitivity for safety
        let safeMultiplier: Float = 0.3

        state.roll.value = gesture.deltaX * safeMultiplier
        state.pitch.value = gesture.deltaY * safeMultiplier
        state.throttle.value = gesture.pressure * safeMultiplier

        // Two-finger gesture = emergency stop
        if gesture.fingerCount >= 2 {
            state.emergencyStop = true
        }

        return state
    }

    public struct TouchpadGesture {
        public var deltaX: Float
        public var deltaY: Float
        public var pressure: Float
        public var fingerCount: Int
    }
}

// MARK: - Simulator Control Manager

/// Main coordinator for all simulator control
@MainActor
public class SimulatorControlManager: ObservableObject {

    @Published public var currentSimulator: SimulatorType?
    @Published public var controlState: VehicleControlState?
    @Published public var safetyStatus: SafetyStatus = .safe
    @Published public var isOperational: Bool = false

    public let networkMotorController: NetworkMotorController
    public let motorOrchestrator: MultiMotorOrchestrator
    public let inputHandler: TraditionalInputHandler

    private var controlSubscription: AnyCancellable?

    public enum SafetyStatus: String {
        case safe = "Safe"
        case warning = "Warning"
        case critical = "Critical"
        case blocked = "Blocked"
    }

    public init() {
        self.networkMotorController = NetworkMotorController()
        self.motorOrchestrator = MultiMotorOrchestrator(networkController: networkMotorController)
        self.inputHandler = TraditionalInputHandler()
    }

    /// Initialize simulator for a specific vehicle type
    public func initializeSimulator(_ type: SimulatorType) {
        currentSimulator = type
        controlState = VehicleControlState(simulatorType: type)

        // Set up appropriate motor configuration
        switch type {
        case .multirotorDrone:
            motorOrchestrator.activeConfiguration = MultiMotorOrchestrator.quadcopterConfig()
        case .solarShip:
            motorOrchestrator.activeConfiguration = MultiMotorOrchestrator.solarShipConfig()
        case .submarine, .underwaterDrone:
            motorOrchestrator.activeConfiguration = MultiMotorOrchestrator.submarineConfig()
        default:
            break
        }

        isOperational = true
    }

    /// Apply control input with safety checks
    public func applyControlInput(_ input: ControlInput) async throws {
        guard var state = controlState else { return }
        guard safetyStatus != .blocked else {
            throw SimulatorError.operatorBlocked
        }

        // Update state from input
        switch input {
        case .axis(let name, let value):
            switch name {
            case "throttle": state.throttle.update(rawValue: value)
            case "pitch": state.pitch.update(rawValue: value)
            case "roll": state.roll.update(rawValue: value)
            case "yaw": state.yaw.update(rawValue: value)
            case "brake": state.brake.update(rawValue: value)
            default: break
            }

        case .button(let name, let pressed):
            if name == "emergencyStop" && pressed {
                state.emergencyStop = true
                networkMotorController.emergencyStopAll()
            }

        case .gesture(let gesture):
            let gestureState = inputHandler.processTouchpadGesture(gesture)
            state.throttle = gestureState.throttle
            state.pitch = gestureState.pitch
            state.roll = gestureState.roll

        case .keyboard(let keys):
            let keyState = inputHandler.keyboardToAxis(pressedKeys: keys)
            state.throttle = keyState.throttle
            state.pitch = keyState.pitch
            state.roll = keyState.roll
            state.yaw = keyState.yaw
            state.emergencyStop = keyState.emergencyStop
        }

        controlState = state

        // Apply to motors
        try await motorOrchestrator.applyControl(state)
    }

    /// Emergency stop everything
    public func emergencyStop() {
        controlState?.emergencyStop = true
        networkMotorController.emergencyStopAll()
        safetyStatus = .blocked
    }

    public enum ControlInput {
        case axis(name: String, value: Float)
        case button(name: String, pressed: Bool)
        case gesture(TraditionalInputHandler.TouchpadGesture)
        case keyboard(Set<String>)
    }

    public enum SimulatorError: Error {
        case notInitialized
        case operatorBlocked
        case safetyViolation
        case connectionLost
    }
}

// MARK: - Future-Proof Extension Points

/// Protocol for future device types
public protocol FutureDeviceProtocol {
    var deviceId: String { get }
    var capabilities: [String] { get }

    func connect() async throws
    func disconnect() async
    func readState() async -> [String: Any]
    func sendCommand(_ command: [String: Any]) async throws
}

/// Protocol for future vehicle types
public protocol FutureVehicleProtocol {
    var vehicleId: String { get }
    var controlAxes: [ControlAxis] { get }

    func initialize() async throws
    func shutdown() async
    func applyControl(_ state: VehicleControlState) async throws
    func getStatus() async -> [String: Any]
}

/// Extension point for community-developed controllers
public protocol ControllerPlugin {
    var pluginId: String { get }
    var pluginName: String { get }
    var supportedDevices: [InputDeviceType] { get }

    func initialize() throws
    func processInput(_ rawInput: [String: Any]) -> VehicleControlState?
}

// MARK: - Convenience Extensions

extension SimulatorControlManager {

    /// Quick setup for common scenarios
    public func quickSetupDrone() async {
        initializeSimulator(.multirotorDrone)
        _ = await networkMotorController.scanNetwork()
    }

    public func quickSetupSolarShip() async {
        initializeSimulator(.solarShip)
        _ = await networkMotorController.scanNetwork()
    }

    public func quickSetupSubmarine() async {
        initializeSimulator(.submarine)
        _ = await networkMotorController.scanNetwork()
    }
}
