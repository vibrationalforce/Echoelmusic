import SwiftUI
import Combine

// MARK: - Liquid Glass Views
// Complete app screen implementations using Apple iOS 26 Liquid Glass design
// Bio-reactive, immersive, professional music production UI

// MARK: - Liquid Glass Main App

/// Root app view with Liquid Glass design system
struct LiquidGlassApp: View {
    @State private var selectedTab: AppTab = .create
    @State private var showSettings = false
    @State private var bioCoherence: Float = 0.65
    @State private var bioHRV: Float = 52
    @State private var bioHeartRate: Int = 72

    enum AppTab: Int, CaseIterable {
        case create, audio, visual, ai, cloud

        var icon: String {
            switch self {
            case .create: return "waveform.badge.plus"
            case .audio: return "waveform"
            case .visual: return "sparkles.rectangle.stack"
            case .ai: return "brain"
            case .cloud: return "cloud"
            }
        }

        var label: String {
            switch self {
            case .create: return "Create"
            case .audio: return "Audio"
            case .visual: return "Visual"
            case .ai: return "AI"
            case .cloud: return "Cloud"
            }
        }
    }

    var body: some View {
        ZStack {
            // Animated background
            AnimatedGlassBackground(
                colors: [
                    BioReactiveGlassColors.coherenceTint(bioCoherence),
                    BioReactiveGlassColors.vaporwavePurple,
                    BioReactiveGlassColors.vaporwaveCyan
                ]
            )

            VStack(spacing: 0) {
                // Navigation bar
                LiquidGlassAppHeader(
                    coherence: bioCoherence,
                    showSettings: $showSettings
                )

                // Content
                TabView(selection: $selectedTab) {
                    LiquidGlassCreateView()
                        .tag(AppTab.create)

                    LiquidGlassAudioView(coherence: bioCoherence)
                        .tag(AppTab.audio)

                    LiquidGlassVisualView()
                        .tag(AppTab.visual)

                    LiquidGlassAIView()
                        .tag(AppTab.ai)

                    LiquidGlassCloudView()
                        .tag(AppTab.cloud)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Tab bar
                LiquidGlassTabBar(
                    selectedTab: Binding(
                        get: { selectedTab.rawValue },
                        set: { selectedTab = AppTab(rawValue: $0) ?? .create }
                    ),
                    items: AppTab.allCases.map { ($0.icon, $0.label) },
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
}

// MARK: - App Header

struct LiquidGlassAppHeader: View {
    let coherence: Float
    @Binding var showSettings: Bool

    var body: some View {
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

            // Bio indicator (compact)
            LiquidGlassBioIndicator(coherence: coherence, compact: true)

            // Settings
            LiquidGlassIconButton(icon: "gear", size: .small, tint: .white.opacity(0.8)) {
                showSettings = true
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

// MARK: - Create View

struct LiquidGlassCreateView: View {
    @State private var searchText = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Search
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
                        LiquidGlassQuickAction(
                            icon: "plus.circle.fill",
                            title: "New Project",
                            color: .blue
                        )

                        LiquidGlassQuickAction(
                            icon: "mic.fill",
                            title: "Record",
                            color: .red
                        )

                        LiquidGlassQuickAction(
                            icon: "square.and.arrow.down.fill",
                            title: "Import",
                            color: .green
                        )

                        LiquidGlassQuickAction(
                            icon: "sparkles",
                            title: "AI Generate",
                            color: .purple
                        )
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

// MARK: - Project Card

struct LiquidGlassProjectCard: View {
    let name: String
    let duration: String
    let lastModified: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Waveform preview
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.6), color.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Mini waveform
                HStack(spacing: 2) {
                    ForEach(0..<20, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 3, height: CGFloat.random(in: 10...40))
                    }
                }
            }
            .frame(width: 160, height: 80)

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                HStack {
                    Text(duration)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(color)

                    Spacer()

                    Text(lastModified)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .padding(12)
        .liquidGlass(.regular, cornerRadius: 20)
    }
}

// MARK: - Quick Action

struct LiquidGlassQuickAction: View {
    let icon: String
    let title: String
    let color: Color

    @State private var isPressed = false

    var body: some View {
        Button {
            // Action
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding()
            .liquidGlass(.tinted, tint: color.opacity(0.3), cornerRadius: 16)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.97 : 1)
        .animation(.spring(response: 0.2), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Template Card

struct LiquidGlassTemplateCard: View {
    let name: String
    let icon: String
    let color: Color

    var body: some View {
        Button {
            // Action
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(color)

                Text(name)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .liquidGlass(.regular, cornerRadius: 16, interactive: true)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Audio View

struct LiquidGlassAudioView: View {
    let coherence: Float

    @State private var masterVolume: Double = 0.75
    @State private var selectedChannel = 0
    @State private var isPlaying = false
    @State private var levels: [Float] = (0..<8).map { _ in Float.random(in: 0.2...0.8) }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Transport controls
                LiquidGlassTransportBar(isPlaying: $isPlaying)

                // Master section
                LiquidGlassCard(variant: .tinted, tint: BioReactiveGlassColors.coherenceTint(coherence).opacity(0.2)) {
                    VStack(spacing: 16) {
                        Text("Master")
                            .font(.headline)
                            .foregroundStyle(.white)

                        LiquidGlassSlider(
                            value: $masterVolume,
                            label: "Volume",
                            tint: BioReactiveGlassColors.coherenceTint(coherence)
                        )

                        // Spectrum
                        LiquidGlassSpectrum(
                            bands: levels,
                            tint: BioReactiveGlassColors.coherenceTint(coherence)
                        )
                        .frame(height: 100)
                    }
                }

                // Channel mixer
                VStack(alignment: .leading, spacing: 16) {
                    Text("Channels")
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<8) { i in
                                LiquidGlassChannelStrip(
                                    name: ["Drums", "Bass", "Keys", "Guitar", "Synth", "Vox", "FX", "Aux"][i],
                                    level: levels[i],
                                    isSelected: selectedChannel == i,
                                    color: [Color.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink][i]
                                ) {
                                    selectedChannel = i
                                }
                            }
                        }
                    }
                }

                // Waveform
                VStack(alignment: .leading, spacing: 16) {
                    Text("Timeline")
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    LiquidGlassWaveform(
                        samples: (0..<200).map { _ in Float.random(in: -0.8...0.8) },
                        tint: BioReactiveGlassColors.coherenceTint(coherence)
                    )
                    .frame(height: 120)
                }
            }
            .padding()
        }
    }
}

// MARK: - Transport Bar

struct LiquidGlassTransportBar: View {
    @Binding var isPlaying: Bool

    @State private var currentTime = "0:00"
    @State private var bpm: Int = 120

    var body: some View {
        HStack(spacing: 16) {
            // Time display
            VStack(alignment: .leading, spacing: 2) {
                Text(currentTime)
                    .font(.title2.monospacedDigit())
                    .foregroundStyle(.white)

                Text("\(bpm) BPM")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.cyan)
            }

            Spacer()

            // Transport controls
            HStack(spacing: 12) {
                LiquidGlassIconButton(icon: "backward.fill", size: .medium) {}

                LiquidGlassIconButton(
                    icon: isPlaying ? "pause.fill" : "play.fill",
                    size: .large,
                    tint: .green
                ) {
                    isPlaying.toggle()
                }

                LiquidGlassIconButton(icon: "forward.fill", size: .medium) {}

                LiquidGlassIconButton(icon: "stop.fill", size: .medium, tint: .red) {
                    isPlaying = false
                }
            }

            Spacer()

            // Record button
            LiquidGlassIconButton(icon: "record.circle", size: .large, tint: .red) {}
        }
        .padding()
        .liquidGlass(.regular, cornerRadius: 20)
    }
}

// MARK: - Channel Strip

struct LiquidGlassChannelStrip: View {
    let name: String
    let level: Float
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    @State private var volume: Double = 0.75
    @State private var pan: Double = 0.5
    @State private var isMuted = false
    @State private var isSolo = false

    var body: some View {
        VStack(spacing: 12) {
            // Channel name
            Text(name)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(1)

            // Level meter
            LiquidGlassAudioMeter(level: level, peak: level + 0.1, orientation: .vertical)
                .frame(width: 20, height: 100)

            // Fader (simplified)
            VStack(spacing: 4) {
                Text(String(format: "%.0f", volume * 100))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(color)

                Slider(value: $volume)
                    .tint(color)
                    .frame(width: 60)
                    .rotationEffect(.degrees(-90))
                    .frame(width: 20, height: 60)
            }

            // Mute/Solo
            HStack(spacing: 4) {
                Button {
                    isMuted.toggle()
                } label: {
                    Text("M")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(isMuted ? .black : .white.opacity(0.6))
                        .frame(width: 24, height: 24)
                        .background(isMuted ? Color.yellow : Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)

                Button {
                    isSolo.toggle()
                } label: {
                    Text("S")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(isSolo ? .black : .white.opacity(0.6))
                        .frame(width: 24, height: 24)
                        .background(isSolo ? Color.green : Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(width: 80)
        .liquidGlass(
            isSelected ? .tinted : .regular,
            tint: isSelected ? color.opacity(0.3) : nil,
            cornerRadius: 16
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isSelected ? color : Color.clear, lineWidth: 2)
        )
        .onTapGesture(perform: action)
    }
}

// MARK: - Visual View

struct LiquidGlassVisualView: View {
    @State private var selectedVisualizer = 0
    let visualizers = ["Spectrum", "Waveform", "Particles", "3D", "Neural"]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Visualizer selector
                LiquidGlassSegmentedControl(
                    selection: $selectedVisualizer,
                    options: visualizers,
                    tint: .purple
                )

                // Preview area
                LiquidGlassCard(variant: .clear) {
                    ZStack {
                        // Placeholder for visualizer
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.purple.opacity(0.3), .cyan.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 300)

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

                // Features grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    LiquidGlassFeatureCard(
                        icon: "atom",
                        title: "Physics Engine",
                        subtitle: "Particle systems",
                        color: .purple
                    )

                    LiquidGlassFeatureCard(
                        icon: "rectangle.split.2x2",
                        title: "VJ Mode",
                        subtitle: "Live performance",
                        color: .pink
                    )

                    LiquidGlassFeatureCard(
                        icon: "cube",
                        title: "3D Scene",
                        subtitle: "Immersive visuals",
                        color: .orange
                    )

                    LiquidGlassFeatureCard(
                        icon: "brain",
                        title: "Neural Style",
                        subtitle: "AI art transfer",
                        color: .green
                    )
                }
            }
            .padding()
        }
    }
}

// MARK: - Feature Card

struct LiquidGlassFeatureCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        Button {
            // Navigation
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(color)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .liquidGlass(.tinted, tint: color.opacity(0.2), cornerRadius: 20, interactive: true)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AI View

struct LiquidGlassAIView: View {
    @State private var aiMode = 0
    let modes = ["Compose", "Analyze", "Generate", "Enhance"]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Mode selector
                LiquidGlassSegmentedControl(
                    selection: $aiMode,
                    options: modes,
                    tint: .purple
                )

                // AI status card
                LiquidGlassCard(variant: .tinted, tint: .purple.opacity(0.2)) {
                    HStack(spacing: 16) {
                        LiquidGlassCircularProgress(
                            progress: 0.0,
                            size: 60,
                            tint: .purple,
                            label: "Ready"
                        )

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

                // Features grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    LiquidGlassFeatureCard(
                        icon: "cpu",
                        title: "AI Agents",
                        subtitle: "Autonomous production",
                        color: .purple
                    )

                    LiquidGlassFeatureCard(
                        icon: "music.quarternote.3",
                        title: "Harmonizer",
                        subtitle: "Intelligent harmonies",
                        color: .blue
                    )

                    LiquidGlassFeatureCard(
                        icon: "square.stack.3d.up",
                        title: "Stem Separator",
                        subtitle: "Neural separation",
                        color: .green
                    )

                    LiquidGlassFeatureCard(
                        icon: "wand.and.stars",
                        title: "Auto-Master",
                        subtitle: "Professional mastering",
                        color: .orange
                    )

                    LiquidGlassFeatureCard(
                        icon: "slider.horizontal.3",
                        title: "Auto-Mix",
                        subtitle: "AI mixing assistant",
                        color: .pink
                    )

                    LiquidGlassFeatureCard(
                        icon: "paintbrush",
                        title: "Style Transfer",
                        subtitle: "Transform your sound",
                        color: .cyan
                    )
                }
            }
            .padding()
        }
    }
}

// MARK: - Cloud View

struct LiquidGlassCloudView: View {
    @State private var syncProgress: Double = 1.0
    @State private var isSyncing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Sync status
                LiquidGlassCard(variant: .tinted, tint: .green.opacity(0.2)) {
                    HStack(spacing: 16) {
                        Image(systemName: syncProgress >= 1.0 ? "checkmark.icloud.fill" : "arrow.clockwise.icloud")
                            .font(.largeTitle)
                            .foregroundStyle(.green)
                            .symbolEffect(.rotate, isActive: isSyncing)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(syncProgress >= 1.0 ? "All Synced" : "Syncing...")
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

                // Storage usage
                VStack(alignment: .leading, spacing: 16) {
                    Text("Storage")
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    LiquidGlassProgress(
                        progress: 0.45,
                        label: "4.5 GB of 10 GB used",
                        tint: .cyan
                    )
                }

                // Cloud features
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    LiquidGlassFeatureCard(
                        icon: "person.2",
                        title: "Collaboration",
                        subtitle: "Real-time sessions",
                        color: .blue
                    )

                    LiquidGlassFeatureCard(
                        icon: "arrow.clockwise.icloud",
                        title: "Backup",
                        subtitle: "Auto cloud backup",
                        color: .green
                    )

                    LiquidGlassFeatureCard(
                        icon: "square.and.arrow.up",
                        title: "Share",
                        subtitle: "Publish & share",
                        color: .orange
                    )

                    LiquidGlassFeatureCard(
                        icon: "square.stack.3d.up",
                        title: "Library",
                        subtitle: "Cloud samples",
                        color: .purple
                    )
                }
            }
            .padding()
        }
    }
}

// MARK: - Settings View

struct LiquidGlassSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var bufferSize = 2
    @State private var sampleRate = 1
    @State private var bioEnabled = true
    @State private var cloudSync = true

    let bufferSizes = ["64", "128", "256", "512", "1024"]
    let sampleRates = ["44.1 kHz", "48 kHz", "96 kHz", "192 kHz"]

    var body: some View {
        ZStack {
            AnimatedGlassBackground()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Settings")
                        .font(.title.bold())
                        .foregroundStyle(.white)

                    Spacer()

                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.cyan)
                }
                .padding()

                ScrollView {
                    VStack(spacing: 24) {
                        // Audio settings
                        LiquidGlassSettingsSection(title: "Audio") {
                            LiquidGlassPicker(
                                selection: $bufferSize,
                                options: Array(0..<bufferSizes.count),
                                label: "Buffer Size",
                                tint: .cyan
                            ) { index in
                                bufferSizes[index]
                            }

                            LiquidGlassPicker(
                                selection: $sampleRate,
                                options: Array(0..<sampleRates.count),
                                label: "Sample Rate",
                                tint: .cyan
                            ) { index in
                                sampleRates[index]
                            }
                        }

                        // Bio settings
                        LiquidGlassSettingsSection(title: "Bio-Reactive") {
                            Toggle("Enable Bio-Reactive Mode", isOn: $bioEnabled)
                                .toggleStyle(LiquidGlassToggleStyle(onColor: .green))

                            LiquidGlassListRow(
                                icon: "heart.fill",
                                title: "HealthKit Integration",
                                subtitle: "Connect to Apple Health",
                                tint: .red
                            ) {}
                        }

                        // Cloud settings
                        LiquidGlassSettingsSection(title: "Cloud") {
                            Toggle("Auto Sync", isOn: $cloudSync)
                                .toggleStyle(LiquidGlassToggleStyle(onColor: .blue))

                            LiquidGlassListRow(
                                icon: "person.circle",
                                title: "Account",
                                subtitle: "Manage your account",
                                tint: .cyan
                            ) {}
                        }

                        // About
                        LiquidGlassSettingsSection(title: "About") {
                            LiquidGlassListRow(
                                title: "Version",
                                trailing: "1.0.0"
                            )

                            LiquidGlassListRow(
                                title: "Build",
                                trailing: "2025.12.05"
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Settings Section

struct LiquidGlassSettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 8)

            VStack(spacing: 8) {
                content
            }
        }
    }
}

// MARK: - Preview

#Preview("Liquid Glass App") {
    LiquidGlassApp()
}

#Preview("Liquid Glass Audio View") {
    ZStack {
        AnimatedGlassBackground()
        LiquidGlassAudioView(coherence: 0.7)
    }
    .preferredColorScheme(.dark)
}

#Preview("Liquid Glass Settings") {
    LiquidGlassSettingsView()
}
