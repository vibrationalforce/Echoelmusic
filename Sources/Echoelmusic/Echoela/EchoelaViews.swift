/**
 * EchoelaViews.swift
 * Echoelmusic - Echoela SwiftUI Views
 *
 * Calm, accessible, non-judgmental UI components
 *
 * Design Principles:
 * - Low visual noise
 * - High contrast options
 * - Large touch targets
 * - Clear typography
 * - No flashing or urgency
 *
 * Created: 2026-01-15
 */

import SwiftUI

// MARK: - Echoela Bubble View

/// Floating help bubble that appears when Echoela has something to say
public struct EchoelaBubble: View {
    @ObservedObject var echoela: EchoelaEngine
    @Environment(\.colorScheme) var colorScheme

    public init(echoela: EchoelaEngine = .shared) {
        self.echoela = echoela
    }

    public var body: some View {
        Group {
            if let offer = echoela.pendingHelpOffer {
                HelpOfferBubble(
                    offer: offer,
                    onAccept: { echoela.acceptHelp() },
                    onDismiss: { echoela.dismissHelp() }
                )
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .opacity
                ))
            } else if let hint = echoela.currentHint {
                HintBubble(
                    hint: hint,
                    onExpand: { echoela.expandHint() },
                    onDismiss: { echoela.dismissHint() }
                )
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: echoela.pendingHelpOffer?.id)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: echoela.currentHint?.id)
    }
}

// MARK: - Help Offer Bubble

struct HelpOfferBubble: View {
    let offer: HelpOffer
    let onAccept: () -> Void
    let onDismiss: () -> Void

    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with Echoela identity
            HStack(spacing: 8) {
                Image(systemName: "sparkle")
                    .font(.title3)
                    .foregroundColor(calmAccentColor)

                Text("Echoela")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                // Dismiss button (always available)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Circle().fill(Color.secondary.opacity(0.1)))
                }
                .accessibilityLabel("Dismiss help")
            }

            // Message
            Text(offer.message)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            // Actions
            HStack(spacing: 12) {
                // Accept help button
                Button(action: onAccept) {
                    Text("Show me")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(calmAccentColor)
                        .cornerRadius(20)
                }
                .accessibilityLabel("Accept guidance")

                // Not now button
                Button(action: onDismiss) {
                    Text("Not now")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("Dismiss, I don't need help right now")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(bubbleBackgroundColor)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        )
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Echoela offers help: \(offer.message)")
        .accessibilityHint("Double tap to accept or swipe to dismiss")
    }

    private var calmAccentColor: Color {
        Color(red: 0.4, green: 0.5, blue: 0.9)  // Calm blue-purple
    }

    private var bubbleBackgroundColor: Color {
        colorScheme == .dark
            ? Color(white: 0.15)
            : Color.white
    }
}

// MARK: - Hint Bubble

struct HintBubble: View {
    let hint: GuidanceHint
    let onExpand: () -> Void
    let onDismiss: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb")
                    .foregroundColor(.orange)

                Text(hint.shortText)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if hint.isExpanded {
                Text(hint.detailedText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            } else {
                Button("Learn more") {
                    onExpand()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.95))
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Echoela Settings View

/// Settings for configuring Echoela
public struct EchoelaSettingsView: View {
    @ObservedObject var echoela: EchoelaEngine
    @State private var preferences: EchoelaPreferences

    public init(echoela: EchoelaEngine = .shared) {
        self.echoela = echoela
        self._preferences = State(initialValue: echoela.preferences)
    }

    public var body: some View {
        Form {
            Section {
                Toggle("Enable Echoela", isOn: $preferences.isEnabled)
                    .onChange(of: preferences.isEnabled) { _, newValue in
                        if newValue {
                            echoela.activate()
                        } else {
                            echoela.deactivate()
                        }
                        save()
                    }

                Text("Echoela is your optional guide. You can turn it off anytime.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Guidance")
            }

            Section {
                Toggle("Show contextual hints", isOn: $preferences.showHints)
                    .onChange(of: preferences.showHints) { _, _ in save() }

                Toggle("Voice guidance", isOn: $preferences.voiceGuidance)
                    .onChange(of: preferences.voiceGuidance) { _, _ in save() }
            } header: {
                Text("Hints & Voice")
            }

            Section {
                Picker("Text size", selection: $preferences.textSize) {
                    ForEach(EchoelaPreferences.TextSize.allCases, id: \.self) { size in
                        Text(size.rawValue.capitalized).tag(size)
                    }
                }
                .onChange(of: preferences.textSize) { _, _ in save() }

                Toggle("Use calm colors", isOn: $preferences.useCalmColors)
                    .onChange(of: preferences.useCalmColors) { _, _ in save() }

                Toggle("Reduce animations", isOn: $preferences.reduceAnimations)
                    .onChange(of: preferences.reduceAnimations) { _, _ in save() }
            } header: {
                Text("Appearance")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Skill level")
                        Spacer()
                        Text("\(Int(echoela.skillLevel * 100))%")
                            .foregroundColor(.secondary)
                    }
                    ProgressView(value: Double(echoela.skillLevel))
                        .tint(.green)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Guidance density")
                        Spacer()
                        Text(guidanceDensityLabel)
                            .foregroundColor(.secondary)
                    }
                    ProgressView(value: Double(echoela.guidanceDensity))
                        .tint(.blue)
                }

                Text("These adapt automatically as you learn")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Progress (Adaptive)")
            }

            Section {
                Button("Reset guidance history") {
                    resetProgress()
                }
                .foregroundColor(.red)

                Text("This resets skill tracking and completed topics. Echoela will start fresh.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Reset")
            }
        }
        .navigationTitle("Echoela Settings")
    }

    private var guidanceDensityLabel: String {
        switch echoela.guidanceDensity {
        case 0..<0.3: return "Minimal"
        case 0.3..<0.6: return "Balanced"
        default: return "Detailed"
        }
    }

    private func save() {
        preferences.save()
        echoela.preferences = preferences
    }

    private func resetProgress() {
        UserDefaults.standard.removeObject(forKey: "echoela_progress")
        echoela.skillLevel = 0.5
        echoela.confidenceScore = 0.5
        echoela.guidanceDensity = 0.5
        echoela.completedTopics.removeAll()
    }
}

// MARK: - Guided Tour View

/// A guided tour screen that walks users through a topic
public struct GuidedTourView: View {
    let context: GuidanceContext
    let onComplete: () -> Void

    @State private var currentStep = 0

    public var body: some View {
        VStack(spacing: 0) {
            // Progress
            ProgressView(value: Double(currentStep + 1), total: Double(context.steps.count))
                .padding()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title
                    Text(context.title)
                        .font(.largeTitle.weight(.bold))
                        .padding(.horizontal)

                    // Description
                    Text(context.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    Divider()
                        .padding(.vertical)

                    // Current step
                    if currentStep < context.steps.count {
                        StepView(
                            step: context.steps[currentStep],
                            stepNumber: currentStep + 1,
                            totalSteps: context.steps.count
                        )
                    }
                }
                .padding(.vertical)
            }

            // Navigation
            HStack {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation { currentStep -= 1 }
                    }
                    .foregroundColor(.secondary)
                }

                Spacer()

                if currentStep < context.steps.count - 1 {
                    Button("Continue") {
                        withAnimation { currentStep += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Done") {
                        EchoelaEngine.shared.completeTopic(context.topic)
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .accessibilityElement(children: .contain)
    }
}

struct StepView: View {
    let step: GuidanceStep
    let stepNumber: Int
    let totalSteps: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Step indicator
            HStack {
                Text("Step \(stepNumber) of \(totalSteps)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.secondary.opacity(0.1)))

                Spacer()
            }
            .padding(.horizontal)

            // Step title
            Text(step.title)
                .font(.title2.weight(.semibold))
                .padding(.horizontal)

            // Step description
            Text(step.description)
                .font(.body)
                .foregroundColor(.primary.opacity(0.8))
                .padding(.horizontal)

            // Optional action button
            if let action = step.action {
                Button("Try it now") {
                    action()
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
    }
}

// MARK: - Topic Browser

/// Browse all available guidance topics
public struct TopicBrowserView: View {
    @ObservedObject var echoela: EchoelaEngine = .shared
    @State private var selectedTopic: GuidanceTopic?

    public var body: some View {
        List {
            Section {
                Text("Learn at your own pace. No pressure, no timers.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Section("Topics") {
                ForEach(GuidanceTopic.allCases, id: \.self) { topic in
                    TopicRow(
                        topic: topic,
                        isComplete: echoela.isTopicComplete(topic)
                    ) {
                        selectedTopic = topic
                    }
                }
            }
        }
        .navigationTitle("Learn")
        .sheet(item: $selectedTopic) { topic in
            NavigationStack {
                GuidedTourView(
                    context: createContext(for: topic),
                    onComplete: { selectedTopic = nil }
                )
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { selectedTopic = nil }
                    }
                }
            }
        }
    }

    private func createContext(for topic: GuidanceTopic) -> GuidanceContext {
        // Return appropriate context for topic
        GuidanceContext(
            id: topic.rawValue,
            topic: topic,
            title: topic.rawValue,
            description: "Learn about \(topic.rawValue.lowercased()) features.",
            hints: [],
            steps: createSteps(for: topic)
        )
    }

    private func createSteps(for topic: GuidanceTopic) -> [GuidanceStep] {
        // Generate steps based on topic
        switch topic {
        case .audioBasics:
            return [
                GuidanceStep(title: "Sound Engine", description: "Echoelmusic uses advanced audio synthesis to create sounds that respond to your input.", action: nil),
                GuidanceStep(title: "Presets", description: "Start with a preset or create your own unique sound.", action: nil),
                GuidanceStep(title: "Controls", description: "Adjust volume, effects, and parameters to shape your sound.", action: nil)
            ]
        case .biofeedback:
            return [
                GuidanceStep(title: "What is Biofeedback?", description: "Your body generates signals like heart rate and breathing. Echoelmusic transforms these into music.", action: nil),
                GuidanceStep(title: "No Medical Claims", description: "This is a creative tool, not a medical device. It's for art and exploration.", action: nil),
                GuidanceStep(title: "Getting Started", description: "Connect your Apple Watch or use touch input to start creating.", action: nil)
            ]
        default:
            return [
                GuidanceStep(title: "Overview", description: "Learn about this feature.", action: nil)
            ]
        }
    }
}

struct TopicRow: View {
    let topic: GuidanceTopic
    let isComplete: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading) {
                    Text(topic.rawValue)
                        .font(.headline)

                    Text(isComplete ? "Explored" : "Tap to learn")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .foregroundColor(.primary)
    }
}

// Make GuidanceTopic Identifiable for sheet presentation
extension GuidanceTopic: Identifiable {
    public var id: String { rawValue }
}

// MARK: - View Modifier

/// Add Echoela overlay to any view
public struct EchoelaOverlayModifier: ViewModifier {
    @ObservedObject var echoela: EchoelaEngine

    public init(echoela: EchoelaEngine = .shared) {
        self.echoela = echoela
    }

    public func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content

            if echoela.isActive {
                EchoelaBubble(echoela: echoela)
                    .padding(.bottom, 100)
            }
        }
    }
}

public extension View {
    /// Add Echoela guidance overlay
    func withEchoela(_ echoela: EchoelaEngine = .shared) -> some View {
        modifier(EchoelaOverlayModifier(echoela: echoela))
    }
}
