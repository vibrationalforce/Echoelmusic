// SPDX-License-Identifier: MIT
// Copyright 2026 Echoelmusic
// Inspired by Aiode's 4-Page Workflow - Adapted for Bio-Reactive Creation

import Foundation
import SwiftUI
import Combine

// MARK: - Bio-Creative Workflow Engine
/// 4-Page workflow adapted from Aiode's concept for bio-reactive content creation
/// Pages: Bio-Sources → Composition → Bio-React → Publish
@MainActor
public final class BioCreativeWorkflow: ObservableObject {

    public static let shared = BioCreativeWorkflow()

    // MARK: - Workflow State

    @Published public var currentPage: WorkflowPage = .bioSources
    @Published public var project: BioProject?
    @Published public var isProcessing: Bool = false

    // MARK: - Page Definitions

    public enum WorkflowPage: Int, CaseIterable, Identifiable {
        case bioSources = 0     // Choose bio inputs (HRV, breath, gesture, face)
        case composition = 1    // Arrange audio, video, visuals, light
        case bioReact = 2       // Fine-tune bio-modulation per region
        case publish = 3        // Mix, stream, social share

        public var id: Int { rawValue }

        public var title: String {
            switch self {
            case .bioSources: return "Bio-Sources"
            case .composition: return "Composition"
            case .bioReact: return "Bio-React"
            case .publish: return "Publish"
            }
        }

        public var subtitle: String {
            switch self {
            case .bioSources: return "Choose your bio inputs"
            case .composition: return "Arrange your content"
            case .bioReact: return "Fine-tune bio-modulation"
            case .publish: return "Share with the world"
            }
        }

        public var icon: String {
            switch self {
            case .bioSources: return "heart.text.square"
            case .composition: return "square.stack.3d.up"
            case .bioReact: return "waveform.path.ecg"
            case .publish: return "paperplane.fill"
            }
        }

        public var color: Color {
            switch self {
            case .bioSources: return .pink
            case .composition: return .blue
            case .bioReact: return .green
            case .publish: return .orange
            }
        }
    }

    // MARK: - Bio Project Model

    public struct BioProject: Identifiable, Codable {
        public let id: UUID
        public var name: String
        public var createdAt: Date
        public var modifiedAt: Date

        // Page 1: Bio-Sources
        public var bioSources: BioSourceConfiguration

        // Page 2: Composition
        public var tracks: [Track]
        public var regions: [Region]

        // Page 3: Bio-React
        public var bioMappings: [BioMapping]
        public var regionBioSettings: [UUID: RegionBioSettings]

        // Page 4: Publish
        public var exportSettings: ExportSettings
        public var publishTargets: [PublishTarget]

        public init(name: String) {
            self.id = UUID()
            self.name = name
            self.createdAt = Date()
            self.modifiedAt = Date()
            self.bioSources = BioSourceConfiguration()
            self.tracks = []
            self.regions = []
            self.bioMappings = []
            self.regionBioSettings = [:]
            self.exportSettings = ExportSettings()
            self.publishTargets = []
        }
    }

    // MARK: - Page 1: Bio-Sources Configuration

    public struct BioSourceConfiguration: Codable {
        public var heartRateEnabled: Bool = true
        public var hrvEnabled: Bool = true
        public var breathingEnabled: Bool = true
        public var gestureEnabled: Bool = false
        public var faceTrackingEnabled: Bool = false
        public var gazeTrackingEnabled: Bool = false
        public var voiceEnabled: Bool = false

        // Source weights (0-1)
        public var heartRateWeight: Double = 1.0
        public var hrvWeight: Double = 1.0
        public var breathingWeight: Double = 0.8
        public var gestureWeight: Double = 0.5
        public var faceWeight: Double = 0.5
        public var gazeWeight: Double = 0.3
        public var voiceWeight: Double = 0.6

        // Device preferences
        public var preferredHRDevice: String = "Apple Watch"
        public var useExternalSensors: Bool = false

        public var enabledSources: [String] {
            var sources: [String] = []
            if heartRateEnabled { sources.append("Heart Rate") }
            if hrvEnabled { sources.append("HRV") }
            if breathingEnabled { sources.append("Breathing") }
            if gestureEnabled { sources.append("Gesture") }
            if faceTrackingEnabled { sources.append("Face") }
            if gazeTrackingEnabled { sources.append("Gaze") }
            if voiceEnabled { sources.append("Voice") }
            return sources
        }
    }

    // MARK: - Page 2: Composition

    public struct Track: Identifiable, Codable {
        public let id: UUID
        public var name: String
        public var type: TrackType
        public var isMuted: Bool = false
        public var isSolo: Bool = false
        public var volume: Double = 1.0
        public var pan: Double = 0.0

        public enum TrackType: String, Codable, CaseIterable {
            case audio = "Audio"
            case video = "Video"
            case visual = "Visual"
            case light = "Light"
            case laser = "Laser"
            case midi = "MIDI"
        }
    }

    public struct Region: Identifiable, Codable {
        public let id: UUID
        public var trackId: UUID
        public var name: String
        public var startTime: TimeInterval
        public var duration: TimeInterval
        public var color: String
        public var contentPath: String?

        // Bio-snapshot captured when region was created
        public var bioSnapshot: BioSnapshot?

        public var endTime: TimeInterval {
            startTime + duration
        }
    }

    public struct BioSnapshot: Codable {
        public let capturedAt: Date
        public let heartRate: Double
        public let hrvCoherence: Double
        public let breathingRate: Double
        public let breathPhase: Double // 0-1, 0=inhale start, 0.5=exhale start
        public let emotionalState: String?

        public var coherenceLevel: CoherenceLevel {
            if hrvCoherence >= 0.8 { return .high }
            if hrvCoherence >= 0.5 { return .medium }
            return .low
        }

        public enum CoherenceLevel: String, Codable {
            case high = "High Coherence"
            case medium = "Medium Coherence"
            case low = "Low Coherence"
        }
    }

    // MARK: - Page 3: Bio-React (Precision Bio-Editing)

    public struct BioMapping: Identifiable, Codable {
        public let id: UUID
        public var source: BioSource
        public var target: MappingTarget
        public var curve: MappingCurve
        public var intensity: Double = 1.0
        public var isEnabled: Bool = true

        public enum BioSource: String, Codable, CaseIterable {
            case heartRate = "Heart Rate"
            case hrvCoherence = "HRV Coherence"
            case breathingRate = "Breathing Rate"
            case breathPhase = "Breath Phase"
            case gestureIntensity = "Gesture Intensity"
            case facialExpression = "Facial Expression"
            case gazePosition = "Gaze Position"
            case voicePitch = "Voice Pitch"
        }

        public enum MappingTarget: String, Codable, CaseIterable {
            // Audio
            case tempo = "Tempo"
            case filterCutoff = "Filter Cutoff"
            case reverbMix = "Reverb Mix"
            case delayFeedback = "Delay Feedback"
            case volume = "Volume"
            case pan = "Pan"

            // Visual
            case visualIntensity = "Visual Intensity"
            case colorHue = "Color Hue"
            case particleDensity = "Particle Density"
            case geometryComplexity = "Geometry Complexity"

            // Light
            case lightIntensity = "Light Intensity"
            case lightColor = "Light Color"
            case strobeRate = "Strobe Rate"

            // Laser
            case laserSpeed = "Laser Speed"
            case laserPattern = "Laser Pattern"
        }

        public enum MappingCurve: String, Codable, CaseIterable {
            case linear = "Linear"
            case exponential = "Exponential"
            case logarithmic = "Logarithmic"
            case sCurve = "S-Curve"
            case sine = "Sine"
            case stepped = "Stepped"
        }
    }

    public struct RegionBioSettings: Codable {
        public var targetCoherence: Double = 0.7 // Target coherence for this region
        public var bioIntensity: Double = 1.0    // How strongly bio affects this region
        public var breathSync: Bool = true       // Sync to breath cycle
        public var emotionalTarget: String?      // "calm", "energetic", "focused"

        // Precision editing: regenerate with specific bio feel
        public var regenerationPreset: RegenerationPreset?

        public enum RegenerationPreset: String, Codable, CaseIterable {
            case highCoherence = "High Coherence Feel"
            case calmBreathing = "Calm Breathing Pattern"
            case energeticPulse = "Energetic Pulse"
            case focusedFlow = "Focused Flow"
            case meditativeDepth = "Meditative Depth"
        }
    }

    // MARK: - Page 4: Publish

    public struct ExportSettings: Codable {
        public var audioFormat: AudioFormat = .wav
        public var videoFormat: VideoFormat = .mp4
        public var sampleRate: Int = 48000
        public var bitDepth: Int = 24
        public var videoResolution: VideoResolution = .hd1080
        public var frameRate: Int = 60
        public var includeBioOverlay: Bool = false
        public var includeSTEMs: Bool = false

        public enum AudioFormat: String, Codable, CaseIterable {
            case wav = "WAV"
            case aiff = "AIFF"
            case mp3 = "MP3"
            case flac = "FLAC"
        }

        public enum VideoFormat: String, Codable, CaseIterable {
            case mp4 = "MP4 (H.264)"
            case mov = "MOV (ProRes)"
            case webm = "WebM"
        }

        public enum VideoResolution: String, Codable, CaseIterable {
            case hd720 = "720p"
            case hd1080 = "1080p"
            case uhd4k = "4K UHD"
            case uhd8k = "8K UHD"
        }
    }

    public struct PublishTarget: Identifiable, Codable {
        public let id: UUID
        public var platform: Platform
        public var isEnabled: Bool = true
        public var customTitle: String?
        public var customDescription: String?

        public enum Platform: String, Codable, CaseIterable {
            case youtube = "YouTube"
            case instagram = "Instagram"
            case tiktok = "TikTok"
            case twitch = "Twitch"
            case soundcloud = "SoundCloud"
            case spotify = "Spotify"
            case local = "Local Export"
        }
    }

    // MARK: - Workflow Navigation

    public func nextPage() {
        guard let next = WorkflowPage(rawValue: currentPage.rawValue + 1) else { return }
        currentPage = next
    }

    public func previousPage() {
        guard let prev = WorkflowPage(rawValue: currentPage.rawValue - 1) else { return }
        currentPage = prev
    }

    public func goToPage(_ page: WorkflowPage) {
        currentPage = page
    }

    // MARK: - Project Management

    public func createProject(name: String) {
        project = BioProject(name: name)
        currentPage = .bioSources
    }

    public func saveProject() {
        guard var proj = project else { return }
        proj.modifiedAt = Date()
        project = proj
        // Persist to storage
    }

    // MARK: - Bio-Snapshot Capture

    public func captureBioSnapshot() -> BioSnapshot {
        // In production: Get real values from HealthKitManager
        BioSnapshot(
            capturedAt: Date(),
            heartRate: 72,
            hrvCoherence: 0.75,
            breathingRate: 12,
            breathPhase: 0.3,
            emotionalState: "focused"
        )
    }

    // MARK: - Region Creation with Bio

    public func createRegion(on trackId: UUID, at startTime: TimeInterval, duration: TimeInterval, name: String) {
        guard project != nil else { return }

        let region = Region(
            id: UUID(),
            trackId: trackId,
            name: name,
            startTime: startTime,
            duration: duration,
            color: "#22C55E",
            contentPath: nil,
            bioSnapshot: captureBioSnapshot()
        )

        project?.regions.append(region)
    }
}

// MARK: - Workflow View

public struct BioCreativeWorkflowView: View {
    @ObservedObject private var workflow = BioCreativeWorkflow.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Page Navigation Bar
            pageNavigationBar

            // Current Page Content
            currentPageContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Bottom Navigation
            bottomNavigation
        }
        .background(Color(.systemBackground))
    }

    private var pageNavigationBar: some View {
        HStack(spacing: 0) {
            ForEach(BioCreativeWorkflow.WorkflowPage.allCases) { page in
                pageTab(page)
            }
        }
        .background(Color(.secondarySystemBackground))
    }

    private func pageTab(_ page: BioCreativeWorkflow.WorkflowPage) -> some View {
        Button {
            workflow.goToPage(page)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: page.icon)
                    .font(.title3)
                Text(page.title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(workflow.currentPage == page ? page.color.opacity(0.2) : Color.clear)
            .foregroundStyle(workflow.currentPage == page ? page.color : .secondary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var currentPageContent: some View {
        switch workflow.currentPage {
        case .bioSources:
            BioSourcesPageView()
        case .composition:
            CompositionPageView()
        case .bioReact:
            BioReactPageView()
        case .publish:
            PublishPageView()
        }
    }

    private var bottomNavigation: some View {
        HStack {
            if workflow.currentPage.rawValue > 0 {
                Button {
                    workflow.previousPage()
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            if workflow.currentPage.rawValue < BioCreativeWorkflow.WorkflowPage.allCases.count - 1 {
                Button {
                    workflow.nextPage()
                } label: {
                    HStack {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(workflow.currentPage.color)
            } else {
                Button {
                    // Export/Publish action
                } label: {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("Publish")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
}

// MARK: - Page Views (Stubs)

struct BioSourcesPageView: View {
    @ObservedObject private var workflow = BioCreativeWorkflow.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Select Bio-Sources")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Choose which biometric inputs drive your creation")
                    .foregroundStyle(.secondary)

                // Bio source toggles would go here
                GroupBox("Primary Sources") {
                    VStack(spacing: 12) {
                        bioSourceRow(icon: "heart.fill", name: "Heart Rate", isEnabled: true)
                        bioSourceRow(icon: "waveform.path.ecg", name: "HRV Coherence", isEnabled: true)
                        bioSourceRow(icon: "wind", name: "Breathing", isEnabled: true)
                    }
                }

                GroupBox("Advanced Sources") {
                    VStack(spacing: 12) {
                        bioSourceRow(icon: "hand.raised", name: "Gesture", isEnabled: false)
                        bioSourceRow(icon: "face.smiling", name: "Face Tracking", isEnabled: false)
                        bioSourceRow(icon: "eye", name: "Gaze Tracking", isEnabled: false)
                        bioSourceRow(icon: "mic", name: "Voice", isEnabled: false)
                    }
                }
            }
            .padding()
        }
    }

    private func bioSourceRow(icon: String, name: String, isEnabled: Bool) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(isEnabled ? .green : .secondary)
                .frame(width: 24)
            Text(name)
            Spacer()
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isEnabled ? .green : .secondary)
        }
    }
}

struct CompositionPageView: View {
    var body: some View {
        VStack {
            Text("Composition")
                .font(.title2)
            Text("Arrange Audio, Video, Visuals & Light")
                .foregroundStyle(.secondary)

            // Timeline/arrangement view would go here
            Spacer()

            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemBackground))
                .frame(height: 200)
                .overlay(
                    Text("Timeline View")
                        .foregroundStyle(.secondary)
                )
                .padding()
        }
    }
}

struct BioReactPageView: View {
    var body: some View {
        VStack {
            Text("Bio-React")
                .font(.title2)
            Text("Fine-tune bio-modulation per region")
                .foregroundStyle(.secondary)

            // Bio-mapping controls would go here
            Spacer()
        }
    }
}

struct PublishPageView: View {
    var body: some View {
        VStack {
            Text("Publish")
                .font(.title2)
            Text("Export and share your creation")
                .foregroundStyle(.secondary)

            // Export/publish controls would go here
            Spacer()
        }
    }
}

#Preview {
    BioCreativeWorkflowView()
}
