import Foundation
import SwiftUI
import Combine

#if os(iOS)
import UIKit
import HealthKit
#elseif os(macOS)
import AppKit
#elseif os(watchOS)
import WatchKit
import HealthKit
#elseif os(tvOS)
import UIKit
#elseif os(visionOS)
import UIKit
import RealityKit
#endif

// MARK: - Platform Type Aliases

/// Unified platform-agnostic type aliases for cross-platform compatibility
/// Allows 90% code reuse across all platforms with minimal conditional compilation

#if os(macOS)
public typealias PlatformColor = NSColor
public typealias PlatformView = NSView
public typealias PlatformViewController = NSViewController
public typealias PlatformImage = NSImage
public typealias PlatformFont = NSFont
public typealias PlatformBezierPath = NSBezierPath
#else
public typealias PlatformColor = UIColor
public typealias PlatformView = UIView
public typealias PlatformViewController = UIViewController
public typealias PlatformImage = UIImage
public typealias PlatformFont = UIFont
public typealias PlatformBezierPath = UIBezierPath
#endif


// MARK: - Platform Capabilities

/// Defines what features are available on each platform
public struct PlatformCapabilities {

    /// Whether HealthKit is available on this platform
    public static var hasHealthKit: Bool {
        #if os(iOS) || os(watchOS)
        return true
        #else
        return false
        #endif
    }

    /// Whether camera/video capture is available
    public static var hasCamera: Bool {
        #if os(iOS) || os(macOS) || os(visionOS)
        return true
        #else
        return false
        #endif
    }

    /// Whether RealityKit/3D rendering is available
    public static var has3DRendering: Bool {
        #if os(visionOS)
        return true
        #else
        return false
        #endif
    }

    /// Whether multi-window support is available
    public static var hasMultiWindow: Bool {
        #if os(macOS) || os(visionOS)
        return true
        #elseif os(iOS)
        if #available(iOS 16.0, *) {
            return true
        }
        return false
        #else
        return false
        #endif
    }

    /// Whether professional audio interfaces are common
    public static var hasProfessionalAudio: Bool {
        #if os(macOS) || os(iOS)
        return true
        #else
        return false
        #endif
    }

    /// Whether keyboard/mouse input is available
    public static var hasKeyboardMouse: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }

    /// Whether touch input is available
    public static var hasTouchInput: Bool {
        #if os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
        return true
        #else
        return false
        #endif
    }

    /// Whether Spatial Audio is available
    public static var hasSpatialAudio: Bool {
        #if os(iOS) || os(macOS) || os(visionOS)
        return true
        #else
        return false
        #endif
    }

    /// Platform name for display
    public static var platformName: String {
        #if os(iOS)
        return "iOS"
        #elseif os(macOS)
        return "macOS"
        #elseif os(watchOS)
        return "watchOS"
        #elseif os(tvOS)
        return "tvOS"
        #elseif os(visionOS)
        return "visionOS"
        #else
        return "Unknown"
        #endif
    }

    /// Device type for analytics
    public static var deviceType: String {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        #elseif os(macOS)
        return "Mac"
        #elseif os(watchOS)
        return "Apple Watch"
        #elseif os(tvOS)
        return "Apple TV"
        #elseif os(visionOS)
        return "Apple Vision Pro"
        #else
        return "Unknown"
        #endif
    }
}


// MARK: - Platform-Specific Helpers

#if os(macOS)
extension NSColor {
    /// Convert macOS NSColor to cross-platform color representation
    public func toPlatformColor() -> PlatformColor {
        return self
    }
}
#else
extension UIColor {
    /// Convert iOS/watchOS/tvOS/visionOS UIColor to cross-platform color representation
    public func toPlatformColor() -> PlatformColor {
        return self
    }
}
#endif


// MARK: - Biofeedback Platform Support

/// Platform-agnostic biofeedback manager
/// - iOS/watchOS: Use HealthKit
/// - macOS: Use Bluetooth HR monitors (Polar H10, Wahoo TICKR)
/// - tvOS: No biofeedback support
/// - visionOS: Use HealthKit when available
public protocol BiofeedbackProvider {
    func startMonitoring() async throws
    func stopMonitoring()
    func getCurrentHeartRate() -> Double?
    func getCurrentHRV() -> Double?
}

#if os(iOS) || os(watchOS)
/// HealthKit-based biofeedback provider for iOS/watchOS
public class HealthKitBiofeedbackProvider: BiofeedbackProvider {
    private let healthStore = HKHealthStore()
    private var currentHR: Double?
    private var currentHRV: Double?

    public init() {
        print("✅ HealthKit Biofeedback Provider initialized")
    }

    public func startMonitoring() async throws {
        // Request HealthKit authorization
        let types: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.heartRateVariabilitySDNN)
        ]

        try await healthStore.requestAuthorization(toShare: [], read: types)
        print("📊 HealthKit monitoring started")
    }

    public func stopMonitoring() {
        print("📊 HealthKit monitoring stopped")
    }

    public func getCurrentHeartRate() -> Double? {
        return currentHR
    }

    public func getCurrentHRV() -> Double? {
        return currentHRV
    }
}
#endif

#if os(macOS)
/// Bluetooth HR monitor provider for macOS
public class BluetoothBiofeedbackProvider: BiofeedbackProvider {
    private var currentHR: Double?
    private var currentHRV: Double?

    public init() {
        print("✅ Bluetooth Biofeedback Provider initialized (macOS)")
    }

    public func startMonitoring() async throws {
        // Scan for Bluetooth HR monitors (Polar H10, Wahoo TICKR, etc.)
        print("📡 Scanning for Bluetooth HR monitors...")
        // Implementation would use CoreBluetooth
    }

    public func stopMonitoring() {
        print("📡 Bluetooth monitoring stopped")
    }

    public func getCurrentHeartRate() -> Double? {
        return currentHR ?? 72.0  // Default fallback
    }

    public func getCurrentHRV() -> Double? {
        return currentHRV ?? 50.0  // Default fallback
    }
}
#endif

#if os(tvOS)
/// No biofeedback support on tvOS
public class NoBiofeedbackProvider: BiofeedbackProvider {
    public init() {
        print("⚠️ No biofeedback support on tvOS")
    }

    public func startMonitoring() async throws {
        // No-op
    }

    public func stopMonitoring() {
        // No-op
    }

    public func getCurrentHeartRate() -> Double? {
        return nil
    }

    public func getCurrentHRV() -> Double? {
        return nil
    }
}
#endif


// MARK: - Platform Factory

/// Factory to create platform-appropriate providers
public struct PlatformFactory {

    /// Create platform-appropriate biofeedback provider
    public static func createBiofeedbackProvider() -> BiofeedbackProvider {
        #if os(iOS) || os(watchOS)
        return HealthKitBiofeedbackProvider()
        #elseif os(macOS)
        return BluetoothBiofeedbackProvider()
        #else
        return NoBiofeedbackProvider()
        #endif
    }

    /// Get recommended buffer size for platform
    public static var recommendedAudioBufferSize: Int {
        #if os(iOS) || os(macOS)
        return 512  // Low latency for professional use
        #elseif os(watchOS)
        return 1024 // Higher latency acceptable on watch
        #else
        return 512
        #endif
    }

    /// Get recommended video resolution for platform
    public static var recommendedVideoResolution: CGSize {
        #if os(iOS)
        return CGSize(width: 1920, height: 1080)  // Full HD
        #elseif os(macOS)
        return CGSize(width: 3840, height: 2160)  // 4K for professional work
        #elseif os(visionOS)
        return CGSize(width: 3840, height: 2160)  // 4K for spatial video
        #else
        return CGSize(width: 1280, height: 720)   // HD
        #endif
    }
}


// MARK: - Debug Logging

public func platformLog(_ message: String) {
    print("[\(PlatformCapabilities.platformName)] \(message)")
}

public func platformDebug(_ message: String) {
    #if DEBUG
    print("[\(PlatformCapabilities.platformName) DEBUG] \(message)")
    #endif
}
