import SwiftUI

// MARK: - Neural Stem Separator View
// AI-powered audio stem separation interface

public struct StemSeparatorView: View {
    @StateObject private var separator = NeuralStemSeparatorEngine()

    @State private var inputURL: URL?
    @State private var isProcessing = false
    @State private var progress: Double = 0
    @State private var separatedStems: [StemTrack] = []
    @State private var selectedModel: SeparationModel = .htDemucs
    @State private var showExportOptions = false

    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Input section
                inputSection

                // Model selection
                modelSelection

                // Progress
                if isProcessing {
                    processingView
                }

                // Results
                if !separatedStems.isEmpty {
                    stemsResultView
                }

                Spacer()

                // Actions
                actionButtons
            }
            .padding()
            .navigationTitle("Stem Separator")
            .sheet(isPresented: $showExportOptions) {
                ExportOptionsView(stems: separatedStems)
            }
        }
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(spacing: 16) {
            if let url = inputURL {
                // File loaded
                HStack {
                    Image(systemName: "music.note")
                        .font(.title)
                        .foregroundStyle(.accentColor)

                    VStack(alignment: .leading) {
                        Text(url.lastPathComponent)
                            .font(.headline)
                        Text("Ready for separation")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(action: { inputURL = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                // Drop zone
                DropZoneView { url in
                    inputURL = url
                }
            }
        }
    }

    // MARK: - Model Selection

    private var modelSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Separation Model")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(SeparationModel.allCases, id: \.self) { model in
                    ModelCard(
                        model: model,
                        isSelected: selectedModel == model
                    ) {
                        selectedModel = model
                    }
                }
            }
        }
    }

    // MARK: - Processing View

    private var processingView: some View {
        VStack(spacing: 16) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)

            HStack {
                Image(systemName: "brain")
                    .symbolEffect(.pulse)

                Text("Separating stems...")
                    .font(.subheadline)

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // GPU usage
            HStack {
                Label("GPU", systemImage: "gpu")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(separator.gpuUsage)%")
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Stems Result

    private var stemsResultView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Separated Stems")
                    .font(.headline)

                Spacer()

                Button("Export All") {
                    showExportOptions = true
                }
                .font(.subheadline)
            }

            ForEach(separatedStems) { stem in
                StemTrackRow(stem: stem)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button(action: { /* Import */ }) {
                Label("Import Audio", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button(action: {
                Task { await separateStems() }
            }) {
                Label("Separate", systemImage: "waveform.badge.magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(inputURL == nil || isProcessing)
        }
    }

    // MARK: - Actions

    private func separateStems() async {
        guard let url = inputURL else { return }

        isProcessing = true
        progress = 0

        // Simulate separation
        for i in 0..<100 {
            try? await Task.sleep(nanoseconds: 50_000_000)
            progress = Double(i + 1) / 100
        }

        // Mock results
        separatedStems = [
            StemTrack(name: "Vocals", type: .vocals, color: .purple),
            StemTrack(name: "Drums", type: .drums, color: .orange),
            StemTrack(name: "Bass", type: .bass, color: .blue),
            StemTrack(name: "Other", type: .other, color: .green)
        ]

        isProcessing = false
    }
}

// MARK: - Supporting Views

struct DropZoneView: View {
    let onDrop: (URL) -> Void

    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 48))
                .foregroundStyle(isTargeted ? .accentColor : .secondary)

            Text("Drop audio file here")
                .font(.headline)

            Text("MP3, WAV, FLAC, M4A supported")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Browse Files") {
                // Open file picker
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, dash: [8])
                )
                .foregroundStyle(isTargeted ? Color.accentColor : Color(.systemGray4))
        )
        .onDrop(of: [.audio], isTargeted: $isTargeted) { providers in
            // Handle drop
            return true
        }
    }
}

struct ModelCard: View {
    let model: SeparationModel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: model.icon)
                        .font(.title2)
                        .foregroundStyle(model.color)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.accentColor)
                    }
                }

                Text(model.name)
                    .font(.headline)

                Text(model.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack {
                    Label("\(model.stems) stems", systemImage: "waveform")
                        .font(.caption2)

                    Spacer()

                    Text(model.quality)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(model.qualityColor.opacity(0.2))
                        .foregroundStyle(model.qualityColor)
                        .clipShape(Capsule())
                }
            }
            .padding()
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct StemTrackRow: View {
    let stem: StemTrack
    @State private var isMuted = false
    @State private var isSolo = false
    @State private var volume: Float = 1.0

    var body: some View {
        HStack(spacing: 12) {
            // Type indicator
            Circle()
                .fill(stem.color)
                .frame(width: 8, height: 8)

            // Name
            Text(stem.name)
                .font(.subheadline)
                .frame(width: 80, alignment: .leading)

            // Waveform preview
            WaveformPreview(color: stem.color)
                .frame(height: 32)

            // Controls
            HStack(spacing: 8) {
                Button(action: { isMuted.toggle() }) {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.fill")
                        .foregroundStyle(isMuted ? .red : .primary)
                }

                Button(action: { isSolo.toggle() }) {
                    Text("S")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(isSolo ? .yellow : .primary)
                }

                Slider(value: $volume, in: 0...1)
                    .frame(width: 80)

                Button(action: { /* Export stem */ }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct WaveformPreview: View {
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let midY = height / 2

                path.move(to: CGPoint(x: 0, y: midY))

                for x in stride(from: 0, through: width, by: 2) {
                    let amplitude = CGFloat.random(in: 0.2...0.8) * (height / 2)
                    path.addLine(to: CGPoint(x: x, y: midY - amplitude))
                    path.addLine(to: CGPoint(x: x, y: midY + amplitude))
                }
            }
            .stroke(color, lineWidth: 1)
        }
    }
}

struct ExportOptionsView: View {
    let stems: [StemTrack]
    @Environment(\.dismiss) private var dismiss

    @State private var exportFormat: ExportFormat = .wav
    @State private var exportQuality: ExportQuality = .high
    @State private var exportAll = true
    @State private var selectedStems: Set<String> = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Stems to Export") {
                    Toggle("Export All", isOn: $exportAll)

                    if !exportAll {
                        ForEach(stems) { stem in
                            Toggle(stem.name, isOn: Binding(
                                get: { selectedStems.contains(stem.name) },
                                set: { if $0 { selectedStems.insert(stem.name) } else { selectedStems.remove(stem.name) } }
                            ))
                        }
                    }
                }

                Section("Format") {
                    Picker("Format", selection: $exportFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Quality") {
                    Picker("Quality", selection: $exportQuality) {
                        ForEach(ExportQuality.allCases, id: \.self) { quality in
                            Text(quality.rawValue).tag(quality)
                        }
                    }
                }

                Section("Options") {
                    Toggle("Normalize levels", isOn: .constant(true))
                    Toggle("Apply dithering", isOn: .constant(false))
                    Toggle("Include metadata", isOn: .constant(true))
                }
            }
            .navigationTitle("Export Options")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Export") {
                        // Export
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Types

class NeuralStemSeparatorEngine: ObservableObject {
    @Published var gpuUsage: Int = 0
}

enum SeparationModel: String, CaseIterable {
    case htDemucs = "HT-Demucs"
    case demucs4 = "Demucs 4"
    case mdxNet = "MDX-Net"
    case spleeter = "Spleeter"

    var name: String { rawValue }

    var description: String {
        switch self {
        case .htDemucs: return "Hybrid Transformer, best quality"
        case .demucs4: return "Latest Demucs, balanced"
        case .mdxNet: return "Fast inference, good quality"
        case .spleeter: return "Classic, very fast"
        }
    }

    var icon: String {
        switch self {
        case .htDemucs: return "brain"
        case .demucs4: return "waveform.path.ecg"
        case .mdxNet: return "bolt"
        case .spleeter: return "hare"
        }
    }

    var color: Color {
        switch self {
        case .htDemucs: return .purple
        case .demucs4: return .blue
        case .mdxNet: return .orange
        case .spleeter: return .green
        }
    }

    var stems: Int {
        switch self {
        case .htDemucs: return 6
        case .demucs4: return 4
        case .mdxNet: return 4
        case .spleeter: return 5
        }
    }

    var quality: String {
        switch self {
        case .htDemucs: return "Best"
        case .demucs4: return "Great"
        case .mdxNet: return "Good"
        case .spleeter: return "Fast"
        }
    }

    var qualityColor: Color {
        switch self {
        case .htDemucs: return .purple
        case .demucs4: return .blue
        case .mdxNet: return .orange
        case .spleeter: return .green
        }
    }
}

struct StemTrack: Identifiable {
    let id = UUID()
    let name: String
    let type: StemType
    let color: Color
}

enum StemType {
    case vocals, drums, bass, other, piano, guitar
}

enum ExportFormat: String, CaseIterable {
    case wav = "WAV"
    case flac = "FLAC"
    case mp3 = "MP3"
    case aiff = "AIFF"
}

enum ExportQuality: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case lossless = "Lossless"
}

#Preview {
    StemSeparatorView()
}
