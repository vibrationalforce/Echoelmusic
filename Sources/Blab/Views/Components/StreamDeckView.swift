import SwiftUI

/// Stream Deck Configuration View
///
/// Features:
/// - Virtual button grid display
/// - Button action configuration
/// - Visual preview of button layout
/// - Preset management
/// - Save/load custom layouts
///
/// Usage:
/// ```swift
/// StreamDeckView(controlHub: hub, audioEngine: engine)
/// ```
@available(iOS 15.0, *)
struct StreamDeckView: View {

    @ObservedObject var streamDeck = StreamDeckController.shared
    @ObservedObject var controlHub: UnifiedControlHub
    @ObservedObject var audioEngine: AudioEngine

    @State private var selectedButton: Int? = nil
    @State private var showingActionPicker = false
    @State private var layoutName = ""
    @State private var showingSaveDialog = false

    var body: some View {
        Form {
            // MARK: - Connection Status
            Section {
                HStack {
                    Image(systemName: streamDeck.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(streamDeck.isConnected ? .green : .red)

                    Text(streamDeck.isConnected ? "Connected" : "Not Connected")
                        .fontWeight(.medium)

                    Spacer()

                    if streamDeck.isConnected {
                        Text(streamDeck.deviceType.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Button("Connect") {
                            connectStreamDeck()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } header: {
                Text("Status")
            }

            // MARK: - Button Grid
            Section {
                buttonGrid
            } header: {
                Text("Button Layout")
            } footer: {
                Text("Tap a button to configure its action")
            }

            // MARK: - Presets
            Section {
                ForEach(StreamDeckController.LayoutPreset.allCases, id: \.self) { preset in
                    Button {
                        streamDeck.loadPreset(preset)
                    } label: {
                        HStack {
                            Text(preset.rawValue)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                }
            } header: {
                Text("Presets")
            }

            // MARK: - Save/Load
            Section {
                Button {
                    showingSaveDialog.toggle()
                } label: {
                    Label("Save Current Layout", systemImage: "square.and.arrow.down")
                }

                Button {
                    // Show load dialog
                } label: {
                    Label("Load Saved Layout", systemImage: "square.and.arrow.up")
                }
            } header: {
                Text("Custom Layouts")
            }
        }
        .navigationTitle("Stream Deck")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedButton) { buttonIndex in
            ButtonConfigView(
                button: $streamDeck.buttonLayout[buttonIndex],
                onSave: {
                    streamDeck.setButton(buttonIndex, config: streamDeck.buttonLayout[buttonIndex])
                    selectedButton = nil
                }
            )
        }
        .alert("Save Layout", isPresented: $showingSaveDialog) {
            TextField("Layout Name", text: $layoutName)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                streamDeck.saveLayout(name: layoutName)
                layoutName = ""
            }
        }
        .onAppear {
            setupStreamDeck()
        }
    }

    // MARK: - Button Grid

    private var buttonGrid: some View {
        let rows = streamDeck.deviceType.rows
        let columns = streamDeck.deviceType.columns

        return VStack(spacing: 8) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(0..<columns, id: \.self) { col in
                        let index = row * columns + col
                        if index < streamDeck.buttonLayout.count {
                            buttonView(index)
                        }
                    }
                }
            }
        }
        .padding()
    }

    private func buttonView(_ index: Int) -> some View {
        let config = streamDeck.buttonLayout[index]

        return Button {
            selectedButton = index
        } label: {
            VStack(spacing: 4) {
                Image(systemName: config.icon)
                    .font(.title3)
                    .foregroundColor(.white)

                Text(config.label)
                    .font(.caption2)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorFromString(config.backgroundColor))
            )
            .opacity(config.enabled ? 1.0 : 0.5)
        }
    }

    // MARK: - Actions

    private func setupStreamDeck() {
        streamDeck.setup(audioEngine: audioEngine, controlHub: controlHub)
    }

    private func connectStreamDeck() {
        streamDeck.connect()
    }

    // MARK: - Helpers

    private func colorFromString(_ colorString: String) -> Color {
        switch colorString.lowercased() {
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        case "yellow": return .yellow
        case "pink": return .pink
        case "cyan": return .cyan
        case "gray": return .gray
        default: return .gray
        }
    }
}

// MARK: - Button Config View

@available(iOS 15.0, *)
struct ButtonConfigView: View {
    @Binding var button: StreamDeckController.ButtonConfig
    let onSave: () -> Void

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Action") {
                    Picker("Action", selection: $button.action) {
                        ForEach(StreamDeckController.ButtonAction.allCases, id: \.self) { action in
                            Text(action.rawValue).tag(action)
                        }
                    }
                }

                Section("Appearance") {
                    TextField("Label", text: $button.label)

                    Picker("Icon", selection: $button.icon) {
                        ForEach(iconOptions, id: \.self) { icon in
                            Label(icon, systemImage: icon).tag(icon)
                        }
                    }

                    Picker("Color", selection: $button.backgroundColor) {
                        ForEach(colorOptions, id: \.self) { color in
                            Text(color.capitalized).tag(color)
                        }
                    }
                }

                Section {
                    Toggle("Enabled", isOn: $button.enabled)
                }

                Section {
                    // Preview
                    VStack(spacing: 8) {
                        Text("Preview")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        VStack(spacing: 4) {
                            Image(systemName: button.icon)
                                .font(.title)
                                .foregroundColor(.white)

                            Text(button.label)
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .frame(width: 80, height: 80)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(colorFromString(button.backgroundColor))
                        )
                        .opacity(button.enabled ? 1.0 : 0.5)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Configure Button")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                    }
                }
            }
        }
    }

    private let iconOptions = [
        "play.circle.fill", "stop.circle.fill", "pause.circle.fill",
        "record.circle", "waveform", "move.3d",
        "antenna.radiowaves.left.and.right", "dot.radiowaves.up.forward",
        "slider.horizontal.3", "speaker.wave.2", "speaker.slash",
        "bolt.circle", "rectangle.3.group"
    ]

    private let colorOptions = ["red", "green", "blue", "orange", "purple", "yellow", "pink", "cyan", "gray"]

    private func colorFromString(_ colorString: String) -> Color {
        switch colorString.lowercased() {
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        case "yellow": return .yellow
        case "pink": return .pink
        case "cyan": return .cyan
        case "gray": return .gray
        default: return .gray
        }
    }
}

// MARK: - Int identifiable extension

extension Int: Identifiable {
    public var id: Int { self }
}

// MARK: - Preview

@available(iOS 15.0, *)
struct StreamDeckView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            StreamDeckView(
                controlHub: UnifiedControlHub(),
                audioEngine: AudioEngine(microphoneManager: MicrophoneManager())
            )
        }
    }
}
