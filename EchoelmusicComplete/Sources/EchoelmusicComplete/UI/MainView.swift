// MainView.swift
// Complete main user interface

import SwiftUI

// MARK: - Main View

public struct MainView: View {
    @EnvironmentObject var appState: AppState

    @State private var showSettings = false
    @State private var showPresets = false
    @State private var showDisclaimer = false
    @State private var hasAcceptedDisclaimer = false

    public init() {}

    public var body: some View {
        ZStack {
            // Dynamic background
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView
                    .padding(.top, 50)

                Spacer()

                // Main visualization
                VisualizationView(
                    type: appState.visualizationType,
                    bioData: appState.bioData,
                    isActive: appState.isSessionActive
                )
                .frame(height: 320)
                .padding(.horizontal, 20)

                Spacer()

                // Bio metrics
                if appState.isSessionActive {
                    bioMetricsView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 10)
                }

                // Visualization picker
                visualizationPicker
                    .padding(.vertical, 10)

                // Audio mode picker
                audioModePicker
                    .padding(.bottom, 10)

                // Control button
                controlButton
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            if !hasAcceptedDisclaimer {
                showDisclaimer = true
            }
        }
        .sheet(isPresented: $showDisclaimer) {
            DisclaimerView(
                isPresented: $showDisclaimer,
                onAccept: {
                    hasAcceptedDisclaimer = true
                    Task {
                        _ = await appState.biofeedbackManager.requestAuthorization()
                    }
                }
            )
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showPresets) {
            PresetPickerView(isPresented: $showPresets)
                .environmentObject(appState)
        }
        .animation(.easeInOut(duration: 0.5), value: appState.isSessionActive)
        .animation(.easeInOut(duration: 1.0), value: appState.bioData.coherence)
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                coherenceColor.opacity(0.3),
                Color.black
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var coherenceColor: Color {
        switch appState.bioData.coherenceLevel {
        case .low: return .purple
        case .medium: return .blue
        case .high: return .green
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Button(action: { showPresets = true }) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 22))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            VStack(spacing: 4) {
                Text("Echoelmusic")
                    .font(.system(size: 26, weight: .light, design: .rounded))
                    .foregroundColor(.white)

                if appState.isSessionActive {
                    Text(appState.formattedDuration)
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            Spacer()

            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 22))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 25)
    }

    // MARK: - Bio Metrics

    private var bioMetricsView: some View {
        HStack(spacing: 25) {
            MetricBadge(
                icon: "heart.fill",
                value: String(format: "%.0f", appState.bioData.heartRate),
                unit: "BPM",
                color: .red
            )

            MetricBadge(
                icon: "waveform.path.ecg",
                value: String(format: "%.0f", appState.bioData.hrvMs),
                unit: "ms HRV",
                color: .orange
            )

            MetricBadge(
                icon: "sparkles",
                value: String(format: "%.0f", appState.bioData.coherence),
                unit: "%",
                color: coherenceColor
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.1))
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Visualization Picker

    private var visualizationPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(VisualizationType.allCases) { type in
                    Button(action: { appState.visualizationType = type }) {
                        VStack(spacing: 5) {
                            Image(systemName: type.icon)
                                .font(.system(size: 20))
                            Text(type.rawValue)
                                .font(.caption2)
                        }
                        .foregroundColor(appState.visualizationType == type ? .white : .gray)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(appState.visualizationType == type ?
                                      coherenceColor.opacity(0.6) : Color.white.opacity(0.1))
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Audio Mode Picker

    private var audioModePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(AudioMode.allCases) { mode in
                    Button(action: { appState.audioMode = mode }) {
                        HStack(spacing: 6) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 16))
                            Text(mode.rawValue)
                                .font(.caption)
                        }
                        .foregroundColor(appState.audioMode == mode ? .white : .gray)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(appState.audioMode == mode ?
                                      Color.blue.opacity(0.6) : Color.white.opacity(0.1))
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Control Button

    private var controlButton: some View {
        Button(action: toggleSession) {
            HStack(spacing: 12) {
                Image(systemName: appState.isSessionActive ? "stop.fill" : "play.fill")
                    .font(.system(size: 20))

                Text(appState.isSessionActive ? "End Session" : "Begin Session")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 45)
            .padding(.vertical, 18)
            .background(
                Capsule()
                    .fill(
                        appState.isSessionActive
                            ? Color.red.opacity(0.8)
                            : coherenceColor.opacity(0.8)
                    )
            )
            .shadow(color: coherenceColor.opacity(0.4), radius: 15)
        }
        .scaleEffect(appState.isSessionActive ? 1.0 : 1.03)
        .animation(
            appState.isSessionActive
                ? .none
                : .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
            value: appState.isSessionActive
        )
    }

    // MARK: - Actions

    private func toggleSession() {
        if appState.isSessionActive {
            appState.stopSession()
        } else {
            appState.startSession()
        }
    }
}

// MARK: - Metric Badge

struct MetricBadge: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(unit)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(minWidth: 70)
    }
}

// MARK: - Disclaimer View

public struct DisclaimerView: View {
    @Binding var isPresented: Bool
    let onAccept: () -> Void

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)

                    Text("Health Disclaimer")
                        .font(.title)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)

                    Text(HealthDisclaimer.full)
                        .font(.body)
                        .foregroundColor(.secondary)

                    Spacer(minLength: 30)

                    Button(action: {
                        onAccept()
                        isPresented = false
                    }) {
                        Text("I Understand")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.bottom, 30)
                }
                .padding(.horizontal)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
    }
}

// MARK: - Settings View

public struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    public var body: some View {
        NavigationView {
            List {
                Section("Audio") {
                    HStack {
                        Text("Volume")
                        Slider(value: Binding(
                            get: { Double(appState.audioEngine.volume) },
                            set: { appState.audioEngine.setVolume(Float($0)) }
                        ))
                    }

                    Picker("Binaural State", selection: $appState.binauralState) {
                        ForEach(BinauralState.allCases) { state in
                            Text(state.rawValue).tag(state)
                        }
                    }
                }

                Section("Biofeedback") {
                    HStack {
                        Text("Source")
                        Spacer()
                        Text(appState.biofeedbackManager.isSimulating ? "Simulation" : "HealthKit")
                            .foregroundColor(.secondary)
                    }

                    if appState.biofeedbackManager.isSimulating {
                        Text("Connect Apple Watch for real biofeedback")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("\(AppConstants.appName) \(AppConstants.version)")
                            .foregroundColor(.secondary)
                    }

                    Link("Health Disclaimer", destination: URL(string: "about:blank")!)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preset Picker View

public struct PresetPickerView: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool

    public var body: some View {
        NavigationView {
            List {
                ForEach(appState.presetManager.presets) { preset in
                    Button(action: {
                        appState.applyPreset(preset)
                        isPresented = false
                    }) {
                        HStack {
                            Image(systemName: preset.icon)
                                .foregroundColor(Color(hex: preset.colorHex))
                                .frame(width: 30)

                            VStack(alignment: .leading) {
                                Text(preset.name)
                                    .foregroundColor(.primary)
                                Text("\(preset.visualization.rawValue) + \(preset.audioMode.rawValue)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if appState.presetManager.activePreset?.id == preset.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { isPresented = false }
                }
            }
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
