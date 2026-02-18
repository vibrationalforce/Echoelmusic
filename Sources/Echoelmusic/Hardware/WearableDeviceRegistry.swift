// WearableDeviceRegistry.swift
// Echoelmusic - λ Lambda Mode
//
// Wearable device registry
// Smartwatches, earbuds, fitness trackers, and biometric wearables

import Foundation

// MARK: - Wearable Device Registry

public final class WearableDeviceRegistry {

    public struct WearableDevice: Identifiable, Hashable {
        public let id: UUID
        public let brand: String
        public let model: String
        public let platform: DevicePlatform
        public let capabilities: Set<DeviceCapability>

        public init(
            id: UUID = UUID(),
            brand: String,
            model: String,
            platform: DevicePlatform,
            capabilities: Set<DeviceCapability>
        ) {
            self.id = id
            self.brand = brand
            self.model = model
            self.platform = platform
            self.capabilities = capabilities
        }
    }

    /// Wearable devices
    public let devices: [WearableDevice] = [
        // Apple Watch
        WearableDevice(brand: "Apple", model: "Apple Watch Ultra 2", platform: .watchOS,
                      capabilities: [.heartRate, .hrv, .bloodOxygen, .ecg, .accelerometer, .gyroscope, .gps, .haptics]),
        WearableDevice(brand: "Apple", model: "Apple Watch Series 10", platform: .watchOS,
                      capabilities: [.heartRate, .hrv, .bloodOxygen, .ecg, .accelerometer, .gyroscope, .gps, .haptics]),
        WearableDevice(brand: "Apple", model: "Apple Watch SE 3", platform: .watchOS,
                      capabilities: [.heartRate, .hrv, .accelerometer, .gyroscope, .gps, .haptics]),

        // Wear OS
        WearableDevice(brand: "Google", model: "Pixel Watch 3", platform: .wearOS,
                      capabilities: [.heartRate, .hrv, .bloodOxygen, .accelerometer, .gyroscope, .gps, .haptics]),
        WearableDevice(brand: "Samsung", model: "Galaxy Watch 7", platform: .wearOS,
                      capabilities: [.heartRate, .hrv, .bloodOxygen, .ecg, .accelerometer, .gyroscope, .gps, .haptics]),
        WearableDevice(brand: "Samsung", model: "Galaxy Watch Ultra", platform: .wearOS,
                      capabilities: [.heartRate, .hrv, .bloodOxygen, .ecg, .accelerometer, .gyroscope, .gps, .haptics]),

        // AirPods
        WearableDevice(brand: "Apple", model: "AirPods Pro 2", platform: .iOS,
                      capabilities: [.audioOutput, .spatialAudio, .accelerometer, .haptics]),
        WearableDevice(brand: "Apple", model: "AirPods Max", platform: .iOS,
                      capabilities: [.audioOutput, .spatialAudio, .accelerometer]),
        WearableDevice(brand: "Apple", model: "AirPods 4", platform: .iOS,
                      capabilities: [.audioOutput, .spatialAudio]),

        // Other Earbuds
        WearableDevice(brand: "Sony", model: "WF-1000XM5", platform: .android,
                      capabilities: [.audioOutput, .spatialAudio]),
        WearableDevice(brand: "Samsung", model: "Galaxy Buds3 Pro", platform: .android,
                      capabilities: [.audioOutput, .spatialAudio]),
        WearableDevice(brand: "Bose", model: "QuietComfort Ultra Earbuds", platform: .android,
                      capabilities: [.audioOutput, .spatialAudio]),

        // Fitness
        WearableDevice(brand: "Whoop", model: "Whoop 4.0", platform: .iOS,
                      capabilities: [.heartRate, .hrv, .bloodOxygen, .breathing, .temperature]),
        WearableDevice(brand: "Oura", model: "Oura Ring Gen 3", platform: .iOS,
                      capabilities: [.heartRate, .hrv, .bloodOxygen, .temperature]),
        WearableDevice(brand: "Garmin", model: "Fenix 8", platform: .iOS,
                      capabilities: [.heartRate, .hrv, .bloodOxygen, .accelerometer, .gyroscope, .gps]),
    ]

    /// Wear OS Health Services API data types (from research)
    public let wearOSHealthDataTypes: [String] = [
        "HEART_RATE_BPM",
        "HEART_RATE_VARIABILITY",
        "STEPS",
        "DISTANCE",
        "CALORIES",
        "ELEVATION",
        "FLOORS",
        "SPEED",
        "PACE",
        "VO2_MAX",
        "RESPIRATORY_RATE",
        "BLOOD_OXYGEN",
    ]
}
