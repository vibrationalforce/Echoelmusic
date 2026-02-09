// BPMTransitionEngine.swift
// Echoelmusic
//
// Controllable smooth BPM transition system
// Features:
// - Smooth transitions between BPM values
// - Bio-influence control (0-100%)
// - BPM lock with optional humanize
// - Situation presets (Meditation, Relax, Training, Romantic, etc.)
// - Intelligent BPM detection for current situation
//
// Created: 2026-01-12
// Ralph Wiggum Lambda Loop Mode

import Foundation
import Combine
import Combine
import SwiftUI

// MARK: - BPM Situation Presets

/// Predefined BPM ranges for different situations
public enum BPMSituation: String, CaseIterable, Identifiable {
    case freeform = "Freeform"
    case deepMeditation = "Deep Meditation"
    case relaxation = "Relaxation"
    case focus = "Focus"
    case romantic = "Romantic"
    case ambient = "Ambient"
    case lofi = "Lo-Fi"
    case house = "House"
    case techno = "Techno"
    case training = "Training"
    case hiit = "HIIT"
    case custom = "Custom"

    public var id: String { rawValue }

    /// Optimal BPM range for this situation
    public var bpmRange: ClosedRange<Double> {
        switch self {
        case .freeform: return 40...200
        case .deepMeditation: return 40...60
        case .relaxation: return 60...75
        case .focus: return 70...90
        case .romantic: return 65...85
        case .ambient: return 60...90
        case .lofi: return 70...90
        case .house: return 118...130
        case .techno: return 125...150
        case .training: return 120...140
        case .hiit: return 140...180
        case .custom: return 40...200
        }
    }

    /// Recommended BPM for this situation
    public var recommendedBPM: Double {
        switch self {
        case .freeform: return 120
        case .deepMeditation: return 50
        case .relaxation: return 68
        case .focus: return 80
        case .romantic: return 75
        case .ambient: return 72
        case .lofi: return 85
        case .house: return 124
        case .techno: return 135
        case .training: return 130
        case .hiit: return 160
        case .custom: return 120
        }
    }

    /// Bio-influence recommendation (0-1)
    public var recommendedBioInfluence: Double {
        switch self {
        case .freeform: return 0.8
        case .deepMeditation: return 0.9
        case .relaxation: return 0.7
        case .focus: return 0.5
        case .romantic: return 0.6
        case .ambient: return 0.7
        case .lofi: return 0.3
        case .house: return 0.2
        case .techno: return 0.1
        case .training: return 0.4
        case .hiit: return 0.3
        case .custom: return 0.5
        }
    }

    /// Humanize amount recommendation (0-1)
    public var recommendedHumanize: Double {
        switch self {
        case .freeform: return 0.3
        case .deepMeditation: return 0.1
        case .relaxation: return 0.15
        case .focus: return 0.1
        case .romantic: return 0.2
        case .ambient: return 0.25
        case .lofi: return 0.4
        case .house: return 0.05
        case .techno: return 0.02
        case .training: return 0.05
        case .hiit: return 0.03
        case .custom: return 0.2
        }
    }

    /// German localized name
    public var nameDE: String {
        switch self {
        case .freeform: return "Frei"
        case .deepMeditation: return "Tiefe Meditation"
        case .relaxation: return "Entspannung"
        case .focus: return "Fokus"
        case .romantic: return "Romantisch"
        case .ambient: return "Ambient"
        case .lofi: return "Lo-Fi"
        case .house: return "House"
        case .techno: return "Techno"
        case .training: return "Training"
        case .hiit: return "HIIT"
        case .custom: return "Benutzerdefiniert"
        }
    }
}

// MARK: - Transition Mode

/// How BPM transitions are handled
public enum BPMTransitionMode: String, CaseIterable {
    case instant = "Instant"
    case smooth = "Smooth"
    case verySmooth = "Very Smooth"
    case gradual = "Gradual"

    /// Transition duration in seconds
    public var duration: Double {
        switch self {
        case .instant: return 0
        case .smooth: return 0.5
        case .verySmooth: return 2.0
        case .gradual: return 5.0
        }
    }
}

// MARK: - BPM Lock State

/// BPM lock configuration
public struct BPMLockState {
    /// Whether BPM is locked
    public var isLocked: Bool = false

    /// Locked BPM value
    public var lockedBPM: Double = 120

    /// Allow slight humanize fluctuations even when locked
    public var allowHumanize: Bool = true

    /// Max fluctuation when locked (±BPM)
    public var maxFluctuation: Double = 2.0

    public init() {}
}

// MARK: - BPM Transition Engine

/// Main engine for controllable smooth BPM transitions
///
/// Features:
/// - Smooth interpolation between BPM values
/// - Bio-reactive BPM modulation with adjustable influence
/// - BPM lock with optional humanize
/// - Situation-based presets
/// - Intelligent BPM detection
///
/// Usage:
/// ```swift
/// let engine = BPMTransitionEngine()
/// engine.situation = .deepMeditation
/// engine.bioInfluence = 0.8
/// engine.setTargetBPM(60)
///
/// // In audio loop:
/// let currentBPM = engine.currentBPM
/// ```
@MainActor
public class BPMTransitionEngine: ObservableObject {

    // MARK: - Published Properties

    /// Current interpolated BPM (use this for playback)
    @Published public private(set) var currentBPM: Double = 120

    /// Target BPM (what we're transitioning to)
    @Published public var targetBPM: Double = 120 {
        didSet {
            if !lockState.isLocked {
                startTransition(to: targetBPM)
            }
        }
    }

    /// Bio-influence amount (0 = no influence, 1 = full bio-reactive)
    @Published public var bioInfluence: Double = 0.5 {
        didSet {
            bioInfluence = max(0, min(1, bioInfluence))
        }
    }

    /// Humanize amount (0 = rigid, 1 = very human fluctuations)
    @Published public var humanize: Double = 0.2 {
        didSet {
            humanize = max(0, min(1, humanize))
        }
    }

    /// Current situation preset
    @Published public var situation: BPMSituation = .freeform {
        didSet {
            applySituationPreset()
        }
    }

    /// Transition mode
    @Published public var transitionMode: BPMTransitionMode = .smooth

    /// Lock state
    @Published public var lockState = BPMLockState()

    /// Is currently transitioning
    @Published public private(set) var isTransitioning: Bool = false

    /// Min BPM limit
    @Published public var minBPM: Double = 40

    /// Max BPM limit
    @Published public var maxBPM: Double = 200

    /// Bio-reactive source BPM (from heart rate, etc.)
    @Published public var bioSourceBPM: Double = 70

    // MARK: - Private Properties

    private var transitionStartBPM: Double = 120
    private var transitionProgress: Double = 1.0
    private var displayLink: CADisplayLink?
    private var humanizePhase: Double = 0
    private var lastUpdateTime: CFTimeInterval = 0
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init() {
        setupDisplayLink()
        setupBindings()
    }

    deinit {
        displayLink?.invalidate()
    }

    // MARK: - Setup

    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateBPM))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        displayLink?.add(to: .main, forMode: .common)
    }

    private func setupBindings() {
        // Auto-apply situation when bio-source changes significantly
        $bioSourceBPM
            .removeDuplicates()
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] bpm in
                self?.handleBioSourceChange(bpm)
            }
            .store(in: &cancellables)
    }

    // MARK: - Update Loop

    @objc private func updateBPM(_ displayLink: CADisplayLink) {
        let currentTime = displayLink.timestamp
        let deltaTime = lastUpdateTime > 0 ? currentTime - lastUpdateTime : 0
        lastUpdateTime = currentTime

        // Update transition progress
        if transitionProgress < 1.0 && transitionMode.duration > 0 {
            let progressIncrement = deltaTime / transitionMode.duration
            transitionProgress = min(1.0, transitionProgress + progressIncrement)

            if transitionProgress >= 1.0 {
                isTransitioning = false
            }
        }

        // Calculate base BPM (interpolated)
        let interpolatedBPM = interpolate(
            from: transitionStartBPM,
            to: targetBPM,
            progress: easeInOutCubic(transitionProgress)
        )

        // Apply bio-influence
        let bioModulatedBPM = applyBioInfluence(baseBPM: interpolatedBPM)

        // Apply lock if active
        let lockedBPM = applyLock(bpm: bioModulatedBPM)

        // Apply humanize
        let humanizedBPM = applyHumanize(bpm: lockedBPM, deltaTime: deltaTime)

        // Clamp to limits
        currentBPM = max(minBPM, min(maxBPM, humanizedBPM))
    }

    // MARK: - Transition Control

    /// Start smooth transition to target BPM
    public func setTargetBPM(_ bpm: Double, instant: Bool = false) {
        let clampedBPM = max(minBPM, min(maxBPM, bpm))

        if instant || transitionMode == .instant {
            transitionStartBPM = clampedBPM
            targetBPM = clampedBPM
            transitionProgress = 1.0
            currentBPM = clampedBPM
            isTransitioning = false
        } else {
            targetBPM = clampedBPM
        }
    }

    private func startTransition(to bpm: Double) {
        transitionStartBPM = currentBPM
        transitionProgress = 0
        isTransitioning = true
    }

    // MARK: - Bio Influence

    private func applyBioInfluence(baseBPM: Double) -> Double {
        guard bioInfluence > 0 else { return baseBPM }

        // Map bio source to situation range
        let situationMidpoint = (situation.bpmRange.lowerBound + situation.bpmRange.upperBound) / 2
        let bioOffset = (bioSourceBPM - 70) * 0.5 // Normalize around resting HR

        // Blend between base and bio-influenced
        let bioInfluencedBPM = situationMidpoint + bioOffset
        let clampedBioInfluenced = max(situation.bpmRange.lowerBound, min(situation.bpmRange.upperBound, bioInfluencedBPM))

        return interpolate(from: baseBPM, to: clampedBioInfluenced, progress: bioInfluence)
    }

    // MARK: - Lock

    /// Lock BPM at current value
    public func lockBPM() {
        lockState.isLocked = true
        lockState.lockedBPM = currentBPM
    }

    /// Unlock BPM
    public func unlockBPM() {
        lockState.isLocked = false
    }

    /// Toggle lock
    public func toggleLock() {
        if lockState.isLocked {
            unlockBPM()
        } else {
            lockBPM()
        }
    }

    private func applyLock(bpm: Double) -> Double {
        guard lockState.isLocked else { return bpm }
        return lockState.lockedBPM
    }

    // MARK: - Humanize

    private func applyHumanize(bpm: Double, deltaTime: Double) -> Double {
        guard humanize > 0 else { return bpm }

        // Skip humanize if locked and not allowed
        if lockState.isLocked && !lockState.allowHumanize {
            return bpm
        }

        // Organic fluctuation using multiple sine waves
        humanizePhase += deltaTime * 0.5

        let fluctuation1 = sin(humanizePhase * 2.1) * 0.4
        let fluctuation2 = sin(humanizePhase * 3.7) * 0.3
        let fluctuation3 = sin(humanizePhase * 0.8) * 0.3

        let combinedFluctuation = fluctuation1 + fluctuation2 + fluctuation3

        // Scale by humanize amount and situation
        let maxFluctuation = lockState.isLocked ? lockState.maxFluctuation : (humanize * 5.0)
        let scaledFluctuation = combinedFluctuation * maxFluctuation

        return bpm + scaledFluctuation
    }

    // MARK: - Situation Presets

    private func applySituationPreset() {
        guard situation != .custom && situation != .freeform else { return }

        bioInfluence = situation.recommendedBioInfluence
        humanize = situation.recommendedHumanize

        // Optionally set recommended BPM
        if !lockState.isLocked {
            setTargetBPM(situation.recommendedBPM)
        }
    }

    /// Auto-detect best situation based on bio source
    public func autoDetectSituation() {
        let hr = bioSourceBPM

        if hr < 55 {
            situation = .deepMeditation
        } else if hr < 70 {
            situation = .relaxation
        } else if hr < 85 {
            situation = .focus
        } else if hr < 100 {
            situation = .ambient
        } else if hr < 130 {
            situation = .training
        } else {
            situation = .hiit
        }
    }

    // MARK: - Bio Source Handling

    private func handleBioSourceChange(_ bpm: Double) {
        // Only auto-adjust if not locked and bio-influence is active
        guard !lockState.isLocked && bioInfluence > 0.3 else { return }

        // Suggest situation change if bio source is far from current range
        if !situation.bpmRange.contains(bpm) && situation == .freeform {
            autoDetectSituation()
        }
    }

    /// Update bio source from heart rate
    public func updateBioSource(heartRate: Double) {
        bioSourceBPM = heartRate
    }

    /// Update bio source from HRV coherence
    public func updateBioSource(coherence: Double) {
        // High coherence = slower, relaxed BPM
        // Low coherence = faster, energetic BPM
        let coherenceInfluence = 1.0 - coherence // Invert: high coherence = calm
        let modulatedBPM = 60 + (coherenceInfluence * 60) // 60-120 BPM range
        bioSourceBPM = modulatedBPM
    }

    // MARK: - Tap Tempo

    private var tapTimes: [Date] = []

    /// Register tap for tap-tempo detection
    public func tap() {
        let now = Date()
        tapTimes.append(now)

        // Keep only last 8 taps
        if tapTimes.count > 8 {
            tapTimes.removeFirst()
        }

        // Need at least 2 taps
        guard tapTimes.count >= 2 else { return }

        // Calculate average interval
        var intervals: [TimeInterval] = []
        for i in 1..<tapTimes.count {
            let interval = tapTimes[i].timeIntervalSince(tapTimes[i-1])
            // Ignore intervals > 2 seconds (reset)
            if interval < 2.0 {
                intervals.append(interval)
            }
        }

        guard !intervals.isEmpty else {
            tapTimes = [now]
            return
        }

        let averageInterval = intervals.reduce(0, +) / Double(intervals.count)
        let tappedBPM = 60.0 / averageInterval

        setTargetBPM(tappedBPM)
    }

    /// Clear tap tempo history
    public func clearTapTempo() {
        tapTimes.removeAll()
    }

    // MARK: - Helpers

    private func interpolate(from: Double, to: Double, progress: Double) -> Double {
        from + (to - from) * progress
    }

    private func easeInOutCubic(_ t: Double) -> Double {
        t < 0.5
            ? 4 * t * t * t
            : 1 - pow(-2 * t + 2, 3) / 2
    }

    // MARK: - Snapshot

    /// Get current state snapshot
    public func getSnapshot() -> BPMSnapshot {
        BPMSnapshot(
            currentBPM: currentBPM,
            targetBPM: targetBPM,
            bioInfluence: bioInfluence,
            humanize: humanize,
            situation: situation,
            isLocked: lockState.isLocked,
            isTransitioning: isTransitioning
        )
    }
}

// MARK: - Snapshot

public struct BPMSnapshot {
    public let currentBPM: Double
    public let targetBPM: Double
    public let bioInfluence: Double
    public let humanize: Double
    public let situation: BPMSituation
    public let isLocked: Bool
    public let isTransitioning: Bool
}

// MARK: - SwiftUI View

/// BPM Control Panel View
public struct BPMControlView: View {
    @ObservedObject var engine: BPMTransitionEngine
    @State private var showSituationPicker = false

    public init(engine: BPMTransitionEngine) {
        self.engine = engine
    }

    public var body: some View {
        VStack(spacing: EchoelSpacing.md) {
            // Current BPM Display
            HStack {
                VStack(alignment: .leading) {
                    Text("BPM")
                        .font(EchoelBrandFont.label())
                        .foregroundColor(EchoelBrand.textTertiary)
                    Text(String(format: "%.1f", engine.currentBPM))
                        .font(EchoelBrandFont.data())
                        .foregroundColor(EchoelBrand.primary)
                }

                Spacer()

                // Lock Button
                Button(action: { engine.toggleLock() }) {
                    Image(systemName: engine.lockState.isLocked ? "lock.fill" : "lock.open")
                        .font(.title2)
                        .foregroundColor(engine.lockState.isLocked ? EchoelBrand.primary : EchoelBrand.textTertiary)
                }

                // Situation Picker
                Button(action: { showSituationPicker.toggle() }) {
                    HStack {
                        Text(engine.situation.rawValue)
                            .font(EchoelBrandFont.caption())
                        Image(systemName: "chevron.down")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(EchoelBrand.bgGlass)
                    .cornerRadius(EchoelRadius.sm)
                }
            }

            // Target BPM Slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Target")
                        .font(EchoelBrandFont.label())
                    Spacer()
                    Text(String(format: "%.0f", engine.targetBPM))
                        .font(EchoelBrandFont.dataSmall())
                }
                .foregroundColor(EchoelBrand.textSecondary)

                Slider(value: $engine.targetBPM, in: engine.minBPM...engine.maxBPM)
                    .accentColor(EchoelBrand.primary)
                    .disabled(engine.lockState.isLocked)
            }

            // Bio Influence Slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Bio Influence")
                        .font(EchoelBrandFont.label())
                    Spacer()
                    Text(String(format: "%.0f%%", engine.bioInfluence * 100))
                        .font(EchoelBrandFont.dataSmall())
                }
                .foregroundColor(EchoelBrand.textSecondary)

                Slider(value: $engine.bioInfluence, in: 0...1)
                    .accentColor(EchoelBrand.accent)
            }

            // Humanize Slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Humanize")
                        .font(EchoelBrandFont.label())
                    Spacer()
                    Text(String(format: "%.0f%%", engine.humanize * 100))
                        .font(EchoelBrandFont.dataSmall())
                }
                .foregroundColor(EchoelBrand.textSecondary)

                Slider(value: $engine.humanize, in: 0...1)
                    .accentColor(EchoelBrand.secondary)
            }

            // Tap Tempo Button
            Button(action: { engine.tap() }) {
                Text("TAP")
                    .font(EchoelBrandFont.body().weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(EchoelBrand.bgSurface)
                    .cornerRadius(EchoelRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: EchoelRadius.md)
                            .stroke(EchoelBrand.border, lineWidth: 1)
                    )
            }
        }
        .padding()
        .echoelCard()
        .sheet(isPresented: $showSituationPicker) {
            SituationPickerView(engine: engine, isPresented: $showSituationPicker)
        }
    }
}

// MARK: - Situation Picker

private struct SituationPickerView: View {
    @ObservedObject var engine: BPMTransitionEngine
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            List(BPMSituation.allCases) { situation in
                Button(action: {
                    engine.situation = situation
                    isPresented = false
                }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(situation.rawValue)
                                .font(EchoelBrandFont.body())
                            Text("\(Int(situation.bpmRange.lowerBound))-\(Int(situation.bpmRange.upperBound)) BPM")
                                .font(EchoelBrandFont.caption())
                                .foregroundColor(EchoelBrand.textTertiary)
                        }
                        Spacer()
                        if engine.situation == situation {
                            Image(systemName: "checkmark")
                                .foregroundColor(EchoelBrand.primary)
                        }
                    }
                }
                .foregroundColor(EchoelBrand.textPrimary)
            }
            .navigationTitle("Situation")
            .navigationBarItems(trailing: Button("Done") {
                isPresented = false
            })
        }
    }
}

// MARK: - Integration Extension

extension BPMTransitionEngine {
    /// Connect to UnifiedControlHub bio data
    public func connectToBioData(heartRate: Published<Double>.Publisher, coherence: Published<Double>.Publisher) {
        heartRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hr in
                self?.updateBioSource(heartRate: hr)
            }
            .store(in: &cancellables)

        coherence
            .receive(on: DispatchQueue.main)
            .sink { [weak self] coh in
                // Only use coherence if no heart rate available
                if self?.bioSourceBPM == 70 {
                    self?.updateBioSource(coherence: coh)
                }
            }
            .store(in: &cancellables)
    }
}
