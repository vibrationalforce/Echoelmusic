//
//  PlatformAbstraction.swift
//  Echoelmusic
//
//  Created: 2025-11-25
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  FUTURE-PROOF PLATFORM ABSTRACTION LAYER
//  Supports iOS, macOS, watchOS, visionOS with unified interface
//

import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

#if canImport(WatchKit)
import WatchKit
#endif

// MARK: - Platform Detection

/// Current platform the app is running on
enum Platform {
    case iOS
    case macOS
    case watchOS
    case visionOS
    case tvOS
    case unknown

    static var current: Platform {
        #if os(iOS)
            #if targetEnvironment(simulator) || targetEnvironment(macCatalyst)
                return .iOS
            #else
                // Check for visionOS
                if ProcessInfo.processInfo.environment["XR_DEVICE"] != nil {
                    return .visionOS
                }
                return .iOS
            #endif
        #elseif os(macOS)
            return .macOS
        #elseif os(watchOS)
            return .watchOS
        #elseif os(tvOS)
            return .tvOS
        #else
            return .unknown
        #endif
    }

    var displayName: String {
        switch self {
        case .iOS: return "iOS"
        case .macOS: return "macOS"
        case .watchOS: return "watchOS"
        case .visionOS: return "visionOS"
        case .tvOS: return "tvOS"
        case .unknown: return "Unknown"
        }
    }

    var supportsMultipleWindows: Bool {
        switch self {
        case .macOS, .visionOS: return true
        case .iOS: return true  // iPadOS supports multiple windows
        default: return false
        }
    }

    var supportsFullscreen: Bool {
        switch self {
        case .iOS, .macOS, .tvOS, .visionOS: return true
        case .watchOS: return false
        default: return false
        }
    }

    var supportsBiofeedback: Bool {
        switch self {
        case .iOS, .watchOS: return true  // HealthKit available
        case .macOS: return false  // No HealthKit on macOS
        case .visionOS: return true  // visionOS supports HealthKit
        default: return false
        }
    }

    var supportsHaptics: Bool {
        switch self {
        case .iOS, .watchOS: return true
        case .macOS: return false  // No haptics on Mac
        case .visionOS: return true  // visionOS supports spatial haptics
        default: return false
        }
    }
}

// MARK: - Platform Configuration

/// Platform-specific configuration manager
@MainActor
class PlatformConfiguration: ObservableObject {
    static let shared = PlatformConfiguration()

    // MARK: - Published Properties

    @Published var currentPlatform: Platform = .current
    @Published var screenSize: CGSize = .zero
    @Published var idiom: DeviceIdiom = .phone
    @Published var orientation: DeviceOrientation = .portrait

    // MARK: - Device Idiom

    enum DeviceIdiom {
        case phone
        case tablet
        case desktop
        case watch
        case tv
        case headset  // visionOS

        static var current: DeviceIdiom {
            #if os(iOS)
                return UIDevice.current.userInterfaceIdiom == .pad ? .tablet : .phone
            #elseif os(macOS)
                return .desktop
            #elseif os(watchOS)
                return .watch
            #elseif os(tvOS)
                return .tv
            #else
                return .phone
            #endif
        }
    }

    enum DeviceOrientation {
        case portrait
        case landscape
        case square  // watchOS, visionOS

        #if os(iOS)
        static var current: DeviceOrientation {
            let orientation = UIDevice.current.orientation
            switch orientation {
            case .portrait, .portraitUpsideDown:
                return .portrait
            case .landscapeLeft, .landscapeRight:
                return .landscape
            default:
                return .portrait
            }
        }
        #else
        static var current: DeviceOrientation {
            return .square
        }
        #endif
    }

    // MARK: - Initialization

    private init() {
        updateConfiguration()
        setupOrientationMonitoring()
    }

    // MARK: - Configuration

    private func updateConfiguration() {
        currentPlatform = Platform.current
        idiom = DeviceIdiom.current
        orientation = DeviceOrientation.current

        #if os(iOS)
        screenSize = UIScreen.main.bounds.size
        #elseif os(macOS)
        if let screen = NSScreen.main {
            screenSize = screen.frame.size
        }
        #elseif os(watchOS)
        screenSize = WKInterfaceDevice.current().screenBounds.size
        #else
        screenSize = CGSize(width: 375, height: 667)  // Default iPhone size
        #endif
    }

    private func setupOrientationMonitoring() {
        #if os(iOS)
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.orientation = DeviceOrientation.current
        }
        #endif
    }

    // MARK: - Platform Capabilities

    func hasCapability(_ capability: PlatformCapability) -> Bool {
        switch capability {
        case .biofeedback:
            return currentPlatform.supportsBiofeedback
        case .haptics:
            return currentPlatform.supportsHaptics
        case .multiWindow:
            return currentPlatform.supportsMultipleWindows
        case .fullscreen:
            return currentPlatform.supportsFullscreen
        case .spatialAudio:
            return [.iOS, .macOS, .visionOS].contains(currentPlatform)
        case .externalDisplay:
            return [.iOS, .macOS, .tvOS].contains(currentPlatform)
        case .bluetooth:
            return [.iOS, .macOS, .watchOS].contains(currentPlatform)
        case .fileSystem:
            return [.iOS, .macOS].contains(currentPlatform)
        case .networking:
            return true  // All platforms
        case .location:
            return [.iOS, .watchOS].contains(currentPlatform)
        }
    }

    enum PlatformCapability {
        case biofeedback
        case haptics
        case multiWindow
        case fullscreen
        case spatialAudio
        case externalDisplay
        case bluetooth
        case fileSystem
        case networking
        case location
    }

    // MARK: - Layout Helpers

    func recommendedColumnCount() -> Int {
        switch idiom {
        case .phone:
            return orientation == .portrait ? 1 : 2
        case .tablet:
            return orientation == .portrait ? 2 : 3
        case .desktop:
            return 3
        case .watch:
            return 1
        case .tv:
            return 4
        case .headset:
            return 2
        }
    }

    func recommendedPadding() -> CGFloat {
        switch idiom {
        case .phone:
            return 16
        case .tablet:
            return 24
        case .desktop:
            return 32
        case .watch:
            return 8
        case .tv:
            return 40
        case .headset:
            return 24
        }
    }

    func recommendedFontScale() -> CGFloat {
        switch idiom {
        case .phone:
            return 1.0
        case .tablet:
            return 1.2
        case .desktop:
            return 1.3
        case .watch:
            return 0.8
        case .tv:
            return 1.5
        case .headset:
            return 1.1
        }
    }
}

// MARK: - Cross-Platform Color

/// Cross-platform color wrapper
struct PlatformColor {
    #if os(iOS) || os(watchOS) || os(tvOS)
    let uiColor: UIColor

    init(_ uiColor: UIColor) {
        self.uiColor = uiColor
    }

    var swiftUIColor: Color {
        Color(uiColor)
    }
    #elseif os(macOS)
    let nsColor: NSColor

    init(_ nsColor: NSColor) {
        self.nsColor = nsColor
    }

    var swiftUIColor: Color {
        Color(nsColor)
    }
    #endif

    // MARK: - Standard Colors

    static var label: PlatformColor {
        #if os(iOS) || os(watchOS) || os(tvOS)
        return PlatformColor(UIColor.label)
        #elseif os(macOS)
        return PlatformColor(NSColor.labelColor)
        #endif
    }

    static var secondaryLabel: PlatformColor {
        #if os(iOS) || os(watchOS) || os(tvOS)
        return PlatformColor(UIColor.secondaryLabel)
        #elseif os(macOS)
        return PlatformColor(NSColor.secondaryLabelColor)
        #endif
    }

    static var background: PlatformColor {
        #if os(iOS) || os(watchOS) || os(tvOS)
        return PlatformColor(UIColor.systemBackground)
        #elseif os(macOS)
        return PlatformColor(NSColor.windowBackgroundColor)
        #endif
    }

    static var secondaryBackground: PlatformColor {
        #if os(iOS) || os(watchOS) || os(tvOS)
        return PlatformColor(UIColor.secondarySystemBackground)
        #elseif os(macOS)
        return PlatformColor(NSColor.controlBackgroundColor)
        #endif
    }
}

// MARK: - Cross-Platform Haptics

/// Cross-platform haptic feedback
struct PlatformHaptics {
    static func impact(_ style: ImpactStyle) {
        guard Platform.current.supportsHaptics else { return }

        #if os(iOS)
        let generator: UIImpactFeedbackGenerator
        switch style {
        case .light:
            generator = UIImpactFeedbackGenerator(style: .light)
        case .medium:
            generator = UIImpactFeedbackGenerator(style: .medium)
        case .heavy:
            generator = UIImpactFeedbackGenerator(style: .heavy)
        case .rigid:
            generator = UIImpactFeedbackGenerator(style: .rigid)
        case .soft:
            generator = UIImpactFeedbackGenerator(style: .soft)
        }
        generator.impactOccurred()
        #elseif os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
    }

    static func notification(_ type: NotificationType) {
        guard Platform.current.supportsHaptics else { return }

        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        switch type {
        case .success:
            generator.notificationOccurred(.success)
        case .warning:
            generator.notificationOccurred(.warning)
        case .error:
            generator.notificationOccurred(.error)
        }
        #elseif os(watchOS)
        switch type {
        case .success:
            WKInterfaceDevice.current().play(.success)
        case .warning:
            WKInterfaceDevice.current().play(.notification)
        case .error:
            WKInterfaceDevice.current().play(.failure)
        }
        #endif
    }

    static func selection() {
        guard Platform.current.supportsHaptics else { return }

        #if os(iOS)
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        #elseif os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
    }

    enum ImpactStyle {
        case light, medium, heavy, rigid, soft
    }

    enum NotificationType {
        case success, warning, error
    }
}

// MARK: - Cross-Platform Storage

/// Cross-platform file storage
class PlatformStorage {
    static let shared = PlatformStorage()

    private init() {}

    /// Get documents directory
    func documentsDirectory() -> URL? {
        #if os(iOS) || os(macOS)
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        #elseif os(watchOS)
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        #else
        return nil
        #endif
    }

    /// Get app support directory
    func appSupportDirectory() -> URL? {
        #if os(iOS) || os(macOS) || os(watchOS)
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        #else
        return nil
        #endif
    }

    /// Get caches directory
    func cachesDirectory() -> URL? {
        #if os(iOS) || os(macOS) || os(watchOS)
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        #else
        return nil
        #endif
    }

    /// Save data to file
    func save(_ data: Data, to filename: String, in directory: StorageDirectory = .documents) throws {
        guard let baseURL = url(for: directory) else {
            throw StorageError.directoryNotAvailable
        }

        let fileURL = baseURL.appendingPathComponent(filename)
        try data.write(to: fileURL)
    }

    /// Load data from file
    func load(from filename: String, in directory: StorageDirectory = .documents) throws -> Data {
        guard let baseURL = url(for: directory) else {
            throw StorageError.directoryNotAvailable
        }

        let fileURL = baseURL.appendingPathComponent(filename)
        return try Data(contentsOf: fileURL)
    }

    private func url(for directory: StorageDirectory) -> URL? {
        switch directory {
        case .documents:
            return documentsDirectory()
        case .appSupport:
            return appSupportDirectory()
        case .caches:
            return cachesDirectory()
        }
    }

    enum StorageDirectory {
        case documents
        case appSupport
        case caches
    }

    enum StorageError: LocalizedError {
        case directoryNotAvailable
        case fileNotFound
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .directoryNotAvailable:
                return "Storage directory not available on this platform"
            case .fileNotFound:
                return "File not found"
            case .writeFailed:
                return "Failed to write file"
            }
        }
    }
}

// MARK: - SwiftUI Extensions

extension View {
    /// Apply platform-specific padding
    func platformPadding() -> some View {
        self.padding(PlatformConfiguration.shared.recommendedPadding())
    }

    /// Apply platform-specific font scale
    func platformScaled() -> some View {
        let scale = PlatformConfiguration.shared.recommendedFontScale()
        return self.scaleEffect(scale)
    }

    /// Hide on specific platforms
    func hiddenOn(platforms: [Platform]) -> some View {
        self.opacity(platforms.contains(Platform.current) ? 0 : 1)
    }

    /// Show only on specific platforms
    func shownOn(platforms: [Platform]) -> some View {
        self.opacity(platforms.contains(Platform.current) ? 1 : 0)
    }
}

// MARK: - Environment Values

private struct PlatformKey: EnvironmentKey {
    static let defaultValue: Platform = .current
}

extension EnvironmentValues {
    var platform: Platform {
        get { self[PlatformKey.self] }
        set { self[PlatformKey.self] = newValue }
    }
}
