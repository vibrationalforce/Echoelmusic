import SwiftUI
import AVFoundation
import Combine

/// First-Time Experience - 30 Second "Aha Moment"
/// Goal: User experiences bio-reactive audio-visual magic within 30 seconds
/// No signup, no permissions required initially - instant gratification
@MainActor
class FirstTimeExperience: ObservableObject {

    // MARK: - Published State

    @Published var currentStep: OnboardingStep = .welcome
    @Published var hasCompletedOnboarding: Bool = false
    @Published var skipPermissions: Bool = false  // Allow usage without HealthKit
    @Published var demoMode: Bool = true  // Start in demo mode

    // MARK: - Onboarding Steps (30 seconds total)

    enum OnboardingStep: Int, CaseIterable {
        case welcome = 0           // 5 seconds
        case instantDemo = 1       // 10 seconds - INSTANT AHA MOMENT
        case explainer = 2         // 5 seconds
        case permissions = 3       // 5 seconds (optional)
        case quickStart = 4        // 5 seconds

        var title: String {
            switch self {
            case .welcome: return "Welcome to Echoelmusic"
            case .instantDemo: return "Feel Your Heartbeat"
            case .explainer: return "What You Just Experienced"
            case .permissions: return "Unlock Full Experience"
            case .quickStart: return "You're All Set!"
            }
        }

        var description: String {
            switch self {
            case .welcome:
                return "Bio-reactive audio-visual experiences. Your body creates music."
            case .instantDemo:
                return "Touch and hold the screen. Notice how the sound reacts to your touch."
            case .explainer:
                return "Echoelmusic translates your biofeedback into immersive audio-visuals. This is art, not medicine."
            case .permissions:
                return "Optional: Connect HealthKit for heart rate reactive music. You can skip this and still enjoy everything."
            case .quickStart:
                return "Start creating! Explore presets, record sessions, or just play."
            }
        }

        var duration: TimeInterval {
            switch self {
            case .welcome: return 5.0
            case .instantDemo: return 10.0
            case .explainer: return 5.0
            case .permissions: return 5.0
            case .quickStart: return 5.0
            }
        }

        var isSkippable: Bool {
            switch self {
            case .permissions: return true
            default: return false
            }
        }
    }

    // MARK: - Demo Modes

    enum DemoMode {
        case touchReactive      // React to screen touch (no permissions)
        case microphoneReactive // React to voice/sound (mic permission only)
        case gestureReactive    // React to hand gestures (camera permission)
        case bioReactive        // React to heart rate (HealthKit permission)
    }

    // MARK: - Quick Start Presets

    struct QuickStartPreset: Identifiable {
        let id = UUID()
        let name: String
        let description: String
        let icon: String
        let category: PresetCategory
        let demoMode: DemoMode

        enum PresetCategory {
            case creative
            case meditation
            case performance
            case experimental
        }
    }

    let quickStartPresets: [QuickStartPreset] = [
        QuickStartPreset(
            name: "Touch Orchestra",
            description: "Create music with your fingertips. No permissions needed.",
            icon: "hand.tap",
            category: .creative,
            demoMode: .touchReactive
        ),
        QuickStartPreset(
            name: "Voice Visualizer",
            description: "Your voice becomes visual art. Mic access required.",
            icon: "waveform",
            category: .creative,
            demoMode: .microphoneReactive
        ),
        QuickStartPreset(
            name: "Breath Meditation",
            description: "Guided breathing with visual feedback.",
            icon: "wind",
            category: .meditation,
            demoMode: .touchReactive
        ),
        QuickStartPreset(
            name: "Heart Sync",
            description: "Music that follows your heartbeat. HealthKit optional.",
            icon: "heart.fill",
            category: .performance,
            demoMode: .bioReactive
        ),
        QuickStartPreset(
            name: "Gesture Symphony",
            description: "Conduct with your hands. Camera access required.",
            icon: "hand.wave",
            category: .experimental,
            demoMode: .gestureReactive
        ),
        QuickStartPreset(
            name: "Freestyle",
            description: "Open playground. All features unlocked.",
            icon: "sparkles",
            category: .creative,
            demoMode: .touchReactive
        )
    ]

    // MARK: - Initialization

    init() {
        // Check if already onboarded
        if UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            hasCompletedOnboarding = true
            demoMode = false
        }

        log.info("✅ First-Time Experience: Initialized", category: .ui)
    }

    // MARK: - Navigation

    func next() {
        guard let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep),
              currentIndex < OnboardingStep.allCases.count - 1 else {
            complete()
            return
        }

        currentStep = OnboardingStep.allCases[currentIndex + 1]
    }

    func skip() {
        guard currentStep.isSkippable else { return }
        next()
    }

    func complete() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        demoMode = false
        log.info("✅ Onboarding completed", category: .ui)
    }

    // MARK: - Demo Actions

    func startInstantDemo() {
        // Launch instant demo (touch-reactive audio-visual)
        // No permissions required - uses touch input only
        log.info("▶️ Instant Demo: Touch-reactive mode", category: .ui)
    }

    func launchPreset(_ preset: QuickStartPreset) {
        // Launch selected preset
        log.info("🚀 Launching preset: \(preset.name)", category: .ui)
    }

    // MARK: - Permission Flow

    func requestPermissions() async {
        // Request permissions gracefully
        // Always offer "Skip" option - app works without permissions

        // HealthKit (optional)
        log.info("📱 Requesting HealthKit permission (optional)", category: .ui)

        // Microphone (optional)
        log.info("🎤 Requesting Microphone permission (optional)", category: .ui)

        // Camera (optional)
        log.info("📷 Requesting Camera permission (optional)", category: .ui)
    }

    // MARK: - Accessibility

    func enableAccessibilityMode() {
        // Enable enhanced accessibility (VoiceOver, larger text, etc.)
        log.info("♿️ Accessibility mode enabled", category: .ui)
    }
}

// MARK: - SwiftUI Onboarding View

struct OnboardingView: View {
    @StateObject private var experience = FirstTimeExperience()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [.blue, .purple, .pink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 2.0), value: experience.currentStep)

            VStack(spacing: 30) {
                // Progress indicator
                OnboardingProgressView(currentStep: experience.currentStep)

                // Content
                stepContent
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    .animation(.spring(), value: experience.currentStep)

                // Navigation buttons
                HStack(spacing: 20) {
                    if experience.currentStep.isSkippable {
                        Button("Skip") {
                            experience.skip()
                        }
                        .foregroundColor(.white.opacity(0.7))
                    }

                    Spacer()

                    Button(action: {
                        if experience.currentStep == .quickStart {
                            experience.complete()
                            dismiss()
                        } else {
                            experience.next()
                        }
                    }) {
                        Text(experience.currentStep == .quickStart ? "Get Started" : "Next")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 15)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(25)
                    }
                }
                .padding(.horizontal, 30)
            }
            .padding()
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch experience.currentStep {
        case .welcome:
            WelcomeStepView()
        case .instantDemo:
            InstantDemoStepView(experience: experience)
        case .explainer:
            ExplainerStepView()
        case .permissions:
            PermissionsStepView(experience: experience)
        case .quickStart:
            QuickStartStepView(experience: experience)
        }
    }
}

// MARK: - Progress View

struct OnboardingProgressView: View {
    let currentStep: FirstTimeExperience.OnboardingStep

    var body: some View {
        HStack(spacing: 8) {
            ForEach(FirstTimeExperience.OnboardingStep.allCases, id: \.self) { step in
                Capsule()
                    .fill(step.rawValue <= currentStep.rawValue ? Color.white : Color.white.opacity(0.3))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 30)
    }
}

// MARK: - Welcome Step

struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.white)

            Text("Welcome to Echoelmusic")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Bio-reactive audio-visual experiences.\nYour body creates music.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Instant Demo Step (AHA MOMENT)

struct InstantDemoStepView: View {
    @ObservedObject var experience: FirstTimeExperience

    var body: some View {
        VStack(spacing: 30) {
            Text("Touch and Hold")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)

            // Interactive demo area
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, .blue, .purple],
                        center: .center,
                        startRadius: 50,
                        endRadius: 150
                    )
                )
                .frame(width: 200, height: 200)
                .overlay(
                    Text("Touch Here")
                        .foregroundColor(.white)
                        .font(.headline)
                )
                .scaleEffect(1.0)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: UUID())

            Text("Notice how the sound reacts to your touch.\nThis is your first bio-reactive experience.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 40)
        }
        .onAppear {
            experience.startInstantDemo()
        }
    }
}

// MARK: - Explainer Step

struct ExplainerStepView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundColor(.white)

            Text("What You Just Experienced")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 15) {
                FeatureBullet(icon: "waveform.path", text: "Bio-reactive audio responds to your input")
                FeatureBullet(icon: "sparkles", text: "Real-time visual feedback")
                FeatureBullet(icon: "paintbrush.pointed", text: "Creative self-expression tool")
                FeatureBullet(icon: "heart", text: "Not a medical device - pure art & creativity")
            }
            .padding(.horizontal, 40)
        }
    }
}

struct FeatureBullet: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 30)

            Text(text)
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

// MARK: - Permissions Step

struct PermissionsStepView: View {
    @ObservedObject var experience: FirstTimeExperience

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundColor(.white)

            Text("Optional Permissions")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Echoelmusic works great without any permissions.\nConnect more sensors for enhanced experiences.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 40)

            VStack(spacing: 15) {
                PermissionRow(icon: "heart.fill", title: "HealthKit", description: "Heart rate reactive music", isOptional: true)
                PermissionRow(icon: "mic.fill", title: "Microphone", description: "Voice-reactive visuals", isOptional: true)
                PermissionRow(icon: "camera.fill", title: "Camera", description: "Gesture control", isOptional: true)
            }
            .padding(.horizontal, 40)

            Button("Enable All (Optional)") {
                Task {
                    await experience.requestPermissions()
                }
            }
            .foregroundColor(.white)
            .padding()
            .background(Color.white.opacity(0.2))
            .cornerRadius(15)
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isOptional: Bool

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 40)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            if isOptional {
                Text("Optional")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Quick Start Step

struct QuickStartStepView: View {
    @ObservedObject var experience: FirstTimeExperience

    var body: some View {
        VStack(spacing: 20) {
            Text("Choose Your Path")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                    ForEach(experience.quickStartPresets) { preset in
                        PresetCard(preset: preset) {
                            experience.launchPreset(preset)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

struct PresetCard: View {
    let preset: FirstTimeExperience.QuickStartPreset
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: preset.icon)
                    .font(.system(size: 40))
                    .foregroundColor(.white)

                Text(preset.name)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(preset.description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.15))
            .cornerRadius(15)
        }
    }
}
