import SwiftUI

/// AI Composition View
///
/// User interface for AI-powered audio generation and composition.
///
/// Features:
/// - Text-to-audio generation
/// - Style transfer
/// - Beat generation
/// - Melody generation
/// - Smart mixing assistant
/// - Source separation
/// - Audio upscaling
/// - AI noise reduction
@available(iOS 15.0, *)
struct AICompositionView: View {

    @ObservedObject var ai = AICompositionEngine.shared
    @State private var selectedFeature: AIFeature = .textToAudio
    @State private var textPrompt = ""
    @State private var selectedStyle: AICompositionEngine.AudioStyle = .ambient
    @State private var duration: Double = 30.0
    @State private var bpm: Float = 120.0
    @State private var isGenerating = false
    @State private var showingModelDownload = false

    enum AIFeature: String, CaseIterable {
        case textToAudio = "Text-to-Audio"
        case styleTransfer = "Style Transfer"
        case beatGeneration = "Beat Generation"
        case melodyGeneration = "Melody Generation"
        case smartMixing = "Smart Mixing"
        case sourceSeparation = "Source Separation"
        case audioUpscaling = "Audio Upscaling"
        case noiseReduction = "Noise Reduction"

        var icon: String {
            switch self {
            case .textToAudio: return "text.bubble"
            case .styleTransfer: return "paintbrush"
            case .beatGeneration: return "waveform.path.ecg"
            case .melodyGeneration: return "music.note"
            case .smartMixing: return "slider.horizontal.3"
            case .sourceSeparation: return "arrow.triangle.branch"
            case .audioUpscaling: return "arrow.up.forward"
            case .noiseReduction: return "waveform.path.badge.minus"
            }
        }
    }

    var body: some View {
        Form {
            // Model Status
            Section {
                modelStatusCard
            }

            // Feature Selection
            Section {
                Picker("AI Feature", selection: $selectedFeature) {
                    ForEach(AIFeature.allCases, id: \.self) { feature in
                        Label(feature.rawValue, systemImage: feature.icon)
                            .tag(feature)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("Select Feature")
            }

            // Feature-specific controls
            featureControls

            // Generation button
            Section {
                Button(action: generate) {
                    HStack {
                        Spacer()
                        if isGenerating {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Generating...")
                        } else {
                            Label("Generate", systemImage: "wand.and.stars")
                        }
                        Spacer()
                    }
                }
                .disabled(isGenerating || !ai.isModelLoaded)

                if isGenerating {
                    ProgressView(value: ai.generationProgress)
                        .progressViewStyle(.linear)

                    if let task = ai.currentTask {
                        Text(taskDescription(task))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Model info
            Section {
                modelInfoView
            } header: {
                Text("Model Information")
            }
        }
        .navigationTitle("AI Composition")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingModelDownload) {
            ModelDownloadView()
        }
    }

    // MARK: - Model Status Card

    private var modelStatusCard: some View {
        HStack(spacing: 16) {
            Image(systemName: ai.isModelLoaded ? "brain" : "brain.head.profile")
                .font(.largeTitle)
                .foregroundColor(ai.isModelLoaded ? .green : .gray)

            VStack(alignment: .leading, spacing: 4) {
                Text(ai.isModelLoaded ? "AI Ready" : "Models Not Loaded")
                    .font(.headline)

                Text(ai.isModelLoaded ? "All features available" : "Download models to use AI features")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !ai.isModelLoaded {
                Button("Download") {
                    showingModelDownload = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Feature Controls

    @ViewBuilder
    private var featureControls: some View {
        switch selectedFeature {
        case .textToAudio:
            textToAudioControls
        case .styleTransfer:
            styleTransferControls
        case .beatGeneration:
            beatGenerationControls
        case .melodyGeneration:
            melodyGenerationControls
        case .smartMixing:
            smartMixingControls
        case .sourceSeparation:
            sourceSeparationControls
        case .audioUpscaling:
            audioUpscalingControls
        case .noiseReduction:
            noiseReductionControls
        }
    }

    private var textToAudioControls: some View {
        Section {
            TextField("Describe the audio you want...", text: $textPrompt, axis: .vertical)
                .lineLimit(3...6)

            Picker("Style", selection: $selectedStyle) {
                ForEach(AICompositionEngine.AudioStyle.allCases, id: \.self) { style in
                    Text(style.rawValue).tag(style)
                }
            }

            HStack {
                Text("Duration")
                Spacer()
                Text("\(Int(duration))s")
                    .foregroundColor(.secondary)
            }
            Slider(value: $duration, in: 5...300, step: 5)
        } header: {
            Text("Parameters")
        } footer: {
            Text("Example: \"Relaxing ambient music with piano and soft strings\"")
        }
    }

    private var styleTransferControls: some View {
        Section {
            Picker("Target Style", selection: $selectedStyle) {
                ForEach(AICompositionEngine.AudioStyle.allCases, id: \.self) { style in
                    Text(style.rawValue).tag(style)
                }
            }

            Button("Select Audio File") {
                // Open file picker
            }
        } header: {
            Text("Style Transfer")
        } footer: {
            Text("Transform your audio into a different musical style")
        }
    }

    private var beatGenerationControls: some View {
        Section {
            HStack {
                Text("BPM")
                Spacer()
                Text("\(Int(bpm))")
                    .foregroundColor(.secondary)
            }
            Slider(value: $bpm, in: 60...200, step: 1)

            Picker("Genre", selection: .constant(AICompositionEngine.BeatGenre.hiphop)) {
                ForEach(AICompositionEngine.BeatGenre.allCases, id: \.self) { genre in
                    Text(genre.rawValue).tag(genre)
                }
            }

            HStack {
                Text("Duration")
                Spacer()
                Text("\(Int(duration))s")
                    .foregroundColor(.secondary)
            }
            Slider(value: $duration, in: 5...60, step: 5)
        } header: {
            Text("Beat Parameters")
        }
    }

    private var melodyGenerationControls: some View {
        Section {
            Picker("Key", selection: .constant(AICompositionEngine.MusicalKey.cMajor)) {
                ForEach(AICompositionEngine.MusicalKey.allCases, id: \.self) { key in
                    Text(key.rawValue).tag(key)
                }
            }

            TextField("Chord Progression (e.g., C Am F G)", text: $textPrompt)

            HStack {
                Text("Duration")
                Spacer()
                Text("\(Int(duration))s")
                    .foregroundColor(.secondary)
            }
            Slider(value: $duration, in: 5...120, step: 5)
        } header: {
            Text("Melody Parameters")
        }
    }

    private var smartMixingControls: some View {
        Section {
            Button("Analyze Current Mix") {
                // Analyze mix
            }

            Text("AI will analyze your mix and provide suggestions for:")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("• EQ adjustments")
                Text("• Compression settings")
                Text("• Panning recommendations")
                Text("• Level balancing")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        } header: {
            Text("Smart Mixing Assistant")
        }
    }

    private var sourceSeparationControls: some View {
        Section {
            Button("Select Audio File") {
                // Open file picker
            }

            Text("Separate audio into:")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Label("Vocals", systemImage: "mic")
                Label("Drums", systemImage: "music.note")
                Label("Bass", systemImage: "waveform")
                Label("Other instruments", systemImage: "guitars")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        } header: {
            Text("Source Separation")
        } footer: {
            Text("Uses AI to isolate different instruments and vocals")
        }
    }

    private var audioUpscalingControls: some View {
        Section {
            Button("Select Audio File") {
                // Open file picker
            }

            Picker("Target Quality", selection: .constant(96000.0)) {
                Text("44.1 kHz → 48 kHz").tag(48000.0)
                Text("44.1 kHz → 96 kHz").tag(96000.0)
                Text("48 kHz → 96 kHz").tag(96000.0)
            }
        } header: {
            Text("Audio Upscaling")
        } footer: {
            Text("AI-powered upsampling for better audio quality")
        }
    }

    private var noiseReductionControls: some View {
        Section {
            Button("Select Audio File") {
                // Open file picker
            }

            HStack {
                Text("Aggressiveness")
                Spacer()
                Text("50%")
                    .foregroundColor(.secondary)
            }
            Slider(value: .constant(0.5), in: 0...1)
        } header: {
            Text("AI Noise Reduction")
        } footer: {
            Text("Advanced noise reduction while preserving audio quality")
        }
    }

    // MARK: - Model Info

    private var modelInfoView: some View {
        let info = ai.getModelInfo()

        return Group {
            HStack {
                Text("Status")
                Spacer()
                Text(info.isLoaded ? "Loaded" : "Not Loaded")
                    .foregroundColor(info.isLoaded ? .green : .secondary)
            }

            HStack {
                Text("Quality")
                Spacer()
                Text(info.quality)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Compute Units")
                Spacer()
                Text(info.computeUnits)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Model Size")
                Spacer()
                Text(info.modelSize)
                    .foregroundColor(.secondary)
            }

            NavigationLink("Capabilities") {
                CapabilitiesView(capabilities: info.capabilities)
            }
        }
    }

    // MARK: - Actions

    private func generate() {
        isGenerating = true

        Task {
            do {
                switch selectedFeature {
                case .textToAudio:
                    _ = try await ai.generateAudio(
                        prompt: textPrompt,
                        duration: duration,
                        style: selectedStyle
                    )
                case .beatGeneration:
                    _ = try await ai.generateBeat(
                        bpm: bpm,
                        duration: duration,
                        genre: .hiphop
                    )
                // ... other features
                default:
                    break
                }

                print("Generation complete!")
            } catch {
                print("Generation failed: \(error)")
            }

            isGenerating = false
        }
    }

    private func taskDescription(_ task: AICompositionEngine.GenerationTask) -> String {
        switch task.type {
        case .textToAudio: return "Generating audio from text..."
        case .styleTransfer: return "Applying style transfer..."
        case .beatGeneration: return "Generating beat pattern..."
        case .melodyGeneration: return "Generating melody..."
        case .audioUpscaling: return "Upscaling audio quality..."
        case .noiseReduction: return "Reducing noise..."
        case .sourceSeparation: return "Separating audio sources..."
        }
    }
}

// MARK: - Model Download View

@available(iOS 15.0, *)
struct ModelDownloadView: View {
    @Environment(\.dismiss) var dismiss
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0.0

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)

                Text("Download AI Models")
                    .font(.title)
                    .fontWeight(.bold)

                Text("BLAB uses advanced AI models for audio generation. The models are approximately 500MB.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding()

                if isDownloading {
                    VStack {
                        ProgressView(value: downloadProgress)
                        Text("\(Int(downloadProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    Button("Download Models") {
                        downloadModels()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("AI Models")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isDownloading)
                }
            }
        }
    }

    private func downloadModels() {
        isDownloading = true

        Task {
            do {
                try await AICompositionEngine.shared.downloadModels()
                dismiss()
            } catch {
                print("Download failed: \(error)")
                isDownloading = false
            }
        }
    }
}

// MARK: - Capabilities View

@available(iOS 15.0, *)
struct CapabilitiesView: View {
    let capabilities: [String]

    var body: some View {
        List(capabilities, id: \.self) { capability in
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(capability)
            }
        }
        .navigationTitle("AI Capabilities")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

@available(iOS 15.0, *)
struct AICompositionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AICompositionView()
        }
    }
}
