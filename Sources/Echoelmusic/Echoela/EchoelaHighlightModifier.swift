// MARK: - EchoelaHighlightModifier.swift
// Echoelmusic Suite - Echoela UI Components
// Copyright 2026 Echoelmusic. All rights reserved.

import SwiftUI
import Combine

// MARK: - Echoela Highlight View Modifier

/// View modifier that adds a quantum glow aura effect when Echoela highlights an element
/// Uses Metal shaders for GPU-accelerated rendering
public struct EchoelaHighlightModifier: ViewModifier {

    // MARK: - Properties

    let elementID: String
    @Binding var isActive: Bool

    @State private var glowIntensity: Double = 0
    @State private var glowPhase: Double = 0
    @StateObject private var echoelaManager = EchoelaManager.shared

    // Accessibility
    @AccessibilityFocusState private var isAccessibilityFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Configuration

    private let glowColor: Color
    private let animationDuration: Double
    private let pulseEnabled: Bool

    public init(
        elementID: String,
        isActive: Binding<Bool>,
        glowColor: Color = .purple,
        animationDuration: Double = 0.5,
        pulseEnabled: Bool = true
    ) {
        self.elementID = elementID
        self._isActive = isActive
        self.glowColor = glowColor
        self.animationDuration = animationDuration
        self.pulseEnabled = pulseEnabled
    }

    // MARK: - Body

    public func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(glowColor, lineWidth: isActive ? 3 : 0)
                    .blur(radius: isActive ? glowIntensity * 10 : 0)
                    .opacity(isActive ? 0.8 : 0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(glowColor.opacity(0.5), lineWidth: isActive ? 1 : 0)
                    .opacity(isActive ? 1 : 0)
            )
            .scaleEffect(isActive && !reduceMotion ? 1.02 + glowIntensity * 0.01 : 1.0)
            .shadow(
                color: isActive ? glowColor.opacity(0.6) : .clear,
                radius: isActive ? 20 * glowIntensity : 0
            )
            .animation(.easeInOut(duration: animationDuration), value: isActive)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(isActive ? "Echoela is highlighting this element" : "")
            .accessibilityAddTraits(isActive ? .isSelected : [])
            .accessibilityFocused($isAccessibilityFocused)
            .onChange(of: isActive) { newValue in
                if newValue {
                    activateHighlight()
                } else {
                    deactivateHighlight()
                }
            }
            .onChange(of: echoelaManager.highlightedElement) { newValue in
                if newValue == elementID {
                    isActive = true
                } else if isActive && newValue != elementID {
                    isActive = false
                }
            }
            .onAppear {
                // Start pulse animation if enabled
                if pulseEnabled && isActive {
                    startPulseAnimation()
                }
            }
    }

    // MARK: - Private Methods

    private func activateHighlight() {
        // Sync with VoiceOver
        isAccessibilityFocused = true

        // Announce to VoiceOver
        let announcement = "Echoela is guiding you to \(elementID.replacingOccurrences(of: "_", with: " "))"
        UIAccessibility.post(notification: .announcement, argument: announcement)

        // Start glow animation
        if !reduceMotion {
            startPulseAnimation()
        } else {
            glowIntensity = 1.0
        }
    }

    private func deactivateHighlight() {
        isAccessibilityFocused = false
        withAnimation(.easeOut(duration: animationDuration)) {
            glowIntensity = 0
            glowPhase = 0
        }
    }

    private func startPulseAnimation() {
        guard pulseEnabled && !reduceMotion else {
            glowIntensity = 1.0
            return
        }

        // Continuous pulse animation
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            glowIntensity = 1.0
        }
    }
}

// MARK: - View Extension

public extension View {
    /// Apply Echoela highlight effect to a view
    /// - Parameters:
    ///   - isActive: Binding to control highlight state
    ///   - elementID: Unique identifier for this element
    ///   - glowColor: Color of the glow effect (default: purple)
    ///   - pulseEnabled: Whether to animate the glow (default: true)
    func echoelaHighlight(
        isActive: Binding<Bool>,
        elementID: String,
        glowColor: Color = .purple,
        pulseEnabled: Bool = true
    ) -> some View {
        self.modifier(EchoelaHighlightModifier(
            elementID: elementID,
            isActive: isActive,
            glowColor: glowColor,
            pulseEnabled: pulseEnabled
        ))
    }

    /// Convenience method using element ID only (auto-binds to EchoelaManager)
    func echoelaHighlight(elementID: String, glowColor: Color = .purple) -> some View {
        EchoelaHighlightWrapper(content: self, elementID: elementID, glowColor: glowColor)
    }
}

// MARK: - Highlight Wrapper (Auto-binding)

struct EchoelaHighlightWrapper<Content: View>: View {
    let content: Content
    let elementID: String
    let glowColor: Color

    @StateObject private var echoelaManager = EchoelaManager.shared
    @State private var isHighlighted = false

    var body: some View {
        content
            .echoelaHighlight(
                isActive: $isHighlighted,
                elementID: elementID,
                glowColor: glowColor
            )
            .onChange(of: echoelaManager.highlightedElement) { newValue in
                isHighlighted = (newValue == elementID)
            }
    }
}

// MARK: - Quantum Glow Effect (Metal Shader Placeholder)

/// Metal shader for quantum glow effect
/// In production, this would be a .metal file with GPU-accelerated rendering
public struct QuantumGlowEffect: ViewModifier {

    let intensity: Double
    let color: Color
    let phase: Double

    public func body(content: Content) -> some View {
        content
            // In production, this would use:
            // .colorEffect(ShaderLibrary.quantumGlow(.float(intensity), .float(phase), .color(color)))
            .overlay(
                ZStack {
                    // Outer glow
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    color.opacity(0.8),
                                    color.opacity(0.4),
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 4
                        )
                        .blur(radius: 8 * intensity)

                    // Inner quantum shimmer
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    color,
                                    color.opacity(0.6),
                                    .white.opacity(0.8),
                                    color.opacity(0.6),
                                    color
                                ],
                                center: .center,
                                angle: .degrees(phase * 360)
                            ),
                            lineWidth: 2
                        )
                        .blur(radius: 2)

                    // Particle-like specks (simulated)
                    ForEach(0..<5, id: \.self) { index in
                        Circle()
                            .fill(color.opacity(0.8))
                            .frame(width: 4, height: 4)
                            .offset(
                                x: CGFloat.random(in: -50...50) * intensity,
                                y: CGFloat.random(in: -50...50) * intensity
                            )
                            .blur(radius: 2)
                    }
                }
                .opacity(intensity)
            )
    }
}

public extension View {
    func quantumGlow(intensity: Double, color: Color = .purple, phase: Double = 0) -> some View {
        self.modifier(QuantumGlowEffect(intensity: intensity, color: color, phase: phase))
    }
}

// MARK: - Echoela Chat Bubble

/// Chat bubble for Echoela responses
public struct EchoelaChatBubble: View {
    let message: EchoelaManager.EchoelaMessage
    let onActionTap: ((URL) -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    public init(message: EchoelaManager.EchoelaMessage, onActionTap: ((URL) -> Void)? = nil) {
        self.message = message
        self.onActionTap = onActionTap
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .assistant {
                // Echoela avatar
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(.purple)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(.purple.opacity(0.2)))
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                // Message content
                Text(message.content)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(message.role == .user ? Color.purple : Color(.systemGray5))
                    )
                    .foregroundColor(message.role == .user ? .white : .primary)

                // Bio context if available
                if let bio = message.bioContext {
                    HStack(spacing: 8) {
                        Label("\(Int(bio.heartRate))", systemImage: "heart.fill")
                        Label("\(Int(bio.hrv))ms", systemImage: "waveform.path.ecg")
                        Label("\(Int(bio.coherence * 100))%", systemImage: "circle.hexagongrid.fill")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                // Tool calls / deep links
                if let tools = message.tools, !tools.isEmpty {
                    ForEach(tools, id: \.toolID) { tool in
                        if let url = tool.deepLink {
                            Button {
                                onActionTap?(url)
                            } label: {
                                Label(tool.action.replacingOccurrences(of: "/", with: " → "), systemImage: "link")
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(.purple.opacity(0.2)))
                            }
                        }
                    }
                }

                // Timestamp
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if message.role == .user {
                Spacer()
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Echoela Action Card

/// Card for suggested actions from Echoela
public struct EchoelaActionCard: View {
    let action: EchoelaManager.EchoelaResponse.SuggestedAction
    let onTap: () -> Void

    public init(action: EchoelaManager.EchoelaResponse.SuggestedAction, onTap: @escaping () -> Void) {
        self.action = action
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: action.icon)
                    .font(.title3)
                    .foregroundStyle(action.isDestructive ? .red : .purple)

                Text(action.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Echoela Assistant View

/// Main Echoela assistant interface
public struct EchoelaAssistantView: View {
    @StateObject private var echoela = EchoelaManager.shared
    @State private var inputText = ""
    @State private var isExpanded = false

    // Bio context from parent
    public var bioContext: EchoelaManager.EchoelaMessage.BioContext?

    public init(bioContext: EchoelaManager.EchoelaMessage.BioContext? = nil) {
        self.bioContext = bioContext
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                Text("Echoela")
                    .font(.headline)
                Spacer()

                // Context badge
                Text(echoela.currentContext.rawValue.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.purple.opacity(0.2)))

                Button {
                    withAnimation { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                }
            }
            .padding()
            .background(Color(.systemBackground))

            if isExpanded {
                // Conversation
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(echoela.conversationHistory) { message in
                            EchoelaChatBubble(message: message) { url in
                                echoela.executeDeepLink(url)
                            }
                        }
                    }
                    .padding(.vertical)
                }

                // Suggested actions
                if let response = echoela.lastResponse, !response.suggestedActions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(response.suggestedActions, id: \.title) { action in
                                EchoelaActionCard(action: action) {
                                    echoela.executeDeepLink(action.deepLink)
                                }
                                .frame(width: 200)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)
                }

                // Input
                HStack(spacing: 12) {
                    TextField("Ask Echoela...", text: $inputText)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.purple)
                    }
                    .disabled(inputText.isEmpty)
                }
                .padding()
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 8)
    }

    private func sendMessage() {
        let text = inputText
        inputText = ""

        Task {
            do {
                _ = try await echoela.sendMessage(text, bioContext: bioContext)
            } catch {
                // Handle error
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Text("Test Element")
            .padding()
            .background(Color.blue)
            .echoelaHighlight(elementID: "test_element")

        EchoelaAssistantView()
            .frame(height: 400)
    }
    .padding()
}
