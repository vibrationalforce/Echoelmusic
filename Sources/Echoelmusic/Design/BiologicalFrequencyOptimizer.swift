//
//  BiologicalFrequencyOptimizer.swift
//  Echoelmusic
//
//  Created: 2025-11-25
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  Biological Frequency Optimizer
//  Adey windows implementation for therapeutic visual/audio pulsation
//  Dr. W. Ross Adey's research on bioactive frequency windows
//  Brainwave entrainment, calcium ion modulation, cellular resonance
//

import SwiftUI
import Combine

/// Implements Adey windows for biological frequency optimization
@MainActor
class BiologicalFrequencyOptimizer: ObservableObject {
    static let shared = BiologicalFrequencyOptimizer()

    @Published var isActive: Bool = false
    @Published var currentWindow: FrequencyWindow = .alphaRelaxation
    @Published var intensity: Double = 0.5  // 0.0 to 1.0
    @Published var currentPhase: Double = 0.0

    private var timer: Timer?
    private var startTime: Date?

    // MARK: - Frequency Windows

    enum FrequencyWindow: String, CaseIterable, Identifiable {
        case deltaDeepSleep = "Delta - Deep Sleep"
        case thetaMeditation = "Theta - Meditation"
        case alphaRelaxation = "Alpha - Relaxation"
        case betaFocus = "Beta - Focus"
        case gammaInsight = "Gamma - Insight"
        case thetaLow = "Theta Low - Deep Relaxation"
        case adeyCalcium = "Adey - Calcium Ion"

        var id: String { rawValue }

        var frequency: Double {
            switch self {
            case .deltaDeepSleep: return 2.0     // 0.5-4 Hz
            case .thetaMeditation: return 6.0    // 4-8 Hz
            case .alphaRelaxation: return 10.0   // 8-13 Hz
            case .betaFocus: return 20.0         // 13-30 Hz
            case .gammaInsight: return 40.0      // 30-100 Hz
            case .thetaLow: return 7.83 // Low theta range (4-8 Hz)
            case .adeyCalcium: return 16.0       // Adey's calcium window (6-20 Hz)
            }
        }

        var description: String {
            switch self {
            case .deltaDeepSleep:
                return "0.5-4 Hz • Deep sleep, physical healing, immune function, growth hormone release"
            case .thetaMeditation:
                return "4-8 Hz • Deep meditation, REM sleep, creativity, memory consolidation, subconscious access"
            case .alphaRelaxation:
                return "8-13 Hz • Relaxed alertness, stress reduction, learning enhancement, creativity"
            case .betaFocus:
                return "13-30 Hz • Active thinking, problem-solving, sustained attention, alertness"
            case .gammaInsight:
                return "30-100 Hz • Higher cognition, insight, peak performance, information processing"
            case .thetaLow:
                return "7.83 Hz • Low theta range, deep relaxation, drowsiness transition"
            case .adeyCalcium:
                return "6-20 Hz • Dr. Adey's calcium ion efflux window, neurotransmitter modulation, synaptic plasticity"
            }
        }

        var biologicalEffects: [String] {
            switch self {
            case .deltaDeepSleep:
                return [
                    "Triggers growth hormone release",
                    "Enhances immune function",
                    "Promotes physical healing",
                    "Deep restorative sleep"
                ]
            case .thetaMeditation:
                return [
                    "Enhances creativity and intuition",
                    "Facilitates memory consolidation",
                    "Reduces anxiety and stress",
                    "Deepens meditation states"
                ]
            case .alphaRelaxation:
                return [
                    "Reduces cortisol (stress hormone)",
                    "Increases serotonin production",
                    "Enhances learning and retention",
                    "Promotes calm focus"
                ]
            case .betaFocus:
                return [
                    "Enhances concentration",
                    "Improves problem-solving",
                    "Increases alertness",
                    "Supports active thinking"
                ]
            case .gammaInsight:
                return [
                    "Enhances cognitive processing",
                    "Increases awareness",
                    "Facilitates insight and epiphany",
                    "Peak mental performance"
                ]
            case .thetaLow:
                return [
                    "Promotes deep relaxation",
                    "Reduces stress and anxiety",
                    "Transition state between wake and sleep",
                    "Supports meditation practice"
                ]
            case .adeyCalcium:
                return [
                    "Modulates calcium ion channels",
                    "Affects neurotransmitter release",
                    "Enhances synaptic plasticity",
                    "Supports neural communication"
                ]
            }
        }

        var safetyNotes: String {
            switch self {
            case .deltaDeepSleep:
                return "May cause drowsiness. Use before sleep, not while driving or operating machinery."
            case .thetaMeditation:
                return "Can induce deep relaxation. Use in safe, comfortable environment."
            case .alphaRelaxation:
                return "Generally safe for extended use. Excellent for stress management."
            case .betaFocus:
                return "Safe for daytime use. Avoid before sleep as it may delay sleep onset."
            case .gammaInsight:
                return "High frequency. Use for short periods (15-30 min). May cause headaches if overused."
            case .thetaLow:
                return "Very safe. Low theta range. Can cause drowsiness - use in relaxed setting."
            case .adeyCalcium:
                return "Research-backed frequency. Safe for most users. Consult physician if epileptic."
            }
        }
    }

    // MARK: - Control

    func start(window: FrequencyWindow) {
        currentWindow = window
        isActive = true
        startTime = Date()
        currentPhase = 0.0

        // Update at screen refresh rate for smooth animation
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.updatePhase()
        }

        print("🧠 Frequency optimizer started: \(window.rawValue) at \(window.frequency) Hz")
    }

    func stop() {
        isActive = false
        timer?.invalidate()
        timer = nil
        startTime = nil
        currentPhase = 0.0

        print("🧠 Frequency optimizer stopped")
    }

    private func updatePhase() {
        guard let startTime = startTime else { return }

        let elapsed = Date().timeIntervalSince(startTime)
        let cycles = elapsed * currentWindow.frequency
        currentPhase = cycles.truncatingRemainder(dividingBy: 1.0)
    }

    // MARK: - Visual Modulation

    /// Get current modulation value (0.0 to 1.0) for visual pulsing
    func getModulationValue() -> Double {
        guard isActive else { return 0.5 }

        // Sine wave modulation
        let sineValue = sin(currentPhase * 2.0 * .pi)

        // Map from -1...1 to 0...1
        let normalized = (sineValue + 1.0) / 2.0

        // Apply intensity
        let center = 0.5
        let modulated = center + (normalized - center) * intensity

        return modulated
    }

    /// Get opacity modulation for pulsing effect
    func getOpacityModulation(baseOpacity: Double = 1.0) -> Double {
        let modulation = getModulationValue()
        return baseOpacity * (0.7 + (modulation * 0.3))
    }

    /// Get brightness modulation
    func getBrightnessModulation() -> Double {
        let modulation = getModulationValue()
        return -0.1 + (modulation * 0.2)  // Range: -0.1 to +0.1
    }

    // MARK: - Audio Modulation

    /// Generate binaural beat frequency for stereo audio
    /// Left ear: base frequency, Right ear: base + beat frequency
    func getBinauralBeatFrequencies(baseFrequency: Double = 200.0) -> (left: Double, right: Double) {
        let beatFrequency = currentWindow.frequency

        return (
            left: baseFrequency,
            right: baseFrequency + beatFrequency
        )
    }

    /// Get isochronic tone modulation (on/off pulses)
    func getIsochronicModulation() -> Double {
        guard isActive else { return 0.0 }

        // Square wave for sharp on/off
        return currentPhase < 0.5 ? 1.0 : 0.0
    }

    // MARK: - Session Management

    struct Session {
        let window: FrequencyWindow
        let duration: TimeInterval  // seconds
        let startTime: Date
        var endTime: Date {
            startTime.addingTimeInterval(duration)
        }
        var isComplete: Bool {
            Date() >= endTime
        }
        var remainingTime: TimeInterval {
            max(0, endTime.timeIntervalSinceNow)
        }
    }

    @Published var currentSession: Session?

    func startSession(window: FrequencyWindow, duration: TimeInterval) {
        currentSession = Session(
            window: window,
            duration: duration,
            startTime: Date()
        )
        start(window: window)

        // Auto-stop when session completes
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.stop()
            self?.currentSession = nil
        }

        print("🧠 Session started: \(Int(duration/60)) minutes at \(window.frequency) Hz")
    }

    // MARK: - Research References

    struct ResearchReference {
        let title: String
        let authors: String
        let journal: String
        let year: Int
        let pubmedID: String?
        let summary: String
    }

    static let adeyResearch = ResearchReference(
        title: "Tissue interactions with nonionizing electromagnetic fields",
        authors: "W. Ross Adey",
        journal: "Physiological Reviews",
        year: 1981,
        pubmedID: "7012859",
        summary: "Seminal work on biological windows for electromagnetic field effects, particularly calcium ion efflux at specific frequencies (6-20 Hz)."
    )

    static let circadianBlueLight = ResearchReference(
        title: "Action spectrum for melatonin regulation in humans: evidence for a novel circadian photoreceptor",
        authors: "Brainard et al.",
        journal: "Journal of Neuroscience",
        year: 2001,
        pubmedID: "11487664",
        summary: "Identified 446-477nm blue light as primary regulator of human circadian rhythm via melanopsin photoreceptors."
    )

    static let photobiomodulation = ResearchReference(
        title: "Mechanisms and applications of the anti-inflammatory effects of photobiomodulation",
        authors: "Hamblin",
        journal: "AIMS Biophysics",
        year: 2017,
        pubmedID: "28580386",
        summary: "Review of red (630-660nm) and near-infrared (810-850nm) light therapy for anti-inflammatory effects and tissue healing."
    )

    private init() {}
}

// MARK: - Frequency Modulated View Modifier

struct FrequencyModulation: ViewModifier {
    @ObservedObject var optimizer: BiologicalFrequencyOptimizer

    func body(content: Content) -> some View {
        content
            .opacity(optimizer.getOpacityModulation())
            .brightness(optimizer.getBrightnessModulation())
    }
}

extension View {
    func frequencyModulated(_ optimizer: BiologicalFrequencyOptimizer = .shared) -> some View {
        modifier(FrequencyModulation(optimizer: optimizer))
    }
}

// MARK: - Pulsing Circle (Visual Entrainment)

struct BrainwaveEntrainmentCircle: View {
    @ObservedObject var optimizer: BiologicalFrequencyOptimizer
    var color: Color = .blue
    var size: CGFloat = 200

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .scaleEffect(0.8 + (optimizer.getModulationValue() * 0.4))
            .opacity(optimizer.getOpacityModulation())
            .shadow(color: color, radius: 20 * optimizer.getModulationValue())
    }
}

// MARK: - Preview

#Preview("Frequency Optimizer") {
    struct PreviewWrapper: View {
        @StateObject private var optimizer = BiologicalFrequencyOptimizer.shared
        @State private var selectedWindow: BiologicalFrequencyOptimizer.FrequencyWindow = .alphaRelaxation

        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 32) {
                    Text("BRAINWAVE ENTRAINMENT")
                        .font(.title)
                        .foregroundColor(.white)

                    // Entrainment circle
                    BrainwaveEntrainmentCircle(
                        optimizer: optimizer,
                        color: .cyan,
                        size: 200
                    )

                    // Window selector
                    Picker("Frequency Window", selection: $selectedWindow) {
                        ForEach(BiologicalFrequencyOptimizer.FrequencyWindow.allCases) { window in
                            Text(window.rawValue).tag(window)
                        }
                    }
                    .pickerStyle(.menu)
                    .foregroundColor(.white)

                    // Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Frequency: \(String(format: "%.2f", selectedWindow.frequency)) Hz")
                            .foregroundColor(.white)
                        Text(selectedWindow.description)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()

                    // Controls
                    HStack {
                        Button(optimizer.isActive ? "Stop" : "Start") {
                            if optimizer.isActive {
                                optimizer.stop()
                            } else {
                                optimizer.start(window: selectedWindow)
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("5 Min Session") {
                            optimizer.startSession(window: selectedWindow, duration: 300)
                        }
                        .buttonStyle(.bordered)
                    }

                    if let session = optimizer.currentSession {
                        Text("Session: \(Int(session.remainingTime / 60)):\(String(format: "%02d", Int(session.remainingTime) % 60))")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                .padding()
            }
        }
    }

    return PreviewWrapper()
}
