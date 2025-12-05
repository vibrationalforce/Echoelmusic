import SwiftUI

// MARK: - Main Dashboard View
// Central hub for Echoelmusic - access all features from one place
// Now featuring Apple iOS 26 Liquid Glass design system

public struct MainDashboardView: View {
    @State private var selectedTab: DashboardTab = .create
    @State private var showSettings = false
    @State private var showQuickActions = false
    @State private var useLiquidGlass = true
    @State private var bioCoherence: Float = 0.65

    public init() {}

    public var body: some View {
        Group {
            if useLiquidGlass {
                // Liquid Glass design (iOS 26+)
                liquidGlassInterface
            } else {
                // Classic design (fallback)
                classicInterface
            }
        }
    }

    // MARK: - Liquid Glass Interface

    @ViewBuilder
    private var liquidGlassInterface: some View {
        ZStack {
            // Bio-reactive animated background
            AnimatedGlassBackground(
                colors: [
                    BioReactiveGlassColors.coherenceTint(bioCoherence),
                    BioReactiveGlassColors.vaporwavePurple,
                    BioReactiveGlassColors.vaporwaveCyan
                ]
            )

            VStack(spacing: 0) {
                // Liquid Glass header
                liquidGlassHeader

                // Content with page-style tabs
                TabView(selection: $selectedTab) {
                    LiquidGlassCreateHub()
                        .tag(DashboardTab.create)

                    LiquidGlassAIHub(coherence: bioCoherence)
                        .tag(DashboardTab.ai)

                    LiquidGlassVisualHub()
                        .tag(DashboardTab.visual)

                    LiquidGlassToolsHub()
                        .tag(DashboardTab.tools)

                    LiquidGlassCloudHub()
                        .tag(DashboardTab.cloud)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Liquid Glass tab bar
                LiquidGlassTabBar(
                    selectedTab: Binding(
                        get: { selectedTab.rawValue },
                        set: { selectedTab = DashboardTab(rawValue: $0) ?? .create }
                    ),
                    items: DashboardTab.allCases.map { ($0.icon, $0.label) },
                    tint: BioReactiveGlassColors.accentColor(bioCoherence)
                )
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) {
            LiquidGlassSettingsView()
        }
    }

    private var liquidGlassHeader: some View {
        HStack {
            // Logo
            HStack(spacing: 8) {
                Image(systemName: "waveform.circle.fill")
                    .font(.title)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Echoelmusic")
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            Spacer()

            // Bio indicator
            LiquidGlassBioIndicator(coherence: bioCoherence, compact: true)

            // Settings button
            LiquidGlassIconButton(icon: "gear", size: .small, tint: .white.opacity(0.8)) {
                showSettings = true
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - Classic Interface (Fallback)

    @ViewBuilder
    private var classicInterface: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                CreateHubView()
                    .tabItem {
                        Label("Create", systemImage: "waveform.badge.plus")
                    }
                    .tag(DashboardTab.create)

                AIHubView()
                    .tabItem {
                        Label("AI", systemImage: "brain")
                    }
                    .tag(DashboardTab.ai)

                VisualHubView()
                    .tabItem {
                        Label("Visual", systemImage: "sparkles.rectangle.stack")
                    }
                    .tag(DashboardTab.visual)

                ToolsHubView()
                    .tabItem {
                        Label("Tools", systemImage: "wrench.and.screwdriver")
                    }
                    .tag(DashboardTab.tools)

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

enum DashboardTab: Int, CaseIterable {
    case create, ai, visual, tools, cloud

    var icon: String {
        switch self {
        case .create: return "waveform.badge.plus"
        case .ai: return "brain"
        case .visual: return "sparkles.rectangle.stack"
        case .tools: return "wrench.and.screwdriver"
        case .cloud: return "cloud"
        }
    }

    var label: String {
        switch self {
        case .create: return "Create"
        case .ai: return "AI"
        case .visual: return "Visual"
        case .tools: return "Tools"
        case .cloud: return "Cloud"
        }
    }
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

// MARK: - Liquid Glass Hub Views

struct LiquidGlassCreateHub: View {
    @State private var searchText = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                LiquidGlassSearchBar(text: $searchText, placeholder: "Search projects...")

                // Recent Projects
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Recent Projects")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Spacer()
                        Button("See All") {}
                            .font(.subheadline)
                            .foregroundStyle(.cyan)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(0..<5) { i in
                                LiquidGlassProjectCard(
                                    name: "Project \(i + 1)",
                                    duration: "\(Int.random(in: 2...8)):\(String(format: "%02d", Int.random(in: 0...59)))",
                                    lastModified: "\(Int.random(in: 1...12))h ago",
                                    color: [Color.purple, .blue, .cyan, .pink, .orange][i % 5]
                                )
                            }
                        }
                    }
                }

                // Quick Create
                VStack(alignment: .leading, spacing: 16) {
                    Text("Quick Create")
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        LiquidGlassQuickAction(icon: "plus.circle.fill", title: "New Project", color: .blue)
                        LiquidGlassQuickAction(icon: "mic.fill", title: "Record", color: .red)
                        LiquidGlassQuickAction(icon: "square.and.arrow.down.fill", title: "Import", color: .green)
                        LiquidGlassQuickAction(icon: "sparkles", title: "AI Generate", color: .purple)
                    }
                }

                // Templates
                VStack(alignment: .leading, spacing: 16) {
                    Text("Templates")
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        LiquidGlassTemplateCard(name: "Electronic", icon: "bolt.fill", color: .cyan)
                        LiquidGlassTemplateCard(name: "Acoustic", icon: "guitars", color: .orange)
                        LiquidGlassTemplateCard(name: "Hip Hop", icon: "music.mic", color: .purple)
                        LiquidGlassTemplateCard(name: "Cinematic", icon: "film", color: .red)
                        LiquidGlassTemplateCard(name: "Ambient", icon: "cloud.fill", color: .blue)
                        LiquidGlassTemplateCard(name: "Podcast", icon: "mic.fill", color: .green)
                    }
                }
            }
            .padding()
        }
    }
}

struct LiquidGlassAIHub: View {
    let coherence: Float

    @State private var aiMode = 0
    let modes = ["Compose", "Analyze", "Generate", "Enhance"]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                LiquidGlassSegmentedControl(selection: $aiMode, options: modes, tint: .purple)

                // AI Status
                LiquidGlassCard(variant: .tinted, tint: .purple.opacity(0.2)) {
                    HStack(spacing: 16) {
                        LiquidGlassCircularProgress(progress: 0.0, size: 60, tint: .purple, label: "Ready")

                        VStack(alignment: .leading, spacing: 4) {
                            Text("AI Engine Ready")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Neural cores initialized")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }

                        Spacer()

                        Button("Start") {}
                            .buttonStyle(.liquidGlass(tint: .purple))
                    }
                }

                // Features
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    LiquidGlassFeatureCard(icon: "cpu", title: "AI Agents", subtitle: "Autonomous production", color: .purple)
                    LiquidGlassFeatureCard(icon: "music.quarternote.3", title: "Harmonizer", subtitle: "Intelligent harmonies", color: .blue)
                    LiquidGlassFeatureCard(icon: "square.stack.3d.up", title: "Stem Separator", subtitle: "Neural separation", color: .green)
                    LiquidGlassFeatureCard(icon: "wand.and.stars", title: "Auto-Master", subtitle: "Professional mastering", color: .orange)
                }
            }
            .padding()
        }
    }
}

struct LiquidGlassVisualHub: View {
    @State private var selectedVisualizer = 0
    let visualizers = ["Spectrum", "Waveform", "Particles", "3D", "Neural"]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                LiquidGlassSegmentedControl(selection: $selectedVisualizer, options: visualizers, tint: .purple)

                // Preview
                LiquidGlassCard(variant: .clear) {
                    ZStack {
                        Rectangle()
                            .fill(LinearGradient(colors: [.purple.opacity(0.3), .cyan.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(height: 250)

                        VStack {
                            Image(systemName: "waveform.path")
                                .font(.system(size: 60))
                                .foregroundStyle(.white.opacity(0.5))
                            Text(visualizers[selectedVisualizer])
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }

                // Features
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    LiquidGlassFeatureCard(icon: "atom", title: "Physics Engine", subtitle: "Particle systems", color: .purple)
                    LiquidGlassFeatureCard(icon: "rectangle.split.2x2", title: "VJ Mode", subtitle: "Live performance", color: .pink)
                    LiquidGlassFeatureCard(icon: "cube", title: "3D Scene", subtitle: "Immersive visuals", color: .orange)
                    LiquidGlassFeatureCard(icon: "brain", title: "Neural Style", subtitle: "AI art transfer", color: .green)
                }
            }
            .padding()
        }
    }
}

struct LiquidGlassToolsHub: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    LiquidGlassFeatureCard(icon: "puzzlepiece.extension", title: "Plugins", subtitle: "AU/VST3 browser", color: .blue)
                    LiquidGlassFeatureCard(icon: "arrow.triangle.2.circlepath", title: "Automation", subtitle: "n8n workflows", color: .orange)
                    LiquidGlassFeatureCard(icon: "pianokeys", title: "MIDI/OSC", subtitle: "Controller mapping", color: .purple)
                    LiquidGlassFeatureCard(icon: "chart.bar", title: "Analyzer", subtitle: "Spectrum & metering", color: .green)
                    LiquidGlassFeatureCard(icon: "tuningfork", title: "Tuner", subtitle: "Chromatic tuner", color: .cyan)
                    LiquidGlassFeatureCard(icon: "metronome", title: "Metronome", subtitle: "Click track", color: .red)
                }
            }
            .padding()
        }
    }
}

struct LiquidGlassCloudHub: View {
    @State private var isSyncing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Sync status
                LiquidGlassCard(variant: .tinted, tint: .green.opacity(0.2)) {
                    HStack(spacing: 16) {
                        Image(systemName: "checkmark.icloud.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.green)
                            .symbolEffect(.rotate, isActive: isSyncing)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("All Synced")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Last sync: Just now")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }

                        Spacer()

                        Button("Sync Now") {
                            isSyncing = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                isSyncing = false
                            }
                        }
                        .buttonStyle(.liquidGlass(variant: .regular, size: .small))
                    }
                }

                // Storage
                LiquidGlassProgress(progress: 0.45, label: "4.5 GB of 10 GB used", tint: .cyan)

                // Features
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    LiquidGlassFeatureCard(icon: "person.2", title: "Collaboration", subtitle: "Real-time sessions", color: .blue)
                    LiquidGlassFeatureCard(icon: "arrow.clockwise.icloud", title: "Backup", subtitle: "Auto cloud backup", color: .green)
                    LiquidGlassFeatureCard(icon: "square.and.arrow.up", title: "Share", subtitle: "Publish & share", color: .orange)
                    LiquidGlassFeatureCard(icon: "square.stack.3d.up", title: "Library", subtitle: "Cloud samples", color: .purple)
                }
            }
            .padding()
        }
    }
}

#Preview("Liquid Glass Dashboard") {
    ZStack {
        AnimatedGlassBackground()
        LiquidGlassCreateHub()
    }
    .preferredColorScheme(.dark)
}
