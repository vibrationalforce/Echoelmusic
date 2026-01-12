// SPDX-License-Identifier: MIT
// Copyright 2026 Echoelmusic
// Inspired by Aiode's Precision Editing - Adapted for Bio-Reactive Region Control

import Foundation
import SwiftUI
import Combine

// MARK: - Precision Bio-Editor
/// Region-based bio-modulation editing - regenerate sections with specific bio-feel
/// Similar to Aiode's punch-in style regeneration, but driven by biometrics
@MainActor
public final class PrecisionBioEditor: ObservableObject {

    public static let shared = PrecisionBioEditor()

    // MARK: - State

    @Published public var selectedRegion: EditableRegion?
    @Published public var generatedTakes: [BioTake] = []
    @Published public var isGenerating: Bool = false
    @Published public var currentBioState: LiveBioState = LiveBioState()

    // MARK: - Configuration

    public let maxTakesPerRegion: Int = 20 // Like Aiode's 20 takes
    public let defaultTakeCount: Int = 5

    // MARK: - Editable Region

    public struct EditableRegion: Identifiable {
        public let id: UUID
        public var name: String
        public var startTime: TimeInterval
        public var duration: TimeInterval
        public var trackType: TrackType
        public var originalContent: Data?

        // Bio settings for this region
        public var bioSettings: RegionBioSettings

        public enum TrackType: String, CaseIterable {
            case audio = "Audio"
            case video = "Video"
            case visual = "Visual"
            case light = "Light"
            case laser = "Laser"
            case midi = "MIDI"
        }

        public init(
            id: UUID = UUID(),
            name: String,
            startTime: TimeInterval,
            duration: TimeInterval,
            trackType: TrackType
        ) {
            self.id = id
            self.name = name
            self.startTime = startTime
            self.duration = duration
            self.trackType = trackType
            self.bioSettings = RegionBioSettings()
        }
    }

    // MARK: - Region Bio Settings

    public struct RegionBioSettings: Codable {
        // Target bio-feel for this region
        public var targetCoherence: Double = 0.7
        public var targetEnergy: Double = 0.5
        public var breathSyncEnabled: Bool = true
        public var heartSyncEnabled: Bool = true

        // Bio-modulation intensity
        public var bioIntensity: Double = 1.0

        // Emotional target
        public var emotionalTarget: EmotionalTarget = .neutral

        // Regeneration preset
        public var regenerationPreset: RegenerationPreset?

        public enum EmotionalTarget: String, Codable, CaseIterable {
            case calm = "Calm"
            case focused = "Focused"
            case energetic = "Energetic"
            case meditative = "Meditative"
            case joyful = "Joyful"
            case intense = "Intense"
            case neutral = "Neutral"

            public var icon: String {
                switch self {
                case .calm: return "leaf.fill"
                case .focused: return "target"
                case .energetic: return "bolt.fill"
                case .meditative: return "moon.stars.fill"
                case .joyful: return "sun.max.fill"
                case .intense: return "flame.fill"
                case .neutral: return "circle"
                }
            }

            public var color: String {
                switch self {
                case .calm: return "#22C55E"      // Bio-Green
                case .focused: return "#3B82F6"   // Blue
                case .energetic: return "#F59E0B" // Amber
                case .meditative: return "#8B5CF6" // Purple
                case .joyful: return "#EC4899"    // Pink
                case .intense: return "#EF4444"   // Red
                case .neutral: return "#6B7280"   // Gray
                }
            }

            public var coherenceRange: ClosedRange<Double> {
                switch self {
                case .calm: return 0.7...1.0
                case .focused: return 0.6...0.9
                case .energetic: return 0.3...0.6
                case .meditative: return 0.8...1.0
                case .joyful: return 0.5...0.8
                case .intense: return 0.2...0.5
                case .neutral: return 0.4...0.7
                }
            }
        }

        public enum RegenerationPreset: String, Codable, CaseIterable {
            case highCoherence = "High Coherence Feel"
            case calmBreathing = "Calm Breathing Pattern"
            case energeticPulse = "Energetic Pulse"
            case focusedFlow = "Focused Flow State"
            case meditativeDepth = "Meditative Depth"
            case heartSync = "Heart-Synchronized"
            case breathWave = "Breath Wave"
            case naturalRhythm = "Natural Body Rhythm"

            public var description: String {
                switch self {
                case .highCoherence:
                    return "Regenerate with high HRV coherence characteristics - smooth, harmonious"
                case .calmBreathing:
                    return "Apply calm 6-breath-per-minute pattern influence"
                case .energeticPulse:
                    return "Add energetic pulse based on elevated heart rate"
                case .focusedFlow:
                    return "Optimize for flow state with balanced bio-metrics"
                case .meditativeDepth:
                    return "Deep, slow modulation for meditative content"
                case .heartSync:
                    return "Synchronize content timing with heartbeat intervals"
                case .breathWave:
                    return "Modulate intensity with breath cycle (inhale=build, exhale=release)"
                case .naturalRhythm:
                    return "Use circadian and ultradian rhythm influences"
                }
            }

            public var targetSettings: (coherence: Double, energy: Double, breathSync: Bool) {
                switch self {
                case .highCoherence: return (0.9, 0.5, true)
                case .calmBreathing: return (0.8, 0.3, true)
                case .energeticPulse: return (0.5, 0.9, false)
                case .focusedFlow: return (0.75, 0.6, true)
                case .meditativeDepth: return (0.95, 0.2, true)
                case .heartSync: return (0.7, 0.5, false)
                case .breathWave: return (0.7, 0.5, true)
                case .naturalRhythm: return (0.6, 0.5, true)
                }
            }
        }
    }

    // MARK: - Bio Take (Generated Variation)

    public struct BioTake: Identifiable {
        public let id: UUID
        public let regionId: UUID
        public let takeNumber: Int
        public let generatedAt: Date

        // Bio snapshot when this take was generated
        public let bioSnapshot: BioSnapshot

        // Content reference
        public var contentPath: String?
        public var previewData: Data?

        // Quality metrics
        public var coherenceMatch: Double // How well it matches target coherence
        public var energyMatch: Double
        public var overallScore: Double

        // User rating
        public var userRating: Int? // 1-5 stars
        public var isSelected: Bool = false

        public struct BioSnapshot: Codable {
            public let heartRate: Double
            public let hrvCoherence: Double
            public let breathingRate: Double
            public let breathPhase: Double
            public let emotionalState: String
        }
    }

    // MARK: - Live Bio State

    public struct LiveBioState {
        public var heartRate: Double = 72
        public var hrvCoherence: Double = 0.7
        public var breathingRate: Double = 12
        public var breathPhase: Double = 0.5
        public var isConnected: Bool = false

        public var coherenceLevel: String {
            if hrvCoherence >= 0.8 { return "High" }
            if hrvCoherence >= 0.5 { return "Medium" }
            return "Low"
        }
    }

    // MARK: - Region Selection

    public func selectRegion(_ region: EditableRegion) {
        selectedRegion = region
        generatedTakes = []
    }

    public func deselectRegion() {
        selectedRegion = nil
        generatedTakes = []
    }

    // MARK: - Precision Bio-Regeneration

    /// Regenerate region with specific bio-feel (like Aiode's punch-in)
    public func regenerateWithBioFeel(
        preset: RegionBioSettings.RegenerationPreset,
        takeCount: Int = 5
    ) async throws {
        guard var region = selectedRegion else {
            throw PrecisionBioError.noRegionSelected
        }

        isGenerating = true
        defer { isGenerating = false }

        // Apply preset settings
        let targetSettings = preset.targetSettings
        region.bioSettings.targetCoherence = targetSettings.coherence
        region.bioSettings.targetEnergy = targetSettings.energy
        region.bioSettings.breathSyncEnabled = targetSettings.breathSync
        region.bioSettings.regenerationPreset = preset

        selectedRegion = region

        // Generate multiple takes
        var takes: [BioTake] = []

        for i in 1...min(takeCount, maxTakesPerRegion) {
            let take = try await generateTake(for: region, takeNumber: i)
            takes.append(take)

            // Small delay between generations
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        generatedTakes = takes.sorted { $0.overallScore > $1.overallScore }
    }

    /// Generate with current live bio-state
    public func regenerateWithLiveBio(takeCount: Int = 5) async throws {
        guard var region = selectedRegion else {
            throw PrecisionBioError.noRegionSelected
        }

        isGenerating = true
        defer { isGenerating = false }

        // Use current live bio state as target
        region.bioSettings.targetCoherence = currentBioState.hrvCoherence
        region.bioSettings.targetEnergy = mapHeartRateToEnergy(currentBioState.heartRate)

        selectedRegion = region

        var takes: [BioTake] = []

        for i in 1...min(takeCount, maxTakesPerRegion) {
            let take = try await generateTake(for: region, takeNumber: i)
            takes.append(take)
        }

        generatedTakes = takes.sorted { $0.overallScore > $1.overallScore }
    }

    /// Generate with custom settings
    public func regenerateWithCustomSettings(
        coherence: Double,
        energy: Double,
        emotionalTarget: RegionBioSettings.EmotionalTarget,
        takeCount: Int = 5
    ) async throws {
        guard var region = selectedRegion else {
            throw PrecisionBioError.noRegionSelected
        }

        isGenerating = true
        defer { isGenerating = false }

        region.bioSettings.targetCoherence = coherence
        region.bioSettings.targetEnergy = energy
        region.bioSettings.emotionalTarget = emotionalTarget

        selectedRegion = region

        var takes: [BioTake] = []

        for i in 1...min(takeCount, maxTakesPerRegion) {
            let take = try await generateTake(for: region, takeNumber: i)
            takes.append(take)
        }

        generatedTakes = takes.sorted { $0.overallScore > $1.overallScore }
    }

    // MARK: - Take Generation

    private func generateTake(for region: EditableRegion, takeNumber: Int) async throws -> BioTake {
        // Simulate bio-influenced content generation
        // In production: Actually regenerate audio/video/visual with bio parameters

        let settings = region.bioSettings

        // Generate with slight variation around target
        let coherenceVariation = Double.random(in: -0.1...0.1)
        let energyVariation = Double.random(in: -0.1...0.1)

        let achievedCoherence = max(0, min(1, settings.targetCoherence + coherenceVariation))
        let achievedEnergy = max(0, min(1, settings.targetEnergy + energyVariation))

        // Calculate how well this take matches the target
        let coherenceMatch = 1.0 - abs(settings.targetCoherence - achievedCoherence)
        let energyMatch = 1.0 - abs(settings.targetEnergy - achievedEnergy)
        let overallScore = (coherenceMatch * 0.6) + (energyMatch * 0.4)

        return BioTake(
            id: UUID(),
            regionId: region.id,
            takeNumber: takeNumber,
            generatedAt: Date(),
            bioSnapshot: BioTake.BioSnapshot(
                heartRate: 60 + (achievedEnergy * 60), // 60-120 BPM based on energy
                hrvCoherence: achievedCoherence,
                breathingRate: 6 + (achievedEnergy * 12), // 6-18 breaths/min
                breathPhase: Double.random(in: 0...1),
                emotionalState: settings.emotionalTarget.rawValue
            ),
            contentPath: nil,
            previewData: nil,
            coherenceMatch: coherenceMatch,
            energyMatch: energyMatch,
            overallScore: overallScore
        )
    }

    // MARK: - Take Selection

    public func selectTake(_ take: BioTake) {
        for i in generatedTakes.indices {
            generatedTakes[i].isSelected = (generatedTakes[i].id == take.id)
        }
    }

    public func rateTake(_ take: BioTake, rating: Int) {
        guard let index = generatedTakes.firstIndex(where: { $0.id == take.id }) else { return }
        generatedTakes[index].userRating = rating
    }

    public func applySelectedTake() throws {
        guard let selected = generatedTakes.first(where: { $0.isSelected }) else {
            throw PrecisionBioError.noTakeSelected
        }

        // Apply the selected take to the region
        // In production: Replace region content with selected take
        print("Applied take \(selected.takeNumber) to region")
    }

    // MARK: - Helpers

    private func mapHeartRateToEnergy(_ heartRate: Double) -> Double {
        // Map heart rate (40-180) to energy (0-1)
        let normalized = (heartRate - 40) / 140
        return max(0, min(1, normalized))
    }

    // MARK: - Errors

    public enum PrecisionBioError: LocalizedError {
        case noRegionSelected
        case noTakeSelected
        case generationFailed(String)

        public var errorDescription: String? {
            switch self {
            case .noRegionSelected:
                return "No region selected for editing"
            case .noTakeSelected:
                return "No take selected to apply"
            case .generationFailed(let reason):
                return "Generation failed: \(reason)"
            }
        }
    }
}

// MARK: - Precision Bio-Editor View

public struct PrecisionBioEditorView: View {
    @ObservedObject private var editor = PrecisionBioEditor.shared
    @State private var selectedPreset: PrecisionBioEditor.RegionBioSettings.RegenerationPreset?
    @State private var customCoherence: Double = 0.7
    @State private var customEnergy: Double = 0.5
    @State private var takeCount: Double = 5

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let region = editor.selectedRegion {
                    // Region Info Header
                    regionHeader(region)

                    Divider()

                    ScrollView {
                        VStack(spacing: 20) {
                            // Bio-Feel Presets
                            presetSection

                            // Custom Settings
                            customSettingsSection

                            // Generated Takes
                            if !editor.generatedTakes.isEmpty {
                                takesSection
                            }
                        }
                        .padding()
                    }

                    // Bottom Actions
                    bottomActions
                } else {
                    emptyState
                }
            }
            .navigationTitle("Precision Bio-Editor")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func regionHeader(_ region: PrecisionBioEditor.EditableRegion) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(region.name)
                    .font(.headline)
                HStack(spacing: 12) {
                    Label(formatTime(region.startTime), systemImage: "clock")
                    Label(formatDuration(region.duration), systemImage: "timer")
                    Label(region.trackType.rawValue, systemImage: "waveform")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: region.bioSettings.emotionalTarget.icon)
                .font(.title2)
                .foregroundStyle(Color(hex: region.bioSettings.emotionalTarget.color) ?? .green)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bio-Feel Presets")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(PrecisionBioEditor.RegionBioSettings.RegenerationPreset.allCases, id: \.self) { preset in
                    presetButton(preset)
                }
            }
        }
    }

    private func presetButton(_ preset: PrecisionBioEditor.RegionBioSettings.RegenerationPreset) -> some View {
        Button {
            selectedPreset = preset
            Task {
                try? await editor.regenerateWithBioFeel(preset: preset, takeCount: Int(takeCount))
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(preset.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(preset.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(selectedPreset == preset ? Color.green.opacity(0.2) : Color(.tertiarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedPreset == preset ? Color.green : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(editor.isGenerating)
    }

    private var customSettingsSection: some View {
        GroupBox("Custom Settings") {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Target Coherence")
                        Spacer()
                        Text("\(Int(customCoherence * 100))%")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $customCoherence, in: 0...1)
                        .tint(.green)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Energy Level")
                        Spacer()
                        Text("\(Int(customEnergy * 100))%")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $customEnergy, in: 0...1)
                        .tint(.orange)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Takes to Generate")
                        Spacer()
                        Text("\(Int(takeCount))")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $takeCount, in: 1...Double(editor.maxTakesPerRegion), step: 1)
                        .tint(.blue)
                }

                Button {
                    Task {
                        try? await editor.regenerateWithCustomSettings(
                            coherence: customCoherence,
                            energy: customEnergy,
                            emotionalTarget: .neutral,
                            takeCount: Int(takeCount)
                        )
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Generate with Custom Settings")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(editor.isGenerating)
            }
        }
    }

    private var takesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Generated Takes")
                    .font(.headline)
                Spacer()
                Text("\(editor.generatedTakes.count) takes")
                    .foregroundStyle(.secondary)
            }

            ForEach(editor.generatedTakes) { take in
                takeRow(take)
            }
        }
    }

    private func takeRow(_ take: PrecisionBioEditor.BioTake) -> some View {
        Button {
            editor.selectTake(take)
        } label: {
            HStack {
                // Take number
                Text("#\(take.takeNumber)")
                    .font(.headline)
                    .frame(width: 40)

                // Score visualization
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        scoreBar(value: take.coherenceMatch, color: .green, label: "Coherence")
                        scoreBar(value: take.energyMatch, color: .orange, label: "Energy")
                    }
                    Text("Score: \(Int(take.overallScore * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Selection indicator
                if take.isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .padding(12)
            .background(take.isSelected ? Color.green.opacity(0.1) : Color(.tertiarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(take.isSelected ? Color.green : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func scoreBar(value: Double, color: Color, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(color.opacity(0.2))
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * value)
                }
            }
            .frame(height: 8)
            .cornerRadius(4)
        }
        .frame(width: 80)
    }

    private var bottomActions: some View {
        HStack {
            Button {
                Task {
                    try? await editor.regenerateWithLiveBio(takeCount: Int(takeCount))
                }
            } label: {
                HStack {
                    Image(systemName: "heart.fill")
                    Text("Use Live Bio")
                }
            }
            .buttonStyle(.bordered)
            .disabled(editor.isGenerating || !editor.currentBioState.isConnected)

            Spacer()

            Button {
                try? editor.applySelectedTake()
            } label: {
                HStack {
                    Image(systemName: "checkmark")
                    Text("Apply Take")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(editor.generatedTakes.filter { $0.isSelected }.isEmpty)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.path.ecg.rectangle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No Region Selected")
                .font(.title2)
            Text("Select a region in the timeline to edit with bio-precision")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Helpers

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        return String(format: "%.1fs", duration)
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}

#Preview {
    PrecisionBioEditorView()
}
