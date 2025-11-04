import SwiftUI
import AVFoundation
import HealthKit

/// Onboarding Wizard
///
/// First-time user experience guiding users through:
/// - Welcome & feature overview
/// - Microphone permission
/// - HealthKit permission (optional)
/// - Basic setup
/// - Quick tour
///
/// Usage:
/// ```swift
/// @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "onboarding_completed")
///
/// .sheet(isPresented: $showOnboarding) {
///     OnboardingView(controlHub: hub, audioEngine: engine)
/// }
/// ```
@available(iOS 15.0, *)
struct OnboardingView: View {

    @ObservedObject var controlHub: UnifiedControlHub
    @ObservedObject var audioEngine: AudioEngine

    @State private var currentStep: OnboardingStep = .welcome
    @State private var microphonePermissionGranted = false
    @State private var healthKitPermissionGranted = false

    @Environment(\.dismiss) var dismiss

    enum OnboardingStep: Int, CaseIterable {
        case welcome = 0
        case features = 1
        case permissions = 2
        case audioSetup = 3
        case tour = 4
        case complete = 5

        var title: String {
            switch self {
            case .welcome: return "Welcome to BLAB"
            case .features: return "What BLAB Can Do"
            case .permissions: return "Permissions"
            case .audioSetup: return "Audio Setup"
            case .tour: return "Quick Tour"
            case .complete: return "You're All Set!"
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress indicator
                progressBar

                // Content
                TabView(selection: $currentStep) {
                    welcomeStep.tag(OnboardingStep.welcome)
                    featuresStep.tag(OnboardingStep.features)
                    permissionsStep.tag(OnboardingStep.permissions)
                    audioSetupStep.tag(OnboardingStep.audioSetup)
                    tourStep.tag(OnboardingStep.tour)
                    completeStep.tag(OnboardingStep.complete)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Navigation buttons
                navigationButtons
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(step.rawValue <= currentStep.rawValue ? Color.blue : Color.gray.opacity(0.3))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal)

            Text(currentStep.title)
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
        }
        .padding(.top, 20)
    }

    // MARK: - Welcome Step

    private var welcomeStep: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 100))
                .foregroundColor(.blue)

            VStack(spacing: 12) {
                Text("Welcome to BLAB")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Professional Audio Control")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            Text("Transform your iOS device into a powerful audio processing and streaming hub")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Features Step

    private var featuresStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("What BLAB Can Do")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top, 20)

                featureCard(
                    icon: "antenna.radiowaves.left.and.right",
                    title: "NDI Audio Streaming",
                    description: "Stream audio to DAWs, OBS, vMix, and other NDI devices on your network",
                    color: .blue
                )

                featureCard(
                    icon: "dot.radiowaves.up.forward",
                    title: "Live Broadcasting",
                    description: "Go live on YouTube, Twitch, and Facebook with professional audio quality",
                    color: .red
                )

                featureCard(
                    icon: "slider.horizontal.3",
                    title: "Advanced DSP",
                    description: "Noise gate, de-esser, compressor, and limiter for pristine audio",
                    color: .purple
                )

                featureCard(
                    icon: "move.3d",
                    title: "Spatial Audio",
                    description: "3D/4D audio with head tracking for immersive experiences",
                    color: .green
                )

                featureCard(
                    icon: "heart.text.square",
                    title: "Biometric Integration",
                    description: "HRV and heart rate reactive audio for healing and meditation",
                    color: .pink
                )

                featureCard(
                    icon: "pianokeys",
                    title: "MIDI 2.0 & MPE",
                    description: "Next-gen MIDI control with 32-bit resolution and 15-voice polyphony",
                    color: .orange
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private func featureCard(icon: String, title: String, description: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }

    // MARK: - Permissions Step

    private var permissionsStep: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            VStack(spacing: 12) {
                Text("Permissions")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("BLAB needs a few permissions to work properly")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            VStack(spacing: 16) {
                permissionRow(
                    icon: "mic.fill",
                    title: "Microphone",
                    description: "Required for audio capture",
                    granted: microphonePermissionGranted,
                    required: true
                ) {
                    requestMicrophonePermission()
                }

                permissionRow(
                    icon: "heart.fill",
                    title: "HealthKit",
                    description: "Optional for biometric features",
                    granted: healthKitPermissionGranted,
                    required: false
                ) {
                    requestHealthKitPermission()
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private func permissionRow(icon: String, title: String, description: String, granted: Bool, required: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(granted ? .green : .gray)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(.headline)

                    if required {
                        Text("Required")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.red))
                    }
                }

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button("Grant") {
                    action()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
        )
    }

    // MARK: - Audio Setup Step

    private var audioSetupStep: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "waveform.path")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            VStack(spacing: 12) {
                Text("Audio Setup")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Choose your audio quality preset")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                audioPresetButton(
                    title: "Low Latency",
                    description: "< 3ms latency, ideal for live performance",
                    icon: "bolt.fill",
                    color: .orange
                ) {
                    // Apply low latency preset
                }

                audioPresetButton(
                    title: "Balanced",
                    description: "Best quality/latency balance (recommended)",
                    icon: "equal.circle.fill",
                    color: .blue
                ) {
                    // Apply balanced preset
                }

                audioPresetButton(
                    title: "High Quality",
                    description: "Studio quality, higher latency",
                    icon: "crown.fill",
                    color: .purple
                ) {
                    // Apply high quality preset
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private func audioPresetButton(title: String, description: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.1))
            )
        }
    }

    // MARK: - Tour Step

    private var tourStep: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "map.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            VStack(spacing: 12) {
                Text("Quick Tour")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Navigate BLAB like a pro")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 16) {
                tourItem(
                    icon: "house.fill",
                    title: "Home",
                    description: "Quick controls and system status"
                )

                tourItem(
                    icon: "waveform.path",
                    title: "Perform",
                    description: "DSP controls and audio effects"
                )

                tourItem(
                    icon: "dot.radiowaves.up.forward",
                    title: "Stream",
                    description: "NDI and RTMP live streaming"
                )

                tourItem(
                    icon: "gearshape.fill",
                    title: "Settings",
                    description: "Full configuration and preferences"
                )
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private func tourItem(icon: String, title: String, description: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
        )
    }

    // MARK: - Complete Step

    private var completeStep: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 100))
                .foregroundColor(.green)

            VStack(spacing: 12) {
                Text("You're All Set!")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Ready to create amazing audio")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Microphone configured")
                }

                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Audio quality optimized")
                }

                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Ready to stream")
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)

            Spacer()
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack {
            if currentStep != .welcome {
                Button("Back") {
                    withAnimation {
                        moveToPreviousStep()
                    }
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            if currentStep == .complete {
                Button("Get Started") {
                    completeOnboarding()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(currentStep == .permissions && !microphonePermissionGranted ? "Skip" : "Next") {
                    withAnimation {
                        moveToNextStep()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(currentStep == .permissions && !canProceedFromPermissions)
            }
        }
        .padding()
    }

    // MARK: - Navigation Logic

    private func moveToNextStep() {
        guard let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = nextStep
    }

    private func moveToPreviousStep() {
        guard let previousStep = OnboardingStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = previousStep
    }

    private var canProceedFromPermissions: Bool {
        // Require microphone permission
        return microphonePermissionGranted
    }

    // MARK: - Permission Requests

    private func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                self.microphonePermissionGranted = granted
                if granted {
                    print("[Onboarding] ✅ Microphone permission granted")
                } else {
                    print("[Onboarding] ❌ Microphone permission denied")
                }
            }
        }
    }

    private func requestHealthKitPermission() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("[Onboarding] ⚠️ HealthKit not available on this device")
            healthKitPermissionGranted = false
            return
        }

        let healthStore = HKHealthStore()
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        ]

        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                self.healthKitPermissionGranted = success
                if success {
                    print("[Onboarding] ✅ HealthKit permission granted")
                } else {
                    print("[Onboarding] ⚠️ HealthKit permission denied or error: \(error?.localizedDescription ?? "unknown")")
                }
            }
        }
    }

    // MARK: - Completion

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "onboarding_completed")
        dismiss()
    }
}

// MARK: - Preview

@available(iOS 15.0, *)
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(
            controlHub: UnifiedControlHub(),
            audioEngine: AudioEngine(microphoneManager: MicrophoneManager())
        )
    }
}
