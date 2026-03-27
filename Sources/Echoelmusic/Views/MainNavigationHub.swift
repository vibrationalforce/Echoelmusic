#if canImport(SwiftUI)
import SwiftUI

/// Main navigation — one-screen touch synth instrument.
struct MainNavigationHub: View {

    @Environment(AudioEngine.self) var audioEngine
    @Environment(ThemeManager.self) var themeManager

    var body: some View {
        EchoelInstrumentView()
            .environment(audioEngine)
    }
}

// MARK: - Settings View (accessible via future gesture/menu)

struct EchoelSettingsView: View {
    @Environment(ThemeManager.self) var themeManager
    @Environment(AudioEngine.self) var audioEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                EchoelBrand.bgDeep.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: EchoelSpacing.lg) {
                        settingsSection(title: "APPEARANCE") {
                            ThemeModePicker(themeManager: themeManager)
                                .padding(.horizontal, EchoelSpacing.md)
                        }
                        settingsSection(title: "AUDIO") {
                            VStack(spacing: EchoelSpacing.sm) {
                                settingsRow(icon: "speaker.wave.2", label: "Master Volume", value: "\(Int(audioEngine.masterVolume * 100))%")
                                Slider(value: Binding(get: { Double(audioEngine.masterVolume) }, set: { audioEngine.masterVolume = Float($0) }), in: 0...1)
                                    .tint(EchoelBrand.primary)
                                    .padding(.horizontal, EchoelSpacing.md)
                                settingsRow(icon: "waveform", label: "Audio Engine", value: audioEngine.isRunning ? "Running" : "Stopped")
                                settingsRow(icon: "mic", label: "Input Monitoring", value: audioEngine.inputMonitoringEnabled ? "On" : "Off")
                            }
                        }
                        settingsSection(title: "SAFETY") {
                            VStack(alignment: .leading, spacing: EchoelSpacing.sm) {
                                safetyWarning("NOT while operating vehicles")
                                safetyWarning("NOT under influence of alcohol/drugs")
                                safetyWarning("Max 3 Hz visual flash rate (WCAG)")
                                safetyWarning("Coordinate therapeutic use with your provider")
                            }
                            .padding(.horizontal, EchoelSpacing.md)
                        }
                        settingsSection(title: "TUNING") {
                            VStack(spacing: EchoelSpacing.sm) {
                                settingsRow(icon: "tuningfork", label: "Concert Pitch (A4)", value: String(format: "%.1f Hz", TuningManager.shared.concertPitch))
                                KammertonWheelView().padding(.horizontal, EchoelSpacing.sm)
                            }
                        }
                        settingsSection(title: "ABOUT") {
                            VStack(spacing: EchoelSpacing.sm) {
                                settingsRow(icon: "info.circle", label: "Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "7.0")
                                settingsRow(icon: "hammer", label: "Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "dev")
                                settingsRow(icon: "person", label: "Developer", value: "Echoel")
                                settingsRow(icon: "building.2", label: "Studio", value: "Hamburg")
                                Text("Create from Within")
                                    .font(EchoelBrandFont.caption())
                                    .foregroundColor(EchoelBrand.textSecondary)
                                    .italic()
                                    .padding(.top, EchoelSpacing.xs)
                            }
                        }
                    }
                    .padding(.vertical, EchoelSpacing.lg)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(EchoelBrand.primary)
                }
            }
        }
    }

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: EchoelSpacing.sm) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(EchoelBrand.textSecondary)
                .tracking(2)
                .padding(.horizontal, EchoelSpacing.lg)
            VStack(spacing: EchoelSpacing.xs) { content() }
                .padding(.vertical, EchoelSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: EchoelRadius.md)
                        .fill(EchoelBrand.bgSurface)
                        .overlay(RoundedRectangle(cornerRadius: EchoelRadius.md).stroke(EchoelBrand.border, lineWidth: 0.5))
                )
                .padding(.horizontal, EchoelSpacing.md)
        }
    }

    private func settingsRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon).font(.system(size: 14)).foregroundColor(EchoelBrand.primary).frame(width: 24)
            Text(label).font(EchoelBrandFont.body()).foregroundColor(EchoelBrand.textPrimary)
            Spacer()
            Text(value).font(EchoelBrandFont.dataSmall()).foregroundColor(EchoelBrand.textSecondary)
        }
        .padding(.horizontal, EchoelSpacing.md)
    }

    private func safetyWarning(_ text: String) -> some View {
        HStack(alignment: .top, spacing: EchoelSpacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 10)).foregroundColor(EchoelBrand.amber).padding(.top, 2)
            Text(text).font(EchoelBrandFont.caption()).foregroundColor(EchoelBrand.textSecondary)
        }
    }
}

#endif
