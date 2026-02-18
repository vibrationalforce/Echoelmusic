// VRARDeviceRegistry.swift
// Echoelmusic - λ Lambda Mode
//
// VR/AR/XR device registry
// Virtual reality, augmented reality, and mixed reality headsets and devices

import Foundation

// MARK: - VR/AR Device Registry

public final class VRARDeviceRegistry {

    public enum XRPlatform: String, CaseIterable {
        case visionOS = "visionOS"
        case questOS = "Quest OS"
        case steamVR = "SteamVR"
        case windowsMR = "Windows Mixed Reality"
        case playStationVR = "PlayStation VR"
    }

    public struct XRDevice: Identifiable, Hashable {
        public let id: UUID
        public let brand: String
        public let model: String
        public let platform: XRPlatform
        public let type: String
        public let hasSpatialAudio: Bool
        public let hasEyeTracking: Bool
        public let hasHandTracking: Bool
        public let hasPassthrough: Bool

        public init(
            id: UUID = UUID(),
            brand: String,
            model: String,
            platform: XRPlatform,
            type: String,
            hasSpatialAudio: Bool = true,
            hasEyeTracking: Bool = false,
            hasHandTracking: Bool = false,
            hasPassthrough: Bool = false
        ) {
            self.id = id
            self.brand = brand
            self.model = model
            self.platform = platform
            self.type = type
            self.hasSpatialAudio = hasSpatialAudio
            self.hasEyeTracking = hasEyeTracking
            self.hasHandTracking = hasHandTracking
            self.hasPassthrough = hasPassthrough
        }
    }

    /// VR/AR devices
    public let devices: [XRDevice] = [
        // Apple
        XRDevice(brand: "Apple", model: "Vision Pro", platform: .visionOS, type: "MR Headset",
                hasSpatialAudio: true, hasEyeTracking: true, hasHandTracking: true, hasPassthrough: true),
        XRDevice(brand: "Apple", model: "Vision Pro 2", platform: .visionOS, type: "MR Headset",
                hasSpatialAudio: true, hasEyeTracking: true, hasHandTracking: true, hasPassthrough: true),

        // Meta
        XRDevice(brand: "Meta", model: "Quest 3", platform: .questOS, type: "MR Headset",
                hasSpatialAudio: true, hasEyeTracking: false, hasHandTracking: true, hasPassthrough: true),
        XRDevice(brand: "Meta", model: "Quest 3S", platform: .questOS, type: "MR Headset",
                hasSpatialAudio: true, hasEyeTracking: false, hasHandTracking: true, hasPassthrough: true),
        XRDevice(brand: "Meta", model: "Quest Pro", platform: .questOS, type: "MR Headset",
                hasSpatialAudio: true, hasEyeTracking: true, hasHandTracking: true, hasPassthrough: true),
        XRDevice(brand: "Meta", model: "Ray-Ban Meta", platform: .questOS, type: "Smart Glasses",
                hasSpatialAudio: true, hasEyeTracking: false, hasHandTracking: false, hasPassthrough: true),

        // Valve
        XRDevice(brand: "Valve", model: "Index", platform: .steamVR, type: "VR Headset",
                hasSpatialAudio: true, hasEyeTracking: false, hasHandTracking: true, hasPassthrough: false),

        // HTC
        XRDevice(brand: "HTC", model: "VIVE XR Elite", platform: .steamVR, type: "MR Headset",
                hasSpatialAudio: true, hasEyeTracking: false, hasHandTracking: true, hasPassthrough: true),
        XRDevice(brand: "HTC", model: "VIVE Pro 2", platform: .steamVR, type: "VR Headset",
                hasSpatialAudio: true, hasEyeTracking: true, hasHandTracking: true, hasPassthrough: false),
        XRDevice(brand: "HTC", model: "VIVE Focus Vision", platform: .steamVR, type: "MR Headset",
                hasSpatialAudio: true, hasEyeTracking: true, hasHandTracking: true, hasPassthrough: true),

        // Sony
        XRDevice(brand: "Sony", model: "PlayStation VR2", platform: .playStationVR, type: "VR Headset",
                hasSpatialAudio: true, hasEyeTracking: true, hasHandTracking: false, hasPassthrough: true),

        // Varjo
        XRDevice(brand: "Varjo", model: "XR-4", platform: .steamVR, type: "MR Headset",
                hasSpatialAudio: true, hasEyeTracking: true, hasHandTracking: true, hasPassthrough: true),

        // Pimax
        XRDevice(brand: "Pimax", model: "Crystal Super", platform: .steamVR, type: "VR Headset",
                hasSpatialAudio: true, hasEyeTracking: true, hasHandTracking: true, hasPassthrough: true),
    ]

    /// Meta XR Audio SDK features (from research)
    public let metaAudioFeatures: [String] = [
        "HRTF-based spatial audio",
        "Ambisonic spatialization (1st, 2nd, 3rd order)",
        "Room acoustics simulation",
        "Point source spatialization",
        "Dolby Atmos support",
        "Unity/Unreal/FMOD/Wwise integration",
    ]
}
