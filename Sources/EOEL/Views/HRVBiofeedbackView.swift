//
//  HRVBiofeedbackView.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  EVIDENCE-BASED HRV BIOFEEDBACK UI
//  Implements Lehrer et al. (2013) protocols with real-time feedback
//

import SwiftUI

/// Evidence-based HRV biofeedback training interface
struct HRVBiofeedbackView: View {
    @StateObject private var manager = EvidenceBasedHRVManager.shared
    @State private var session = EvidenceBasedHRVManager.BiofeedbackSession.new()
    @State private var breathingPhase: BreathingPhase = .inhale
    @State private var breathingProgress: Double = 0.0
    @State private var timer: Timer?

    enum BreathingPhase {
        case inhale
        case exhale

        var color: Color {
            switch self {
            case .inhale: return .cyan
            case .exhale: return .purple
            }
        }

        var instruction: String {
            switch self {
            case .inhale: return "Breathe In"
            case .exhale: return "Breathe Out"
            }
        }
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.black,
                    manager.coherenceLevel.color.opacity(0.2)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                // Header
                VStack(spacing: 8) {
                    Text("HRV Biofeedback Training")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Evidence-Based Protocol (Lehrer et al. 2013)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Coherence Score
                CoherenceScoreView(
                    score: manager.coherenceScore,
                    level: manager.coherenceLevel
                )

                Spacer()

                // Breathing Pacer (Main Visual)
                BreathingPacerView(
                    phase: breathingPhase,
                    progress: breathingProgress,
                    resonantFrequency: manager.resonantFrequency
                )
                .frame(height: 300)

                // Breathing Instructions
                Text(breathingPhase.instruction)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(breathingPhase.color)

                Spacer()

                // Session Info
                if manager.isTraining {
                    SessionInfoView(session: session)
                }

                // Controls
                HStack(spacing: 20) {
                    if !manager.isTraining {
                        Button(action: startSession) {
                            Label("Start Session", systemImage: "play.circle.fill")
                                .font(.headline)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    } else {
                        Button(action: stopSession) {
                            Label("Stop", systemImage: "stop.circle.fill")
                                .font(.headline)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .onAppear {
            // Generate test data for demo
            #if DEBUG
            manager.generateTestData()
            #endif
        }
        .onDisappear {
            stopSession()
        }
    }

    // MARK: - Session Control

    private func startSession() {
        manager.startBiofeedbackSession()
        session = EvidenceBasedHRVManager.BiofeedbackSession.new()

        // Start breathing pacer timer
        let protocol = EvidenceBasedHRVManager.ResonantFrequencyProtocol.standard()
        let breathCycleDuration = protocol.inhaleSeconds + protocol.exhaleSeconds

        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            // Update breathing progress
            breathingProgress += 0.05 / breathCycleDuration

            if breathingProgress >= 1.0 {
                breathingProgress = 0.0
                breathingPhase = breathingPhase == .inhale ? .exhale : .inhale
            }

            // Update session (would connect to real HRV data)
            let simulatedHRV = 50.0 + Double.random(in: -5.0...5.0)
            let simulatedCoherence = manager.coherenceScore + Double.random(in: -2.0...2.0)
            session.update(
                hrv: simulatedHRV,
                coherence: simulatedCoherence,
                breathingRate: protocol.breathsPerMinute
            )
        }
    }

    private func stopSession() {
        manager.stopBiofeedbackSession()
        timer?.invalidate()
        timer = nil

        // Show session summary
        let summary = session.sessionSummary
        print("Session Summary:")
        print("  Duration: \(Int(summary.duration))s")
        print("  HRV Improvement: \(String(format: "%.1f", summary.hrvImprovement))%")
        print("  Avg Coherence: \(String(format: "%.1f", summary.averageCoherence))")
    }
}

// MARK: - Coherence Score View

struct CoherenceScoreView: View {
    let score: Double
    let level: EvidenceBasedHRVManager.CoherenceLevel

    var body: some View {
        VStack(spacing: 12) {
            // Circular progress
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 20)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: score / 100.0)
                    .stroke(
                        level.color,
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: score)

                VStack(spacing: 4) {
                    Text("\(Int(score))")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(level.color)

                    Text("Coherence")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Level indicator
            Text(level.rawValue)
                .font(.headline)
                .foregroundColor(level.color)

            Text(level.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
    }
}

// MARK: - Breathing Pacer View

struct BreathingPacerView: View {
    let phase: HRVBiofeedbackView.BreathingPhase
    let progress: Double
    let resonantFrequency: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background circle
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                phase.color.opacity(0.3),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                    .frame(width: circleSize, height: circleSize)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

                // Animated circle
                Circle()
                    .stroke(phase.color, lineWidth: 4)
                    .frame(width: circleSize, height: circleSize)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .shadow(color: phase.color.opacity(0.5), radius: 20)

                // Inner glow
                Circle()
                    .fill(phase.color.opacity(0.2))
                    .frame(width: circleSize * 0.8, height: circleSize * 0.8)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .blur(radius: 30)

                // Center info
                VStack(spacing: 8) {
                    Text("\(String(format: "%.1f", resonantFrequency * 60)) BPM")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Resonant Frequency")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
        .animation(.easeInOut(duration: phase == .inhale ? 4.5 : 5.5), value: circleSize)
    }

    private var circleSize: CGFloat {
        let minSize: CGFloat = 100
        let maxSize: CGFloat = 250

        if phase == .inhale {
            return minSize + (maxSize - minSize) * progress
        } else {
            return maxSize - (maxSize - minSize) * progress
        }
    }
}

// MARK: - Session Info View

struct SessionInfoView: View {
    let session: EvidenceBasedHRVManager.BiofeedbackSession

    var body: some View {
        VStack(spacing: 12) {
            // Progress bar
            ProgressView(value: session.progress)
                .tint(.green)

            // Phase and time
            HStack {
                Text(session.phase.instructions)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text(timeString(from: session.elapsedTime))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            // Stats
            HStack(spacing: 20) {
                StatView(
                    title: "HRV",
                    value: String(format: "%.1f ms", session.currentHRV),
                    change: session.hrvImprovement
                )

                StatView(
                    title: "Coherence",
                    value: String(format: "%.0f", session.currentCoherence),
                    change: nil
                )

                StatView(
                    title: "Breathing",
                    value: String(format: "%.1f/min", session.breathingRate),
                    change: nil
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    private func timeString(from interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct StatView: View {
    let title: String
    let value: String
    let change: Double?

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.headline)
                .monospacedDigit()

            if let change = change {
                HStack(spacing: 2) {
                    Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                        .font(.caption2)
                    Text(String(format: "%.1f%%", abs(change)))
                        .font(.caption2)
                }
                .foregroundColor(change >= 0 ? .green : .red)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#if DEBUG
struct HRVBiofeedbackView_Previews: PreviewProvider {
    static var previews: some View {
        HRVBiofeedbackView()
    }
}
#endif
