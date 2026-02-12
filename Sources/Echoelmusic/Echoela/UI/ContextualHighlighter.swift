// ContextualHighlighter.swift
// Echoelmusic - Echoela Physical AI
//
// Metal-accelerated Aura UI for focus-steering and contextual highlighting
// Integrates with WorldModel for confidence-driven visual feedback
//
// Copyright © 2026 Echoelmusic. All rights reserved.

import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Aura Configuration

/// Configuration for the contextual aura effect
public struct AuraConfiguration: Sendable {
    public var baseColor: Color
    public var secondaryColor: Color
    public var pulseSpeed: Double
    public var glowRadius: CGFloat
    public var intensity: CGFloat
    public var blurAmount: CGFloat

    public static let stable = AuraConfiguration(
        baseColor: .cyan,
        secondaryColor: .blue,
        pulseSpeed: 2.0,
        glowRadius: 20,
        intensity: 0.8,
        blurAmount: 15
    )

    public static let creative = AuraConfiguration(
        baseColor: Color(red: 1, green: 0, blue: 1),
        secondaryColor: .purple,
        pulseSpeed: 1.5,
        glowRadius: 25,
        intensity: 0.9,
        blurAmount: 20
    )

    public static let warning = AuraConfiguration(
        baseColor: .orange,
        secondaryColor: .yellow,
        pulseSpeed: 3.0,
        glowRadius: 15,
        intensity: 1.0,
        blurAmount: 10
    )

    public static let calm = AuraConfiguration(
        baseColor: .green,
        secondaryColor: .mint,
        pulseSpeed: 4.0,
        glowRadius: 30,
        intensity: 0.6,
        blurAmount: 25
    )

    /// Generate aura config from WorldModel confidence
    public static func fromConfidence(_ confidence: Float, variance: Float) -> AuraConfiguration {
        if confidence > 0.8 {
            // High confidence = stable cyan
            return .stable
        } else if variance > 0.5 {
            // High variance = creative magenta
            return .creative
        } else if confidence < 0.4 {
            // Low confidence = warning orange
            return .warning
        } else {
            // Moderate = calm green
            return .calm
        }
    }
}

// MARK: - Contextual Highlighter Manager

/// Manages contextual highlighting and focus-steering across the UI
@MainActor
public final class ContextualHighlighter: ObservableObject {

    // MARK: - Singleton

    public static let shared = ContextualHighlighter()

    // MARK: - Published State

    @Published public var focusedElementID: String?
    @Published public var auraConfig: AuraConfiguration = .stable
    @Published public var isHighlighting: Bool = false
    @Published public var highlightedElements: Set<String> = []
    @Published public var dimmedElements: Set<String> = []
    @Published public var activeDeepLink: URL?

    // MARK: - Configuration

    /// Transition duration for focus changes
    public var transitionDuration: Double = 0.3

    /// Whether to auto-dim non-focused elements
    public var autoDimEnabled: Bool = true

    /// Dim opacity for non-focused elements
    public var dimOpacity: Double = 0.3

    // MARK: - Internal

    private var cancellables = Set<AnyCancellable>()
    private var worldModelSubscription: AnyCancellable?

    // MARK: - Initialization

    private init() {
        setupWorldModelBinding()
    }

    private func setupWorldModelBinding() {
        // Subscribe to WorldModel predictions to update aura
        worldModelSubscription = WorldModel.shared.$latestPrediction
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] prediction in
                self?.updateAuraFromPrediction(prediction)
            }
    }

    // MARK: - Public API

    /// Highlight a specific UI element with aura glow
    public func highlight(elementID: String, config: AuraConfiguration? = nil) {
        withAnimation(.easeInOut(duration: transitionDuration)) {
            focusedElementID = elementID
            highlightedElements.insert(elementID)
            isHighlighting = true

            if let config = config {
                auraConfig = config
            }

            if autoDimEnabled {
                // All other elements get dimmed
                dimmedElements = highlightedElements.subtracting([elementID])
            }
        }

        log.info("Highlighting element: \(elementID)", category: .interface)
    }

    /// Flow focus to a new element with matched geometry effect
    public func flowFocus(to elementID: String, from sourceID: String? = nil) {
        let source = sourceID ?? focusedElementID

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if let source = source {
                dimmedElements.insert(source)
            }
            focusedElementID = elementID
            highlightedElements = [elementID]
            isHighlighting = true
        }
    }

    /// Clear all highlighting
    public func clearHighlight() {
        withAnimation(.easeOut(duration: transitionDuration)) {
            focusedElementID = nil
            highlightedElements.removeAll()
            dimmedElements.removeAll()
            isHighlighting = false
        }
    }

    /// Dim all elements except the specified one
    public func dimExcept(elementID: String) {
        withAnimation(.easeInOut(duration: transitionDuration * 0.5)) {
            dimmedElements = highlightedElements.subtracting([elementID])
        }
    }

    /// Set deep link for current context
    public func setDeepLink(_ url: URL) {
        activeDeepLink = url
    }

    /// Generate and set deep link for action
    public func setDeepLink(category: String, action: String, parameters: [String: String] = [:]) {
        var components = URLComponents()
        components.scheme = "echoelmusic"
        components.host = "action"
        components.path = "/\(category)/\(action)"

        if !parameters.isEmpty {
            components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        activeDeepLink = components.url
    }

    // MARK: - Private

    private func updateAuraFromPrediction(_ prediction: WorldPrediction) {
        // Map prediction confidence to aura color
        let confidence = prediction.confidence
        let mood = prediction.emotionalTrajectory.currentMood

        let newConfig: AuraConfiguration
        switch mood {
        case .calm, .introspective:
            newConfig = .calm
        case .focused:
            newConfig = .stable
        case .energized, .euphoric:
            newConfig = .creative
        case .tense, .fatigued:
            newConfig = .warning
        }

        // Adjust intensity based on confidence
        var adjustedConfig = newConfig
        adjustedConfig.intensity = CGFloat(confidence)

        withAnimation(.easeInOut(duration: 0.5)) {
            auraConfig = adjustedConfig
        }
    }
}

// MARK: - Aura View Modifier

/// SwiftUI modifier that applies the contextual aura effect
public struct AuraHighlightModifier: ViewModifier {
    let elementID: String
    @ObservedObject var highlighter: ContextualHighlighter

    @State private var pulsePhase: CGFloat = 0

    private var isHighlighted: Bool {
        highlighter.focusedElementID == elementID
    }

    private var isDimmed: Bool {
        highlighter.isHighlighting && !isHighlighted && highlighter.autoDimEnabled
    }

    public func body(content: Content) -> some View {
        content
            .opacity(isDimmed ? highlighter.dimOpacity : 1.0)
            .overlay {
                if isHighlighted {
                    auraOverlay
                }
            }
            .background {
                if isHighlighted {
                    auraBackground
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(isHighlighted ? .isSelected : [])
    }

    @ViewBuilder
    private var auraOverlay: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(
                LinearGradient(
                    colors: [
                        highlighter.auraConfig.baseColor.opacity(Double(pulsePhase)),
                        highlighter.auraConfig.secondaryColor.opacity(Double(1 - pulsePhase))
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 2
            )
            .blur(radius: 2)
            .onAppear {
                withAnimation(.easeInOut(duration: highlighter.auraConfig.pulseSpeed).repeatForever(autoreverses: true)) {
                    pulsePhase = 1
                }
            }
    }

    @ViewBuilder
    private var auraBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                RadialGradient(
                    colors: [
                        highlighter.auraConfig.baseColor.opacity(0.3 * Double(highlighter.auraConfig.intensity)),
                        highlighter.auraConfig.baseColor.opacity(0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: highlighter.auraConfig.glowRadius
                )
            )
            .blur(radius: highlighter.auraConfig.blurAmount)
    }
}

// MARK: - Contextual Action Button

/// Button that appears alongside highlighted elements with deep link action
public struct ContextualActionButton: View {
    let title: String
    let systemImage: String
    let deepLink: URL?
    let action: () -> Void

    @ObservedObject private var highlighter = ContextualHighlighter.shared

    public init(
        title: String,
        systemImage: String,
        deepLink: URL? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.deepLink = deepLink
        self.action = action
    }

    public var body: some View {
        Button {
            if let deepLink = deepLink {
                #if os(iOS) || os(visionOS)
                UIApplication.shared.open(deepLink)
                #elseif os(macOS)
                NSWorkspace.shared.open(deepLink)
                #endif
            }
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(highlighter.auraConfig.baseColor.opacity(0.5), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Focus Explanation View

/// Overlay view that explains the focused element
public struct FocusExplanationView: View {
    let title: String
    let explanation: String
    let deepLinkAction: String?
    let onDismiss: () -> Void

    @ObservedObject private var highlighter = ContextualHighlighter.shared
    @Environment(\.colorScheme) private var colorScheme

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(highlighter.auraConfig.baseColor)
                Text("Echoela erklärt")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            // Title
            Text(title)
                .font(.headline)

            // Explanation
            Text(explanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Action button if deep link available
            if let action = deepLinkAction, let url = highlighter.activeDeepLink {
                Divider()

                ContextualActionButton(
                    title: action,
                    systemImage: "arrow.right.circle",
                    deepLink: url
                ) {
                    onDismiss()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: highlighter.auraConfig.baseColor.opacity(0.3), radius: 20)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(highlighter.auraConfig.baseColor.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Accessibility Focus Sync

/// Synchronizes VoiceOver focus with visual aura highlighting
public struct AccessibilityFocusSyncModifier: ViewModifier {
    let elementID: String
    @ObservedObject var highlighter: ContextualHighlighter

    @AccessibilityFocusState private var isAccessibilityFocused: Bool

    public func body(content: Content) -> some View {
        content
            .accessibilityFocused($isAccessibilityFocused)
            .onChange(of: isAccessibilityFocused) { newValue in
                if newValue {
                    highlighter.highlight(elementID: elementID)
                }
            }
            .onChange(of: highlighter.focusedElementID) { newValue in
                isAccessibilityFocused = (newValue == elementID)
            }
    }
}

// MARK: - Look-to-Action (visionOS)

#if os(visionOS)
import RealityKit

/// visionOS gaze-based interaction for Echoela
public struct GazeInteractionModifier: ViewModifier {
    let elementID: String
    let contextDescription: String
    @ObservedObject var highlighter: ContextualHighlighter

    @State private var isGazeTarget: Bool = false
    @State private var gazeDuration: TimeInterval = 0
    private let gazeThreshold: TimeInterval = 1.5  // seconds to trigger

    public func body(content: Content) -> some View {
        content
            .hoverEffect(.highlight)
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    if !isGazeTarget {
                        isGazeTarget = true
                        startGazeTimer()
                    }
                case .ended:
                    isGazeTarget = false
                    gazeDuration = 0
                }
            }
            .onChange(of: gazeDuration) { duration in
                if duration >= gazeThreshold {
                    triggerGazeAction()
                }
            }
    }

    private func startGazeTimer() {
        Task {
            while isGazeTarget {
                try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
                gazeDuration += 0.1
            }
        }
    }

    private func triggerGazeAction() {
        highlighter.highlight(elementID: elementID)

        // Notify Echoela of gaze context
        NotificationCenter.default.post(
            name: .echoelaGazeContext,
            object: nil,
            userInfo: [
                "elementID": elementID,
                "context": contextDescription
            ]
        )
    }
}

extension Notification.Name {
    static let echoelaGazeContext = Notification.Name("echoelaGazeContext")
}
#endif

// MARK: - View Extensions

public extension View {
    /// Apply aura highlight effect
    func echoelaAura(id: String) -> some View {
        modifier(AuraHighlightModifier(
            elementID: id,
            highlighter: ContextualHighlighter.shared
        ))
    }

    /// Sync accessibility focus with visual highlight
    func echoelaAccessibilitySync(id: String) -> some View {
        modifier(AccessibilityFocusSyncModifier(
            elementID: id,
            highlighter: ContextualHighlighter.shared
        ))
    }

    #if os(visionOS)
    /// Enable look-to-action for visionOS
    func echoelaGaze(id: String, context: String) -> some View {
        modifier(GazeInteractionModifier(
            elementID: id,
            contextDescription: context,
            highlighter: ContextualHighlighter.shared
        ))
    }
    #endif

    /// Full Echoela integration (aura + accessibility)
    func echoelaInteractive(id: String, context: String = "") -> some View {
        self
            .echoelaAura(id: id)
            .echoelaAccessibilitySync(id: id)
            #if os(visionOS)
            .echoelaGaze(id: id, context: context)
            #endif
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack(spacing: 20) {
        Text("Filter Cutoff")
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)
            .echoelaInteractive(id: "filterCutoff", context: "Controls the brightness of the sound")

        Text("Reverb Mix")
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)
            .echoelaInteractive(id: "reverbMix", context: "Adds space and depth")

        Button("Highlight Filter") {
            ContextualHighlighter.shared.highlight(elementID: "filterCutoff", config: .creative)
        }
    }
    .padding()
}
#endif
