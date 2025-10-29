import SwiftUI

/// Preset selection view for bio-mapping configurations
struct PresetSelectionView: View {
    @Binding var selectedPreset: BioMappingPreset
    @State private var showPreview = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Bio-Mapping Preset")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)

            // Current preset display
            currentPresetCard

            // Preset grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(BioMappingPreset.allCases, id: \.self) { preset in
                        presetButton(for: preset)
                    }
                }
                .padding(.horizontal)
            }

            // Preview toggle
            Toggle("Show Live Preview", isOn: $showPreview)
                .padding(.horizontal)
                .tint(.cyan)

            if showPreview {
                previewSection
            }
        }
        .padding(.vertical, 20)
        .background(Color.black.opacity(0.3))
    }

    // MARK: - Current Preset Card

    private var currentPresetCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: selectedPreset.iconName)
                    .font(.system(size: 32))
                    .foregroundColor(.cyan)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(Color.cyan.opacity(0.2))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedPreset.rawValue)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    Text(selectedPreset.description)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.cyan.opacity(0.15))
            )
        }
        .padding(.horizontal)
    }

    // MARK: - Preset Button

    private func presetButton(for preset: BioMappingPreset) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedPreset = preset
            }
        }) {
            VStack(spacing: 8) {
                Image(systemName: preset.iconName)
                    .font(.system(size: 28))
                    .foregroundColor(selectedPreset == preset ? .cyan : .white.opacity(0.7))
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(selectedPreset == preset ? Color.cyan.opacity(0.3) : Color.white.opacity(0.1))
                    )

                Text(preset.rawValue)
                    .font(.system(size: 13, weight: selectedPreset == preset ? .semibold : .regular))
                    .foregroundColor(selectedPreset == preset ? .cyan : .white.opacity(0.8))
                    .lineLimit(1)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedPreset == preset ? Color.cyan.opacity(0.15) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedPreset == preset ? Color.cyan : Color.clear, lineWidth: 2)
            )
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Parameter Preview")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))

            let config = selectedPreset.mapping()

            parameterRow(
                label: "Filter Cutoff",
                range: "\(Int(config.filterCutoffRange.lowerBound)) - \(Int(config.filterCutoffRange.upperBound)) Hz"
            )

            parameterRow(
                label: "Reverb",
                range: "\(Int(config.reverbWetRange.lowerBound * 100)) - \(Int(config.reverbWetRange.upperBound * 100))%"
            )

            parameterRow(
                label: "Tempo",
                range: "\(Int(config.tempoRange.lowerBound)) - \(Int(config.tempoRange.upperBound)) BPM"
            )

            parameterRow(
                label: "LED Brightness",
                range: "\(Int(config.ledBrightness * 100))%"
            )

            parameterRow(
                label: "Motion Intensity",
                range: "\(Int(config.motionIntensity * 100))%"
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
        .padding(.horizontal)
    }

    private func parameterRow(label: String, range: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))

            Spacer()

            Text(range)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.cyan)
        }
    }
}

// MARK: - Preview

struct PresetSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        PresetSelectionView(selectedPreset: .constant(.creative))
            .preferredColorScheme(.dark)
    }
}
