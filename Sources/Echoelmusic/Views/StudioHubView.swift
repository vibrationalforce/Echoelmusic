import SwiftUI

// MARK: - Professional Studio Hub
// Central access point for all professional production features:
// - Plugin Host (VST3/AU/AAX)
// - Visual Programming (TouchDesigner-style)
// - Dolby Atmos Renderer (3D Spatial Audio)
// - Medical Imaging Bridge
// - Social Media Command Center

struct StudioHubView: View {

    // MARK: - State

    @State private var selectedModule: StudioModule?
    @State private var showModuleDetail = false

    enum StudioModule: String, CaseIterable, Identifiable {
        case plugins = "Plugin Host"
        case visual = "Visual Engine"
        case atmos = "Spatial Audio"
        case medical = "Medical Bridge"
        case social = "Social Media"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .plugins: return "puzzlepiece.extension"
            case .visual: return "square.grid.3x3.topleft.filled"
            case .atmos: return "speaker.wave.3.fill"
            case .medical: return "waveform.path.ecg"
            case .social: return "square.and.arrow.up.on.square"
            }
        }

        var color: Color {
            switch self {
            case .plugins: return .orange
            case .visual: return .purple
            case .atmos: return .blue
            case .medical: return .green
            case .social: return .pink
            }
        }

        var description: String {
            switch self {
            case .plugins: return "Load VST3, AU, AAX plugins"
            case .visual: return "Node-based visual programming"
            case .atmos: return "Dolby Atmos 3D/4D audio"
            case .medical: return "DICOM, EEG, sonification"
            case .social: return "Multi-platform management"
            }
        }

        var features: [String] {
            switch self {
            case .plugins:
                return [
                    "VST3/AU/AAX/CLAP hosting",
                    "Plugin scanner with vendor detection",
                    "Preset management",
                    "Chain processing",
                    "Latency compensation"
                ]
            case .visual:
                return [
                    "TOP (Texture) operators",
                    "CHOP (Channel) operators",
                    "SOP (3D Surface) operators",
                    "Bio-reactive nodes",
                    "GLSL shader editor"
                ]
            case .atmos:
                return [
                    "Object-based 3D panning",
                    "5.1/7.1.4/9.1.6 layouts",
                    "Binaural HRTF rendering",
                    "ADM metadata export",
                    "Head tracking support"
                ]
            case .medical:
                return [
                    "DICOM/NIFTI import",
                    "EEG band power analysis",
                    "EKG R-peak detection",
                    "Medical sonification",
                    "HL7 FHIR integration"
                ]
            case .social:
                return [
                    "10+ platform support",
                    "Content calendar",
                    "Analytics dashboard",
                    "Multi-platform streaming",
                    "Engagement tracking"
                ]
            }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color.black, Color(white: 0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection

                        // Module Grid
                        moduleGrid

                        // Quick Actions
                        quickActions
                    }
                    .padding()
                }
            }
            .navigationTitle("Studio Hub")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedModule) { module in
                moduleDetailView(for: module)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink, .purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(alignment: .leading) {
                    Text("Professional Tools")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("Advanced production features")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
    }

    // MARK: - Module Grid

    private var moduleGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ForEach(StudioModule.allCases) { module in
                moduleCard(module)
            }
        }
    }

    private func moduleCard(_ module: StudioModule) -> some View {
        Button {
            selectedModule = module
        } label: {
            VStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(module.color.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: module.icon)
                        .font(.system(size: 24))
                        .foregroundColor(module.color)
                }

                // Title
                Text(module.rawValue)
                    .font(.headline)
                    .foregroundColor(.white)

                // Description
                Text(module.description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(module.color.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("QUICK ACTIONS")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.gray)
                .tracking(2)

            HStack(spacing: 12) {
                quickActionButton(
                    title: "Scan Plugins",
                    icon: "magnifyingglass",
                    color: .orange
                )

                quickActionButton(
                    title: "New Visual Project",
                    icon: "plus.square",
                    color: .purple
                )

                quickActionButton(
                    title: "Export Atmos",
                    icon: "square.and.arrow.up",
                    color: .blue
                )
            }
        }
    }

    private func quickActionButton(title: String, icon: String, color: Color) -> some View {
        Button {
            // Action
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)

                Text(title)
                    .font(.caption2)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
    }

    // MARK: - Module Detail View

    @ViewBuilder
    private func moduleDetailView(for module: StudioModule) -> some View {
        switch module {
        case .plugins:
            PluginHostView()
        case .visual:
            VisualNodeEditorView()
        case .atmos:
            DolbyAtmosView()
        case .medical:
            MedicalBridgeView()
        case .social:
            SocialMediaHubView()
        }
    }
}

// MARK: - Plugin Host View

struct PluginHostView: View {
    @StateObject private var pluginManager = PluginHostManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    // Scanner Status
                    if pluginManager.scanner.isScanning {
                        ProgressView(value: pluginManager.scanner.scanProgress) {
                            Text("Scanning plugins...")
                                .foregroundColor(.gray)
                        }
                        .tint(.orange)
                        .padding()
                    }

                    // Plugin List
                    List {
                        ForEach(pluginManager.scanner.availablePlugins) { plugin in
                            pluginRow(plugin)
                        }
                    }
                    .listStyle(.plain)

                    // Scan Button
                    Button {
                        Task {
                            await pluginManager.scanner.scanAllFormats()
                        }
                    } label: {
                        Label("Scan for Plugins", systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .padding()
                }
            }
            .navigationTitle("Plugin Host")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func pluginRow(_ plugin: PluginMetadata) -> some View {
        HStack {
            Image(systemName: plugin.isSynth ? "pianokeys" : "slider.horizontal.3")
                .foregroundColor(plugin.isSynth ? .purple : .blue)

            VStack(alignment: .leading) {
                Text(plugin.name)
                    .font(.headline)
                    .foregroundColor(.white)

                Text("\(plugin.vendor) • \(plugin.format.rawValue)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Button("Load") {
                Task {
                    _ = try? await pluginManager.loadPlugin(plugin)
                }
            }
            .buttonStyle(.bordered)
            .tint(.orange)
        }
        .listRowBackground(Color.white.opacity(0.05))
    }
}

// MARK: - Visual Node Editor View

struct VisualNodeEditorView: View {
    @StateObject private var graphManager = NodeGraphManager()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack {
                    // Toolbar
                    HStack {
                        Button("Add TOP") {
                            graphManager.addNode(NoiseTOP())
                        }
                        .buttonStyle(.bordered)

                        Button("Add CHOP") {
                            graphManager.addNode(LFOCHOP())
                        }
                        .buttonStyle(.bordered)

                        Button("Add SOP") {
                            graphManager.addNode(SphereSOP())
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        // FPS Counter
                        Text(String(format: "%.1f FPS", graphManager.fps))
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding()

                    // Node Canvas (placeholder)
                    GeometryReader { geometry in
                        ZStack {
                            // Grid background
                            Canvas { context, size in
                                let gridSize: CGFloat = 20
                                for x in stride(from: 0, through: size.width, by: gridSize) {
                                    var path = Path()
                                    path.move(to: CGPoint(x: x, y: 0))
                                    path.addLine(to: CGPoint(x: x, y: size.height))
                                    context.stroke(path, with: .color(.white.opacity(0.1)), lineWidth: 0.5)
                                }
                                for y in stride(from: 0, through: size.height, by: gridSize) {
                                    var path = Path()
                                    path.move(to: CGPoint(x: 0, y: y))
                                    path.addLine(to: CGPoint(x: size.width, y: y))
                                    context.stroke(path, with: .color(.white.opacity(0.1)), lineWidth: 0.5)
                                }
                            }

                            // Nodes
                            ForEach(graphManager.nodes, id: \.id) { node in
                                nodeView(for: node)
                                    .position(node.position)
                            }
                        }
                    }

                    // Status Bar
                    HStack {
                        Text("Nodes: \(graphManager.nodes.count)")
                        Spacer()
                        Text("Cook: \(String(format: "%.2fms", graphManager.totalCookTime * 1000))")
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("Visual Engine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(graphManager.isRunning ? "Stop" : "Run") {
                        if graphManager.isRunning {
                            graphManager.stop()
                        } else {
                            graphManager.start()
                        }
                    }
                    .tint(graphManager.isRunning ? .red : .green)
                }
            }
        }
    }

    private func nodeView(for node: any VisualNode) -> some View {
        VStack(spacing: 4) {
            Text(node.name)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(node.nodeType.rawValue)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.purple.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.purple, lineWidth: 1)
                )
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    node.position = value.location
                }
        )
    }
}

// MARK: - Dolby Atmos View

struct DolbyAtmosView: View {
    @StateObject private var renderer = DolbyAtmosRenderer()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    // 3D Panning View (Top-down)
                    ZStack {
                        // Room outline
                        Circle()
                            .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                            .frame(width: 250, height: 250)

                        // Speaker positions
                        ForEach(Array(renderer.speakerLayout.speakers.enumerated()), id: \.offset) { index, speaker in
                            if !speaker.isLFE {
                                speakerDot(speaker: speaker, index: index)
                            }
                        }

                        // Audio objects
                        ForEach(renderer.objects) { object in
                            objectDot(object: object)
                        }

                        // Center (listener)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 10, height: 10)
                    }
                    .frame(height: 280)

                    // Controls
                    VStack(spacing: 12) {
                        // Layout Picker
                        Picker("Layout", selection: Binding(
                            get: { renderer.speakerLayout.name },
                            set: { name in
                                switch name {
                                case "5.1": renderer.setLayout(.surround51)
                                case "7.1": renderer.setLayout(.surround71)
                                case "7.1.4": renderer.setLayout(.atmos714)
                                case "9.1.6": renderer.setLayout(.atmos916)
                                default: break
                                }
                            }
                        )) {
                            Text("5.1").tag("5.1")
                            Text("7.1").tag("7.1")
                            Text("7.1.4").tag("7.1.4")
                            Text("9.1.6").tag("9.1.6")
                        }
                        .pickerStyle(.segmented)

                        // Binaural Toggle
                        Toggle("Binaural (Headphones)", isOn: $renderer.binauralMode)
                            .tint(.blue)

                        // Add Object Button
                        Button {
                            _ = renderer.addObject(name: "Object \(renderer.objects.count + 1)")
                        } label: {
                            Label("Add Audio Object", systemImage: "plus.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                    .padding()

                    Spacer()
                }
            }
            .navigationTitle("Dolby Atmos")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func speakerDot(speaker: SpeakerLayout.Speaker, index: Int) -> some View {
        let position = speakerPosition(azimuth: speaker.azimuth, elevation: speaker.elevation)
        return ZStack {
            Circle()
                .fill(Color.blue)
                .frame(width: 12, height: 12)

            Text(speaker.name)
                .font(.system(size: 8))
                .foregroundColor(.white)
                .offset(y: -16)
        }
        .position(x: 125 + position.x * 100, y: 125 - position.y * 100)
    }

    private func objectDot(object: AudioObject) -> some View {
        ZStack {
            Circle()
                .fill(Color.orange)
                .frame(width: 16, height: 16)

            Text(object.name.prefix(2))
                .font(.system(size: 8))
                .foregroundColor(.white)
        }
        .position(
            x: 125 + CGFloat(object.position.x) * 100,
            y: 125 - CGFloat(object.position.z) * 100
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    let x = Float((value.location.x - 125) / 100)
                    let z = Float((125 - value.location.y) / 100)
                    object.position = SIMD3<Float>(x, object.position.y, z)
                }
        )
    }

    private func speakerPosition(azimuth: Float, elevation: Float) -> CGPoint {
        let rad = azimuth * .pi / 180
        return CGPoint(
            x: CGFloat(sin(rad)),
            y: CGFloat(cos(rad))
        )
    }
}

// MARK: - Medical Bridge View

struct MedicalBridgeView: View {
    @StateObject private var waveformProcessor = PhysiologicalWaveformProcessor()
    @StateObject private var sonificationEngine = MedicalSonificationEngine()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // EEG Band Powers
                        VStack(alignment: .leading, spacing: 12) {
                            Text("EEG BAND POWERS")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                                .tracking(2)

                            HStack(spacing: 8) {
                                bandBar(name: "Delta", value: waveformProcessor.deltaPower, color: .purple)
                                bandBar(name: "Theta", value: waveformProcessor.thetaPower, color: .blue)
                                bandBar(name: "Alpha", value: waveformProcessor.alphaPower, color: .green)
                                bandBar(name: "Beta", value: waveformProcessor.betaPower, color: .yellow)
                                bandBar(name: "Gamma", value: waveformProcessor.gammaPower, color: .orange)
                            }
                            .frame(height: 100)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)

                        // EKG Metrics
                        VStack(alignment: .leading, spacing: 12) {
                            Text("EKG METRICS")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                                .tracking(2)

                            HStack(spacing: 20) {
                                metricCard(
                                    value: String(format: "%.0f", waveformProcessor.heartRate),
                                    unit: "BPM",
                                    label: "Heart Rate",
                                    color: .red
                                )

                                metricCard(
                                    value: String(format: "%.0f", waveformProcessor.rrInterval),
                                    unit: "ms",
                                    label: "RR Interval",
                                    color: .orange
                                )

                                metricCard(
                                    value: String(format: "%.1f", waveformProcessor.hrvRMSSD),
                                    unit: "ms",
                                    label: "HRV RMSSD",
                                    color: .green
                                )
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)

                        // Sonification Controls
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SONIFICATION")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                                .tracking(2)

                            Picker("Mode", selection: $sonificationEngine.sonificationMode) {
                                Text("Spectral").tag(MedicalSonificationEngine.SonificationMode.spectral)
                                Text("Temporal").tag(MedicalSonificationEngine.SonificationMode.temporal)
                                Text("Parameter").tag(MedicalSonificationEngine.SonificationMode.parameter)
                                Text("Rhythmic").tag(MedicalSonificationEngine.SonificationMode.rhythmic)
                            }
                            .pickerStyle(.segmented)

                            Button {
                                sonificationEngine.isPlaying.toggle()
                            } label: {
                                Label(
                                    sonificationEngine.isPlaying ? "Stop" : "Play Sonification",
                                    systemImage: sonificationEngine.isPlaying ? "stop.fill" : "play.fill"
                                )
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)

                        // Disclaimer
                        Text("For research and visualization purposes only. Not intended for clinical diagnosis.")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .padding()
                }
            }
            .navigationTitle("Medical Bridge")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func bandBar(name: String, value: Float, color: Color) -> some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(color)
                        .frame(height: geo.size.height * CGFloat(min(value, 1.0)))
                }
            }

            Text(name)
                .font(.system(size: 8))
                .foregroundColor(.gray)
        }
    }

    private func metricCard(value: String, unit: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(color)

                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Social Media Hub View

struct SocialMediaHubView: View {
    @StateObject private var socialCenter = SocialMediaCommandCenter.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Connected Accounts
                        VStack(alignment: .leading, spacing: 12) {
                            Text("CONNECTED ACCOUNTS")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                                .tracking(2)

                            if socialCenter.accounts.isEmpty {
                                Text("No accounts connected")
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else {
                                ForEach(socialCenter.accounts) { account in
                                    accountRow(account)
                                }
                            }

                            Button {
                                // Connect new account
                            } label: {
                                Label("Connect Account", systemImage: "plus.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.pink)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)

                        // Supported Platforms
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SUPPORTED PLATFORMS")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                                .tracking(2)

                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 16) {
                                ForEach(SocialPlatform.allCases, id: \.self) { platform in
                                    platformIcon(platform)
                                }
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)

                        // Quick Actions
                        VStack(alignment: .leading, spacing: 12) {
                            Text("QUICK ACTIONS")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                                .tracking(2)

                            Button {
                                // Open calendar
                            } label: {
                                Label("Content Calendar", systemImage: "calendar")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                // Open analytics
                            } label: {
                                Label("Analytics Dashboard", systemImage: "chart.bar")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                // Start live stream
                            } label: {
                                Label("Start Live Stream", systemImage: "video.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                    }
                    .padding()
                }
            }
            .navigationTitle("Social Media")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func accountRow(_ account: SocialAccount) -> some View {
        HStack {
            Image(systemName: platformIcon(for: account.platform))
                .foregroundColor(platformColor(for: account.platform))

            VStack(alignment: .leading) {
                Text(account.displayName)
                    .font(.headline)
                    .foregroundColor(.white)

                Text("@\(account.username)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Circle()
                .fill(account.isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }

    private func platformIcon(_ platform: SocialPlatform) -> some View {
        VStack(spacing: 4) {
            Image(systemName: platformIcon(for: platform))
                .font(.system(size: 20))
                .foregroundColor(platformColor(for: platform))

            Text(platform.rawValue.prefix(4))
                .font(.system(size: 8))
                .foregroundColor(.gray)
        }
    }

    private func platformIcon(for platform: SocialPlatform) -> String {
        switch platform {
        case .instagram: return "camera"
        case .tiktok: return "music.note"
        case .youtube: return "play.rectangle"
        case .facebook: return "person.2"
        case .twitter: return "bubble.left"
        case .linkedin: return "briefcase"
        case .twitch: return "gamecontroller"
        case .discord: return "message"
        case .threads: return "at"
        case .bluesky: return "cloud"
        }
    }

    private func platformColor(for platform: SocialPlatform) -> Color {
        switch platform {
        case .instagram: return .pink
        case .tiktok: return .cyan
        case .youtube: return .red
        case .facebook: return .blue
        case .twitter: return .blue
        case .linkedin: return .blue
        case .twitch: return .purple
        case .discord: return .indigo
        case .threads: return .gray
        case .bluesky: return .cyan
        }
    }
}

// MARK: - Preview

#Preview {
    StudioHubView()
}
