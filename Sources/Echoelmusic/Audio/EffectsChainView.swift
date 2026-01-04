import SwiftUI

/// Visual effects chain editor with node routing
/// Uses VaporwaveTheme for consistent styling
struct EffectsChainView: View {
    @ObservedObject var nodeGraph: NodeGraph

    @State private var selectedNode: UUID?
    @State private var showNodePicker = false
    @State private var showPresets = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: VaporwaveSpacing.lg) {
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
            .background(VaporwaveGradients.background)
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
        VStack(alignment: .leading, spacing: VaporwaveSpacing.md) {
            Text("Signal Flow")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(VaporwaveColors.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: VaporwaveSpacing.md) {
                    // Input
                    signalFlowBox("Input", color: VaporwaveColors.coherenceHigh, isInput: true)
                        .accessibilityLabel("Audio input")

                    ForEach(nodeGraph.nodes, id: \.id) { node in
                        Image(systemName: "arrow.right")
                            .foregroundColor(VaporwaveColors.textTertiary)

                        signalFlowBox(node.name, color: nodeColor(for: node), isNode: true)
                            .onTapGesture {
                                selectedNode = node.id
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedNode == node.id ? VaporwaveColors.neonCyan : Color.clear, lineWidth: 2)
                            )
                            .accessibilityLabel("\(node.name) effect node")
                            .accessibilityHint("Double tap to select")
                    }

                    Image(systemName: "arrow.right")
                        .foregroundColor(VaporwaveColors.textTertiary)

                    // Output
                    signalFlowBox("Output", color: VaporwaveColors.neonCyan, isOutput: true)
                        .accessibilityLabel("Audio output")
                }
            }
        }
        .padding()
        .glassCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Effects signal flow with \(nodeGraph.nodes.count) nodes")
    }

    private func signalFlowBox(_ label: String, color: Color, isInput: Bool = false, isOutput: Bool = false, isNode: Bool = false) -> some View {
        VStack(spacing: VaporwaveSpacing.xs) {
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
                .foregroundColor(VaporwaveColors.textSecondary)
                .lineLimit(1)
        }
    }

    // MARK: - Node List

    private var nodeListView: some View {
        VStack(alignment: .leading, spacing: VaporwaveSpacing.md) {
            Text("Active Nodes (\(nodeGraph.nodes.count))")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(VaporwaveColors.textSecondary)

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
        Button(action: { showNodePicker.toggle() }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                Text("Add Effect Node")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(VaporwaveColors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, VaporwaveSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(VaporwaveColors.neonCyan.opacity(0.3))
            )
        }
        .accessibilityLabel("Add effect node")
        .accessibilityHint("Opens effect picker")
    }

    // MARK: - Presets Section

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: VaporwaveSpacing.md) {
            HStack {
                Text("Presets")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(VaporwaveColors.textSecondary)

                Spacer()

                Button(action: { showPresets.toggle() }) {
                    Text("View All")
                        .font(.system(size: 12))
                        .foregroundColor(VaporwaveColors.neonCyan)
                }
                .accessibilityLabel("View all presets")
            }

            HStack(spacing: VaporwaveSpacing.md) {
                presetButton("Biofeedback", icon: "heart.fill", color: VaporwaveColors.neonPink) {
                    nodeGraph = NodeGraph.createBiofeedbackChain()
                }

                presetButton("Healing", icon: "leaf.fill", color: VaporwaveColors.coherenceHigh) {
                    nodeGraph = NodeGraph.createHealingPreset()
                }

                presetButton("Energizing", icon: "bolt.fill", color: VaporwaveColors.coral) {
                    nodeGraph = NodeGraph.createEnergizingPreset()
                }
            }
        }
    }

    private func presetButton(_ title: String, icon: String, color: Color = VaporwaveColors.neonCyan, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: VaporwaveSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)

                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(VaporwaveColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, VaporwaveSpacing.lg)
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
                        nodeGraph = NodeGraph.createBiofeedbackChain()
                        showPresets = false
                    }

                    presetRow("Healing", description: "Deep reverb with gentle compression") {
                        nodeGraph = NodeGraph.createHealingPreset()
                        showPresets = false
                    }

                    presetRow("Energizing", description: "Bright filter with rhythmic delay") {
                        nodeGraph = NodeGraph.createEnergizingPreset()
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
            return VaporwaveColors.neonPurple
        } else if name.contains("reverb") {
            return VaporwaveColors.neonCyan
        } else if name.contains("delay") {
            return VaporwaveColors.coral
        } else if name.contains("compressor") {
            return VaporwaveColors.coherenceHigh
        } else {
            return VaporwaveColors.neonPink
        }
    }
}

// MARK: - Node Row

struct NodeRow: View {
    let node: EchoelmusicNode
    @ObservedObject var nodeGraph: NodeGraph
    let isSelected: Bool

    var body: some View {
        VStack(spacing: VaporwaveSpacing.md) {
            HStack(spacing: VaporwaveSpacing.md) {
                // Node icon
                Image(systemName: nodeIcon)
                    .font(.system(size: 18))
                    .foregroundColor(nodeColor)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(nodeColor.opacity(0.2))
                    )
                    .neonGlow(color: nodeColor, radius: 5)

                // Node info
                VStack(alignment: .leading, spacing: VaporwaveSpacing.xs) {
                    Text(node.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(VaporwaveColors.textPrimary)

                    Text(nodeDescription)
                        .font(.system(size: 11))
                        .foregroundColor(VaporwaveColors.textTertiary)
                }

                Spacer()

                // Delete button
                Button(action: {
                    nodeGraph.removeNode(node.id)
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(VaporwaveColors.coherenceLow.opacity(0.7))
                }
                .accessibilityLabel("Delete \(node.name)")
            }

            // Bio-reactive indicator
            if node.isBioReactive {
                HStack(spacing: VaporwaveSpacing.xs) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                        .foregroundColor(VaporwaveColors.neonPink)

                    Text("Bio-Reactive")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(VaporwaveColors.neonPink)

                    Spacer()
                }
            }
        }
        .padding(VaporwaveSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? VaporwaveColors.neonCyan.opacity(0.1) : Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? VaporwaveColors.neonCyan : Color.clear, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(node.name), \(nodeDescription)\(node.isBioReactive ? ", bio-reactive" : "")")
        .accessibilityHint(isSelected ? "Selected" : "Double tap to select")
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
            return VaporwaveColors.neonPurple
        } else if name.contains("reverb") {
            return VaporwaveColors.neonCyan
        } else if name.contains("delay") {
            return VaporwaveColors.coral
        } else if name.contains("compressor") {
            return VaporwaveColors.coherenceHigh
        } else {
            return VaporwaveColors.neonPink
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
