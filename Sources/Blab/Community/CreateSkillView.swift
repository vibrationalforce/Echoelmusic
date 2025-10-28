import SwiftUI

/// View for creating a new skill
struct CreateSkillView: View {
    @ObservedObject var repository: SkillsRepository
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var selectedType: SkillType = .sessionTemplate
    @State private var selectedCategory: SkillCategory = .meditation
    @State private var tags: [String] = []
    @State private var newTag = ""

    // Session Template specific
    @State private var duration: TimeInterval = 300
    @State private var brainwaveState: BinauralBeatGenerator.BrainwaveState = .alpha
    @State private var visualizationMode: VisualizationMode = .particles
    @State private var binauralFrequency: Float = 10.0
    @State private var includesBinaural = true
    @State private var includesHRV = true

    @State private var isCreating = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            Form {
                // Basic Info
                Section(header: Text("Basic Information")) {
                    TextField("Skill Name", text: $name)

                    TextEditor(text: $description)
                        .frame(height: 100)
                        .overlay(
                            Group {
                                if description.isEmpty {
                                    Text("Describe your skill...")
                                        .foregroundColor(.secondary)
                                        .padding(.top, 8)
                                        .padding(.leading, 5)
                                        .allowsHitTesting(false)
                                }
                            },
                            alignment: .topLeading
                        )
                }

                // Classification
                Section(header: Text("Classification")) {
                    Picker("Type", selection: $selectedType) {
                        ForEach(SkillType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.rawValue)
                            }
                            .tag(type)
                        }
                    }

                    Picker("Category", selection: $selectedCategory) {
                        ForEach(SkillCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                            }
                            .tag(category)
                        }
                    }
                }

                // Tags
                Section(header: Text("Tags")) {
                    HStack {
                        TextField("Add tag", text: $newTag)
                        Button(action: addTag) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                        .disabled(newTag.isEmpty)
                    }

                    if !tags.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                HStack(spacing: 4) {
                                    Text("#\(tag)")
                                        .font(.system(size: 13))
                                    Button(action: { removeTag(tag) }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 12))
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.blue.opacity(0.2)))
                                .foregroundColor(.blue)
                            }
                        }
                    }
                }

                // Type-specific settings
                if selectedType == .sessionTemplate {
                    sessionTemplateSection
                } else if selectedType == .binauralPreset {
                    binauralPresetSection
                }

                // Create Button
                Section {
                    Button(action: createSkill) {
                        HStack {
                            Spacer()
                            if isCreating {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            } else {
                                Text("Create Skill")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            Spacer()
                        }
                    }
                    .disabled(!isValid || isCreating)
                }
            }
            .navigationTitle("Create Skill")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Create") {
                    createSkill()
                }
                .disabled(!isValid || isCreating)
            )
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Session Template Section

    private var sessionTemplateSection: some View {
        Section(header: Text("Session Template Settings")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Duration: \(formatDuration(duration))")
                    .font(.system(size: 14))
                Slider(value: $duration, in: 60...3600, step: 60)
            }

            Picker("Brainwave State", selection: $brainwaveState) {
                ForEach(BinauralBeatGenerator.BrainwaveState.allCases, id: \.self) { state in
                    Text(state.rawValue.capitalized).tag(state)
                }
            }

            Picker("Visualization", selection: $visualizationMode) {
                ForEach(VisualizationMode.allCases, id: \.self) { mode in
                    HStack {
                        Image(systemName: mode.icon)
                        Text(mode.rawValue)
                    }
                    .tag(mode)
                }
            }

            if includesBinaural {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Binaural Frequency: \(String(format: "%.1f", binauralFrequency)) Hz")
                        .font(.system(size: 14))
                    Slider(value: $binauralFrequency, in: 0.5...40.0, step: 0.5)
                }
            }

            Toggle("Include Binaural Beats", isOn: $includesBinaural)
            Toggle("Include HRV Monitoring", isOn: $includesHRV)
        }
    }

    // MARK: - Binaural Preset Section

    private var binauralPresetSection: some View {
        Section(header: Text("Binaural Preset Settings")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Frequency: \(String(format: "%.1f", binauralFrequency)) Hz")
                    .font(.system(size: 14))
                Slider(value: $binauralFrequency, in: 0.5...40.0, step: 0.5)
            }

            Picker("Brainwave State", selection: $brainwaveState) {
                ForEach(BinauralBeatGenerator.BrainwaveState.allCases, id: \.self) { state in
                    Text(state.rawValue.capitalized).tag(state)
                }
            }
        }
    }

    // MARK: - Validation

    private var isValid: Bool {
        !name.isEmpty && !description.isEmpty
    }

    // MARK: - Actions

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        tags.append(trimmed)
        newTag = ""
    }

    private func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }

    private func createSkill() {
        isCreating = true

        Task {
            do {
                let content = createContent()

                let skill = UserSkill(
                    creatorID: "local_user",  // TODO: Get from auth
                    creatorName: "You",
                    name: name,
                    description: description,
                    type: selectedType,
                    category: selectedCategory,
                    tags: tags,
                    content: content
                )

                try await repository.createSkill(skill)

                await MainActor.run {
                    isCreating = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func createContent() -> SkillContent {
        switch selectedType {
        case .sessionTemplate:
            return .sessionTemplate(SessionTemplateSkill(
                duration: duration,
                brainwaveState: brainwaveState,
                visualizationMode: visualizationMode,
                binauralFrequency: binauralFrequency,
                includesBinaural: includesBinaural,
                includesHRV: includesHRV
            ))

        case .binauralPreset:
            return .binauralPreset(BinauralPresetSkill(
                carrierFrequency: 200.0,  // Default carrier
                beatFrequency: binauralFrequency,
                amplitude: 0.3,
                brainwaveState: brainwaveState,
                waveform: "sine"
            ))

        case .visualizationConfig:
            return .visualizationConfig(VisualizationConfigSkill(
                mode: visualizationMode,
                colorScheme: "default",
                sensitivity: 1.0,
                customParameters: [:]
            ))

        default:
            // Default to session template for other types
            return .sessionTemplate(SessionTemplateSkill(
                duration: duration,
                brainwaveState: brainwaveState,
                visualizationMode: visualizationMode,
                binauralFrequency: binauralFrequency,
                includesBinaural: includesBinaural,
                includesHRV: includesHRV
            ))
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        if remainingSeconds == 0 {
            return "\(minutes) min"
        } else {
            return "\(minutes):\(String(format: "%02d", remainingSeconds))"
        }
    }
}


// MARK: - Preview

#Preview {
    CreateSkillView(repository: SkillsRepository())
}
