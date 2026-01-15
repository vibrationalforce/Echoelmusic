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

// MARK: - Echoela Peek View (Playful Peek Animation)

/// Echoela peeking playfully from behind UI elements
public struct EchoelaPeekView: View {
    @ObservedObject var echoela: EchoelaEngine
    @Environment(\.colorScheme) var colorScheme

    public init(echoela: EchoelaEngine = .shared) {
        self.echoela = echoela
    }

    public var body: some View {
        GeometryReader { geometry in
            if echoela.peekState.visibility > 0 && !echoela.isLivePerformanceMode {
                ZStack {
                    // Subtle background glow
                    echoela.peekState.backgroundTint
                        .opacity(Double(echoela.peekState.visibility) * 0.3)
                        .blur(radius: 30)
                        .allowsHitTesting(false)

                    // Echoela avatar peeking
                    EchoelaAvatarView(
                        personality: echoela.personality,
                        phase: echoela.peekState.animationPhase
                    )
                    .scaleEffect(CGFloat(0.5 + echoela.peekState.visibility * 0.5))
                    .opacity(Double(echoela.peekState.visibility))
                    .position(peekPosition(in: geometry.size))
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: echoela.peekState.visibility)
            }
        }
    }

    private func peekPosition(in size: CGSize) -> CGPoint {
        let visibility = CGFloat(echoela.peekState.visibility)
        let offset = (1 - visibility) * 60  // How far offscreen when peeking

        switch echoela.peekState.peekEdge {
        case .bottomTrailing:
            return CGPoint(x: size.width - 40 + offset, y: size.height - 80 + offset)
        case .bottomLeading:
            return CGPoint(x: 40 - offset, y: size.height - 80 + offset)
        case .topTrailing:
            return CGPoint(x: size.width - 40 + offset, y: 80 - offset)
        case .topLeading:
            return CGPoint(x: 40 - offset, y: 80 - offset)
        case .bottom:
            return CGPoint(x: size.width / 2, y: size.height - 40 + offset)
        case .trailing:
            return CGPoint(x: size.width - 40 + offset, y: size.height / 2)
        case .leading:
            return CGPoint(x: 40 - offset, y: size.height / 2)
        }
    }
}

// MARK: - Echoela Avatar View

/// Echoela's visual avatar that reflects her personality
struct EchoelaAvatarView: View {
    let personality: EchoelaPersonality
    let phase: EchoelaPeekState.PeekAnimationPhase

    @State private var pulseScale: CGFloat = 1.0
    @State private var eyeOffset: CGFloat = 0.0

    var body: some View {
        ZStack {
            // Soft glow background
            Circle()
                .fill(avatarGradient)
                .frame(width: 56, height: 56)
                .blur(radius: 8)
                .scaleEffect(pulseScale)

            // Main avatar circle
            Circle()
                .fill(avatarGradient)
                .frame(width: 48, height: 48)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

            // Sparkle icon
            Image(systemName: "sparkle")
                .font(.title2.weight(.medium))
                .foregroundColor(.white)
                .offset(y: eyeOffset)

            // Playful expression overlay
            if personality.playfulness > 0.5 && phase == .peeking {
                // Little "peeking" eyes effect
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                }
                .offset(y: -4 + eyeOffset)
            }
        }
        .onAppear {
            startAnimations()
        }
        .onChange(of: phase) { _, newPhase in
            updateAnimations(for: newPhase)
        }
    }

    private var avatarGradient: LinearGradient {
        let baseColor = Color(red: 0.4, green: 0.5, blue: 0.9)
        let warmColor = Color(red: 0.6, green: 0.5, blue: 0.9)
        let playfulColor = Color(red: 0.5, green: 0.7, blue: 0.95)

        let topColor = personality.playfulness > 0.5 ? playfulColor : baseColor
        let bottomColor = personality.warmth > 0.5 ? warmColor : baseColor

        return LinearGradient(
            colors: [topColor, bottomColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func startAnimations() {
        // Gentle breathing pulse
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            pulseScale = 1.05
        }
    }

    private func updateAnimations(for phase: EchoelaPeekState.PeekAnimationPhase) {
        switch phase {
        case .peeking:
            // Playful eye movement
            withAnimation(.easeInOut(duration: 0.3)) {
                eyeOffset = -2
            }
        case .visible, .explaining:
            withAnimation(.easeInOut(duration: 0.2)) {
                eyeOffset = 0
            }
        default:
            eyeOffset = 0
        }
    }
}

// MARK: - Personality Settings View

/// View for adjusting Echoela's personality
public struct EchoelaPersonalityView: View {
    @ObservedObject var echoela: EchoelaEngine

    public init(echoela: EchoelaEngine = .shared) {
        self.echoela = echoela
    }

    public var body: some View {
        Form {
            Section {
                Text("Adjust how Echoela communicates with you")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Section("Presets") {
                ForEach(EchoelaEngine.PersonalityPreset.allCases, id: \.self) { preset in
                    Button {
                        echoela.applyPersonalityPreset(preset)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(preset.rawValue)
                                    .foregroundColor(.primary)
                                Text(presetDescription(preset))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if isCurrentPreset(preset) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }

            Section("Fine Tuning") {
                PersonalitySlider(
                    title: "Warmth",
                    value: Binding(
                        get: { echoela.personality.warmth },
                        set: { echoela.personality.warmth = $0; echoela.setPersonality(echoela.personality) }
                    ),
                    lowLabel: "Neutral",
                    highLabel: "Warm"
                )

                PersonalitySlider(
                    title: "Playfulness",
                    value: Binding(
                        get: { echoela.personality.playfulness },
                        set: { echoela.personality.playfulness = $0; echoela.setPersonality(echoela.personality) }
                    ),
                    lowLabel: "Serious",
                    highLabel: "Playful"
                )

                PersonalitySlider(
                    title: "Verbosity",
                    value: Binding(
                        get: { echoela.personality.verbosity },
                        set: { echoela.personality.verbosity = $0; echoela.setPersonality(echoela.personality) }
                    ),
                    lowLabel: "Brief",
                    highLabel: "Detailed"
                )

                PersonalitySlider(
                    title: "Encouragement",
                    value: Binding(
                        get: { echoela.personality.encouragement },
                        set: { echoela.personality.encouragement = $0; echoela.setPersonality(echoela.personality) }
                    ),
                    lowLabel: "Minimal",
                    highLabel: "Frequent"
                )
            }

            Section("Voice") {
                PersonalitySlider(
                    title: "Voice Speed",
                    value: Binding(
                        get: { echoela.personality.voiceSpeed },
                        set: { echoela.personality.voiceSpeed = $0; echoela.setPersonality(echoela.personality) }
                    ),
                    lowLabel: "Slow",
                    highLabel: "Fast",
                    range: 0.5...1.5
                )

                PersonalitySlider(
                    title: "Voice Pitch",
                    value: Binding(
                        get: { echoela.personality.voicePitch },
                        set: { echoela.personality.voicePitch = $0; echoela.setPersonality(echoela.personality) }
                    ),
                    lowLabel: "Lower",
                    highLabel: "Higher",
                    range: 0.5...1.5
                )
            }
        }
        .navigationTitle("Echoela Personality")
    }

    private func presetDescription(_ preset: EchoelaEngine.PersonalityPreset) -> String {
        switch preset {
        case .warm: return "Gentle and supportive"
        case .playful: return "Fun and cheeky with subtle humor"
        case .professional: return "Clear and efficient"
        case .minimal: return "Only essential guidance"
        case .empathetic: return "Understanding and patient"
        }
    }

    private func isCurrentPreset(_ preset: EchoelaEngine.PersonalityPreset) -> Bool {
        switch preset {
        case .warm: return echoela.personality == .warm
        case .playful: return echoela.personality == .playful
        case .professional: return echoela.personality == .professional
        case .minimal: return echoela.personality == .minimal
        case .empathetic: return echoela.personality == .empathetic
        }
    }
}

struct PersonalitySlider: View {
    let title: String
    @Binding var value: Float
    let lowLabel: String
    let highLabel: String
    var range: ClosedRange<Float> = 0...1

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)

            HStack {
                Text(lowLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .leading)

                Slider(value: $value, in: range)
                    .tint(Color(red: 0.4, green: 0.5, blue: 0.9))

                Text(highLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
        }
    }
}

// MARK: - Feedback View

/// View for submitting feedback to Echoela
public struct EchoelaFeedbackView: View {
    @ObservedObject var echoela: EchoelaEngine
    @Environment(\.dismiss) var dismiss

    @State private var feedbackType: EchoelaFeedback.FeedbackType = .suggestion
    @State private var message: String = ""
    @State private var rating: Int = 3
    @State private var suggestion: String = ""

    public init(echoela: EchoelaEngine = .shared) {
        self.echoela = echoela
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Your feedback helps Echoela improve for everyone")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Section("Type") {
                    Picker("Feedback Type", selection: $feedbackType) {
                        Text("Suggestion").tag(EchoelaFeedback.FeedbackType.suggestion)
                        Text("Issue").tag(EchoelaFeedback.FeedbackType.issue)
                        Text("Praise").tag(EchoelaFeedback.FeedbackType.praise)
                        Text("Confusion").tag(EchoelaFeedback.FeedbackType.confusion)
                        Text("Feature Request").tag(EchoelaFeedback.FeedbackType.featureRequest)
                        Text("Accessibility").tag(EchoelaFeedback.FeedbackType.accessibility)
                    }
                    .pickerStyle(.menu)
                }

                Section("Your Feedback") {
                    TextField("What would you like to share?", text: $message, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Rating (Optional)") {
                    HStack {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                rating = star
                            } label: {
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .foregroundColor(star <= rating ? .yellow : .gray)
                                    .font(.title2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                Section("Additional Suggestion (Optional)") {
                    TextField("Any specific suggestions?", text: $suggestion, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section {
                    Button("Submit Feedback") {
                        submitFeedback()
                    }
                    .disabled(message.isEmpty)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func submitFeedback() {
        echoela.submitFeedback(
            type: feedbackType,
            context: echoela.currentContext?.id ?? "general",
            message: message,
            rating: rating,
            suggestion: suggestion.isEmpty ? nil : suggestion
        )
        dismiss()
    }
}

// MARK: - Enhanced Overlay with Peek

/// Enhanced Echoela overlay with peek animations
public struct EchoelaEnhancedOverlayModifier: ViewModifier {
    @ObservedObject var echoela: EchoelaEngine

    public init(echoela: EchoelaEngine = .shared) {
        self.echoela = echoela
    }

    public func body(content: Content) -> some View {
        ZStack {
            content

            // Peek animation layer
            EchoelaPeekView(echoela: echoela)

            // Main bubble (when fully visible)
            if echoela.isActive && !echoela.isLivePerformanceMode {
                VStack {
                    Spacer()
                    EchoelaBubble(echoela: echoela)
                        .padding(.bottom, 100)
                }
            }
        }
    }
}

public extension View {
    /// Add enhanced Echoela overlay with peek animations
    func withEchoelaEnhanced(_ echoela: EchoelaEngine = .shared) -> some View {
        modifier(EchoelaEnhancedOverlayModifier(echoela: echoela))
    }
}
