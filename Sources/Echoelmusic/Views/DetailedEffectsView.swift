import SwiftUI

/// Detailed Professional Effects Chain Builder UI
/// FULL USER CONTROL - Build custom effect chains
/// Drag & drop effects, reorder, configure parameters
/// NOT AI - USER builds every chain!
@MainActor
struct DetailedEffectsView: View {

    @ObservedObject var effectChainBuilder: EffectChainBuilder

    @State private var selectedChain: UUID?
    @State private var showAddChainDialog = false
    @State private var newChainName = ""
    @State private var showEffectLibrary = false

    var body: some View {
        HStack(spacing: 0) {
            // Chain List Sidebar
            chainListSidebar
                .frame(width: 200)

            Divider()

            // Chain Editor
            if let chainId = selectedChain,
               let chain = effectChainBuilder.chains.first(where: { $0.id == chainId }) {
                chainEditor(chain: chain)
            } else {
                emptyState
            }

            Divider()

            // Effect Library
            if showEffectLibrary {
                effectLibrarySidebar
                    .frame(width: 250)
            }
        }
    }

    // MARK: - Chain List Sidebar

    private var chainListSidebar: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Chains")
                    .font(.headline)

                Spacer()

                Button(action: { showAddChainDialog.toggle() }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.secondary.opacity(0.05))

            Divider()

            // Chain List
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(effectChainBuilder.chains) { chain in
                        ChainListItem(
                            chain: chain,
                            isSelected: selectedChain == chain.id
                        )
                        .onTapGesture {
                            selectedChain = chain.id
                        }
                        .contextMenu {
                            Button("Duplicate") {
                                effectChainBuilder.duplicateChain(id: chain.id)
                            }
                            Button("Delete", role: .destructive) {
                                effectChainBuilder.deleteChain(id: chain.id)
                                if selectedChain == chain.id {
                                    selectedChain = nil
                                }
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddChainDialog) {
            AddChainDialog(newChainName: $newChainName) {
                let chain = effectChainBuilder.createChain(name: newChainName)
                selectedChain = chain.id
                newChainName = ""
                showAddChainDialog = false
            }
        }
    }

    // MARK: - Chain Editor

    private func chainEditor(chain: EffectChainBuilder.EffectChain) -> some View {
        VStack(spacing: 0) {
            // Chain Header
            HStack {
                VStack(alignment: .leading) {
                    Text(chain.name)
                        .font(.title2)

                    Text("\(chain.effects.count) effects")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Routing Mode
                Picker("Routing", selection: Binding(
                    get: { chain.routing },
                    set: { routing in
                        effectChainBuilder.setRouting(chainId: chain.id, routing: routing)
                    }
                )) {
                    Text("Series").tag(EffectChainBuilder.RoutingMode.series)
                    Text("Parallel").tag(EffectChainBuilder.RoutingMode.parallel)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                // Wet/Dry Mix
                HStack {
                    Text("Mix")
                        .font(.caption)
                    Slider(
                        value: Binding(
                            get: { chain.wetDryMix },
                            set: { mix in
                                effectChainBuilder.setWetDryMix(chainId: chain.id, mix: mix)
                            }
                        ),
                        in: 0...1
                    )
                    .frame(width: 100)
                    Text(String(format: "%.0f%%", chain.wetDryMix * 100))
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                // Toggle Library
                Button(action: { showEffectLibrary.toggle() }) {
                    Image(systemName: showEffectLibrary ? "sidebar.right" : "sidebar.left")
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.secondary.opacity(0.05))

            Divider()

            // Effect Chain
            ScrollView {
                VStack(spacing: 12) {
                    if chain.effects.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "waveform.path")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)

                            Text("No effects in chain")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            Text("Add effects from the library")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button(action: { showEffectLibrary = true }) {
                                Label("Show Effect Library", systemImage: "plus.circle")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(60)
                    } else {
                        ForEach(chain.effects) { effect in
                            EffectPanel(
                                effect: effect,
                                chain: chain,
                                effectChainBuilder: effectChainBuilder
                            )
                        }
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Effect Library Sidebar

    private var effectLibrarySidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Effect Library")
                    .font(.headline)

                Spacer()

                Button(action: { showEffectLibrary = false }) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.secondary.opacity(0.05))

            Divider()

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(effectChainBuilder.effectLibrary) { effectDescriptor in
                        EffectLibraryItem(descriptor: effectDescriptor)
                            .onTapGesture {
                                if let chainId = selectedChain {
                                    addEffectToChain(chainId: chainId, effectType: effectDescriptor.name)
                                }
                            }
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("No Chain Selected")
                .font(.title2)
                .foregroundColor(.secondary)

            Text("Select a chain from the sidebar or create a new one")
                .font(.caption)
                .foregroundColor(.secondary)

            Button(action: { showAddChainDialog.toggle() }) {
                Label("Create New Chain", systemImage: "plus.circle")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func addEffectToChain(chainId: UUID, effectType: String) {
        // Map effect name to EffectType
        let effect: EffectChainBuilder.EffectType

        switch effectType {
        case "Reverb":
            effect = .reverb(EffectChainBuilder.ReverbParams(roomSize: 0.5, damping: 0.5, wetLevel: 0.3, dryLevel: 0.7, width: 1.0))
        case "Delay":
            effect = .delay(EffectChainBuilder.DelayParams(delayTime: 0.5, feedback: 0.3, wetLevel: 0.5, dryLevel: 0.5, syncToTempo: false, tempoMultiplier: .quarter))
        case "Chorus":
            effect = .chorus(EffectChainBuilder.ChorusParams(rate: 1.0, depth: 0.5, feedback: 0.2, wetLevel: 0.5, dryLevel: 0.5))
        case "Compressor":
            effect = .compressor(EffectChainBuilder.CompressorParams(threshold: -20, ratio: 4.0, attack: 0.01, release: 0.1, makeupGain: 0))
        case "Distortion":
            effect = .distortion(EffectChainBuilder.DistortionParams(drive: 20, tone: 0.5, wetLevel: 1.0, dryLevel: 0.0, type: .overdrive))
        default:
            DebugConsole.shared.warning("Unknown effect type: \(effectType)", category: "Effects")
            return
        }

        effectChainBuilder.addEffect(to: chainId, effect: effect)
        DebugConsole.shared.info("Added \(effectType) to chain", category: "Effects")
    }
}

// MARK: - Chain List Item

struct ChainListItem: View {
    let chain: EffectChainBuilder.EffectChain
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(chain.name)
                .font(.callout)

            HStack {
                Image(systemName: "sparkles")
                    .font(.caption2)
                Text("\(chain.effects.count)")
                    .font(.caption2)

                Spacer()

                Text(routingText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(isSelected ? Color.blue.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
    }

    private var routingText: String {
        switch chain.routing {
        case .series: return "Series"
        case .parallel: return "Parallel"
        case .splitter: return "Split"
        }
    }
}

// MARK: - Effect Panel

struct EffectPanel: View {
    let effect: EffectChainBuilder.EffectInstance
    let chain: EffectChainBuilder.EffectChain
    @ObservedObject var effectChainBuilder: EffectChainBuilder

    var body: some View {
        GroupBox {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Image(systemName: effectIcon)
                        .foregroundColor(effect.enabled ? .blue : .secondary)

                    Text(effectName)
                        .font(.headline)

                    Spacer()

                    // Enable Toggle
                    Toggle("", isOn: Binding(
                        get: { effect.enabled },
                        set: { _ in
                            effectChainBuilder.toggleEffect(chainId: chain.id, effectId: effect.id)
                        }
                    ))
                    .toggleStyle(.switch)

                    // Delete Button
                    Button(action: {
                        effectChainBuilder.removeEffect(from: chain.id, effectId: effect.id)
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }

                if effect.enabled {
                    Divider()

                    // Effect Parameters
                    effectParameters
                }
            }
            .padding()
        }
    }

    private var effectName: String {
        switch effect.effect {
        case .reverb: return "Reverb"
        case .delay: return "Delay"
        case .chorus: return "Chorus"
        case .flanger: return "Flanger"
        case .phaser: return "Phaser"
        case .distortion: return "Distortion"
        case .bitcrusher: return "Bitcrusher"
        case .compressor: return "Compressor"
        case .limiter: return "Limiter"
        case .eq: return "EQ"
        case .filter: return "Filter"
        case .tremolo: return "Tremolo"
        case .vibrato: return "Vibrato"
        case .ringModulator: return "Ring Modulator"
        case .waveshaper: return "Waveshaper"
        case .stereoWidth: return "Stereo Width"
        case .panning: return "Panning"
        case .gating: return "Gate"
        }
    }

    private var effectIcon: String {
        switch effect.effect {
        case .reverb: return "speaker.wave.3"
        case .delay: return "arrow.triangle.2.circlepath"
        case .chorus, .flanger, .phaser: return "waveform.path"
        case .distortion, .bitcrusher: return "waveform.path.ecg"
        case .compressor, .limiter, .gating: return "chart.bar"
        case .eq, .filter: return "slider.horizontal.3"
        case .tremolo, .vibrato: return "waveform"
        case .ringModulator, .waveshaper: return "waveform.path.badge.minus"
        case .stereoWidth, .panning: return "speaker.wave.2"
        }
    }

    @ViewBuilder
    private var effectParameters: some View {
        switch effect.effect {
        case .reverb(let params):
            ReverbParametersView(params: params)

        case .delay(let params):
            DelayParametersView(params: params)

        case .compressor(let params):
            CompressorParametersView(params: params)

        case .distortion(let params):
            DistortionParametersView(params: params)

        default:
            Text("Parameters UI coming soon...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Effect Parameters Views

struct ReverbParametersView: View {
    let params: EffectChainBuilder.ReverbParams

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Room Size")
                    .font(.caption)
                Spacer()
                Text(String(format: "%.2f", params.roomSize))
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            HStack {
                Text("Damping")
                    .font(.caption)
                Spacer()
                Text(String(format: "%.2f", params.damping))
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            HStack {
                Text("Wet")
                    .font(.caption)
                Spacer()
                Text(String(format: "%.2f", params.wetLevel))
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
    }
}

struct DelayParametersView: View {
    let params: EffectChainBuilder.DelayParams

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Time")
                    .font(.caption)
                Spacer()
                Text(String(format: "%.3f s", params.delayTime))
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            HStack {
                Text("Feedback")
                    .font(.caption)
                Spacer()
                Text(String(format: "%.2f", params.feedback))
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            if params.syncToTempo {
                HStack {
                    Text("Tempo Sync")
                        .font(.caption)
                    Spacer()
                    Text(params.tempoMultiplier.rawValue)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

struct CompressorParametersView: View {
    let params: EffectChainBuilder.CompressorParams

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Threshold")
                    .font(.caption)
                Spacer()
                Text(String(format: "%.1f dB", params.threshold))
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            HStack {
                Text("Ratio")
                    .font(.caption)
                Spacer()
                Text(String(format: "%.1f:1", params.ratio))
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            HStack {
                Text("Attack")
                    .font(.caption)
                Spacer()
                Text(String(format: "%.3f s", params.attack))
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            HStack {
                Text("Release")
                    .font(.caption)
                Spacer()
                Text(String(format: "%.3f s", params.release))
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
    }
}

struct DistortionParametersView: View {
    let params: EffectChainBuilder.DistortionParams

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Drive")
                    .font(.caption)
                Spacer()
                Text(String(format: "%.1f", params.drive))
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            HStack {
                Text("Tone")
                    .font(.caption)
                Spacer()
                Text(String(format: "%.2f", params.tone))
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            HStack {
                Text("Type")
                    .font(.caption)
                Spacer()
                Text(params.type.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
    }
}

// MARK: - Effect Library Item

struct EffectLibraryItem: View {
    let descriptor: EffectChainBuilder.EffectDescriptor

    var body: some View {
        HStack {
            Image(systemName: "waveform.path")
                .foregroundColor(.blue)

            VStack(alignment: .leading) {
                Text(descriptor.name)
                    .font(.callout)

                Text(descriptor.category)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "plus.circle")
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Add Chain Dialog

struct AddChainDialog: View {
    @Binding var newChainName: String
    let onCreate: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("New Effect Chain")
                .font(.headline)

            TextField("Chain Name", text: $newChainName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    dismiss()
                }

                Button("Create") {
                    onCreate()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newChainName.isEmpty)
            }
        }
        .padding()
        .frame(width: 300, height: 150)
    }
}
