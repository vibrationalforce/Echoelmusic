// ThemeManager.swift
// Echoelmusic - Seamless Dark/Light Mode Toggle
//
// Manages app-wide color scheme with seamless animated transitions.
// Supports: Dark, Light, System (auto-follows device setting)
//
// Copyright (c) 2026 Echoelmusic. All rights reserved.

import SwiftUI
import Combine

// MARK: - App Theme Mode

/// User-selectable appearance mode
public enum AppThemeMode: String, CaseIterable, Codable, Sendable {
    case dark = "Dark"
    case light = "Light"
    case system = "System"

    /// Resolve to SwiftUI ColorScheme (nil = follow system)
    public var colorScheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }

    /// SF Symbol for UI
    public var icon: String {
        switch self {
        case .dark: return "moon.fill"
        case .light: return "sun.max.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }

    /// Localized display name
    public var displayName: String {
        switch self {
        case .dark: return "Dunkel"
        case .light: return "Hell"
        case .system: return "System"
        }
    }
}

// MARK: - Theme Manager

/// Central theme manager for seamless dark/light mode switching.
/// Persists user preference via UserDefaults.
@MainActor
public final class ThemeManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = ThemeManager()

    // MARK: - Published State

    @Published public var currentMode: AppThemeMode {
        didSet {
            UserDefaults.standard.set(currentMode.rawValue, forKey: Self.themeKey)
        }
    }

    /// Resolved color scheme for .preferredColorScheme() modifier
    /// Returns nil when following system, which lets SwiftUI use device setting
    public var resolvedColorScheme: ColorScheme? {
        currentMode.colorScheme
    }

    // MARK: - Persistence

    private static let themeKey = "echoelmusic_theme_mode"

    // MARK: - Init

    public init() {
        if let saved = UserDefaults.standard.string(forKey: Self.themeKey),
           let mode = AppThemeMode(rawValue: saved) {
            self.currentMode = mode
        } else {
            self.currentMode = .dark  // Default: dark (preserves existing behavior)
        }
    }

    // MARK: - Public API

    /// Toggle between dark and light (skips system)
    public func toggle() {
        withAnimation(.easeInOut(duration: 0.35)) {
            currentMode = (currentMode == .dark) ? .light : .dark
        }
    }

    /// Cycle through all modes: dark -> light -> system -> dark
    public func cycleMode() {
        withAnimation(.easeInOut(duration: 0.35)) {
            switch currentMode {
            case .dark: currentMode = .light
            case .light: currentMode = .system
            case .system: currentMode = .dark
            }
        }
    }

    /// Set specific mode with animation
    public func setMode(_ mode: AppThemeMode) {
        withAnimation(.easeInOut(duration: 0.35)) {
            currentMode = mode
        }
    }
}

// MARK: - Theme Toggle Button

/// Compact toggle button for dark/light mode switching
public struct ThemeToggleButton: View {

    @ObservedObject private var themeManager: ThemeManager

    public init(themeManager: ThemeManager = .shared) {
        self.themeManager = themeManager
    }

    public var body: some View {
        Button {
            themeManager.cycleMode()
        } label: {
            if #available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *) {
                Image(systemName: themeManager.currentMode.icon)
                    .font(.title3)
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .contentTransition(.symbolEffect(.replace))
            } else {
                Image(systemName: themeManager.currentMode.icon)
                    .font(.title3)
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Erscheinungsmodus: \(themeManager.currentMode.displayName)")
        .accessibilityHint("Tippen zum Wechseln")
    }
}

// MARK: - Theme Picker (for Settings)

/// Full picker for Settings views
public struct ThemeModePicker: View {

    @ObservedObject private var themeManager: ThemeManager

    public init(themeManager: ThemeManager = .shared) {
        self.themeManager = themeManager
    }

    public var body: some View {
        HStack(spacing: 12) {
            ForEach(AppThemeMode.allCases, id: \.self) { mode in
                Button {
                    themeManager.setMode(mode)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: mode.icon)
                            .font(.title2)
                        Text(mode.displayName)
                            .font(.caption2)
                    }
                    .foregroundColor(themeManager.currentMode == mode ? .primary : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(themeManager.currentMode == mode
                                  ? Color.primary.opacity(0.1)
                                  : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - View Extension

extension View {
    /// Apply the app's current theme mode seamlessly.
    /// Use this ONCE at the root view instead of hardcoded .preferredColorScheme(.dark)
    public func echoelTheme(_ themeManager: ThemeManager = .shared) -> some View {
        self.preferredColorScheme(themeManager.resolvedColorScheme)
    }
}
