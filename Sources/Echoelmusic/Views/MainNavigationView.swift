//
//  MainNavigationView.swift
//  Echoelmusic
//
//  Created: 2025-11-27
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  MAIN NAVIGATION HUB - Access to ALL Echoelmusic features
//  This is the root view that provides navigation to:
//  - Home (Bio-reactive visualization)
//  - DAW (Full digital audio workstation)
//  - Video (DaVinci Resolve-level editing)
//  - VJ (Resolume Arena-level visual performance)
//  - Stream (Live broadcasting)
//  - Collaborate (Worldwide real-time collaboration)
//  - Settings (All configuration)
//

import SwiftUI

struct MainNavigationView: View {
    @State private var selectedTab: MainTab = .home
    @State private var showSidebar: Bool = false

    enum MainTab: String, CaseIterable {
        case home = "Home"
        case daw = "DAW"
        case video = "Video"
        case vj = "VJ"
        case stream = "Stream"
        case collaborate = "Collab"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .home: return "waveform.circle.fill"
            case .daw: return "pianokeys"
            case .video: return "film"
            case .vj: return "square.grid.3x3.fill"
            case .stream: return "video.badge.waveform"
            case .collaborate: return "person.3.fill"
            case .settings: return "gearshape.fill"
            }
        }

        var color: Color {
            switch self {
            case .home: return .cyan
            case .daw: return .purple
            case .video: return .orange
            case .vj: return .pink
            case .stream: return .red
            case .collaborate: return .green
            case .settings: return .gray
            }
        }
    }

    var body: some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad: Sidebar navigation
            NavigationSplitView {
                sidebarContent
            } detail: {
                selectedView
            }
        } else {
            // iPhone: Tab bar
            TabView(selection: $selectedTab) {
                ForEach(MainTab.allCases, id: \.self) { tab in
                    selectedViewFor(tab)
                        .tabItem {
                            Label(tab.rawValue, systemImage: tab.icon)
                        }
                        .tag(tab)
                }
            }
            .tint(.purple)
        }
        #else
        // macOS: Sidebar
        NavigationSplitView {
            sidebarContent
        } detail: {
            selectedView
        }
        #endif
    }

    // MARK: - Sidebar Content

    private var sidebarContent: some View {
        List(MainTab.allCases, id: \.self, selection: $selectedTab) { tab in
            NavigationLink(value: tab) {
                Label {
                    Text(tab.rawValue)
                } icon: {
                    Image(systemName: tab.icon)
                        .foregroundColor(tab.color)
                }
            }
        }
        .navigationTitle("Echoelmusic")
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
    }

    // MARK: - Selected View

    @ViewBuilder
    private var selectedView: some View {
        selectedViewFor(selectedTab)
    }

    @ViewBuilder
    private func selectedViewFor(_ tab: MainTab) -> some View {
        switch tab {
        case .home:
            HomeView()
        case .daw:
            DAWMainView()
        case .video:
            VideoEditingView()
        case .vj:
            VJPerformanceView()
        case .stream:
            LiveStreamingView()
        case .collaborate:
            CollaborationView()
        case .settings:
            SettingsView()
        }
    }
}

// MARK: - Home View (Bio-reactive visualization - original ContentView)

struct HomeView: View {
    @EnvironmentObject var microphoneManager: MicrophoneManager
    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var healthKitManager: HealthKitManager

    var body: some View {
        NavigationView {
            ContentView()
                .navigationTitle("Home")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Video Editing View

struct VideoEditingView: View {
    @StateObject private var videoEngine = VideoEditingEngine.shared

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Mode selector
                VideoModeSelector()

                // Main content
                VideoTimelineView()
            }
            .navigationTitle("Video Editor")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    NavigationLink {
                        ColorGradingView()
                    } label: {
                        Label("Color", systemImage: "paintpalette")
                    }

                    NavigationLink {
                        ChromaKeyView()
                    } label: {
                        Label("Chroma Key", systemImage: "person.crop.rectangle")
                    }
                }
            }
        }
    }
}

struct VideoModeSelector: View {
    @State private var selectedMode: VideoMode = .edit

    enum VideoMode: String, CaseIterable {
        case cut = "Cut"
        case edit = "Edit"
        case color = "Color"
        case effects = "Effects"
        case audio = "Audio"
        case export = "Export"
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(VideoMode.allCases, id: \.self) { mode in
                    Button {
                        selectedMode = mode
                    } label: {
                        Text(mode.rawValue)
                            .font(.subheadline)
                            .fontWeight(selectedMode == mode ? .semibold : .regular)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedMode == mode ? Color.orange.opacity(0.2) : Color.clear)
                            .foregroundColor(selectedMode == mode ? .orange : .secondary)
                    }
                }
            }
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - VJ Performance View

struct VJPerformanceView: View {
    @StateObject private var oscManager = OSCManager.shared
    @State private var selectedMode: VJMode = .clipLauncher

    enum VJMode: String, CaseIterable {
        case clipLauncher = "Clips"
        case visualizer = "Visualizer"
        case lighting = "Lighting"
        case projection = "Projection"

        var icon: String {
            switch self {
            case .clipLauncher: return "square.grid.3x3"
            case .visualizer: return "waveform.path"
            case .lighting: return "lightbulb.fill"
            case .projection: return "rectangle.on.rectangle"
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Mode tabs
                HStack(spacing: 0) {
                    ForEach(VJMode.allCases, id: \.self) { mode in
                        Button {
                            selectedMode = mode
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: mode.icon)
                                    .font(.title2)
                                Text(mode.rawValue)
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(selectedMode == mode ? Color.pink.opacity(0.2) : Color.clear)
                            .foregroundColor(selectedMode == mode ? .pink : .secondary)
                        }
                    }
                }
                .background(Color(.systemBackground))

                Divider()

                // Content based on mode
                Group {
                    switch selectedMode {
                    case .clipLauncher:
                        ClipLauncherMatrix()
                    case .visualizer:
                        VisualizerView()
                    case .lighting:
                        LightingControlView()
                    case .projection:
                        ProjectionMappingView()
                    }
                }
            }
            .navigationTitle("VJ Performance")
        }
    }
}

struct VisualizerView: View {
    @State private var selectedVisualization: String = "Cymatics"

    let visualizations = ["Cymatics", "Mandala", "Spectral", "Waveform", "Particles"]

    var body: some View {
        VStack {
            Picker("Visualization", selection: $selectedVisualization) {
                ForEach(visualizations, id: \.self) { viz in
                    Text(viz).tag(viz)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Visualization placeholder
            ZStack {
                Color.black
                Text("Select audio input to visualize")
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
}

struct ProjectionMappingView: View {
    var body: some View {
        VStack {
            Text("Projection Mapping")
                .font(.title2)

            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .font(.system(size: 80))
                    .foregroundColor(.purple.opacity(0.5))

                Text("Map visuals to surfaces")
                    .font(.headline)

                Text("Use LiDAR for automatic surface detection\nor manually define projection zones")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Live Streaming View

struct LiveStreamingView: View {
    @StateObject private var streamEngine = StreamEngine.shared

    var body: some View {
        NavigationView {
            LiveBroadcastControlPanelView()
                .navigationTitle("Live Stream")
        }
    }
}

// MARK: - Collaboration View

struct CollaborationView: View {
    @StateObject private var syncEngine = EchoelSyncEngine.shared

    var body: some View {
        NavigationView {
            EchoelSyncControlPanelView()
                .navigationTitle("Collaborate")
        }
    }
}

// MARK: - Preview

#Preview {
    MainNavigationView()
        .environmentObject(MicrophoneManager())
        .environmentObject(AudioEngine(microphoneManager: MicrophoneManager()))
        .environmentObject(HealthKitManager())
        .environmentObject(RecordingEngine())
}
