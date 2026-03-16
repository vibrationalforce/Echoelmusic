#if canImport(SwiftUI)
// LiquidGlassDesignSystem.swift
// Echoelmusic — Solid Design System
//
// Clean, minimal design: solid fills, subtle borders, no glassmorphism.
// Follows Echoelmusic design constraints (no blur, no glow, max 8px shadow).
//
// Copyright (c) 2026 Echoelmusic. All rights reserved.

import SwiftUI

// MARK: - Echoel Surface

/// Clean surface system — solid fills with subtle borders
public struct EchoelSurface {

    // MARK: - Tints

    /// Surface tint colors for different contexts
    public enum Tint: String, CaseIterable, Sendable {
        case clear = "Clear"
        case subtle = "Subtle"
        case vibrant = "Vibrant"
        case muted = "Muted"
        case accent = "Accent"

        /// Bio-reactive tints (Echoelmusic specific)
        case coherenceLow = "Coherence Low"
        case coherenceMedium = "Coherence Medium"
        case coherenceHigh = "Coherence High"

        public var fillOpacity: Double {
            switch self {
            case .clear: return 0.04
            case .subtle: return 0.08
            case .vibrant: return 0.15
            case .muted: return 0.06
            case .accent: return 0.12
            case .coherenceLow: return 0.10
            case .coherenceMedium: return 0.12
            case .coherenceHigh: return 0.15
            }
        }

        public var fillColor: Color {
            switch self {
            case .clear, .subtle, .muted: return Color.white
            case .vibrant, .accent: return Color.blue
            case .coherenceLow: return Color.orange
            case .coherenceMedium: return Color.yellow
            case .coherenceHigh: return Color.green
            }
        }
    }

    // MARK: - Depth Levels

    /// Semantic depth levels for UI hierarchy
    public enum DepthLevel: Int, CaseIterable, Sendable {
        case background = 0
        case base = 1
        case elevated = 2
        case floating = 3
        case overlay = 4
        case modal = 5

        /// Shadow radius capped at 8px per design constraints
        public var shadowRadius: CGFloat {
            switch self {
            case .background: return 0
            case .base: return 1
            case .elevated: return 3
            case .floating: return 5
            case .overlay: return 7
            case .modal: return 8
            }
        }

        public var zOffset: CGFloat {
            CGFloat(rawValue) * 10.0
        }
    }

    // MARK: - Corner Styles

    /// Corner radius styles (max 12px per design constraints)
    public enum CornerStyle: Sendable {
        case sharp
        case rounded      // 8px
        case continuous   // 12px (squircle)

        public func radius(for size: CGSize) -> CGFloat {
            switch self {
            case .sharp: return 0
            case .rounded: return 8
            case .continuous: return 12
            }
        }
    }
}

// MARK: - Surface View Modifier

/// Apply clean surface styling to any view
public struct SurfaceModifier: ViewModifier {
    let tint: EchoelSurface.Tint
    let depth: EchoelSurface.DepthLevel
    let cornerStyle: EchoelSurface.CornerStyle

    @Environment(\.colorScheme) private var colorScheme

    public func body(content: Content) -> some View {
        content
            .background(surfaceBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(
                color: shadowColor,
                radius: depth.shadowRadius,
                x: 0,
                y: depth.shadowRadius / 3
            )
    }

    private var surfaceBackground: some View {
        Rectangle()
            .fill(tint.fillColor.opacity(tint.fillOpacity))
            .background(colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.97))
    }

    private var borderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.06)
    }

    private var shadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.4)
            : Color.black.opacity(0.08)
    }
}

// MARK: - View Extension

extension View {

    /// Apply clean surface styling
    public func echoelSurface(
        tint: EchoelSurface.Tint = .subtle,
        depth: EchoelSurface.DepthLevel = .elevated,
        cornerStyle: EchoelSurface.CornerStyle = .continuous
    ) -> some View {
        modifier(SurfaceModifier(
            tint: tint,
            depth: depth,
            cornerStyle: cornerStyle
        ))
    }

    /// Bio-reactive surface that responds to coherence
    public func bioReactiveSurface(coherence: Double) -> some View {
        let tint: EchoelSurface.Tint
        if coherence >= 0.6 {
            tint = .coherenceHigh
        } else if coherence >= 0.4 {
            tint = .coherenceMedium
        } else {
            tint = .coherenceLow
        }
        return self.echoelSurface(tint: tint, depth: .floating)
    }
}

// MARK: - Backward Compatibility

/// Type aliases for existing code referencing LiquidGlass
public typealias LiquidGlass = EchoelSurface

extension View {
    /// Backward-compatible alias — applies clean surface styling
    public func liquidGlass(
        tint: EchoelSurface.Tint = .subtle,
        depth: EchoelSurface.DepthLevel = .elevated,
        cornerStyle: EchoelSurface.CornerStyle = .continuous,
        interactive: Bool = false
    ) -> some View {
        echoelSurface(tint: tint, depth: depth, cornerStyle: cornerStyle)
    }

    /// Backward-compatible alias
    public func bioReactiveLiquidGlass(coherence: Double) -> some View {
        bioReactiveSurface(coherence: coherence)
    }
}

// MARK: - Surface Button

/// Button with clean surface styling
public struct SurfaceButton: View {
    let title: String
    let icon: String?
    let tint: EchoelSurface.Tint
    let action: () -> Void

    @State private var isPressed = false

    public init(
        _ title: String,
        icon: String? = nil,
        tint: EchoelSurface.Tint = .vibrant,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.action = action
    }

    public var body: some View {
        Button(action: {
            #if canImport(UIKit) && !os(watchOS) && !os(tvOS)
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            #endif
            action()
        }) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.body.weight(.semibold))
                }
                Text(title)
                    .font(.body.weight(.semibold))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .echoelSurface(tint: tint, depth: .elevated)
        }
        .buttonStyle(.plain)
        .opacity(isPressed ? 0.7 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

/// Backward-compatible alias
public typealias LiquidGlassButton = SurfaceButton

// MARK: - Surface Card

/// Card component with clean surface styling
public struct SurfaceCard<Content: View>: View {
    let depth: EchoelSurface.DepthLevel
    let tint: EchoelSurface.Tint
    let content: () -> Content

    public init(
        depth: EchoelSurface.DepthLevel = .elevated,
        tint: EchoelSurface.Tint = .subtle,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.depth = depth
        self.tint = tint
        self.content = content
    }

    public var body: some View {
        content()
            .padding(16)
            .echoelSurface(tint: tint, depth: depth)
    }
}

/// Backward-compatible alias
public typealias LiquidGlassCard = SurfaceCard

// MARK: - Surface Navigation Bar

/// Navigation bar with clean surface backdrop
public struct SurfaceNavigationBar: View {
    let title: String
    let leadingAction: (() -> Void)?
    let trailingAction: (() -> Void)?

    public init(
        title: String,
        leadingAction: (() -> Void)? = nil,
        trailingAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.leadingAction = leadingAction
        self.trailingAction = trailingAction
    }

    public var body: some View {
        HStack {
            if let leading = leadingAction {
                Button(action: leading) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.primary)
                }
                .frame(width: 44, height: 44)
            }

            Spacer()

            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            if let trailing = trailingAction {
                Button(action: trailing) {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.primary)
                }
                .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .echoelSurface(tint: .muted, depth: .floating)
    }
}

/// Backward-compatible alias
public typealias LiquidGlassNavigationBar = SurfaceNavigationBar

// MARK: - Surface Tab Bar

/// Tab bar with clean surface styling
public struct SurfaceTabBar: View {
    @Binding var selectedTab: Int
    let tabs: [(icon: String, title: String)]

    public init(selectedTab: Binding<Int>, tabs: [(icon: String, title: String)]) {
        self._selectedTab = selectedTab
        self.tabs = tabs
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        selectedTab = index
                    }
                    #if canImport(UIKit) && !os(watchOS) && !os(tvOS)
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    #endif
                } label: {
                    VStack(spacing: 4) {
                        if #available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *) {
                            Image(systemName: selectedTab == index ? "\(tab.icon).fill" : tab.icon)
                                .font(.system(size: 22))
                                .symbolEffect(.bounce, value: selectedTab == index)
                        } else {
                            Image(systemName: selectedTab == index ? "\(tab.icon).fill" : tab.icon)
                                .font(.system(size: 22))
                        }

                        Text(tab.title)
                            .font(.caption2)
                    }
                    .foregroundColor(selectedTab == index ? .primary : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .echoelSurface(tint: .subtle, depth: .floating)
    }
}

/// Backward-compatible alias
public typealias LiquidGlassTabBar = SurfaceTabBar

// MARK: - Preview

#if DEBUG
#Preview("Surface Components") {
    ZStack {
        Color(white: 0.08)
            .ignoresSafeArea()

        VStack(spacing: 20) {
            SurfaceNavigationBar(
                title: "Echoelmusic",
                leadingAction: {},
                trailingAction: {}
            )

            SurfaceCard(tint: .accent) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Creative Session")
                        .font(.headline)
                    Text("DAW + Video Production")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 16) {
                SurfaceButton("Start", icon: "play.fill", tint: .coherenceHigh) {}
                SurfaceButton("Pause", icon: "pause.fill", tint: .subtle) {}
            }

            Spacer()
        }
        .padding()
    }
}
#endif
#endif
