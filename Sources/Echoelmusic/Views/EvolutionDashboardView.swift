import SwiftUI

// MARK: - Evolution Dashboard View
// Monitor and control the self-evolving thermodynamic system

public struct EvolutionDashboardView: View {
    @StateObject private var evolutionEngine = ThermodynamicEvolutionEngine.shared
    @StateObject private var runtimeOptimizer = AdaptiveRuntimeOptimizer.shared

    @State private var showDetailedMetrics = false
    @State private var showGenomeEditor = false

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // System status
                    systemStatusCard

                    // Energy landscape
                    energyLandscapeCard

                    // Runtime profile
                    runtimeProfileCard

                    // Active optimizations
                    activeOptimizationsSection

                    // Genome visualization
                    genomeSection

                    // History graph
                    historySection
                }
                .padding()
            }
            .navigationTitle("System Evolution")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: { evolutionEngine.forceMutation() }) {
                            Label("Force Mutation", systemImage: "bolt")
                        }
                        Button(action: { evolutionEngine.resetToDefault() }) {
                            Label("Reset to Default", systemImage: "arrow.counterclockwise")
                        }
                        Divider()
                        Button(action: { showGenomeEditor = true }) {
                            Label("Edit Genome", systemImage: "slider.horizontal.3")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showGenomeEditor) {
                GenomeEditorView(engine: evolutionEngine)
            }
        }
    }

    // MARK: - System Status Card

    private var systemStatusCard: some View {
        HStack {
            // Evolution status
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle()
                        .fill(evolutionEngine.isEvolving ? Color.green : Color.gray)
                        .frame(width: 10, height: 10)

                    Text(evolutionEngine.isEvolving ? "Evolving" : "Paused")
                        .font(.headline)
                }

                Text("Generation \(evolutionEngine.generationCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Toggle
            Button(action: toggleEvolution) {
                Image(systemName: evolutionEngine.isEvolving ? "pause.fill" : "play.fill")
                    .padding()
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Energy Landscape

    private var energyLandscapeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Energy Landscape")
                .font(.headline)

            HStack(spacing: 24) {
                // Current energy
                VStack {
                    ZStack {
                        Circle()
                            .stroke(energyColor(evolutionEngine.currentEnergy), lineWidth: 8)
                            .frame(width: 80, height: 80)

                        VStack(spacing: 2) {
                            Text(String(format: "%.2f", evolutionEngine.currentEnergy))
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Energy")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Temperature
                VStack {
                    ZStack {
                        Circle()
                            .stroke(temperatureColor(evolutionEngine.temperature), lineWidth: 8)
                            .frame(width: 80, height: 80)

                        VStack(spacing: 2) {
                            Text(String(format: "%.3f", evolutionEngine.temperature))
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Temp")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // Explanation
                VStack(alignment: .leading, spacing: 4) {
                    Text("Lower energy = better")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("System cooling over time")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Optimal state approached")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Runtime Profile

    private var runtimeProfileCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Runtime Profile")
                    .font(.headline)

                Spacer()

                Text(runtimeOptimizer.currentProfile.rawValue)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(profileColor(runtimeOptimizer.currentProfile))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }

            // Environment indicators
            HStack(spacing: 16) {
                EnvironmentIndicator(
                    icon: "battery.100",
                    label: "Battery",
                    value: String(format: "%.0f%%", runtimeOptimizer.environmentState.batteryLevel * 100)
                )

                EnvironmentIndicator(
                    icon: "thermometer",
                    label: "Thermal",
                    value: runtimeOptimizer.environmentState.thermalState.rawValue.capitalized
                )

                EnvironmentIndicator(
                    icon: "wifi",
                    label: "Network",
                    value: runtimeOptimizer.environmentState.networkQuality.rawValue.capitalized
                )

                EnvironmentIndicator(
                    icon: "waveform",
                    label: "Audio Load",
                    value: String(format: "%.0f%%", runtimeOptimizer.environmentState.audioLoad * 100)
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Active Optimizations

    private var activeOptimizationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Active Optimizations")
                    .font(.headline)

                Spacer()

                Text("\(runtimeOptimizer.activeOptimizations.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }

            if runtimeOptimizer.activeOptimizations.isEmpty {
                Text("No active optimizations")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(Array(runtimeOptimizer.activeOptimizations), id: \.rawValue) { opt in
                        OptimizationBadge(optimization: opt)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Genome Section

    private var genomeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Current Genome")
                    .font(.headline)

                Spacer()

                Button("Edit") {
                    showGenomeEditor = true
                }
                .font(.subheadline)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(Array(evolutionEngine.activeGenomes.first?.genes.prefix(6) ?? [:]), id: \.key) { key, value in
                    GeneCard(name: key, value: value)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Evolution History")
                .font(.headline)

            // Simple energy graph
            GeometryReader { geometry in
                Path { path in
                    let records = evolutionEngine.optimizationHistory.suffix(50)
                    guard !records.isEmpty else { return }

                    let width = geometry.size.width
                    let height = geometry.size.height

                    let maxEnergy = records.map { $0.energy }.max() ?? 1
                    let minEnergy = records.map { $0.energy }.min() ?? 0
                    let energyRange = maxEnergy - minEnergy

                    path.move(to: CGPoint(x: 0, y: height))

                    for (index, record) in records.enumerated() {
                        let x = CGFloat(index) / CGFloat(records.count) * width
                        let normalizedEnergy = energyRange > 0 ? (record.energy - minEnergy) / energyRange : 0.5
                        let y = height - (normalizedEnergy * height)

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.accentColor, lineWidth: 2)
            }
            .frame(height: 100)
            .background(Color.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                Text("Adaptations: \(runtimeOptimizer.adaptationCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("Generations: \(evolutionEngine.generationCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Actions

    private func toggleEvolution() {
        if evolutionEngine.isEvolving {
            evolutionEngine.pauseEvolution()
        } else {
            evolutionEngine.startEvolution()
        }
    }

    // MARK: - Helpers

    private func energyColor(_ energy: Double) -> Color {
        if energy < 0.3 { return .green }
        if energy < 0.6 { return .yellow }
        return .orange
    }

    private func temperatureColor(_ temp: Double) -> Color {
        if temp < 0.1 { return .blue }
        if temp < 0.5 { return .cyan }
        return .orange
    }

    private func profileColor(_ profile: RuntimeProfile) -> Color {
        switch profile {
        case .performance: return .green
        case .balanced: return .blue
        case .powerSaver: return .orange
        case .minimal: return .red
        case .background: return .gray
        }
    }
}

// MARK: - Supporting Views

struct EnvironmentIndicator: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct OptimizationBadge: View {
    let optimization: OptimizationType

    var body: some View {
        Text(optimization.rawValue)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(badgeColor.opacity(0.2))
            .foregroundStyle(badgeColor)
            .clipShape(Capsule())
    }

    private var badgeColor: Color {
        switch optimization {
        case .reducedVisuals: return .purple
        case .reducedAI: return .blue
        case .reducedProcessing: return .orange
        case .aggressiveCaching: return .green
        case .aggressiveCompression: return .cyan
        case .reducedSync: return .yellow
        case .deferredOperations: return .pink
        case .lazyLoading: return .mint
        case .prioritizeAudio: return .red
        }
    }
}

struct GeneCard: View {
    let name: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formatGeneName(name))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                ProgressView(value: value, total: 1.0)
                    .tint(geneColor(value))

                Text(String(format: "%.2f", value))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 40)
            }
        }
        .padding()
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formatGeneName(_ name: String) -> String {
        name.replacingOccurrences(of: ".", with: " › ").capitalized
    }

    private func geneColor(_ value: Double) -> Color {
        if value < 0.3 { return .red }
        if value < 0.7 { return .yellow }
        return .green
    }
}

struct GenomeEditorView: View {
    @ObservedObject var engine: ThermodynamicEvolutionEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(ParameterCategory.allCases, id: \.rawValue) { category in
                    Section(category.rawValue) {
                        ForEach(genesForCategory(category), id: \.key) { key, value in
                            VStack(alignment: .leading) {
                                Text(formatGeneName(key))
                                    .font(.subheadline)

                                Slider(value: .constant(value), in: 0...1)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Genome Editor")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func genesForCategory(_ category: ParameterCategory) -> [(key: String, value: Double)] {
        let prefix = category.rawValue.lowercased()
        return engine.activeGenomes.first?.genes
            .filter { $0.key.hasPrefix(prefix) }
            .map { (key: $0.key, value: $0.value) } ?? []
    }

    private func formatGeneName(_ name: String) -> String {
        name.components(separatedBy: ".").last?.capitalized ?? name
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

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
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

#Preview {
    EvolutionDashboardView()
}
