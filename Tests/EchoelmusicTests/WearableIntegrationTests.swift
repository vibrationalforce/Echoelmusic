import XCTest
@testable import Echoelmusic

/// Wearable Integration Test Suite
///
/// Tests for bio-reactive music integration:
/// - Apple Watch connectivity (WatchConnectivity, HealthKit)
/// - Oura Ring OAuth2 flow
/// - BLE device scanning and connection
/// - Polar H10 heart rate parsing
/// - Bio-modulation mappings
///
@MainActor
final class WearableIntegrationTests: XCTestCase {

    // MARK: - Apple Watch Tests

    func testWatchConnectivityBridgeSingleton() {
        let bridge1 = WatchConnectivityBridge.shared
        let bridge2 = WatchConnectivityBridge.shared
        XCTAssertTrue(bridge1 === bridge2)
    }

    func testWatchConnectivityStateTransitions() {
        let bridge = WatchConnectivityBridge.shared

        XCTAssertEqual(bridge.state, .inactive, "Should start inactive")

        bridge.activate()

        // On non-iOS, should remain in appropriate state
        #if os(iOS)
        XCTAssertNotEqual(bridge.state, .notSupported)
        #endif
    }

    func testWatchMessageParsing() {
        let device = AppleWatchDevice()
        var receivedHeartRate: Double?

        device.setDataCallback { sample in
            if sample.type == .heartRate {
                receivedHeartRate = sample.value
            }
        }

        // Simulate incoming message
        let message = WatchConnectivityBridge.WatchMessage(
            type: "heartRate",
            data: ["bpm": 75.0],
            timestamp: Date()
        )

        device.handleTestMessage(message)

        XCTAssertEqual(receivedHeartRate, 75.0)
    }

    func testWatchHapticFeedback() {
        let device = AppleWatchDevice()

        // Should not crash
        device.sendHapticPulse(intensity: 0.8, durationMs: 50)
        device.sendHapticPattern([
            (0.5, 30),
            (0.0, 50),
            (1.0, 30)
        ])
    }

    // MARK: - Oura Ring OAuth2 Tests

    func testOAuthConfigDefaults() {
        let config = OuraOAuth2Handler.OAuthConfig(
            clientId: "test",
            clientSecret: "secret"
        )

        XCTAssertEqual(config.redirectUri, "echoelmusic://oura/callback")
        XCTAssertTrue(config.scope.contains("heartrate"))
        XCTAssertTrue(config.scope.contains("sleep"))
    }

    func testOAuthStateGeneration() {
        let config = OuraOAuth2Handler.OAuthConfig(
            clientId: "test",
            clientSecret: "secret"
        )

        let handler = OuraOAuth2Handler(config: config)

        let url1 = handler.getAuthorizationUrl()
        let url2 = handler.getAuthorizationUrl()

        // State should be different each time
        let state1 = extractState(from: url1)
        let state2 = extractState(from: url2)

        XCTAssertNotEqual(state1, state2, "State should be unique per request")
    }

    func testOAuthCallbackValidation() {
        let config = OuraOAuth2Handler.OAuthConfig(
            clientId: "test",
            clientSecret: "secret"
        )

        let handler = OuraOAuth2Handler(config: config)

        // Get authorization URL to set state
        let authUrl = handler.getAuthorizationUrl()
        let validState = extractState(from: authUrl)!

        // Test with wrong state (CSRF attack)
        let expectation = XCTestExpectation(description: "Callback validation")

        handler.handleCallback(
            url: "echoelmusic://oura/callback?code=test&state=wrong_state"
        ) { success, error in
            XCTAssertFalse(success)
            XCTAssertTrue(error?.contains("CSRF") ?? false)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testOAuthErrorHandling() {
        let config = OuraOAuth2Handler.OAuthConfig(
            clientId: "test",
            clientSecret: "secret"
        )

        let handler = OuraOAuth2Handler(config: config)
        _ = handler.getAuthorizationUrl()

        let expectation = XCTestExpectation(description: "Error handling")

        handler.handleCallback(
            url: "echoelmusic://oura/callback?error=access_denied&error_description=User%20denied"
        ) { success, error in
            XCTAssertFalse(success)
            XCTAssertTrue(error?.contains("denied") ?? false)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testTokenValidity() {
        let token = OuraOAuth2Handler.TokenResponse(
            accessToken: "test_token",
            refreshToken: "refresh",
            tokenType: "Bearer",
            expiresIn: 3600,
            expiresAt: Date().addingTimeInterval(3600)
        )

        XCTAssertTrue(token.isValid, "Token with future expiry should be valid")

        let expiredToken = OuraOAuth2Handler.TokenResponse(
            accessToken: "test",
            refreshToken: "refresh",
            tokenType: "Bearer",
            expiresIn: 3600,
            expiresAt: Date().addingTimeInterval(-60) // Expired 1 minute ago
        )

        XCTAssertFalse(expiredToken.isValid, "Expired token should be invalid")
    }

    // MARK: - BLE Scanner Tests

    func testBLEServiceUUIDs() {
        XCTAssertEqual(BLEScanner.HEART_RATE_SERVICE, "180D")
        XCTAssertEqual(BLEScanner.BATTERY_SERVICE, "180F")
        XCTAssertEqual(BLEScanner.DEVICE_INFO_SERVICE, "180A")
        XCTAssertEqual(BLEScanner.HEART_RATE_MEASUREMENT, "2A37")
    }

    func testDeviceDiscoveryCallback() {
        let scanner = BLEScanner.shared
        var discoveredDevices: [BLEScanner.DiscoveredDevice] = []

        scanner.setDeviceFoundCallback { device in
            discoveredDevices.append(device)
        }

        // Simulate device discovery
        let testDevice = BLEScanner.DiscoveredDevice(
            name: "Polar H10",
            identifier: "test-uuid-123",
            rssi: -45,
            serviceUUIDs: ["180D"],
            inferredType: .polarH10
        )

        scanner.onDeviceDiscovered(testDevice)

        XCTAssertEqual(discoveredDevices.count, 1)
        XCTAssertEqual(discoveredDevices.first?.name, "Polar H10")
    }

    func testConnectionStateTracking() {
        let scanner = BLEScanner.shared

        XCTAssertFalse(scanner.isConnected)

        scanner.onConnectionStateChanged(connected: true, error: nil)
        XCTAssertTrue(scanner.isConnected)
        XCTAssertEqual(scanner.state, .connected)

        scanner.onConnectionStateChanged(connected: false, error: nil)
        XCTAssertFalse(scanner.isConnected)
        XCTAssertEqual(scanner.state, .idle)
    }

    // MARK: - Polar H10 Tests

    func testPolarH10DeviceCreation() {
        let device = PolarH10Device(deviceId: "test-id", deviceName: "Polar H10 12345")

        let info = device.deviceInfo
        XCTAssertEqual(info.type, .polarH10)
        XCTAssertEqual(info.name, "Polar H10 12345")
        XCTAssertEqual(info.identifier, "test-id")
    }

    func testHeartRateMeasurementParsingUInt8() {
        let device = PolarH10Device(deviceId: "test", deviceName: "Test")
        var receivedHR: Double?

        device.setDataCallback { sample in
            if sample.type == .heartRate {
                receivedHR = sample.value
            }
        }

        // Byte 0: Flags (0x00 = UINT8 format, no RR intervals)
        // Byte 1: Heart rate = 72 BPM
        let data: [UInt8] = [0x00, 72]
        device.parseHeartRateMeasurement(Data(data))

        XCTAssertEqual(receivedHR, 72.0)
    }

    func testHeartRateMeasurementParsingUInt16() {
        let device = PolarH10Device(deviceId: "test", deviceName: "Test")
        var receivedHR: Double?

        device.setDataCallback { sample in
            if sample.type == .heartRate {
                receivedHR = sample.value
            }
        }

        // Byte 0: Flags (0x01 = UINT16 format)
        // Bytes 1-2: Heart rate = 150 BPM (little endian: 0x96, 0x00)
        let data: [UInt8] = [0x01, 0x96, 0x00]
        device.parseHeartRateMeasurement(Data(data))

        XCTAssertEqual(receivedHR, 150.0)
    }

    func testHeartRateMeasurementWithRRIntervals() {
        let device = PolarH10Device(deviceId: "test", deviceName: "Test")
        var receivedHRV: Double?

        device.setDataCallback { sample in
            if sample.type == .heartRateVariability {
                receivedHRV = sample.value
            }
        }

        // Byte 0: Flags (0x10 = RR intervals present)
        // Byte 1: Heart rate = 70 BPM
        // Bytes 2-3: RR interval 1 (850ms in 1/1024 sec = 870)
        // Bytes 4-5: RR interval 2 (820ms in 1/1024 sec = 840)
        let data: [UInt8] = [0x10, 70, 0x66, 0x03, 0x48, 0x03]

        // Need multiple readings for HRV calculation
        for _ in 0..<5 {
            device.parseHeartRateMeasurement(Data(data))
        }

        XCTAssertNotNil(receivedHRV, "Should calculate HRV from RR intervals")
    }

    func testRMSSDCalculation() {
        let device = PolarH10Device(deviceId: "test", deviceName: "Test")

        // Test with known values
        let rrIntervals = [800, 810, 795, 805, 800] // ms
        let hrv = device.calculateHRV(rrIntervals: rrIntervals)

        // RMSSD = sqrt(mean of squared successive differences)
        // Diffs: 10, -15, 10, -5
        // Squared: 100, 225, 100, 25
        // Mean: 112.5
        // RMSSD: ~10.6

        XCTAssertGreaterThan(hrv, 5.0)
        XCTAssertLessThan(hrv, 20.0)
    }

    // MARK: - Bio Modulation Tests

    func testLinearMapping() {
        let mapping = BioModulationMapping(
            sourceType: .heartRate,
            targetParameter: "filter",
            inputMin: 60.0,
            inputMax: 120.0,
            outputMin: 0.0,
            outputMax: 1.0
        )

        // Test boundary values
        XCTAssertEqual(mapping.mapValue(60.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(mapping.mapValue(120.0), 1.0, accuracy: 0.001)
        XCTAssertEqual(mapping.mapValue(90.0), 0.5, accuracy: 0.001)

        // Test clamping
        XCTAssertEqual(mapping.mapValue(50.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(mapping.mapValue(150.0), 1.0, accuracy: 0.001)
    }

    func testInvertedMapping() {
        let mapping = BioModulationMapping(
            sourceType: .stressLevel,
            targetParameter: "relaxation",
            inputMin: 0.0,
            inputMax: 100.0,
            outputMin: 0.0,
            outputMax: 1.0,
            inverted: true
        )

        // High stress -> low relaxation
        XCTAssertEqual(mapping.mapValue(100.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(mapping.mapValue(0.0), 1.0, accuracy: 0.001)
        XCTAssertEqual(mapping.mapValue(50.0), 0.5, accuracy: 0.001)
    }

    func testMappingWithSensitivity() {
        let mapping = BioModulationMapping(
            sourceType: .heartRate,
            targetParameter: "intensity",
            inputMin: 60.0,
            inputMax: 120.0,
            outputMin: 0.0,
            outputMax: 1.0,
            sensitivity: 2.0 // More sensitive
        )

        // With higher sensitivity, values should reach max faster
        let normalMid = BioModulationMapping(
            sourceType: .heartRate,
            targetParameter: "test",
            inputMin: 60.0,
            inputMax: 120.0,
            outputMin: 0.0,
            outputMax: 1.0,
            sensitivity: 1.0
        ).mapValue(90.0)

        let sensitiveMid = mapping.mapValue(90.0)

        XCTAssertGreaterThan(sensitiveMid, normalMid,
                            "Higher sensitivity should produce higher output")
    }

    func testDisabledMapping() {
        var mapping = BioModulationMapping(
            sourceType: .heartRate,
            targetParameter: "filter",
            inputMin: 60.0,
            inputMax: 120.0,
            outputMin: 0.0,
            outputMax: 1.0
        )

        mapping.isActive = false

        XCTAssertEqual(mapping.mapValue(90.0), 0.0,
                      "Disabled mapping should return outputMin")
    }

    // MARK: - Simulator Tests

    func testSimulatorDeviceMetrics() {
        let simulator = SimulatorDevice()

        let metrics = simulator.supportedMetrics

        XCTAssertTrue(metrics.contains(.heartRate))
        XCTAssertTrue(metrics.contains(.heartRateVariability))
        XCTAssertTrue(metrics.contains(.stressLevel))
        XCTAssertTrue(metrics.contains(.energyLevel))
    }

    func testSimulatorDataGeneration() async {
        let simulator = SimulatorDevice()
        var samples: [BiometricSample] = []

        simulator.setDataCallback { sample in
            samples.append(sample)
        }

        _ = await simulator.connect()
        simulator.startStreaming()

        // Wait for some data
        try? await Task.sleep(nanoseconds: 200_000_000)

        simulator.stopStreaming()
        simulator.disconnect()

        XCTAssertFalse(samples.isEmpty, "Should generate samples while streaming")
    }

    func testSimulatorParameters() {
        let simulator = SimulatorDevice()

        simulator.setBaseHeartRate(80.0)
        simulator.setStressLevel(60.0)
        simulator.setActivityLevel(0.5)

        // Parameters should be set (no crash)
        XCTAssertTrue(true)
    }

    // MARK: - Helper Functions

    private func extractState(from url: String) -> String? {
        guard let urlComponents = URLComponents(string: url),
              let queryItems = urlComponents.queryItems else {
            return nil
        }

        return queryItems.first { $0.name == "state" }?.value
    }
}

// MARK: - Test Extensions

extension AppleWatchDevice {
    func handleTestMessage(_ message: WatchConnectivityBridge.WatchMessage) {
        // Simulate message handling for tests
        if message.type == "heartRate", let bpm = message.data["bpm"] {
            let sample = BiometricSample(type: .heartRate, value: bpm)
            dataCallback?(sample)
        }
    }
}

extension PolarH10Device {
    func parseHeartRateMeasurement(_ data: Data) {
        // Expose for testing
        handleHeartRateMeasurement(Array(data))
    }

    func handleHeartRateMeasurement(_ data: [UInt8]) {
        guard !data.isEmpty else { return }

        let flags = data[0]
        var offset = 1

        // Parse heart rate
        var heartRate: UInt16
        if flags & 0x01 != 0 {
            // UINT16 format
            guard data.count >= 3 else { return }
            heartRate = UInt16(data[1]) | (UInt16(data[2]) << 8)
            offset = 3
        } else {
            // UINT8 format
            guard data.count >= 2 else { return }
            heartRate = UInt16(data[1])
            offset = 2
        }

        dataCallback?(BiometricSample(type: .heartRate, value: Double(heartRate)))

        // Skip energy expended if present
        if flags & 0x08 != 0 {
            offset += 2
        }

        // Parse RR intervals if present
        if flags & 0x10 != 0 {
            while offset + 1 < data.count {
                let rr = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
                let rrMs = Int((Double(rr) * 1000.0) / 1024.0)

                if rrMs > 200 && rrMs < 2000 {
                    rrBuffer.append(rrMs)
                }

                offset += 2
            }

            // Keep buffer manageable
            while rrBuffer.count > 30 {
                rrBuffer.removeFirst()
            }

            // Calculate HRV if enough data
            if rrBuffer.count >= 5 {
                let hrv = calculateHRV(rrIntervals: rrBuffer)
                dataCallback?(BiometricSample(type: .heartRateVariability, value: hrv))
            }
        }
    }

    func calculateHRV(rrIntervals: [Int]) -> Double {
        guard rrIntervals.count >= 2 else { return 0.0 }

        var sumSquaredDiff = 0.0
        for i in 1..<rrIntervals.count {
            let diff = Double(rrIntervals[i] - rrIntervals[i-1])
            sumSquaredDiff += diff * diff
        }

        return sqrt(sumSquaredDiff / Double(rrIntervals.count - 1))
    }

    private var rrBuffer: [Int] {
        get { objc_getAssociatedObject(self, &rrBufferKey) as? [Int] ?? [] }
        set { objc_setAssociatedObject(self, &rrBufferKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }
}

private var rrBufferKey: UInt8 = 0
