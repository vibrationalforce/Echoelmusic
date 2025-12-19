import SwiftUI

/// Quality & Format Settings UI
/// **Hardware-intelligent quality and format control**
///
/// **Features**:
/// - Automatic hardware detection and optimization
/// - Professional video codecs (ProRes, H.265, H.264, AV1)
/// - Professional audio formats (WAV, FLAC, ALAC, AAC, Opus, MP3)
/// - Quality presets (Draft, Good, Best, Master)
/// - Performance modes (Efficiency, Balanced, Performance)
/// - Real-time file size estimation
/// - Battery and thermal awareness
struct QualityFormatSettingsView: View {
    @StateObject private var settings = QualityFormatSettings()
    @State private var showingResetAlert = false
    @State private var estimatedDurationMinutes: Double = 1.0  // Default 1 minute

    var body: some View {
        NavigationView {
            Form {
                // HARDWARE PROFILE
                hardwareSection

                // QUALITY PRESETS
                qualityPresetsSection

                // VIDEO SETTINGS
                videoSection

                // AUDIO SETTINGS
                audioSection

                // PERFORMANCE & OPTIMIZATION
                performanceSection

                // FILE SIZE ESTIMATION
                fileSizeSection

                // ACTIONS
                actionsSection
            }
            .navigationTitle("Quality & Format")
            .navigationBarTitleDisplayMode(.large)
            .alert("Auto-Optimize for Hardware", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Optimize") {
                    settings.optimizeForHardware()
                }
            } message: {
                Text("This will reset all settings to recommended values for your device.")
            }
        }
    }

    // MARK: - Hardware Section

    private var hardwareSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: hardwareIcon)
                        .font(.title2)
                        .foregroundColor(hardwareColor)

                    VStack(alignment: .leading) {
                        Text("Hardware Profile")
                            .font(.headline)
                        Text(settings.hardwareProfile.displayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if settings.autoOptimize {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }

                Divider()

                // Hardware specs
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("CPU Cores:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(settings.deviceInfo.cpuCores)")
                            .font(.caption.bold())
                    }

                    HStack {
                        Text("RAM:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(settings.deviceInfo.totalRAM / 1_073_741_824) GB")
                            .font(.caption.bold())
                    }

                    HStack {
                        Text("GPU:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(settings.deviceInfo.gpuFamily)
                            .font(.caption.bold())
                            .lineLimit(1)
                    }
                }
            }
            .padding(.vertical, 4)

            Toggle("Auto-Optimize for Hardware", isOn: $settings.autoOptimize)
                .tint(.cyan)

        } header: {
            Label("Hardware Detection", systemImage: "cpu")
        } footer: {
            Text("Auto-optimization adjusts settings based on your device capabilities, battery level, and thermal state.")
                .font(.caption)
        }
    }

    // MARK: - Quality Presets Section

    private var qualityPresetsSection: some View {
        Section {
            VStack(spacing: 12) {
                // Quick preset buttons
                HStack(spacing: 12) {
                    ForEach(QualityPreset.allCases, id: \.self) { preset in
                        Button {
                            settings.videoQualityPreset = preset
                            settings.audioQualityPreset = preset
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: presetIcon(preset))
                                    .font(.title2)
                                Text(preset.rawValue)
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(settings.videoQualityPreset == preset ? Color.cyan.opacity(0.2) : Color.secondary.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(settings.videoQualityPreset == preset ? Color.cyan : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(settings.videoQualityPreset.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

        } header: {
            Label("Quality Presets", systemImage: "sparkles")
        }
    }

    // MARK: - Video Section

    private var videoSection: some View {
        Section {
            // Format picker
            Picker("Video Format", selection: $settings.videoFormat) {
                ForEach(settings.availableFormats, id: \.self) { format in
                    HStack {
                        Text(format.displayName)
                        Spacer()
                        if !settings.deviceInfo.supportsProRes && format.rawValue.contains("ProRes") {
                            Text("Not Supported")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    .tag(format)
                }
            }
            .pickerStyle(.menu)

            // Resolution picker
            Picker("Resolution", selection: $settings.videoResolution) {
                ForEach(settings.availableResolutions, id: \.self) { resolution in
                    Text(resolution.displayName).tag(resolution)
                }
            }
            .pickerStyle(.menu)

            // Frame rate
            VStack(alignment: .leading, spacing: 4) {
                Text("Frame Rate: \(String(format: "%.2f", settings.videoFrameRate)) fps")
                    .font(.subheadline)

                HStack(spacing: 16) {
                    Button("23.976") {
                        settings.videoFrameRate = 23.976
                    }
                    .buttonStyle(.bordered)
                    .tint(settings.videoFrameRate == 23.976 ? .cyan : .gray)

                    Button("24") {
                        settings.videoFrameRate = 24.0
                    }
                    .buttonStyle(.bordered)
                    .tint(settings.videoFrameRate == 24.0 ? .cyan : .gray)

                    Button("25") {
                        settings.videoFrameRate = 25.0
                    }
                    .buttonStyle(.bordered)
                    .tint(settings.videoFrameRate == 25.0 ? .cyan : .gray)

                    Button("30") {
                        settings.videoFrameRate = 30.0
                    }
                    .buttonStyle(.bordered)
                    .tint(settings.videoFrameRate == 30.0 ? .cyan : .gray)

                    Button("60") {
                        settings.videoFrameRate = 60.0
                    }
                    .buttonStyle(.bordered)
                    .tint(settings.videoFrameRate == 60.0 ? .cyan : .gray)
                }
            }

            // Bitrate (for compressed formats)
            if settings.videoFormat != .proRes422 &&
               settings.videoFormat != .proRes422HQ &&
               settings.videoFormat != .proRes4444 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Video Bitrate: \(settings.formatBitrate(settings.videoBitrate))")
                        .font(.subheadline)

                    Slider(value: Binding(
                        get: { Double(settings.videoBitrate) },
                        set: { settings.videoBitrate = Int($0) }
                    ), in: 5_000_000...200_000_000, step: 5_000_000)
                }
            }

        } header: {
            Label("Video Format", systemImage: "video.fill")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if settings.videoFormat.rawValue.contains("ProRes") {
                    Text("**ProRes**: Professional codec for editing and mastering")
                } else if settings.videoFormat == .h265 {
                    Text("**H.265 (HEVC)**: 50% smaller than H.264, same quality")
                } else if settings.videoFormat == .h264 {
                    Text("**H.264 (AVC)**: Universal compatibility, all devices")
                } else if settings.videoFormat == .av1 {
                    Text("**AV1**: Next-gen codec, 30% smaller than HEVC")
                }
            }
            .font(.caption)
        }
    }

    // MARK: - Audio Section

    private var audioSection: some View {
        Section {
            // Format picker
            Picker("Audio Format", selection: $settings.audioFormat) {
                ForEach(AudioFormat.allCases, id: \.self) { format in
                    HStack {
                        Text(format.displayName)
                        Spacer()
                        if format.isCompressed {
                            Text(format == .aac || format == .opus || format == .mp3 ? "Lossy" : "Lossless")
                                .font(.caption)
                                .foregroundColor(format == .aac || format == .opus || format == .mp3 ? .orange : .green)
                        }
                    }
                    .tag(format)
                }
            }
            .pickerStyle(.menu)

            // Sample rate
            Picker("Sample Rate", selection: $settings.audioSampleRate) {
                ForEach(AudioSampleRate.allCases, id: \.self) { rate in
                    Text(rate.rawValue).tag(rate)
                }
            }
            .pickerStyle(.menu)

            // Bit depth (for uncompressed formats)
            if !settings.audioFormat.isCompressed || settings.audioFormat == .flac || settings.audioFormat == .alac {
                Picker("Bit Depth", selection: $settings.audioBitDepth) {
                    ForEach(AudioBitDepth.allCases, id: \.self) { depth in
                        Text(depth.rawValue).tag(depth)
                    }
                }
                .pickerStyle(.menu)
            }

            // Channels
            Picker("Channels", selection: $settings.audioChannels) {
                ForEach(AudioChannels.allCases, id: \.self) { channels in
                    Text(channels.rawValue).tag(channels)
                }
            }
            .pickerStyle(.menu)

            // Bitrate (for compressed formats)
            if settings.audioFormat == .aac || settings.audioFormat == .opus || settings.audioFormat == .mp3 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Audio Bitrate: \(settings.audioBitrate / 1000) kbps")
                        .font(.subheadline)

                    HStack(spacing: 12) {
                        Button("128") {
                            settings.audioBitrate = 128_000
                        }
                        .buttonStyle(.bordered)
                        .tint(settings.audioBitrate == 128_000 ? .cyan : .gray)

                        Button("192") {
                            settings.audioBitrate = 192_000
                        }
                        .buttonStyle(.bordered)
                        .tint(settings.audioBitrate == 192_000 ? .cyan : .gray)

                        Button("256") {
                            settings.audioBitrate = 256_000
                        }
                        .buttonStyle(.bordered)
                        .tint(settings.audioBitrate == 256_000 ? .cyan : .gray)

                        Button("320") {
                            settings.audioBitrate = 320_000
                        }
                        .buttonStyle(.bordered)
                        .tint(settings.audioBitrate == 320_000 ? .cyan : .gray)
                    }
                }
            }

        } header: {
            Label("Audio Format", systemImage: "waveform")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if settings.audioFormat == .wav {
                    Text("**WAV (PCM)**: Uncompressed, master quality - Large file size")
                } else if settings.audioFormat == .alac {
                    Text("**ALAC**: Apple Lossless - Perfect quality, 40-60% smaller than WAV")
                } else if settings.audioFormat == .flac {
                    Text("**FLAC**: Lossless compression - Perfect quality, 40-60% smaller")
                } else if settings.audioFormat == .aac {
                    Text("**AAC**: High quality lossy - 128 kbps transparent for most content")
                } else if settings.audioFormat == .opus {
                    Text("**Opus**: Best quality/size ratio - Superior to AAC and MP3")
                } else if settings.audioFormat == .mp3 {
                    Text("**MP3**: Universal compatibility - Works on all devices")
                }
            }
            .font(.caption)
        }
    }

    // MARK: - Performance Section

    private var performanceSection: some View {
        Section {
            Picker("Performance Mode", selection: $settings.performanceMode) {
                ForEach(PerformanceMode.allCases, id: \.self) { mode in
                    Label {
                        VStack(alignment: .leading) {
                            Text(mode.rawValue)
                            Text(mode.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: performanceModeIcon(mode))
                    }
                    .tag(mode)
                }
            }
            .pickerStyle(.menu)

            // Battery/thermal info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: batteryIcon)
                        .foregroundColor(batteryColor)
                    Text("Battery: \(Int(UIDevice.current.batteryLevel * 100))%")
                        .font(.caption)
                    Spacer()
                    Text(batteryStateText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                #if os(iOS)
                HStack {
                    Image(systemName: thermalIcon)
                        .foregroundColor(thermalColor)
                    Text("Thermal State:")
                        .font(.caption)
                    Spacer()
                    Text(thermalStateText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                #endif
            }

        } header: {
            Label("Performance & Power", systemImage: "bolt.fill")
        } footer: {
            Text("Efficiency mode reduces quality on battery. Performance mode maximizes quality regardless of power state.")
                .font(.caption)
        }
    }

    // MARK: - File Size Section

    private var fileSizeSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                // Duration slider
                VStack(alignment: .leading, spacing: 4) {
                    Text("Estimated Duration: \(formatDuration(estimatedDurationMinutes))")
                        .font(.subheadline)

                    Slider(value: $estimatedDurationMinutes, in: 0.5...60, step: 0.5)
                        .onChange(of: estimatedDurationMinutes) { newValue in
                            settings.estimatedDuration = newValue * 60  // Convert to seconds
                            settings.updateFileSizeEstimate()
                        }
                }

                Divider()

                // File size estimate
                HStack {
                    VStack(alignment: .leading) {
                        Text("Estimated File Size")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(settings.formatFileSize(settings.estimatedFileSize))
                            .font(.title2.bold())
                            .foregroundColor(.cyan)
                    }

                    Spacer()

                    Image(systemName: fileSizeIcon)
                        .font(.largeTitle)
                        .foregroundColor(fileSizeColor)
                }

                // Per-minute estimate
                let sizePerMinute = settings.estimatedFileSize / Int64(max(1, estimatedDurationMinutes))
                Text("≈ \(settings.formatFileSize(sizePerMinute)) per minute")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)

        } header: {
            Label("File Size Estimation", systemImage: "doc.fill")
        } footer: {
            Text("Estimates based on current video and audio settings. Actual size may vary by ±10%.")
                .font(.caption)
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        Section {
            Button {
                showingResetAlert = true
            } label: {
                Label("Auto-Optimize for This Device", systemImage: "wand.and.stars")
            }
            .foregroundColor(.cyan)

            Button(role: .destructive) {
                settings.optimizeForHardware()
            } label: {
                Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
            }

        } header: {
            Text("Actions")
        }
    }

    // MARK: - Helper Functions

    private var hardwareIcon: String {
        switch settings.hardwareProfile {
        case .professional: return "laptopcomputer.and.iphone"
        case .highEnd: return "iphone.gen3"
        case .midRange: return "iphone.gen2"
        case .lowEnd: return "iphone.gen1"
        case .unknown: return "questionmark.circle"
        }
    }

    private var hardwareColor: Color {
        switch settings.hardwareProfile {
        case .professional: return .purple
        case .highEnd: return .cyan
        case .midRange: return .blue
        case .lowEnd: return .orange
        case .unknown: return .gray
        }
    }

    private func presetIcon(_ preset: QualityPreset) -> String {
        switch preset {
        case .draft: return "pencil.line"
        case .good: return "checkmark"
        case .best: return "star"
        case .master: return "crown"
        }
    }

    private func performanceModeIcon(_ mode: PerformanceMode) -> String {
        switch mode {
        case .efficiency: return "leaf.fill"
        case .balanced: return "scale.3d"
        case .performance: return "flame.fill"
        }
    }

    private var batteryIcon: String {
        let level = UIDevice.current.batteryLevel
        if UIDevice.current.batteryState == .charging {
            return "battery.100.bolt"
        } else if level > 0.75 {
            return "battery.100"
        } else if level > 0.5 {
            return "battery.75"
        } else if level > 0.25 {
            return "battery.50"
        } else {
            return "battery.25"
        }
    }

    private var batteryColor: Color {
        let level = UIDevice.current.batteryLevel
        if UIDevice.current.batteryState == .charging {
            return .green
        } else if level > 0.5 {
            return .green
        } else if level > 0.2 {
            return .orange
        } else {
            return .red
        }
    }

    private var batteryStateText: String {
        switch UIDevice.current.batteryState {
        case .charging: return "Charging"
        case .full: return "Full"
        case .unplugged: return "On Battery"
        default: return "Unknown"
        }
    }

    #if os(iOS)
    private var thermalIcon: String {
        let state = ProcessInfo.processInfo.thermalState
        switch state {
        case .nominal: return "thermometer.low"
        case .fair: return "thermometer.medium"
        case .serious: return "thermometer.high"
        case .critical: return "thermometer.high"
        @unknown default: return "thermometer"
        }
    }

    private var thermalColor: Color {
        let state = ProcessInfo.processInfo.thermalState
        switch state {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        @unknown default: return .gray
        }
    }

    private var thermalStateText: String {
        let state = ProcessInfo.processInfo.thermalState
        switch state {
        case .nominal: return "Normal"
        case .fair: return "Warm"
        case .serious: return "Hot"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
    #endif

    private var fileSizeIcon: String {
        let gb = Double(settings.estimatedFileSize) / 1_073_741_824.0
        if gb > 10 {
            return "externaldrive.fill"
        } else if gb > 1 {
            return "internaldrive.fill"
        } else {
            return "doc.fill"
        }
    }

    private var fileSizeColor: Color {
        let gb = Double(settings.estimatedFileSize) / 1_073_741_824.0
        if gb > 10 {
            return .red
        } else if gb > 5 {
            return .orange
        } else if gb > 1 {
            return .yellow
        } else {
            return .green
        }
    }

    private func formatDuration(_ minutes: Double) -> String {
        if minutes < 1 {
            return String(format: "%.0f seconds", minutes * 60)
        } else if minutes < 60 {
            return String(format: "%.1f minutes", minutes)
        } else {
            let hours = Int(minutes / 60)
            let mins = Int(minutes.truncatingRemainder(dividingBy: 60))
            return "\(hours)h \(mins)m"
        }
    }
}

#Preview {
    QualityFormatSettingsView()
}
