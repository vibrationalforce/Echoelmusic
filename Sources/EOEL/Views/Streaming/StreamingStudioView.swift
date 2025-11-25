//
//  StreamingStudioView.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  STREAMING STUDIO UI - Professional multi-platform streaming interface
//  OBS / Streamlabs level interface
//

import SwiftUI

struct StreamingStudioView: View {
    @StateObject private var streamEngine = StreamEngine.shared
    @StateObject private var sceneManager = SceneManager.shared
    @StateObject private var analytics = StreamAnalytics.shared
    @StateObject private var liveEngine = LiveStreamingEngine.shared

    @State private var showSettings: Bool = false
    @State private var showChat: Bool = true
    @State private var showAnalytics: Bool = true

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Top toolbar
                StreamToolbar(
                    showSettings: $showSettings,
                    showChat: $showChat,
                    showAnalytics: $showAnalytics
                )
                .frame(height: 60)

                Divider()

                HSplitView {
                    // Left: Scene selector & sources
                    VStack(spacing: 0) {
                        SceneSelectorView()
                            .frame(height: geometry.size.height * 0.4)

                        Divider()

                        SourceListView()
                    }
                    .frame(width: 300)

                    // Center: Preview & controls
                    VStack(spacing: 0) {
                        // Stream preview
                        StreamPreviewView()

                        Divider()

                        // Stream controls
                        StreamControlsView()
                            .frame(height: 120)
                    }

                    // Right: Chat & Analytics (collapsible)
                    if showChat || showAnalytics {
                        VStack(spacing: 0) {
                            if showChat {
                                ChatView()
                                    .frame(height: showAnalytics ? geometry.size.height * 0.5 : nil)
                            }

                            if showAnalytics {
                                Divider()
                                AnalyticsView()
                            }
                        }
                        .frame(width: 350)
                    }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            StreamSettingsView()
        }
    }
}

// MARK: - Stream Toolbar

struct StreamToolbar: View {
    @Binding var showSettings: Bool
    @Binding var showChat: Bool
    @Binding var showAnalytics: Bool

    var body: some View {
        HStack(spacing: 20) {
            // Logo/Title
            HStack {
                Image(systemName: "video.circle.fill")
                    .font(.title)
                    .foregroundColor(.red)
                Text("Streaming Studio")
                    .font(.headline)
            }

            Spacer()

            // View toggles
            Toggle("Chat", isOn: $showChat)
                .toggleStyle(.button)

            Toggle("Analytics", isOn: $showAnalytics)
                .toggleStyle(.button)

            Button(action: { showSettings.toggle() }) {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Scene Selector

struct SceneSelectorView: View {
    @StateObject private var sceneManager = SceneManager.shared
    @StateObject private var liveEngine = LiveStreamingEngine.shared

    @State private var showAddScene: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Scenes")
                    .font(.headline)

                Spacer()

                Button(action: { showAddScene.toggle() }) {
                    Image(systemName: "plus.circle")
                }
            }
            .padding()

            Divider()

            // Scene list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(liveEngine.scenes) { scene in
                        SceneCard(
                            scene: scene,
                            isActive: liveEngine.activeScene?.id == scene.id,
                            onSelect: { liveEngine.switchToScene(scene) }
                        )
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showAddScene) {
            AddSceneView()
        }
    }
}

struct SceneCard: View {
    let scene: LiveStreamingEngine.Scene
    let isActive: Bool
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Preview thumbnail
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black)
                .frame(height: 120)
                .overlay(
                    VStack {
                        Image(systemName: "video")
                            .font(.largeTitle)
                            .foregroundColor(.white.opacity(0.5))
                        Text(scene.name)
                            .foregroundColor(.white)
                    }
                )

            // Scene info
            HStack {
                Text(scene.name)
                    .font(.caption)
                    .fontWeight(.semibold)

                Spacer()

                Text("\(scene.sources.count) sources")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(isActive ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            onSelect()
        }
    }
}

struct AddSceneView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sceneName: String = "New Scene"

    var body: some View {
        NavigationView {
            Form {
                TextField("Scene Name", text: $sceneName)
            }
            .navigationTitle("Add Scene")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        // Add scene logic
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Source List

struct SourceListView: View {
    @State private var showAddSource: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Sources")
                    .font(.headline)

                Spacer()

                Button(action: { showAddSource.toggle() }) {
                    Image(systemName: "plus.circle")
                }
            }
            .padding()

            Divider()

            // Source list
            List {
                Section(header: Text("Video")) {
                    SourceRow(icon: "video", name: "Camera 1", isVisible: true)
                    SourceRow(icon: "display", name: "Screen Capture", isVisible: true)
                }

                Section(header: Text("Audio")) {
                    SourceRow(icon: "mic", name: "Microphone", isVisible: true)
                    SourceRow(icon: "music.note", name: "Music", isVisible: false)
                }

                Section(header: Text("Other")) {
                    SourceRow(icon: "text.bubble", name: "Chat Overlay", isVisible: true)
                }
            }
        }
        .sheet(isPresented: $showAddSource) {
            AddSourceView()
        }
    }
}

struct SourceRow: View {
    let icon: String
    let name: String
    let isVisible: Bool

    var body: some View {
        HStack {
            Image(systemName: isVisible ? "eye" : "eye.slash")
                .foregroundColor(isVisible ? .primary : .gray)

            Image(systemName: icon)
                .foregroundColor(.accentColor)

            Text(name)

            Spacer()

            Image(systemName: "line.3.horizontal")
                .foregroundColor(.gray)
        }
    }
}

struct AddSourceView: View {
    @Environment(\.dismiss) private var dismiss

    let sourceTypes = [
        ("video", "Camera"),
        ("display", "Screen Capture"),
        ("photo", "Image"),
        ("doc.text", "Text"),
        ("waveform", "Audio Input"),
        ("safari", "Browser Source")
    ]

    var body: some View {
        NavigationView {
            List {
                ForEach(sourceTypes, id: \.0) { type in
                    Button(action: {
                        // Add source logic
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: type.0)
                                .frame(width: 30)
                            Text(type.1)
                        }
                    }
                }
            }
            .navigationTitle("Add Source")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#if DEBUG
struct StreamingStudioView_Previews: PreviewProvider {
    static var previews: some View {
        StreamingStudioView()
            .frame(width: 1400, height: 900)
    }
}
#endif
