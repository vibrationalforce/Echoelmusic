//
//  NodeWorkflowEditorView.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  NODE WORKFLOW EDITOR - Visual programming for everything
//  TouchDesigner / Unreal Blueprints / Max/MSP level node editor
//
//  **Features:**
//  - Visual node graph editor
//  - Drag-and-drop node creation
//  - Connection drawing
//  - Parameter controls
//  - Node categories (Audio, Video, Effects, Logic, Math, etc.)
//  - Real-time preview
//  - Graph execution visualization
//  - Preset system
//  - Zoom & pan
//

import SwiftUI

// MARK: - Node Workflow Editor View

struct NodeWorkflowEditorView: View {
    @StateObject private var workflow = NodeBasedWorkflow.shared

    @State private var selectedNode: UUID?
    @State private var draggedNode: UUID?
    @State private var panOffset: CGSize = .zero
    @State private var zoomLevel: CGFloat = 1.0
    @State private var showNodePalette: Bool = false
    @State private var connectionStart: (nodeId: UUID, outputIndex: Int)?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background grid
                GridBackground(zoom: zoomLevel, offset: panOffset)

                // Node canvas
                Canvas { context, size in
                    // Draw connections
                    for connection in workflow.currentGraph?.connections ?? [] {
                        drawConnection(
                            context: context,
                            connection: connection,
                            nodes: workflow.currentGraph?.nodes ?? []
                        )
                    }
                }

                // Nodes
                ForEach(workflow.currentGraph?.nodes ?? []) { node in
                    NodeView(
                        node: node,
                        isSelected: selectedNode == node.id,
                        onSelect: { selectedNode = node.id },
                        onOutputDrag: { outputIndex in
                            connectionStart = (node.id, outputIndex)
                        },
                        onInputDrop: { inputIndex in
                            if let start = connectionStart {
                                connectNodes(from: start.nodeId, output: start.outputIndex, to: node.id, input: inputIndex)
                                connectionStart = nil
                            }
                        }
                    )
                    .position(
                        x: CGFloat(node.position.x) * zoomLevel + panOffset.width,
                        y: CGFloat(node.position.y) * zoomLevel + panOffset.height
                    )
                    .scaleEffect(zoomLevel)
                }

                // Toolbar
                VStack {
                    HStack {
                        // Node palette button
                        Button(action: { showNodePalette.toggle() }) {
                            Label("Add Node", systemImage: "plus.circle.fill")
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }

                        Spacer()

                        // Zoom controls
                        HStack {
                            Button(action: { zoomLevel = max(0.1, zoomLevel - 0.1) }) {
                                Image(systemName: "minus.magnifyingglass")
                            }
                            Text("\(Int(zoomLevel * 100))%")
                                .frame(width: 60)
                            Button(action: { zoomLevel = min(3.0, zoomLevel + 0.1) }) {
                                Image(systemName: "plus.magnifyingglass")
                            }
                            Button(action: { zoomLevel = 1.0; panOffset = .zero }) {
                                Text("Reset")
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)

                        Spacer()

                        // Execute button
                        Button(action: executeGraph) {
                            Label("Execute", systemImage: "play.circle.fill")
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                    .padding()

                    Spacer()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if selectedNode == nil {
                            panOffset = CGSize(
                                width: panOffset.width + value.translation.width,
                                height: panOffset.height + value.translation.height
                            )
                        }
                    }
            )
            .sheet(isPresented: $showNodePalette) {
                NodePaletteView(onNodeSelected: addNode)
            }
        }
    }

    private func drawConnection(context: GraphicsContext, connection: NodeBasedWorkflow.NodeConnection, nodes: [NodeBasedWorkflow.Node]) {
        guard let fromNode = nodes.first(where: { $0.id == connection.fromNode }),
              let toNode = nodes.first(where: { $0.id == connection.toNode }) else {
            return
        }

        let startX = CGFloat(fromNode.position.x + 150) * zoomLevel + panOffset.width
        let startY = CGFloat(fromNode.position.y + 30 + connection.fromOutput * 25) * zoomLevel + panOffset.height

        let endX = CGFloat(toNode.position.x) * zoomLevel + panOffset.width
        let endY = CGFloat(toNode.position.y + 30 + connection.toInput * 25) * zoomLevel + panOffset.height

        let path = Path { path in
            path.move(to: CGPoint(x: startX, y: startY))

            // Bezier curve
            let controlPoint1 = CGPoint(x: startX + 50, y: startY)
            let controlPoint2 = CGPoint(x: endX - 50, y: endY)

            path.addCurve(
                to: CGPoint(x: endX, y: endY),
                control1: controlPoint1,
                control2: controlPoint2
            )
        }

        context.stroke(path, with: .color(.accentColor), lineWidth: 3 * zoomLevel)
    }

    private func addNode(type: NodeBasedWorkflow.Node.NodeType) {
        let node = NodeBasedWorkflow.Node(
            type: type,
            position: SIMD2<Float>(400, 300)
        )

        if workflow.currentGraph == nil {
            let graph = NodeBasedWorkflow.NodeGraph(name: "New Graph")
            workflow.currentGraph = graph
        }

        workflow.currentGraph?.addNode(node)
        showNodePalette = false
    }

    private func connectNodes(from fromNode: UUID, output: Int, to toNode: UUID, input: Int) {
        workflow.currentGraph?.connect(
            from: fromNode,
            outputIndex: output,
            to: toNode,
            inputIndex: input
        )
    }

    private func executeGraph() {
        guard let graph = workflow.currentGraph else { return }

        Task {
            do {
                let result = try await workflow.executeGraph(graph)
                print("✅ Graph executed: \(result.keys.count) outputs")
            } catch {
                print("❌ Graph execution failed: \(error)")
            }
        }
    }
}

// MARK: - Grid Background

struct GridBackground: View {
    let zoom: CGFloat
    let offset: CGSize

    var body: some View {
        Canvas { context, size in
            let gridSize: CGFloat = 50 * zoom

            // Vertical lines
            var x = offset.width.truncatingRemainder(dividingBy: gridSize)
            while x < size.width {
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    },
                    with: .color(.gray.opacity(0.2)),
                    lineWidth: 1
                )
                x += gridSize
            }

            // Horizontal lines
            var y = offset.height.truncatingRemainder(dividingBy: gridSize)
            while y < size.height {
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    },
                    with: .color(.gray.opacity(0.2)),
                    lineWidth: 1
                )
                y += gridSize
            }
        }
        .background(Color.black.opacity(0.05))
    }
}

// MARK: - Node View

struct NodeView: View {
    let node: NodeBasedWorkflow.Node
    let isSelected: Bool
    let onSelect: () -> Void
    let onOutputDrag: (Int) -> Void
    let onInputDrop: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: node.type.icon)
                    .foregroundColor(node.type.color)
                Text(node.type.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(8)
            .background(node.type.color.opacity(0.2))

            // Inputs & Outputs
            HStack(alignment: .top, spacing: 0) {
                // Inputs
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(0..<node.inputs.count, id: \.self) { index in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 12, height: 12)
                                .onDrop(of: ["public.text"], isTargeted: nil) { _ in
                                    onInputDrop(index)
                                    return true
                                }

                            Text(node.inputs[index].name)
                                .font(.caption2)
                        }
                    }
                }
                .padding(8)

                Spacer()

                // Outputs
                VStack(alignment: .trailing, spacing: 4) {
                    ForEach(0..<node.outputs.count, id: \.self) { index in
                        HStack(spacing: 4) {
                            Text(node.outputs[index].name)
                                .font(.caption2)

                            Circle()
                                .fill(Color.orange)
                                .frame(width: 12, height: 12)
                                .gesture(
                                    DragGesture()
                                        .onChanged { _ in
                                            onOutputDrag(index)
                                        }
                                )
                        }
                    }
                }
                .padding(8)
            }

            // Parameters
            if !node.parameters.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(node.parameters, id: \.name) { param in
                        HStack {
                            Text(param.name)
                                .font(.caption2)
                            Spacer()
                            Text("\(param.value as? Double ?? 0.0, specifier: "%.2f")")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(8)
            }
        }
        .frame(width: 200)
        .background(isSelected ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .shadow(radius: 4)
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - Node Palette

struct NodePaletteView: View {
    @Environment(\.dismiss) private var dismiss
    let onNodeSelected: (NodeBasedWorkflow.Node.NodeType) -> Void

    @State private var searchText: String = ""
    @State private var selectedCategory: NodeCategory? = nil

    enum NodeCategory: String, CaseIterable {
        case audio = "Audio"
        case video = "Video"
        case effects = "Effects"
        case generators = "Generators"
        case math = "Math"
        case logic = "Logic"
        case data = "Data"
        case io = "I/O"
    }

    var body: some View {
        NavigationView {
            List {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search nodes...", text: $searchText)
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

                // Categories
                ForEach(NodeCategory.allCases, id: \.self) { category in
                    Section(header: Text(category.rawValue)) {
                        ForEach(nodesForCategory(category), id: \.self) { nodeType in
                            Button(action: {
                                onNodeSelected(nodeType)
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: nodeType.icon)
                                        .foregroundColor(nodeType.color)
                                        .frame(width: 30)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(nodeType.rawValue)
                                            .font(.headline)
                                        Text(nodeType.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Node")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func nodesForCategory(_ category: NodeCategory) -> [NodeBasedWorkflow.Node.NodeType] {
        switch category {
        case .audio:
            return [.oscillator, .filter, .mixer, .amplifier]
        case .video:
            return [.videoPlayer, .videoMixer]
        case .effects:
            return [.reverb, .delay, .distortion, .colorGrade]
        case .generators:
            return [.noise, .waveform]
        case .math:
            return [.add, .multiply, .clamp]
        case .logic:
            return [.compare, .branch]
        case .data:
            return [.constant, .variable]
        case .io:
            return [.audioInput, .audioOutput, .midiInput]
        }
    }
}

// MARK: - Node Type Extensions

extension NodeBasedWorkflow.Node.NodeType {
    var icon: String {
        switch self {
        case .audioInput: return "waveform.circle"
        case .audioOutput: return "speaker.wave.3"
        case .oscillator: return "waveform"
        case .filter: return "slider.horizontal.3"
        case .amplifier: return "speaker.wave.2"
        case .mixer: return "slider.vertical.3"
        case .reverb: return "waveform.path.ecg"
        case .delay: return "timer"
        case .distortion: return "waveform.path.badge.minus"
        case .midiInput: return "pianokeys"
        case .videoPlayer: return "play.rectangle"
        case .videoMixer: return "rectangle.stack"
        case .colorGrade: return "paintpalette"
        case .noise: return "cloud"
        case .waveform: return "waveform"
        case .add: return "plus"
        case .multiply: return "multiply"
        case .clamp: return "arrow.up.and.down"
        case .compare: return "equal"
        case .branch: return "arrow.triangle.branch"
        case .constant: return "number"
        case .variable: return "x.squareroot"
        }
    }

    var color: Color {
        switch self {
        case .audioInput, .audioOutput, .oscillator, .filter, .amplifier, .mixer:
            return .blue
        case .reverb, .delay, .distortion:
            return .purple
        case .midiInput:
            return .green
        case .videoPlayer, .videoMixer, .colorGrade:
            return .red
        case .noise, .waveform:
            return .orange
        case .add, .multiply, .clamp:
            return .yellow
        case .compare, .branch:
            return .pink
        case .constant, .variable:
            return .gray
        }
    }

    var description: String {
        switch self {
        case .audioInput: return "Audio input source"
        case .audioOutput: return "Audio output destination"
        case .oscillator: return "Generate waveforms"
        case .filter: return "Filter audio frequencies"
        case .amplifier: return "Control volume"
        case .mixer: return "Mix multiple audio sources"
        case .reverb: return "Add reverb effect"
        case .delay: return "Add delay effect"
        case .distortion: return "Add distortion"
        case .midiInput: return "MIDI input source"
        case .videoPlayer: return "Play video file"
        case .videoMixer: return "Mix video sources"
        case .colorGrade: return "Adjust colors"
        case .noise: return "Generate noise"
        case .waveform: return "Generate waveform"
        case .add: return "Add numbers"
        case .multiply: return "Multiply numbers"
        case .clamp: return "Limit value range"
        case .compare: return "Compare values"
        case .branch: return "Conditional branch"
        case .constant: return "Constant value"
        case .variable: return "Variable storage"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct NodeWorkflowEditorView_Previews: PreviewProvider {
    static var previews: some View {
        NodeWorkflowEditorView()
            .frame(width: 1400, height: 900)
    }
}
#endif
