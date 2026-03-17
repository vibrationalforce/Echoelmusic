#if canImport(SwiftUI)
import SwiftUI

/// Visual effects chain editor with node routing
/// Uses EchoelBrand design system for consistent styling
struct EffectsChainView: View {
    @Bindable var nodeGraph: NodeGraph

    @State private var selectedNode: UUID?
    @State private var showNodePicker = false
    @State private var showPresets = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: EchoelSpacing.lg) {
                    // Node Graph Visualization
                    nodeGraphView

                    // Node List
                    nodeListView

                    // Add Node Button
                    addNodeButton

                    // Presets Section
                    presetsSection
                }
                .padding()
            }
            .background(EchoelBrand.bgDeep)
            .navigationTitle("Effects Chain")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showNodePicker) {
                nodePickerView
            }
            .sheet(isPresented: $showPresets) {
                presetsView
            }
        }
    }

    // MARK: - Node Graph Visualization

    private var nodeGraphView: some View {
        VStack(alignment: .leading, spacing: EchoelSpacing.md) {
            Text("Signal Flow")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(EchoelBrand.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: EchoelSpacing.md) {
                    // Input
                    signalFlowBox("Input", color: EchoelBrand.emerald, isInput: true)
                        .accessibilityLabel("Audio input")

                    ForEach(nodeGraph.nodes, id: \.id) { node in
                        Image(systemName: "arrow.right")
                            .foregroundColor(EchoelBrand.textTertiary)

                        signalFlowBox(node.name, color: nodeColor(for: node), isNode: true)
                            .onTapGesture {
                                selectedNode = node.id
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedNode == node.id ? EchoelBrand.sky : Color.clear, lineWidth: 2)
                            )
                            .accessibilityLabel("\(node.name) effect node")
                            .accessibilityHint("Double tap to select")
                    }

                    Image(systemName: "arrow.right")
                        .foregroundColor(EchoelBrand.textTertiary)

                    // Output
                    signalFlowBox("Output", color: EchoelBrand.sky, isOutput: true)
                        .accessibilityLabel("Audio output")
                }
            }
        }
        .padding()
        .echoelSurface()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Effects signal flow with \(nodeGraph.nodes.count) nodes")
    }

    private func signalFlowBox(_ label: String, color: Color, isInput: Bool = false, isOutput: Bool = false, isNode: Bool = false) -> some View {
        VStack(spacing: EchoelSpacing.xs) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.2))
                    .frame(width: 80, height: 60)

                if isInput {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 24))
                        .foregroundColor(color)
                } else if isOutput {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 24))
                        .foregroundColor(color)
                } else {
                    Image(systemName: "waveform.path")
                        .font(.system(size: 24))
                        .foregroundColor(color)
                }
            }
            .neonGlow(color: color, radius: 5)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(EchoelBrand.textSecondary)
                .lineLimit(1)
        }
    }

    // MARK: - Node List

    private var nodeListView: some View {
        VStack(alignment: .leading, spacing: EchoelSpacing.md) {
            Text("Active Nodes (\(nodeGraph.nodes.count))")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(EchoelBrand.textSecondary)

            if nodeGraph.nodes.isEmpty {
                emptyStateView
            } else {
                ForEach(nodeGraph.nodes, id: \.id) { node in
                    NodeRow(node: node, nodeGraph: nodeGraph, isSelected: selectedNode == node.id)
                        .onTapGesture {
                            selectedNode = node.id
                        }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Active nodes list")
    }

    private var emptyStateView: some View {
        VaporwaveEmptyState(
            icon: "waveform.path.badge.plus",
            title: "No Effects Added",
            message: "Tap + to add your first audio effect node",
            actionTitle: "Add Effect",
            action: { showNodePicker.toggle() }
        )
    }

    // MARK: - Add Node Button

    private var addNodeButton: some View {
        Button {
            showNodePicker.toggle()
            HapticHelper.impact(.medium)
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                Text("Add Effect Node")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(EchoelBrand.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, EchoelSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(EchoelBrand.sky.opacity(0.3))
            )
        }
        .accessibilityLabel("Add effect node")
        .accessibilityHint("Opens effect picker")
    }

    // MARK: - Presets Section

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: EchoelSpacing.md) {
            HStack {
                Text("Presets")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(EchoelBrand.textSecondary)

                Spacer()

                Button {
                    showPresets.toggle()
                    HapticHelper.impact(.light)
                } label: {
                    Text("View All")
                        .font(.system(size: 12))
                        .foregroundColor(EchoelBrand.sky)
                }
                .accessibilityLabel("View all presets")
            }

            HStack(spacing: EchoelSpacing.md) {
                presetButton("Biofeedback", icon: "heart.fill", color: EchoelBrand.coral) {
                    nodeGraph.loadFromPreset(NodeGraph.createBiofeedbackChain())
                }

                presetButton("Relax", icon: "leaf.fill", color: EchoelBrand.emerald) {
                    nodeGraph.loadFromPreset(NodeGraph.createRelaxPreset())
                }

                presetButton("Energizing", icon: "bolt.fill", color: EchoelBrand.coral) {
                    nodeGraph.loadFromPreset(NodeGraph.createEnergizingPreset())
                }
            }
        }
    }

    private func presetButton(_ title: String, icon: String, color: Color = EchoelBrand.sky, action: @escaping () -> Void) -> some View {
        Button {
            action()
            HapticHelper.impact(.medium)
        } label: {
            VStack(spacing: EchoelSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)

                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(EchoelBrand.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, EchoelSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.1))
            )
            .neonGlow(color: color, radius: 5)
        }
        .accessibilityLabel("Apply \(title) preset")
    }

    // MARK: - Node Picker

    private var nodePickerView: some View {
        NavigationView {
            List {
                Section(header: Text("Filter Effects")) {
                    nodeTypeButton("Low-Pass Filter", icon: "waveform.path", description: "Bio-reactive frequency filter") {
                        addFilterNode()
                    }
                }

                Section(header: Text("Dynamics")) {
                    nodeTypeButton("Compressor", icon: "waveform.path.ecg", description: "Respiratory-controlled compression") {
                        addCompressorNode()
                    }
                }

                Section(header: Text("Time-Based")) {
                    nodeTypeButton("Reverb", icon: "music.note.house", description: "HRV-coherence reverb") {
                        addReverbNode()
                    }

                    nodeTypeButton("Delay", icon: "arrow.triangle.2.circlepath", description: "Heart rate synced delay") {
                        addDelayNode()
                    }
                }
            }
            .navigationTitle("Add Effect")
            .navigationBarItems(trailing: Button("Done") {
                showNodePicker = false
            })
        }
    }

    private func nodeTypeButton(_ title: String, icon: String, description: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
            showNodePicker = false
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.cyan)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.cyan)
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Presets View

    private var presetsView: some View {
        NavigationView {
            List {
                Section(header: Text("Bio-Reactive Presets")) {
                    presetRow("Biofeedback Chain", description: "Filter → Reverb optimized for biofeedback") {
                        nodeGraph.loadFromPreset(NodeGraph.createBiofeedbackChain())
                        showPresets = false
                    }

                    presetRow("Relax", description: "Deep reverb with gentle compression") {
                        nodeGraph.loadFromPreset(NodeGraph.createRelaxPreset())
                        showPresets = false
                    }

                    presetRow("Energizing", description: "Bright filter with rhythmic delay") {
                        nodeGraph.loadFromPreset(NodeGraph.createEnergizingPreset())
                        showPresets = false
                    }
                }

                Section(header: Text("Actions")) {
                    Button(action: {
                        nodeGraph.nodes.removeAll()
                        nodeGraph.connections.removeAll()
                        showPresets = false
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear All Nodes")
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Presets")
            .navigationBarItems(trailing: Button("Done") {
                showPresets = false
            })
        }
    }

    private func presetRow(_ title: String, description: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)

                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Node Actions

    private func addFilterNode() {
        let node = FilterNode()
        nodeGraph.addNode(node)
    }

    private func addCompressorNode() {
        let node = CompressorNode()
        nodeGraph.addNode(node)
    }

    private func addReverbNode() {
        let node = ReverbNode()
        nodeGraph.addNode(node)
    }

    private func addDelayNode() {
        let node = DelayNode()
        nodeGraph.addNode(node)
    }

    // MARK: - Helpers

    private func nodeColor(for node: EchoelmusicNode) -> Color {
        let name = node.name.lowercased()

        if name.contains("filter") {
            return EchoelBrand.violet
        } else if name.contains("reverb") {
            return EchoelBrand.sky
        } else if name.contains("delay") {
            return EchoelBrand.coral
        } else if name.contains("compressor") {
            return EchoelBrand.emerald
        } else {
            return EchoelBrand.coral
        }
    }
}

// MARK: - Node Row

struct NodeRow: View {
    let node: EchoelmusicNode
    @Bindable var nodeGraph: NodeGraph
    let isSelected: Bool

    var body: some View {
        VStack(spacing: EchoelSpacing.md) {
            nodeHeader
            if node.isBioReactive {
                bioReactiveIndicator
            }
        }
        .padding(EchoelSpacing.md)
        .background(nodeBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(node.name), \(nodeDescription)\(node.isBioReactive ? ", bio-reactive" : "")")
        .accessibilityHint(isSelected ? "Selected" : "Double tap to select")
    }

    private var nodeHeader: some View {
        HStack(spacing: EchoelSpacing.md) {
            Image(systemName: nodeIcon)
                .font(.system(size: 18))
                .foregroundColor(nodeColor)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(nodeColor.opacity(0.2))
                )
                .neonGlow(color: nodeColor, radius: 5)

            VStack(alignment: .leading, spacing: EchoelSpacing.xs) {
                Text(node.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(EchoelBrand.textPrimary)
                Text(nodeDescription)
                    .font(.system(size: 11))
                    .foregroundColor(EchoelBrand.textTertiary)
            }

            Spacer()

            Button(action: { nodeGraph.removeNode(id: node.id) }) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(EchoelBrand.coral.opacity(0.7))
            }
            .accessibilityLabel("Delete \(node.name)")
        }
    }

    private var bioReactiveIndicator: some View {
        HStack(spacing: EchoelSpacing.xs) {
            Image(systemName: "heart.fill")
                .font(.system(size: 10))
                .foregroundColor(EchoelBrand.coral)
            Text("Bio-Reactive")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(EchoelBrand.coral)
            Spacer()
        }
    }

    private var nodeBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(isSelected ? EchoelBrand.sky.opacity(0.1) : EchoelBrand.bgElevated)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? EchoelBrand.sky : Color.clear, lineWidth: 1)
            )
    }

    private var nodeIcon: String {
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

    private var nodeColor: Color {
        let name = node.name.lowercased()

        if name.contains("filter") {
            return EchoelBrand.violet
        } else if name.contains("reverb") {
            return EchoelBrand.sky
        } else if name.contains("delay") {
            return EchoelBrand.coral
        } else if name.contains("compressor") {
            return EchoelBrand.emerald
        } else {
            return EchoelBrand.coral
        }
    }

    private var nodeDescription: String {
        let name = node.name.lowercased()

        if name.contains("filter") {
            return "Frequency filtering"
        } else if name.contains("reverb") {
            return "Spatial reverb effect"
        } else if name.contains("delay") {
            return "Time-delayed echo"
        } else if name.contains("compressor") {
            return "Dynamic range control"
        } else {
            return "Audio processing"
        }
    }
}
#endif
