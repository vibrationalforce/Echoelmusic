// UniversalControlTests.swift
// Echoelmusic - Comprehensive Tests for Universal Control System
//
// Tests: SimulatorControlFramework, NetworkMotorController, Safety Systems

import XCTest
@testable import Echoelmusic

final class UniversalControlTests: XCTestCase {

    // MARK: - SimulatorControlFramework Tests

    func testSimulatorTypesExist() {
        // Verify all simulator types are defined
        XCTAssertEqual(SimulatorType.allCases.count, 40, "Should have 40 simulator types")

        // Check categories
        let aerialTypes = SimulatorType.allCases.filter { $0.category == .aerial }
        XCTAssertGreaterThan(aerialTypes.count, 5, "Should have multiple aerial types")

        let medicalTypes = SimulatorType.allCases.filter { $0.category == .medical }
        XCTAssertGreaterThan(medicalTypes.count, 3, "Should have medical types")
    }

    func testSafetyIntegrityLevels() {
        // Medical devices should require highest safety
        XCTAssertEqual(SimulatorType.surgicalRobot.requiredSafetyLevel, .silD)
        XCTAssertEqual(SimulatorType.nanobot.requiredSafetyLevel, .silD)

        // Aircraft should require high safety
        XCTAssertEqual(SimulatorType.fixedWingAircraft.requiredSafetyLevel, .silC)
        XCTAssertEqual(SimulatorType.helicopter.requiredSafetyLevel, .silC)

        // Ground vehicles moderate
        XCTAssertEqual(SimulatorType.car.requiredSafetyLevel, .silB)
    }

    func testControlAxisDeadzone() {
        var axis = ControlAxis(name: "Test", deadzone: 0.1)

        // Values within deadzone should be zero
        axis.update(rawValue: 0.05)
        XCTAssertEqual(axis.value, 0, accuracy: 0.001)

        axis.update(rawValue: -0.05)
        XCTAssertEqual(axis.value, 0, accuracy: 0.001)

        // Values outside deadzone should pass through (scaled)
        axis.update(rawValue: 0.5)
        XCTAssertGreaterThan(axis.value, 0)
    }

    func testControlAxisInversion() {
        var axis = ControlAxis(name: "Test", inverted: true)
        axis.update(rawValue: 1.0)

        // Inverted axis should flip sign
        XCTAssertLessThan(axis.value, 0)
    }

    func testControlAxisClamping() {
        var axis = ControlAxis(name: "Test", sensitivity: 2.0)
        axis.update(rawValue: 1.0)

        // Even with high sensitivity, should clamp to -1...1
        XCTAssertLessThanOrEqual(axis.value, 1.0)
        XCTAssertGreaterThanOrEqual(axis.value, -1.0)
    }

    func testVehicleControlStateInitialization() {
        let droneState = VehicleControlState(simulatorType: .multirotorDrone)

        // Drone should have aerial-specific controls
        XCTAssertNotNil(droneState.auxiliaryAxes["flaps"])
        XCTAssertNotNil(droneState.buttons["landingGear"])
    }

    func testMedicalSimulatorHighPrecision() {
        let surgicalState = VehicleControlState(simulatorType: .surgicalRobot)

        // Medical should have high stabilization
        XCTAssertGreaterThan(surgicalState.stabilizationLevel, 0.9)

        // Should have precision control
        XCTAssertNotNil(surgicalState.auxiliaryAxes["precision"])
    }

    // MARK: - NetworkMotorController Tests

    func testNetworkMotorControllerInitialization() {
        let controller = NetworkMotorController()

        XCTAssertTrue(controller.connectedMotors.isEmpty)
        XCTAssertFalse(controller.isScanning)
        XCTAssertEqual(controller.connectionQuality, 0)
    }

    func testNetworkScanReturnsSimulatedMotors() async {
        let controller = NetworkMotorController()

        let motors = await controller.scanNetwork()

        // Should return simulated motors (clearly marked)
        XCTAssertEqual(motors.count, 10)
        XCTAssertTrue(motors.first?.name.contains("Simulated") == true)
    }

    func testMotorEndpointProtocols() {
        // All protocols should be defined
        let allProtocols = NetworkMotorController.CommunicationProtocol.allCases
        XCTAssertGreaterThan(allProtocols.count, 5)

        // Check specific protocols exist
        XCTAssertTrue(allProtocols.contains(.http))
        XCTAssertTrue(allProtocols.contains(.websocket))
        XCTAssertTrue(allProtocols.contains(.mqtt))
        XCTAssertTrue(allProtocols.contains(.mavlink))
    }

    func testEmergencyStopAllMotors() {
        let controller = NetworkMotorController()

        // Should not crash even with no motors
        controller.emergencyStopAll()

        // All motors should be stopped
        for motor in controller.connectedMotors {
            XCTAssertEqual(motor.status, .emergency)
            XCTAssertEqual(motor.currentPower, 0)
        }
    }

    // MARK: - Input Mapping Tests

    func testGamepadMapping() {
        let mapping = TraditionalInputHandler.gamepadMapping

        XCTAssertEqual(mapping.deviceType, .gamepad)
        XCTAssertFalse(mapping.axisBindings.isEmpty)
        XCTAssertFalse(mapping.buttonBindings.isEmpty)

        // Check critical bindings exist
        XCTAssertNotNil(mapping.axisBindings["leftStickX"])
        XCTAssertNotNil(mapping.axisBindings["leftStickY"])
    }

    func testKeyboardToAxisConversion() {
        let handler = TraditionalInputHandler()

        // W key should pitch down
        let wState = handler.keyboardToAxis(pressedKeys: ["w"])
        XCTAssertLessThan(wState.pitch.value, 0)

        // Escape should trigger emergency stop
        let escState = handler.keyboardToAxis(pressedKeys: ["escape"])
        XCTAssertTrue(escState.emergencyStop)
    }

    func testTouchpadSafeMode() {
        let handler = TraditionalInputHandler()

        let gesture = TraditionalInputHandler.TouchpadGesture(
            deltaX: 1.0,
            deltaY: 1.0,
            pressure: 1.0,
            fingerCount: 1
        )

        let state = handler.processTouchpadGesture(gesture)

        // Safe mode should limit sensitivity
        XCTAssertLessThan(abs(state.roll.value), 0.5)
        XCTAssertLessThan(abs(state.pitch.value), 0.5)
    }

    func testTwoFingerEmergencyStop() {
        let handler = TraditionalInputHandler()

        let gesture = TraditionalInputHandler.TouchpadGesture(
            deltaX: 0,
            deltaY: 0,
            pressure: 0,
            fingerCount: 2  // Two fingers = emergency
        )

        let state = handler.processTouchpadGesture(gesture)
        XCTAssertTrue(state.emergencyStop)
    }

    // MARK: - Response Curve Tests

    func testResponseCurveLinear() {
        let curve = InputMapping.ResponseCurve.linear
        XCTAssertEqual(curve.apply(0.5), 0.5, accuracy: 0.001)
        XCTAssertEqual(curve.apply(-0.5), -0.5, accuracy: 0.001)
    }

    func testResponseCurveExponential() {
        let curve = InputMapping.ResponseCurve.exponential

        // Exponential should reduce small inputs
        XCTAssertLessThan(abs(curve.apply(0.5)), 0.5)

        // But preserve sign and extremes
        XCTAssertGreaterThan(curve.apply(0.5), 0)
        XCTAssertEqual(curve.apply(1.0), 1.0, accuracy: 0.001)
    }

    func testResponseCurveSCurve() {
        let curve = InputMapping.ResponseCurve.sCurve

        // S-curve should be smooth at center
        let center = curve.apply(0)
        XCTAssertEqual(center, 0, accuracy: 0.1)

        // And reach extremes
        XCTAssertGreaterThan(curve.apply(1.0), 0.9)
    }

    // MARK: - Error Handling Tests

    func testMotorErrorDescriptions() {
        let errors: [NetworkMotorController.MotorError] = [
            .motorNotFound,
            .connectionFailed,
            .protocolNotImplemented("WebSocket"),
            .commandFailed(statusCode: 500)
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    // MARK: - Multi-Motor Orchestrator Tests

    func testQuadcopterConfiguration() {
        let config = MultiMotorOrchestrator.quadcopterConfig()

        XCTAssertEqual(config.type, .multirotorDrone)
        XCTAssertEqual(config.motorGroups.first?.motorIds.count, 4)
    }

    func testSolarShipConfiguration() {
        let config = MultiMotorOrchestrator.solarShipConfig(motorCount: 3)

        XCTAssertEqual(config.type, .solarShip)
        XCTAssertEqual(config.motorGroups.first?.motorIds.count, 3)
    }

    func testSubmarineConfiguration() {
        let config = MultiMotorOrchestrator.submarineConfig()

        XCTAssertEqual(config.type, .submarine)
        // Submarine has 5 thrusters (main, 2 vertical, 2 lateral)
        XCTAssertEqual(config.motorGroups.first?.motorIds.count, 5)
    }
}

// MARK: - Safety Tests

final class SafetySystemTests: XCTestCase {

    func testSafetyIntegrityLevelComparison() {
        XCTAssertTrue(SafetyIntegrityLevel.silA < SafetyIntegrityLevel.silB)
        XCTAssertTrue(SafetyIntegrityLevel.silB < SafetyIntegrityLevel.silC)
        XCTAssertTrue(SafetyIntegrityLevel.silC < SafetyIntegrityLevel.silD)
    }

    func testControlModeValues() {
        let modes = ControlMode.allCases
        XCTAssertEqual(modes.count, 5)

        XCTAssertTrue(modes.contains(.manual))
        XCTAssertTrue(modes.contains(.autonomous))
        XCTAssertTrue(modes.contains(.emergency))
    }
}

// MARK: - Performance Tests

final class ControlPerformanceTests: XCTestCase {

    func testAxisUpdatePerformance() {
        var axis = ControlAxis(name: "Test")

        measure {
            for i in 0..<10000 {
                let value = Float(i % 200 - 100) / 100.0
                axis.update(rawValue: value)
            }
        }
    }

    func testKeyboardMappingPerformance() {
        let handler = TraditionalInputHandler()
        let keys: Set<String> = ["w", "a", "shift", "space"]

        measure {
            for _ in 0..<1000 {
                _ = handler.keyboardToAxis(pressedKeys: keys)
            }
        }
    }
}
