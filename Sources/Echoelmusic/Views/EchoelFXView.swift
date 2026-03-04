import SwiftUI

// MARK: - EchoelFX View
// Connects: NodeGraph, EffectsChainView, EffectParametersView

struct EchoelFXView: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @StateObject private var nodeGraph = NodeGraph()
    @State private var activePanel: FXPanel = .chain
    @State private var selectedNodeID: UUID?

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

    var body: some View {
        VStack(spacing: 0) {
            panelSelector
            panelContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(VaporwaveGradients.background.ignoresSafeArea())
        .onAppear {
            if nodeGraph.nodes.isEmpty {
                nodeGraph.loadFromPreset(NodeGraph.createProductionChain())
            }
        }
    }

    // MARK: - Panel Selector

    private var panelSelector: some View {
        HStack(spacing: 0) {
            ForEach(FXPanel.allCases, id: \.self) { panel in
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
                    .foregroundColor(activePanel == panel ? VaporwaveColors.neonPurple : VaporwaveColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        activePanel == panel
                            ? VaporwaveColors.neonPurple.opacity(0.1)
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
        let activeNode = nodeGraph.nodes.first(where: { $0.id == selectedNodeID }) ?? nodeGraph.nodes.first

        return Group {
            if let node = activeNode {
                VStack(spacing: 0) {
                    // Node picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: VaporwaveSpacing.sm) {
                            ForEach(nodeGraph.nodes, id: \.id) { n in
                                Button {
                                    selectedNodeID = n.id
                                    HapticHelper.impact(.light)
                                } label: {
                                    Text(n.name)
                                        .font(VaporwaveTypography.caption())
                                        .foregroundColor(n.id == node.id ? VaporwaveColors.neonCyan : VaporwaveColors.textSecondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule().fill(
                                                n.id == node.id
                                                    ? VaporwaveColors.neonCyan.opacity(0.15)
                                                    : VaporwaveColors.deepBlack.opacity(0.5)
                                            )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, VaporwaveSpacing.md)
                        .padding(.vertical, VaporwaveSpacing.sm)
                    }

                    EffectParametersView(node: node, nodeGraph: nodeGraph)
                }
            } else {
                VStack(spacing: VaporwaveSpacing.md) {
                    Image(systemName: "waveform.slash")
                        .font(.system(size: 40))
                        .foregroundColor(VaporwaveColors.textTertiary)
                    Text("No effects in chain")
                        .font(VaporwaveTypography.body())
                        .foregroundColor(VaporwaveColors.textSecondary)
                    Text("Add effects from the Chain tab")
                        .font(VaporwaveTypography.caption())
                        .foregroundColor(VaporwaveColors.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Preset Browser

    private var presetBrowser: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VaporwaveSpacing.md) {
                presetCard(
                    name: "Production",
                    description: "Filter + Compressor + Reverb",
                    factory: NodeGraph.createProductionChain
                )
                presetCard(
                    name: "Biofeedback",
                    description: "Bio-reactive Filter + Reverb",
                    factory: NodeGraph.createBiofeedbackChain
                )
                presetCard(
                    name: "Healing",
                    description: "Gentle reverb wash",
                    factory: NodeGraph.createHealingPreset
                )
                presetCard(
                    name: "Energizing",
                    description: "Bright resonant filter",
                    factory: NodeGraph.createEnergizingPreset
                )
            }
            .padding(VaporwaveSpacing.md)
        }
    }

    private func presetCard(name: String, description: String, factory: @escaping () -> NodeGraph) -> some View {
        Button {
            nodeGraph.loadFromPreset(factory())
            selectedNodeID = nodeGraph.nodes.first?.id
            HapticHelper.impact(.medium)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(VaporwaveTypography.body())
                        .foregroundColor(VaporwaveColors.textPrimary)
                    Text(description)
                        .font(VaporwaveTypography.caption())
                        .foregroundColor(VaporwaveColors.textTertiary)
                }
                Spacer()
                Image(systemName: "arrow.right.circle")
                    .foregroundColor(VaporwaveColors.neonPurple)
            }
            .padding(VaporwaveSpacing.md)
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
