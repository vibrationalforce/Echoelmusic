import SwiftUI

// MARK: - Node Editor View
// TouchDesigner/DaVinci Resolve inspired node-based visual programming
// Full VaporwaveTheme Corporate Identity

struct NodeEditorView: View {
    @StateObject private var nodeEditor = NodeEditorViewModel()
    @State private var canvasOffset: CGSize = .zero
    @State private var canvasScale: CGFloat = 1.0
    @State private var showNodePalette = false
    @State private var selectedNode: VisualNode?
    @State private var isConnecting = false
    @State private var connectionStart: NodePort?
    @State private var dragLocation: CGPoint = .zero

    var body: some View {
        ZStack {
            VaporwaveGradients.background.ignoresSafeArea()

            // Canvas
            GeometryReader { geo in
                ZStack {
                    // Grid Background
                    NodeGridBackground()
                        .scaleEffect(canvasScale)
                        .offset(canvasOffset)

                    // Connections
                    ForEach(nodeEditor.connections) { connection in
                        ConnectionPath(
                            from: nodeEditor.portPosition(connection.fromPort),
                            to: nodeEditor.portPosition(connection.toPort),
                            color: connection.color,
                            scale: canvasScale,
                            offset: canvasOffset
                        )
                    }

                    // Active connection being drawn
                    if isConnecting, let start = connectionStart {
                        ConnectionPath(
                            from: nodeEditor.portPosition(start),
                            to: dragLocation,
                            color: start.isOutput ? VaporwaveColors.neonCyan : VaporwaveColors.neonPink,
                            scale: canvasScale,
                            offset: canvasOffset,
                            isDashed: true
                        )
                    }

                    // Nodes
                    ForEach(nodeEditor.nodes) { node in
                        NodeView(
                            node: node,
                            isSelected: selectedNode?.id == node.id,
                            onSelect: { selectedNode = node },
                            onMove: { nodeEditor.moveNode(node.id, by: $0) },
                            onStartConnect: { port in
                                connectionStart = port
                                isConnecting = true
                            },
                            onEndConnect: { port in
                                if let start = connectionStart {
                                    nodeEditor.connect(from: start, to: port)
                                }
                                isConnecting = false
                                connectionStart = nil
                            },
                            onDelete: { nodeEditor.deleteNode(node.id) }
                        )
                        .scaleEffect(canvasScale)
                        .offset(x: node.position.x * canvasScale + canvasOffset.width,
                                y: node.position.y * canvasScale + canvasOffset.height)
                    }
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if isConnecting {
                                dragLocation = value.location
                            } else if selectedNode == nil {
                                canvasOffset = CGSize(
                                    width: canvasOffset.width + value.translation.width,
                                    height: canvasOffset.height + value.translation.height
                                )
                            }
                        }
                        .onEnded { _ in
                            if isConnecting {
                                isConnecting = false
                                connectionStart = nil
                            }
                        }
                )
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            canvasScale = max(0.5, min(2.0, value))
                        }
                )
                .onTapGesture {
                    selectedNode = nil
                }
            }

            // UI Overlay
            VStack {
                // Header
                headerView

                Spacer()

                // Bottom Toolbar
                bottomToolbar
            }

            // Node Palette
            if showNodePalette {
                NodePaletteSheet(isPresented: $showNodePalette) { type in
                    nodeEditor.addNode(type: type, at: CGPoint(x: 200, y: 200))
                }
            }

            // Inspector Panel
            if let node = selectedNode {
                HStack {
                    Spacer()
                    NodeInspectorPanel(node: node, onUpdate: { nodeEditor.updateNode($0) })
                        .frame(width: 280)
                }
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: VaporwaveSpacing.xs) {
                Text("NODE EDITOR")
                    .font(VaporwaveTypography.sectionTitle())
                    .foregroundColor(VaporwaveColors.textPrimary)

                Text("\(nodeEditor.nodes.count) Nodes • \(nodeEditor.connections.count) Connections")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.neonCyan)
            }

            Spacer()

            // Processing Status
            HStack(spacing: VaporwaveSpacing.sm) {
                VaporwaveStatusIndicator(isActive: nodeEditor.isProcessing, activeColor: VaporwaveColors.coherenceHigh)
                Text(nodeEditor.isProcessing ? "Processing" : "Idle")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textSecondary)
            }
            .padding(.horizontal, VaporwaveSpacing.md)
            .padding(.vertical, VaporwaveSpacing.sm)
            .glassCard()

            // Play/Stop
            Button(action: { nodeEditor.toggleProcessing() }) {
                Image(systemName: nodeEditor.isProcessing ? "stop.fill" : "play.fill")
                    .font(.system(size: 20))
                    .foregroundColor(nodeEditor.isProcessing ? VaporwaveColors.neonPink : VaporwaveColors.neonCyan)
            }
            .neonGlow(color: nodeEditor.isProcessing ? VaporwaveColors.neonPink : VaporwaveColors.neonCyan, radius: 8)
        }
        .padding(VaporwaveSpacing.md)
        .background(VaporwaveColors.deepBlack.opacity(0.8))
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: VaporwaveSpacing.md) {
            // Add Node
            Button(action: { showNodePalette = true }) {
                HStack(spacing: VaporwaveSpacing.sm) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Node")
                }
                .font(VaporwaveTypography.caption())
                .foregroundColor(VaporwaveColors.neonCyan)
            }
            .padding(.horizontal, VaporwaveSpacing.md)
            .padding(.vertical, VaporwaveSpacing.sm)
            .glassCard()

            Spacer()

            // Zoom Controls
            HStack(spacing: VaporwaveSpacing.sm) {
                Button(action: { canvasScale = max(0.5, canvasScale - 0.1) }) {
                    Image(systemName: "minus.magnifyingglass")
                        .foregroundColor(VaporwaveColors.textSecondary)
                }

                Text("\(Int(canvasScale * 100))%")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textSecondary)
                    .frame(width: 50)

                Button(action: { canvasScale = min(2.0, canvasScale + 0.1) }) {
                    Image(systemName: "plus.magnifyingglass")
                        .foregroundColor(VaporwaveColors.textSecondary)
                }

                Button(action: { canvasScale = 1.0; canvasOffset = .zero }) {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(VaporwaveColors.textTertiary)
                }
            }
            .padding(.horizontal, VaporwaveSpacing.md)
            .padding(.vertical, VaporwaveSpacing.sm)
            .glassCard()

            // Bio Sync Toggle
            Button(action: { nodeEditor.bioSyncEnabled.toggle() }) {
                HStack(spacing: VaporwaveSpacing.sm) {
                    Image(systemName: "heart.fill")
                    Text("Bio Sync")
                }
                .font(VaporwaveTypography.caption())
                .foregroundColor(nodeEditor.bioSyncEnabled ? VaporwaveColors.neonPink : VaporwaveColors.textTertiary)
            }
            .padding(.horizontal, VaporwaveSpacing.md)
            .padding(.vertical, VaporwaveSpacing.sm)
            .background(nodeEditor.bioSyncEnabled ? VaporwaveColors.neonPink.opacity(0.2) : Color.clear)
            .glassCard()
        }
        .padding(VaporwaveSpacing.md)
        .background(VaporwaveColors.deepBlack.opacity(0.8))
    }
}

// MARK: - Node View

struct NodeView: View {
    let node: VisualNode
    let isSelected: Bool
    let onSelect: () -> Void
    let onMove: (CGSize) -> Void
    let onStartConnect: (NodePort) -> Void
    let onEndConnect: (NodePort) -> Void
    let onDelete: () -> Void

    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: node.type.icon)
                    .font(.system(size: 12))
                    .foregroundColor(node.type.color)

                Text(node.name)
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textPrimary)
                    .lineLimit(1)

                Spacer()

                if isSelected {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(VaporwaveColors.textTertiary)
                    }
                }
            }
            .padding(.horizontal, VaporwaveSpacing.sm)
            .padding(.vertical, VaporwaveSpacing.xs)
            .background(node.type.color.opacity(0.3))

            // Body
            HStack(alignment: .top, spacing: 0) {
                // Input Ports
                VStack(spacing: VaporwaveSpacing.sm) {
                    ForEach(node.inputs) { port in
                        PortView(port: port, isInput: true)
                            .onTapGesture { onEndConnect(port) }
                    }
                }
                .frame(width: 20)

                Spacer()

                // Preview/Content
                if node.showPreview {
                    NodePreviewContent(node: node)
                        .frame(width: 80, height: 50)
                }

                Spacer()

                // Output Ports
                VStack(spacing: VaporwaveSpacing.sm) {
                    ForEach(node.outputs) { port in
                        PortView(port: port, isInput: false)
                            .gesture(
                                DragGesture(minimumDistance: 5)
                                    .onChanged { _ in onStartConnect(port) }
                            )
                    }
                }
                .frame(width: 20)
            }
            .padding(.vertical, VaporwaveSpacing.sm)

            // Parameter Preview
            if !node.parameters.isEmpty && isSelected {
                Divider()
                    .background(VaporwaveColors.textTertiary.opacity(0.3))

                VStack(spacing: 4) {
                    ForEach(node.parameters.prefix(3), id: \.name) { param in
                        HStack {
                            Text(param.name)
                                .font(VaporwaveTypography.label())
                                .foregroundColor(VaporwaveColors.textTertiary)
                            Spacer()
                            Text(String(format: "%.1f", param.value))
                                .font(VaporwaveTypography.label())
                                .foregroundColor(VaporwaveColors.neonCyan)
                        }
                    }
                }
                .padding(VaporwaveSpacing.sm)
            }
        }
        .frame(width: node.showPreview ? 140 : 120)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(VaporwaveColors.deepBlack.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? node.type.color : VaporwaveColors.textTertiary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: isSelected ? node.type.color.opacity(0.5) : .clear, radius: 10)
        .onTapGesture { onSelect() }
        .gesture(
            DragGesture()
                .onChanged { value in
                    onMove(value.translation)
                    isDragging = true
                }
                .onEnded { _ in isDragging = false }
        )
    }
}

struct PortView: View {
    let port: NodePort
    let isInput: Bool

    var body: some View {
        HStack(spacing: 4) {
            if !isInput {
                Text(port.name)
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)
            }

            Circle()
                .fill(port.isConnected ? port.dataType.color : VaporwaveColors.deepBlack)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(port.dataType.color, lineWidth: 1)
                )

            if isInput {
                Text(port.name)
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)
            }
        }
    }
}

struct NodePreviewContent: View {
    let node: VisualNode

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(VaporwaveColors.deepBlack)

            switch node.type {
            case .generator:
                // Waveform preview
                WaveformPreview()
            case .filter:
                // Filter curve
                FilterCurvePreview()
            case .visualizer:
                // Visual preview
                VisualizerPreview()
            case .output:
                // Output meters
                OutputMeterPreview()
            default:
                Image(systemName: node.type.icon)
                    .foregroundColor(node.type.color.opacity(0.5))
            }
        }
    }
}

struct WaveformPreview: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let width = geo.size.width
                let height = geo.size.height
                let midY = height / 2

                path.move(to: CGPoint(x: 0, y: midY))
                for x in stride(from: 0, to: width, by: 2) {
                    let y = midY + sin(x * 0.2) * (height * 0.3)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(VaporwaveColors.neonCyan, lineWidth: 1)
        }
    }
}

struct FilterCurvePreview: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let width = geo.size.width
                let height = geo.size.height

                path.move(to: CGPoint(x: 0, y: height * 0.2))
                path.addCurve(
                    to: CGPoint(x: width, y: height * 0.8),
                    control1: CGPoint(x: width * 0.3, y: height * 0.2),
                    control2: CGPoint(x: width * 0.7, y: height * 0.8)
                )
            }
            .stroke(VaporwaveColors.neonPink, lineWidth: 1)
        }
    }
}

struct VisualizerPreview: View {
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<8, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(VaporwaveColors.neonPurple)
                    .frame(width: 4, height: CGFloat.random(in: 10...40))
            }
        }
    }
}

struct OutputMeterPreview: View {
    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(VaporwaveColors.coherenceHigh)
                .frame(width: 8)
            RoundedRectangle(cornerRadius: 2)
                .fill(VaporwaveColors.coherenceHigh)
                .frame(width: 8)
        }
        .padding(4)
    }
}

// MARK: - Connection Path

struct ConnectionPath: View {
    let from: CGPoint
    let to: CGPoint
    let color: Color
    let scale: CGFloat
    let offset: CGSize
    var isDashed: Bool = false

    var body: some View {
        Path { path in
            let startX = from.x * scale + offset.width
            let startY = from.y * scale + offset.height
            let endX = to.x * scale + offset.width
            let endY = to.y * scale + offset.height

            let controlOffset = abs(endX - startX) * 0.5

            path.move(to: CGPoint(x: startX, y: startY))
            path.addCurve(
                to: CGPoint(x: endX, y: endY),
                control1: CGPoint(x: startX + controlOffset, y: startY),
                control2: CGPoint(x: endX - controlOffset, y: endY)
            )
        }
        .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: isDashed ? [5, 5] : []))
    }
}

// MARK: - Grid Background

struct NodeGridBackground: View {
    var body: some View {
        Canvas { context, size in
            let gridSpacing: CGFloat = 30
            let dotSize: CGFloat = 2

            for x in stride(from: 0, to: size.width, by: gridSpacing) {
                for y in stride(from: 0, to: size.height, by: gridSpacing) {
                    let rect = CGRect(x: x - dotSize/2, y: y - dotSize/2, width: dotSize, height: dotSize)
                    context.fill(Ellipse().path(in: rect), with: .color(VaporwaveColors.textTertiary.opacity(0.2)))
                }
            }
        }
    }
}

// MARK: - Node Palette

struct NodePaletteSheet: View {
    @Binding var isPresented: Bool
    let onSelect: (NodeType) -> Void

    let categories: [(String, [NodeType])] = [
        ("Generators", [.generator, .oscillator, .noise, .bioInput]),
        ("Processors", [.filter, .mixer, .math, .transform]),
        ("Effects", [.reverb, .delay, .distortion, .modulator]),
        ("Visuals", [.visualizer, .shader, .particles, .geometry]),
        ("Output", [.output, .midiOut, .oscOut, .dmxOut])
    ]

    var body: some View {
        ZStack {
            VaporwaveGradients.background.ignoresSafeArea()

            VStack(spacing: VaporwaveSpacing.md) {
                HStack {
                    Text("ADD NODE")
                        .font(VaporwaveTypography.sectionTitle())
                        .foregroundColor(VaporwaveColors.textPrimary)

                    Spacer()

                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(VaporwaveColors.textSecondary)
                    }
                }
                .padding(VaporwaveSpacing.md)

                ScrollView {
                    VStack(spacing: VaporwaveSpacing.lg) {
                        ForEach(categories, id: \.0) { category, types in
                            VStack(alignment: .leading, spacing: VaporwaveSpacing.sm) {
                                VaporwaveSectionHeader(category, icon: nil)

                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: VaporwaveSpacing.sm) {
                                    ForEach(types, id: \.self) { type in
                                        NodeTypeCard(type: type) {
                                            onSelect(type)
                                            isPresented = false
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(VaporwaveSpacing.md)
                }
            }
        }
    }
}

struct NodeTypeCard: View {
    let type: NodeType
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: type.icon)
                    .font(.system(size: 20))
                    .foregroundColor(type.color)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.name)
                        .font(VaporwaveTypography.caption())
                        .foregroundColor(VaporwaveColors.textPrimary)

                    Text(type.description)
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(VaporwaveSpacing.sm)
            .glassCard()
        }
    }
}

// MARK: - Node Inspector Panel

struct NodeInspectorPanel: View {
    let node: VisualNode
    let onUpdate: (VisualNode) -> Void
    @State private var editedNode: VisualNode

    init(node: VisualNode, onUpdate: @escaping (VisualNode) -> Void) {
        self.node = node
        self.onUpdate = onUpdate
        self._editedNode = State(initialValue: node)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: node.type.icon)
                    .foregroundColor(node.type.color)

                Text(node.name)
                    .font(VaporwaveTypography.body())
                    .foregroundColor(VaporwaveColors.textPrimary)

                Spacer()
            }
            .padding(VaporwaveSpacing.md)
            .background(node.type.color.opacity(0.2))

            ScrollView {
                VStack(spacing: VaporwaveSpacing.md) {
                    // Parameters
                    VaporwaveSectionHeader("PARAMETERS", icon: "slider.horizontal.3")

                    ForEach(editedNode.parameters.indices, id: \.self) { index in
                        ParameterSlider(
                            parameter: $editedNode.parameters[index],
                            onChanged: { onUpdate(editedNode) }
                        )
                    }

                    // Inputs
                    if !node.inputs.isEmpty {
                        VaporwaveSectionHeader("INPUTS", icon: "arrow.down.circle")
                            .padding(.top, VaporwaveSpacing.md)

                        ForEach(node.inputs) { port in
                            PortInfoRow(port: port, isInput: true)
                        }
                    }

                    // Outputs
                    if !node.outputs.isEmpty {
                        VaporwaveSectionHeader("OUTPUTS", icon: "arrow.up.circle")
                            .padding(.top, VaporwaveSpacing.md)

                        ForEach(node.outputs) { port in
                            PortInfoRow(port: port, isInput: false)
                        }
                    }

                    // Bio Modulation
                    VaporwaveSectionHeader("BIO MODULATION", icon: "heart.fill")
                        .padding(.top, VaporwaveSpacing.md)

                    ForEach(editedNode.parameters.indices, id: \.self) { index in
                        BioModulationRow(parameter: $editedNode.parameters[index])
                    }
                }
                .padding(VaporwaveSpacing.md)
            }
        }
        .background(VaporwaveColors.deepBlack.opacity(0.95))
        .overlay(
            Rectangle()
                .fill(node.type.color)
                .frame(width: 3),
            alignment: .leading
        )
    }
}

struct ParameterSlider: View {
    @Binding var parameter: NodeParameter
    let onChanged: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: VaporwaveSpacing.xs) {
            HStack {
                Text(parameter.name)
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textSecondary)

                Spacer()

                Text(String(format: "%.2f", parameter.value))
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.neonCyan)
            }

            Slider(value: $parameter.value, in: parameter.min...parameter.max)
                .accentColor(VaporwaveColors.neonCyan)
                .onChange(of: parameter.value) { _, _ in onChanged() }
        }
        .padding(VaporwaveSpacing.sm)
        .glassCard()
    }
}

struct PortInfoRow: View {
    let port: NodePort
    let isInput: Bool

    var body: some View {
        HStack {
            Circle()
                .fill(port.dataType.color)
                .frame(width: 8, height: 8)

            Text(port.name)
                .font(VaporwaveTypography.caption())
                .foregroundColor(VaporwaveColors.textSecondary)

            Spacer()

            Text(port.dataType.rawValue)
                .font(VaporwaveTypography.label())
                .foregroundColor(VaporwaveColors.textTertiary)

            if port.isConnected {
                Image(systemName: "link")
                    .font(.system(size: 10))
                    .foregroundColor(VaporwaveColors.coherenceHigh)
            }
        }
        .padding(VaporwaveSpacing.sm)
        .glassCard()
    }
}

struct BioModulationRow: View {
    @Binding var parameter: NodeParameter

    var body: some View {
        HStack {
            Text(parameter.name)
                .font(VaporwaveTypography.caption())
                .foregroundColor(VaporwaveColors.textSecondary)

            Spacer()

            Picker("Source", selection: $parameter.bioSource) {
                Text("None").tag(BioSource?.none)
                Text("HR").tag(BioSource?.some(.heartRate))
                Text("HRV").tag(BioSource?.some(.hrv))
                Text("Coherence").tag(BioSource?.some(.coherence))
                Text("Breath").tag(BioSource?.some(.breathing))
            }
            .pickerStyle(.menu)
            .font(VaporwaveTypography.label())
        }
        .padding(VaporwaveSpacing.sm)
        .glassCard()
    }
}

// MARK: - Models

@MainActor
class NodeEditorViewModel: ObservableObject {
    @Published var nodes: [VisualNode] = []
    @Published var connections: [NodeConnection] = []
    @Published var isProcessing = false
    @Published var bioSyncEnabled = true

    init() {
        // Sample nodes
        nodes = [
            VisualNode(
                id: UUID(),
                name: "Bio Input",
                type: .bioInput,
                position: CGPoint(x: 50, y: 100),
                inputs: [],
                outputs: [
                    NodePort(id: UUID(), name: "HR", dataType: .float, isOutput: true),
                    NodePort(id: UUID(), name: "HRV", dataType: .float, isOutput: true),
                    NodePort(id: UUID(), name: "Coh", dataType: .float, isOutput: true)
                ],
                parameters: []
            ),
            VisualNode(
                id: UUID(),
                name: "Filter",
                type: .filter,
                position: CGPoint(x: 250, y: 100),
                inputs: [
                    NodePort(id: UUID(), name: "In", dataType: .audio, isOutput: false),
                    NodePort(id: UUID(), name: "Mod", dataType: .float, isOutput: false)
                ],
                outputs: [
                    NodePort(id: UUID(), name: "Out", dataType: .audio, isOutput: true)
                ],
                parameters: [
                    NodeParameter(name: "Cutoff", value: 0.5, min: 0, max: 1),
                    NodeParameter(name: "Resonance", value: 0.3, min: 0, max: 1)
                ]
            ),
            VisualNode(
                id: UUID(),
                name: "Visualizer",
                type: .visualizer,
                position: CGPoint(x: 450, y: 100),
                inputs: [
                    NodePort(id: UUID(), name: "Audio", dataType: .audio, isOutput: false),
                    NodePort(id: UUID(), name: "Color", dataType: .color, isOutput: false)
                ],
                outputs: [
                    NodePort(id: UUID(), name: "Video", dataType: .video, isOutput: true)
                ],
                parameters: [
                    NodeParameter(name: "Intensity", value: 0.7, min: 0, max: 1),
                    NodeParameter(name: "Speed", value: 0.5, min: 0, max: 1)
                ],
                showPreview: true
            )
        ]
    }

    func addNode(type: NodeType, at position: CGPoint) {
        let node = VisualNode(
            id: UUID(),
            name: type.name,
            type: type,
            position: position,
            inputs: type.defaultInputs,
            outputs: type.defaultOutputs,
            parameters: type.defaultParameters
        )
        nodes.append(node)
    }

    func deleteNode(_ id: UUID) {
        connections.removeAll { $0.fromNode == id || $0.toNode == id }
        nodes.removeAll { $0.id == id }
    }

    func moveNode(_ id: UUID, by offset: CGSize) {
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            nodes[index].position.x += offset.width
            nodes[index].position.y += offset.height
        }
    }

    func connect(from: NodePort, to: NodePort) {
        guard from.isOutput && !to.isOutput else { return }
        guard from.dataType == to.dataType || from.dataType == .float else { return }

        let connection = NodeConnection(
            id: UUID(),
            fromNode: nodes.first { $0.outputs.contains { $0.id == from.id } }?.id ?? UUID(),
            fromPort: from,
            toNode: nodes.first { $0.inputs.contains { $0.id == to.id } }?.id ?? UUID(),
            toPort: to,
            color: from.dataType.color
        )
        connections.append(connection)
    }

    func portPosition(_ port: NodePort) -> CGPoint {
        for node in nodes {
            if let index = node.outputs.firstIndex(where: { $0.id == port.id }) {
                return CGPoint(x: node.position.x + 120, y: node.position.y + 50 + CGFloat(index) * 20)
            }
            if let index = node.inputs.firstIndex(where: { $0.id == port.id }) {
                return CGPoint(x: node.position.x, y: node.position.y + 50 + CGFloat(index) * 20)
            }
        }
        return .zero
    }

    func updateNode(_ node: VisualNode) {
        if let index = nodes.firstIndex(where: { $0.id == node.id }) {
            nodes[index] = node
        }
    }

    func toggleProcessing() { isProcessing.toggle() }
}

struct VisualNode: Identifiable {
    let id: UUID
    var name: String
    var type: NodeType
    var position: CGPoint
    var inputs: [NodePort]
    var outputs: [NodePort]
    var parameters: [NodeParameter]
    var showPreview: Bool = false
}

struct NodePort: Identifiable {
    let id: UUID
    var name: String
    var dataType: DataType
    var isOutput: Bool
    var isConnected: Bool = false
}

struct NodeParameter: Identifiable {
    let id = UUID()
    var name: String
    var value: Float
    var min: Float
    var max: Float
    var bioSource: BioSource? = nil
}

struct NodeConnection: Identifiable {
    let id: UUID
    let fromNode: UUID
    let fromPort: NodePort
    let toNode: UUID
    let toPort: NodePort
    let color: Color
}

enum NodeType: String, CaseIterable {
    case generator, oscillator, noise, bioInput
    case filter, mixer, math, transform
    case reverb, delay, distortion, modulator
    case visualizer, shader, particles, geometry
    case output, midiOut, oscOut, dmxOut

    var name: String {
        switch self {
        case .generator: return "Generator"
        case .oscillator: return "Oscillator"
        case .noise: return "Noise"
        case .bioInput: return "Bio Input"
        case .filter: return "Filter"
        case .mixer: return "Mixer"
        case .math: return "Math"
        case .transform: return "Transform"
        case .reverb: return "Reverb"
        case .delay: return "Delay"
        case .distortion: return "Distortion"
        case .modulator: return "Modulator"
        case .visualizer: return "Visualizer"
        case .shader: return "Shader"
        case .particles: return "Particles"
        case .geometry: return "Geometry"
        case .output: return "Audio Out"
        case .midiOut: return "MIDI Out"
        case .oscOut: return "OSC Out"
        case .dmxOut: return "DMX Out"
        }
    }

    var description: String {
        switch self {
        case .generator: return "Audio signal source"
        case .oscillator: return "Waveform generator"
        case .noise: return "Noise generator"
        case .bioInput: return "Biometric data"
        case .filter: return "Frequency filter"
        case .mixer: return "Signal mixer"
        case .math: return "Math operations"
        case .transform: return "Transform data"
        case .reverb: return "Reverb effect"
        case .delay: return "Delay effect"
        case .distortion: return "Distortion"
        case .modulator: return "LFO/Envelope"
        case .visualizer: return "Visual output"
        case .shader: return "Custom shader"
        case .particles: return "Particle system"
        case .geometry: return "3D geometry"
        case .output: return "Audio output"
        case .midiOut: return "MIDI output"
        case .oscOut: return "OSC output"
        case .dmxOut: return "DMX/Art-Net"
        }
    }

    var icon: String {
        switch self {
        case .generator, .oscillator: return "waveform"
        case .noise: return "waveform.path.ecg"
        case .bioInput: return "heart.fill"
        case .filter: return "slider.horizontal.3"
        case .mixer: return "slider.vertical.3"
        case .math: return "function"
        case .transform: return "arrow.triangle.branch"
        case .reverb: return "wave.3.right"
        case .delay: return "clock.arrow.2.circlepath"
        case .distortion: return "bolt.fill"
        case .modulator: return "waveform.circle"
        case .visualizer: return "eye"
        case .shader: return "paintbrush"
        case .particles: return "sparkles"
        case .geometry: return "cube"
        case .output: return "speaker.wave.3"
        case .midiOut: return "pianokeys"
        case .oscOut: return "antenna.radiowaves.left.and.right"
        case .dmxOut: return "light.max"
        }
    }

    var color: Color {
        switch self {
        case .generator, .oscillator, .noise: return VaporwaveColors.neonCyan
        case .bioInput: return VaporwaveColors.neonPink
        case .filter, .mixer, .math, .transform: return VaporwaveColors.neonPurple
        case .reverb, .delay, .distortion, .modulator: return VaporwaveColors.coral
        case .visualizer, .shader, .particles, .geometry: return VaporwaveColors.lavender
        case .output, .midiOut, .oscOut, .dmxOut: return VaporwaveColors.coherenceHigh
        }
    }

    var defaultInputs: [NodePort] {
        switch self {
        case .bioInput: return []
        case .filter: return [NodePort(id: UUID(), name: "In", dataType: .audio, isOutput: false), NodePort(id: UUID(), name: "Mod", dataType: .float, isOutput: false)]
        case .visualizer: return [NodePort(id: UUID(), name: "Audio", dataType: .audio, isOutput: false)]
        case .output: return [NodePort(id: UUID(), name: "L", dataType: .audio, isOutput: false), NodePort(id: UUID(), name: "R", dataType: .audio, isOutput: false)]
        default: return [NodePort(id: UUID(), name: "In", dataType: .audio, isOutput: false)]
        }
    }

    var defaultOutputs: [NodePort] {
        switch self {
        case .bioInput: return [NodePort(id: UUID(), name: "HR", dataType: .float, isOutput: true), NodePort(id: UUID(), name: "HRV", dataType: .float, isOutput: true), NodePort(id: UUID(), name: "Coh", dataType: .float, isOutput: true)]
        case .visualizer: return [NodePort(id: UUID(), name: "Video", dataType: .video, isOutput: true)]
        case .output: return []
        default: return [NodePort(id: UUID(), name: "Out", dataType: .audio, isOutput: true)]
        }
    }

    var defaultParameters: [NodeParameter] {
        switch self {
        case .filter: return [NodeParameter(name: "Cutoff", value: 0.5, min: 0, max: 1), NodeParameter(name: "Resonance", value: 0.3, min: 0, max: 1)]
        case .reverb: return [NodeParameter(name: "Size", value: 0.5, min: 0, max: 1), NodeParameter(name: "Decay", value: 0.5, min: 0, max: 1), NodeParameter(name: "Mix", value: 0.3, min: 0, max: 1)]
        case .delay: return [NodeParameter(name: "Time", value: 0.3, min: 0, max: 1), NodeParameter(name: "Feedback", value: 0.4, min: 0, max: 1)]
        case .visualizer: return [NodeParameter(name: "Intensity", value: 0.7, min: 0, max: 1), NodeParameter(name: "Speed", value: 0.5, min: 0, max: 1)]
        default: return []
        }
    }
}

enum DataType: String {
    case audio = "Audio"
    case float = "Float"
    case color = "Color"
    case video = "Video"
    case midi = "MIDI"

    var color: Color {
        switch self {
        case .audio: return VaporwaveColors.neonCyan
        case .float: return VaporwaveColors.coherenceMedium
        case .color: return VaporwaveColors.neonPurple
        case .video: return VaporwaveColors.neonPink
        case .midi: return VaporwaveColors.coral
        }
    }
}

enum BioSource {
    case heartRate, hrv, coherence, breathing, gsr
}

#Preview {
    NodeEditorView()
}
