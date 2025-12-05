import SwiftUI

/// Beautiful preset selection view for bio-mapping presets
/// Features animated cards, live parameter preview, and smooth transitions
struct PresetSelectionView: View {

    @ObservedObject var presetManager: BioPresetManager
    @State private var showingDetail = false
    @State private var selectedForDetail: BioMappingPreset?
    @Namespace private var animation

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Preset Grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(BioMappingPreset.allCases) { preset in
                        PresetCard(
                            preset: preset,
                            isSelected: presetManager.currentPreset == preset,
                            namespace: animation
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                presetManager.currentPreset = preset
                            }
                        }
                        .onLongPressGesture {
                            selectedForDetail = preset
                            showingDetail = true
                        }
                    }
                }
                .padding()
            }

            // Current Preset Info Bar
            currentPresetBar
        }
        .background(Color.black.opacity(0.95))
        .sheet(item: $selectedForDetail) { preset in
            PresetDetailView(preset: preset, presetManager: presetManager)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Bio-Mapping")
                    .font(.title2.bold())
                    .foregroundColor(.white)

                Text("Select your state")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()

            // Quick cycle buttons
            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring()) {
                        presetManager.previousPreset()
                    }
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title2)
                        .foregroundStyle(presetManager.currentPreset.color)
                }

                Button {
                    withAnimation(.spring()) {
                        presetManager.nextPreset()
                    }
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(presetManager.currentPreset.color)
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [
                    presetManager.currentPreset.color.opacity(0.3),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Current Preset Bar

    private var currentPresetBar: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: presetManager.currentPreset.icon)
                .font(.title)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            presetManager.currentPreset.color,
                            presetManager.currentPreset.gradientColor
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: presetManager.currentPreset.color.opacity(0.5), radius: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(presetManager.currentPreset.rawValue)
                    .font(.headline)
                    .foregroundColor(.white)

                Text("Active")
                    .font(.caption)
                    .foregroundColor(.green)
            }

            Spacer()

            // Live parameter preview
            LiveParameterPreview(config: presetManager.activeConfiguration)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(presetManager.currentPreset.color.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}


// MARK: - Preset Card

struct PresetCard: View {

    let preset: BioMappingPreset
    let isSelected: Bool
    var namespace: Namespace.ID

    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: preset.icon)
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [preset.color, preset.gradientColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            // Title
            Text(preset.rawValue)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)

            // Description preview
            Text(preset.description)
                .font(.caption)
                .foregroundColor(.gray)
                .lineLimit(2)

            // Parameter indicators
            HStack(spacing: 8) {
                ParameterIndicator(
                    label: "Rev",
                    value: Double(preset.mapping.hrvToReverbRange.max),
                    color: .blue
                )

                ParameterIndicator(
                    label: "Flt",
                    value: Double(preset.mapping.hrToFilterRange.max) / 8000,
                    color: .orange
                )

                ParameterIndicator(
                    label: "Spd",
                    value: Double(1.0 - preset.mapping.parameterSmoothingFactor),
                    color: .green
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    isSelected
                        ? preset.color.opacity(0.2)
                        : Color.white.opacity(0.05)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isSelected
                                ? preset.color.opacity(0.8)
                                : Color.white.opacity(0.1),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
        )
        .shadow(
            color: isSelected ? preset.color.opacity(0.3) : .clear,
            radius: isSelected ? 12 : 0
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3), value: isPressed)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}


// MARK: - Parameter Indicator

struct ParameterIndicator: View {

    let label: String
    let value: Double // 0-1
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.gray)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    Capsule()
                        .fill(Color.white.opacity(0.1))

                    // Fill
                    Capsule()
                        .fill(color.opacity(0.8))
                        .frame(width: geo.size.width * CGFloat(value))
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
    }
}


// MARK: - Live Parameter Preview

struct LiveParameterPreview: View {

    let config: BioMappingConfiguration

    var body: some View {
        HStack(spacing: 12) {
            parameterDot(
                value: Double(config.hrvToReverbRange.max),
                label: "REV",
                color: .cyan
            )

            parameterDot(
                value: Double(config.hrToFilterRange.max) / 8000,
                label: "FLT",
                color: .orange
            )

            parameterDot(
                value: Double(config.coherenceToAmplitudeRange.max),
                label: "AMP",
                color: .green
            )
        }
    }

    private func parameterDot(value: Double, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .fill(color)
                        .scaleEffect(CGFloat(value))
                )

            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.gray)
        }
    }
}


// MARK: - Preset Detail View

struct PresetDetailView: View {

    let preset: BioMappingPreset
    @ObservedObject var presetManager: BioPresetManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header with icon
                    HStack {
                        Image(systemName: preset.icon)
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [preset.color, preset.gradientColor],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: preset.color.opacity(0.5), radius: 16)

                        Spacer()
                    }
                    .padding(.top)

                    // Description
                    Text(preset.description)
                        .font(.body)
                        .foregroundColor(.secondary)

                    // Use cases
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Best For")
                            .font(.headline)

                        FlowLayout(spacing: 8) {
                            ForEach(preset.useCases, id: \.self) { useCase in
                                Text(useCase)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(preset.color.opacity(0.2))
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(preset.color.opacity(0.5), lineWidth: 1)
                                    )
                            }
                        }
                    }

                    // Technical parameters
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Parameters")
                            .font(.headline)

                        ParameterRow(
                            label: "Base Frequency",
                            value: "\(Int(preset.mapping.baseFrequency)) Hz",
                            description: "Solfeggio healing frequency"
                        )

                        ParameterRow(
                            label: "Reverb Range",
                            value: "\(Int(preset.mapping.hrvToReverbRange.min * 100))% - \(Int(preset.mapping.hrvToReverbRange.max * 100))%",
                            description: "HRV → spatial depth"
                        )

                        ParameterRow(
                            label: "Filter Range",
                            value: "\(Int(preset.mapping.hrToFilterRange.min)) - \(Int(preset.mapping.hrToFilterRange.max)) Hz",
                            description: "Heart rate → brightness"
                        )

                        ParameterRow(
                            label: "Response Speed",
                            value: responseSpeedLabel,
                            description: "How quickly sound responds to changes"
                        )

                        ParameterRow(
                            label: "Spatial Movement",
                            value: "\(Int(preset.mapping.spatialMovementIntensity * 100))%",
                            description: "3D audio motion intensity"
                        )

                        ParameterRow(
                            label: "Harmonic Richness",
                            value: String(format: "%.1fx", preset.mapping.harmonicEnrichmentFactor),
                            description: "Overtone complexity"
                        )
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle(preset.rawValue)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation(.spring()) {
                            presetManager.currentPreset = preset
                        }
                        dismiss()
                    } label: {
                        Text(presetManager.currentPreset == preset ? "Active" : "Select")
                            .font(.headline)
                            .foregroundColor(presetManager.currentPreset == preset ? .green : preset.color)
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var responseSpeedLabel: String {
        let smoothing = preset.mapping.parameterSmoothingFactor
        if smoothing < 0.6 { return "Fast" }
        if smoothing < 0.8 { return "Medium" }
        if smoothing < 0.9 { return "Slow" }
        return "Very Slow"
    }
}


// MARK: - Parameter Row

struct ParameterRow: View {

    let label: String
    let value: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text(value)
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.primary)
            }

            Text(description)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
}


// MARK: - Flow Layout

struct FlowLayout: Layout {

    let spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )

        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(
                x: bounds.minX + result.positions[index].x,
                y: bounds.minY + result.positions[index].y
            ), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth, currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
                self.size.width = max(self.size.width, currentX)
            }

            self.size.height = currentY + lineHeight
        }
    }
}


// MARK: - Compact Preset Picker (for embedding in other views)

struct CompactPresetPicker: View {

    @ObservedObject var presetManager: BioPresetManager

    var body: some View {
        Menu {
            ForEach(BioMappingPreset.allCases) { preset in
                Button {
                    withAnimation(.spring()) {
                        presetManager.currentPreset = preset
                    }
                } label: {
                    Label(preset.rawValue, systemImage: preset.icon)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: presetManager.currentPreset.icon)
                    .foregroundStyle(presetManager.currentPreset.color)

                Text(presetManager.currentPreset.rawValue)
                    .font(.subheadline)

                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.1))
            )
        }
    }
}


// MARK: - Preview

#Preview {
    PresetSelectionView(presetManager: BioPresetManager())
        .preferredColorScheme(.dark)
}

#Preview("Compact Picker") {
    CompactPresetPicker(presetManager: BioPresetManager())
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
}
