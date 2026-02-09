// LiquidGlassDesignSystem.swift
// Echoelmusic - Apple Liquid Glass Design System Integration
//
// Based on Apple Human Interface Guidelines February 2026 Update
// "Liquid Glass" - The new design language for visionOS, iOS 26, macOS 17
//
// "I bent my Wookiee." - Ralph Wiggum, UI Designer
//
// Created 2026-02-04
// Copyright (c) 2026 Echoelmusic. All rights reserved.

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Liquid Glass Material

/// Apple's Liquid Glass material system (HIG February 2026)
/// Combines depth, translucency, and environmental awareness
public struct LiquidGlass {

    // MARK: - Glass Tints

    /// Glass tint colors for different contexts
    public enum Tint: String, CaseIterable, Sendable {
        case clear = "Clear"
        case subtle = "Subtle"
        case vibrant = "Vibrant"
        case ultraThin = "Ultra Thin"
        case thick = "Thick"
        case chromatic = "Chromatic"

        /// Bio-reactive tints (Echoelmusic specific)
        case coherenceLow = "Coherence Low"
        case coherenceMedium = "Coherence Medium"
        case coherenceHigh = "Coherence High"

        public var opacity: Double {
            switch self {
            case .clear: return 0.1
            case .subtle: return 0.2
            case .vibrant: return 0.4
            case .ultraThin: return 0.05
            case .thick: return 0.6
            case .chromatic: return 0.3
            case .coherenceLow: return 0.25
            case .coherenceMedium: return 0.35
            case .coherenceHigh: return 0.45
            }
        }

        public var blur: CGFloat {
            switch self {
            case .clear, .ultraThin: return 20
            case .subtle, .chromatic: return 30
            case .vibrant: return 40
            case .thick: return 50
            case .coherenceLow, .coherenceMedium, .coherenceHigh: return 35
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

        public var shadowRadius: CGFloat {
            switch self {
            case .background: return 0
            case .base: return 2
            case .elevated: return 8
            case .floating: return 16
            case .overlay: return 24
            case .modal: return 32
            }
        }

        public var zOffset: CGFloat {
            CGFloat(rawValue) * 10.0
        }
    }

    // MARK: - Corner Styles

    /// Liquid Glass corner radius styles
    public enum CornerStyle: Sendable {
        case sharp
        case rounded
        case continuous     // Apple's squircle
        case pill
        case circle

        public func radius(for size: CGSize) -> CGFloat {
            switch self {
            case .sharp: return 0
            case .rounded: return 12
            case .continuous: return min(size.width, size.height) * 0.2
            case .pill: return min(size.width, size.height) / 2
            case .circle: return min(size.width, size.height) / 2
            }
        }
    }
}

// MARK: - Liquid Glass View Modifier

/// Apply Liquid Glass effect to any view
public struct LiquidGlassModifier: ViewModifier {
    let tint: LiquidGlass.Tint
    let depth: LiquidGlass.DepthLevel
    let cornerStyle: LiquidGlass.CornerStyle
    let isInteractive: Bool

    @State private var isPressed = false
    @Environment(\.colorScheme) private var colorScheme

    public func body(content: Content) -> some View {
        content
            .background(glassBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(
                color: shadowColor,
                radius: depth.shadowRadius,
                x: 0,
                y: depth.shadowRadius / 4
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }

    private var glassBackground: some View {
        ZStack {
            // Base blur
            Rectangle()
                .fill(.ultraThinMaterial)

            // Tint overlay
            Rectangle()
                .fill(tintGradient)
                .opacity(tint.opacity)

            // Inner highlight (top edge)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )

            // Specular highlight
            Circle()
                .fill(Color.white.opacity(0.1))
                .blur(radius: 20)
                .offset(x: -30, y: -30)
                .scaleEffect(0.5)
        }
    }

    private var tintGradient: LinearGradient {
        switch tint {
        case .coherenceLow:
            return LinearGradient(
                colors: [Color.orange.opacity(0.3), Color.red.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .coherenceMedium:
            return LinearGradient(
                colors: [Color.yellow.opacity(0.3), Color.orange.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .coherenceHigh:
            return LinearGradient(
                colors: [Color.green.opacity(0.3), Color.cyan.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .chromatic:
            return LinearGradient(
                colors: [
                    Color.pink.opacity(0.2),
                    Color.purple.opacity(0.2),
                    Color.cyan.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var shadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.5)
            : Color.black.opacity(0.15)
    }
}

// MARK: - View Extension

extension View {

    /// Apply Liquid Glass material effect
    public func liquidGlass(
        tint: LiquidGlass.Tint = .subtle,
        depth: LiquidGlass.DepthLevel = .elevated,
        cornerStyle: LiquidGlass.CornerStyle = .continuous,
        interactive: Bool = false
    ) -> some View {
        modifier(LiquidGlassModifier(
            tint: tint,
            depth: depth,
            cornerStyle: cornerStyle,
            isInteractive: interactive
        ))
    }

    /// Bio-reactive Liquid Glass that responds to coherence
    public func bioReactiveLiquidGlass(coherence: Double) -> some View {
        let tint: LiquidGlass.Tint
        if coherence >= 0.6 {
            tint = .coherenceHigh
        } else if coherence >= 0.4 {
            tint = .coherenceMedium
        } else {
            tint = .coherenceLow
        }

        return self.liquidGlass(tint: tint, depth: .floating)
    }
}

// MARK: - Liquid Glass Button

/// Button styled with Liquid Glass effect
public struct LiquidGlassButton: View {
    let title: String
    let icon: String?
    let tint: LiquidGlass.Tint
    let action: () -> Void

    @State private var isPressed = false

    public init(
        _ title: String,
        icon: String? = nil,
        tint: LiquidGlass.Tint = .vibrant,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.action = action
    }

    public var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
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
            .liquidGlass(tint: tint, depth: .elevated, interactive: true)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Liquid Glass Card

/// Card component with Liquid Glass effect
public struct LiquidGlassCard<Content: View>: View {
    let depth: LiquidGlass.DepthLevel
    let tint: LiquidGlass.Tint
    let content: () -> Content

    public init(
        depth: LiquidGlass.DepthLevel = .elevated,
        tint: LiquidGlass.Tint = .subtle,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.depth = depth
        self.tint = tint
        self.content = content
    }

    public var body: some View {
        content()
            .padding(16)
            .liquidGlass(tint: tint, depth: depth)
    }
}

// MARK: - Bio-Reactive Glass Panel

/// Panel that visually responds to biometric data
public struct BioReactiveGlassPanel<Content: View>: View {
    @ObservedObject var healthKit: UnifiedHealthKitEngine
    let content: () -> Content

    @State private var pulseScale: CGFloat = 1.0

    public init(
        healthKit: UnifiedHealthKitEngine = .shared,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.healthKit = healthKit
        self.content = content
    }

    public var body: some View {
        content()
            .padding(20)
            .bioReactiveLiquidGlass(coherence: healthKit.coherence)
            .overlay(
                // Coherence pulse ring
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(pulseColor, lineWidth: 2)
                    .scaleEffect(pulseScale)
                    .opacity(2 - pulseScale)
            )
            .onReceive(Timer.publish(every: 60.0 / max(healthKit.heartRate, 60), on: .main, in: .common).autoconnect()) { _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    pulseScale = 1.1
                }
                withAnimation(.easeIn(duration: 0.5).delay(0.3)) {
                    pulseScale = 1.0
                }
            }
    }

    private var pulseColor: Color {
        switch healthKit.coherenceLevel {
        case .high: return .green
        case .medium: return .yellow
        case .low: return .orange
        }
    }
}

// MARK: - Liquid Glass Navigation Bar

/// Navigation bar with Liquid Glass backdrop
public struct LiquidGlassNavigationBar: View {
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
        .liquidGlass(tint: .ultraThin, depth: .floating)
    }
}

// MARK: - Liquid Glass Tab Bar

/// Tab bar with Liquid Glass effect
public struct LiquidGlassTabBar: View {
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
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                } label: {
                    VStack(spacing: 4) {
                        if #available(iOS 17.0, *) {
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
        .liquidGlass(tint: .subtle, depth: .floating)
    }
}

// MARK: - Coherence Orb (Liquid Glass)

/// Bio-reactive orb with Liquid Glass aesthetic
public struct CoherenceOrb: View {
    @ObservedObject var healthKit: UnifiedHealthKitEngine

    @State private var rotation: Double = 0
    @State private var breathPhase: Double = 0

    public init(healthKit: UnifiedHealthKitEngine = .shared) {
        self.healthKit = healthKit
    }

    public var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(orbGradient)
                .blur(radius: 40)
                .opacity(0.5)
                .scaleEffect(1 + breathPhase * 0.1)

            // Glass orb
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle()
                        .stroke(orbColor.opacity(0.5), lineWidth: 2)
                )
                .overlay(
                    // Specular highlight
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.5),
                                    Color.white.opacity(0.0)
                                ],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .scaleEffect(0.8)
                        .offset(x: -20, y: -20)
                )
                .shadow(color: orbColor.opacity(0.3), radius: 20)

            // Inner content
            VStack(spacing: 4) {
                Text("\(Int(healthKit.coherence * 100))")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("Coherence")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 180, height: 180)
        .rotation3DEffect(.degrees(rotation), axis: (x: 0.1, y: 1, z: 0))
        .onAppear {
            withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                breathPhase = healthKit.respiratoryData.breathPhase
            }
        }
    }

    private var orbColor: Color {
        switch healthKit.coherenceLevel {
        case .high: return .green
        case .medium: return .yellow
        case .low: return .orange
        }
    }

    private var orbGradient: RadialGradient {
        RadialGradient(
            colors: [
                orbColor,
                orbColor.opacity(0.3),
                Color.clear
            ],
            center: .center,
            startRadius: 20,
            endRadius: 100
        )
    }
}

// MARK: - Preview

#Preview("Liquid Glass Components") {
    ZStack {
        // Background
        LinearGradient(
            colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 20) {
            LiquidGlassNavigationBar(
                title: "Echoelmusic",
                leadingAction: {},
                trailingAction: {}
            )

            CoherenceOrb()

            LiquidGlassCard(tint: .chromatic) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bio-Reactive Session")
                        .font(.headline)
                    Text("Your coherence is improving")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 16) {
                LiquidGlassButton("Start", icon: "play.fill", tint: .coherenceHigh) {}
                LiquidGlassButton("Pause", icon: "pause.fill", tint: .subtle) {}
            }

            Spacer()
        }
        .padding()
    }
}
