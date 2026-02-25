//
//  OnboardingFlow.swift
//  Echoelmusic
//
//  Created on 2026-01-07
//  Phase 10000.1 ULTRA MODE - User Onboarding Experience
//

import SwiftUI
#if canImport(HealthKit)
import HealthKit
#endif
import AVFoundation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

// MARK: - Onboarding Manager

/// Manages onboarding state and completion status
@MainActor
public final class OnboardingManager: ObservableObject {
    @Published public var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        }
    }

    @Published public var hasGrantedHealthKit: Bool = false
    @Published public var hasGrantedMicrophone: Bool = false
    @Published public var hasConnectedWatch: Bool = false

    public static let shared = OnboardingManager()

    private init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        checkPermissions()
    }

    /// Check current permission states
    public func checkPermissions() {
        // Check HealthKit authorization
        #if canImport(HealthKit)
        if HKHealthStore.isHealthDataAvailable() {
            let healthStore = HKHealthStore()
            if let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate),
               let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
                hasGrantedHealthKit = healthStore.authorizationStatus(for: heartRateType) == .sharingAuthorized &&
                                     healthStore.authorizationStatus(for: hrvType) == .sharingAuthorized
            }
        }
        #endif

        // Check microphone authorization
        #if os(iOS)
        if #available(iOS 17.0, *) {
            hasGrantedMicrophone = AVAudioApplication.shared.recordPermission == .granted
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted:
                hasGrantedMicrophone = true
            default:
                hasGrantedMicrophone = false
            }
        }
        #endif

        // Check Watch connectivity
        #if canImport(WatchConnectivity)
        if WCSession.isSupported() {
            hasConnectedWatch = WCSession.default.isWatchAppInstalled
        }
        #endif
    }

    /// Mark onboarding as complete
    public func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    /// Reset onboarding (for testing/debugging)
    public func resetOnboarding() {
        hasCompletedOnboarding = false
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
    }
}

// MARK: - Main Onboarding View

/// Main onboarding container with page navigation
public struct OnboardingView: View {
    @StateObject private var manager = OnboardingManager.shared
    @State private var currentPage: Int = 0
    @State private var showMainApp: Bool = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let totalPages = 5

    public init() {}

    public var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            TabView(selection: $currentPage) {
                // Page 0: Welcome
                WelcomePage(currentPage: $currentPage)
                    .tag(0)

                // Page 1: Features
                FeaturesPage(currentPage: $currentPage)
                    .tag(1)

                // Page 2: Permissions
                PermissionsPage(currentPage: $currentPage)
                    .tag(2)

                // Page 3: Watch Setup
                WatchSetupPage(currentPage: $currentPage)
                    .tag(3)

                // Page 4: Ready
                ReadyPage(currentPage: $currentPage, showMainApp: $showMainApp)
                    .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(reduceMotion ? nil : .easeInOut, value: currentPage)

            // Custom page indicators
            VStack {
                Spacer()
                PageIndicators(currentPage: currentPage, totalPages: totalPages)
                    .padding(.bottom, 100)
            }
        }
        .onChange(of: showMainApp) { newValue in
            if newValue {
                manager.completeOnboarding()
                dismiss()
            }
        }
    }
}

// MARK: - Welcome Page

private struct WelcomePage: View {
    @Binding var currentPage: Int

    var body: some View {
        OnboardingPageView(
            title: "Welcome to Echoelmusic",
            description: "Transform your biometrics, voice, and gestures into spatial audio and immersive visuals.",
            illustration: {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.3)],
                                center: .center,
                                startRadius: 20,
                                endRadius: 120
                            )
                        )
                        .frame(width: 240, height: 240)

                    Image(systemName: "waveform.path.ecg.rectangle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .pulseAnimation()
            },
            primaryAction: {
                OnboardingButton(title: "Get Started", icon: "arrow.right") {
                    withAnimation {
                        currentPage = 1
                    }
                    hapticFeedback(.medium)
                }
            }
        )
    }
}

// MARK: - Features Page

private struct FeaturesPage: View {
    @Binding var currentPage: Int

    var body: some View {
        OnboardingPageView(
            title: "Powerful Features",
            description: "Experience bio-reactive audio, real-time visuals, and quantum-inspired sound design.",
            illustration: {
                VStack(spacing: 30) {
                    FeatureRow(
                        icon: "heart.fill",
                        iconColor: .red,
                        title: "Bio-Reactive Audio",
                        description: "Your heart rate and HRV shape the music"
                    )

                    FeatureRow(
                        icon: "speaker.wave.3.fill",
                        iconColor: .blue,
                        title: "Spatial Audio",
                        description: "3D/4D immersive sound fields"
                    )

                    FeatureRow(
                        icon: "sparkles",
                        iconColor: .purple,
                        title: "Quantum Visuals",
                        description: "Real-time photonics visualization"
                    )
                }
                .padding(.horizontal)
            },
            primaryAction: {
                OnboardingButton(title: "Continue", icon: "arrow.right") {
                    withAnimation {
                        currentPage = 2
                    }
                    hapticFeedback(.medium)
                }
            },
            secondaryAction: {
                OnboardingTextButton(title: "Back") {
                    withAnimation {
                        currentPage = 0
                    }
                    hapticFeedback(.light)
                }
            }
        )
    }
}

// MARK: - Permissions Page

private struct PermissionsPage: View {
    @Binding var currentPage: Int
    @StateObject private var manager = OnboardingManager.shared

    var body: some View {
        OnboardingPageView(
            title: "Permissions",
            description: "Echoelmusic needs access to create your bio-reactive experience.",
            illustration: {
                VStack(spacing: 25) {
                    PermissionRequestView(
                        icon: "heart.text.square.fill",
                        title: "HealthKit",
                        description: "Access heart rate and HRV to modulate audio in real-time.",
                        isGranted: manager.hasGrantedHealthKit,
                        onRequest: {
                            requestHealthKitPermission()
                        }
                    )

                    PermissionRequestView(
                        icon: "mic.fill",
                        title: "Microphone",
                        description: "Analyze your voice to create harmonics and vocal effects.",
                        isGranted: manager.hasGrantedMicrophone,
                        onRequest: {
                            requestMicrophonePermission()
                        }
                    )
                }
                .padding(.horizontal)
            },
            primaryAction: {
                OnboardingButton(title: "Continue", icon: "arrow.right") {
                    withAnimation {
                        currentPage = 3
                    }
                    hapticFeedback(.medium)
                }
            },
            secondaryAction: {
                VStack(spacing: 12) {
                    OnboardingTextButton(title: "Skip for Now") {
                        withAnimation {
                            currentPage = 3
                        }
                        hapticFeedback(.light)
                    }

                    OnboardingTextButton(title: "Back") {
                        withAnimation {
                            currentPage = 1
                        }
                        hapticFeedback(.light)
                    }
                }
            }
        )
    }

    private func requestHealthKitPermission() {
        Task {
            let healthStore = HKHealthStore()

            // Build types set safely without force unwraps
            var typesToRead: Set<HKObjectType> = []
            if let hr = HKObjectType.quantityType(forIdentifier: .heartRate) { typesToRead.insert(hr) }
            if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { typesToRead.insert(hrv) }
            if let resp = HKObjectType.quantityType(forIdentifier: .respiratoryRate) { typesToRead.insert(resp) }
            if let spo2 = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) { typesToRead.insert(spo2) }

            guard !typesToRead.isEmpty else {
                log.warning("No HealthKit types available on this device")
                return
            }

            do {
                try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
                await MainActor.run {
                    manager.checkPermissions()
                    hapticFeedback(.success)
                }
            } catch {
                log.error("HealthKit authorization error: \(error)")
                hapticFeedback(.error)
            }
        }
    }

    private func requestMicrophonePermission() {
        #if os(iOS)
        if #available(iOS 17.0, *) {
            Task {
                let granted = await AVAudioApplication.requestRecordPermission()
                await MainActor.run {
                    manager.checkPermissions()
                    AdaptiveCapabilityManager.shared.refresh(.microphone)
                    hapticFeedback(granted ? .success : .error)
                    if granted {
                        try? AudioConfiguration.upgradeToPlayAndRecord()
                    }
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    manager.checkPermissions()
                    AdaptiveCapabilityManager.shared.refresh(.microphone)
                    hapticFeedback(granted ? .success : .error)
                    if granted {
                        try? AudioConfiguration.upgradeToPlayAndRecord()
                    }
                }
            }
        }
        #endif
    }
}

// MARK: - Watch Setup Page

private struct WatchSetupPage: View {
    @Binding var currentPage: Int
    @StateObject private var manager = OnboardingManager.shared

    var body: some View {
        OnboardingPageView(
            title: "Apple Watch",
            description: "Connect your Apple Watch for continuous biometric monitoring.",
            illustration: {
                VStack(spacing: 25) {
                    WatchSetupView(isConnected: manager.hasConnectedWatch)

                    if !manager.hasConnectedWatch {
                        VStack(alignment: .leading, spacing: 12) {
                            InstructionRow(
                                number: 1,
                                text: "Open the Watch app on your iPhone"
                            )
                            InstructionRow(
                                number: 2,
                                text: "Make sure your Watch is paired and nearby"
                            )
                            InstructionRow(
                                number: 3,
                                text: "Install Echoelmusic from the App Store"
                            )
                        }
                        .padding(.horizontal)
                    }
                }
            },
            primaryAction: {
                OnboardingButton(
                    title: manager.hasConnectedWatch ? "Continue" : "Check Connection",
                    icon: manager.hasConnectedWatch ? "arrow.right" : "arrow.clockwise"
                ) {
                    if manager.hasConnectedWatch {
                        withAnimation {
                            currentPage = 4
                        }
                        hapticFeedback(.medium)
                    } else {
                        manager.checkPermissions()
                        hapticFeedback(.light)
                    }
                }
            },
            secondaryAction: {
                VStack(spacing: 12) {
                    OnboardingTextButton(title: "Setup Later") {
                        withAnimation {
                            currentPage = 4
                        }
                        hapticFeedback(.light)
                    }

                    OnboardingTextButton(title: "Back") {
                        withAnimation {
                            currentPage = 2
                        }
                        hapticFeedback(.light)
                    }
                }
            }
        )
    }
}

// MARK: - Ready Page

private struct ReadyPage: View {
    @Binding var currentPage: Int
    @Binding var showMainApp: Bool

    var body: some View {
        OnboardingPageView(
            title: "You're All Set!",
            description: "Ready to transform your biometrics into art. Let's begin your journey.",
            illustration: {
                ZStack {
                    ForEach(0..<3) { index in
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.green.opacity(0.6), Color.blue.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 100 + CGFloat(index * 50), height: 100 + CGFloat(index * 50))
                            .scaleEffect(CGFloat(index) * 0.3 + 1.0)
                    }
                    .rippleAnimation()

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            },
            primaryAction: {
                OnboardingButton(title: "Start Creating", icon: "play.fill") {
                    hapticFeedback(.success)
                    withAnimation {
                        showMainApp = true
                    }
                }
                .scaleEffect(1.1)
            },
            secondaryAction: {
                OnboardingTextButton(title: "Back") {
                    withAnimation {
                        currentPage = 3
                    }
                    hapticFeedback(.light)
                }
            }
        )
    }
}

// MARK: - Reusable Components

/// Reusable onboarding page layout
private struct OnboardingPageView<Illustration: View, PrimaryAction: View, SecondaryAction: View>: View {
    let title: String
    let description: String
    @ViewBuilder let illustration: () -> Illustration
    @ViewBuilder let primaryAction: () -> PrimaryAction
    @ViewBuilder let secondaryAction: () -> SecondaryAction

    init(
        title: String,
        description: String,
        @ViewBuilder illustration: @escaping () -> Illustration,
        @ViewBuilder primaryAction: @escaping () -> PrimaryAction,
        @ViewBuilder secondaryAction: @escaping () -> SecondaryAction = { EmptyView() }
    ) {
        self.title = title
        self.description = description
        self.illustration = illustration
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
    }

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Illustration
            illustration()
                .frame(maxHeight: 300)

            Spacer()

            // Text content
            VStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)

                Text(description)
                    .font(.system(size: 17, weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 32)
            }

            Spacer()

            // Actions
            VStack(spacing: 16) {
                primaryAction()
                secondaryAction()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 50)
        }
        .accessibilityElement(children: .contain)
    }
}

/// Feature row component
private struct FeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(iconColor)
                .frame(width: 50, height: 50)
                .background(iconColor.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)

                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

/// Permission request component
private struct PermissionRequestView: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let onRequest: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(isGranted ? .green : .blue)
                    .frame(width: 50, height: 50)
                    .background((isGranted ? Color.green : Color.blue).opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            if !isGranted {
                Button(action: onRequest) {
                    Text("Allow Access")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityLabel("Allow \(title) access")
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Granted")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.green.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("\(title) access granted")
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// Watch setup status view
private struct WatchSetupView: View {
    let isConnected: Bool

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(isConnected ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: "applewatch")
                    .font(.system(size: 50))
                    .foregroundColor(isConnected ? .green : .gray)

                if isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.green)
                        .offset(x: 35, y: 35)
                }
            }

            VStack(spacing: 8) {
                Text(isConnected ? "Watch Connected" : "Watch Not Found")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)

                Text(isConnected ? "You're ready to track biometrics" : "Follow the steps below to connect")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isConnected ? "Apple Watch connected" : "Apple Watch not connected")
    }
}

/// Instruction row
private struct InstructionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color.blue)
                .clipShape(Circle())

            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.secondary)

            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

/// Primary button
private struct OnboardingButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                Image(systemName: icon)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: [Color.blue, Color.purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .accessibilityLabel(title)
        .accessibilityHint("Double tap to continue")
    }
}

/// Text button
private struct OnboardingTextButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }
        .accessibilityLabel(title)
    }
}

/// Page indicators
private struct PageIndicators: View {
    let currentPage: Int
    let totalPages: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                Circle()
                    .fill(currentPage == index ? Color.primary : Color.secondary.opacity(0.4))
                    .frame(width: currentPage == index ? 10 : 8, height: currentPage == index ? 10 : 8)
                    .animation(.spring(response: 0.3), value: currentPage)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(currentPage + 1) of \(totalPages)")
    }
}

// MARK: - Animations

private extension View {
    func pulseAnimation() -> some View {
        modifier(PulseAnimationModifier())
    }

    func rippleAnimation() -> some View {
        modifier(RippleAnimationModifier())
    }
}

private struct PulseAnimationModifier: ViewModifier {
    @State private var isPulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing && !reduceMotion ? 1.05 : 1.0)
            .animation(reduceMotion ? nil : .easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear {
                if !reduceMotion { isPulsing = true }
            }
    }
}

private struct RippleAnimationModifier: ViewModifier {
    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating && !reduceMotion ? 1.2 : 1.0)
            .opacity(isAnimating && !reduceMotion ? 0.5 : 1.0)
            .animation(reduceMotion ? nil : .easeOut(duration: 2.0).repeatForever(autoreverses: false), value: isAnimating)
            .onAppear {
                if !reduceMotion { isAnimating = true }
            }
    }
}

// MARK: - Haptic Feedback

#if canImport(UIKit) && !os(watchOS) && !os(tvOS) && !os(visionOS)
private func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
    let generator = UIImpactFeedbackGenerator(style: style)
    generator.prepare()
    generator.impactOccurred()
}

private func hapticFeedback(_ type: UINotificationFeedbackGenerator.FeedbackType) {
    let generator = UINotificationFeedbackGenerator()
    generator.prepare()
    generator.notificationOccurred(type)
}
#else
// No-op stubs for macOS/watchOS/tvOS — matches call-site enum values
private enum FallbackImpactStyle { case light, medium, heavy, rigid, soft }
private enum FallbackNotificationType { case success, error, warning }
private func hapticFeedback(_ style: FallbackImpactStyle) {}
private func hapticFeedback(_ type: FallbackNotificationType) {}
#endif

// MARK: - Preview

#if DEBUG
struct OnboardingFlow_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            OnboardingView()
                .preferredColorScheme(.light)

            OnboardingView()
                .preferredColorScheme(.dark)
        }
    }
}
#endif
