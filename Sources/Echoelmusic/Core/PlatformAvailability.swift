// PlatformAvailability.swift
// Centralized platform availability checks

import Foundation

// MARK: - Platform Detection

public enum Platform {
    /// Check if running on iOS
    public static var isiOS: Bool {
        #if os(iOS)
        return true
        #else
        return false
        #endif
    }

    /// Check if running on macOS
    public static var isMacOS: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }

    /// Check if running on watchOS
    public static var isWatchOS: Bool {
        #if os(watchOS)
        return true
        #else
        return false
        #endif
    }

    /// Check if running on tvOS
    public static var isTVOS: Bool {
        #if os(tvOS)
        return true
        #else
        return false
        #endif
    }

    /// Check if running on visionOS
    public static var isVisionOS: Bool {
        #if os(visionOS)
        return true
        #else
        return false
        #endif
    }

    /// Check if HealthKit is available
    public static var hasHealthKit: Bool {
        #if canImport(HealthKit)
        return true
        #else
        return false
        #endif
    }

    /// Check if ARKit is available
    public static var hasARKit: Bool {
        #if canImport(ARKit)
        return true
        #else
        return false
        #endif
    }

    /// Check if RealityKit is available
    public static var hasRealityKit: Bool {
        #if canImport(RealityKit)
        return true
        #else
        return false
        #endif
    }

    /// Check if CoreMotion is available
    public static var hasCoreMotion: Bool {
        #if canImport(CoreMotion)
        return true
        #else
        return false
        #endif
    }
}

// MARK: - Feature Availability

public enum FeatureAvailability {
    /// Biofeedback features (HealthKit required)
    public static var biofeedback: Bool {
        #if canImport(HealthKit) && (os(iOS) || os(watchOS))
        return true
        #else
        return false
        #endif
    }

    /// Face tracking features (ARKit + iOS required)
    public static var faceTracking: Bool {
        #if canImport(ARKit) && os(iOS)
        return true
        #else
        return false
        #endif
    }

    /// Spatial audio features
    public static var spatialAudio: Bool {
        #if os(iOS) || os(visionOS)
        return true
        #else
        return false
        #endif
    }

    /// Immersive experiences (visionOS)
    public static var immersive: Bool {
        #if os(visionOS)
        return true
        #else
        return false
        #endif
    }
}

// MARK: - Simulation Fallback

/// Use this to provide simulation fallbacks when real hardware isn't available
public protocol SimulatableService {
    var isSimulating: Bool { get }
    func startSimulation()
    func stopSimulation()
}
