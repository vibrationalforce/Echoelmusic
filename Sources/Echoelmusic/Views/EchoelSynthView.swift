import SwiftUI

// MARK: - EchoelSynth View
// Connects: TouchInstruments, SynthPresetLibrary, EchoelBass, EchoelBeat

struct EchoelSynthView: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @StateObject private var touchHub = TouchInstrumentsHub()
    @State private var activePanel: SynthPanel = .keyboard

    enum SynthPanel: String, CaseIterable {
        case keyboard = "Keys"
        case drums = "Drums"
        case bass = "Bass"
        case presets = "Presets"

        var icon: String {
            switch self {
            case .keyboard: return "pianokeys"
            case .drums: return "square.grid.3x3.fill"
            case .bass: return "waveform"
            case .presets: return "list.bullet"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Panel selector
            panelSelector

            // Active panel content
            panelContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(VaporwaveGradients.background.ignoresSafeArea())
    }

    // MARK: - Panel Selector

    private var panelSelector: some View {
        HStack(spacing: 0) {
            ForEach(SynthPanel.allCases, id: \.self) { panel in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        activePanel = panel
                    }
                    HapticHelper.impact(.light)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: panel.icon)
                            .font(.system(size: 18))
                        Text(panel.rawValue)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(activePanel == panel ? VaporwaveColors.neonCyan : VaporwaveColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        activePanel == panel
                            ? VaporwaveColors.neonCyan.opacity(0.1)
                            : Color.clear
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .background(VaporwaveColors.deepBlack.opacity(0.8))
    }

    // MARK: - Panel Content

    @ViewBuilder
    private var panelContent: some View {
        switch activePanel {
        case .keyboard:
            TouchKeyboardView(hub: touchHub)
        case .drums:
            DrumPadView(hub: touchHub)
        case .bass:
            EchoelBassView()
        case .presets:
            synthPresetBrowser
        }
    }

    // MARK: - Preset Browser

    private var synthPresetBrowser: some View {
        let library = SynthPresetLibrary.shared

        return ScrollView {
            VStack(alignment: .leading, spacing: VaporwaveSpacing.md) {
                ForEach(PresetCategory.allCases, id: \.self) { category in
                    VStack(alignment: .leading, spacing: VaporwaveSpacing.sm) {
                        Text(category.rawValue.replacingOccurrences(of: "ECHOEL_", with: ""))
                            .font(VaporwaveTypography.label())
                            .foregroundColor(VaporwaveColors.neonCyan)
                            .tracking(2)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: VaporwaveSpacing.sm) {
                            ForEach(library.presets(for: category)) { preset in
                                presetCard(preset)
                            }
                        }
                    }
                    .padding(.horizontal, VaporwaveSpacing.md)
                }
            }
            .padding(.vertical, VaporwaveSpacing.md)
        }
    }

    private func presetCard(_ preset: SynthPreset) -> some View {
        Button {
            // Render and preview preset
            let library = SynthPresetLibrary.shared
            if let buffer = library.renderPresetToBuffer(preset) {
                audioEngine.schedulePlayback(buffer: buffer)
            }
            HapticHelper.impact(.medium)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(preset.name)
                    .font(VaporwaveTypography.body())
                    .foregroundColor(VaporwaveColors.textPrimary)
                    .lineLimit(1)

                Text(preset.engine.rawValue)
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textTertiary)

                // Mini waveform indicator
                HStack(spacing: 2) {
                    ForEach(preset.tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 9))
                            .foregroundColor(VaporwaveColors.neonPurple)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                Capsule().fill(VaporwaveColors.neonPurple.opacity(0.15))
                            )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(VaporwaveSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(VaporwaveColors.deepBlack.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(VaporwaveColors.neonPurple.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
