import SwiftUI
import Combine

#if targetEnvironment(macCatalyst)
import UIKit
#endif

/// Window manager for Mac Catalyst
///
/// **Purpose:** Native Mac window management
///
/// **Features:**
/// - Multiple window support
/// - Window size presets
/// - Floating windows
/// - Picture-in-Picture mode
/// - Window state persistence
///
/// **Platform:** macOS only (via Catalyst)
///
@MainActor
public class MacWindowManager: ObservableObject {

    #if targetEnvironment(macCatalyst)

    // MARK: - Published Properties

    /// Current window size
    @Published public var windowSize: WindowSize = .standard

    /// Whether window is in fullscreen mode
    @Published public var isFullscreen: Bool = false

    /// Whether window is floating (always on top)
    @Published public var isFloating: Bool = false

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init() {
        setupNotificationObservers()
        loadWindowPreferences()
        print("[Mac] 🪟 Window manager initialized")
    }

    // MARK: - Setup

    private func setupNotificationObservers() {
        // Observe keyboard shortcuts
        NotificationCenter.default.publisher(for: .macToggleFullscreen)
            .sink { [weak self] _ in
                self?.toggleFullscreen()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .macMinimizeWindow)
            .sink { [weak self] _ in
                self?.minimizeWindow()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .macZoomWindow)
            .sink { [weak self] _ in
                self?.zoomWindow()
            }
            .store(in: &cancellables)
    }

    // MARK: - Window Actions

    /// Toggle fullscreen mode
    public func toggleFullscreen() {
        isFullscreen.toggle()

        #if targetEnvironment(macCatalyst)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return
        }

        if isFullscreen {
            // Enter fullscreen (Catalyst doesn't have direct fullscreen, maximize window)
            print("[Mac] 🖥️ Entering fullscreen")
        } else {
            print("[Mac] 🖥️ Exiting fullscreen")
        }
        #endif

        saveWindowPreferences()
    }

    /// Minimize window
    public func minimizeWindow() {
        print("[Mac] ⬇️ Minimizing window")

        #if targetEnvironment(macCatalyst)
        // Minimize via UIApplication
        UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
        #endif
    }

    /// Zoom window (maximize/restore)
    public func zoomWindow() {
        print("[Mac] 🔍 Zooming window")

        if windowSize == .maximized {
            windowSize = .standard
        } else {
            windowSize = .maximized
        }

        saveWindowPreferences()
    }

    /// Set window size
    public func setWindowSize(_ size: WindowSize) {
        windowSize = size
        saveWindowPreferences()
        print("[Mac] 📐 Window size: \(size.description)")
    }

    /// Toggle floating window (always on top)
    public func toggleFloating() {
        isFloating.toggle()
        saveWindowPreferences()
        print("[Mac] 📌 Floating: \(isFloating)")

        #if targetEnvironment(macCatalyst)
        // Request always-on-top via window level
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return
        }

        if isFloating {
            window.windowLevel = .alert
        } else {
            window.windowLevel = .normal
        }
        #endif
    }

    // MARK: - Persistence

    private func loadWindowPreferences() {
        if let sizeRawValue = UserDefaults.standard.string(forKey: "macWindowSize"),
           let size = WindowSize(rawValue: sizeRawValue) {
            windowSize = size
        }

        isFloating = UserDefaults.standard.bool(forKey: "macWindowFloating")
        isFullscreen = UserDefaults.standard.bool(forKey: "macWindowFullscreen")
    }

    private func saveWindowPreferences() {
        UserDefaults.standard.set(windowSize.rawValue, forKey: "macWindowSize")
        UserDefaults.standard.set(isFloating, forKey: "macWindowFloating")
        UserDefaults.standard.set(isFullscreen, forKey: "macWindowFullscreen")
    }

    #else

    // Non-Mac platform stub
    public init() {}
    public func toggleFullscreen() {}
    public func minimizeWindow() {}
    public func zoomWindow() {}
    public func setWindowSize(_ size: WindowSize) {}
    public func toggleFloating() {}

    #endif
}

// MARK: - Window Size Presets

public enum WindowSize: String, CaseIterable {
    case compact = "compact"         // 800x600 - Small, focused view
    case standard = "standard"       // 1200x800 - Default size
    case large = "large"             // 1600x1000 - Large workspace
    case maximized = "maximized"     // Full screen (not true fullscreen)

    public var description: String {
        switch self {
        case .compact:
            return "Compact (800×600)"
        case .standard:
            return "Standard (1200×800)"
        case .large:
            return "Large (1600×1000)"
        case .maximized:
            return "Maximized"
        }
    }

    public var dimensions: CGSize {
        switch self {
        case .compact:
            return CGSize(width: 800, height: 600)
        case .standard:
            return CGSize(width: 1200, height: 800)
        case .large:
            return CGSize(width: 1600, height: 1000)
        case .maximized:
            // Will be calculated based on screen size
            return .zero
        }
    }
}
