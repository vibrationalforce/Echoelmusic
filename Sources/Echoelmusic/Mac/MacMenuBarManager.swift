import SwiftUI
import Combine

#if targetEnvironment(macCatalyst)
import UIKit
#endif

/// Menu bar manager for Mac Catalyst
///
/// **Purpose:** Native Mac menu bar integration
///
/// **Features:**
/// - Status item in menu bar
/// - Quick actions menu
/// - HRV display in menu bar
/// - Session status indicator
/// - Background operation support
///
/// **Platform:** macOS only (via Catalyst)
///
@MainActor
public class MacMenuBarManager: ObservableObject {

    #if targetEnvironment(macCatalyst)

    // MARK: - Published Properties

    /// Whether menu bar icon is visible
    @Published public var isMenuBarVisible: Bool = true

    /// Current HRV value to display
    @Published public var currentHRV: Double = 0.0

    /// Whether session is active
    @Published public var isSessionActive: Bool = false

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init() {
        setupNotificationObservers()
        print("[Mac] 🍎 Menu bar manager initialized")
    }

    // MARK: - Setup

    private func setupNotificationObservers() {
        // Observe keyboard shortcuts
        NotificationCenter.default.publisher(for: .macNewSession)
            .sink { [weak self] _ in
                self?.handleNewSession()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .macToggleRecording)
            .sink { [weak self] _ in
                self?.handleToggleRecording()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .macShowAudioDevices)
            .sink { [weak self] _ in
                self?.handleShowAudioDevices()
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    private func handleNewSession() {
        print("[Mac] 📝 New session triggered")
        isSessionActive = true
        // Post notification for app to handle
        NotificationCenter.default.post(name: .appStartNewSession, object: nil)
    }

    private func handleToggleRecording() {
        print("[Mac] 🔴 Toggle recording triggered")
        NotificationCenter.default.post(name: .appToggleRecording, object: nil)
    }

    private func handleShowAudioDevices() {
        print("[Mac] 🎤 Show audio devices triggered")
        NotificationCenter.default.post(name: .appShowAudioDevices, object: nil)
    }

    // MARK: - Menu Bar UI

    /// Get menu bar status text
    public func getMenuBarStatusText() -> String {
        if isSessionActive {
            return "🟢 Echoelmusic - HRV: \(Int(currentHRV)) ms"
        } else {
            return "⚪️ Echoelmusic - Idle"
        }
    }

    /// Update HRV value in menu bar
    public func updateHRV(_ hrv: Double) {
        currentHRV = hrv
    }

    /// Update session status
    public func updateSessionStatus(active: Bool) {
        isSessionActive = active
    }

    #else

    // Non-Mac platform stub
    public init() {}
    public func updateHRV(_ hrv: Double) {}
    public func updateSessionStatus(active: Bool) {}

    #endif
}

// MARK: - App Notification Names

public extension Notification.Name {
    static let appStartNewSession = Notification.Name("appStartNewSession")
    static let appToggleRecording = Notification.Name("appToggleRecording")
    static let appShowAudioDevices = Notification.Name("appShowAudioDevices")
}
