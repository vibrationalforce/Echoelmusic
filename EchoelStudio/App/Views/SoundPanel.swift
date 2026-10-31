import EchoelCore
import SwiftUI
import UniformTypeIdentifiers

/// An instrument track's sound: which instrument plays it, then that instrument's settings.
///
/// The file picker is this sheet's own presentation: it opens from inside the editor sheet,
/// so it cannot share the root's one slot without closing the editor first.
struct SoundPanel: View {
    @Environment(ProjectStore.self) private var store
    @Environment(DocumentController.self) private var documents
    @Environment(AudioEngine.self) private var engine
    @Environment(ParameterWriter.self) private var writer
    /// The choice picked during an automation pass: it goes into the lane, not the track, so the
    /// picker would otherwise go on showing the track's value and ignore a tap on it. One for the
    /// page: each built-in device has at most one choice row (the waveform, the sampler's mode).
    @State private var passPick: Int?
    let track: Track

    @State private var isPickingFile = false

    @ScaledMetric(relativeTo: .body) private var columnWidth: CGFloat = 150

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                devicePicker
                switch track.instrument.device {
                case .drums:
                    // The kit map's one source, shared with the AUv3 drum page and pinned by a test.
                    Text(DrumNoteMap.line)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                    deviceFields(.drums)
                case .sampler:
                    samplerControls
                case .synth:
                    synthControls
                case .unrecognized:
                    Text("This track's instrument comes from a later version of Echoel Studio. It stays in the song and plays nothing here; choose another instrument to replace it.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                case .plugin:
                    pluginStatus
                    PluginInterfaceSection(slot: .instrument(track.id))
                        .id(track.instrument.plugin)
                }
                pluginMenu
            }
            .padding(Theme.Space.l)
        }
        .background(Theme.Color.background)
        // A field typed into opens Echoel's number pad at the page's bottom edge, not a sheet.
        .numberPadHost()
        // On the page, not on a picker: a device switch swaps the picker out, and a new view's
        // `onChange` never fires for the value it appears with.
        .onChange(of: writer.isWriting && engine.isPlaying) { _, on in if !on { passPick = nil } }
        .onChange(of: track.id) { passPick = nil }
        .onChange(of: track.instrument.device) { passPick = nil }
        .fileImporter(isPresented: $isPickingFile, allowedContentTypes: [.audio]) { result in
            guard case .success(let url) = result else { return }
            let target = track.id
            Task { await documents.importAudio(url, onto: target) }
        }
    }

    private var devicePicker: some View {
        Picker("Instrument", selection: Binding(
            get: { track.instrument.device },
            set: { try? store.perform(.setInstrumentDevice(track.id, $0)) }
        )) {
            ForEach(InstrumentDevice.builtIn, id: \.self) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Instrument")
    }

    /// Every installed Audio Unit instrument; choosing one plays this track through it.
    private var pluginMenu: some View {
        let host = engine.plugins
        return Menu {
            if host.instruments.isEmpty {
                Text("No Audio Unit instruments installed")
            }
            ForEach(host.instruments, id: \.self) { component in
                Button("\(component.displayName) — \(component.manufacturerName)") { choose(component) }
            }
        } label: {
            Label("Audio Unit Instrument", systemImage: "puzzlepiece.extension")
                .font(Theme.Font.body)
        }
        .accessibilityHint("Plays this track through an installed Audio Unit instrument.")
    }

    /// The chosen plugin and the switch to it, as one undo step.
    private func choose(_ component: PluginComponent) {
        try? store.perform([.setInstrumentPlugin(track.id, component), .setInstrumentDevice(track.id, .plugin)],
                           title: "Choose Plugin")
    }

    @ViewBuilder private var pluginStatus: some View {
        let host = engine.plugins
        let name = track.instrument.plugin?.displayName ?? "A plugin"
        Group {
            if let problem = host.problems[.instrument(track.id)] {
                Text(problem)
            } else if host.loading.contains(.instrument(track.id)) {
                Text("Loading \(name)…")
            } else if host.revision >= 0 && host.units[track.id] != nil {
                Text("Plays \(name). Notes reach it on the exact frame they fall on.")
            } else {
                Text("\(name) is not loaded yet.")
            }
        }
        .font(Theme.Font.caption)
        .foregroundStyle(Theme.Color.textSecondary)
    }

    @ViewBuilder private var samplerControls: some View {
        let loaded = track.instrument.sample.flatMap { store.project.mediaFile($0) }
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(loaded?.name ?? "No Sample")
                .font(Theme.Font.body)
                .foregroundStyle(loaded == nil ? Theme.Color.textSecondary : Theme.Color.text)
                .lineLimit(2)
            if let loaded {
                Text(NumberText.string(loaded.duration, decimals: 2, unit: "s") + " · " + NumberText.string(loaded.sampleRate, decimals: 0, unit: "Hz"))
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)

        HStack(spacing: Theme.Space.s) {
            Button {
                isPickingFile = true
            } label: {
                Label(documents.isImporting ? "Importing…" : "Import Audio File…", systemImage: "square.and.arrow.down")
                    .font(Theme.Font.label)
                    .frame(minHeight: Theme.Size.touch)
            }
            .disabled(documents.isImporting)

            if !store.project.media.isEmpty {
                Menu {
                    ForEach(store.project.media) { file in
                        Button {
                            try? store.perform(.setInstrumentSample(track.id, file.id))
                        } label: {
                            if file.id == track.instrument.sample {
                                Label(file.name, systemImage: "checkmark")
                            } else {
                                Text(file.name)
                            }
                        }
                    }
                } label: {
                    Label("Song Samples", systemImage: "waveform")
                        .font(Theme.Font.label)
                        .frame(minHeight: Theme.Size.touch)
                }
            }
        }

        choicePicker(.samplerMode)
        deviceFields(.sampler)

        let root = Int(track.instrument.value(.samplerRoot).rounded())
        Text("Plays the sample at its own pitch on \(NoteEditing.name(of: root)) (MIDI \(root)); other notes transpose it.")
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Color.textSecondary)
    }

    /// A built-in instrument's numbers, one field each; its choices have their own picker.
    private func deviceFields(_ device: InstrumentDevice) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: columnWidth), spacing: Theme.Space.s)],
                  alignment: .leading, spacing: Theme.Space.s) {
            ForEach(device.parameters.filter { $0.unit != .choice }, id: \.key) { parameter in
                ParameterField(address: ParameterAddress(.track(track.id), parameter.key))
            }
        }
    }


    @ViewBuilder private var synthControls: some View {
        Menu {
            ForEach(InstrumentPreset.all, id: \.name) { preset in
                Button(preset.name) { try? store.perform(.loadInstrumentPreset(track.id, name: preset.name)) }
            }
        } label: {
            HStack {
                Text("Preset").foregroundStyle(Theme.Color.textSecondary)
                Text(track.instrument.preset).foregroundStyle(Theme.Color.text)
                if track.instrument.isEditedFromPreset {
                    Text("· edited").foregroundStyle(Theme.Color.textSecondary)
                }
                Image(systemName: "chevron.down").foregroundStyle(Theme.Color.textSecondary)
                    .accessibilityHidden(true)
            }
            .font(Theme.Font.body)
            .frame(minHeight: Theme.Size.touch)
        }
        .accessibilityLabel("Preset \(track.instrument.preset)\(track.instrument.isEditedFromPreset ? ", edited" : "")")

        choicePicker(.engine)
        choicePicker(.waveform)
        choicePicker(.filter)

        LazyVGrid(columns: [GridItem(.adaptive(minimum: columnWidth), spacing: Theme.Space.s)],
                  alignment: .leading, spacing: Theme.Space.s) {
            ForEach(SynthParameter.all.filter { $0.unit != .choice }, id: \.key) { parameter in
                ParameterField(address: ParameterAddress(.track(track.id), parameter.key))
            }
        }
    }

    /// A named choice of the instrument (the synth's waveform, the sampler's gate or one-shot).
    /// Through the writer like every other control, so a choice made while automation writing is
    /// armed and the song plays lands in its lane instead of being overridden by it.
    private func choicePicker(_ parameter: InstrumentParameter) -> some View {
        let address = ParameterAddress(.track(track.id), parameter.key)
        let current = Int(track.instrument.value(parameter).rounded())
        let writing = writer.isWriting && engine.isPlaying
        return Picker(parameter.title, selection: Binding(
            get: { writing ? (passPick ?? current) : current },
            set: {
                passPick = writing ? $0 : nil
                writer.set(address, to: Double($0), coalescingKey: nil)
                writer.endGesture()
            }
        )) {
            ForEach(parameter.choices.indices, id: \.self) { Text(parameter.choices[$0]).tag($0) }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel(parameter.title)
    }
}
