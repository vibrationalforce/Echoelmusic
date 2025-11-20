//
//  QuantumTherapyView.swift
//  Echoelmusic
//
//  Quantum Science Therapy Interface
//  Created: 2025-11-20
//

import SwiftUI
import HealthKit

@available(iOS 15.0, *)
struct QuantumTherapyView: View {
    @StateObject private var therapyEngine = QuantumTherapyEngine()
    @State private var selectedCategory: QuantumTherapyEngine.TherapyCategory = .solfeggio
    @State private var showSessionPicker = false
    @State private var selectedSession: QuantumTherapyEngine.TherapySession?

    var body: some View {
        ZStack {
            // Background gradient
            EchoelBranding.quantumGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerView

                    // Active Therapy Display
                    if therapyEngine.isActive {
                        activeTherapyCard
                    }

                    // Category Selector
                    categorySelector

                    // Therapy Modes Grid
                    therapyModesGrid

                    // Preset Sessions
                    presetSessionsSection

                    // Info Section
                    infoSection
                }
                .padding()
            }
        }
        .sheet(isPresented: $showSessionPicker) {
            sessionPickerSheet
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 32))
                    .foregroundColor(.white)

                VStack(alignment: .leading) {
                    Text("Quantum Therapy")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    Text("Frequency Healing & Brainwave Entrainment")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()
            }
        }
    }

    // MARK: - Active Therapy Card

    private var activeTherapyCard: some View {
        VStack(spacing: 16) {
            // Pulsing circle visualization
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                EchoelBranding.accent.opacity(0.6),
                                EchoelBranding.accent.opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .scaleEffect(therapyEngine.isActive ? 1.2 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                        value: therapyEngine.isActive
                    )

                VStack {
                    Text("\(Int(therapyEngine.currentFrequency)) Hz")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)

                    Text(therapyEngine.currentTherapy.rawValue)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
            }

            // Intensity Control
            VStack(spacing: 8) {
                HStack {
                    Text("Intensity")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)

                    Spacer()

                    Text("\(Int(therapyEngine.intensity * 100))%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }

                Slider(value: $therapyEngine.intensity, in: 0...1)
                    .accentColor(EchoelBranding.accent)
            }

            // Heart Rate Coherence (if available)
            if therapyEngine.heartRateCoherence > 0 {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)

                    Text("Coherence:")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))

                    Spacer()

                    // Coherence bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.2))

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [.green, .yellow, .green],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(therapyEngine.heartRateCoherence))
                        }
                    }
                    .frame(height: 8)
                    .frame(maxWidth: 150)

                    Text("\(Int(therapyEngine.heartRateCoherence * 100))%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            // Stop Button
            Button(action: {
                therapyEngine.stopTherapy()
            }) {
                HStack {
                    Image(systemName: "stop.fill")
                    Text("Stop Therapy")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Category Selector

    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(QuantumTherapyEngine.TherapyCategory.allCases, id: \.self) { category in
                    CategoryButton(
                        title: category.rawValue,
                        isSelected: selectedCategory == category,
                        action: { selectedCategory = category }
                    )
                }
            }
        }
    }

    // MARK: - Therapy Modes Grid

    private var therapyModesGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(therapyModesForCategory(selectedCategory), id: \.id) { mode in
                TherapyModeCard(
                    mode: mode,
                    isActive: therapyEngine.isActive && therapyEngine.currentTherapy == mode,
                    action: {
                        if therapyEngine.isActive && therapyEngine.currentTherapy == mode {
                            therapyEngine.stopTherapy()
                        } else {
                            therapyEngine.stopTherapy()
                            therapyEngine.startTherapy(mode: mode)
                        }
                    }
                )
            }
        }
    }

    // MARK: - Preset Sessions

    private var presetSessionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Guided Sessions")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            ForEach(QuantumTherapyEngine.presetSessions, id: \.name) { session in
                SessionCard(session: session) {
                    selectedSession = session
                    showSessionPicker = true
                }
            }
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About Quantum Therapy")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            Text("""
            Quantum therapy uses specific frequencies to promote healing, relaxation, and wellness. \
            Each frequency resonates with different aspects of your physical, emotional, and spiritual body.

            🎵 Solfeggio Frequencies: Ancient healing tones
            🧠 Binaural Beats: Brainwave entrainment
            🌍 Schumann Resonance: Earth's natural frequency
            💎 Chakra Tuning: Energy center balancing
            ⚛️ Quantum Fields: Universal resonance

            Use headphones for optimal binaural beat effect.
            """)
            .font(.system(size: 14))
            .foregroundColor(.white.opacity(0.8))
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
        )
    }

    // MARK: - Session Picker Sheet

    private var sessionPickerSheet: some View {
        NavigationView {
            ZStack {
                EchoelBranding.quantumGradient.ignoresSafeArea()

                if let session = selectedSession {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Text(session.name)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)

                            Text(session.description)
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.9))

                            Divider()
                                .background(Color.white.opacity(0.3))

                            Text("Session Outline:")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)

                            ForEach(Array(session.modes.enumerated()), id: \.offset) { index, mode in
                                HStack {
                                    Text("\(index + 1).")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(EchoelBranding.accent)
                                        .frame(width: 30)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(mode.rawValue)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.white)

                                        Text("\(Int(session.durations[index] / 60)) minutes")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.7))
                                    }

                                    Spacer()
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                )
                            }

                            let totalMinutes = Int(session.durations.reduce(0, +) / 60)
                            Text("Total Duration: \(totalMinutes) minutes")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(EchoelBranding.accent)

                            Button(action: {
                                // Start session (would implement session player)
                                showSessionPicker = false
                            }) {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("Start Session")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(EchoelBranding.accent)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationBarItems(trailing: Button("Close") {
                showSessionPicker = false
            }.foregroundColor(.white))
        }
    }

    // MARK: - Helper Functions

    private func therapyModesForCategory(_ category: QuantumTherapyEngine.TherapyCategory) -> [QuantumTherapyEngine.TherapyMode] {
        QuantumTherapyEngine.TherapyMode.allCases.filter { $0.category == category }
    }
}

// MARK: - Supporting Views

struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? EchoelBranding.accent : Color.white.opacity(0.2))
                )
                .foregroundColor(.white)
        }
    }
}

struct TherapyModeCard: View {
    let mode: QuantumTherapyEngine.TherapyMode
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: iconForMode(mode))
                        .font(.system(size: 24))
                        .foregroundColor(isActive ? .white : EchoelBranding.accent)

                    Spacer()

                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }

                Text("\(Int(mode.frequency)) Hz")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text(mode.rawValue.components(separatedBy: " - ").last ?? "")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(2)
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isActive ? EchoelBranding.accent : Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isActive ? Color.white.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }

    private func iconForMode(_ mode: QuantumTherapyEngine.TherapyMode) -> String {
        switch mode.category {
        case .solfeggio: return "music.note"
        case .earthResonance: return "globe"
        case .binauralBeats: return "brain.head.profile"
        case .chakra: return "sparkles"
        case .quantum: return "atom"
        }
    }
}

struct SessionCard: View {
    let session: QuantumTherapyEngine.TherapySession
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(session.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Text(session.description)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)

                    let totalMinutes = Int(session.durations.reduce(0, +) / 60)
                    Text("\(session.modes.count) steps • \(totalMinutes) min")
                        .font(.system(size: 12))
                        .foregroundColor(EchoelBranding.accent)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Preview

@available(iOS 15.0, *)
struct QuantumTherapyView_Previews: PreviewProvider {
    static var previews: some View {
        QuantumTherapyView()
    }
}
