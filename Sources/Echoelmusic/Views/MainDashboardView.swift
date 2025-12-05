import SwiftUI

// MARK: - Main Dashboard View
// Central hub for Echoelmusic - access all features from one place

public struct MainDashboardView: View {
    @State private var selectedTab: DashboardTab = .create
    @State private var showSettings = false
    @State private var showQuickActions = false

    public var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                // Create Tab
                CreateHubView()
                    .tabItem {
                        Label("Create", systemImage: "waveform.badge.plus")
                    }
                    .tag(DashboardTab.create)

                // AI Tab
                AIHubView()
                    .tabItem {
                        Label("AI", systemImage: "brain")
                    }
                    .tag(DashboardTab.ai)

                // Visual Tab
                VisualHubView()
                    .tabItem {
                        Label("Visual", systemImage: "sparkles.rectangle.stack")
                    }
                    .tag(DashboardTab.visual)

                // Tools Tab
                ToolsHubView()
                    .tabItem {
                        Label("Tools", systemImage: "wrench.and.screwdriver")
                    }
                    .tag(DashboardTab.tools)

                // Cloud Tab
                CloudHubView()
                    .tabItem {
                        Label("Cloud", systemImage: "cloud")
                    }
                    .tag(DashboardTab.cloud)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gear")
                    }
                }

                ToolbarItem(placement: .principal) {
                    HStack {
                        Image(systemName: "waveform.circle.fill")
                            .foregroundStyle(.accentColor)
                        Text("Echoelmusic")
                            .font(.headline)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
}

enum DashboardTab {
    case create, ai, visual, tools, cloud
}

// MARK: - Create Hub

struct CreateHubView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Recent Projects
                RecentProjectsSection()

                // Quick Create
                QuickCreateSection()

                // Templates
                TemplatesSection()
            }
            .padding()
        }
        .navigationTitle("Create")
    }
}

struct RecentProjectsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Projects")
                    .font(.headline)
                Spacer()
                Button("See All") {}
                    .font(.subheadline)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(0..<5) { i in
                        ProjectCard(name: "Project \(i + 1)", lastModified: "2 hours ago")
                    }
                }
            }
        }
    }
}

struct ProjectCard: View {
    let name: String
    let lastModified: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 150, height: 100)
                .overlay(
                    Image(systemName: "waveform")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.5))
                )

            Text(name)
                .font(.subheadline)
                .fontWeight(.medium)

            Text(lastModified)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 150)
    }
}

struct QuickCreateSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Create")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                QuickCreateButton(title: "New Project", icon: "plus.circle", color: .blue)
                QuickCreateButton(title: "Record", icon: "mic", color: .red)
                QuickCreateButton(title: "Import Audio", icon: "square.and.arrow.down", color: .green)
                QuickCreateButton(title: "AI Generate", icon: "sparkles", color: .purple)
            }
        }
    }
}

struct QuickCreateButton: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        Button(action: {}) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(color)

                Text(title)
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct TemplatesSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Templates")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                TemplateCard(name: "Electronic", icon: "bolt.fill", color: .cyan)
                TemplateCard(name: "Acoustic", icon: "guitars", color: .orange)
                TemplateCard(name: "Hip Hop", icon: "music.mic", color: .purple)
                TemplateCard(name: "Cinematic", icon: "film", color: .red)
                TemplateCard(name: "Ambient", icon: "cloud", color: .blue)
                TemplateCard(name: "Podcast", icon: "mic.fill", color: .green)
            }
        }
    }
}

struct TemplateCard: View {
    let name: String
    let icon: String
    let color: Color

    var body: some View {
        Button(action: {}) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Text(name)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AI Hub

struct AIHubView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // AI Features Grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                    AIFeatureCard(
                        title: "AI Agents",
                        subtitle: "Autonomous production",
                        icon: "cpu",
                        color: .purple,
                        destination: AnyView(AIAgentDashboardView())
                    )

                    AIFeatureCard(
                        title: "Harmonizer",
                        subtitle: "Intelligent harmonies",
                        icon: "music.quarternote.3",
                        color: .blue,
                        destination: AnyView(HarmonizerView())
                    )

                    AIFeatureCard(
                        title: "Stem Separator",
                        subtitle: "Neural separation",
                        icon: "square.stack.3d.up",
                        color: .green,
                        destination: AnyView(StemSeparatorView())
                    )

                    AIFeatureCard(
                        title: "Auto-Mix",
                        subtitle: "AI mixing assistant",
                        icon: "slider.horizontal.3",
                        color: .orange
                    )

                    AIFeatureCard(
                        title: "Auto-Master",
                        subtitle: "Professional mastering",
                        icon: "wand.and.stars",
                        color: .pink
                    )

                    AIFeatureCard(
                        title: "Style Transfer",
                        subtitle: "Transform your sound",
                        icon: "paintbrush",
                        color: .cyan
                    )
                }
            }
            .padding()
        }
        .navigationTitle("AI Studio")
    }
}

struct AIFeatureCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    var destination: AnyView?

    var body: some View {
        NavigationLink(destination: destination ?? AnyView(EmptyView())) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(color)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Visual Hub

struct VisualHubView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                    VisualFeatureCard(
                        title: "Physics Engine",
                        subtitle: "Particle systems",
                        icon: "atom",
                        color: .purple,
                        destination: AnyView(PhysicsVisualizerView())
                    )

                    VisualFeatureCard(
                        title: "VJ Mode",
                        subtitle: "Live performance",
                        icon: "rectangle.split.2x2",
                        color: .pink,
                        destination: AnyView(VJModeView())
                    )

                    VisualFeatureCard(
                        title: "Visualizers",
                        subtitle: "Audio reactive",
                        icon: "waveform.path",
                        color: .cyan
                    )

                    VisualFeatureCard(
                        title: "3D Scene",
                        subtitle: "Immersive visuals",
                        icon: "cube",
                        color: .orange
                    )

                    VisualFeatureCard(
                        title: "Neural Style",
                        subtitle: "AI art transfer",
                        icon: "brain",
                        color: .green
                    )

                    VisualFeatureCard(
                        title: "DMX Control",
                        subtitle: "Lighting sync",
                        icon: "lightbulb",
                        color: .yellow
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Visual")
    }
}

struct VisualFeatureCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    var destination: AnyView?

    var body: some View {
        NavigationLink(destination: destination ?? AnyView(EmptyView())) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(color)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tools Hub

struct ToolsHubView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                    ToolCard(
                        title: "Plugins",
                        subtitle: "AU/VST3 browser",
                        icon: "puzzlepiece.extension",
                        color: .blue,
                        destination: AnyView(PluginBrowserView())
                    )

                    ToolCard(
                        title: "Automation",
                        subtitle: "n8n workflows",
                        icon: "arrow.triangle.2.circlepath",
                        color: .orange,
                        destination: AnyView(AutomationWorkflowView())
                    )

                    ToolCard(
                        title: "MIDI/OSC",
                        subtitle: "Controller mapping",
                        icon: "pianokeys",
                        color: .purple
                    )

                    ToolCard(
                        title: "Analyzer",
                        subtitle: "Spectrum & metering",
                        icon: "chart.bar",
                        color: .green
                    )

                    ToolCard(
                        title: "Tuner",
                        subtitle: "Chromatic tuner",
                        icon: "tuningfork",
                        color: .cyan
                    )

                    ToolCard(
                        title: "Metronome",
                        subtitle: "Click track",
                        icon: "metronome",
                        color: .red
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Tools")
    }
}

struct ToolCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    var destination: AnyView?

    var body: some View {
        NavigationLink(destination: destination ?? AnyView(EmptyView())) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(color)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Cloud Hub

struct CloudHubView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Sync Status
                SyncStatusCard()

                // Cloud Features
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                    CloudFeatureCard(
                        title: "Collaboration",
                        subtitle: "Real-time sessions",
                        icon: "person.2",
                        color: .blue
                    )

                    CloudFeatureCard(
                        title: "Backup",
                        subtitle: "Auto cloud backup",
                        icon: "arrow.clockwise.icloud",
                        color: .green
                    )

                    CloudFeatureCard(
                        title: "Share",
                        subtitle: "Publish & share",
                        icon: "square.and.arrow.up",
                        color: .orange
                    )

                    CloudFeatureCard(
                        title: "Library",
                        subtitle: "Cloud samples",
                        icon: "square.stack.3d.up",
                        color: .purple
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Cloud")
    }
}

struct SyncStatusCard: View {
    var body: some View {
        HStack {
            Image(systemName: "checkmark.icloud.fill")
                .font(.title)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 4) {
                Text("All synced")
                    .font(.headline)

                Text("Last sync: Just now")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Sync Now") {}
                .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct CloudFeatureCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        Button(action: {}) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(color)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Audio") {
                    NavigationLink("Audio Device") { EmptyView() }
                    NavigationLink("Buffer Size") { EmptyView() }
                    NavigationLink("Sample Rate") { EmptyView() }
                }

                Section("MIDI") {
                    NavigationLink("MIDI Devices") { EmptyView() }
                    NavigationLink("MIDI Learn") { EmptyView() }
                }

                Section("Cloud") {
                    NavigationLink("Account") { EmptyView() }
                    NavigationLink("Sync Settings") { EmptyView() }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Build", value: "2024.12.05")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    MainDashboardView()
}
