import SwiftUI

// MARK: - EchoelSynth View
// Adaptive layout for iPhone (portrait/landscape) and iPad
// Connects: TouchInstruments, SynthPresetLibrary, EchoelBass, EchoelBeat

struct EchoelSynthView: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @StateObject private var touchHub = TouchInstrumentsHub()
    @State private var activePanel: SynthPanel = .keyboard

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    enum SynthPanel: String, CaseIterable, Identifiable {
        case keyboard = "Keys"
        case drums = "Drums"
        case bass = "Bass"
        case presets = "Presets"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .keyboard: return "pianokeys"
            case .drums: return "square.grid.3x3.fill"
            case .bass: return "waveform"
            case .presets: return "list.bullet"
            }
        }

        var accentColor: Color {
            switch self {
            case .keyboard: return EchoelBrand.sky
            case .drums: return EchoelBrand.coral
            case .bass: return EchoelBrand.violet
            case .presets: return EchoelBrand.emerald
            }
        }
    }

    // MARK: - Layout Classification

    private var isLandscapePhone: Bool {
        horizontalSizeClass == .compact && verticalSizeClass == .compact
    }

    private var isPortraitPhone: Bool {
        horizontalSizeClass == .compact && verticalSizeClass == .regular
    }

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    // MARK: - Body

    var body: some View {
        Group {
            if isLandscapePhone {
                landscapePhoneLayout
            } else if isIPad {
                iPadLayout
            } else {
                portraitPhoneLayout
            }
        }
        .background(EchoelBrand.bgDeep.ignoresSafeArea())
    }

    // MARK: - Portrait iPhone Layout
    // Panel selector on top, instrument below filling remaining space

    private var portraitPhoneLayout: some View {
        VStack(spacing: 0) {
            horizontalPanelSelector(compact: true)
            panelContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Landscape iPhone Layout
    // Thin vertical panel strip on LEFT, instrument on right taking full height

    private var landscapePhoneLayout: some View {
        HStack(spacing: 0) {
            verticalPanelSelector(wide: false)
            panelContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - iPad Layout
    // Wider side panel on left, instrument area filling right

    private var iPadLayout: some View {
        HStack(spacing: 0) {
            verticalPanelSelector(wide: true)
            panelContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Horizontal Panel Selector (Portrait iPhone)

    private func horizontalPanelSelector(compact: Bool) -> some View {
        HStack(spacing: 0) {
            ForEach(SynthPanel.allCases) { panel in
                Button {
                    withAnimation(.easeInOut(duration: EchoelAnimation.quick)) {
                        activePanel = panel
                    }
                    HapticHelper.impact(.light)
                } label: {
                    let isActive = activePanel == panel
                    VStack(spacing: EchoelSpacing.xs) {
                        Image(systemName: panel.icon)
                            .font(.system(size: compact ? 16 : 18, weight: isActive ? .semibold : .regular))
                            .symbolRenderingMode(.hierarchical)

                        Text(panel.rawValue)
                            .font(EchoelBrandFont.label())
                    }
                    .foregroundColor(isActive ? panel.accentColor : EchoelBrand.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, EchoelSpacing.sm)
                    .background(
                        isActive
                            ? panel.accentColor.opacity(0.08)
                            : Color.clear
                    )
                    .overlay(alignment: .bottom) {
                        if isActive {
                            Rectangle()
                                .fill(panel.accentColor)
                                .frame(height: 2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(panel.rawValue) panel")
                .accessibilityAddTraits(activePanel == panel ? .isSelected : [])
            }
        }
        .background(
            EchoelBrand.bgSurface
                .overlay(
                    Rectangle()
                        .fill(EchoelBrand.border)
                        .frame(height: 1),
                    alignment: .bottom
                )
        )
    }

    // MARK: - Vertical Panel Selector (Landscape iPhone & iPad)

    private func verticalPanelSelector(wide: Bool) -> some View {
        let selectorWidth: CGFloat = wide ? 88 : 56

        return VStack(spacing: wide ? EchoelSpacing.sm : EchoelSpacing.xs) {
            Spacer()
                .frame(height: EchoelSpacing.sm)

            ForEach(SynthPanel.allCases) { panel in
                Button {
                    withAnimation(.easeInOut(duration: EchoelAnimation.quick)) {
                        activePanel = panel
                    }
                    HapticHelper.impact(.light)
                } label: {
                    let isActive = activePanel == panel
                    VStack(spacing: wide ? EchoelSpacing.xs : 2) {
                        Image(systemName: panel.icon)
                            .font(.system(size: wide ? 20 : 16, weight: isActive ? .semibold : .regular))
                            .symbolRenderingMode(.hierarchical)

                        if wide {
                            Text(panel.rawValue)
                                .font(EchoelBrandFont.label())
                                .lineLimit(1)
                        }
                    }
                    .foregroundColor(isActive ? panel.accentColor : EchoelBrand.textSecondary)
                    .frame(width: selectorWidth - EchoelSpacing.sm * 2, height: wide ? 60 : 44)
                    .background(
                        RoundedRectangle(cornerRadius: EchoelRadius.sm)
                            .fill(isActive ? panel.accentColor.opacity(0.1) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: EchoelRadius.sm)
                            .stroke(isActive ? panel.accentColor.opacity(0.25) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(panel.rawValue) panel")
                .accessibilityAddTraits(activePanel == panel ? .isSelected : [])
            }

            Spacer()
        }
        .frame(width: selectorWidth)
        .background(
            EchoelBrand.bgSurface
                .overlay(
                    Rectangle()
                        .fill(EchoelBrand.border)
                        .frame(width: 1),
                    alignment: .trailing
                )
        )
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

    private var presetGridMinimum: CGFloat {
        isIPad ? 160 : 140
    }

    private var synthPresetBrowser: some View {
        let library = SynthPresetLibrary.shared

        return ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: EchoelSpacing.lg) {
                ForEach(PresetCategory.allCases, id: \.self) { category in
                    presetSection(category: category, library: library)
                }
            }
            .padding(.horizontal, isIPad ? EchoelSpacing.lg : EchoelSpacing.md)
            .padding(.vertical, EchoelSpacing.md)
        }
        .background(EchoelBrand.bgDeep)
    }

    private func presetSection(category: PresetCategory, library: SynthPresetLibrary) -> some View {
        let categoryPresets = library.presets(for: category)
        guard !categoryPresets.isEmpty else {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(alignment: .leading, spacing: EchoelSpacing.sm) {
                // Section header
                HStack(spacing: EchoelSpacing.sm) {
                    Text(categoryDisplayName(category))
                        .font(EchoelBrandFont.label())
                        .foregroundColor(EchoelBrand.textSecondary)
                        .tracking(1.5)

                    Rectangle()
                        .fill(EchoelBrand.border)
                        .frame(height: 1)

                    Text("\(categoryPresets.count)")
                        .font(EchoelBrandFont.label())
                        .foregroundColor(EchoelBrand.textTertiary)
                }

                // Preset grid
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: presetGridMinimum), spacing: EchoelSpacing.sm)],
                    spacing: EchoelSpacing.sm
                ) {
                    ForEach(categoryPresets) { preset in
                        presetCard(preset)
                    }
                }
            }
        )
    }

    private func categoryDisplayName(_ category: PresetCategory) -> String {
        category.rawValue
            .replacingOccurrences(of: "ECHOEL_", with: "")
            .uppercased()
    }

    private func presetCard(_ preset: SynthPreset) -> some View {
        Button {
            let library = SynthPresetLibrary.shared
            if let buffer = library.renderPresetToBuffer(preset) {
                if !audioEngine.isRunning { audioEngine.start() }
                audioEngine.schedulePlayback(buffer: buffer)
                HapticHelper.notification(.success)
            } else {
                HapticHelper.impact(.medium)
            }
        } label: {
            VStack(alignment: .leading, spacing: EchoelSpacing.xs) {
                // Preset name
                Text(preset.name)
                    .font(EchoelBrandFont.body())
                    .foregroundColor(EchoelBrand.textPrimary)
                    .lineLimit(1)

                // Engine label
                Text(preset.engine.rawValue)
                    .font(EchoelBrandFont.caption())
                    .foregroundColor(EchoelBrand.textTertiary)
                    .lineLimit(1)

                // Tags
                if !preset.tags.isEmpty {
                    HStack(spacing: EchoelSpacing.xs) {
                        ForEach(preset.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(EchoelBrand.textSecondary)
                                .padding(.horizontal, EchoelSpacing.xs + 2)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(EchoelBrand.primary.opacity(0.08))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(EchoelBrand.border, lineWidth: 0.5)
                                )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(EchoelSpacing.sm + EchoelSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: EchoelRadius.md)
                    .fill(EchoelBrand.bgSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: EchoelRadius.md)
                    .stroke(EchoelBrand.border, lineWidth: 1)
            )
        }
        .buttonStyle(PresetCardButtonStyle())
        .accessibilityLabel("\(preset.name), \(preset.engine.rawValue)")
        .accessibilityHint("Double tap to preview")
    }
}

// MARK: - Preset Card Button Style

/// Provides subtle scale and highlight feedback on press
private struct PresetCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: EchoelAnimation.quick), value: configuration.isPressed)
    }
}
