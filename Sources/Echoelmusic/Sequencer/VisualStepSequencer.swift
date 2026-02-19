// VisualStepSequencer.swift
// Echoelmusic - Bio-Reactive Visual Step Sequencer
//
// Inspired by nw_wrld's event-driven sequencer concept
// https://github.com/aagentah/nw_wrld
//
// Features:
// - 16-step pattern grid for visual triggers
// - Bio-feedback modulation (HRV → pattern density)
// - MIDI sync and external clock
// - Method mapping to visual parameters
//
// Copyright 2026 Echoelmusic. MIT License.

import SwiftUI
import Combine

// MARK: - Step Sequencer Core

/// 16-Step Visual Sequencer with Bio-Reactive Modulation
@MainActor
public final class VisualStepSequencer: ObservableObject {

    // MARK: - Published State

    @Published public var isPlaying: Bool = false
    @Published public var currentStep: Int = 0
    @Published public var bpm: Double = 120.0
    @Published public var pattern: SequencerPattern = SequencerPattern()
    @Published public var bioModulation: BioModulationState = BioModulationState()

    // MARK: - Configuration

    public static let stepCount: Int = 16
    public static let bpmRange: ClosedRange<Double> = 60...180
    public static let channelCount: Int = 8

    // MARK: - Timing

    private var timer: Timer?
    private var stepInterval: TimeInterval {
        60.0 / bpm / 4.0  // 16th notes
    }

    // MARK: - Channels

    public enum Channel: Int, CaseIterable, Identifiable {
        case visual1 = 0
        case visual2 = 1
        case visual3 = 2
        case visual4 = 3
        case lighting = 4
        case effect1 = 5
        case effect2 = 6
        case bioTrigger = 7

        public var id: Int { rawValue }

        public var name: String {
            switch self {
            case .visual1: return "Visual A"
            case .visual2: return "Visual B"
            case .visual3: return "Visual C"
            case .visual4: return "Visual D"
            case .lighting: return "Lighting"
            case .effect1: return "Effect 1"
            case .effect2: return "Effect 2"
            case .bioTrigger: return "Bio Trigger"
            }
        }

        public var color: Color {
            switch self {
            case .visual1: return .cyan
            case .visual2: return .purple
            case .visual3: return .pink
            case .visual4: return .orange
            case .lighting: return .yellow
            case .effect1: return .green
            case .effect2: return .blue
            case .bioTrigger: return .red
            }
        }
    }

    // MARK: - Singleton

    public static let shared = VisualStepSequencer()

    private init() {}

    // MARK: - Playback Control

    public func play() {
        guard !isPlaying else { return }
        isPlaying = true
        startTimer()
    }

    public func stop() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
        currentStep = 0
    }

    public func pause() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advanceStep()
            }
        }
    }

    private func advanceStep() {
        // Apply bio-modulation to step advancement
        let skipProbability = bioModulation.skipProbability

        if Double.random(in: 0...1) > skipProbability {
            triggerCurrentStep()
        }

        currentStep = (currentStep + 1) % Self.stepCount
    }

    private func triggerCurrentStep() {
        for channel in Channel.allCases {
            if pattern.isActive(channel: channel, step: currentStep) {
                let velocity = pattern.velocity(channel: channel, step: currentStep)
                let modulatedVelocity = applyBioModulation(velocity: velocity)

                // Notify listeners
                NotificationCenter.default.post(
                    name: .sequencerStepTriggered,
                    object: nil,
                    userInfo: [
                        "channel": channel,
                        "step": currentStep,
                        "velocity": modulatedVelocity
                    ]
                )
            }
        }
    }

    private func applyBioModulation(velocity: Float) -> Float {
        let coherenceFactor = bioModulation.coherence
        let modulated = velocity * (0.5 + coherenceFactor * 0.5)
        return min(max(modulated, 0.0), 1.0)
    }

    // MARK: - Pattern Editing

    public func toggleStep(channel: Channel, step: Int) {
        pattern.toggle(channel: channel, step: step)
    }

    public func setVelocity(channel: Channel, step: Int, velocity: Float) {
        pattern.setVelocity(channel: channel, step: step, velocity: velocity)
    }

    public func clearChannel(_ channel: Channel) {
        pattern.clearChannel(channel)
    }

    public func clearAll() {
        pattern = SequencerPattern()
    }

    // MARK: - Bio-Feedback Integration

    public func updateBioState(coherence: Float, heartRate: Float, hrvVariability: Float) {
        bioModulation.coherence = coherence
        bioModulation.heartRate = heartRate
        bioModulation.hrvVariability = hrvVariability

        // Dynamic BPM modulation based on heart rate
        if bioModulation.tempoLockEnabled {
            let targetBPM = Double(heartRate).clamped(to: Self.bpmRange)
            bpm = bpm * 0.95 + targetBPM * 0.05  // Smooth transition

            if isPlaying {
                startTimer()  // Restart timer with new interval
            }
        }

        // Pattern density modulation based on HRV
        bioModulation.skipProbability = Double(1.0 - hrvVariability) * 0.3
    }

    // MARK: - Presets

    public func loadPreset(_ preset: SequencerPreset) {
        pattern = preset.pattern
        bpm = preset.bpm
    }

    public static let presets: [SequencerPreset] = [
        .fourOnFloor,
        .breakbeat,
        .ambient,
        .bioReactive,
        .minimal
    ]
}

// MARK: - Pattern Data

public struct SequencerPattern: Codable, Equatable {
    private var steps: [[StepData]]

    public init() {
        steps = Array(
            repeating: Array(repeating: StepData(), count: VisualStepSequencer.stepCount),
            count: VisualStepSequencer.channelCount
        )
    }

    public struct StepData: Codable, Equatable {
        public var isActive: Bool = false
        public var velocity: Float = 1.0
        public var parameter: Float = 0.5
    }

    public func isActive(channel: VisualStepSequencer.Channel, step: Int) -> Bool {
        guard step < VisualStepSequencer.stepCount else { return false }
        return steps[channel.rawValue][step].isActive
    }

    public func velocity(channel: VisualStepSequencer.Channel, step: Int) -> Float {
        guard step < VisualStepSequencer.stepCount else { return 0 }
        return steps[channel.rawValue][step].velocity
    }

    public mutating func toggle(channel: VisualStepSequencer.Channel, step: Int) {
        guard step < VisualStepSequencer.stepCount else { return }
        steps[channel.rawValue][step].isActive.toggle()
    }

    public mutating func setVelocity(channel: VisualStepSequencer.Channel, step: Int, velocity: Float) {
        guard step < VisualStepSequencer.stepCount else { return }
        steps[channel.rawValue][step].velocity = velocity.clamped(to: 0...1)
    }

    public mutating func clearChannel(_ channel: VisualStepSequencer.Channel) {
        for i in 0..<VisualStepSequencer.stepCount {
            steps[channel.rawValue][i] = StepData()
        }
    }
}

// MARK: - Bio Modulation State

public struct BioModulationState {
    public var coherence: Float = 0.5
    public var heartRate: Float = 70.0
    public var hrvVariability: Float = 0.5
    public var skipProbability: Double = 0.0
    public var tempoLockEnabled: Bool = false
}

// MARK: - Presets

public struct SequencerPreset: Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let pattern: SequencerPattern
    public let bpm: Double

    public static let fourOnFloor = SequencerPreset(
        id: "four_on_floor",
        name: "Four on Floor",
        description: "Classic kick pattern",
        pattern: {
            var p = SequencerPattern()
            for step in stride(from: 0, to: 16, by: 4) {
                p.toggle(channel: .visual1, step: step)
            }
            return p
        }(),
        bpm: 120
    )

    public static let breakbeat = SequencerPreset(
        id: "breakbeat",
        name: "Breakbeat",
        description: "Syncopated rhythm",
        pattern: {
            var p = SequencerPattern()
            p.toggle(channel: .visual1, step: 0)
            p.toggle(channel: .visual1, step: 6)
            p.toggle(channel: .visual1, step: 10)
            p.toggle(channel: .visual2, step: 4)
            p.toggle(channel: .visual2, step: 12)
            return p
        }(),
        bpm: 90
    )

    public static let ambient = SequencerPreset(
        id: "ambient",
        name: "Ambient",
        description: "Sparse, atmospheric",
        pattern: {
            var p = SequencerPattern()
            p.toggle(channel: .visual1, step: 0)
            p.toggle(channel: .visual3, step: 8)
            p.toggle(channel: .lighting, step: 4)
            p.toggle(channel: .lighting, step: 12)
            return p
        }(),
        bpm: 70
    )

    public static let bioReactive = SequencerPreset(
        id: "bio_reactive",
        name: "Bio-Reactive",
        description: "Responds to HRV coherence",
        pattern: {
            var p = SequencerPattern()
            // Dense pattern - bio-modulation will thin it out
            for step in 0..<16 {
                if step % 2 == 0 {
                    p.toggle(channel: .bioTrigger, step: step)
                }
            }
            p.toggle(channel: .visual1, step: 0)
            p.toggle(channel: .visual1, step: 8)
            return p
        }(),
        bpm: 100
    )

    public static let minimal = SequencerPreset(
        id: "minimal",
        name: "Minimal",
        description: "Less is more",
        pattern: {
            var p = SequencerPattern()
            p.toggle(channel: .visual1, step: 0)
            p.toggle(channel: .lighting, step: 8)
            return p
        }(),
        bpm: 110
    )
}

// MARK: - Notifications

extension Notification.Name {
    public static let sequencerStepTriggered = Notification.Name("sequencerStepTriggered")
}

// MARK: - SwiftUI View

public struct VisualStepSequencerView: View {
    @ObservedObject var sequencer = VisualStepSequencer.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("VISUAL SEQUENCER")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)

                Spacer()

                // BPM Display
                Text("\(Int(sequencer.bpm)) BPM")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))

                // Bio-lock toggle
                Button(action: {
                    sequencer.bioModulation.tempoLockEnabled.toggle()
                }) {
                    Image(systemName: sequencer.bioModulation.tempoLockEnabled ? "heart.fill" : "heart")
                        .foregroundColor(sequencer.bioModulation.tempoLockEnabled ? .red : .gray)
                }
                .buttonStyle(.plain)
            }

            // Step Grid
            VStack(spacing: 4) {
                ForEach(VisualStepSequencer.Channel.allCases) { channel in
                    HStack(spacing: 4) {
                        // Channel Label
                        Text(channel.name)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(channel.color.opacity(0.8))
                            .frame(width: 60, alignment: .leading)

                        // Steps
                        ForEach(0..<VisualStepSequencer.stepCount, id: \.self) { step in
                            StepButton(
                                isActive: sequencer.pattern.isActive(channel: channel, step: step),
                                isCurrent: sequencer.currentStep == step && sequencer.isPlaying,
                                color: channel.color
                            ) {
                                sequencer.toggleStep(channel: channel, step: step)
                            }
                        }
                    }
                }
            }

            // Transport Controls
            HStack(spacing: 20) {
                Button(action: { sequencer.stop() }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                Button(action: {
                    if sequencer.isPlaying {
                        sequencer.pause()
                    } else {
                        sequencer.play()
                    }
                }) {
                    Image(systemName: sequencer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.cyan)
                }
                .buttonStyle(.plain)

                // BPM Slider
                Slider(value: $sequencer.bpm, in: VisualStepSequencer.bpmRange)
                    .tint(.cyan)
                    .frame(width: 150)
                    .accessibilityLabel("Tempo")
                    .accessibilityValue("\(Int(sequencer.bpm)) BPM")

                // Preset Picker
                Menu {
                    ForEach(VisualStepSequencer.presets) { preset in
                        Button(preset.name) {
                            sequencer.loadPreset(preset)
                        }
                    }
                } label: {
                    Image(systemName: "square.grid.2x2")
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            // Bio Status
            if sequencer.bioModulation.tempoLockEnabled {
                HStack {
                    Text("Coherence: \(Int(sequencer.bioModulation.coherence * 100))%")
                    Spacer()
                    Text("HR: \(Int(sequencer.bioModulation.heartRate))")
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(16)
    }
}

// MARK: - Step Button

struct StepButton: View {
    let isActive: Bool
    let isCurrent: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 4)
                .fill(isActive ? color : Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isCurrent ? Color.white : Color.clear, lineWidth: 2)
                )
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isActive ? "Step active" : "Step inactive")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

// Note: clamped(to:) extension moved to NumericExtensions.swift

// MARK: - Preview

#if DEBUG
struct VisualStepSequencerView_Previews: PreviewProvider {
    static var previews: some View {
        VisualStepSequencerView()
            .frame(width: 500, height: 400)
            .preferredColorScheme(.dark)
    }
}
#endif
