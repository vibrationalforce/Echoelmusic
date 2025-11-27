//
//  LiveBroadcastControlPanelView.swift
//  Echoelmusic
//
//  Created: 2025-11-25
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  Live Broadcast Control Panel - OBS Studio / vMix level interface
//  Professional worldwide streaming control
//

import SwiftUI

/// Professional Live Broadcasting Control Panel
struct LiveBroadcastControlPanelView: View {
    @StateObject private var broadcastSystem = WorldwideLiveBroadcastingSystem.shared
    @State private var selectedTab: BroadcastTab = .dashboard

    enum BroadcastTab: String, CaseIterable {
        case dashboard = "Dashboard"
        case platforms = "Platforms"
        case scenes = "Scenes"
        case sources = "Sources"
        case audio = "Audio Mixer"
        case chat = "Live Chat"
        case analytics = "Analytics"

        var icon: String {
            switch self {
            case .dashboard: return "rectangle.3.group.fill"
            case .platforms: return "dot.radiowaves.left.and.right"
            case .scenes: return "rectangle.stack"
            case .sources: return "video.fill"
            case .audio: return "waveform"
            case .chat: return "message.fill"
            case .analytics: return "chart.line.uptrend.xyaxis"
            }
        }
    }

    var body: some View {
        NavigationView {
            // Sidebar
            List(BroadcastTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .navigationTitle("Live Broadcast")
            .frame(minWidth: 200)

            // Detail view
            Group {
                switch selectedTab {
                case .dashboard:
                    BroadcastDashboardView()
                case .platforms:
                    PlatformConfigurationView()
                case .scenes:
                    SceneManagementView()
                case .sources:
                    SourceManagementView()
                case .audio:
                    AudioMixerView()
                case .chat:
                    LiveChatView()
                case .analytics:
                    AnalyticsView()
                }
            }
            .frame(minWidth: 800)
        }
    }
}

// MARK: - Dashboard

struct BroadcastDashboardView: View {
    @StateObject private var broadcastSystem = WorldwideLiveBroadcastingSystem.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header with main controls
                HStack {
                    Text("Live Broadcast Dashboard")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Spacer()

                    if broadcastSystem.isStreaming {
                        Button {
                            Task {
                                try? await broadcastSystem.stopStreaming()
                            }
                        } label: {
                            Label("Stop Stream", systemImage: "stop.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    } else {
                        Button {
                            Task {
                                try? await broadcastSystem.startStreaming()
                            }
                        } label: {
                            Label("Go Live", systemImage: "record.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }

                // Stream Status
                GroupBox("Stream Status") {
                    HStack(spacing: 40) {
                        StatusIndicator(
                            label: "Status",
                            value: broadcastSystem.isStreaming ? "LIVE" : "OFFLINE",
                            color: broadcastSystem.isStreaming ? .red : .gray
                        )

                        StatusIndicator(
                            label: "Health",
                            value: broadcastSystem.streamHealth.rawValue,
                            color: colorForHealth(broadcastSystem.streamHealth)
                        )

                        StatusIndicator(
                            label: "Viewers",
                            value: "\(broadcastSystem.viewerCount)",
                            color: .blue
                        )

                        StatusIndicator(
                            label: "Platforms",
                            value: "\(broadcastSystem.activePlatforms.count)",
                            color: .purple
                        )
                    }
                    .padding()
                }

                // Preview + Program
                HStack(spacing: 20) {
                    GroupBox("Preview") {
                        Rectangle()
                            .fill(Color.black)
                            .aspectRatio(16/9, contentMode: .fit)
                            .overlay(
                                Text("Preview Scene")
                                    .foregroundColor(.white.opacity(0.5))
                            )
                    }

                    GroupBox("Program (Live)") {
                        Rectangle()
                            .fill(Color.black)
                            .aspectRatio(16/9, contentMode: .fit)
                            .overlay(
                                VStack {
                                    if broadcastSystem.isStreaming {
                                        HStack {
                                            Circle()
                                                .fill(Color.red)
                                                .frame(width: 12, height: 12)
                                            Text("LIVE")
                                                .foregroundColor(.red)
                                                .fontWeight(.bold)
                                            Spacer()
                                        }
                                        .padding()
                                        Spacer()
                                    }
                                }
                            )
                    }
                }

                // Quick Stats
                GroupBox("Live Statistics") {
                    Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                        GridRow {
                            StatCard(label: "Bitrate", value: String(format: "%.1f Mbps", broadcastSystem.currentBitrate))
                            StatCard(label: "Dropped Frames", value: "\(broadcastSystem.droppedFrames)")
                        }
                        GridRow {
                            StatCard(label: "Resolution", value: broadcastSystem.outputResolution.rawValue)
                            StatCard(label: "Frame Rate", value: broadcastSystem.outputFrameRate.rawValue)
                        }
                    }
                    .padding()
                }

                // Active Platforms
                if !broadcastSystem.activePlatforms.isEmpty {
                    GroupBox("Streaming To") {
                        FlowLayout(spacing: 12) {
                            ForEach(Array(broadcastSystem.activePlatforms), id: \.rawValue) { platform in
                                PlatformBadge(platform: platform, isLive: true)
                            }
                        }
                        .padding()
                    }
                }
            }
            .padding()
        }
    }

    private func colorForHealth(_ health: WorldwideLiveBroadcastingSystem.StreamHealth) -> Color {
        switch health {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .yellow
        case .poor: return .orange
        case .offline: return .gray
        }
    }
}

struct StatusIndicator: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
    }
}

struct StatCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Platform Configuration

struct PlatformConfigurationView: View {
    @StateObject private var broadcastSystem = WorldwideLiveBroadcastingSystem.shared
    @State private var showAddPlatform: Bool = false
    @State private var selectedPlatform: WorldwideLiveBroadcastingSystem.StreamingPlatform = .youTubeLive
    @State private var streamKey: String = ""
    @State private var customRTMP: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Streaming Platforms")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                Button {
                    showAddPlatform = true
                } label: {
                    Label("Add Platform", systemImage: "plus.circle")
                }
                .buttonStyle(.borderedProminent)
            }

            if broadcastSystem.destinations.isEmpty {
                ContentUnavailableView(
                    "No Platforms Configured",
                    systemImage: "dot.radiowaves.left.and.right",
                    description: Text("Add streaming platforms to start broadcasting worldwide")
                )
            } else {
                List {
                    ForEach($broadcastSystem.destinations) { $destination in
                        PlatformDestinationRow(destination: $destination)
                    }
                }
            }
        }
        .padding()
        .sheet(isPresented: $showAddPlatform) {
            AddPlatformSheet(
                selectedPlatform: $selectedPlatform,
                streamKey: $streamKey,
                customRTMP: $customRTMP,
                onAdd: {
                    broadcastSystem.addDestination(
                        platform: selectedPlatform,
                        streamKey: streamKey,
                        customRTMP: selectedPlatform == .customRTMP ? customRTMP : nil
                    )
                    showAddPlatform = false
                    streamKey = ""
                    customRTMP = ""
                }
            )
        }
    }
}

struct PlatformDestinationRow: View {
    @Binding var destination: WorldwideLiveBroadcastingSystem.StreamDestination

    var body: some View {
        HStack {
            Image(systemName: destination.platform.icon)
                .font(.title2)
                .foregroundColor(destination.enabled ? .accentColor : .gray)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(destination.platform.rawValue)
                    .font(.headline)
                Text(destination.rtmpURL)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Key: •••\(destination.streamKey.suffix(4))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if destination.status == .live {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("LIVE")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Toggle("", isOn: $destination.enabled)
                .labelsHidden()
        }
        .padding(.vertical, 8)
    }
}

struct AddPlatformSheet: View {
    @Binding var selectedPlatform: WorldwideLiveBroadcastingSystem.StreamingPlatform
    @Binding var streamKey: String
    @Binding var customRTMP: String
    let onAdd: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Platform") {
                    Picker("Select Platform", selection: $selectedPlatform) {
                        ForEach(WorldwideLiveBroadcastingSystem.StreamingPlatform.allCases) { platform in
                            Label(platform.rawValue, systemImage: platform.icon)
                                .tag(platform)
                        }
                    }
                }

                Section("Configuration") {
                    TextField("Stream Key", text: $streamKey)
                        .textContentType(.password)

                    if selectedPlatform == .customRTMP {
                        TextField("RTMP URL", text: $customRTMP)
                            .textContentType(.URL)
                    } else {
                        LabeledContent("RTMP URL") {
                            Text(selectedPlatform.defaultRTMPURL)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Instructions") {
                    Text(instructionsForPlatform(selectedPlatform))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add Platform")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Add") {
                    onAdd()
                    dismiss()
                }
                .disabled(streamKey.isEmpty)
            )
        }
    }

    private func instructionsForPlatform(_ platform: WorldwideLiveBroadcastingSystem.StreamingPlatform) -> String {
        switch platform {
        case .youTubeLive:
            return "Go to YouTube Studio → Go Live → Stream Settings to get your stream key"
        case .twitch:
            return "Go to Twitch Dashboard → Settings → Stream to find your stream key"
        case .facebookLive:
            return "Go to Facebook → Live Producer → Streaming Software to get your stream key"
        default:
            return "Find your stream key in the platform's dashboard or settings"
        }
    }
}

// MARK: - Scene Management

struct SceneManagementView: View {
    @StateObject private var broadcastSystem = WorldwideLiveBroadcastingSystem.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Scene Management")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                Button {
                    // Add scene
                } label: {
                    Label("New Scene", systemImage: "plus.rectangle.on.rectangle")
                }
                .buttonStyle(.borderedProminent)
            }

            if broadcastSystem.scenes.isEmpty {
                ContentUnavailableView(
                    "No Scenes",
                    systemImage: "rectangle.stack",
                    description: Text("Create scenes to organize your stream layout")
                )
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 16) {
                        ForEach(broadcastSystem.scenes) { scene in
                            ScenePreviewCard(scene: scene)
                        }
                    }
                    .padding()
                }

                Divider()

                // Scene editor would go here
                Text("Scene Editor")
                    .font(.headline)
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 400)
                    .overlay(
                        Text("Drag and drop sources to arrange your scene")
                            .foregroundColor(.secondary)
                    )
            }
        }
        .padding()
    }
}

struct ScenePreviewCard: View {
    let scene: WorldwideLiveBroadcastingSystem.Scene

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(Color.black)
                .aspectRatio(16/9, contentMode: .fit)
                .frame(width: 200)
                .overlay(
                    Text(scene.name)
                        .foregroundColor(.white)
                )

            Text(scene.name)
                .font(.caption)
                .fontWeight(.semibold)
            Text("\(scene.sources.count) sources")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Sources

struct SourceManagementView: View {
    @StateObject private var broadcastSystem = WorldwideLiveBroadcastingSystem.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Video & Audio Sources")
                .font(.largeTitle)
                .fontWeight(.bold)

            GroupBox("Cameras") {
                if broadcastSystem.cameras.isEmpty {
                    Text("No cameras detected")
                        .foregroundColor(.secondary)
                } else {
                    ForEach($broadcastSystem.cameras) { $camera in
                        CameraSourceRow(camera: $camera)
                    }
                }
            }

            GroupBox("Screen Capture") {
                HStack {
                    Image(systemName: "display")
                    Text("Add Screen Capture")
                    Spacer()
                    Button("Add") {}
                        .buttonStyle(.bordered)
                }
                .padding()
            }

            GroupBox("Media Files") {
                VStack(spacing: 12) {
                    AddSourceButton(icon: "photo", title: "Image")
                    AddSourceButton(icon: "video", title: "Video")
                    AddSourceButton(icon: "text.alignleft", title: "Text")
                    AddSourceButton(icon: "globe", title: "Browser Source")
                }
                .padding()
            }
        }
        .padding()
    }
}

struct CameraSourceRow: View {
    @Binding var camera: WorldwideLiveBroadcastingSystem.CameraSource

    var body: some View {
        HStack {
            Image(systemName: "video.fill")
            VStack(alignment: .leading) {
                Text(camera.name)
                    .font(.headline)
                Text("\(camera.resolution.rawValue) @ \(camera.frameRate.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: $camera.isActive)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

struct AddSourceButton: View {
    let icon: String
    let title: String

    var body: some View {
        Button {
            // Add source
        } label: {
            HStack {
                Image(systemName: icon)
                Text(title)
                Spacer()
                Image(systemName: "plus.circle")
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Audio Mixer

struct AudioMixerView: View {
    @StateObject private var broadcastSystem = WorldwideLiveBroadcastingSystem.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Audio Mixer")
                .font(.largeTitle)
                .fontWeight(.bold)

            HStack(alignment: .top, spacing: 20) {
                ForEach($broadcastSystem.audioSources) { $source in
                    AudioChannelStrip(source: $source)
                }
            }
            .padding()

            Spacer()
        }
        .padding()
    }
}

struct AudioChannelStrip: View {
    @Binding var source: WorldwideLiveBroadcastingSystem.AudioSource

    var body: some View {
        VStack(spacing: 12) {
            // Level meter
            AudioLevelMeter(level: source.volume)
                .frame(width: 40, height: 200)

            // Fader
            Slider(value: $source.volume, in: 0...1)
                .rotationEffect(.degrees(-90))
                .frame(width: 200, height: 40)

            // Mute button
            Button {
                source.muted.toggle()
            } label: {
                Image(systemName: source.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .foregroundColor(source.muted ? .red : .primary)
            }
            .buttonStyle(.bordered)

            // Name
            Text(source.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 80)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct AudioLevelMeter: View {
    let level: Float

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))

                Rectangle()
                    .fill(LinearGradient(
                        colors: [.green, .yellow, .red],
                        startPoint: .bottom,
                        endPoint: .top
                    ))
                    .frame(height: geometry.size.height * CGFloat(level))
            }
        }
        .cornerRadius(4)
    }
}

// MARK: - Live Chat

struct LiveChatView: View {
    @StateObject private var broadcastSystem = WorldwideLiveBroadcastingSystem.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Live Chat")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(broadcastSystem.liveComments) { comment in
                        LiveCommentRow(comment: comment)
                    }
                }
                .padding()
            }
        }
    }
}

struct LiveCommentRow: View {
    let comment: WorldwideLiveBroadcastingSystem.LiveComment

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: comment.platform.icon)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.username)
                        .fontWeight(.semibold)
                    if comment.isSuperchat {
                        Text("$\(String(format: "%.2f", comment.superChatAmount ?? 0))")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.yellow)
                            .cornerRadius(4)
                    }
                    Spacer()
                    Text(comment.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(comment.message)
                    .font(.body)
            }
        }
        .padding()
        .background(comment.isSuperchat ? Color.yellow.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

// MARK: - Analytics

struct AnalyticsView: View {
    @StateObject private var broadcastSystem = WorldwideLiveBroadcastingSystem.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Stream Analytics")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                let analytics = broadcastSystem.getStreamAnalytics()

                GroupBox("Overview") {
                    Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                        GridRow {
                            AnalyticCard(label: "Peak Viewers", value: "\(analytics.peakViewers)")
                            AnalyticCard(label: "Avg Viewers", value: "\(analytics.averageViewers)")
                        }
                        GridRow {
                            AnalyticCard(label: "Total Views", value: "\(analytics.totalViews)")
                            AnalyticCard(label: "Duration", value: formatDuration(analytics.duration))
                        }
                    }
                    .padding()
                }

                GroupBox("Performance") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Dropped Frames")
                            Spacer()
                            Text("\(analytics.droppedFrames)")
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Data Sent")
                            Spacer()
                            Text("\(analytics.bytesSent / (1024 * 1024)) MB")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }
            }
            .padding()
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

struct AnalyticCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Helper Views

struct PlatformBadge: View {
    let platform: WorldwideLiveBroadcastingSystem.StreamingPlatform
    let isLive: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: platform.icon)
            Text(platform.rawValue)
                .font(.caption)
            if isLive {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(16)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var point = bounds.origin

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            subview.place(at: point, proposal: .unspecified)
            point.x += size.width + spacing
        }
    }
}

#if DEBUG
struct LiveBroadcastControlPanelView_Previews: PreviewProvider {
    static var previews: some View {
        LiveBroadcastControlPanelView()
            .frame(width: 1200, height: 800)
    }
}
#endif
