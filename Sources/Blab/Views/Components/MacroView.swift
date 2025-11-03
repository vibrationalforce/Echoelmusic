import SwiftUI

/// Macro System View
///
/// Features:
/// - List of saved macros
/// - Execute macros
/// - Record new macros
/// - Edit macro actions
/// - Configure triggers
///
/// Usage:
/// ```swift
/// MacroView(controlHub: hub, audioEngine: engine)
/// ```
@available(iOS 15.0, *)
struct MacroView: View {

    @ObservedObject var macroSystem = MacroSystem.shared
    @ObservedObject var controlHub: UnifiedControlHub
    @ObservedObject var audioEngine: AudioEngine

    @State private var selectedMacro: MacroSystem.Macro? = nil
    @State private var showingRecorder = false
    @State private var showingEditor = false
    @State private var recordingName = ""

    var body: some View {
        List {
            // MARK: - Status
            if macroSystem.isRecording {
                Section {
                    recordingStatusCard
                }
            }

            if macroSystem.isExecuting, let current = macroSystem.currentMacro {
                Section {
                    executingStatusCard(current)
                }
            }

            // MARK: - Macros
            Section {
                if macroSystem.macros.isEmpty {
                    Text("No macros yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(macroSystem.macros) { macro in
                        macroRow(macro)
                    }
                    .onDelete(perform: deleteMacros)
                }
            } header: {
                Text("Macros")
            }

            // MARK: - Actions
            Section {
                Button {
                    showingRecorder.toggle()
                } label: {
                    Label("Record New Macro", systemImage: "record.circle")
                }
                .disabled(macroSystem.isRecording || macroSystem.isExecuting)
            } header: {
                Text("Actions")
            }
        }
        .navigationTitle("Macros")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingRecorder) {
            MacroRecorderView(
                audioEngine: audioEngine,
                controlHub: controlHub
            )
        }
        .sheet(item: $selectedMacro) { macro in
            MacroEditorView(macro: macro)
        }
        .onAppear {
            setupMacroSystem()
        }
    }

    // MARK: - Recording Status

    private var recordingStatusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)

                    Circle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 24, height: 24)
                        .scaleEffect(1.5)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: macroSystem.isRecording)
                }

                Text("RECORDING")
                    .font(.headline)
                    .foregroundColor(.red)

                Spacer()

                Button("Stop") {
                    macroSystem.stopRecording()
                }
                .buttonStyle(.bordered)

                Button("Cancel") {
                    macroSystem.cancelRecording()
                }
                .buttonStyle(.bordered)
            }

            if let current = macroSystem.currentMacro {
                Text(current.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.1))
        )
    }

    // MARK: - Executing Status

    private func executingStatusCard(_ macro: MacroSystem.Macro) -> some View {
        HStack {
            ProgressView()

            VStack(alignment: .leading, spacing: 4) {
                Text("Executing")
                    .font(.headline)

                Text(macro.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.1))
        )
    }

    // MARK: - Macro Row

    private func macroRow(_ macro: MacroSystem.Macro) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(macro.name)
                    .font(.headline)

                HStack {
                    Text("\(macro.actions.count) actions")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(macro.trigger.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Execute button
            Button {
                Task {
                    await macroSystem.execute(macro)
                }
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            .disabled(macroSystem.isExecuting || !macro.enabled)

            // Edit button
            Button {
                selectedMacro = macro
            } label: {
                Image(systemName: "pencil.circle")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .opacity(macro.enabled ? 1.0 : 0.5)
    }

    // MARK: - Actions

    private func setupMacroSystem() {
        macroSystem.setup(audioEngine: audioEngine, controlHub: controlHub)
    }

    private func deleteMacros(at offsets: IndexSet) {
        for index in offsets {
            macroSystem.removeMacro(macroSystem.macros[index])
        }
    }
}

// MARK: - Macro Recorder View

@available(iOS 15.0, *)
struct MacroRecorderView: View {
    @ObservedObject var macroSystem = MacroSystem.shared
    @ObservedObject var audioEngine: AudioEngine
    @ObservedObject var controlHub: UnifiedControlHub

    @State private var macroName = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Macro Name", text: $macroName)
                } header: {
                    Text("Name")
                }

                Section {
                    Text("Start recording, then perform the actions you want to automate. Each action will be recorded.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Instructions")
                }

                Section {
                    if !macroSystem.isRecording {
                        Button("Start Recording") {
                            startRecording()
                        }
                        .disabled(macroName.isEmpty)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 12, height: 12)

                                Text("Recording in progress...")
                                    .foregroundColor(.red)

                                Spacer()
                            }

                            Button("Stop Recording") {
                                stopRecording()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
            .navigationTitle("Record Macro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if macroSystem.isRecording {
                            macroSystem.cancelRecording()
                        }
                        dismiss()
                    }
                }
            }
        }
    }

    private func startRecording() {
        macroSystem.startRecording(name: macroName)
    }

    private func stopRecording() {
        macroSystem.stopRecording()
        dismiss()
    }
}

// MARK: - Macro Editor View

@available(iOS 15.0, *)
struct MacroEditorView: View {
    @ObservedObject var macroSystem = MacroSystem.shared
    @State var macro: MacroSystem.Macro

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    TextField("Name", text: $macro.name)
                    Toggle("Enabled", isOn: $macro.enabled)
                }

                Section("Trigger") {
                    Text(macro.trigger.description)
                        .foregroundColor(.secondary)
                }

                Section("Actions") {
                    if macro.actions.isEmpty {
                        Text("No actions")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(macro.actions.enumerated()), id: \.offset) { index, action in
                            HStack {
                                Text("\(index + 1).")
                                    .foregroundColor(.secondary)
                                    .frame(width: 30)

                                Text(action.description)
                                    .font(.callout)
                            }
                        }
                    }
                }

                Section {
                    Button("Test Macro") {
                        Task {
                            await macroSystem.execute(macro)
                        }
                    }
                }
            }
            .navigationTitle("Edit Macro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        macroSystem.updateMacro(macro)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

@available(iOS 15.0, *)
struct MacroView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            MacroView(
                controlHub: UnifiedControlHub(),
                audioEngine: AudioEngine(microphoneManager: MicrophoneManager())
            )
        }
    }
}
