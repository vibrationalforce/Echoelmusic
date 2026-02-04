// Phase8000Views.swift
// Echoelmusic - 8000% MAXIMUM OVERDRIVE MODE
//
// Comprehensive SwiftUI views for all Phase 2000+ engines
// Video, Creative, Science, Wellness, Collaboration, Developer
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

import SwiftUI
import Combine

// MARK: - Video Processing View

/// Complete video processing interface
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
public struct VideoProcessingView: View {
    @StateObject private var engine = VideoProcessingEngine()
    @State private var selectedResolution: VideoResolution = .uhd4k
    @State private var selectedFrameRate: VideoFrameRate = .smooth60
    @State private var showingEffectPicker = false
    @State private var isRecording = false

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Video Preview
                videoPreviewSection

                // Controls
                controlsSection

                // Effects Bar
                effectsBar

                // Stats
                statsSection
            }
            .navigationTitle("Video Studio")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        ForEach(VideoResolution.allCases, id: \.self) { res in
                            Button(res.rawValue) {
                                selectedResolution = res
                                engine.outputResolution = res
                            }
                        }
                    } label: {
                        Label(selectedResolution.rawValue, systemImage: "aspectratio")
                    }
                }
            }
        }
    }

    private var videoPreviewSection: some View {
        ZStack {
            Rectangle()
                .fill(Color.black)
                .aspectRatio(16/9, contentMode: .fit)

            if engine.isRunning {
                // Quantum visualization overlay
                QuantumVideoOverlay(coherence: engine.stats.quantumCoherence)
            } else {
                VStack {
                    Image(systemName: "video.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("Tap Start to begin")
                        .foregroundColor(.gray)
                }
            }

            // Recording indicator
            if isRecording {
                VStack {
                    HStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                        Text("REC")
                            .font(.caption.bold())
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding()
                    Spacer()
                }
            }
        }
        .cornerRadius(12)
        .padding()
    }

    private var controlsSection: some View {
        HStack(spacing: 20) {
            // Start/Stop
            Button {
                if engine.isRunning {
                    engine.stop()
                } else {
                    engine.start()
                }
            } label: {
                Image(systemName: engine.isRunning ? "stop.fill" : "play.fill")
                    .font(.title)
                    .frame(width: 60, height: 60)
                    .background(engine.isRunning ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .clipShape(Circle())
            }

            // Record
            Button {
                isRecording.toggle()
            } label: {
                Image(systemName: isRecording ? "record.circle.fill" : "record.circle")
                    .font(.title)
                    .foregroundColor(isRecording ? .red : .primary)
            }

            // Effects
            Button {
                showingEffectPicker = true
            } label: {
                Image(systemName: "wand.and.stars")
                    .font(.title)
            }

            // Quantum Mode Toggle
            Toggle(isOn: $engine.quantumSyncEnabled) {
                Image(systemName: "atom")
            }
            .toggleStyle(.button)
        }
        .padding()
        .sheet(isPresented: $showingEffectPicker) {
            VideoEffectPicker(engine: engine)
        }
    }

    private var effectsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(engine.activeEffects, id: \.self) { effect in
                    EffectChip(effect: effect) {
                        engine.removeEffect(effect)
                    }
                }
                if engine.activeEffects.isEmpty {
                    Text("No effects active")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 44)
    }

    private var statsSection: some View {
        HStack {
            StatBadge(title: "FPS", value: String(format: "%.1f", engine.stats.currentFPS))
            StatBadge(title: "GPU", value: String(format: "%.0f%%", engine.stats.gpuUtilization * 100))
            StatBadge(title: "Latency", value: String(format: "%.1fms", engine.stats.processingLatency * 1000))
            StatBadge(title: "Coherence", value: String(format: "%.0f%%", engine.stats.quantumCoherence * 100))
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Creative Studio View

/// AI-powered creative studio interface
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
public struct CreativeStudioView: View {
    @StateObject private var engine = CreativeStudioEngine()
    @State private var prompt = ""
    @State private var selectedMode: CreativeMode = .generativeArt
    @State private var selectedStyle: ArtStyle = .quantumGenerated
    @State private var showingResult = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Mode Selection
                    modeSelector

                    // Style Selection
                    styleSelector

                    // Prompt Input
                    promptInput

                    // Generate Button
                    generateButton

                    // Progress
                    if engine.isProcessing {
                        progressSection
                    }

                    // Recent Results
                    recentResultsSection
                }
                .padding()
            }
            .navigationTitle("Creative Studio")
        }
    }

    private var modeSelector: some View {
        VStack(alignment: .leading) {
            Text("Creative Mode")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach([CreativeMode.generativeArt, .painting, .musicComposition, .fractals, .quantumArt], id: \.self) { mode in
                        ModeChip(mode: mode, isSelected: selectedMode == mode) {
                            selectedMode = mode
                            engine.selectedMode = mode
                        }
                    }
                }
            }
        }
    }

    private var styleSelector: some View {
        VStack(alignment: .leading) {
            Text("Art Style")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach([ArtStyle.quantumGenerated, .sacredGeometry, .cyberpunk, .impressionism, .photorealistic], id: \.self) { style in
                        StyleChip(style: style, isSelected: selectedStyle == style) {
                            selectedStyle = style
                            engine.selectedStyle = style
                        }
                    }
                }
            }
        }
    }

    private var promptInput: some View {
        VStack(alignment: .leading) {
            Text("Prompt")
                .font(.headline)
            TextField("Describe your creation...", text: $prompt, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
        }
    }

    private var generateButton: some View {
        Button {
            Task {
                _ = try? await engine.generateArt(prompt: prompt, style: selectedStyle)
            }
        } label: {
            HStack {
                Image(systemName: "sparkles")
                Text("Generate")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.purple)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(prompt.isEmpty || engine.isProcessing)
    }

    private var progressSection: some View {
        VStack {
            ProgressView(value: engine.generationProgress)
            Text("Generating... \(Int(engine.generationProgress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var recentResultsSection: some View {
        VStack(alignment: .leading) {
            Text("Recent Creations")
                .font(.headline)
            if engine.recentResults.isEmpty {
                Text("No creations yet")
                    .foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 10) {
                    ForEach(engine.recentResults.prefix(6)) { result in
                        CreationThumbnail(result: result)
                    }
                }
            }
        }
    }
}

// MARK: - Scientific Dashboard View

/// Scientific visualization and analysis dashboard
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
public struct ScientificDashboardView: View {
    @StateObject private var engine = ScientificVisualizationEngine()
    @State private var selectedVisualization: ScientificVisualizationType = .quantumField
    @State private var showingDataImport = false

    public init() {}

    public var body: some View {
        NavigationStack {
            scientificContent
                .navigationTitle("Scientific Lab")
                .toolbar {
                    ToolbarItem {
                        Button {
                            showingDataImport = true
                        } label: {
                            Label("Import Data", systemImage: "square.and.arrow.down")
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var scientificContent: some View {
        #if os(macOS)
        HSplitView {
            // Sidebar
            sidebarContent

            // Main visualization
            mainVisualization
        }
        #else
        HStack(spacing: 0) {
            // Sidebar
            sidebarContent
                .frame(width: 200)

            // Main visualization
            mainVisualization
        }
        #endif
    }

    private var sidebarContent: some View {
        List {
            Section("Visualizations") {
                ForEach([ScientificVisualizationType.quantumField, .waveFunction, .particleSystem, .molecularStructure, .galaxySimulation], id: \.self) { type in
                    Button {
                        selectedVisualization = type
                        engine.selectedVisualization = type
                    } label: {
                        Label(type.rawValue, systemImage: iconForVisualization(type))
                    }
                    .foregroundColor(selectedVisualization == type ? .accentColor : .primary)
                }
            }

            Section("Datasets (\(engine.datasets.count))") {
                ForEach(engine.datasets) { dataset in
                    HStack {
                        Text(dataset.name)
                        Spacer()
                        Text("\(dataset.count) pts")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }

            Section("Quantum") {
                Toggle("Quantum Simulation", isOn: $engine.quantumSimulationEnabled)
                Toggle("Real-Time Updates", isOn: $engine.realTimeUpdates)
            }
        }
        .frame(minWidth: 200, maxWidth: 300)
    }

    private var mainVisualization: some View {
        VStack {
            // Visualization canvas
            ZStack {
                Rectangle()
                    .fill(Color.black)

                QuantumFieldVisualization(type: selectedVisualization, engine: engine)
            }
            .cornerRadius(12)

            // Controls
            HStack {
                Button("Generate Data") {
                    _ = engine.generateSyntheticData(name: "Sample \(engine.datasets.count + 1)", type: .quantum, count: 500)
                }
                Button("Run Simulation") {
                    Task {
                        _ = await engine.simulateWaveEquation(parameters: .default)
                    }
                }
                Spacer()
                if engine.isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("\(Int(engine.simulationProgress * 100))%")
                }
            }
            .padding()
        }
    }

    private func iconForVisualization(_ type: ScientificVisualizationType) -> String {
        switch type {
        case .quantumField: return "atom"
        case .waveFunction: return "waveform"
        case .particleSystem: return "sparkles"
        case .molecularStructure: return "cube.transparent"
        case .galaxySimulation: return "sparkle"
        default: return "chart.xyaxis.line"
        }
    }
}

// MARK: - Collaboration Lobby View

/// Worldwide collaboration session browser and manager
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
public struct CollaborationLobbyView: View {
    @StateObject private var hub = WorldwideCollaborationHub()
    @State private var sessionCode = ""
    @State private var newSessionName = ""
    @State private var selectedMode: CollaborationMode = .musicJam
    @State private var showingCreateSession = false

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if hub.currentSession != nil {
                    CollaborationActiveSessionView(hub: hub)
                } else {
                    lobbyContent
                }
            }
            .navigationTitle("Collaboration")
            .task {
                try? await hub.connect()
            }
        }
    }

    private var lobbyContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Connection Status
                connectionStatus

                // Join Session
                joinSessionCard

                // Create Session
                createSessionCard

                // Browse Public Sessions
                publicSessionsSection

                // Stats
                globalStatsSection
            }
            .padding()
        }
    }

    private var connectionStatus: some View {
        HStack {
            Circle()
                .fill(hub.isConnected ? Color.green : Color.red)
                .frame(width: 12, height: 12)
            Text(hub.isConnected ? "Connected to \(hub.selectedRegion.rawValue)" : "Disconnected")
            Spacer()
            if let quality = hub.networkQuality {
                Text(quality.quality.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
    }

    private var joinSessionCard: some View {
        VStack(alignment: .leading) {
            Text("Join Session")
                .font(.headline)
            HStack {
                TextField("Enter code", text: $sessionCode)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.characters)
                Button("Join") {
                    Task {
                        try? await hub.joinSession(code: sessionCode)
                    }
                }
                .disabled(sessionCode.count != 6)
            }
        }
    }

    private var createSessionCard: some View {
        VStack(alignment: .leading) {
            Text("Create Session")
                .font(.headline)

            TextField("Session name", text: $newSessionName)
                .textFieldStyle(.roundedBorder)

            Picker("Mode", selection: $selectedMode) {
                ForEach([CollaborationMode.musicJam, .groupMeditation, .artCollaboration, .researchSession, .coherenceSync], id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Button {
                Task {
                    _ = try? await hub.createSession(name: newSessionName, mode: selectedMode)
                }
            } label: {
                Text("Create Session")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(newSessionName.isEmpty)
        }
    }

    private var publicSessionsSection: some View {
        VStack(alignment: .leading) {
            Text("Public Sessions")
                .font(.headline)
            Text("Join open sessions from around the world")
                .font(.caption)
                .foregroundColor(.secondary)

            // This would show browsed sessions
            Text("Tap to browse...")
                .foregroundColor(.blue)
        }
    }

    private var globalStatsSection: some View {
        VStack(alignment: .leading) {
            Text("Global Activity")
                .font(.headline)
            HStack {
                Phase8000StatCard(title: "Sessions", value: "\(hub.statistics.totalSessions)", icon: "globe")
                Phase8000StatCard(title: "Online", value: "\(hub.statistics.activeParticipants)", icon: "person.3")
                Phase8000StatCard(title: "Regions", value: "\(hub.statistics.regionsOnline)", icon: "map")
            }
        }
    }
}

// MARK: - Collaboration Active Session View (renamed to avoid conflict with AppClip.ActiveSessionView)

struct CollaborationActiveSessionView: View {
    @ObservedObject var hub: WorldwideCollaborationHub

    var body: some View {
        VStack {
            if let session = hub.currentSession {
                // Session Header
                VStack {
                    Text(session.name)
                        .font(.title.bold())
                    Text("Code: \(session.code)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(session.participantCount) participants")
                }

                // Coherence Sync
                Phase8000CoherenceRing(coherence: session.sharedState.currentCoherence)
                    .frame(width: 200, height: 200)

                // Participants
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(session.participants) { participant in
                            Phase8000ParticipantAvatar(participant: participant)
                        }
                    }
                }

                // Controls
                HStack(spacing: 20) {
                    Button {
                        hub.toggleAudio()
                    } label: {
                        Image(systemName: hub.localParticipant?.audioEnabled == true ? "mic.fill" : "mic.slash.fill")
                            .font(.title)
                    }

                    Button {
                        Task { await hub.triggerEntanglement() }
                    } label: {
                        Image(systemName: "atom")
                            .font(.title)
                    }

                    Button {
                        Task { await hub.leaveSession() }
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.title)
                            .foregroundColor(.red)
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Developer Console View

/// In-app developer console
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
public struct DeveloperConsoleView: View {
    @ObservedObject private var console = DeveloperConsole.shared
    @ObservedObject private var monitor = PerformanceMonitor.shared
    @State private var selectedTab = 0

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack {
                Picker("Tab", selection: $selectedTab) {
                    Text("Console").tag(0)
                    Text("Performance").tag(1)
                    Text("Plugins").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()

                switch selectedTab {
                case 0:
                    consoleTab
                case 1:
                    performanceTab
                case 2:
                    pluginsTab
                default:
                    EmptyView()
                }
            }
            .navigationTitle("Developer")
        }
    }

    private var consoleTab: some View {
        VStack {
            // Log Level Filter
            Picker("Level", selection: $console.logLevel) {
                ForEach(DeveloperConsole.LogLevel.allCases, id: \.self) { level in
                    Text(level.rawValue).tag(level)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Logs
            List(console.logs) { entry in
                HStack {
                    Circle()
                        .fill(colorForLevel(entry.level))
                        .frame(width: 8, height: 8)
                    Text("[\(entry.source)]")
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                    Text(entry.message)
                        .font(.caption.monospaced())
                }
            }

            // Actions
            HStack {
                Button("Clear") { console.clear() }
                Button("Export") { _ = console.exportLogs() }
            }
            .padding()
        }
    }

    private var performanceTab: some View {
        VStack(spacing: 20) {
            // FPS Gauge
            GaugeView(value: monitor.fps / 120, title: "FPS", valueText: String(format: "%.0f", monitor.fps))

            // CPU/GPU
            HStack {
                GaugeView(value: monitor.cpuUsage, title: "CPU", valueText: String(format: "%.0f%%", monitor.cpuUsage * 100))
                GaugeView(value: monitor.gpuUsage, title: "GPU", valueText: String(format: "%.0f%%", monitor.gpuUsage * 100))
            }

            // Memory
            Text("Memory: \(ByteCountFormatter.string(fromByteCount: monitor.memoryUsage, countStyle: .memory))")
                .font(.headline)

            // Latency
            HStack {
                Text("Audio: \(String(format: "%.1fms", monitor.audioLatency * 1000))")
                Text("Network: \(String(format: "%.1fms", monitor.networkLatency * 1000))")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            Spacer()
        }
        .padding()
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
    }

    private var pluginsTab: some View {
        List {
            Text("Plugin Manager")
            Text("Load plugins from Developer SDK")
                .foregroundColor(.secondary)
        }
    }

    private func colorForLevel(_ level: DeveloperConsole.LogLevel) -> Color {
        switch level {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}

// MARK: - Supporting Views

/// Coherence ring for Phase 8000 views (renamed to avoid conflict with WatchAppView.CoherenceRing)
struct Phase8000CoherenceRing: View {
    let coherence: Float

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 20)

            Circle()
                .trim(from: 0, to: CGFloat(coherence))
                .stroke(
                    AngularGradient(colors: [.blue, .purple, .pink, .blue], center: .center),
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack {
                Text("\(Int(coherence * 100))%")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text("Coherence")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct StatBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Stat card for Phase 8000 views (renamed to avoid conflict with QuantumCoherenceComplication.StatCard)
struct Phase8000StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            Text(value)
                .font(.title3.bold())
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
    }
}

struct EffectChip: View {
    let effect: VideoEffectType
    let onRemove: () -> Void

    var body: some View {
        HStack {
            Text(effect.rawValue)
                .font(.caption)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.2))
        .cornerRadius(16)
    }
}

struct ModeChip: View {
    let mode: CreativeMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(mode.rawValue)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.purple : Color(.systemGroupedBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
        .accessibilityLabel("\(mode.rawValue) mode")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct StyleChip: View {
    let style: ArtStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(style.rawValue)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.orange : Color(.systemGroupedBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
        .accessibilityLabel("\(style.rawValue) style")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct CategoryPill: View {
    let category: WellnessCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(category.rawValue)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? Color.green : Color(.systemGroupedBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
        .accessibilityLabel("\(category.rawValue) category")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct BreathingPatternCard: View {
    let pattern: BreathingPattern
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading) {
                Text(pattern.rawValue)
                    .font(.headline)
                Text("\(pattern.cycleDurationSeconds)s cycle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(pattern.rawValue) breathing pattern, \(pattern.cycleDurationSeconds) second cycle")
        .accessibilityHint("Double tap to start this breathing exercise")
    }
}

/// Participant avatar for Phase 8000 (renamed to avoid conflict with AppStoreScreenshots.ParticipantAvatar)
struct Phase8000ParticipantAvatar: View {
    let participant: Participant

    var body: some View {
        VStack {
            Circle()
                .fill(participant.status == .active ? Color.green : Color.gray)
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(participant.displayName.prefix(2)).uppercased())
                        .foregroundColor(.white)
                        .font(.headline)
                )
            Text(participant.displayName)
                .font(.caption)
                .lineLimit(1)
        }
        .frame(width: 70)
    }
}

struct GaugeView: View {
    let value: Double
    let title: String
    let valueText: String

    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: min(value, 1.0))
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(valueText)
                    .font(.headline)
            }
            .frame(width: 80, height: 80)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct CreationThumbnail: View {
    let result: AIGenerationResult

    var body: some View {
        VStack {
            Rectangle()
                .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                .aspectRatio(1, contentMode: .fit)
                .cornerRadius(8)
            Text(result.outputType.rawValue)
                .font(.caption)
                .lineLimit(1)
        }
    }
}

struct QuantumVideoOverlay: View {
    let coherence: Float

    // Pre-computed particle data to avoid CGFloat.random() in view body (compiler crash fix)
    private static let particleData: [(relX: CGFloat, relY: CGFloat, size: CGFloat)] = (0..<20).map { i in
        let seed = Double(i)
        return (
            relX: CGFloat((seed * 0.618).truncatingRemainder(dividingBy: 1.0)),
            relY: CGFloat((seed * 0.382 + 0.1).truncatingRemainder(dividingBy: 1.0)),
            size: CGFloat(10 + (seed.truncatingRemainder(dividingBy: 4)) * 10)
        )
    }

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<20, id: \.self) { i in
                let particle = Self.particleData[i]
                Circle()
                    .fill(Color.blue.opacity(Double(coherence) * 0.3))
                    .frame(width: particle.size)
                    .position(
                        x: particle.relX * geo.size.width,
                        y: particle.relY * geo.size.height
                    )
                    .blur(radius: 5)
            }
        }
    }
}

struct QuantumFieldVisualization: View {
    let type: ScientificVisualizationType
    let engine: ScientificVisualizationEngine

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                // Draw quantum field visualization
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                for i in 0..<100 {
                    let angle = Double(i) * 0.1
                    let radius = Double(i) * 3
                    let x = center.x + CGFloat(cos(angle) * radius)
                    let y = center.y + CGFloat(sin(angle) * radius)

                    context.fill(
                        Path(ellipseIn: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)),
                        with: .color(.cyan.opacity(0.7))
                    )
                }
            }
        }
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
struct VideoEffectPicker: View {
    @ObservedObject var engine: VideoProcessingEngine
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Quantum Effects") {
                    ForEach([VideoEffectType.quantumWave, .coherenceField, .photonTrails, .entanglement], id: \.self) { effect in
                        EffectRow(effect: effect, isActive: engine.activeEffects.contains(effect)) {
                            toggleEffect(effect)
                        }
                    }
                }
                Section("Bio-Reactive") {
                    ForEach([VideoEffectType.heartbeatPulse, .breathingWave, .hrvCoherence], id: \.self) { effect in
                        EffectRow(effect: effect, isActive: engine.activeEffects.contains(effect)) {
                            toggleEffect(effect)
                        }
                    }
                }
                Section("Cinematic") {
                    ForEach([VideoEffectType.filmGrain, .vignette, .bokeh, .lensFlare], id: \.self) { effect in
                        EffectRow(effect: effect, isActive: engine.activeEffects.contains(effect)) {
                            toggleEffect(effect)
                        }
                    }
                }
            }
            .navigationTitle("Effects")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    func toggleEffect(_ effect: VideoEffectType) {
        if engine.activeEffects.contains(effect) {
            engine.removeEffect(effect)
        } else {
            engine.addEffect(effect)
        }
    }
}

struct EffectRow: View {
    let effect: VideoEffectType
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(effect.rawValue)
                Spacer()
                if isActive {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
        }
    }
}

// MARK: - Main Demo View

/// Unified demo view showcasing all 8000% features
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
public struct Phase8000DemoView: View {
    @State private var selectedTab = 0

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            VideoProcessingView()
                .tabItem {
                    Label("Video", systemImage: "video.fill")
                }
                .tag(0)

            CreativeStudioView()
                .tabItem {
                    Label("Create", systemImage: "paintbrush.fill")
                }
                .tag(1)

            ScientificDashboardView()
                .tabItem {
                    Label("Science", systemImage: "atom")
                }
                .tag(2)

            BiophysicalWellnessView()
                .tabItem {
                    Label("Wellness", systemImage: "heart.fill")
                }
                .tag(3)

            CollaborationLobbyView()
                .tabItem {
                    Label("Collab", systemImage: "globe")
                }
                .tag(4)

            DeveloperConsoleView()
                .tabItem {
                    Label("Dev", systemImage: "terminal.fill")
                }
                .tag(5)
        }
    }
}
