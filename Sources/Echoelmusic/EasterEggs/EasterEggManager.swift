// SPDX-License-Identifier: MIT
// Copyright 2026 Echoelmusic

import Foundation
import SwiftUI
import Combine

// MARK: - Easter Egg Manager
/// Manages the hidden NeuroPsychoImmunoBody feature
/// Unlocked through coherence achievement, secret codes, or special gestures
@MainActor
public final class EasterEggManager: ObservableObject {

    public static let shared = EasterEggManager()

    // MARK: - The Easter Egg

    /// Single unified Easter Egg: NeuroPsychoImmunoBody Tool
    /// Combines all wellness, longevity, and body health research
    public struct NeuroBodyEasterEgg {
        public static let name = "NeuroBody"
        public static let fullName = "NeuroPsychoImmunoBody"
        public static let icon = "heart.text.square.fill"

        public static let description = """
        Ganzheitliches Gesundheitstool basierend auf Psychoneuroimmunologie:

        🧠 Neuroplastizität & Gehirngesundheit
        🛡️ Immunsystem & Entzündungsregulation
        💪 Muskel-, Organ- & Knochengesundheit
        🔄 Regeneration & Zellreparatur
        ⏰ Circadiane Rhythmen & Chronobiologie
        🧬 Langlebigkeit & Blue Zones Forschung
        🌊 Polyvagal-Theorie & Vagusnerv
        ❤️ HRV-basierte Gesundheitsoptimierung
        """

        public static let unlockCodes = [
            "NEUROBODY",
            "PSYCHONEUROIMMUNO",
            "HOLISTICHEALTH",
            "BODYMIND",
            "ECHOELHEALTH"
        ]

        public static let coherenceThreshold: Double = 0.80
        public static let coherenceDuration: TimeInterval = 120 // 2 minutes

        public static let gestureUnlocks = [
            "heart_coherence",    // Heart-focused breathing gesture
            "body_scan",          // Full body awareness gesture
            "healing_hands"       // Hands over heart gesture
        ]
    }

    // MARK: - Unlock State

    @Published public private(set) var isUnlocked: Bool = false
    @Published public private(set) var discoveryProgress: Double = 0.0
    @Published public var showUnlockAnimation: Bool = false
    @Published public private(set) var coherenceStreak: TimeInterval = 0
    @Published public private(set) var unlockMethod: String?

    private let storageKey = "echoelmusic.neurobody.unlocked"
    private var highCoherenceStartTime: Date?

    // MARK: - Initialization

    private init() {
        loadUnlockState()
    }

    // MARK: - Unlock Methods

    /// Try unlock with secret code
    public func tryUnlock(code: String) -> Bool {
        let normalizedCode = code.uppercased().trimmingCharacters(in: .whitespaces)

        if NeuroBodyEasterEgg.unlockCodes.contains(normalizedCode) && !isUnlocked {
            unlock(method: "Code: \(normalizedCode)")
            return true
        }
        return false
    }

    /// Check coherence-based unlock (called from UnifiedControlHub)
    public func checkCoherenceUnlock(coherence: Double, duration: TimeInterval) {
        guard !isUnlocked else { return }

        if coherence >= NeuroBodyEasterEgg.coherenceThreshold {
            if highCoherenceStartTime == nil {
                highCoherenceStartTime = Date()
            }

            let streak = Date().timeIntervalSince(highCoherenceStartTime!)
            coherenceStreak = streak

            // Update progress
            discoveryProgress = min(1.0, streak / NeuroBodyEasterEgg.coherenceDuration)

            // Unlock when threshold duration reached
            if streak >= NeuroBodyEasterEgg.coherenceDuration {
                unlock(method: "Kohärenz \(Int(coherence * 100))% für \(Int(streak))s")
            }
        } else {
            // Reset streak if coherence drops
            highCoherenceStartTime = nil
            coherenceStreak = 0
            // Keep some progress as encouragement
            discoveryProgress = max(0, discoveryProgress - 0.01)
        }
    }

    /// Gesture-based unlock
    public func gestureUnlock(_ gesture: String) {
        guard !isUnlocked else { return }

        if NeuroBodyEasterEgg.gestureUnlocks.contains(gesture) {
            // Gesture adds progress
            discoveryProgress = min(1.0, discoveryProgress + 0.2)

            if discoveryProgress >= 1.0 {
                unlock(method: "Geste: \(gesture)")
            }
        }
    }

    /// Direct unlock (for testing/admin)
    public func unlock(method: String = "Direct") {
        guard !isUnlocked else { return }

        isUnlocked = true
        unlockMethod = method
        showUnlockAnimation = true
        discoveryProgress = 1.0
        saveUnlockState()

        // Haptic feedback
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif

        // Reset animation after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            self?.showUnlockAnimation = false
        }
    }

    /// Master unlock (developer)
    public func masterUnlock(_ code: String) -> Bool {
        if code == "ECHOELMASTER2026" || code == "LAMBDAINFINITY" || code == "NEUROBODYUNLOCK" {
            unlock(method: "Master Code")
            return true
        }
        return false
    }

    // MARK: - Persistence

    private func loadUnlockState() {
        isUnlocked = UserDefaults.standard.bool(forKey: storageKey)
        if isUnlocked {
            discoveryProgress = 1.0
        }
    }

    private func saveUnlockState() {
        UserDefaults.standard.set(isUnlocked, forKey: storageKey)
    }

    /// Reset (for testing)
    public func reset() {
        isUnlocked = false
        discoveryProgress = 0
        coherenceStreak = 0
        highCoherenceStartTime = nil
        unlockMethod = nil
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    // MARK: - Integration Helpers

    /// Called from UnifiedControlHub
    public func onCoherenceUpdate(coherence: Double, sessionDuration: TimeInterval) {
        checkCoherenceUnlock(coherence: coherence, duration: sessionDuration)

        // Also update the NeuroPsychoImmunoBody engine if unlocked
        if isUnlocked {
            NeuroPsychoImmunoBodyEngine.shared.updateCoherence(coherence, duration: sessionDuration)
        }
    }

    /// Called from gesture detection
    public func onGestureDetected(_ gesture: String) {
        gestureUnlock(gesture)
    }
}

// MARK: - Easter Egg Discovery View

public struct EasterEggDiscoveryView: View {
    @ObservedObject private var manager = EasterEggManager.shared
    @State private var secretCode: String = ""
    @State private var showCodeInput: Bool = false
    @State private var tapCount: Int = 0

    public init() {}

    public var body: some View {
        Group {
            if manager.isUnlocked {
                // Show the full NeuroPsychoImmunoBody tool
                NeuroPsychoImmunoBodyView()
            } else {
                // Show discovery/unlock UI
                discoveryView
            }
        }
        .overlay {
            if manager.showUnlockAnimation {
                unlockAnimation
            }
        }
    }

    private var discoveryView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Mystery Icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 120, height: 120)

                Circle()
                    .stroke(Color.green.opacity(0.3), lineWidth: 2)
                    .frame(width: 140, height: 140)

                Image(systemName: manager.discoveryProgress > 0.5 ? "heart.text.square" : "lock.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(manager.discoveryProgress > 0.5 ? .green : .gray)
            }
            .onTapGesture {
                tapCount += 1
                if tapCount >= 7 {
                    withAnimation { showCodeInput = true }
                }
            }

            // Title
            VStack(spacing: 8) {
                Text(manager.discoveryProgress > 0.5 ? "NeuroBody" : "Versteckte Funktion")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Entdecke das ganzheitliche Gesundheitstool")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Progress
            VStack(spacing: 12) {
                ProgressView(value: manager.discoveryProgress)
                    .tint(.green)
                    .padding(.horizontal, 40)

                Text("\(Int(manager.discoveryProgress * 100))% entdeckt")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if manager.coherenceStreak > 0 {
                    Text("Kohärenz: \(Int(manager.coherenceStreak))s / \(Int(EasterEggManager.NeuroBodyEasterEgg.coherenceDuration))s")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }

            // Hints
            VStack(alignment: .leading, spacing: 8) {
                hintRow(icon: "heart.fill", text: "Erreiche 80% Kohärenz für 2 Minuten", unlocked: manager.discoveryProgress >= 0.3)
                hintRow(icon: "hand.raised.fill", text: "Spezielle Geste ausführen", unlocked: manager.discoveryProgress >= 0.6)
                hintRow(icon: "key.fill", text: "Oder finde den Geheimcode...", unlocked: manager.discoveryProgress >= 0.9)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .padding(.horizontal)

            // Secret code input (hidden until 7 taps)
            if showCodeInput {
                VStack(spacing: 12) {
                    TextField("Geheimcode...", text: $secretCode)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.characters)

                    Button("Freischalten") {
                        if manager.tryUnlock(code: secretCode) || manager.masterUnlock(secretCode) {
                            secretCode = ""
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                .padding()
            }

            Spacer()
        }
        .padding()
    }

    private func hintRow(icon: String, text: String, unlocked: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: unlocked ? "checkmark.circle.fill" : icon)
                .foregroundStyle(unlocked ? .green : .gray)

            Text(text)
                .font(.caption)
                .foregroundStyle(unlocked ? .primary : .secondary)

            Spacer()
        }
    }

    private var unlockAnimation: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(.green)
                    .symbolEffect(.pulse)

                Text("Freigeschaltet!")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("NeuroBody")
                    .font(.title2)
                    .foregroundStyle(.green)

                Text(EasterEggManager.NeuroBodyEasterEgg.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if let method = manager.unlockMethod {
                    Text("Methode: \(method)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Compact Easter Egg Button (for main UI)

public struct EasterEggButton: View {
    @ObservedObject private var manager = EasterEggManager.shared
    @State private var showSheet = false

    public init() {}

    public var body: some View {
        Button {
            showSheet = true
        } label: {
            ZStack {
                Circle()
                    .fill(manager.isUnlocked ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: manager.isUnlocked ? "heart.text.square.fill" : "sparkles")
                    .foregroundStyle(manager.isUnlocked ? .green : .gray)
            }
        }
        .sheet(isPresented: $showSheet) {
            EasterEggDiscoveryView()
        }
    }
}
