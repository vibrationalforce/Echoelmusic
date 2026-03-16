#if canImport(SwiftUI)
import SwiftUI

// MARK: - EchoelFX View
// Adaptive effects processor view for iPhone (portrait/landscape) and iPad
// EchoelSurface design system with EchoelBrand tokens
// Connects: NodeGraph, EffectsChainView, EffectParametersView

struct EchoelFXView: View {
    @Environment(AudioEngine.self) var audioEngine
    @State private var nodeGraph = NodeGraph()
    @State private var activePanel: FXPanel = .chain
    @State private var selectedNodeID: UUID?
    @State private var showPresetSheet = false

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    #endif

    // MARK: - Panel Definition

    enum FXPanel: String, CaseIterable {
        case chain = "Chain"
        case params = "Params"
        case presets = "Presets"

        var icon: String {
            switch self {
            case .chain: return "link"
            case .params: return "slider.horizontal.3"
            case .presets: return "list.bullet"
            }
        }
    }

    // MARK: - Layout Detection

    private enum LayoutMode {
        case compactPortrait    // iPhone portrait
        case compactLandscape   // iPhone landscape
        case regular            // iPad
    }

    private var layoutMode: LayoutMode {
        #if os(iOS)
        if horizontalSizeClass == .regular {
            return .regular
        }
        if verticalSizeClass == .compact {
            return .compactLandscape
        }
        return .compactPortrait
        #else
        return .regular
        #endif
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            EchoelBrand.bgDeep.ignoresSafeArea()

            switch layoutMode {
            case .compactPortrait:
                compactPortraitLayout
            case .compactLandscape:
                compactLandscapeLayout
            case .regular:
                regularLayout
            }
        }
        .onAppear {
            if nodeGraph.nodes.isEmpty {
                nodeGraph.loadFromPreset(NodeGraph.createProductionChain())
                selectedNodeID = nodeGraph.nodes.first?.id
            }
        }
        .sheet(isPresented: $showPresetSheet) {
            presetSheet
        }
    }

    // MARK: - Compact Portrait (iPhone Portrait)
    // Stacked: panel selector tabs on top, content below

    private var compactPortraitLayout: some View {
        VStack(spacing: 0) {
            portraitHeader
            portraitPanelSelector
            panelContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Compact Landscape (iPhone Landscape)
    // Side-by-side: vertical icon strip on left, content on right (full height)

    private var compactLandscapeLayout: some View {
        HStack(spacing: 0) {
            landscapeIconStrip
            panelContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Regular Layout (iPad)
    // Split view: effects chain on left (60%), parameters/presets on right (40%)

    private var regularLayout: some View {
        VStack(spacing: 0) {
            iPadToolbar
            HStack(spacing: 0) {
                // Left panel: Effects chain (60%)
                VStack(spacing: 0) {
                    iPadSectionHeader(title: "EFFECTS CHAIN", icon: "link")
                    EffectsChainView(nodeGraph: nodeGraph)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity)

                // Vertical glass divider
                glassDividerVertical

                // Right panel: Parameters + Presets (40%)
                VStack(spacing: 0) {
                    iPadRightPanelSelector
                    iPadRightPanelContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity)
                .layoutPriority(-0.5)
            }
        }
    }

    // MARK: - Portrait Header

    private var portraitHeader: some View {
        HStack(spacing: EchoelSpacing.sm) {
            Image(systemName: "waveform.path")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(EchoelBrand.primary)

            Text("EchoelFX")
                .font(EchoelBrandFont.cardTitle())
                .foregroundColor(EchoelBrand.textPrimary)

            Spacer()

            // Node count badge
            if !nodeGraph.nodes.isEmpty {
                nodeCountBadge
            }

            // Preset button
            Button {
                showPresetSheet = true
                HapticHelper.impact(.light)
            } label: {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(EchoelBrand.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: EchoelRadius.sm)
                            .fill(EchoelBrand.bgElevated)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: EchoelRadius.sm)
                            .stroke(EchoelBrand.border, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open presets")
        }
        .padding(.horizontal, EchoelSpacing.md)
        .padding(.vertical, EchoelSpacing.sm)
        .background(EchoelBrand.bgSurface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(EchoelBrand.border)
                .frame(height: 1)
        }
    }

    // MARK: - Portrait Panel Selector (Horizontal tabs)

    private var portraitPanelSelector: some View {
        HStack(spacing: 0) {
            ForEach(FXPanel.allCases, id: \.self) { panel in
                Button {
                    withAnimation(.easeInOut(duration: EchoelAnimation.quick)) {
                        activePanel = panel
                    }
                    HapticHelper.impact(.light)
                } label: {
                    VStack(spacing: EchoelSpacing.xs) {
                        Image(systemName: panel.icon)
                            .font(.system(size: 16, weight: .medium))
                        Text(panel.rawValue)
                            .font(EchoelBrandFont.label())
                    }
                    .foregroundColor(activePanel == panel ? EchoelBrand.primary : EchoelBrand.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, EchoelSpacing.sm + 2)
                    .background(
                        activePanel == panel
                            ? EchoelBrand.primary.opacity(0.06)
                            : Color.clear
                    )
                    .overlay(alignment: .bottom) {
                        if activePanel == panel {
                            Capsule()
                                .fill(EchoelBrand.primary)
                                .frame(width: 32, height: 2)
                                .padding(.bottom, 1)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(panel.rawValue) tab")
                .accessibilityAddTraits(activePanel == panel ? .isSelected : [])
            }
        }
        .background(EchoelBrand.bgSurface.opacity(0.8))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(EchoelBrand.border)
                .frame(height: 1)
        }
    }

    // MARK: - Landscape Icon Strip (Vertical sidebar)

    private var landscapeIconStrip: some View {
        VStack(spacing: EchoelSpacing.xs) {
            // Title
            Image(systemName: "waveform.path")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(EchoelBrand.primary)
                .frame(width: 52, height: 32)
                .padding(.bottom, EchoelSpacing.xs)

            // Panel tabs
            ForEach(FXPanel.allCases, id: \.self) { panel in
                Button {
                    withAnimation(.easeInOut(duration: EchoelAnimation.quick)) {
                        activePanel = panel
                    }
                    HapticHelper.impact(.light)
                } label: {
                    VStack(spacing: EchoelSpacing.xxs) {
                        Image(systemName: panel.icon)
                            .font(.system(size: 18, weight: .medium))
                        Text(panel.rawValue)
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundColor(activePanel == panel ? EchoelBrand.primary : EchoelBrand.textSecondary)
                    .frame(width: 52, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: EchoelRadius.sm)
                            .fill(activePanel == panel ? EchoelBrand.primary.opacity(0.08) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: EchoelRadius.sm)
                            .stroke(
                                activePanel == panel ? EchoelBrand.borderActive : Color.clear,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(panel.rawValue) tab")
                .accessibilityAddTraits(activePanel == panel ? .isSelected : [])
            }

            Spacer()

            // Preset quick-access
            Button {
                showPresetSheet = true
                HapticHelper.impact(.light)
            } label: {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(EchoelBrand.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: EchoelRadius.sm)
                            .fill(EchoelBrand.bgElevated)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: EchoelRadius.sm)
                            .stroke(EchoelBrand.border, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open presets")
        }
        .padding(.vertical, EchoelSpacing.sm)
        .padding(.horizontal, EchoelSpacing.xs)
        .background(EchoelBrand.bgSurface)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(EchoelBrand.border)
                .frame(width: 1)
        }
    }

    // MARK: - iPad Toolbar

    private var iPadToolbar: some View {
        HStack(spacing: EchoelSpacing.md) {
            Image(systemName: "waveform.path")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(EchoelBrand.primary)

            Text("EchoelFX")
                .font(EchoelBrandFont.cardTitle())
                .foregroundColor(EchoelBrand.textPrimary)

            Spacer()

            if !nodeGraph.nodes.isEmpty {
                nodeCountBadge
            }

            // Preset button
            Button {
                showPresetSheet = true
                HapticHelper.impact(.light)
            } label: {
                HStack(spacing: EchoelSpacing.sm) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 14, weight: .medium))
                    Text("Presets")
                        .font(EchoelBrandFont.label())
                }
                .foregroundColor(EchoelBrand.textSecondary)
                .padding(.horizontal, EchoelSpacing.md)
                .padding(.vertical, EchoelSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: EchoelRadius.sm)
                        .fill(EchoelBrand.bgElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: EchoelRadius.sm)
                        .stroke(EchoelBrand.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open presets")
        }
        .padding(.horizontal, EchoelSpacing.md)
        .padding(.vertical, EchoelSpacing.sm)
        .background(EchoelBrand.bgSurface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(EchoelBrand.border)
                .frame(height: 1)
        }
    }

    // MARK: - iPad Section Header

    private func iPadSectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: EchoelSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(EchoelBrand.textSecondary)

            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(EchoelBrand.textSecondary)
                .tracking(1.5)

            Spacer()

            // Node count inline
            Text("\(nodeGraph.nodes.count) nodes")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(EchoelBrand.textSecondary)
        }
        .padding(.horizontal, EchoelSpacing.md)
        .padding(.vertical, EchoelSpacing.sm)
        .background(EchoelBrand.bgSurface.opacity(0.6))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(EchoelBrand.border)
                .frame(height: 1)
        }
    }

    // MARK: - iPad Right Panel Selector

    private var iPadRightPanelSelector: some View {
        HStack(spacing: 0) {
            iPadTabButton(panel: .params)
            iPadTabButton(panel: .presets)
        }
        .background(EchoelBrand.bgSurface.opacity(0.6))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(EchoelBrand.border)
                .frame(height: 1)
        }
    }

    private func iPadTabButton(panel: FXPanel) -> some View {
        Button {
            withAnimation(.easeInOut(duration: EchoelAnimation.quick)) {
                activePanel = panel
            }
            HapticHelper.impact(.light)
        } label: {
            HStack(spacing: EchoelSpacing.sm) {
                Image(systemName: panel.icon)
                    .font(.system(size: 13, weight: .medium))
                Text(panel.rawValue)
                    .font(EchoelBrandFont.label())
            }
            .foregroundColor(activePanel == panel ? EchoelBrand.primary : EchoelBrand.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, EchoelSpacing.sm)
            .overlay(alignment: .bottom) {
                if activePanel == panel {
                    Capsule()
                        .fill(EchoelBrand.primary)
                        .frame(width: 28, height: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(panel.rawValue) tab")
        .accessibilityAddTraits(activePanel == panel ? .isSelected : [])
    }

    @ViewBuilder
    private var iPadRightPanelContent: some View {
        switch activePanel {
        case .chain, .params:
            parameterPanel
        case .presets:
            presetBrowser
        }
    }

    // MARK: - Glass Divider

    private var glassDividerVertical: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        EchoelBrand.border.opacity(0),
                        EchoelBrand.border,
                        EchoelBrand.border,
                        EchoelBrand.border.opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 1)
    }

    // MARK: - Panel Content (iPhone)

    @ViewBuilder
    private var panelContent: some View {
        switch activePanel {
        case .chain:
            EffectsChainView(nodeGraph: nodeGraph)
        case .params:
            parameterPanel
        case .presets:
            presetBrowser
        }
    }

    // MARK: - Parameter Panel

    private var parameterPanel: some View {
        let activeNode = nodeGraph.nodes.first(where: { $0.id == selectedNodeID })
            ?? nodeGraph.nodes.first

        return Group {
            if let node = activeNode {
                VStack(spacing: 0) {
                    nodePickerStrip(selectedNode: node)
                    EffectParametersView(node: node, nodeGraph: nodeGraph)
                }
            } else {
                emptyParameterState
            }
        }
    }

    private func nodeTextColor(node: EchoelmusicNode, isSelected: Bool) -> Color {
        if node.isBypassed { return EchoelBrand.textTertiary }
        return isSelected ? EchoelBrand.primary : EchoelBrand.textSecondary
    }

    private func nodeFillColor(node: EchoelmusicNode, isSelected: Bool) -> Color {
        if node.isBypassed { return EchoelBrand.coral.opacity(0.05) }
        return isSelected ? EchoelBrand.primary.opacity(0.08) : EchoelBrand.bgSurface
    }

    private func nodeStrokeColor(node: EchoelmusicNode, isSelected: Bool) -> Color {
        if node.isBypassed { return EchoelBrand.coral.opacity(0.3) }
        return isSelected ? EchoelBrand.borderActive : EchoelBrand.border
    }

    private func nodePickerStrip(selectedNode: EchoelmusicNode) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EchoelSpacing.sm) {
                ForEach(nodeGraph.nodes, id: \.id) { node in
                    let isSelected: Bool = node.id == selectedNode.id
                    nodePickerItem(node: node, isSelected: isSelected)
                }
            }
            .padding(.horizontal, EchoelSpacing.md)
            .padding(.vertical, EchoelSpacing.sm)
        }
        .background(EchoelBrand.bgSurface.opacity(0.5))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(EchoelBrand.border)
                .frame(height: 1)
        }
    }

    private func nodePickerItem(node: EchoelmusicNode, isSelected: Bool) -> some View {
        let dotColor: Color = node.isBypassed ? EchoelBrand.textTertiary : accentColorForNode(node)
        let foreground: Color = nodeTextColor(node: node, isSelected: isSelected)
        let fill: Color = nodeFillColor(node: node, isSelected: isSelected)
        let stroke: Color = nodeStrokeColor(node: node, isSelected: isSelected)
        let bypassIcon: String = node.isBypassed ? "xmark.circle.fill" : "power.circle"
        let bypassColor: Color = node.isBypassed ? EchoelBrand.coral : EchoelBrand.emerald
        let accessLabel: String = "\(node.name) effect, \(node.isBypassed ? "bypassed" : "active")"

        return HStack(spacing: 2) {
            Button {
                withAnimation(.easeInOut(duration: EchoelAnimation.quick)) {
                    selectedNodeID = node.id
                }
                HapticHelper.impact(.light)
            } label: {
                HStack(spacing: EchoelSpacing.xs) {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 6, height: 6)
                    Image(systemName: iconForNode(node))
                        .font(.system(size: 11))
                    Text(node.name)
                        .font(EchoelBrandFont.label())
                        .strikethrough(node.isBypassed, color: EchoelBrand.textTertiary)
                }
                .foregroundColor(foreground)
            }
            .buttonStyle(.plain)

            Button {
                node.isBypassed.toggle()
                HapticHelper.impact(.medium)
            } label: {
                Image(systemName: bypassIcon)
                    .font(.system(size: 13))
                    .foregroundColor(bypassColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, EchoelSpacing.sm + 2)
        .padding(.vertical, EchoelSpacing.xs + 2)
        .background(Capsule().fill(fill))
        .overlay(Capsule().stroke(stroke, lineWidth: 1))
        .accessibilityLabel(accessLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var emptyParameterState: some View {
        VStack(spacing: EchoelSpacing.lg) {
            ZStack {
                Circle()
                    .fill(EchoelBrand.primary.opacity(0.04))
                    .frame(width: 88, height: 88)

                Circle()
                    .stroke(EchoelBrand.border, lineWidth: 1)
                    .frame(width: 88, height: 88)

                Image(systemName: "waveform.slash")
                    .font(.system(size: 32))
                    .foregroundColor(EchoelBrand.textSecondary)
            }

            VStack(spacing: EchoelSpacing.sm) {
                Text("No Effects in Chain")
                    .font(EchoelBrandFont.cardTitle())
                    .foregroundColor(EchoelBrand.textPrimary)

                Text("Load a preset or add effects from the Chain tab")
                    .font(EchoelBrandFont.caption())
                    .foregroundColor(EchoelBrand.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, EchoelSpacing.xl)
            }

            Button {
                showPresetSheet = true
                HapticHelper.impact(.medium)
            } label: {
                HStack(spacing: EchoelSpacing.sm) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 14, weight: .medium))
                    Text("Browse Presets")
                        .font(EchoelBrandFont.body())
                }
                .foregroundColor(EchoelBrand.bgDeep)
                .padding(.horizontal, EchoelSpacing.lg)
                .padding(.vertical, EchoelSpacing.sm + 2)
                .background(
                    Capsule()
                        .fill(EchoelBrand.primary)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Browse presets")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Preset Browser

    private var presetBrowser: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EchoelSpacing.md) {
                // Section header
                HStack(spacing: EchoelSpacing.sm) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(EchoelBrand.textSecondary)

                    Text("FACTORY PRESETS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(EchoelBrand.textSecondary)
                        .tracking(1.5)
                }
                .padding(.bottom, EchoelSpacing.xs)

                presetCard(
                    name: "Production",
                    description: "Filter + Compressor + Reverb",
                    icon: "music.mic",
                    accentColor: EchoelBrand.primary,
                    factory: NodeGraph.createProductionChain
                )

                presetCard(
                    name: "Biofeedback",
                    description: "Bio-reactive filter + reverb chain",
                    icon: "heart.text.square",
                    accentColor: EchoelBrand.sky,
                    factory: NodeGraph.createBiofeedbackChain
                )

                presetCard(
                    name: "Relax",
                    description: "Gentle reverb wash",
                    icon: "leaf",
                    accentColor: EchoelBrand.emerald,
                    factory: NodeGraph.createRelaxPreset
                )

                presetCard(
                    name: "Energizing",
                    description: "Bright resonant filter",
                    icon: "bolt",
                    accentColor: EchoelBrand.amber,
                    factory: NodeGraph.createEnergizingPreset
                )

                // Clear chain action
                if !nodeGraph.nodes.isEmpty {
                    clearChainButton
                        .padding(.top, EchoelSpacing.sm)
                }
            }
            .padding(EchoelSpacing.md)
        }
    }

    private func presetCard(
        name: String,
        description: String,
        icon: String,
        accentColor: Color,
        factory: @escaping () -> NodeGraph
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: EchoelAnimation.smooth)) {
                nodeGraph.loadFromPreset(factory())
                selectedNodeID = nodeGraph.nodes.first?.id
                activePanel = .chain
            }
            HapticHelper.impact(.medium)
        } label: {
            HStack(spacing: EchoelSpacing.md) {
                // Icon with accent background
                ZStack {
                    RoundedRectangle(cornerRadius: EchoelRadius.sm)
                        .fill(accentColor.opacity(0.08))
                        .frame(width: 44, height: 44)

                    RoundedRectangle(cornerRadius: EchoelRadius.sm)
                        .stroke(accentColor.opacity(0.15), lineWidth: 1)
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(accentColor)
                }

                // Text content
                VStack(alignment: .leading, spacing: EchoelSpacing.xxs) {
                    Text(name)
                        .font(EchoelBrandFont.body())
                        .foregroundColor(EchoelBrand.textPrimary)

                    Text(description)
                        .font(EchoelBrandFont.caption())
                        .foregroundColor(EchoelBrand.textSecondary)
                }

                Spacer()

                // Arrow indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(EchoelBrand.textSecondary)
            }
            .padding(EchoelSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: EchoelRadius.md)
                    .fill(EchoelBrand.bgSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: EchoelRadius.md)
                    .stroke(EchoelBrand.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Load \(name) preset: \(description)")
    }

    private var clearChainButton: some View {
        Button {
            withAnimation(.easeInOut(duration: EchoelAnimation.smooth)) {
                nodeGraph.loadFromPreset(NodeGraph())
                selectedNodeID = nil
            }
            HapticHelper.impact(.medium)
        } label: {
            HStack(spacing: EchoelSpacing.sm) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 14, weight: .medium))
                Text("Clear Chain")
                    .font(EchoelBrandFont.caption())
            }
            .foregroundColor(EchoelBrand.coral)
            .frame(maxWidth: .infinity)
            .padding(.vertical, EchoelSpacing.sm + 2)
            .background(
                RoundedRectangle(cornerRadius: EchoelRadius.md)
                    .fill(EchoelBrand.coral.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: EchoelRadius.md)
                    .stroke(EchoelBrand.coral.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Clear effects chain")
    }

    // MARK: - Node Count Badge

    private var nodeCountBadge: some View {
        HStack(spacing: EchoelSpacing.xs) {
            Circle()
                .fill(EchoelBrand.emerald)
                .frame(width: 6, height: 6)

            Text("\(nodeGraph.nodes.count)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(EchoelBrand.textSecondary)

            Text(nodeGraph.nodes.count == 1 ? "node" : "nodes")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(EchoelBrand.textSecondary)
        }
        .padding(.horizontal, EchoelSpacing.sm + 2)
        .padding(.vertical, EchoelSpacing.xs)
        .background(
            Capsule()
                .fill(EchoelBrand.bgElevated)
        )
        .overlay(
            Capsule()
                .stroke(EchoelBrand.border, lineWidth: 1)
        )
        .accessibilityLabel("\(nodeGraph.nodes.count) active nodes")
    }

    // MARK: - Preset Sheet

    private var presetSheet: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: EchoelSpacing.md) {
                    presetCard(
                        name: "Production",
                        description: "Filter + Compressor + Reverb",
                        icon: "music.mic",
                        accentColor: EchoelBrand.primary,
                        factory: NodeGraph.createProductionChain
                    )

                    presetCard(
                        name: "Biofeedback",
                        description: "Bio-reactive filter + reverb chain",
                        icon: "heart.text.square",
                        accentColor: EchoelBrand.sky,
                        factory: NodeGraph.createBiofeedbackChain
                    )

                    presetCard(
                        name: "Relax",
                        description: "Gentle reverb wash",
                        icon: "leaf",
                        accentColor: EchoelBrand.emerald,
                        factory: NodeGraph.createRelaxPreset
                    )

                    presetCard(
                        name: "Energizing",
                        description: "Bright resonant filter",
                        icon: "bolt",
                        accentColor: EchoelBrand.amber,
                        factory: NodeGraph.createEnergizingPreset
                    )
                }
                .padding(EchoelSpacing.md)
            }
            .background(EchoelBrand.bgDeep.ignoresSafeArea())
            .navigationTitle("Presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showPresetSheet = false
                    }
                    .foregroundColor(EchoelBrand.primary)
                }
            }
        }
    }

    // MARK: - Helpers

    private func iconForNode(_ node: EchoelmusicNode) -> String {
        let name = node.name.lowercased()

        if name.contains("filter") {
            return "waveform.path"
        } else if name.contains("reverb") {
            return "music.note.house"
        } else if name.contains("delay") {
            return "arrow.triangle.2.circlepath"
        } else if name.contains("compressor") {
            return "waveform.path.ecg"
        } else {
            return "waveform"
        }
    }

    private func accentColorForNode(_ node: EchoelmusicNode) -> Color {
        let name = node.name.lowercased()

        if name.contains("filter") {
            return EchoelBrand.violet
        } else if name.contains("reverb") {
            return EchoelBrand.sky
        } else if name.contains("delay") {
            return EchoelBrand.amber
        } else if name.contains("compressor") {
            return EchoelBrand.emerald
        } else {
            return EchoelBrand.primary
        }
    }
}
#endif
