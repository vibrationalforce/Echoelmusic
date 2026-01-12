// SPDX-License-Identifier: MIT
// Copyright 2026 Echoelmusic

import Foundation
import SwiftUI
import Combine

// MARK: - Easter Egg Manager
/// Manages hidden features unlocked through special gestures, codes, or achievements
@MainActor
public final class EasterEggManager: ObservableObject {

    public static let shared = EasterEggManager()

    // MARK: - Easter Egg Features

    public enum EasterEgg: String, CaseIterable, Identifiable {
        case longevityNutrition = "longevity"
        case wellnessTracking = "wellness"
        case neuroSpiritual = "consciousness"
        case circadianRhythm = "circadian"
        case quantumHealth = "quantum_health"
        case adeyWindows = "bioelectromagnetic"
        case lifestyleCoach = "lifestyle"
        case astronautHealth = "astronaut"
        case socialHealth = "social_coherence"

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .longevityNutrition: return "Longevity Lab"
            case .wellnessTracking: return "Wellness Studio"
            case .neuroSpiritual: return "Consciousness Explorer"
            case .circadianRhythm: return "Circadian Flow"
            case .quantumHealth: return "Quantum Coherence"
            case .adeyWindows: return "Biofield Science"
            case .lifestyleCoach: return "Life Harmony"
            case .astronautHealth: return "Space Vitals"
            case .socialHealth: return "Collective Heart"
            }
        }

        public var icon: String {
            switch self {
            case .longevityNutrition: return "leaf.fill"
            case .wellnessTracking: return "heart.text.square.fill"
            case .neuroSpiritual: return "brain.head.profile"
            case .circadianRhythm: return "sun.and.horizon.fill"
            case .quantumHealth: return "atom"
            case .adeyWindows: return "waveform.path.ecg"
            case .lifestyleCoach: return "figure.mind.and.body"
            case .astronautHealth: return "airplane.circle.fill"
            case .socialHealth: return "person.3.fill"
            }
        }

        public var unlockCode: String {
            switch self {
            case .longevityNutrition: return "BLUEZONE"
            case .wellnessTracking: return "BREATHE"
            case .neuroSpiritual: return "AWAKEN"
            case .circadianRhythm: return "SUNRISE"
            case .quantumHealth: return "ENTANGLE"
            case .adeyWindows: return "FREQUENCY"
            case .lifestyleCoach: return "BALANCE"
            case .astronautHealth: return "ORBIT"
            case .socialHealth: return "TOGETHER"
            }
        }

        public var coherenceThreshold: Double {
            switch self {
            case .longevityNutrition: return 0.85
            case .wellnessTracking: return 0.60
            case .neuroSpiritual: return 0.90
            case .circadianRhythm: return 0.70
            case .quantumHealth: return 0.95
            case .adeyWindows: return 0.88
            case .lifestyleCoach: return 0.65
            case .astronautHealth: return 0.92
            case .socialHealth: return 0.80
            }
        }

        public var description: String {
            switch self {
            case .longevityNutrition:
                return "Blue Zones research, 9 Hallmarks of Aging, 15+ longevity compounds"
            case .wellnessTracking:
                return "25+ wellness categories, 6 breathing patterns, guided meditations"
            case .neuroSpiritual:
                return "10 consciousness states, Polyvagal theory, FACS expression mapping"
            case .circadianRhythm:
                return "Chronotype optimization, sleep cycles, biological timing"
            case .quantumHealth:
                return "Unlimited collaboration, 8 session types, quantum-inspired metrics"
            case .adeyWindows:
                return "Dr. Adey's research, frequency-body mapping, scientific windows"
            case .lifestyleCoach:
                return "Holistic wellness coaching, personalized recommendations"
            case .astronautHealth:
                return "Space medicine protocols, extreme environment adaptation"
            case .socialHealth:
                return "Group coherence, collective heart synchronization"
            }
        }
    }

    // MARK: - Unlock State

    @Published public private(set) var unlockedEggs: Set<EasterEgg> = []
    @Published public private(set) var discoveryProgress: [EasterEgg: Double] = [:]
    @Published public var showUnlockAnimation: Bool = false
    @Published public var lastUnlockedEgg: EasterEgg?

    private let storageKey = "echoelmusic.easter_eggs.unlocked"
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Unlock Methods

    private init() {
        loadUnlockedEggs()
    }

    /// Unlock with secret code
    public func tryUnlock(code: String) -> EasterEgg? {
        let normalizedCode = code.uppercased().trimmingCharacters(in: .whitespaces)

        for egg in EasterEgg.allCases {
            if egg.unlockCode == normalizedCode && !unlockedEggs.contains(egg) {
                unlock(egg)
                return egg
            }
        }
        return nil
    }

    /// Unlock through coherence achievement
    public func checkCoherenceUnlock(coherence: Double, duration: TimeInterval) {
        for egg in EasterEgg.allCases where !unlockedEggs.contains(egg) {
            if coherence >= egg.coherenceThreshold && duration >= 60 {
                // Update progress
                let currentProgress = discoveryProgress[egg] ?? 0
                let newProgress = min(1.0, currentProgress + 0.1)
                discoveryProgress[egg] = newProgress

                // Unlock at 100% progress
                if newProgress >= 1.0 {
                    unlock(egg)
                }
            }
        }
    }

    /// Special gesture unlock (e.g., heart shape with hands)
    public func gestureUnlock(_ gesture: String) {
        switch gesture {
        case "heart_shape":
            if !unlockedEggs.contains(.socialHealth) {
                unlock(.socialHealth)
            }
        case "meditation_pose":
            if !unlockedEggs.contains(.neuroSpiritual) {
                unlock(.neuroSpiritual)
            }
        case "sunrise_gesture":
            if !unlockedEggs.contains(.circadianRhythm) {
                unlock(.circadianRhythm)
            }
        case "quantum_wave":
            if !unlockedEggs.contains(.quantumHealth) {
                unlock(.quantumHealth)
            }
        default:
            break
        }
    }

    /// Direct unlock (for testing/admin)
    public func unlock(_ egg: EasterEgg) {
        guard !unlockedEggs.contains(egg) else { return }

        unlockedEggs.insert(egg)
        lastUnlockedEgg = egg
        showUnlockAnimation = true
        saveUnlockedEggs()

        // Haptic feedback
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif

        // Reset animation after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.showUnlockAnimation = false
        }
    }

    /// Unlock all (master code)
    public func unlockAll(masterCode: String) -> Bool {
        if masterCode == "ECHOELMASTER2026" || masterCode == "LAMBDAINFINITY" {
            EasterEgg.allCases.forEach { unlock($0) }
            return true
        }
        return false
    }

    // MARK: - Feature Access

    public func isUnlocked(_ egg: EasterEgg) -> Bool {
        unlockedEggs.contains(egg)
    }

    public var totalUnlocked: Int {
        unlockedEggs.count
    }

    public var totalEggs: Int {
        EasterEgg.allCases.count
    }

    public var completionPercentage: Double {
        Double(totalUnlocked) / Double(totalEggs) * 100
    }

    // MARK: - Persistence

    private func loadUnlockedEggs() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            unlockedEggs = Set(decoded.compactMap { EasterEgg(rawValue: $0) })
        }
    }

    private func saveUnlockedEggs() {
        let rawValues = unlockedEggs.map { $0.rawValue }
        if let data = try? JSONEncoder().encode(rawValues) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    /// Reset all progress (for testing)
    public func resetAll() {
        unlockedEggs.removeAll()
        discoveryProgress.removeAll()
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}

// MARK: - Easter Egg View

public struct EasterEggGalleryView: View {
    @ObservedObject private var manager = EasterEggManager.shared
    @State private var secretCode: String = ""
    @State private var showCodeInput: Bool = false
    @State private var tapCount: Int = 0

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Progress Header
                    progressHeader

                    // Easter Eggs Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(EasterEggManager.EasterEgg.allCases) { egg in
                            EasterEggCard(egg: egg, isUnlocked: manager.isUnlocked(egg))
                        }
                    }
                    .padding(.horizontal)

                    // Secret Code Input (hidden until 5 taps on header)
                    if showCodeInput {
                        secretCodeInput
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Hidden Features")
            .background(Color(.systemBackground))
        }
        .overlay {
            if manager.showUnlockAnimation, let egg = manager.lastUnlockedEgg {
                UnlockAnimationView(egg: egg)
            }
        }
    }

    private var progressHeader: some View {
        VStack(spacing: 8) {
            Text("\(manager.totalUnlocked) / \(manager.totalEggs)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text("Features Discovered")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ProgressView(value: manager.completionPercentage, total: 100)
                .tint(.green)
                .padding(.horizontal, 40)
        }
        .padding()
        .onTapGesture {
            tapCount += 1
            if tapCount >= 5 {
                withAnimation {
                    showCodeInput = true
                }
            }
        }
    }

    private var secretCodeInput: some View {
        VStack(spacing: 12) {
            TextField("Enter secret code...", text: $secretCode)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.characters)
                .padding(.horizontal)

            Button("Unlock") {
                if let egg = manager.tryUnlock(code: secretCode) {
                    secretCode = ""
                } else if manager.unlockAll(masterCode: secretCode) {
                    secretCode = ""
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding()
    }
}

// MARK: - Easter Egg Card

struct EasterEggCard: View {
    let egg: EasterEggManager.EasterEgg
    let isUnlocked: Bool

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 60, height: 60)

                Image(systemName: isUnlocked ? egg.icon : "lock.fill")
                    .font(.title2)
                    .foregroundStyle(isUnlocked ? .green : .gray)
            }

            Text(isUnlocked ? egg.displayName : "???")
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundStyle(isUnlocked ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Unlock Animation

struct UnlockAnimationView: View {
    let egg: EasterEggManager.EasterEgg
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: egg.icon)
                    .font(.system(size: 80))
                    .foregroundStyle(.green)

                Text("Unlocked!")
                    .font(.title)
                    .fontWeight(.bold)

                Text(egg.displayName)
                    .font(.title2)
                    .foregroundStyle(.secondary)

                Text(egg.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

// MARK: - Integration with UnifiedControlHub

extension EasterEggManager {

    /// Called from UnifiedControlHub coherence updates
    public func onCoherenceUpdate(coherence: Double, sessionDuration: TimeInterval) {
        checkCoherenceUnlock(coherence: coherence, duration: sessionDuration)
    }

    /// Called from HandTrackingManager gesture detection
    public func onGestureDetected(_ gesture: String) {
        gestureUnlock(gesture)
    }
}
