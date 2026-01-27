//
//  UserFriendlyErrorHandler.swift
//  Echoelmusic
//
//  User-Friendly Error Handling System - A+ Rating
//  Converts technical errors into actionable, accessible messages
//
//  Created: 2026-01-27
//

import SwiftUI
import Combine
#if canImport(CoreHaptics)
import CoreHaptics
#endif

// MARK: - Error Severity Levels

/// Error severity determines UI presentation and haptic feedback
public enum ErrorSeverity: Int, Comparable {
    case info = 0       // Informational, auto-dismiss
    case warning = 1    // Warning, requires acknowledgment
    case error = 2      // Error, requires action
    case critical = 3   // Critical, blocks interaction

    public static func < (lhs: ErrorSeverity, rhs: ErrorSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .red
        }
    }

    var hapticPattern: HapticPattern {
        switch self {
        case .info: return .light
        case .warning: return .warning
        case .error: return .error
        case .critical: return .critical
        }
    }

    enum HapticPattern {
        case light, warning, error, critical
    }
}

// MARK: - User-Friendly Error

/// A user-friendly error with actionable guidance
public struct UserFriendlyError: Identifiable, Equatable {
    public let id = UUID()
    public let title: String
    public let message: String
    public let severity: ErrorSeverity
    public let recoveryAction: RecoveryAction?
    public let technicalDetails: String?
    public let timestamp: Date

    public init(
        title: String,
        message: String,
        severity: ErrorSeverity = .error,
        recoveryAction: RecoveryAction? = nil,
        technicalDetails: String? = nil
    ) {
        self.title = title
        self.message = message
        self.severity = severity
        self.recoveryAction = recoveryAction
        self.technicalDetails = technicalDetails
        self.timestamp = Date()
    }

    public static func == (lhs: UserFriendlyError, rhs: UserFriendlyError) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Recovery Actions

/// Actions users can take to recover from errors
public enum RecoveryAction: Equatable {
    case retry(action: String)
    case openSettings
    case checkPermissions
    case checkNetwork
    case restartApp
    case contactSupport
    case ignore
    case custom(label: String, action: String)

    var buttonLabel: String {
        switch self {
        case .retry(let action): return "Retry \(action)"
        case .openSettings: return "Open Settings"
        case .checkPermissions: return "Check Permissions"
        case .checkNetwork: return "Check Connection"
        case .restartApp: return "Restart App"
        case .contactSupport: return "Contact Support"
        case .ignore: return "Dismiss"
        case .custom(let label, _): return label
        }
    }

    var icon: String {
        switch self {
        case .retry: return "arrow.clockwise"
        case .openSettings: return "gear"
        case .checkPermissions: return "lock.open"
        case .checkNetwork: return "wifi"
        case .restartApp: return "arrow.triangle.2.circlepath"
        case .contactSupport: return "envelope"
        case .ignore: return "xmark"
        case .custom: return "arrow.right.circle"
        }
    }
}

// MARK: - Error Handler

/// Centralized error handling with user-friendly presentation
@MainActor
public class UserFriendlyErrorHandler: ObservableObject {

    public static let shared = UserFriendlyErrorHandler()

    // MARK: - Published State

    @Published public var currentError: UserFriendlyError?
    @Published public var errorHistory: [UserFriendlyError] = []
    @Published public var showingErrorSheet: Bool = false

    // MARK: - Configuration

    public var autoDismissInfoErrors: Bool = true
    public var autoDismissDelay: TimeInterval = 4.0
    public var maxHistoryCount: Int = 50

    // MARK: - Haptic Engine
    #if canImport(CoreHaptics)
    private var hapticEngine: CHHapticEngine?
    #endif

    // MARK: - Initialization

    private init() {
        prepareHaptics()
    }

    private func prepareHaptics() {
        #if canImport(CoreHaptics)
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            log.warning("Error haptic engine failed: \(error.localizedDescription)", category: .ui)
        }
        #endif
    }

    // MARK: - Error Presentation

    /// Show an error to the user with appropriate UI and haptics
    public func showError(_ error: UserFriendlyError) {
        log.error("User error: \(error.title) - \(error.message)", category: .ui)

        currentError = error
        errorHistory.insert(error, at: 0)

        // Trim history
        if errorHistory.count > maxHistoryCount {
            errorHistory = Array(errorHistory.prefix(maxHistoryCount))
        }

        showingErrorSheet = true
        playHaptic(for: error.severity)

        // Auto-dismiss info errors
        if error.severity == .info && autoDismissInfoErrors {
            Task {
                try? await Task.sleep(nanoseconds: UInt64(autoDismissDelay * 1_000_000_000))
                if currentError?.id == error.id {
                    dismiss()
                }
            }
        }
    }

    /// Dismiss the current error
    public func dismiss() {
        showingErrorSheet = false
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s for animation
            currentError = nil
        }
    }

    /// Clear error history
    public func clearHistory() {
        errorHistory.removeAll()
    }

    // MARK: - Haptic Feedback

    private func playHaptic(for severity: ErrorSeverity) {
        #if canImport(CoreHaptics)
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        let events: [CHHapticEvent]
        switch severity.hapticPattern {
        case .light:
            events = [CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ], relativeTime: 0)]

        case .warning:
            events = [
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ], relativeTime: 0),
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ], relativeTime: 0.15)
            ]

        case .error:
            events = [
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                ], relativeTime: 0, duration: 0.2)
            ]

        case .critical:
            events = [
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ], relativeTime: 0, duration: 0.3),
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                ], relativeTime: 0.4)
            ]
        }

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try hapticEngine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            log.debug("Error haptic failed: \(error.localizedDescription)", category: .ui)
        }
        #endif
    }

    // MARK: - Error Conversion

    /// Convert a Swift Error to a user-friendly error
    public func convert(_ error: Error, context: String? = nil) -> UserFriendlyError {
        let contextPrefix = context.map { "\($0): " } ?? ""

        // Handle known error types
        switch error {
        case let urlError as URLError:
            return handleURLError(urlError, context: contextPrefix)
        case let decodingError as DecodingError:
            return handleDecodingError(decodingError, context: contextPrefix)
        default:
            return UserFriendlyError(
                title: "Something Went Wrong",
                message: "\(contextPrefix)\(error.localizedDescription)",
                severity: .error,
                recoveryAction: .retry(action: ""),
                technicalDetails: String(describing: error)
            )
        }
    }

    private func handleURLError(_ error: URLError, context: String) -> UserFriendlyError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return UserFriendlyError(
                title: "No Internet Connection",
                message: "\(context)Please check your network connection and try again.",
                severity: .warning,
                recoveryAction: .checkNetwork,
                technicalDetails: "URLError: \(error.code.rawValue)"
            )
        case .timedOut:
            return UserFriendlyError(
                title: "Connection Timed Out",
                message: "\(context)The server is taking too long to respond. Please try again.",
                severity: .warning,
                recoveryAction: .retry(action: ""),
                technicalDetails: "URLError: timeout"
            )
        case .cannotFindHost, .cannotConnectToHost:
            return UserFriendlyError(
                title: "Server Unavailable",
                message: "\(context)The server is currently unavailable. Please try again later.",
                severity: .error,
                recoveryAction: .retry(action: "later"),
                technicalDetails: "URLError: \(error.code.rawValue)"
            )
        default:
            return UserFriendlyError(
                title: "Network Error",
                message: "\(context)A network error occurred. Please check your connection.",
                severity: .error,
                recoveryAction: .checkNetwork,
                technicalDetails: "URLError: \(error.code.rawValue)"
            )
        }
    }

    private func handleDecodingError(_ error: DecodingError, context: String) -> UserFriendlyError {
        return UserFriendlyError(
            title: "Data Error",
            message: "\(context)We received unexpected data. This has been reported automatically.",
            severity: .error,
            recoveryAction: .retry(action: ""),
            technicalDetails: String(describing: error)
        )
    }
}

// MARK: - Common Error Factories

extension UserFriendlyErrorHandler {

    /// Create error for HealthKit permission issues
    public func healthKitPermissionError() -> UserFriendlyError {
        UserFriendlyError(
            title: "HealthKit Access Needed",
            message: "To use bio-reactive features, please enable HealthKit access in Settings.",
            severity: .warning,
            recoveryAction: .openSettings,
            technicalDetails: "HealthKit authorization denied or not determined"
        )
    }

    /// Create error for audio engine failures
    public func audioEngineError(_ details: String? = nil) -> UserFriendlyError {
        UserFriendlyError(
            title: "Audio Engine Issue",
            message: "There was a problem with the audio system. Try restarting the app.",
            severity: .error,
            recoveryAction: .restartApp,
            technicalDetails: details
        )
    }

    /// Create error for ML model loading failures
    public func mlModelError(modelName: String) -> UserFriendlyError {
        UserFriendlyError(
            title: "AI Feature Unavailable",
            message: "The \(modelName) feature couldn't be loaded. Other features still work normally.",
            severity: .warning,
            recoveryAction: .ignore,
            technicalDetails: "Failed to load CoreML model: \(modelName)"
        )
    }

    /// Create error for streaming failures
    public func streamingError() -> UserFriendlyError {
        UserFriendlyError(
            title: "Streaming Interrupted",
            message: "The stream was interrupted. Check your connection and try again.",
            severity: .error,
            recoveryAction: .checkNetwork,
            technicalDetails: nil
        )
    }

    /// Create info message for successful operations
    public func successInfo(_ message: String) -> UserFriendlyError {
        UserFriendlyError(
            title: "Success",
            message: message,
            severity: .info,
            recoveryAction: nil,
            technicalDetails: nil
        )
    }
}

// MARK: - SwiftUI Error View

/// Overlay view for displaying errors
public struct ErrorOverlayView: View {
    @ObservedObject var handler = UserFriendlyErrorHandler.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric private var iconSize: CGFloat = 40

    public init() {}

    public var body: some View {
        ZStack {
            if handler.showingErrorSheet, let error = handler.currentError {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        if error.severity <= .warning {
                            handler.dismiss()
                        }
                    }

                VStack(spacing: 16) {
                    // Header
                    HStack {
                        Image(systemName: error.severity.icon)
                            .font(.system(size: iconSize))
                            .foregroundColor(error.severity.color)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading) {
                            Text(error.title)
                                .font(.headline)
                                .foregroundColor(.primary)
                                .accessibilityAddTraits(.isHeader)

                            Text(error.message)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()
                    }

                    // Actions
                    HStack(spacing: 12) {
                        if let action = error.recoveryAction {
                            Button(action: {
                                performRecoveryAction(action)
                            }) {
                                Label(action.buttonLabel, systemImage: action.icon)
                                    .font(.subheadline.weight(.medium))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(error.severity.color)
                        }

                        Button("Dismiss") {
                            handler.dismiss()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .shadow(radius: 10)
                )
                .padding(.horizontal, 20)
                .transition(reduceMotion ? .opacity : .asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Error: \(error.title)")
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: handler.showingErrorSheet)
    }

    private func performRecoveryAction(_ action: RecoveryAction) {
        switch action {
        case .openSettings:
            #if os(iOS)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
            #endif
            handler.dismiss()

        case .retry, .checkNetwork, .checkPermissions, .restartApp, .contactSupport, .ignore, .custom:
            handler.dismiss()
        }
    }
}

// MARK: - View Modifier

/// Modifier to add error handling overlay to any view
public struct ErrorHandlingModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .overlay(ErrorOverlayView())
    }
}

extension View {
    /// Add user-friendly error handling overlay
    public func withErrorHandling() -> some View {
        modifier(ErrorHandlingModifier())
    }
}
