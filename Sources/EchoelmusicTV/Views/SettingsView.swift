import SwiftUI

/// Settings view for Apple TV app
/// Configure visualizations, sessions, and app preferences
struct SettingsView: View {

    @EnvironmentObject var visualizationManager: TVVisualizationManager
    @EnvironmentObject var sessionManager: TVSessionManager

    @AppStorage("defaultSessionDuration") private var defaultSessionDuration: Double = 600 // 10 minutes
    @AppStorage("autoStartAmbient") private var autoStartAmbient: Bool = true
    @AppStorage("showParticipantNames") private var showParticipantNames: Bool = true
    @AppStorage("enableHapticSync") private var enableHapticSync: Bool = true

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [.purple.opacity(0.2), .indigo.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 40) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.purple)

                        Text("Settings")
                            .font(.largeTitle.bold())
                            .foregroundColor(.white)
                    }
                    .padding(.top, 60)

                    // Visualization Settings
                    SettingsSection(title: "Visualization", icon: "waveform.path") {
                        // Style selector
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Style")
                                .font(.headline)
                                .foregroundColor(.white)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 20) {
                                    ForEach(VisualizationStyle.allCases, id: \.self) { style in
                                        StyleButton(
                                            style: style,
                                            isSelected: visualizationManager.currentStyle == style,
                                            action: { visualizationManager.setStyle(style) }
                                        )
                                    }
                                }
                            }
                        }

                        Divider()
                            .background(Color.white.opacity(0.2))

                        // Intensity slider
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Intensity")
                                .font(.headline)
                                .foregroundColor(.white)

                            HStack {
                                Image(systemName: "sun.min")
                                    .foregroundColor(.white.opacity(0.6))

                                Slider(value: $visualizationManager.intensity, in: 0...1)
                                    .tint(.cyan)

                                Image(systemName: "sun.max.fill")
                                    .foregroundColor(.white)

                                Text("\(Int(visualizationManager.intensity * 100))%")
                                    .font(.body.bold())
                                    .foregroundColor(.cyan)
                                    .frame(width: 60, alignment: .trailing)
                            }
                        }

                        Divider()
                            .background(Color.white.opacity(0.2))

                        // Animation speed
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Animation Speed")
                                .font(.headline)
                                .foregroundColor(.white)

                            HStack {
                                Image(systemName: "tortoise")
                                    .foregroundColor(.white.opacity(0.6))

                                Slider(value: $visualizationManager.animationSpeed, in: 0.1...2.0)
                                    .tint(.cyan)

                                Image(systemName: "hare.fill")
                                    .foregroundColor(.white)

                                Text(String(format: "%.1fx", visualizationManager.animationSpeed))
                                    .font(.body.bold())
                                    .foregroundColor(.cyan)
                                    .frame(width: 60, alignment: .trailing)
                            }
                        }
                    }

                    // Session Settings
                    SettingsSection(title: "Sessions", icon: "timer") {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Default Session Duration")
                                .font(.headline)
                                .foregroundColor(.white)

                            HStack(spacing: 30) {
                                ForEach([300.0, 600.0, 900.0, 1200.0, 1800.0], id: \.self) { duration in
                                    Button(action: { defaultSessionDuration = duration }) {
                                        VStack(spacing: 4) {
                                            Text("\(Int(duration / 60))")
                                                .font(.title2.bold())

                                            Text("min")
                                                .font(.caption)
                                        }
                                        .frame(width: 80, height: 80)
                                        .background(
                                            defaultSessionDuration == duration
                                                ? Color.cyan.opacity(0.3)
                                                : Color.black.opacity(0.3)
                                        )
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    defaultSessionDuration == duration ? Color.cyan : Color.clear,
                                                    lineWidth: 2
                                                )
                                        )
                                    }
                                    .buttonStyle(.card)
                                }
                            }
                        }

                        Divider()
                            .background(Color.white.opacity(0.2))

                        Toggle(isOn: $showParticipantNames) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Show Participant Names")
                                    .font(.headline)
                                    .foregroundColor(.white)

                                Text("Display names in group sessions")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tint(.cyan)

                        Toggle(isOn: $enableHapticSync) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Sync with Watch Haptics")
                                    .font(.headline)
                                    .foregroundColor(.white)

                                Text("Coordinate haptic feedback with Apple Watch")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tint(.cyan)
                    }

                    // App Settings
                    SettingsSection(title: "App", icon: "app.badge") {
                        Toggle(isOn: $autoStartAmbient) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Auto-Start Ambient Mode")
                                    .font(.headline)
                                    .foregroundColor(.white)

                                Text("Start ambient visuals on app launch")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tint(.cyan)
                    }

                    // About
                    SettingsSection(title: "About", icon: "info.circle") {
                        HStack {
                            Text("App Version")
                                .font(.body)
                                .foregroundColor(.white)

                            Spacer()

                            Text("1.0.0")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Build")
                                .font(.body)
                                .foregroundColor(.white)

                            Spacer()

                            Text("2025.11.06")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Echoelmusic for Apple TV")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("Immersive biofeedback experiences on the big screen")
                                .font(.caption)
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                    }

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 60)
            }
        }
    }
}

/// Settings section container
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Section header
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.cyan)

                Text(title)
                    .font(.title2.bold())
                    .foregroundColor(.white)
            }

            // Section content
            VStack(alignment: .leading, spacing: 20) {
                content
            }
            .padding(24)
            .background(Color.black.opacity(0.3))
            .cornerRadius(20)
        }
    }
}

/// Style selection button
struct StyleButton: View {
    let style: VisualizationStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: style.icon)
                    .font(.system(size: 40))
                    .foregroundColor(isSelected ? .cyan : .white)

                Text(style.name)
                    .font(.body.bold())
                    .foregroundColor(isSelected ? .cyan : .white)

                Text(style.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(width: 180)
            }
            .padding(20)
            .frame(width: 220, height: 200)
            .background(
                isSelected
                    ? Color.cyan.opacity(0.2)
                    : Color.black.opacity(0.3)
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.cyan : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.card)
    }
}

#Preview {
    SettingsView()
        .environmentObject(TVVisualizationManager())
        .environmentObject(TVSessionManager())
}
